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
    final sender =
        json['sender'] is Map ? json['sender'] as Map<String, dynamic> : <String, dynamic>{};
    return SosAlert(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      message: json['message']?.toString() ?? 'SOS',
      address: json['address']?.toString() ?? '',
      senderName: sender['displayName']?.toString() ?? 'Thành viên',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class SosProvider extends ChangeNotifier {
  List<SosAlert> _alerts = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;

  List<SosAlert> get alerts => _alerts;
  List<SosAlert> get activeAlerts => _alerts.where((a) => a.isActive).toList();
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  Future<void> fetchAlerts() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/sos');
      final list = data is Map && data['alerts'] is List
          ? data['alerts'] as List
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

  Future<void> sendSos({
    String message = 'SOS from Flutter mobile',
    String address = 'Mobile app',
  }) async {
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance
          .post('/sos', {'message': message, 'address': address});
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> updateAlert(String id, String status) async {
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/sos/$id', {'status': status});
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
