import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/tab_option.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/sos_provider.dart';
import '../providers/tab_config_provider.dart';
import '../services/api_client.dart';
import '../services/local_notification_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import 'notification_router.dart';

// Shell dùng chung cho cả 3 role (Manager/Deputy/Member). Mỗi role khai đủ 9
// branch (xem kShellBranchOrder trong models/tab_option.dart) vì
// StatefulShellRoute.indexedStack cố định branch lúc dựng router.
//
// Thanh nav luôn 6 ô, thứ tự cố định và người dùng KHÔNG đổi được:
//   0 Trang chủ │ 1 tùy chọn │ 2 tùy chọn │ 3 SOS │ 4 tùy chọn │ 5 Tôi
// Ba ô tùy chọn ánh xạ sang branch nào là do TabConfigProvider quyết định.
class FamilyShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const FamilyShell({super.key, required this.navigationShell});

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> with WidgetsBindingObserver {
  // BE chưa có push/websocket — poll nhẹ ở tầng shell (sống suốt phiên đăng
  // nhập, mọi tab) để banner SOS + chuông thông báo cập nhật trên các thiết bị
  // khác khi app đang mở. Dừng khi app xuống nền cho đỡ pin/băng thông, và
  // fetch lại NGAY khi quay lại foreground để không phải chờ hết 1 chu kỳ.
  static const _kPollInterval = Duration(seconds: 15);
  // Ở nền vẫn poll (để SOS nổ được khi user đang ở app khác), chỉ giãn chu kỳ.
  static const _kPollIntervalBackground = Duration(seconds: 30);
  Timer? _pollTimer;
  bool _verificationDialogOpen = false;
  NotificationProvider? _notif; // giữ ref để dùng trong dispose
  // id các cảnh báo SOS đã bắn notification hệ thống — tránh poll 15s bắn lại
  // cùng một cảnh báo mỗi chu kỳ.
  final Set<String> _notifiedSosIds = {};
  bool _sosSeeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiClient.instance.onVerificationRequired = _showVerificationRequired;
      // Notification hệ thống (khay + chuông). Chỉ chạy khi tiến trình app còn
      // sống — app tắt hẳn vẫn cần FCM, xem KE_HOACH_NOTIFICATIONS_REALTIME.md.
      LocalNotificationService.instance
        ..onTapPayload = _onNotificationTapPayload
        ..init();
      // FCM push — kênh duy nhất nhận được khi app ở nền/đã tắt. Đã đăng nhập
      // tới đây nên gọi POST /devices/tokens được ngay.
      PushService.instance
        ..onTapPayload = _onNotificationTapPayload
        ..start();
      // Realtime notification (Socket.IO /notifications) — REST poll bên dưới
      // vẫn giữ làm fallback nếu socket rớt. Toast cho push-only (id null).
      _notif = context.read<NotificationProvider>()
        ..onTransient = _showTransientNotif;
      _notif!.fetchUnreadCount();
      _notif!.startRealtime();
      // Cấu hình thanh nav nằm trong secure storage → đọc bất đồng bộ. Chưa
      // đọc xong thì tabsFor() trả mặc định của role, nên thanh nav vẫn dựng
      // được ngay, không chờ.
      final role = context.read<AuthProvider>().user?.role;
      if (role != null) context.read<TabConfigProvider>().load(role);
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
    // Bắn ra khay hệ thống (kêu + heads-up kể cả khi user đang ở app khác,
    // miễn tiến trình còn sống).
    LocalNotificationService.instance.show(
      title: '${n.emoji} ${n.title}',
      body: n.body,
      isSos: n.type == 'SOS',
      payload: '${n.referenceType ?? ''}|${n.referenceId ?? ''}',
    );
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
    messenger.showSnackBar(
      SnackBar(
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
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _refreshLive();
        _startPolling(background: false);
      case AppLifecycleState.detached:
        // App đang bị hủy → dừng hẳn.
        _pollTimer?.cancel();
      default:
        // ⚠️ KHÔNG dừng poll khi xuống nền. Đây là app an toàn: cảnh báo SOS
        // phải nổ được lúc người dùng đang ở app khác. Trước đây hủy timer ở
        // đây nên notification chỉ hiện khi mở lại app.
        // Giãn chu kỳ để đỡ pin/băng thông.
        _startPolling(background: true);
    }
  }

  void _startPolling({bool background = false}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      background ? _kPollIntervalBackground : _kPollInterval,
      (_) => _refreshLive(),
    );
  }

  void _refreshLive() {
    if (!mounted) return;
    context.read<SosProvider>().fetchAlerts().then((_) => _notifyNewSos());
    context.read<NotificationProvider>().fetchNotifications();
  }

  // Bắn notification hệ thống cho cảnh báo SOS MỚI của người khác.
  void _notifyNewSos() {
    if (!mounted) return;
    final alerts = context.read<SosProvider>().activeAlerts;
    final myId = context.read<AuthProvider>().user?.id;
    // Lần fetch đầu: chỉ ghi nhận cảnh báo đang có, KHÔNG bắn — tránh spam
    // thông báo cũ ngay khi vừa mở app.
    if (!_sosSeeded) {
      _sosSeeded = true;
      _notifiedSosIds.addAll(alerts.map((a) => a.id));
      return;
    }
    for (final a in alerts) {
      if (a.id.isEmpty || _notifiedSosIds.contains(a.id)) continue;
      _notifiedSosIds.add(a.id);
      if (a.isMine(myId)) continue; // không tự báo cảnh báo của chính mình
      LocalNotificationService.instance.show(
        title: '🚨 ${a.senderName} cần trợ giúp khẩn cấp!',
        body: a.message.isNotEmpty ? a.message : 'Cảnh báo SOS từ gia đình',
        isSos: true,
        payload: 'SOS_ALERT|${a.id}',
      );
    }
  }

  // Payload dạng "referenceType|referenceId" → điều hướng như tap noti in-app.
  void _onNotificationTapPayload(String payload) {
    if (!mounted) return;
    final parts = payload.split('|');
    final role = context.read<AuthProvider>().user?.role;
    if (role == null) return;
    final path = NotificationRouter.routeFor(
      referenceType: parts.isNotEmpty ? parts[0] : null,
      referenceId: parts.length > 1 ? parts[1] : null,
      role: role,
    );
    if (path == null) return;
    if (NotificationRouter.isShellBranch(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
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

  Widget _tabItem(TabOption option, UserRole role, int current) => _NavItem(
    icon: option.icon,
    label: option.labelFor(role),
    index: option.branchIndex,
    current: current,
    onTap: () => _go(option.branchIndex),
  );

  @override
  Widget build(BuildContext context) {
    final activeAlerts = context.watch<SosProvider>().activeAlerts;
    final current = widget.navigationShell.currentIndex;
    final role = context.watch<AuthProvider>().user?.role ?? UserRole.member;
    final tabs = context.watch<TabConfigProvider>().tabsFor(role);

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
                    const Icon(
                      Icons.sos_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        // Người PHÁT cảnh báo không được nhận thông điệp
                        // "X cần trợ giúp" về chính mình.
                        activeAlerts.length == 1
                            ? (activeAlerts.first.isMine(
                                    context.read<AuthProvider>().user?.id,
                                  )
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
                  index: kHomeBranchIndex,
                  current: current,
                  onTap: () => _go(kHomeBranchIndex),
                ),
                _tabItem(tabs[0], role, current),
                _tabItem(tabs[1], role, current),
                _SOSNavItem(
                  hasAlert: activeAlerts.isNotEmpty,
                  current: current,
                  onTap: () => _go(kSosBranchIndex),
                ),
                _tabItem(tabs[2], role, current),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Tôi',
                  index: kProfileBranchIndex,
                  current: current,
                  onTap: () => _go(kProfileBranchIndex),
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
                  child: const Icon(
                    Icons.sos_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
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
