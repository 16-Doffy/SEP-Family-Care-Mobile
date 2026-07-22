import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SupportRequest {
  final String id;
  final String requesterName;
  final double amount;
  final String purpose;
  final String status;
  final DateTime createdAt;
  final String? decisionNote;

  const SupportRequest({
    required this.id,
    required this.requesterName,
    required this.amount,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.decisionNote,
  });

  factory SupportRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map? ?? json['user'] as Map? ?? {};
    return SupportRequest(
      id: json['id']?.toString() ?? '',
      requesterName:
          requester['fullName']?.toString() ??
          requester['name']?.toString() ??
          'Thành viên',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      decisionNote: json['decisionNote']?.toString(),
    );
  }

  bool get isPending => status == 'PENDING';
}

class SupportRequestProvider extends ChangeNotifier {
  List<SupportRequest> _requests = [];
  bool _loading = false;
  String? _error;

  List<SupportRequest> get requests => _requests;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingCount => _requests.where((r) => r.isPending).length;

  Future<void> fetchRequests() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/finance/support-requests',
      );
      final list = data is List
          ? data
          : (data['items'] as List? ?? data['data'] as List? ?? []);
      _requests = list
          .whereType<Map<String, dynamic>>()
          .map(SupportRequest.fromJson)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest({
    required double amount,
    required String purpose,
    String? categoryId,
  }) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final body = <String, dynamic>{
      'amount': amount,
      'purpose': purpose,
      'categoryId': ?categoryId,
    };
    await ApiClient.instance.post(
      '/families/$fid/finance/support-requests',
      body,
    );
    await fetchRequests();
  }

  Future<void> review({
    required String requestId,
    required String decision,
    String? decisionNote,
  }) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    final body = <String, dynamic>{
      'decision': decision,
      if (decisionNote != null && decisionNote.isNotEmpty)
        'decisionNote': decisionNote,
      'occurredAt': DateTime.now().toIso8601String(),
    };
    await ApiClient.instance.patch(
      '/families/$fid/finance/support-requests/$requestId/review',
      body,
    );
    await fetchRequests();
  }

  // GET /families/{familyId}/finance/support-requests/{requestId} — chi
  // tiết 1 yêu cầu (list đã đủ hầu hết field hiển thị, gọi thêm để lấy field
  // audit như reviewedBy/reviewedAt nếu BE có mà list không trả về).
  Future<Map<String, dynamic>> fetchRequestDetail(String requestId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.get(
      '/families/$fid/finance/support-requests/$requestId',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> cancel(String requestId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$fid/finance/support-requests/$requestId/cancel',
      {},
    );
    await fetchRequests();
  }
}
