enum UserRole { manager, deputy, member }

class AppUser {
  final String id;
  final String name;
  final String familyName;
  final String? familyId;
  final UserRole role;
  final String avatarInitials;
  final int avatarColor;
  final String? accessToken;
  final String? refreshToken;

  const AppUser({
    required this.id,
    required this.name,
    required this.familyName,
    this.familyId,
    required this.role,
    required this.avatarInitials,
    required this.avatarColor,
    this.accessToken,
    this.refreshToken,
  });

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    String? accessToken,
    String? refreshToken,
    String? familyId,
  }) {
    final roleStr = (json['role'] as String? ?? '').toUpperCase();
    final role = roleStr.contains('MANAGER') || roleStr.contains('ADMIN')
        ? UserRole.manager
        : roleStr.contains('DEPUTY')
            ? UserRole.deputy
            : UserRole.member;

    // BE returns fullName on user object; family member has displayName
    final name = json['fullName'] as String? ??
        json['displayName'] as String? ??
        'User';

    // Try to extract familyId from nested member info in auth response
    final member = json['familyMember'] as Map<String, dynamic>?;
    final family = member?['family'] as Map<String, dynamic>?;
    final extractedFamilyId = familyId ??
        member?['familyId']?.toString() ??
        family?['id']?.toString();
    final familyName = family?['name'] as String? ?? '';

    return AppUser(
      id: json['id']?.toString() ?? '',
      name: name,
      familyName: familyName,
      familyId: extractedFamilyId,
      role: role,
      avatarInitials: _initials(name),
      avatarColor: colorForRole(role),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  AppUser copyWith({String? familyId, String? familyName}) => AppUser(
        id: id,
        name: name,
        familyName: familyName ?? this.familyName,
        familyId: familyId ?? this.familyId,
        role: role,
        avatarInitials: avatarInitials,
        avatarColor: avatarColor,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  static int colorForRole(UserRole role) => switch (role) {
        UserRole.manager => 0xFF2563EB,
        UserRole.deputy => 0xFF16A34A,
        UserRole.member => 0xFFEA580C,
      };

  bool get isAdministrative => role == UserRole.manager || role == UserRole.deputy;
  bool get canAccessSensitiveFinance => isAdministrative;
  bool get canApproveWithdrawals => isAdministrative;
  bool get canManageTasks => isAdministrative;
}
