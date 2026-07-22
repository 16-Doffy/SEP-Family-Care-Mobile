import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/tab_option.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tab_config_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Tùy chỉnh thanh điều hướng — người dùng chọn mục cho 3 vị trí trống.
///
/// Vị trí Trang chủ / SOS / Tôi cố định, không cho đổi: SOS là tính năng an
/// toàn phải luôn ở đúng chỗ để bấm được theo phản xạ, Trang chủ và Tôi là
/// mỏ neo điều hướng.
class TabSettingsScreen extends StatelessWidget {
  const TabSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? UserRole.member;
    final config = context.watch<TabConfigProvider>();
    final tabs = config.tabsFor(role);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Thanh điều hướng',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.white,
        actions: [
          TextButton(
            onPressed: () => config.resetToDefault(role),
            child: const Text('Mặc định'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Tùy chỉnh thanh điều hướng',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn 3 mục bạn hay dùng nhất. Trang chủ, SOS và Tôi luôn cố định '
            'nên không thay đổi được.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _Preview(tabs: tabs, role: role),
          const SizedBox(height: 24),
          for (var slot = 0; slot < kCustomTabCount; slot++) ...[
            _SlotPicker(slot: slot, role: role, tabs: tabs),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// Xem trước thanh nav thật — để người dùng thấy ngay mục mình chọn nằm ở đâu,
/// thay vì phải thoát ra kiểm tra.
class _Preview extends StatelessWidget {
  const _Preview({required this.tabs, required this.role});

  final List<TabOption> tabs;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData? icon, String label, bool fixed})>[
      (icon: Icons.home_rounded, label: 'Trang chủ', fixed: true),
      (icon: tabs[0].icon, label: tabs[0].labelFor(role), fixed: false),
      (icon: tabs[1].icon, label: tabs[1].labelFor(role), fixed: false),
      (icon: null, label: 'SOS', fixed: true),
      (icon: tabs[2].icon, label: tabs[2].labelFor(role), fixed: false),
      (icon: Icons.person_rounded, label: 'Tôi', fixed: true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Column(
                children: [
                  if (item.icon == null)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sos,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.sos_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      item.icon,
                      size: 22,
                      color: item.fixed ? AppColors.textMuted : AppColors.link,
                    ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: item.fixed
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: item.fixed ? AppColors.textMuted : AppColors.link,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slot,
    required this.role,
    required this.tabs,
  });

  final int slot;
  final UserRole role;
  final List<TabOption> tabs;

  /// Vị trí hiển thị trên thanh nav (1-indexed cho người dùng dễ hiểu):
  /// slot 0→ô 2, slot 1→ô 3, slot 2→ô 5 (ô 4 là SOS).
  static const _positionLabel = ['Vị trí 2', 'Vị trí 3', 'Vị trí 5'];

  @override
  Widget build(BuildContext context) {
    final config = context.read<TabConfigProvider>();
    final selected = tabs[slot];
    final options = allowedTabsFor(role);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _positionLabel[slot],
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in options)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => config.setTabAt(role, slot, option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      option.icon,
                      size: 22,
                      color: option == selected
                          ? AppColors.link
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.labelFor(role),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            option.descriptionFor(role),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mục đang nằm ở vị trí khác: chọn sẽ HOÁN ĐỔI hai vị trí,
                    // nói trước để người dùng không bất ngờ vì ô kia đổi theo.
                    if (option == selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.link,
                      )
                    else if (tabs.contains(option))
                      Text(
                        'đang ở ${_positionLabel[tabs.indexOf(option)].toLowerCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
