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
  // true khi BE chưa triển khai /location/* (404) — dùng để UI hiện "đang phát
  // triển" thay vì phơi raw "Cannot GET /api/v1/location/family".
  bool get sharingUnavailable => _sharingUnavailable;

  Future<void> fetchFamilyLocations() async {
    _loading = true;
    _error = null;
    _sharingUnavailable = false;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/location/family');
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
      // /location/family chưa được BE triển khai → 404 "Cannot GET ...". Đây
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
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/location/toggle', {'isSharing': value});
      await fetchFamilyLocations();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(double latitude, double longitude,
      {double accuracy = 18}) async {
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/location/update', {
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
