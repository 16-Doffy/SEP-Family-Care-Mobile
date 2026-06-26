import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';

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

  // Route theo role hiện tại — mỗi role có prefix riêng (/manager, /deputy,
  // /member) trong family_shell.dart, không dùng chung 1 path cố định.
  String _rolePrefix(UserRole role) => switch (role) {
        UserRole.manager => '/manager',
        UserRole.deputy  => '/deputy',
        UserRole.member  => '/member',
      };

  void _onTapNotification(BuildContext context, AppNotification n) {
    context.read<NotificationProvider>().markRead(n.id);
    final role = context.read<AuthProvider>().user?.role;
    if (role == null) return;
    final prefix = _rolePrefix(role);
    final path = switch (n.type) {
      'SOS'     => '$prefix/sos',
      'TASK'    => '$prefix/tasks',
      'FINANCE' => '$prefix/wallet',
      _         => null,
    };
    if (path != null) context.push(path);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(child: Center(child: Text('Thông báo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
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
                  const Text('🔔', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('Chưa có thông báo nào', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
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
          color: n.isRead ? AppColors.white : n.accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Text(n.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                if (!n.isRead)
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: n.accentColor, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 2),
              Text(n.body, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(_fmtTime(n.createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
