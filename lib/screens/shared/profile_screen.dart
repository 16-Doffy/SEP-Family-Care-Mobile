import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  AvatarWidget(initial: user?.avatarInitials ?? 'BA', color: Color(user?.avatarColor ?? AppColors.avatarBlue.toARGB32()), size: 80),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'Ba Nguyễn', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Gia đình ${user?.familyName ?? "Nguyễn"}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.link.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text(_getRoleName(user?.role), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _section('Tài khoản', [
              _tile('👤', 'Chỉnh sửa hồ sơ',
                  onTap: () => context.push('/profile/edit')),
              _tile('🔒', 'Bảo mật', onTap: () {}),
              _tile('🔔', 'Thông báo', onTap: () {}),
            ]),
            const SizedBox(height: 16),

            _section('Gia đình', [
              _tile('👥', 'Mời thành viên',
                  onTap: () => context.push('/manager/invite')),
              _tile('⚙️', 'Gói đăng ký',
                  onTap: () => context.push('/manager/subscription')),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: auth.logout,
                child: Text('Đăng xuất', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getRoleName(UserRole? role) {
    if (role == null) return 'KHÁCH';
    switch (role) {
      case UserRole.manager: return 'TRƯỞNG NHÓM';
      case UserRole.deputy: return 'PHÓ NHÓM';
      case UserRole.member: return 'THÀNH VIÊN';
    }
  }

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
        Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _tile(String icon, String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
