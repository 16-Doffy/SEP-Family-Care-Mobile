import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SosAlert {
  final String id;
  final String status;
  final String message;
  final String address;
  final String senderName;
  final String createdAt;
  final double? latitude;
  final double? longitude;

  const SosAlert({
    required this.id,
    required this.status,
    required this.message,
    required this.address,
    required this.senderName,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  bool get isActive => status == 'ACTIVE';
  bool get hasLocation => latitude != null && longitude != null;

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] is Map
        ? json['sender'] as Map<String, dynamic>
        : (json['triggeredBy'] is Map ? json['triggeredBy'] as Map<String, dynamic> : <String, dynamic>{});
    return SosAlert(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      message: json['message']?.toString() ?? 'SOS',
      address: json['address']?.toString() ?? '',
      senderName:
          sender['displayName']?.toString() ??
          sender['fullName']?.toString() ??
          json['senderName']?.toString() ??
          'Thành viên',
      createdAt: json['createdAt']?.toString() ?? '',
      // BE trả initialLatitude/initialLongitude khi tạo alert.
      latitude: _d(json['latitude'] ?? json['initialLatitude']),
      longitude: _d(json['longitude'] ?? json['initialLongitude']),
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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

  String? get _fid => ApiClient.instance.familyId;

  // GET /families/{familyId}/sos/alerts
  Future<void> fetchAlerts() async {
    final fid = _fid;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/sos/alerts');
      final raw = data is List
          ? data
          : (data is Map && data['alerts'] is List
                ? data['alerts']
                : <dynamic>[]);
      _alerts = (raw as List)
          .whereType<Map>()
          .map((e) => SosAlert.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('SosProvider: fetchAlerts failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/sos/alerts
  // address: chỉ dùng hiển thị local (UI cũ), KHÔNG gửi lên BE — xem comment
  // trong body POST bên dưới.
  Future<String> sendSos({
    String message = 'SOS khẩn cấp',
    String address = '',
    double? latitude,
    double? longitude,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      // address KHÔNG nằm trong CreateSosAlertDto theo API_DOCS — không gửi
      // vì backend có thể bật forbidNonWhitelisted và trả 400 cho field lạ.
      final created = await ApiClient.instance.post('/families/$fid/sos/alerts', {
        'sourceType': 'MOBILE_APP',
        'message': message,
        'initialLatitude': ?latitude,
        'initialLongitude': ?longitude,
      });
      await fetchAlerts();
      final id = created['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Server không trả về ID cảnh báo');
      }
      return id;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // PATCH /families/{familyId}/sos/alerts/{alertId}/resolve — chỉ
  // FAMILY_MANAGER / DEPUTY_MEMBER.
  Future<void> resolveAlert(String alertId, {String? resolutionNote}) =>
      _patchAlert(alertId, 'resolve', resolutionNote);

  // PATCH /families/{familyId}/sos/alerts/{alertId}/cancel — chỉ
  // FAMILY_MANAGER / DEPUTY_MEMBER.
  Future<void> cancelAlert(String alertId, {String? resolutionNote}) =>
      _patchAlert(alertId, 'cancel', resolutionNote);

  Future<void> _patchAlert(String alertId, String action, String? resolutionNote) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/families/$fid/sos/alerts/$alertId/$action', {
        if (resolutionNote != null && resolutionNote.isNotEmpty) 'resolutionNote': resolutionNote,
      });
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/sos/alerts/{alertId}/responses — thành viên
  // khác phản hồi cảnh báo (VIEWED / CONFIRM_SAFE / NEED_HELP).
  Future<void> respond(String alertId, String responseType, {String? message}) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$fid/sos/alerts/$alertId/responses', {
        'responseType': responseType,
        if (message != null && message.isNotEmpty) 'message': message,
      });
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/sos/alerts/{alertId}/confirm-safety — người
  // kích hoạt SOS tự xác nhận đã an toàn.
  Future<void> confirmSafety(String alertId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$fid/sos/alerts/$alertId/confirm-safety', {});
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void _ensureNoActionInProgress() {
    if (_sending) {
      throw Exception('Một thao tác SOS khác đang được xử lý, vui lòng chờ.');
    }
  }
}
