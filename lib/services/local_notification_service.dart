import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Hiển thị **thông báo hệ thống** (khay thông báo + heads-up + chuông) cho
/// notification realtime nhận qua Socket.IO và cảnh báo SOS.
///
/// **Giới hạn quan trọng:** đây KHÔNG phải push. Nó chỉ chạy khi **tiến
/// trình app còn sống** (đang mở, hoặc vừa ẩn xuống nền). **App bị tắt hẳn thì
/// không nhận được gì** — muốn vậy phải có FCM (`firebase_messaging` +
/// `POST /devices/tokens`) — xem `PushService`.
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

  /// Cuộc gọi video đến — kênh riêng, `fullScreenIntent` để tự mở
  /// `IncomingCallScreen` đè lên màn khoá kể cả khi app đã bị kill hẳn (xem
  /// [showIncomingCall]). Tách kênh riêng SOS vì khác hẳn về vòng đời (cuộc
  /// gọi tự hết sau ~30s BE timeout, SOS không tự hết).
  static const _callChannel = AndroidNotificationChannel(
    'incoming_call',
    'Cuộc gọi video đến',
    description: 'Tự mở màn nhận cuộc gọi khi có người gọi video, kể cả lúc khoá máy.',
    importance: Importance.max,
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
      await android.createNotificationChannel(_callChannel);
      // Android 13+ bắt buộc xin quyền runtime POST_NOTIFICATIONS.
      await android.requestNotificationsPermission();
    }
    _ready = true;
    debugPrint('LocalNotif: sẵn sàng');

    // App bị kill hẳn, mở lên nhờ bấm/tự bung 1 local notification (vd cuộc
    // gọi đến full-screen-intent) — plugin chỉ vừa init() xong nên tap lúc
    // app chưa chạy sẽ KHÔNG tự bắn `onDidReceiveNotificationResponse`, phải
    // tự hỏi lại bằng API riêng. Cùng khuôn với `PushService.getInitialMessage()`.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.isNotEmpty) {
      onTapPayload?.call(payload);
    }
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

  /// ID cố định — cuộc gọi mới cùng lúc phải THAY THẾ noti cũ (giống điện
  /// thoại thật), không cộng dồn nhiều thông báo cuộc gọi chồng nhau như
  /// [show] (vốn dùng id xoay vòng vì có thể có nhiều thông báo thường cùng
  /// lúc).
  static const _incomingCallNotificationId = 9301;

  /// Cuộc gọi video đến, gọi được cả từ `firebaseBackgroundHandler` (isolate
  /// nền khi app đã kill hẳn) lẫn lúc app đang mở. `fullScreenIntent: true`
  /// để hệ thống tự mở app đè lên màn khoá — cùng cơ chế `SosAlertLauncher`
  /// đã dùng cho SOS (`setShowWhenLocked`/`setTurnScreenOn` ở
  /// `MainActivity.onCreate()` áp dụng chung, không cần sửa lại).
  ///
  /// Không tự build `Intent`/`PendingIntent` như `SosAlertLauncher` (đó là
  /// code Kotlin, không gọi được từ đây) — dựa vào cơ chế payload có sẵn của
  /// `flutter_local_notifications`: [payload] theo đúng khuôn
  /// `referenceType|referenceId` (`CALL|<callId>`) đã dùng cho mọi notification
  /// khác trong app, `_onNotificationTapPayload` ở `family_shell.dart` tự
  /// điều hướng qua `NotificationRouter` → `/incoming-call/:token?callId=...`
  /// (route đã có sẵn). `timeoutAfter` khớp `RINGING_TIMEOUT_MS` 30 giây phía
  /// BE — quá giờ đó cuộc gọi coi như nhỡ, không cần noti nằm lì thêm.
  ///
  /// ⚠️ **Chưa test trên máy Oppo thật** (khác các phần khác trong đợt 12/08,
  /// vốn đều đã gọi thật giữa 2 máy để xác nhận) — cần một cuộc gọi thật lúc
  /// app B đã bị kill hẳn để kiểm chứng `fullScreenIntent` + cold-start launch
  /// details hoạt động đúng, đặc biệt `AndroidNotificationCategory.call` có
  /// gây thanh lạ/vỡ hình trên ROM ColorOS hay không (xem cảnh báo tương tự
  /// đã gặp với `CATEGORY_CALL` + foreground service ở `CallGuardService.kt`
  /// — tình huống ở đây khác, chưa có foreground service `camera|microphone`
  /// nào chạy lúc noti này bắn ra, nhưng vẫn nên đo lại chứ không suy luận).
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
  }) async {
    if (!_ready) await init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _callChannel.id,
        _callChannel.name,
        channelDescription: _callChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: true,
        timeoutAfter: 30000,
        color: const Color(0xFFDC2626),
      ),
    );
    try {
      await _plugin.show(
        id: _incomingCallNotificationId,
        title: callerName,
        body: 'Cuộc gọi video đến',
        notificationDetails: details,
        payload: 'CALL|$callId',
      );
    } catch (e) {
      debugPrint('LocalNotif: showIncomingCall thất bại: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
