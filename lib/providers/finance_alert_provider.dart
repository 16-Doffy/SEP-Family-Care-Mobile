import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FinanceAlert {
  final String id;
  final String alertType;
  final String severity;
  final String status;
  final String message;
  final DateTime createdAt;

  const FinanceAlert({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory FinanceAlert.fromJson(Map<String, dynamic> json) => FinanceAlert(
        id:        json['id']?.toString() ?? '',
        alertType: json['alertType']?.toString() ?? '',
        severity:  json['severity']?.toString() ?? 'LOW',
        status:    json['status']?.toString() ?? 'NEW',
        message:   json['message']?.toString()
                   ?? json['description']?.toString()
                   ?? _defaultMessage(json['alertType']?.toString()),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  static String _defaultMessage(String? type) => switch (type) {
        'OVER_BUDGET'           => 'Chi tiêu vượt ngân sách',
        'GOAL_AT_RISK'          => 'Mục tiêu tài chính có nguy cơ không đạt',
        'NON_ESSENTIAL_TOO_HIGH'=> 'Chi tiêu không thiết yếu quá cao',
        _                       => 'Cảnh báo tài chính',
      };

  bool get isNew => status == 'NEW';
}

class FinanceAlertProvider extends ChangeNotifier {
  List<FinanceAlert> _alerts = [];
  bool _loading = false;
  String? _error;

  List<FinanceAlert> get alerts => _alerts;
  bool get loading => _loading;
  String? get error => _error;
  int get newCount => _alerts.where((a) => a.isNew).length;

  Future<void> fetchAlerts({String? status}) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final query = status != null ? '?status=$status' : '';
      final data = await ApiClient.instance.get(
        '/families/$fid/finance/alerts$query',
      );
      final list = data is List ? data : (data['items'] as List? ?? data['data'] as List? ?? []);
      _alerts = list
          .whereType<Map<String, dynamic>>()
          .map(FinanceAlert.fromJson)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledge(String alertId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      await ApiClient.instance.patch(
        '/families/$fid/finance/alerts/$alertId/acknowledge',
        {},
      );
      _alerts = _alerts.map((a) => a.id == alertId
          ? FinanceAlert(
              id: a.id, alertType: a.alertType, severity: a.severity,
              status: 'ACKNOWLEDGED', message: a.message, createdAt: a.createdAt)
          : a).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resolve(String alertId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      await ApiClient.instance.patch(
        '/families/$fid/finance/alerts/$alertId/resolve',
        {},
      );
      _alerts = _alerts.where((a) => a.id != alertId).toList();
      notifyListeners();
    } catch (_) {}
  }
}
