import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'local_notification_service.dart';

/// Handler chạy trong **isolate riêng** khi app ở nền/đã tắt. Bắt buộc là
/// top-level function + @pragma('vm:entry-point') nếu không release build sẽ
/// tree-shake mất.
///
/// Mặc định (mọi loại trừ CALL): chỉ log — Android tự vẽ notification cho
/// message có khối `notification`, không cần FE làm gì thêm.
///
/// Riêng `referenceType=CALL` + `callEventType=incoming` (xem `API_DOCS.md`
/// mục Calls > Push): BE gửi **data-only message** (không có khối
/// `notification`) đúng cho mục đích này — Android không tự vẽ gì, FE tự
/// dựng notification `fullScreenIntent` để mở thẳng màn nhận cuộc gọi kể cả
/// lúc khoá máy/app đã bị kill hẳn. `WidgetsFlutterBinding.ensureInitialized()`
/// bắt buộc phải gọi trước khi dùng `flutter_local_notifications` từ isolate
/// nền này (isolate riêng, khác isolate chính của app).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Push(bg): Firebase init skipped/failed: $e');
  }

  final n = message.notification;
  debugPrint(
    'Push(bg): ${message.messageId} notification='
    '${n == null ? 'null' : '${n.title}|${n.body}'} data=${message.data}',
  );
  final type = (message.data['type'] ?? message.data['referenceType'] ?? '')
      .toString()
      .toUpperCase();
  final eventType = (message.data['callEventType'] ?? '')
      .toString()
      .toLowerCase();
  if (type != 'CALL' || eventType != 'incoming') return;

  final callId =
      message.data['callId']?.toString() ??
      message.data['referenceId']?.toString() ??
      '';
  if (callId.isEmpty) return;
  debugPrint('Push(bg): incoming CALL -> show full-screen callId=$callId');
  await LocalNotificationService.instance.showIncomingCall(
    callId: callId,
    callerName:
        message.data['callerName']?.toString() ??
        message.data['title']?.toString() ??
        'Thành viên',
  );
}

/// FCM push — kênh DUY NHẤT nhận được thông báo khi **app ở nền hoặc đã tắt**
/// (socket + poll + local notification chỉ chạy khi tiến trình còn sống).
///
/// Luồng: init Firebase → xin quyền → lấy token → `POST /devices/tokens`.
/// Khi logout gọi [unregister] để máy dùng chung không nhận push nhầm tài khoản.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  String? _token;
  bool _started = false;

  /// Điều hướng khi user bấm vào push (payload "referenceType|referenceId").
  void Function(String payload)? onTapPayload;

  static String _payloadOf(RemoteMessage m) =>
      '${m.data['referenceType'] ?? ''}|${m.data['referenceId'] ?? ''}';

  /// Gọi sau khi đăng nhập (đã có access token để POST /devices/tokens).
  Future<void> start() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;

      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push: người dùng từ chối quyền thông báo');
        return;
      }

      // App đang mở: FCM KHÔNG tự vẽ notification → tự bắn bằng local
      // notification để vẫn có chuông + khay như lúc ở nền.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        debugPrint(
          'Push(fg): ${m.messageId} notification='
          '${n == null ? 'null' : '${n.title}|${n.body}'} data=${m.data}',
        );
        final type = (m.data['type'] ?? m.data['referenceType'] ?? '')
            .toString()
            .toUpperCase();
        // Cuộc gọi đến lúc app đang mở: socket `call:incoming` (CallProvider,
        // xem family_shell.dart) đã tự mở IncomingCallScreen theo thời gian
        // thực, nhanh hơn hẳn push. Bắn thêm banner ở đây là thừa — chồng lên
        // đúng lúc màn cuộc gọi đến vừa mở, không phải lỗi nhưng gây rối mắt.
        if (type == 'CALL') return;
        final title = n?.title ?? m.data['title'] ?? 'Family Care';
        final body = n?.body ?? m.data['body'] ?? '';
        LocalNotificationService.instance.show(
          title: title,
          body: body,
          isSos: type == 'SOS',
          payload: _payloadOf(m),
        );
      });

      // Bấm vào push khi app ở nền → mở app rồi điều hướng.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => onTapPayload?.call(_payloadOf(m)),
      );
      // App đang TẮT HẲN, mở lên nhờ bấm push.
      final initial = await fm.getInitialMessage();
      if (initial != null) onTapPayload?.call(_payloadOf(initial));

      _token = await fm.getToken();
      if (_token != null) await _register(_token!);
      // Token có thể xoay vòng → đăng ký lại.
      fm.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      });

      _started = true;
      debugPrint('Push: sẵn sàng, token=${_token?.substring(0, 12)}…');
    } catch (e) {
      // Firebase lỗi (thiếu/sai google-services.json…) KHÔNG được làm chết app —
      // socket + poll + local notification vẫn chạy như cũ.
      debugPrint('Push: init thất bại (bỏ qua, dùng socket/poll): $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await ApiClient.instance.post('/devices/tokens', {
        'token': token,
        'platform': 'ANDROID',
        'deviceName': 'Android',
      });
      debugPrint('Push: đã đăng ký token với BE');
    } catch (e) {
      debugPrint('Push: đăng ký token thất bại: $e');
    }
  }

  /// Gọi khi logout — tránh nhận push của tài khoản cũ trên máy dùng chung.
  Future<void> unregister() async {
    final t = _token;
    _started = false;
    if (t == null) return;
    try {
      await ApiClient.instance.delete('/devices/tokens/$t');
    } catch (e) {
      debugPrint('Push: hủy token thất bại: $e');
    }
    _token = null;
  }
}
