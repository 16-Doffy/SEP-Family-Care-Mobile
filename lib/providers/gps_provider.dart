import 'package:flutter/material.dart';
import '../services/api_client.dart';

// Shape response đã được BE document (Swagger 19/07):
// { userId, memberId, displayName, avatarUrl, latitude, longitude, accuracy,
//   updatedAt, isSharing } — vẫn giữ fallback key cũ cho chắc.
class LocationShare {
  final String userId;
  final String? memberId;
  final String displayName;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? updatedAt;
  final bool isSharing;

  const LocationShare({
    required this.userId,
    this.memberId,
    required this.displayName,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.updatedAt,
    this.isSharing = true,
  });

  factory LocationShare.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final displayName =
        json['displayName']?.toString() ??
        json['fullName']?.toString() ??
        user['displayName']?.toString() ??
        user['fullName']?.toString() ??
        'Thành viên';
    return LocationShare(
      userId: json['userId']?.toString() ?? user['id']?.toString() ?? '',
      memberId: json['memberId']?.toString(),
      displayName: displayName,
      avatarUrl: json['avatarUrl']?.toString() ?? user['avatarUrl']?.toString(),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      accuracy: _parseDouble(json['accuracy']),
      updatedAt:
          json['updatedAt']?.toString() ?? json['recordedAt']?.toString(),
      // Endpoint chỉ trả thành viên đang bật chia sẻ → mặc định true.
      isSharing: json['isSharing'] as bool? ?? true,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

class GpsProvider extends ChangeNotifier {
  List<LocationShare> _shares = [];
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _sharingUnavailable = false;

  // Trạng thái chia sẻ vị trí của CHÍNH MÌNH. BE không có endpoint đọc riêng →
  // suy từ việc mình có mặt trong members/locations (endpoint chỉ trả người
  // đang bật), và cập nhật lạc quan khi bấm toggle.
  bool _mySharing = false;

  List<LocationShare> get shares => _shares;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  bool get mySharing => _mySharing;
  // Giữ làm lưới an toàn: nếu endpoint location 404 (BE rollback/đổi path),
  // UI hiện "đang phát triển" thay vì phơi raw "Cannot GET ...".
  bool get sharingUnavailable => _sharingUnavailable;

  // BE ship 3 EP location 19/07 (đúng contract BAO_CAO_BE_SOS_2026-07-16 §7
  // phương án B — family-scoped). Path cũ `/location/*` đã chết, không dùng.
  String? get _fid => ApiClient.instance.familyId;

  Future<void> fetchFamilyLocations({String? myUserId}) async {
    final fid = _fid;
    if (fid == null) return;
    _loading = true;
    _error = null;
    _sharingUnavailable = false;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/members/locations',
      );
      final list = data is List
          ? data
          : data is Map && data['shares'] is List
          ? data['shares'] as List
          : data is Map && data['items'] is List
          ? data['items'] as List
          : data is Map && data['locations'] is List
          ? data['locations'] as List
          : <dynamic>[];
      _shares = list
          .whereType<Map>()
          .map((e) => LocationShare.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Có mặt trong danh sách = mình đang bật chia sẻ.
      if (myUserId != null && myUserId.isNotEmpty) {
        _mySharing = _shares.any((s) => s.userId == myUserId && s.isSharing);
      }
    } catch (e) {
      // Nếu endpoint location trả 404 (rollback/đổi path) → coi như chưa. Đây
      // KHÔNG phải lỗi thật, chỉ là tính năng chia sẻ vị trí chưa sẵn sàng —
      // đặt cờ để UI hiện "đang phát triển", không phơi thông báo kỹ thuật.
      final msg = e.toString();
      if (msg.contains('Cannot GET') ||
          msg.contains('404') ||
          msg.toLowerCase().contains('not found')) {
        _sharingUnavailable = true;
        _error = null;
      } else {
        _error = 'Không tải được vị trí gia đình';
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSharing(bool value, {String? myUserId}) async {
    final fid = _fid;
    if (fid == null) return;
    _busy = true;
    _mySharing = value; // lạc quan để UI phản hồi ngay
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$fid/members/me/location-sharing',
        {'isSharing': value},
      );
      await fetchFamilyLocations(myUserId: myUserId);
      // Endpoint danh sách có thể chưa trả chính mình ngay sau PATCH nếu chưa
      // có bản ghi tọa độ mới. Giữ trạng thái theo kết quả PATCH để switch
      // không bật xong lại nhảy về tắt trước khi FE kịp POST /locations.
      _mySharing = value;
    } catch (e) {
      _mySharing = !value; // rollback nếu BE từ chối
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Đẩy vị trí của mình. [silent] = true khi gọi từ timer định kỳ: không bật
  /// cờ busy và không refetch, tránh nhấp nháy UI mỗi chu kỳ.
  Future<void> updateLocation(
    double latitude,
    double longitude, {
    double accuracy = 18,
    bool silent = false,
    String? myUserId,
  }) async {
    final fid = _fid;
    if (fid == null) return;
    if (!silent) {
      _busy = true;
      notifyListeners();
    }
    try {
      await ApiClient.instance.post('/families/$fid/locations', {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      });
      if (!silent) await fetchFamilyLocations(myUserId: myUserId);
    } catch (e) {
      debugPrint('GpsProvider: updateLocation failed: $e');
    } finally {
      if (!silent) {
        _busy = false;
        notifyListeners();
      }
    }
  }
}
