import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CallGuardService {
  CallGuardService._();
  static final CallGuardService instance = CallGuardService._();

  static const _channel = MethodChannel(
    'com.familycare.family_care/call_guard',
  );

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('start');
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> stop() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('stop');
  }

  Future<bool> isRunning() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
