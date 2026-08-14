import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

class SosGuardStatus {
  final bool running;
  final bool shakeEnabled;
  final bool fallEnabled;

  /// Từ Android 14 (API 34): app phải được người dùng cấp thủ công mới mở
  /// được màn SOS đè lên màn khóa. Máy cũ hơn không có giới hạn này nên luôn
  /// `true`. UI dùng cờ này để hiện nút "Cấp quyền" khi cần.
  final bool fullScreenIntentGranted;

  /// Người dùng đã tự bật `EmergencySosWatcherService` trong Cài đặt > Trợ
  /// năng chưa — app không tự bật hộ được, chỉ đọc trạng thái để hiện đúng
  /// UI. Luôn `false` trên máy không phải ColorOS (không sai, chỉ là tính
  /// năng này không có tác dụng ở đó — xem `EmergencySosMatcher`).
  final bool emergencyWatcherEnabled;

  const SosGuardStatus({
    required this.running,
    required this.shakeEnabled,
    required this.fallEnabled,
    this.fullScreenIntentGranted = true,
    this.emergencyWatcherEnabled = false,
  });

  factory SosGuardStatus.fromMap(Map<Object?, Object?> map) => SosGuardStatus(
    running: map['running'] == true,
    shakeEnabled: map['shakeEnabled'] == true,
    fallEnabled: map['fallEnabled'] == true,
    fullScreenIntentGranted: map['fullScreenIntentGranted'] != false,
    emergencyWatcherEnabled: map['emergencyWatcherEnabled'] == true,
  );

  static const off = SosGuardStatus(
    running: false,
    shakeEnabled: false,
    fallEnabled: false,
  );
}

class SosGuardService {
  SosGuardService._() {
    // Thiết bị dùng chung trong gia đình: đăng xuất mà không dừng service
    // native thì người sau đăng nhập vào máy vẫn "thừa hưởng" cảm biến của
    // người trước — lắc nhầm sẽ gửi SOS dưới tên người đang đăng nhập lúc đó.
    ApiClient.addSessionResetListener(_resetForNewSession);
  }
  static final SosGuardService instance = SosGuardService._();

  void _resetForNewSession() {
    unawaited(stop());
  }

  static const _channel = MethodChannel('com.familycare.family_care/sos_guard');

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  Future<SosGuardStatus> getStatus() async {
    if (!_supported) return SosGuardStatus.off;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getStatus',
      );
      return raw == null ? SosGuardStatus.off : SosGuardStatus.fromMap(raw);
    } on MissingPluginException {
      return SosGuardStatus.off;
    }
  }

  Future<void> start({
    required bool shakeEnabled,
    required bool fallEnabled,
  }) async {
    if (!_supported) return;
    if (!shakeEnabled && !fallEnabled) {
      await stop();
      return;
    }
    await _channel.invokeMethod<void>('start', {
      'shakeEnabled': shakeEnabled,
      'fallEnabled': fallEnabled,
    });
  }

  Future<void> stop() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('stop');
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
  }

  /// Mở màn hệ thống cho phép app tự mở Activity full-screen từ notification
  /// (Android 14+). Không có quyền này thì lắc/té ngã chỉ bắn được thông báo
  /// phải chạm tay, không tự mở màn SOS đè lên màn khóa được.
  Future<void> openFullScreenIntentSettings() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('openFullScreenIntentSettings');
  }

  /// Mở Cài đặt > Trợ năng của Android để người dùng tự bật
  /// `EmergencySosWatcherService` — app không có cách nào tự bật hộ, đây là
  /// quyền hệ thống chặn không cho làm vậy.
  Future<void> openAccessibilitySettings() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  /// Đọc riêng trạng thái bật/tắt của `EmergencySosWatcherService` — dùng khi
  /// chỉ cần refresh 1 cờ (ví dụ lúc quay lại app sau khi vào Cài đặt hệ
  /// thống) mà không cần gọi lại toàn bộ [getStatus].
  Future<bool> isEmergencyWatcherEnabled() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEmergencyWatcherEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
