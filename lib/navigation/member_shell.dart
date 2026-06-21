import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sos_provider.dart';
import '../theme/app_colors.dart';

class MemberShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MemberShell({super.key, required this.navigationShell});
  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
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

    return Scaffold(
      body: Column(children: [
        // ── Global SOS banner (thành viên khác đang kêu cứu) ──────────────
        if (activeAlerts.isNotEmpty)
          GestureDetector(
            onTap: () => context.go('/sos'),
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
              _NavItem(icon: Icons.home_rounded, label: 'Trang chủ', index: 0, current: widget.navigationShell.currentIndex, onTap: () => _go(0)),
              _NavItem(icon: Icons.task_alt_rounded, label: 'Nhiệm vụ', index: 1, current: widget.navigationShell.currentIndex, onTap: () => _go(1)),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Ví', index: 2, current: widget.navigationShell.currentIndex, onTap: () => _go(2)),
              _SOSNavItem(
                hasAlert: activeAlerts.isNotEmpty,
                current: widget.navigationShell.currentIndex,
                onTap: () => _go(3),
              ),
              _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat', index: 4, current: widget.navigationShell.currentIndex, onTap: () => _go(4)),
              _NavItem(icon: Icons.person_rounded, label: 'Tôi', index: 5, current: widget.navigationShell.currentIndex, onTap: () => _go(5)),
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
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.sos),
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
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sos)),
        ]),
      ),
    );
  }
}
