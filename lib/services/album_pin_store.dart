import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu danh sách ảnh đã ghim **trên máy này**.
///
/// BE hiện chưa có field `isPinned` hay endpoint ghim nào cho album media (đã
/// đối chiếu Swagger 2026-08-17), nên ghim là trạng thái cục bộ: chỉ thấy trên
/// đúng thiết bị đã ghim, không đồng bộ sang máy khác hay thành viên khác. Khi
/// BE bổ sung endpoint thì thay chỗ đọc/ghi này bằng lời gọi API, phần UI giữ
/// nguyên. Xem đề xuất trong `DE_XUAT_BE_ALBUM_PIN.md`.
///
/// Dùng `flutter_secure_storage` cho đồng bộ với `SecureTabConfigStore` —
/// không thêm dependency mới chỉ để lưu vài id.
class AlbumPinStore {
  const AlbumPinStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Khóa tách theo **user + family**: ghim là sở thích cá nhân, hai tài khoản
  /// dùng chung một máy (hoặc một tài khoản ở hai gia đình) không được thấy
  /// ghim của nhau.
  static String keyFor(String userId, String familyId) =>
      'album_pinned_${userId}_$familyId';

  Future<Set<String>> read(String userId, String familyId) async {
    final raw = await _storage.read(key: keyFor(userId, familyId));
    return parse(raw);
  }

  Future<void> write(String userId, String familyId, Set<String> ids) {
    final key = keyFor(userId, familyId);
    // Không còn ghim nào thì xóa hẳn khóa thay vì ghi chuỗi rỗng, để lần đọc
    // sau không phải phân biệt "chưa từng ghim" với "đã bỏ ghim hết".
    if (ids.isEmpty) return _storage.delete(key: key);
    return _storage.write(key: key, value: ids.join(','));
  }

  /// Tách riêng để unit test được mà không cần chạm storage thật.
  static Set<String> parse(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}
