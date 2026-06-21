import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FamilyMember {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String familyRole; // FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER
  final String status;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.familyRole,
    required this.status,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user?['id']?.toString() ?? '',
      displayName: json['displayName'] as String? ??
          user?['fullName'] as String? ??
          'Thành viên',
      avatarUrl: user?['avatarUrl'] as String?,
      familyRole: json['familyRole'] as String? ?? 'FAMILY_MEMBER',
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  bool get isManager => familyRole == 'FAMILY_MANAGER';
  bool get isDeputy  => familyRole == 'DEPUTY_MEMBER';

  String get roleLabel => switch (familyRole) {
        'FAMILY_MANAGER' => 'Trưởng nhóm',
        'DEPUTY_MEMBER'  => 'Phó nhóm',
        _                => 'Thành viên',
      };
}

class FamilyDetail {
  final String id;
  final String name;
  final String? description;
  final List<FamilyMember> members;

  const FamilyDetail({
    required this.id,
    required this.name,
    this.description,
    this.members = const [],
  });

  factory FamilyDetail.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return FamilyDetail(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      members: rawMembers
          .whereType<Map>()
          .map((m) => FamilyMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class FamilyProvider extends ChangeNotifier {
  String? _familyId;

  FamilyDetail? _family;
  bool _loading = false;
  String? _error;

  FamilyDetail? get family => _family;
  bool get isLoading => _loading;
  String? get error => _error;
  List<FamilyMember> get members => _family?.members ?? [];

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchFamily();
    }
  }

  // ─── Families ─────────────────────────────────────────────────────────────

  Future<String> createFamily({
    required String name,
    String description = '',
    String? avatarUrl,
  }) async {
    final data = await ApiClient.instance.post('/families', {
      'name': name,
      if (description.isNotEmpty) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    final id = (data is Map ? data['id']?.toString() : null) ?? '';
    return id;
  }

  Future<void> fetchFamily() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId');
      if (data is Map<String, dynamic>) {
        _family = FamilyDetail.fromJson(data);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateFamily({
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    if (_familyId == null) return;
    await ApiClient.instance.patch('/families/$_familyId', {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    await fetchFamily();
  }

  Future<void> removeMember(String userId) async {
    if (_familyId == null) return;
    await ApiClient.instance.delete('/families/$_familyId/members/$userId');
    await fetchFamily();
  }

  // ─── Invitations ──────────────────────────────────────────────────────────

  // Returns the invite token so the caller can display a shareable link
  Future<String> inviteMember(
    String email, {
    String familyRole = 'FAMILY_MEMBER',
    String relationship = 'OTHER',
    String? invitedPhone,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.post('/families/$_familyId/invitations', {
      'email': email,
      'familyRole': familyRole,
      'relationship': relationship,
      if (invitedPhone != null && invitedPhone.isNotEmpty) 'invitedPhone': invitedPhone,
    });
    final map = data is Map ? data : {};
    final token = map['token']?.toString() ?? map['inviteToken']?.toString() ?? map['data']?['token']?.toString() ?? '';
    return token;
  }

  Future<Map<String, dynamic>> lookupInvitation(String token) async {
    final data = await ApiClient.instance.get('/invitations/$token');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> acceptInvitation(String token) async {
    await ApiClient.instance.post('/invitations/$token/accept');
  }

  Future<void> rejectInvitation(String token) async {
    await ApiClient.instance.post('/invitations/$token/reject');
  }
}
