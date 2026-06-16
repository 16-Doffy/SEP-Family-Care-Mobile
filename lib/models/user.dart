enum UserRole { manager, deputy, member }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
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
    required this.email,
    this.phone,
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
    String? familyName,
    String? familyRole,
    String? phone,
  }) {
    // Role ưu tiên: từ familyMember.familyRole (context gia đình) > json.role (account level)
    final roleStr = (familyRole ?? json['familyRole'] as String? ??
            json['role'] as String? ?? '')
        .toUpperCase();
    final role = roleStr.contains('MANAGER') || roleStr.contains('ADMIN')
        ? UserRole.manager
        : roleStr.contains('DEPUTY')
            ? UserRole.deputy
            : UserRole.member;

    final name = json['fullName'] as String? ??
        json['displayName'] as String? ??
        'User';

    // familyName: ưu tiên từ tham số truyền vào (sau khi gọi /families/my)
    final fName = familyName ??
        (json['familyMember'] is Map
            ? ((json['familyMember'] as Map)['family'] is Map
                ? ((json['familyMember'] as Map)['family'] as Map)['name']
                    ?.toString()
                : null)
            : null) ??
        '';

    final resolvedPhone = phone
        ?? json['phone']?.toString()
        ?? json['phoneNumber']?.toString();

    return AppUser(
      id:             json['id']?.toString() ?? '',
      name:           name,
      email:          json['email']?.toString() ?? '',
      phone:          resolvedPhone,
      familyName:     fName,
      familyId:       familyId,
      role:           role,
      avatarInitials: _initials(name),
      avatarColor:    colorForRole(role),
      accessToken:    accessToken,
      refreshToken:   refreshToken,
    );
  }

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  static int colorForRole(UserRole role) => switch (role) {
        UserRole.manager => 0xFF2563EB,
        UserRole.deputy  => 0xFF2563EB,
        UserRole.member  => 0xFFEA580C,
      };

  bool get isAdministrative => role == UserRole.manager || role == UserRole.deputy;
  bool get canAccessSensitiveFinance => isAdministrative;
  bool get canApproveWithdrawals => isAdministrative;
  bool get canManageTasks => isAdministrative;
}
