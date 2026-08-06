import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Lấy vị trí để đính kèm vào cảnh báo SOS.
///
/// Nguyên tắc: **GPS không được chặn việc gửi SOS** — `CreateSosAlertDto` không
/// bắt buộc toạ độ. `getCurrentPosition` trên emulator / fused provider có thể
/// treo vô hạn chờ fix mới (`timeLimit` của geolocator không phải lúc nào cũng
/// nhả) nên phải bọc timeout cứng rồi fallback sang `getLastKnownPosition`.
///
/// Tách ra khỏi `sos_screen.dart` để nút SOS thủ công và phát hiện té ngã dùng
/// **cùng một** đường lấy vị trí; trước đây logic này chỉ nằm trong state của
/// màn SOS nên nơi khác không gọi lại được.
Future<Position?> resolveSosPosition() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Không lấy được fix mới trong 10s → dùng vị trí gần nhất đã biết (trả
      // về ngay, không chờ) — vẫn hơn là không có gì.
      return await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    }
  } catch (e) {
    debugPrint('resolveSosPosition failed: $e');
    return null;
  }
}

/// Chuỗi địa chỉ dạng `GPS: lat, lng` để gửi kèm alert; rỗng nếu không có toạ độ.
String sosAddressOf(Position? pos) => pos == null
    ? ''
    : 'GPS: ${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';
