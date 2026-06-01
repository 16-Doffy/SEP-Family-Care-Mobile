enum UserRole { manager, deputy, member }

class AppUser {
  final String id;
  final String name;
  final String familyName;
  final UserRole role;
  final String avatarInitials;
  final int avatarColor;

  const AppUser({
    required this.id,
    required this.name,
    required this.familyName,
    required this.role,
    required this.avatarInitials,
    required this.avatarColor,
  });

  /// Kiểm tra xem người dùng có quyền quản trị (Trưởng/Phó nhóm) hay không
  bool get isAdministrative => role == UserRole.manager || role == UserRole.deputy;

  /// Quyền xem tài chính nhạy cảm (Hạng 9) và quản lý ví chung
  bool get canAccessSensitiveFinance => isAdministrative;

  /// Quyền duyệt yêu cầu rút tiền từ thành viên
  bool get canApproveWithdrawals => isAdministrative;

  /// Quyền điều phối công việc (Tasks)
  bool get canManageTasks => isAdministrative;
}
