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

  List<LocationShare> get shares => _shares;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> fetchFamilyLocations() async {
    _loading = true;
    _error = null;
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
      _error = e.toString();
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
