import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cầu nối đọc nhịp tim THẬT trên đồng hồ Wear OS qua Health Services API
/// (native: `WearHeartRateBridge.kt` + `MainActivity.kt`). Chỉ hoạt động
/// trên Wear OS thật có cảm biến PPG — không chạy được trên emulator/điện
/// thoại thường (không có cảm biến để Health Services đọc), xem
/// `PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md`.
///
/// **[CHƯA VERIFY]** Chưa build/chạy thật với đồng hồ Wear OS thật — không có
/// thiết bị để test tại thời điểm viết (2026-08-19).
class WearHeartRateBridge {
  WearHeartRateBridge._();

  static const _channel = MethodChannel(
    'com.familycare.family_care/wear_heart_rate',
  );
  static const _events = EventChannel(
    'com.familycare.family_care/wear_heart_rate_stream',
  );

  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  static StreamSubscription<dynamic>? _sub;

  /// Xin quyền `BODY_SENSORS` (Android permission dangerous, runtime) — PHẢI
  /// gọi và được `true` trước [start], nếu không native đăng ký measure
  /// callback sẽ thất bại vì thiếu quyền.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    final status = await Permission.sensors.request();
    return status.isGranted;
  }

  static Future<bool> hasPermission() async {
    if (!_supported) return false;
    return (await Permission.sensors.status).isGranted;
  }

  /// Bắt đầu nghe nhịp tim thật, gọi [onReading] mỗi khi có mẫu mới. Health
  /// Services trả `bpm` dạng `double` — làm tròn về `int` cho khớp
  /// `HeartRateDetector.addSample(int bpm, ...)` đã có sẵn.
  static Future<void> start({required void Function(int bpm) onReading}) async {
    if (!_supported) {
      throw Exception('Đọc nhịp tim thật chỉ hỗ trợ trên Wear OS (Android)');
    }
    await stop();
    try {
      await _channel.invokeMethod<void>('start');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Không khởi động được cảm biến nhịp tim');
    } on MissingPluginException {
      throw Exception('Chưa build lại app — thiếu cầu nối nhịp tim native');
    }
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        final map = event as Map<dynamic, dynamic>;
        final bpm = (map['bpm'] as num).round();
        onReading(bpm);
      },
      onError: (Object _) {
        // Lỗi luồng (vd Health Services báo UNAVAILABLE) — không có API rõ
        // ràng để báo lên UI qua đường này; màn gọi vẫn còn nút tắt cảm biến
        // thủ công nếu không thấy dữ liệu về.
      },
      cancelOnError: false,
    );
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Chưa build lại native — không chặn luồng dừng.
    }
  }
}
