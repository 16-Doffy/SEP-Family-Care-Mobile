import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SosAlert {
  final String id;
  final String status;
  final String message;
  final String address;
  final String senderName;
  final String createdAt;

  const SosAlert({
    required this.id,
    required this.status,
    required this.message,
    required this.address,
    required this.senderName,
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE' || status == 'ACKNOWLEDGED';

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final triggeredBy = json['triggeredBy'] is Map
        ? json['triggeredBy'] as Map<String, dynamic>
        : json['sender'] is Map
            ? json['sender'] as Map<String, dynamic>
            : <String, dynamic>{};
    final location = json['location'] is Map ? json['location'] as Map : {};
    return SosAlert(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      message: json['message']?.toString() ?? json['note']?.toString() ?? 'SOS',
      address: location['address']?.toString() ?? json['address']?.toString() ?? '',
      senderName: triggeredBy['displayName']?.toString() ?? 'Thành viên',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class SosProvider extends ChangeNotifier {
  String? _familyId;
  List<SosAlert> _alerts = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;

  List<SosAlert> get alerts => _alerts;
  List<SosAlert> get activeAlerts => _alerts.where((a) => a.isActive).toList();
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchAlerts();
    }
  }

  Future<void> fetchAlerts() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId/sos/alerts');
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
      _alerts = list
          .whereType<Map>()
          .map((e) => SosAlert.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> sendSos({String message = 'SOS', String? address}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$_familyId/sos/alerts', {
        'message': message,
        if (address != null && address.isNotEmpty) 'address': address,
      });
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> resolveAlert(String alertId, {String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$_familyId/sos/alerts/$alertId/resolve',
        {if (note != null && note.isNotEmpty) 'note': note},
      );
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> cancelAlert(String alertId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/families/$_familyId/sos/alerts/$alertId/cancel');
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> confirmSafety(String alertId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/sos/alerts/$alertId/confirm-safety', {});
    await fetchAlerts();
  }

  Future<void> respondToAlert(String alertId, {String? message}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/sos/alerts/$alertId/responses',
      {if (message != null) 'message': message},
    );
  }

  Future<void> sendLocationToAlert(
    String alertId, {
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/sos/alerts/$alertId/locations',
      {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
  }

  // Giữ lại cho tương thích ngược với màn hình cũ
  Future<void> updateAlert(String id, String status) async {
    if (status == 'RESOLVED') {
      await resolveAlert(id);
    } else if (status == 'CANCELLED') {
      await cancelAlert(id);
    }
  }
}
