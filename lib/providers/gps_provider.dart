import 'package:flutter/material.dart';

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
}

class GpsProvider extends ChangeNotifier {
  final List<LocationPoint> _points = [];
  bool _loading = false;
  bool _busy = false;
  String? _error;

  List<LocationPoint> get points => _points;
  List<LocationPoint> get shares => _points;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  set familyId(String id) {}

  Future<void> fetchFamilyLocations() async {
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> toggleSharing(bool value) async {
    _busy = false;
    _error = 'Location sharing API is not available in Swagger';
    notifyListeners();
  }

  Future<void> updateLocation(
    double latitude,
    double longitude, {
    double accuracy = 18,
  }) async {
    _busy = false;
    _error = 'Member location API is not available in Swagger';
    notifyListeners();
  }
}
