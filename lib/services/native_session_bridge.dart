import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Đẩy access token + `familyId` hiện tại xuống native (EncryptedSharedPreferences,
/// xem `TokenCache.kt`) để `SosEmergencyFlowService` tự gọi được API SOS khi
/// phát hiện té ngã lúc Flutter engine không còn sống (app bị kill hẳn, không
/// chỉ background) — `ApiClient` (Dart) không đọc được từ tiến trình native.
///
/// CHỈ cache access token, không cache refresh token. Token sống 15 phút nên
/// nếu app bị kill quá lâu trước khi ngã, cache có thể hết hạn; native khi đó
/// nhận 401 và ghi rõ trong log bước 6 thay vì tự ý refresh.
class NativeSessionBridge {
  NativeSessionBridge._();
  static const _channel = MethodChannel(
    'com.familycare.family_care/native_session',
  );

  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  static Future<void> cacheSession({
    required String token,
    required String familyId,
    required String baseUrl,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('cacheSession', {
        'token': token,
        'familyId': familyId,
        'baseUrl': baseUrl,
      });
    } on MissingPluginException {
      // Chưa build lại native (hot reload/hot restart) — không chặn Flutter.
    } on FlutterError {
      // Unit test thuần có thể chưa khởi tạo ServicesBinding.
    }
  }

  static Future<void> clearSession() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('clearSession');
    } on MissingPluginException {
      // Chưa có plugin native trong test/unit environment — bỏ qua.
    } on FlutterError {
      // Unit test thuần có thể chưa khởi tạo ServicesBinding.
    }
  }
}
