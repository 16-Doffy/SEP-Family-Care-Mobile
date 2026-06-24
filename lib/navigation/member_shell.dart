import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class MemberShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MemberShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  index: 0,
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 0),
                ),
                _NavItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Nhiệm vụ',
                  index: 1,
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 1),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Sổ chi',
                  index: 2,
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 2),
                ),
                _SOSNavItem(
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 3),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  index: 4,
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 4),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Tôi',
                  index: 5,
                  current: navigationShell.currentIndex,
                  onTap: () => _go(context, 5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? AppColors.link : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.link : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SOSNavItem extends StatelessWidget {
  final int current;
  final VoidCallback onTap;

  const _SOSNavItem({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sos,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.emergency_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SOS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.sos,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
