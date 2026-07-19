import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SosAlert {
  final String id;
  final String status;   // ACTIVE | RESOLVED | CANCELED
  final String severity; // LOW | MEDIUM | HIGH | CRITICAL
  final String message;
  final String address;
  final String senderName;
  final String createdAt;
  final String? resolutionNote;
  final String? resolvedByName;
  final double? latitude;
  final double? longitude;

  const SosAlert({
    required this.id,
    required this.status,
    this.severity = 'HIGH',
    required this.message,
    required this.address,
    required this.senderName,
    required this.createdAt,
    this.resolutionNote,
    this.resolvedByName,
    this.latitude,
    this.longitude,
  });

  bool get isActive => status == 'ACTIVE';
  bool get hasLocation => latitude != null && longitude != null;

  // Tên hiển thị của 1 member object BE trả: {displayName, user: {fullName}}
  static String? _memberName(dynamic m) {
    if (m is! Map) return null;
    final display = m['displayName']?.toString();
    if (display != null && display.isNotEmpty) return display;
    final user = m['user'];
    if (user is Map) {
      final full = user['fullName']?.toString();
      if (full != null && full.isNotEmpty) return full;
    }
    // format phẳng cũ: {fullName: ...} ngay trên member object
    final flat = m['fullName']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  // Response thật của BE (verified live 2026-07-10): id nằm ở "sosAlertId",
  // người gửi ở "triggeredByMember.user.fullName", tọa độ là STRING.
  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['sosAlertId']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      severity: json['severity']?.toString() ?? 'HIGH',
      message: json['message']?.toString() ?? 'SOS',
      address: json['address']?.toString() ?? '',
      senderName: _memberName(json['triggeredByMember']) ??
          _memberName(json['sender']) ??
          _memberName(json['triggeredBy']) ??
          json['senderName']?.toString() ??
          'Thành viên',
      createdAt: json['triggeredAt']?.toString() ?? json['createdAt']?.toString() ?? '',
      resolutionNote: json['resolutionNote']?.toString(),
      resolvedByName: _memberName(json['resolvedByMember']),
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

/// Liên hệ khẩn cấp của gia đình (BE ship 19/07):
/// GET/POST `/families/{id}/sos/emergency-contacts`,
/// PATCH/DELETE `.../{contactId}`.
class EmergencyContact {
  final String id;
  final String contactName;
  final String phoneNumber;
  final String? relationshipNote;
  final int? priorityOrder;
  final bool isActive;

  const EmergencyContact({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    this.relationshipNote,
    this.priorityOrder,
    this.isActive = true,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id']?.toString() ?? j['contactId']?.toString() ?? '',
        contactName: j['contactName']?.toString() ?? 'Liên hệ',
        phoneNumber: j['phoneNumber']?.toString() ?? '',
        relationshipNote: j['relationshipNote']?.toString(),
        priorityOrder: (j['priorityOrder'] as num?)?.toInt(),
        isActive: j['isActive'] as bool? ?? true,
      );
}

class SosProvider extends ChangeNotifier {
  // ── Danh bạ khẩn cấp ─────────────────────────────────────────────────────
  List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get emergencyContacts => _contacts;

  /// Số gọi nhanh hiển thị ở màn SOS: ưu tiên danh bạ gia đình (ACTIVE, theo
  /// priorityOrder); rỗng thì fallback hotline quốc gia.
  static const kDefaultHotlines = ['113', '115', '114'];

  Future<void> fetchEmergencyContacts() async {
    final fid = _fid;
    if (fid == null) return;
    try {
      final data =
          await ApiClient.instance.get('/families/$fid/sos/emergency-contacts');
      final raw = data is List
          ? data
          : (data is Map && data['items'] is List ? data['items'] : <dynamic>[]);
      final list = (raw as List)
          .whereType<Map>()
          .map((e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.isActive && c.phoneNumber.isNotEmpty)
          .toList()
        ..sort((a, b) =>
            (a.priorityOrder ?? 9999).compareTo(b.priorityOrder ?? 9999));
      _contacts = list;
      notifyListeners();
    } catch (e) {
      debugPrint('SosProvider: fetchEmergencyContacts failed: $e');
    }
  }

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
          : (data is Map && data['items'] is List
                ? data['items']
                : (data is Map && data['alerts'] is List
                    ? data['alerts']
                    : <dynamic>[]));
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
      // BE trả "sosAlertId" (verified live), không phải "id"
      final id = created['sosAlertId']?.toString() ?? created['id']?.toString();
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
  // FAMILY_MANAGER / DEPUTY_MEMBER. [isFalseAlarm] (BE ship 19/07) = đóng với
  // trạng thái FALSE_ALARM thay vì RESOLVED; cancel bỏ qua field này.
  Future<void> resolveAlert(String alertId,
          {String? resolutionNote, bool isFalseAlarm = false}) =>
      _patchAlert(alertId, 'resolve', resolutionNote,
          isFalseAlarm: isFalseAlarm);

  // PATCH /families/{familyId}/sos/alerts/{alertId}/cancel — chỉ
  // FAMILY_MANAGER / DEPUTY_MEMBER.
  Future<void> cancelAlert(String alertId, {String? resolutionNote}) =>
      _patchAlert(alertId, 'cancel', resolutionNote);

  Future<void> _patchAlert(String alertId, String action, String? resolutionNote,
      {bool isFalseAlarm = false}) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.patch('/families/$fid/sos/alerts/$alertId/$action', {
        if (resolutionNote != null && resolutionNote.isNotEmpty) 'resolutionNote': resolutionNote,
        if (action == 'resolve' && isFalseAlarm) 'isFalseAlarm': true,
      });
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/sos/alerts/{alertId}/responses — thành viên
  // khác phản hồi cảnh báo. Enum BE (verify 19/07): VIEWED | ON_THE_WAY |
  // CONFIRM_SAFE | NEED_HELP (RESOLVED/CANCELED do manager qua endpoint riêng).
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

  // POST /families/{familyId}/sos/alerts/{alertId}/locations — gửi 1 điểm vị
  // trí trong lúc alert đang active (gọi lặp lại từ SOSScreen bằng Timer, xem
  // _startLocationStreaming). Không dùng _ensureNoActionInProgress/_sending
  // vì đây là tác vụ nền lặp lại, không nên chặn các thao tác SOS khác
  // (resolve/cancel/confirm-safety) của cùng alert.
  Future<void> pushLocation(String alertId, double latitude, double longitude, {double? accuracy}) async {
    final fid = _fid;
    if (fid == null) return;
    try {
      await ApiClient.instance.post('/families/$fid/sos/alerts/$alertId/locations', {
        'latitude': latitude,
        'longitude': longitude,
        'sourceType': 'MOBILE_GPS',
        'accuracy': ?accuracy,
      });
    } catch (e) {
      debugPrint('SosProvider: pushLocation failed: $e');
    }
  }

  // GET .../sos/alerts/{alertId}/location/current — vị trí MỚI NHẤT của alert
  // (BE bổ sung 2026-07-10, dành cho người theo dõi vừa vào xem). Trả null nếu
  // alert chưa có điểm vị trí nào hoặc gọi lỗi — caller tự fallback.
  Future<({double lat, double lng})?> fetchCurrentLocation(String alertId) async {
    final fid = _fid;
    if (fid == null) return null;
    try {
      final data = await ApiClient.instance
          .get('/families/$fid/sos/alerts/$alertId/location/current');
      if (data is Map) {
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        if (lat != null && lng != null) return (lat: lat, lng: lng);
      }
    } catch (e) {
      debugPrint('SosProvider: fetchCurrentLocation failed: $e');
    }
    return null;
  }

  // POST .../sos/alerts/{alertId}/locations/batch — gửi nhiều điểm vị trí một
  // lần (BE bổ sung 2026-07-10; thiết bị buffer khi offline rồi flush — dành
  // cho Wear OS / mất mạng tạm thời).
  Future<void> pushLocationBatch(
      String alertId, List<({double lat, double lng, double? accuracy, DateTime? recordedAt})> points,
      {String sourceType = 'MOBILE_GPS'}) async {
    final fid = _fid;
    if (fid == null || points.isEmpty) return;
    try {
      await ApiClient.instance.post('/families/$fid/sos/alerts/$alertId/locations/batch', {
        'points': [
          for (final p in points)
            {
              'latitude': p.lat,
              'longitude': p.lng,
              'sourceType': sourceType,
              if (p.accuracy != null) 'accuracy': p.accuracy,
              if (p.recordedAt != null) 'recordedAt': p.recordedAt!.toUtc().toIso8601String(),
            }
        ],
      });
    } catch (e) {
      debugPrint('SosProvider: pushLocationBatch failed: $e');
    }
  }

  // GET /families/{familyId}/sos/alerts/{alertId} — chi tiết 1 alert (kèm
  // phản hồi + vị trí, theo mô tả API_DOCS.md). List hiện tại đủ cho UI
  // chính, gọi thêm khi cần xem đầy đủ responses/locations lịch sử.
  Future<Map<String, dynamic>> fetchAlertDetail(String alertId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.get('/families/$fid/sos/alerts/$alertId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  void _ensureNoActionInProgress() {
    if (_sending) {
      throw Exception('Một thao tác SOS khác đang được xử lý, vui lòng chờ.');
    }
  }
}
