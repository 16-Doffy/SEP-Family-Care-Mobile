import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FamilyMember {
  final String id;       // familyMember.id (membership record)
  final String userId;   // user.id
  final String name;
  final String email;
  final String role;     // MANAGER | DEPUTY | MEMBER
  final String relation;
  final int avatarColor;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.relation,
    required this.avatarColor,
  });

  String get avatarInitials =>
      name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

  bool get isManager => role.toUpperCase().contains('MANAGER');
  bool get isDeputy  => role.toUpperCase().contains('DEPUTY');

  String get roleLabel {
    final r = role.toUpperCase();
    if (r.contains('MANAGER')) return 'Trưởng nhóm';
    if (r.contains('DEPUTY'))  return 'Phó nhóm';
    return 'Thành viên';
  }

  Color get roleColor {
    final r = role.toUpperCase();
    if (r.contains('MANAGER') || r.contains('DEPUTY')) return const Color(0xFF2563EB);
    return const Color(0xFF6B7280);
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final colors = [0xFF3B82F6, 0xFFA78BFA, 0xFFFB923C, 0xFF2DD4BF, 0xFFEC4899];
    // BE trả về member record: { id, userId, familyRole, relationship, user: { id, fullName, email } }
    final userMap = json['user'] is Map
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final userId = userMap['id']?.toString() ?? json['userId']?.toString() ?? '';
    final idx    = userId.hashCode.abs() % colors.length;
    final name   = userMap['fullName']?.toString() ??
                   userMap['displayName']?.toString() ??
                   json['displayName']?.toString() ?? '';
    return FamilyMember(
      id:          json['id']?.toString() ?? '',
      userId:      userId,
      name:        name,
      email:       userMap['email']?.toString() ?? json['email']?.toString() ?? '',
      role:        json['familyRole']?.toString() ?? json['role']?.toString() ?? 'MEMBER',
      relation:    json['relationship']?.toString() ?? json['relation']?.toString() ?? '',
      avatarColor: json['avatarColor'] is int ? json['avatarColor'] as int : colors[idx],
    );
  }
}

class FamilyProvider extends ChangeNotifier {
  List<FamilyMember> _members = [];
  String _familyName = '';
  bool _loading = false;
  String? _error;

  List<FamilyMember> get members => _members;
  String get familyName => _familyName;
  bool get isLoading => _loading;
  String? get error => _error;

  // UC20 — Lấy danh sách thành viên: GET /families/{familyId}
  Future<void> fetchMembers() async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$familyId') as Map<String, dynamic>;
      _familyName = data['name']?.toString() ?? '';
      final list  = data['members'] as List? ?? [];
      _members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // UC19 — Xoá thành viên: DELETE /families/{familyId}/members/{userId}
  Future<void> removeMember(String userId) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    await ApiClient.instance.delete('/families/$familyId/members/$userId');
    _members.removeWhere((m) => m.userId == userId);
    notifyListeners();
  }

  // UC17/18 — Thay đổi role: chờ BE-04
  // Backend hiện chỉ có admin endpoint cho việc này
  Future<void> updateRole(String memberId, String newRole) async {
    throw Exception('Tính năng thay đổi quyền đang được cập nhật từ phía server.');
  }

  Future<void> grantDeputy(String memberId)  => updateRole(memberId, 'DEPUTY');
  Future<void> revokeDeputy(String memberId) => updateRole(memberId, 'MEMBER');
}
