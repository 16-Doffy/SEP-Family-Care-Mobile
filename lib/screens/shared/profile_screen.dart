import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_mode_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/avatar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshMe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isManager = user?.isAdministrative ?? false;
    final isMember = !(user?.isAdministrative ?? true);
    final themeController = context.watch<ThemeModeController>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),

            // ── Avatar + tên + gia đình + role chip ──────────────────
            Center(
              child: Column(
                children: [
                  AvatarWidget(
                    initial: user?.avatarInitials ?? '?',
                    color: Color(
                      user?.avatarColor ?? AppColors.avatarBlue.toARGB32(),
                    ),
                    size: 80,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gia đình ${user?.familyName ?? ""}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.link.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _getRoleName(user?.role),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.link,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Info card: email + phone ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _infoRow(Icons.email_outlined, 'Email', user?.email ?? '—'),
                  if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                    Divider(height: 16, color: colors.divider),
                    _infoRow(Icons.phone_outlined, 'Điện thoại', user.phone!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tài khoản ─────────────────────────────────────────────
            _section('Tài khoản', [
              _tile(
                Icons.person_outline_rounded,
                'Chỉnh sửa hồ sơ',
                onTap: () => context.push('/profile/edit'),
              ),
              _tile(
                Icons.receipt_long_outlined,
                'Tài chính tháng của tôi',
                onTap: () => context.push('/profile/edit'),
              ),
              _tile(
                Icons.lock_outline_rounded,
                'Bảo mật',
                onTap: () => context.push('/profile/change-password'),
              ),
              _tile(
                Icons.palette_outlined,
                'Giao diện',
                subtitle: themeController.preference.label,
                onTap: () => _showThemeModeSheet(context),
              ),
              // Mọi role đều tùy chỉnh được — cấu hình lưu riêng theo role.
              _tile(
                Icons.dashboard_customize_outlined,
                'Thanh điều hướng',
                onTap: () => context.push('/settings/tabs'),
              ),
              // Quản lý thiết bị đeo (đồng hồ/định vị). Mọi role vào được;
              // ghép/gỡ chỉ Manager/Deputy (gate trong màn).
              _tile(
                Icons.watch_outlined,
                'Thiết bị đeo',
                onTap: () => context.push('/wearables'),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Gia đình — theo role ──────────────────────────────────
            _section('Gia đình', [
              if (isManager) ...[
                _tile(
                  Icons.groups_2_outlined,
                  'Thành viên gia đình',
                  onTap: () => context.push('/manager/members'),
                ),
                if (user?.canInviteMembers ?? false) ...[
                  _tile(
                    Icons.mail_outline_rounded,
                    'Mời thành viên',
                    onTap: () => context.push('/manager/invite'),
                  ),
                  _tile(
                    Icons.how_to_reg_outlined,
                    'Duyệt yêu cầu tham gia',
                    onTap: () => context.push('/manager/invite-requests'),
                  ),
                ],
                if (user?.canManageSubscription ?? false)
                  _tile(
                    Icons.card_membership_outlined,
                    'Gói đăng ký',
                    onTap: () => context.push('/manager/subscription'),
                  ),
                _tile(
                  Icons.account_balance_outlined,
                  'Mô hình tài chính',
                  onTap: () => context.push('/manager/finance-model'),
                ),
                _tile(
                  Icons.savings_outlined,
                  'Kế hoạch ngân sách',
                  onTap: () => context.push('/manager/budget-plans'),
                ),
                _tile(
                  Icons.flag_outlined,
                  'Mục tiêu tiết kiệm',
                  onTap: () => context.push('/manager/financial-goals'),
                ),
                _tile(
                  Icons.notification_important_outlined,
                  'Cảnh báo tài chính',
                  onTap: () => context.push('/manager/finance-alerts'),
                ),
                _tile(
                  Icons.bar_chart_rounded,
                  'Báo cáo tài chính',
                  onTap: () => context.push('/manager/finance-reports'),
                ),
                _tile(
                  Icons.request_quote_outlined,
                  'Yêu cầu hỗ trợ chi tiêu',
                  onTap: () => context.push('/finance/support-requests'),
                ),
                _tile(
                  Icons.map_outlined,
                  'Bản đồ gia đình',
                  onTap: () => context.push('/map'),
                ),
                // Manager đã có tab Ảnh ở bottom nav — chỉ Deputy cần lối này
                if (user?.role == UserRole.deputy)
                  _tile(
                    Icons.photo_library_outlined,
                    'Ảnh gia đình',
                    onTap: () => context.push('/album'),
                  ),
                if (user?.role == UserRole.deputy)
                  _tile(
                    Icons.logout_rounded,
                    'Rời gia đình',
                    onTap: () => _showLeaveUnavailable(context),
                  ),
              ] else if (isMember) ...[
                _tile(
                  Icons.groups_2_outlined,
                  'Xem thành viên gia đình',
                  onTap: () => context.push('/manager/members'),
                ),
                _tile(
                  Icons.photo_library_outlined,
                  'Ảnh gia đình',
                  onTap: () => context.push('/album'),
                ),
                _tile(
                  Icons.request_quote_outlined,
                  'Yêu cầu hỗ trợ chi tiêu',
                  onTap: () => context.push('/finance/support-requests'),
                ),
                _tile(
                  Icons.map_outlined,
                  'Bản đồ gia đình',
                  onTap: () => context.push('/map'),
                ),
                _tile(
                  Icons.logout_rounded,
                  'Rời gia đình',
                  onTap: () => _showLeaveUnavailable(context),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            _section('Khác', [
              _tile(Icons.help_outline_rounded, 'Trợ giúp & FAQ', onTap: () {}),
              _tile(Icons.description_outlined, 'Điều khoản sử dụng', onTap: () {}),
            ]),
            const SizedBox(height: 16),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: AppColors.danger,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: auth.logout,
                child: Text(
                  'Đăng xuất',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getRoleName(UserRole? role) => switch (role) {
    UserRole.manager => 'TRƯỞNG NHÓM',
    UserRole.deputy => 'PHÓ NHÓM',
    UserRole.member => 'THÀNH VIÊN',
    null => 'KHÁCH',
  };

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: context.colors.textMuted),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _section(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textMuted,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: items),
      ),
    ],
  );

  Widget _tile(
    IconData icon,
    String label, {
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AppFeatureIcon(
                icon: icon,
                color: AppColors.link,
                backgroundColor: AppColors.link.withValues(alpha: 0.08),
                size: 38,
                iconSize: 20,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      );

  void _showThemeModeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Consumer<ThemeModeController>(
          builder: (sheetContext, controller, _) {
            final colors = sheetContext.colors;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giao diện',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chọn cách ứng dụng dùng chế độ sáng hoặc tối trên thiết bị này.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final mode in AppThemePreference.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppFeatureIcon(
                        icon: switch (mode) {
                          AppThemePreference.system =>
                            Icons.brightness_auto_outlined,
                          AppThemePreference.light =>
                            Icons.light_mode_outlined,
                          AppThemePreference.dark => Icons.dark_mode_outlined,
                        },
                        color: AppColors.link,
                        backgroundColor:
                            AppColors.link.withValues(alpha: 0.08),
                        size: 38,
                        iconSize: 20,
                        radius: 12,
                      ),
                      title: Text(
                        mode.label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      trailing: controller.preference == mode
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.link,
                            )
                          : null,
                      onTap: () async {
                        await controller.setPreference(mode);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLeaveUnavailable(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Chưa thể rời gia đình',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ứng dụng đang chờ backend bổ sung API rời gia đình và thông báo cho các thành viên còn lại. Hiện tại chỉ Trưởng nhóm có thể xoá thành viên khỏi gia đình.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Đã hiểu',
              style: GoogleFonts.inter(
                color: AppColors.link,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
