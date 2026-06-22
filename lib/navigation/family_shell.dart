import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sos_provider.dart';
import '../theme/app_colors.dart';

// Tab thường (không phải SOS) trong bottom nav.
class FamilyTab {
  final IconData icon;
  final String label;
  const FamilyTab({required this.icon, required this.label});
}

// Shell dùng chung cho cả 3 role (Manager/Deputy/Member) — khác biệt giữa
// role chỉ nằm ở danh sách tab + route đích (định nghĩa ở app_router.dart),
// không ảnh hưởng tới logic phân quyền (xem AppUser.canXxx trong
// lib/models/user.dart).
//
// Thứ tự 6 vị trí luôn cố định: 0 Trang chủ, 1-2 middleTabs[0..1], 3 SOS
// (nút tròn đỏ đặc biệt, giống nhau mọi role), 4 middleTabs[2], 5 Tôi.
class FamilyShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<FamilyTab> middleTabs; // đúng 3 phần tử: vị trí 1, 2, 4
  const FamilyShell({super.key, required this.navigationShell, required this.middleTabs});

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
    });
  }

  void _go(int index) {
    widget.navigationShell
        .goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = context.watch<SosProvider>().activeAlerts;
    final current = widget.navigationShell.currentIndex;

    return Scaffold(
      body: Column(children: [
        if (activeAlerts.isNotEmpty)
          GestureDetector(
            // Chuyển sang tab SOS (index 3) trong shell hiện tại — không
            // dùng context.go('/sos') vì route đó không tồn tại (mỗi role
            // có path riêng /manager|deputy|member/sos).
            onTap: () => _go(3),
            child: Container(
              width: double.infinity,
              color: AppColors.sos,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 8,
                left: 16,
                right: 16,
              ),
              child: Row(children: [
                const Text('🚨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeAlerts.length == 1
                        ? '${activeAlerts.first.senderName} cần trợ giúp khẩn cấp!'
                        : '${activeAlerts.length} cảnh báo SOS đang hoạt động!',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                Text('Xem ngay →',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ]),
            ),
          ),
        Expanded(child: widget.navigationShell),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(children: [
              _NavItem(icon: Icons.home_rounded, label: 'Trang chủ', index: 0, current: current, onTap: () => _go(0)),
              _NavItem(icon: widget.middleTabs[0].icon, label: widget.middleTabs[0].label, index: 1, current: current, onTap: () => _go(1)),
              _NavItem(icon: widget.middleTabs[1].icon, label: widget.middleTabs[1].label, index: 2, current: current, onTap: () => _go(2)),
              _SOSNavItem(hasAlert: activeAlerts.isNotEmpty, current: current, onTap: () => _go(3)),
              _NavItem(icon: widget.middleTabs[2].icon, label: widget.middleTabs[2].label, index: 4, current: current, onTap: () => _go(4)),
              _NavItem(icon: Icons.person_rounded, label: 'Tôi', index: 5, current: current, onTap: () => _go(5)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: active ? AppColors.link : AppColors.textMuted),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.link : AppColors.textMuted)),
        ]),
      ),
    );
  }
}

class _SOSNavItem extends StatelessWidget {
  final int current;
  final bool hasAlert;
  final VoidCallback onTap;
  const _SOSNavItem({required this.current, required this.hasAlert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.sos),
              alignment: Alignment.center,
              child: const Text('🚨', style: TextStyle(fontSize: 18)),
            ),
            if (hasAlert)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sos, width: 1.5),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          Text('SOS',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.sos)),
        ]),
      ),
    );
  }
}
