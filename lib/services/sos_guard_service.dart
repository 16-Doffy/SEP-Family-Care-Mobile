import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Cầu nối tạm cho spike SOS nền trên Android.
///
/// Service native chỉ ghi log gia tốc kế với tag `SOSSHAKE`; chưa tự gửi SOS.
class SosGuardService {
  static const _channel = MethodChannel('familycare/sos_guard_spike');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> startSpike() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('startSpike') ?? false;
  }

  static Future<bool> stopSpike() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('stopSpike') ?? false;
  }

  static Future<bool> isSpikeRunning() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('isSpikeRunning') ?? false;
  }
}
