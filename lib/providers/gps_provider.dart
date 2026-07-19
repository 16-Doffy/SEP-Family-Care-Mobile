import 'package:flutter/material.dart';
import '../services/api_client.dart';

class LocationShare {
  final String userId;
  final String displayName;
  final double? latitude;
  final double? longitude;
  final String? updatedAt;

  const LocationShare({
    required this.userId,
    required this.displayName,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  factory LocationShare.fromJson(Map<String, dynamic> json) {
    final user =
        json['user'] is Map ? json['user'] as Map<String, dynamic> : <String, dynamic>{};
    final displayName = json['displayName']?.toString() ??
        json['fullName']?.toString() ??
        user['displayName']?.toString() ??
        user['fullName']?.toString() ??
        'Thành viên';
    return LocationShare(
      userId: json['userId']?.toString() ?? user['id']?.toString() ?? '',
      displayName: displayName,
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      updatedAt: json['updatedAt']?.toString() ?? json['recordedAt']?.toString(),
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

  List<LocationShare> get shares => _shares;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  // Giữ làm lưới an toàn: nếu endpoint location 404 (BE rollback/đổi path),
  // UI hiện "đang phát triển" thay vì phơi raw "Cannot GET ...".
  bool get sharingUnavailable => _sharingUnavailable;

  // BE ship 3 EP location 19/07 (đúng contract BAO_CAO_BE_SOS_2026-07-16 §7
  // phương án B — family-scoped). Path cũ `/location/*` đã chết, không dùng.
  String? get _fid => ApiClient.instance.familyId;

  Future<void> fetchFamilyLocations() async {
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

  Future<void> toggleSharing(bool value) async {
    final fid = _fid;
    if (fid == null) return;
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$fid/members/me/location-sharing',
        {'isSharing': value},
      );
      await fetchFamilyLocations();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(double latitude, double longitude,
      {double accuracy = 18}) async {
    final fid = _fid;
    if (fid == null) return;
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$fid/locations', {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      });
      await fetchFamilyLocations();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
