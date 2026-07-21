import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gia đình ${user?.familyName ?? ""}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMuted,
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
                color: AppColors.white,
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
                    const Divider(height: 16, color: Color(0xFFF3F4F6)),
                    _infoRow(Icons.phone_outlined, 'Điện thoại', user.phone!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tài khoản ─────────────────────────────────────────────
            _section('Tài khoản', [
              _tile(
                '👤',
                'Chỉnh sửa hồ sơ',
                onTap: () => context.push('/profile/edit'),
              ),
              _tile(
                '📋',
                'Tài chính tháng của tôi',
                onTap: () => context.push('/profile/edit'),
              ),
              _tile(
                '🔒',
                'Bảo mật',
                onTap: () => context.push('/profile/change-password'),
              ),
              _tile('🔔', 'Thông báo', onTap: () {}),
              // Mọi role đều tùy chỉnh được — cấu hình lưu riêng theo role.
              _tile(
                '🧭',
                'Thanh điều hướng',
                onTap: () => context.push('/settings/tabs'),
              ),
              // Quản lý thiết bị đeo (đồng hồ/định vị). Mọi role vào được;
              // ghép/gỡ chỉ Manager/Deputy (gate trong màn).
              _tile(
                '⌚',
                'Thiết bị đeo',
                onTap: () => context.push('/wearables'),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Gia đình — theo role ──────────────────────────────────
            _section('Gia đình', [
              if (isManager) ...[
                _tile(
                  '👥',
                  'Thành viên gia đình',
                  onTap: () => context.push('/manager/members'),
                ),
                if (user?.canInviteMembers ?? false) ...[
                  _tile(
                    '✉️',
                    'Mời thành viên',
                    onTap: () => context.push('/manager/invite'),
                  ),
                  _tile(
                    '🙋',
                    'Duyệt yêu cầu tham gia',
                    onTap: () => context.push('/manager/invite-requests'),
                  ),
                ],
                if (user?.canManageSubscription ?? false)
                  _tile(
                    '💳',
                    'Gói đăng ký',
                    onTap: () => context.push('/manager/subscription'),
                  ),
                _tile(
                  '🏦',
                  'Mô hình tài chính',
                  onTap: () => context.push('/manager/finance-model'),
                ),
                _tile(
                  '🫙',
                  'Kế hoạch ngân sách',
                  onTap: () => context.push('/manager/budget-plans'),
                ),
                _tile(
                  '🎯',
                  'Mục tiêu tiết kiệm',
                  onTap: () => context.push('/manager/financial-goals'),
                ),
                _tile(
                  '🔔',
                  'Cảnh báo tài chính',
                  onTap: () => context.push('/manager/finance-alerts'),
                ),
                _tile(
                  '📊',
                  'Báo cáo tài chính',
                  onTap: () => context.push('/manager/finance-reports'),
                ),
                _tile(
                  '📬',
                  'Yêu cầu hỗ trợ chi tiêu',
                  onTap: () => context.push('/finance/support-requests'),
                ),
                _tile(
                  '🗺️',
                  'Bản đồ gia đình',
                  onTap: () => context.push('/map'),
                ),
                // Manager đã có tab Album ở bottom nav — chỉ Deputy cần lối này
                if (user?.role == UserRole.deputy)
                  _tile(
                    '🖼️',
                    'Album gia đình',
                    onTap: () => context.push('/album'),
                  ),
                if (user?.role == UserRole.deputy)
                  _tile(
                    '🚪',
                    'Rời gia đình',
                    onTap: () => _showLeaveUnavailable(context),
                  ),
              ] else if (isMember) ...[
                _tile(
                  '👨‍👩‍👧‍👦',
                  'Xem thành viên gia đình',
                  onTap: () => context.push('/manager/members'),
                ),
                _tile(
                  '🖼️',
                  'Album gia đình',
                  onTap: () => context.push('/album'),
                ),
                _tile(
                  '🙋',
                  'Yêu cầu hỗ trợ chi tiêu',
                  onTap: () => context.push('/finance/support-requests'),
                ),
                _tile(
                  '🗺️',
                  'Bản đồ gia đình',
                  onTap: () => context.push('/map'),
                ),
                _tile(
                  '🚪',
                  'Rời gia đình',
                  onTap: () => _showLeaveUnavailable(context),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            _section('Khác', [
              _tile('❓', 'Trợ giúp & FAQ', onTap: () {}),
              _tile('📋', 'Điều khoản sử dụng', onTap: () {}),
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
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
            color: AppColors.textMuted,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.white,
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

  Widget _tile(String icon, String label, {required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      );

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
