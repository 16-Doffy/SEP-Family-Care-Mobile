import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Hiển thị **thông báo hệ thống** (khay thông báo + heads-up + chuông) cho
/// notification realtime nhận qua Socket.IO và cảnh báo SOS.
///
/// **Giới hạn quan trọng:** đây KHÔNG phải push. Nó chỉ chạy khi **tiến
/// trình app còn sống** (đang mở, hoặc vừa ẩn xuống nền). **App bị tắt hẳn thì
/// không nhận được gì** — muốn vậy phải có FCM (`firebase_messaging` +
/// `POST /devices/tokens`), xem KE_HOACH_NOTIFICATIONS_REALTIME.md.
///
/// Dùng 2 channel để SOS nổi bật hơn thông báo thường (Android cho phép user
/// chỉnh riêng từng channel).
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _sosChannel = AndroidNotificationChannel(
    'sos_alerts',
    'Cảnh báo khẩn cấp (SOS)',
    description: 'Thông báo khi thành viên trong gia đình phát cảnh báo SOS.',
    importance: Importance.max,
  );

  static const _generalChannel = AndroidNotificationChannel(
    'general_notifications',
    'Thông báo chung',
    description: 'Nhiệm vụ, tài chính, ảnh, yêu cầu tham gia, chat…',
    importance: Importance.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  /// Bấm vào notification → trả payload (referenceType|referenceId) cho app
  /// điều hướng qua NotificationRouter.
  void Function(String payload)? onTapPayload;

  Future<void> init() async {
    if (_ready) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (res) {
        final p = res.payload;
        if (p != null && p.isNotEmpty) onTapPayload?.call(p);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // Tạo channel trước — nếu không Android báo "app does not send
      // notifications" và mục cài đặt thông báo trống trơn.
      await android.createNotificationChannel(_sosChannel);
      await android.createNotificationChannel(_generalChannel);
      // Android 13+ bắt buộc xin quyền runtime POST_NOTIFICATIONS.
      await android.requestNotificationsPermission();
    }
    _ready = true;
    debugPrint('LocalNotif: sẵn sàng');
  }

  Future<void> show({
    required String title,
    required String body,
    bool isSos = false,
    String? payload,
    int? badgeNumber,
  }) async {
    if (!_ready) await init();
    final channel = isSos ? _sosChannel : _generalChannel;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: isSos ? Importance.max : Importance.high,
        priority: isSos ? Priority.max : Priority.high,
        category: isSos
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.message,
        // Một số launcher (Samsung/Xiaomi...) dùng `number` để hiện badge số.
        // Pixel Launcher chỉ hiện notification dot dù app có truyền giá trị.
        number: badgeNumber,
        color: const Color(0xFFDC2626),
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    _id = (_id + 1) % 100000;
    try {
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('LocalNotif: show thất bại: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
