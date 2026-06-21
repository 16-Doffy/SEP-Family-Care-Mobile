import 'package:flutter/material.dart';
import '../services/api_client.dart';

class LocationPoint {
  final String memberId;
  final String displayName;
  final double? latitude;
  final double? longitude;
  final String? recordedAt;

  const LocationPoint({
    required this.memberId,
    required this.displayName,
    this.latitude,
    this.longitude,
    this.recordedAt,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    final member = json['member'] is Map ? json['member'] as Map : {};
    return LocationPoint(
      memberId: member['id']?.toString() ?? json['memberId']?.toString() ?? '',
      displayName: member['displayName']?.toString() ?? 'Thành viên',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      recordedAt: json['recordedAt']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

class GpsProvider extends ChangeNotifier {
  String? _familyId;
  List<LocationPoint> _points = [];
  bool _loading = false;
  bool _busy = false;
  String? _error;

  List<LocationPoint> get points => _points;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  // Giữ tương thích với code cũ
  List<LocationPoint> get shares => _points;

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchFamilyLocations();
    }
  }

  Future<void> fetchFamilyLocations() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId/locations/member-points');
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
      _points = list
          .whereType<Map>()
          .map((e) => LocationPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSharing(bool value) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$_familyId/location-sharing',
        {'isSharing': value},
      );
      await fetchFamilyLocations();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(double latitude, double longitude, {double accuracy = 18}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _busy = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$_familyId/locations/member-points', {
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
