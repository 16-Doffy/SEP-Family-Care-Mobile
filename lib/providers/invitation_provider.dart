import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Request to join a family using its reusable 8-character invite code.
class JoinRequest {
  final String id;
  final String status;
  final String? message;
  final String? requesterName;
  final String? requesterEmail;
  final String? familyName;

  const JoinRequest({
    required this.id,
    required this.status,
    this.message,
    this.requesterName,
    this.requesterEmail,
    this.familyName,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  String get statusLabel => switch (status.toUpperCase()) {
    'APPROVED' => 'Đã được duyệt',
    'REJECTED' => 'Đã bị từ chối',
    'CANCELED' => 'Đã hủy',
    _ => 'Đang chờ duyệt',
  };

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']) ?? _map(json['requester']) ?? <String, dynamic>{};
    final family = _map(json['family']) ?? <String, dynamic>{};
    return JoinRequest(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      message: json['message']?.toString(),
      requesterName:
          user['fullName']?.toString() ?? user['displayName']?.toString(),
      requesterEmail: user['email']?.toString(),
      familyName: family['name']?.toString(),
    );
  }
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _list(dynamic data) {
  final raw = data is List
      ? data
      : data is Map && data['items'] is List
      ? data['items'] as List
      : <dynamic>[];
  return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

/// Provider for the current BE flow: invite code -> join request -> manager
/// decision. The retired email/token invitation APIs are intentionally absent.
class InvitationProvider extends ChangeNotifier {
  List<JoinRequest> joinRequests = [];
  List<JoinRequest> myJoinRequests = [];
  bool loading = false;
  String? error;

  String? get _familyId => ApiClient.instance.familyId;
  int get pendingJoinRequestCount =>
      joinRequests.where((request) => request.isPending).length;

  Future<String?> fetchInviteCode() async {
    final familyId = _familyId;
    if (familyId == null) return null;
    final data = await ApiClient.instance.get('/families/$familyId/invite-code');
    return data is Map ? data['inviteCode']?.toString() : null;
  }

  /// Creates the first code or invalidates the old code and returns a new one.
  Future<String?> regenerateInviteCode() async {
    final familyId = _familyId;
    if (familyId == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.post(
      '/families/$familyId/invite-code/regenerate',
      {},
    );
    return data['inviteCode']?.toString();
  }

  Future<void> fetchJoinRequests({String? status = 'PENDING'}) async {
    final familyId = _familyId;
    if (familyId == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final query = status == null
          ? ''
          : '?status=${Uri.encodeQueryComponent(status)}';
      final data = await ApiClient.instance.get(
        '/families/$familyId/join-requests$query',
      );
      joinRequests = _list(data).map(JoinRequest.fromJson).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> approveJoinRequest(
    String requestId, {
    String familyRole = 'FAMILY_MEMBER',
    String relationship = 'OTHER',
  }) async {
    final familyId = _familyId;
    if (familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$familyId/join-requests/$requestId/approve',
      {'familyRole': familyRole, 'relationship': relationship},
    );
    await fetchJoinRequests();
  }

  Future<void> rejectJoinRequest(String requestId) async {
    final familyId = _familyId;
    if (familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$familyId/join-requests/$requestId/reject',
      {},
    );
    await fetchJoinRequests();
  }

  Future<Map<String, dynamic>?> previewInviteCode(String code) async {
    final data = await ApiClient.instance.get('/invite-codes/${code.trim()}');
    return _map(data);
  }

  Future<JoinRequest> requestJoinByCode(String code, {String? message}) async {
    final data = await ApiClient.instance.post(
      '/invite-codes/${code.trim()}/join-requests',
      {if (message != null && message.trim().isNotEmpty) 'message': message.trim()},
    );
    return JoinRequest.fromJson(data);
  }

  Future<void> fetchMyJoinRequests() async {
    final data = await ApiClient.instance.get('/me/join-requests');
    myJoinRequests = _list(data).map(JoinRequest.fromJson).toList();
    notifyListeners();
  }

  Future<void> cancelMyJoinRequest(String requestId) async {
    await ApiClient.instance.post('/me/join-requests/$requestId/cancel', {});
    await fetchMyJoinRequests();
  }
}
