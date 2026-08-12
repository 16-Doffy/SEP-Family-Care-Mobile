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

  const SosGuardStatus({
    required this.running,
    required this.shakeEnabled,
    required this.fallEnabled,
    this.fullScreenIntentGranted = true,
  });

  factory SosGuardStatus.fromMap(Map<Object?, Object?> map) => SosGuardStatus(
    running: map['running'] == true,
    shakeEnabled: map['shakeEnabled'] == true,
    fallEnabled: map['fallEnabled'] == true,
    fullScreenIntentGranted: map['fullScreenIntentGranted'] != false,
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
}
