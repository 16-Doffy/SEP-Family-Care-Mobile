import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/sos_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/task_provider.dart';
import '../wear_widgets.dart';
import 'wear_alerts_screen.dart';
import 'wear_calendar_screen.dart';
import 'wear_map_screen.dart';
import 'wear_notifications_screen.dart';
import 'wear_quick_message_screen.dart';
import 'wear_sensor_sos_screen.dart';
import 'wear_sos_screen.dart';
import 'wear_status_screen.dart';
import 'wear_tasks_screen.dart';

class WearHomeScreen extends StatefulWidget {
  const WearHomeScreen({super.key});

  @override
  State<WearHomeScreen> createState() => _WearHomeScreenState();
}

class _WearHomeScreenState extends State<WearHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
      context.read<GpsProvider>().fetchFamilyLocations();
      context.read<TaskProvider>().fetchMyAssignments();
      context.read<CalendarProvider>().fetchBootstrap(
        DateTime.now(),
        context.read<SubscriptionProvider>(),
      );
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final gps = context.watch<GpsProvider>();
    final tasks = context
        .watch<TaskProvider>()
        .myAssignments
        .where((a) => a.status != 'APPROVED' && a.status != 'CANCELED')
        .length;
    final events = context
        .watch<CalendarProvider>()
        .events
        .where((e) => e.startTime.isAfter(DateTime.now()))
        .length;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final myId = context.watch<AuthProvider>().user?.id;
    final othersInDanger = sos.activeAlerts
        .where((a) => !a.isMine(myId))
        .length;

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WearHeader(
            icon: Icons.favorite_rounded,
            label: 'FamilyCare',
            color: WearPalette.sosSoft,
          ),
          const SizedBox(height: 10),
          WearTile(
            icon: Icons.sos_rounded,
            title: sos.activeAlerts.isEmpty ? 'SOS' : 'SOS đang mở',
            subtitle: 'Giữ 2 giây để báo khẩn',
            color: WearPalette.sos,
            filled: true,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: WearPalette.muted,
            ),
            onTap: () => _open(const WearSosScreen()),
          ),
          // Cảnh báo của NGƯỜI KHÁC — chỉ hiện khi thực sự có, để menu không bị
          // dài thêm lúc bình thường. Đây là lối duy nhất trên đồng hồ để bấm
          // "Tôi đang đến" / đóng cảnh báo (UC51).
          if (othersInDanger > 0) ...[
            const SizedBox(height: 6),
            WearTile(
              icon: Icons.emergency_share_rounded,
              title: 'Người nhà cần giúp',
              subtitle: '$othersInDanger cảnh báo đang mở',
              color: WearPalette.sos,
              filled: true,
              onTap: () => _open(const WearAlertsScreen()),
            ),
          ],
          const SizedBox(height: 6),
          // SOS tự động từ cảm biến (té ngã, nhịp tim) — đi qua endpoint
          // wearable event theo spec Wear OS, khác với nút SOS thủ công ở trên.
          WearTile(
            icon: Icons.sensors_rounded,
            title: 'Cảm biến SOS',
            subtitle: 'Té ngã, nhịp tim bất thường',
            color: WearPalette.amber,
            onTap: () => _open(const WearSensorSosScreen()),
          ),
          const SizedBox(height: 12),
          const WearSectionLabel('Tác vụ nhanh'),
          WearTile(
            icon: Icons.location_on_rounded,
            title: 'Định vị',
            subtitle: gps.shares.isEmpty
                ? 'Bản đồ gia đình'
                : '${gps.shares.length} vị trí đang chia sẻ',
            color: WearPalette.blue,
            onTap: () => _open(const WearMapScreen()),
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: Icons.message_rounded,
            title: 'Tin nhắn',
            subtitle: 'Gửi trả lời nhanh',
            color: WearPalette.green,
            onTap: () => _open(const WearQuickMessageScreen()),
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: Icons.checklist_rounded,
            title: 'Task',
            subtitle: tasks == 0 ? 'Không còn việc' : '$tasks việc cần làm',
            color: WearPalette.amber,
            onTap: () => _open(const WearTasksScreen()),
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: Icons.calendar_month_rounded,
            title: 'Calendar',
            subtitle: events == 0 ? 'Không có lịch tới' : '$events sự kiện',
            color: WearPalette.violet,
            onTap: () => _open(const WearCalendarScreen()),
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: Icons.notifications_rounded,
            title: 'Notify',
            subtitle: unread == 0 ? 'Đã đọc hết' : '$unread chưa đọc',
            color: WearPalette.sosSoft,
            onTap: () => _open(const WearNotificationsScreen()),
          ),
          const SizedBox(height: 6),
          // Nơi DUY NHẤT trên đồng hồ có công tắc phát hiện té ngã và nút đăng
          // xuất — đừng gỡ tile này khỏi menu, màn sẽ thành code chết như trước.
          WearTile(
            icon: Icons.watch_rounded,
            title: 'Trạng thái',
            subtitle: 'Vị trí, phát hiện té ngã, đăng xuất',
            color: WearPalette.muted,
            onTap: () => _open(const WearStatusScreen()),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
