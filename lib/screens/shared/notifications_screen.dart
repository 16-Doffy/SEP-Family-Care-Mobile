import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../navigation/notification_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/app_feature_icon.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  void _onTapNotification(BuildContext context, AppNotification n) {
    context.read<NotificationProvider>().markRead(n.id);
    final role = context.read<AuthProvider>().user?.role;
    if (role == null) return;
    // Điều hướng theo referenceType/referenceId (chuẩn hợp đồng WS); lạ/null
    // → NotificationRouter trả null → ở lại màn danh sách, không crash.
    final path = NotificationRouter.routeFor(
      referenceType: n.referenceType,
      referenceId: n.referenceId,
      role: role,
    );
    if (path == null) return;
    // Shell-branch → go (đổi tab). Push shell-branch sẽ nhân đôi shell và
    // crash Navigator do trùng GlobalKey của nhánh.
    if (NotificationRouter.isShellBranch(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifs = provider.notifications;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textPrimary),
                ),
              ),
              Expanded(child: Center(child: Text('Thông báo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.textPrimary)))),
              if (provider.unreadCount > 0)
                GestureDetector(
                  onTap: () => provider.markAllRead(),
                  child: Container(
                    width: 40, height: 40, alignment: Alignment.center,
                    child: const Icon(Icons.done_all_rounded, size: 20, color: AppColors.link),
                  ),
                )
              else
                const SizedBox(width: 40),
            ]),
          ),

          if (provider.loading && notifs.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error != null && notifs.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Lỗi tải dữ liệu', style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => provider.fetchNotifications(), child: const Text('Thử lại')),
                ]),
              ),
            )
          else if (notifs.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const AppFeatureIcon(
                    icon: Icons.notifications_none_rounded,
                    color: AppColors.primary500,
                    size: 64,
                    iconSize: 32,
                    radius: 20,
                  ),
                  const SizedBox(height: 8),
                  Text('Chưa có thông báo nào', style: GoogleFonts.inter(fontSize: 14, color: context.colors.textMuted)),
                ]),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchNotifications(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: notifs.length,
                  itemBuilder: (_, i) => _notifCard(context, notifs[i]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _notifCard(BuildContext context, AppNotification n) {
    return GestureDetector(
      onTap: () => _onTapNotification(context, n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? context.colors.surface : n.accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          AppFeatureIcon(
            icon: _notificationIcon(n.type),
            color: n.accentColor,
            backgroundColor: n.accentColor.withValues(alpha: 0.12),
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary))),
                if (!n.isRead)
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: n.accentColor, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 2),
              Text(n.body, style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(_fmtTime(n.createdAt), style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted)),
        ]),
      ),
    );
  }

  IconData _notificationIcon(String type) => switch (type) {
    'SOS' => Icons.sos_rounded,
    'TASK' => Icons.task_alt_rounded,
    'FINANCE' => Icons.account_balance_wallet_outlined,
    'INVITATION' || 'JOIN_REQUEST' => Icons.mail_outline_rounded,
    'MEMBER' || 'MEMBER_LEFT' => Icons.person_outline_rounded,
    'ALBUM_TAG' => Icons.photo_library_outlined,
    'CALENDAR' => Icons.calendar_month_outlined,
    'CHAT' => Icons.chat_bubble_outline_rounded,
    _ => Icons.notifications_none_rounded,
  };
}
