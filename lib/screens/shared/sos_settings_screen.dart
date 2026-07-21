import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';

/// Cài đặt SOS của gia đình — 4 công tắc khớp UpdateSosSettingsDto.
///
/// Chỉ Manager/Deputy được đổi (config cấp gia đình, cùng nhóm quyền với
/// canResolveSos). Member xem read-only kèm ghi chú.
class SosSettingsScreen extends StatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  State<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends State<SosSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SosProvider>().fetchSettings();
    });
  }

  Future<void> _toggle(SosSettings next) async {
    try {
      await context.read<SosProvider>().updateSettings(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không lưu được cài đặt: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final s = sos.settings ?? const SosSettings();
    final canEdit = context.watch<AuthProvider>().user?.canResolveSos ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Cài đặt SOS',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: sos.settingsLoading && sos.settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!canEdit)
                  _note(
                    'Chỉ Trưởng nhóm hoặc Phó nhóm mới thay đổi được cài đặt '
                    'SOS. Bạn đang xem ở chế độ chỉ đọc.',
                  ),
                _tile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Bật SOS',
                  subtitle: 'Cho phép gửi cảnh báo khẩn cấp trong gia đình.',
                  value: s.isEnabled,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(isEnabled: v))
                      : null,
                ),
                _tile(
                  icon: Icons.groups_rounded,
                  title: 'Báo cho tất cả thành viên',
                  subtitle:
                      'Khi có SOS, gửi thông báo tới mọi người trong nhà.',
                  value: s.notifyAllMembers,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(notifyAllMembers: v))
                      : null,
                ),
                _tile(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Tự cảnh báo khi phát hiện té ngã',
                  subtitle:
                      'Tự động tạo cảnh báo SOS khi thiết bị nhận thấy cú ngã.',
                  value: s.autoCreateAlertFromFall,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(autoCreateAlertFromFall: v))
                      : null,
                ),
                _tile(
                  icon: Icons.location_on_rounded,
                  title: 'Bắt buộc chia sẻ vị trí',
                  subtitle:
                      'Yêu cầu đính kèm vị trí khi gửi SOS để người nhà tìm nhanh.',
                  value: s.locationRequired,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(locationRequired: v))
                      : null,
                ),
              ],
            ),
    );
  }

  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
    ),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: Icon(icon, color: AppColors.sos),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
      ),
      value: value,
      onChanged: onChanged,
    ),
  );
}
