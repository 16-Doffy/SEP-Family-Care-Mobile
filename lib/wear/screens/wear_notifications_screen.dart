import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../wear_widgets.dart';

class WearNotificationsScreen extends StatefulWidget {
  const WearNotificationsScreen({super.key});

  @override
  State<WearNotificationsScreen> createState() =>
      _WearNotificationsScreenState();
}

class _WearNotificationsScreenState extends State<WearNotificationsScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<NotificationProvider>().fetchNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = [...provider.notifications]
      ..sort((a, b) {
        if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.notifications_rounded,
            label: 'Notify',
            color: WearPalette.sosSoft,
            trailing: provider.loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.sosSoft,
                    ),
                  )
                : Text(
                    '${provider.unreadCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: WearPalette.sosSoft,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (_error != null || provider.error != null) ...[
            Text(
              _error ?? provider.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 6),
          ],
          if (provider.loading && items.isEmpty)
            const WearEmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang tải thông báo',
              color: WearPalette.sosSoft,
            )
          else if (items.isEmpty)
            const WearEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Chưa có thông báo',
              color: WearPalette.green,
            )
          else
            ...items
                .take(8)
                .map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: WearTile(
                      icon: _icon(n.type),
                      title: n.title.isEmpty ? n.type : n.title,
                      subtitle: n.body.isEmpty ? _ago(n.createdAt) : n.body,
                      color: _color(n),
                      filled: !n.isRead,
                      trailing: n.isRead
                          ? null
                          : const Icon(
                              Icons.circle,
                              size: 9,
                              color: WearPalette.sosSoft,
                            ),
                      onTap: n.isRead ? null : () => _markRead(provider, n.id),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _markRead(NotificationProvider provider, String id) async {
    if (id.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _error = null);
    try {
      await provider.markRead(id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  IconData _icon(String type) => switch (type) {
    'SOS' => Icons.sos_rounded,
    'TASK' => Icons.checklist_rounded,
    'CALENDAR' => Icons.calendar_month_rounded,
    'CHAT' || 'MESSAGE' => Icons.message_rounded,
    _ => Icons.notifications_rounded,
  };

  Color _color(AppNotification n) => switch (n.priority) {
    'CRITICAL' || 'HIGH' => WearPalette.sosSoft,
    'LOW' => WearPalette.faint,
    _ => WearPalette.blue,
  };

  String _ago(DateTime time) {
    final delta = DateTime.now().difference(time.toLocal());
    if (delta.inMinutes < 1) return 'vừa xong';
    if (delta.inMinutes < 60) return '${delta.inMinutes} phút trước';
    if (delta.inHours < 24) return '${delta.inHours} giờ trước';
    return '${delta.inDays} ngày trước';
  }
}
