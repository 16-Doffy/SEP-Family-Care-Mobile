import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/sos_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'notification_router.dart';

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
  const FamilyShell({
    super.key,
    required this.navigationShell,
    required this.middleTabs,
  });

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> with WidgetsBindingObserver {
  // BE chưa có push/websocket — poll nhẹ ở tầng shell (sống suốt phiên đăng
  // nhập, mọi tab) để banner SOS + chuông thông báo cập nhật trên các thiết bị
  // khác khi app đang mở. Dừng khi app xuống nền cho đỡ pin/băng thông, và
  // fetch lại NGAY khi quay lại foreground để không phải chờ hết 1 chu kỳ.
  static const _kPollInterval = Duration(seconds: 15);
  Timer? _pollTimer;
  bool _verificationDialogOpen = false;
  NotificationProvider? _notif; // giữ ref để dùng trong dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiClient.instance.onVerificationRequired = _showVerificationRequired;
      // Realtime notification (Socket.IO /notifications) — REST poll bên dưới
      // vẫn giữ làm fallback nếu socket rớt. Toast cho push-only (id null).
      _notif = context.read<NotificationProvider>()
        ..onTransient = _showTransientNotif;
      _notif!.fetchUnreadCount();
      _notif!.startRealtime();
      _refreshLive();
      _startPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    if (ApiClient.instance.onVerificationRequired ==
        _showVerificationRequired) {
      ApiClient.instance.onVerificationRequired = null;
    }
    if (_notif?.onTransient == _showTransientNotif) {
      _notif!.onTransient = null;
    }
    _notif?.stopRealtime();
    super.dispose();
  }

  // Toast in-app cho notification realtime (persisted + push-only). Nút "Xem"
  // điều hướng theo NotificationRouter (role-aware).
  void _showTransientNotif(AppNotification n) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final role = context.read<AuthProvider>().user?.role;
    final path = role == null
        ? null
        : NotificationRouter.routeFor(
            referenceType: n.referenceType,
            referenceId: n.referenceId,
            role: role,
          );
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      backgroundColor: const Color(0xFF111827),
      content: Text(
        '${n.emoji}  ${n.title}${n.body.isNotEmpty ? ' — ${n.body}' : ''}',
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      action: path == null
          ? null
          : SnackBarAction(
              label: 'Xem',
              textColor: Colors.white,
              onPressed: () {
                if (!mounted) return;
                // Shell-branch → go (đổi tab); push sẽ nhân đôi shell →
                // crash trùng GlobalKey. Xem NotificationRouter.isShellBranch.
                if (NotificationRouter.isShellBranch(path)) {
                  context.go(path);
                } else {
                  context.push(path);
                }
              },
            ),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLive();
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _refreshLive());
  }

  void _refreshLive() {
    if (!mounted) return;
    context.read<SosProvider>().fetchAlerts();
    context.read<NotificationProvider>().fetchNotifications();
  }

  Future<void> _showVerificationRequired(String message) async {
    if (!mounted || _verificationDialogOpen) return;
    final currentUri = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.toString();
    _verificationDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tài khoản chưa xác thực',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bạn cần xác thực email để dùng tính năng này.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Để sau',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push(
                '/verify-email?returnTo=${Uri.encodeComponent(currentUri)}',
              );
            },
            child: Text(
              'Xác thực ngay',
              style: GoogleFonts.inter(
                color: AppColors.link,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    _verificationDialogOpen = false;
  }

  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = context.watch<SosProvider>().activeAlerts;
    final current = widget.navigationShell.currentIndex;

    return Scaffold(
      body: Column(
        children: [
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
                child: Row(
                  children: [
                    const Text('🚨', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        // Người PHÁT cảnh báo không được nhận thông điệp
                        // "X cần trợ giúp" về chính mình.
                        activeAlerts.length == 1
                            ? (activeAlerts.first.isMine(
                                    context.read<AuthProvider>().user?.id)
                                ? 'Bạn đang phát cảnh báo SOS — chạm để xác nhận an toàn'
                                : '${activeAlerts.first.senderName} cần trợ giúp khẩn cấp!')
                            : '${activeAlerts.length} cảnh báo SOS đang hoạt động!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      'Xem ngay →',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                  current: current,
                  onTap: () => _go(0),
                ),
                _NavItem(
                  icon: widget.middleTabs[0].icon,
                  label: widget.middleTabs[0].label,
                  index: 1,
                  current: current,
                  onTap: () => _go(1),
                ),
                _NavItem(
                  icon: widget.middleTabs[1].icon,
                  label: widget.middleTabs[1].label,
                  index: 2,
                  current: current,
                  onTap: () => _go(2),
                ),
                _SOSNavItem(
                  hasAlert: activeAlerts.isNotEmpty,
                  current: current,
                  onTap: () => _go(3),
                ),
                _NavItem(
                  icon: widget.middleTabs[2].icon,
                  label: widget.middleTabs[2].label,
                  index: 4,
                  current: current,
                  onTap: () => _go(4),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Tôi',
                  index: 5,
                  current: current,
                  onTap: () => _go(5),
                ),
              ],
            ),
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
  final bool hasAlert;
  final VoidCallback onTap;
  const _SOSNavItem({
    required this.current,
    required this.hasAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sos,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚨', style: TextStyle(fontSize: 18)),
                ),
                if (hasAlert)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.sos, width: 1.5),
                      ),
                    ),
                  ),
              ],
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
