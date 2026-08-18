import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Danh sách thiết bị Garmin đã pair với **Garmin Connect Mobile** trên máy
/// (không phải danh sách pair của Family Care) — lấy qua `ConnectIQ.knownDevices`.
class GarminIqDevice {
  final int iqDeviceId;
  final String friendlyName;
  final String status;

  const GarminIqDevice({
    required this.iqDeviceId,
    required this.friendlyName,
    required this.status,
  });

  factory GarminIqDevice.fromMap(Map<dynamic, dynamic> m) => GarminIqDevice(
    iqDeviceId: (m['iqDeviceId'] as num).toInt(),
    friendlyName: (m['friendlyName'] as String?) ?? 'Garmin watch',
    status: (m['status'] as String?) ?? 'UNKNOWN',
  );

  bool get isConnected => status.toUpperCase() == 'CONNECTED';
}

/// Cầu nối Garmin Connect IQ Mobile SDK (native, xem `GarminBridgeService.kt`).
///
/// Garmin watch app KHÔNG gọi backend trực tiếp — nó chỉ là sensor source.
/// Toàn bộ giao tiếp với SDK (liệt kê thiết bị, gửi `PAIR_CONFIRMED`, nhận
/// `FALL_DETECTED` rồi tự POST `/wearables/{deviceId}/events`) chạy TRONG
/// native (`GarminBridgeService`, foreground service độc lập Flutter engine)
/// — lớp này chỉ là lối gọi từ Dart, không giữ state.
///
/// **[CHƯA VERIFY]** Chưa build/chạy thật với SDK + watch app thật, xem
/// `KE_HOACH_GARMIN_CONNECTIQ_INTEGRATION_2026-08-18.md`.
class GarminBridge {
  GarminBridge._();
  static const _channel = MethodChannel('com.familycare.family_care/garmin');

  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  static Future<List<GarminIqDevice>> getKnownDevices() async {
    if (!_supported) return const [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getKnownDevices',
      );
      return (result ?? const [])
          .whereType<Map>()
          .map(GarminIqDevice.fromMap)
          .toList();
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Không lấy được danh sách thiết bị Garmin');
    } on MissingPluginException {
      throw Exception('Chưa build lại app — thiếu cầu nối Garmin native');
    }
  }

  /// Preflight — gọi TRƯỚC `WearableProvider.pairDevice()` (backend) để xác
  /// nhận thiết bị đang `CONNECTED` và watch app đã cài (`INSTALLED`). Ném
  /// exception nếu chưa sẵn sàng; nơi gọi PHẢI dừng lại, không được tạo bản
  /// ghi pairing ở backend cho một thiết bị chưa đủ điều kiện nhận
  /// `PAIR_CONFIRMED`.
  static Future<void> checkDeviceReady({
    required int iqDeviceId,
    required String iqFriendlyName,
  }) async {
    if (!_supported) {
      throw Exception('Garmin chỉ hỗ trợ trên Android');
    }
    try {
      await _channel.invokeMethod<void>('checkDeviceReady', {
        'iqDeviceId': iqDeviceId,
        'iqFriendlyName': iqFriendlyName,
      });
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Đồng hồ Garmin chưa sẵn sàng để ghép nối');
    } on MissingPluginException {
      throw Exception('Chưa build lại app — thiếu cầu nối Garmin native');
    }
  }

  /// Gọi SAU KHI đã pair xong qua API backend hiện có
  /// (`WearableProvider.pairDevice`) — [backendDeviceId] là `deviceId` BE trả
  /// về. Lưu mapping IQDevice <-> backendDeviceId trong native rồi gửi
  /// `PAIR_CONFIRMED` xuống watch; watch chỉ bắt đầu fall detection sau
  /// message này.
  static Future<void> confirmPair({
    required int iqDeviceId,
    required String iqFriendlyName,
    required String backendDeviceId,
    required String memberName,
  }) async {
    if (!_supported) {
      throw Exception('Garmin chỉ hỗ trợ trên Android');
    }
    try {
      await _channel.invokeMethod<void>('confirmPair', {
        'iqDeviceId': iqDeviceId,
        'iqFriendlyName': iqFriendlyName,
        'backendDeviceId': backendDeviceId,
        'memberName': memberName,
      });
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Xác nhận ghép nối Garmin thất bại');
    } on MissingPluginException {
      throw Exception('Chưa build lại app — thiếu cầu nối Garmin native');
    }
  }

  /// Gọi khi người dùng gỡ ghép nối Garmin (song song với
  /// `WearableProvider.unpairDevice`) — dừng service nền và xoá mapping
  /// native, tránh watch cũ còn gửi được `FALL_DETECTED` sau khi đã gỡ.
  static Future<void> stopBridge() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('stopBridge');
    } on MissingPluginException {
      // Chưa build lại native — không chặn luồng gỡ ghép nối phía BE.
    }
  }
}
