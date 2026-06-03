import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FamilyMember {
  final String id;
  final String name;
  final String email;
  final String role; // MANAGER | DEPUTY | MEMBER
  final String relation;
  final int avatarColor;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.relation,
    required this.avatarColor,
  });

  String get avatarInitials =>
      name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

  String get roleLabel {
    switch (role.toUpperCase()) {
      case 'MANAGER': return 'Trưởng nhóm';
      case 'DEPUTY':  return 'Phó nhóm';
      default:        return 'Thành viên';
    }
  }

  Color get roleColor {
    switch (role.toUpperCase()) {
      case 'MANAGER': return const Color(0xFF2563EB);
      case 'DEPUTY':  return const Color(0xFF2563EB);
      default:        return const Color(0xFF6B7280);
    }
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final colors = [0xFF3B82F6, 0xFFA78BFA, 0xFFFB923C, 0xFF2DD4BF, 0xFFEC4899];
    final idx    = (json['id']?.toString() ?? '').hashCode.abs() % colors.length;
    return FamilyMember(
      id:          json['id']?.toString() ?? '',
      name:        json['displayName']?.toString() ?? json['name']?.toString() ?? '',
      email:       json['email']?.toString() ?? '',
      role:        json['role']?.toString() ?? 'MEMBER',
      relation:    json['relation']?.toString() ?? '',
      avatarColor: json['avatarColor'] is int ? json['avatarColor'] as int : colors[idx],
    );
  }
}

class FamilyProvider extends ChangeNotifier {
  List<FamilyMember> _members = [];
  bool _loading = false;
  String? _error;

  List<FamilyMember> get members => _members;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> fetchMembers() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/family/members');
      final list = data is List
          ? data
          : data is Map && data['members'] is List
              ? data['members'] as List
              : data is Map && data['items'] is List
                  ? data['items'] as List
                  : <dynamic>[];
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

  // UC17 — Thay đổi role thành viên
  Future<void> updateRole(String memberId, String newRole) async {
    await ApiClient.instance.patch('/family/members/$memberId', {'role': newRole});
    await fetchMembers();
  }

  // UC18 — Cấp / Thu quyền Phó nhóm
  Future<void> grantDeputy(String memberId) => updateRole(memberId, 'DEPUTY');
  Future<void> revokeDeputy(String memberId) => updateRole(memberId, 'MEMBER');

  // UC19 — Xoá thành viên
  Future<void> removeMember(String memberId) async {
    await ApiClient.instance.delete('/family/members/$memberId');
    _members.removeWhere((m) => m.id == memberId);
    notifyListeners();
  }
}
