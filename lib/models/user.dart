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
  // account-level type từ BE: NORMAL_USER | SYSTEM_ADMIN (không liên quan familyRole)
  final String userType;

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
    this.userType = 'NORMAL_USER',
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
    // familyRole = vai trò trong gia đình (FAMILY_MANAGER / DEPUTY_MEMBER / FAMILY_MEMBER)
    // userType   = loại tài khoản hệ thống (NORMAL_USER / SYSTEM_ADMIN) — KHÔNG dùng để xác định role gia đình
    final roleStr = (familyRole ?? json['familyRole'] as String? ??
            json['role'] as String? ?? '')
        .toUpperCase();
    final role = roleStr == 'FAMILY_MANAGER'
        ? UserRole.manager
        : roleStr == 'DEPUTY_MEMBER'
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

    final resolvedUserType = json['userType']?.toString() ?? 'NORMAL_USER';

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
      userType:       resolvedUserType,
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

  bool get isSystemAdmin => userType == 'SYSTEM_ADMIN';

  /// Trả về giá trị familyRole đúng theo BE enum để truyền lại vào fromJson
  String get familyRoleString => switch (role) {
        UserRole.manager => 'FAMILY_MANAGER',
        UserRole.deputy  => 'DEPUTY_MEMBER',
        UserRole.member  => 'FAMILY_MEMBER',
      };
  bool get isAdministrative => role == UserRole.manager || role == UserRole.deputy;

  // Quyền chung Manager + Deputy ("limited management authority")
  bool get canAccessSensitiveFinance => isAdministrative;
  bool get canApproveWithdrawals => isAdministrative;
  bool get canManageTasks => isAdministrative;
  bool get canManageFinance => isAdministrative;
  bool get canApproveSupportRequests => isAdministrative;
  bool get canManageCalendar => isAdministrative;
  bool get canResolveSos => isAdministrative;

  // Quyền Manager-only — Deputy KHÔNG được, dù isAdministrative = true
  bool get canManageMemberRoles => role == UserRole.manager;
  bool get canRemoveMembers => role == UserRole.manager;
  bool get canManageSubscription => role == UserRole.manager;

  // Đã verify bằng tài khoản Deputy thật trên BE (2026-06-22): POST
  // /invitations trả 403 "Yêu cầu vai trò gia đình: FAMILY_MANAGER" cho
  // Deputy — chỉ Manager được mời thành viên.
  bool get canInviteMembers => role == UserRole.manager;
}
