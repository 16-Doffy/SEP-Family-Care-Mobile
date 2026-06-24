import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SosAlert {
  final String id;
  final String status;
  final String severity;
  final String message;
  final String address;
  final String senderName;
  final String senderId;
  final String sourceType;
  final String createdAt;

  const SosAlert({
    required this.id,
    required this.status,
    this.severity = 'MEDIUM',
    required this.message,
    required this.address,
    required this.senderName,
    this.senderId = '',
    this.sourceType = 'MOBILE_APP',
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE' || status == 'ACKNOWLEDGED';

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final root = data.isNotEmpty ? data : json;
    final triggeredBy = _asMap(
      json['triggeredBy'] ?? json['sender'] ?? root['triggeredBy'] ?? root['sender'],
    );
    final location = _asMap(json['location'] ?? root['location']);

    return SosAlert(
      id: _pickString([
            json['id'],
            json['alertId'],
            json['sosAlertId'],
            root['id'],
            root['alertId'],
            root['sosAlertId'],
          ]) ??
          '',
      status: _pickString([json['status'], root['status']]) ?? 'ACTIVE',
      severity: _pickString([json['severity'], root['severity']]) ?? 'MEDIUM',
      message: _pickString([json['message'], root['message'], json['note'], root['note']]) ?? 'SOS',
      address: _pickString([location['address'], json['address'], root['address']]) ?? '',
      senderName: _pickString([
            triggeredBy['displayName'],
            triggeredBy['fullName'],
            triggeredBy['name'],
            json['senderName'],
            root['senderName'],
          ]) ??
          'Thành viên',
      senderId: _pickString([
            triggeredBy['id'],
            triggeredBy['userId'],
            json['triggeredByMemberId'],
            root['triggeredByMemberId'],
          ]) ??
          '',
      sourceType: _pickString([json['sourceType'], root['sourceType']]) ?? 'MOBILE_APP',
      createdAt: _pickString([json['createdAt'], root['createdAt'], json['sentAt'], root['sentAt']]) ?? '',
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String? _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
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
      _alerts = _extractList(data)
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

  Future<SosAlert?> fetchAlertDetail(String alertId) async {
    if (_familyId == null || alertId.trim().isEmpty) return null;
    try {
      final data = await ApiClient.instance.get('/families/$_familyId/sos/alerts/$alertId');
      if (data is Map<String, dynamic>) return SosAlert.fromJson(data);
      if (data is Map) return SosAlert.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {}
    return null;
  }

  Future<void> sendSos({
    String message = 'SOS',
    String severity = 'HIGH',
    double? latitude,
    double? longitude,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$_familyId/sos/alerts', {
        'message': message,
        'severity': severity,
        'sourceType': 'MOBILE_APP',
        if (latitude != null) 'initialLatitude': latitude,
        if (longitude != null) 'initialLongitude': longitude,
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
        {if (note != null && note.isNotEmpty) 'resolutionNote': note},
      );
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> cancelAlert(String alertId, {String? note}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$_familyId/sos/alerts/$alertId/cancel',
        {if (note != null && note.isNotEmpty) 'resolutionNote': note},
      );
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

  Future<void> respondToAlert(
    String alertId, {
    required String responseType,
    String? message,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/sos/alerts/$alertId/responses',
      {
        'responseType': responseType,
        if (message != null && message.isNotEmpty) 'message': message,
      },
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

  Future<void> updateAlert(String id, String status, {String? note}) async {
    if (status == 'RESOLVED') {
      await resolveAlert(id, note: note);
    } else if (status == 'CANCELED' || status == 'CANCELLED') {
      await cancelAlert(id, note: note);
    }
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return const <dynamic>[];
    for (final key in const ['items', 'data', 'alerts', 'results', 'rows', 'records']) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const <dynamic>[];
  }
}
