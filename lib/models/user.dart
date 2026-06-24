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
    UserRole? roleOverride,
  }) {
    // familyMember.familyRole = role trong gia đình (FAMILY_MANAGER/DEPUTY_MEMBER/FAMILY_MEMBER)
    // json['role'] = platform role (USER/ADMIN) — không phản ánh vai trò gia đình
    final member = json['familyMember'] as Map<String, dynamic>?;
    final memberFamilyRole = (member?['familyRole'] as String? ?? '').toUpperCase();
    final platformRole    = (json['role'] as String? ?? '').toUpperCase();
    // Ưu tiên: override > familyRole > platformRole
    final effectiveRole = roleOverride != null
        ? roleOverride
        : _parseRole(memberFamilyRole.isNotEmpty ? memberFamilyRole : platformRole);

    final name = json['fullName'] as String? ??
        json['displayName'] as String? ??
        'User';

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
      role: effectiveRole,
      avatarInitials: _initials(name),
      avatarColor: colorForRole(effectiveRole),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  static UserRole _parseRole(String s) {
    if (s.contains('MANAGER') || s.contains('ADMIN')) return UserRole.manager;
    if (s.contains('DEPUTY')) return UserRole.deputy;
    return UserRole.member;
  }

  AppUser copyWith({String? familyId, String? familyName, UserRole? role}) {
    final newRole = role ?? this.role;
    return AppUser(
      id: id,
      name: name,
      familyName: familyName ?? this.familyName,
      familyId: familyId ?? this.familyId,
      role: newRole,
      avatarInitials: avatarInitials,
      avatarColor: colorForRole(newRole),
      accessToken: accessToken,
      refreshToken: refreshToken,
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
        UserRole.deputy => 0xFF16A34A,
        UserRole.member => 0xFFEA580C,
      };

  bool get isFamilyManager => role == UserRole.manager;
  bool get hasDeputyPermission => role == UserRole.deputy;
  bool get isMember => role == UserRole.member;

  bool get canAccessManagerWorkspace => isFamilyManager || hasDeputyPermission;
  bool get canManageSharedFinance => isFamilyManager || hasDeputyPermission;
  bool get canAccessSensitiveFinance => canManageSharedFinance;
  bool get canApproveWithdrawals => canManageSharedFinance;
  bool get canManageTasks => isFamilyManager || hasDeputyPermission;
  bool get canResolveSos => isFamilyManager || hasDeputyPermission;
  bool get canInviteMembers => isFamilyManager;
  bool get canManageFamilyMembers => isFamilyManager;
  bool get canManageFamilySettings => isFamilyManager;
  bool get canManageSubscription => isFamilyManager;

  bool get isAdministrative => canAccessManagerWorkspace;
}
