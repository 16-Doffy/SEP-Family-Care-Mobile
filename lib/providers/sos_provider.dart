import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/sos_realtime_service.dart';

typedef SosRealtimeLocation = ({
  double lat,
  double lng,
  double? accuracy,
  String? sourceType,
  DateTime? recordedAt,
  String? deviceId,
});

class SosResponderLocation {
  final String alertId;
  final String responderMemberId;
  final String displayName;
  final String? avatarUrl;
  final SosRealtimeLocation location;

  const SosResponderLocation({
    required this.alertId,
    required this.responderMemberId,
    required this.displayName,
    this.avatarUrl,
    required this.location,
  });
}

class SosAlert {
  final String id;
  final String status; // ACTIVE | RESOLVED | CANCELED
  final String severity; // LOW | MEDIUM | HIGH | CRITICAL
  final String message;
  final String address;
  final String senderName;

  /// userId của người kích hoạt (`triggeredByMember.user.id`) — dùng để biết
  /// cảnh báo này có phải DO CHÍNH MÌNH phát hay không. Thiếu nó thì UI đối
  /// xử người phát như người nhận (banner "cần trợ giúp", nút "Tôi đang đến"
  /// hiện trên máy nạn nhân).
  final String? triggeredByUserId;
  final String createdAt;
  final String? resolutionNote;
  final String? resolvedByName;
  final double? latitude;
  final double? longitude;

  /// true nếu cảnh báo do chính [myUserId] phát.
  bool isMine(String? myUserId) =>
      myUserId != null && myUserId.isNotEmpty && triggeredByUserId == myUserId;

  const SosAlert({
    required this.id,
    required this.status,
    this.severity = 'HIGH',
    required this.message,
    required this.address,
    required this.senderName,
    this.triggeredByUserId,
    required this.createdAt,
    this.resolutionNote,
    this.resolvedByName,
    this.latitude,
    this.longitude,
  });

  bool get isActive => status == 'ACTIVE';
  bool get hasLocation => latitude != null && longitude != null;

  // userId nằm trong member.user.id (member.id là FamilyMember.id, KHÁC).
  static String? _memberUserId(dynamic m) {
    if (m is! Map) return null;
    final user = m['user'];
    if (user is Map) {
      final id = user['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return m['userId']?.toString();
  }

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
      senderName:
          _memberName(json['triggeredByMember']) ??
          _memberName(json['sender']) ??
          _memberName(json['triggeredBy']) ??
          json['senderName']?.toString() ??
          'Thành viên',
      // Swagger: triggeredByMember.user.id (verify 19/07).
      triggeredByUserId:
          _memberUserId(json['triggeredByMember']) ??
          _memberUserId(json['sender']) ??
          _memberUserId(json['triggeredBy']),
      createdAt:
          json['triggeredAt']?.toString() ??
          json['createdAt']?.toString() ??
          '',
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

/// Cài đặt SOS của gia đình — khớp UpdateSosSettingsDto (Swagger tuần 10).
/// GET /sos/settings không khai schema response, nên parse phòng thủ: field
/// thiếu thì dùng mặc định "bật" cho các cờ an toàn (an toàn hơn khi thiếu dữ
/// liệu là bật cảnh báo, không phải tắt).
class SosSettings {
  final bool isEnabled;
  final bool notifyAllMembers;
  final bool autoCreateAlertFromFall;
  final bool locationRequired;

  const SosSettings({
    this.isEnabled = true,
    this.notifyAllMembers = true,
    this.autoCreateAlertFromFall = false,
    this.locationRequired = true,
  });

  static bool _b(dynamic v, bool fallback) => v is bool ? v : fallback;

  factory SosSettings.fromJson(Map<String, dynamic> j) => SosSettings(
    isEnabled: _b(j['isEnabled'], true),
    notifyAllMembers: _b(j['notifyAllMembers'], true),
    autoCreateAlertFromFall: _b(j['autoCreateAlertFromFall'], false),
    locationRequired: _b(j['locationRequired'], true),
  );

  SosSettings copyWith({
    bool? isEnabled,
    bool? notifyAllMembers,
    bool? autoCreateAlertFromFall,
    bool? locationRequired,
  }) => SosSettings(
    isEnabled: isEnabled ?? this.isEnabled,
    notifyAllMembers: notifyAllMembers ?? this.notifyAllMembers,
    autoCreateAlertFromFall:
        autoCreateAlertFromFall ?? this.autoCreateAlertFromFall,
    locationRequired: locationRequired ?? this.locationRequired,
  );

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'notifyAllMembers': notifyAllMembers,
    'autoCreateAlertFromFall': autoCreateAlertFromFall,
    'locationRequired': locationRequired,
  };
}

class SosProvider extends ChangeNotifier {
  SosProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    stopRealtime();
    _alerts = [];
    _contacts = [];
    _settings = null;
    _settingsLoading = false;
    _loading = false;
    _sending = false;
    _error = null;
    _latestRealtimeLocations.clear();
    _responderLocationsByAlert.clear();
    notifyListeners();
  }

  // ── Danh bạ khẩn cấp ─────────────────────────────────────────────────────
  List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get emergencyContacts => _contacts;

  // ── Cài đặt SOS ───────────────────────────────────────────────────────────
  SosSettings? _settings;
  bool _settingsLoading = false;
  SosSettings? get settings => _settings;
  bool get settingsLoading => _settingsLoading;

  // GET /families/{familyId}/sos/settings
  Future<void> fetchSettings() async {
    final fid = _fid;
    if (fid == null) return;
    _settingsLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/sos/settings');
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      // BE có thể bọc trong { settings: {...} } hoặc trả phẳng.
      final inner = map['settings'] is Map
          ? Map<String, dynamic>.from(map['settings'] as Map)
          : map;
      _settings = SosSettings.fromJson(inner);
    } catch (e) {
      debugPrint('SosProvider: fetchSettings failed: $e');
    } finally {
      _settingsLoading = false;
      notifyListeners();
    }
  }

  // PATCH /families/{familyId}/sos/settings — cập nhật lạc quan: đổi UI ngay,
  // rollback nếu BE lỗi để công tắc không kẹt ở trạng thái sai.
  Future<void> updateSettings(SosSettings next) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final prev = _settings;
    _settings = next;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$fid/sos/settings',
        next.toJson(),
      );
    } catch (e) {
      _settings = prev;
      notifyListeners();
      rethrow;
    }
  }

  /// Số gọi nhanh hiển thị ở màn SOS: ưu tiên danh bạ gia đình (ACTIVE, theo
  /// priorityOrder); rỗng thì fallback hotline quốc gia.
  static const kDefaultHotlines = ['113', '115', '114'];

  Future<void> fetchEmergencyContacts() async {
    final fid = _fid;
    if (fid == null) return;
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/sos/emergency-contacts',
      );
      final raw = data is List
          ? data
          : (data is Map && data['items'] is List
                ? data['items']
                : <dynamic>[]);
      final list =
          (raw as List)
              .whereType<Map>()
              .map(
                (e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e)),
              )
              .where((c) => c.isActive && c.phoneNumber.isNotEmpty)
              .toList()
            ..sort(
              (a, b) =>
                  (a.priorityOrder ?? 9999).compareTo(b.priorityOrder ?? 9999),
            );
      _contacts = list;
      notifyListeners();
    } catch (e) {
      debugPrint('SosProvider: fetchEmergencyContacts failed: $e');
    }
  }

  Future<void> addEmergencyContact({
    required String contactName,
    required String phoneNumber,
    String? relationshipNote,
    int? priorityOrder,
    bool isActive = true,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final payload = <String, dynamic>{
      'contactName': contactName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'isActive': isActive,
    };
    if (relationshipNote != null && relationshipNote.trim().isNotEmpty) {
      payload['relationshipNote'] = relationshipNote.trim();
    }
    if (priorityOrder != null) payload['priorityOrder'] = priorityOrder;
    await ApiClient.instance.post(
      '/families/$fid/sos/emergency-contacts',
      payload,
    );
    await fetchEmergencyContacts();
  }

  Future<void> updateEmergencyContact(
    String contactId, {
    String? contactName,
    String? phoneNumber,
    String? relationshipNote,
    int? priorityOrder,
    bool? isActive,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final payload = <String, dynamic>{};
    if (contactName != null) payload['contactName'] = contactName.trim();
    if (phoneNumber != null) payload['phoneNumber'] = phoneNumber.trim();
    if (relationshipNote != null) {
      payload['relationshipNote'] = relationshipNote.trim();
    }
    if (priorityOrder != null) payload['priorityOrder'] = priorityOrder;
    if (isActive != null) payload['isActive'] = isActive;
    await ApiClient.instance.patch(
      '/families/$fid/sos/emergency-contacts/$contactId',
      payload,
    );
    await fetchEmergencyContacts();
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.delete(
      '/families/$fid/sos/emergency-contacts/$contactId',
    );
    await fetchEmergencyContacts();
  }

  List<SosAlert> _alerts = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  bool _realtimeOn = false;
  final Map<String, SosRealtimeLocation> _latestRealtimeLocations = {};
  final Map<String, Map<String, SosResponderLocation>>
  _responderLocationsByAlert = {};

  void Function(SosAlert alert)? onNewRealtimeAlert;
  void Function(String alertId, Map<String, dynamic> payload)?
  onRealtimeResolved;

  List<SosAlert> get alerts => _alerts;
  List<SosAlert> get activeAlerts => _alerts.where((a) => a.isActive).toList();
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;
  bool get realtimeConnected => SosRealtimeService.instance.connected;

  SosRealtimeLocation? realtimeLocationOf(String alertId) =>
      _latestRealtimeLocations[alertId];

  List<SosResponderLocation> responderLocationsFor(String alertId) {
    return List.unmodifiable(
      _responderLocationsByAlert[alertId]?.values ??
          const <SosResponderLocation>[],
    );
  }

  String? get _fid => ApiClient.instance.familyId;

  // ── Realtime (Socket.IO /sos) ────────────────────────────────────────────
  void startRealtime() {
    if (_realtimeOn) return;
    _realtimeOn = true;
    final svc = SosRealtimeService.instance;
    svc.onSnapshot = _applyRealtimeSnapshot;
    svc.onNewAlert = _applyRealtimeNewAlert;
    svc.onLocation = _applyRealtimeLocation;
    svc.onResponderLocation = _applyRealtimeResponderLocation;
    svc.onResolved = _applyRealtimeResolved;
    svc.onResponse = (_) => fetchAlerts(silent: true);
    svc.onKicked = _handleRealtimeKicked;
    svc.connect();
  }

  void stopRealtime() {
    if (!_realtimeOn) return;
    _realtimeOn = false;
    final svc = SosRealtimeService.instance;
    svc.onSnapshot = null;
    svc.onNewAlert = null;
    svc.onLocation = null;
    svc.onResponderLocation = null;
    svc.onResponse = null;
    svc.onResolved = null;
    svc.onKicked = null;
    svc.disconnect();
    _latestRealtimeLocations.clear();
    _responderLocationsByAlert.clear();
  }

  void _applyRealtimeSnapshot(
    Map<String, dynamic> alertJson,
    Map<String, dynamic>? lastLocation,
  ) {
    final alert = SosAlert.fromJson(alertJson);
    _upsertAlert(alert);
    final loc = _parseRealtimeLocation(lastLocation);
    if (alert.id.isNotEmpty && loc != null) {
      _latestRealtimeLocations[alert.id] = loc;
    }
    notifyListeners();
  }

  void _applyRealtimeNewAlert(Map<String, dynamic> alertJson) {
    final alert = SosAlert.fromJson(alertJson);
    _upsertAlert(alert);
    notifyListeners();
    if (alert.id.isNotEmpty) onNewRealtimeAlert?.call(alert);
  }

  void _applyRealtimeLocation(String alertId, Map<String, dynamic> point) {
    final loc = _parseRealtimeLocation(point);
    if (loc == null) return;
    _latestRealtimeLocations[alertId] = loc;
    notifyListeners();
  }

  void _applyRealtimeResponderLocation(SosResponderLocationEvent event) {
    final loc = _parseRealtimeLocation(event.point);
    if (loc == null) {
      // Chỗ nuốt event nguy hiểm nhất: BE bắn đúng nhưng tên field toạ độ lệch
      // thì marker không bao giờ hiện mà không có lỗi nào.
      sosResponderLog(
        'PARSE THẤT BẠI point=${event.point} — không đọc được latitude/lat '
        'hoặc longitude/lng, bỏ qua event',
      );
      return;
    }
    final displayName =
        SosAlert._memberName(event.responderMember) ??
        event.responderMember['displayName']?.toString() ??
        'Đang tới';
    final user = event.responderMember['user'];
    final avatarUrl =
        event.responderMember['avatarUrl']?.toString() ??
        (user is Map ? user['avatarUrl']?.toString() : null);
    final perAlert = Map<String, SosResponderLocation>.from(
      _responderLocationsByAlert[event.sosAlertId] ?? const {},
    );
    perAlert[event.responderMemberId] = SosResponderLocation(
      alertId: event.sosAlertId,
      responderMemberId: event.responderMemberId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      location: loc,
    );
    _responderLocationsByAlert[event.sosAlertId] = perAlert;
    sosResponderLog(
      'LƯU STATE alertId=${event.sosAlertId} responder="$displayName" '
      'lat=${loc.lat} lng=${loc.lng} → responderLocationsFor().length='
      '${perAlert.length}',
    );
    notifyListeners();
  }

  void _applyRealtimeResolved(String alertId, Map<String, dynamic> payload) {
    _latestRealtimeLocations.remove(alertId);
    _responderLocationsByAlert.remove(alertId);
    final status = payload['status']?.toString() ?? 'RESOLVED';
    _alerts = [
      for (final alert in _alerts)
        if (alert.id == alertId)
          SosAlert(
            id: alert.id,
            status: status,
            severity: alert.severity,
            message: alert.message,
            address: alert.address,
            senderName: alert.senderName,
            triggeredByUserId: alert.triggeredByUserId,
            createdAt: alert.createdAt,
            resolutionNote:
                payload['resolutionNote']?.toString() ?? alert.resolutionNote,
            resolvedByName: alert.resolvedByName,
            latitude: alert.latitude,
            longitude: alert.longitude,
          )
        else
          alert,
    ];
    notifyListeners();
    onRealtimeResolved?.call(alertId, payload);
  }

  void _handleRealtimeKicked(String workspaceId) {
    if (_fid != null && workspaceId != _fid) return;
    _realtimeOn = false;
    _latestRealtimeLocations.clear();
    _responderLocationsByAlert.clear();
    notifyListeners();
  }

  @visibleForTesting
  void debugApplyResponderLocation(Map<String, dynamic> payload) {
    _applyRealtimeResponderLocation(
      SosResponderLocationEvent.fromJson(payload),
    );
  }

  @visibleForTesting
  void debugApplyResolved(String alertId) {
    _applyRealtimeResolved(alertId, {'status': 'RESOLVED'});
  }

  void _upsertAlert(SosAlert alert) {
    if (alert.id.isEmpty) return;
    final i = _alerts.indexWhere((a) => a.id == alert.id);
    if (i == -1) {
      _alerts = [alert, ..._alerts];
      return;
    }
    _alerts = [
      for (var index = 0; index < _alerts.length; index++)
        index == i ? alert : _alerts[index],
    ];
  }

  SosRealtimeLocation? _parseRealtimeLocation(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = _doubleOf(json['latitude'] ?? json['lat']);
    final lng = _doubleOf(json['longitude'] ?? json['lng']);
    if (lat == null || lng == null) return null;
    return (
      lat: lat,
      lng: lng,
      accuracy: _doubleOf(json['accuracy']),
      sourceType: json['sourceType']?.toString(),
      recordedAt: DateTime.tryParse(
        json['recordedAt']?.toString() ?? json['createdAt']?.toString() ?? '',
      ),
      deviceId: json['deviceId']?.toString(),
    );
  }

  static double? _doubleOf(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // GET /families/{familyId}/sos/alerts
  Future<void> fetchAlerts({bool silent = false}) async {
    final fid = _fid;
    if (fid == null) return;
    if (!silent) _loading = true;
    _error = null;
    if (!silent) notifyListeners();
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
      final activeIds = _alerts
          .where((a) => a.isActive)
          .map((a) => a.id)
          .toSet();
      _responderLocationsByAlert.removeWhere(
        (alertId, _) => !activeIds.contains(alertId),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('SosProvider: fetchAlerts failed: $e');
    } finally {
      if (!silent) _loading = false;
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
    String sourceType = 'MOBILE_APP',
    String triggerReason = 'MANUAL',
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      // address KHÔNG nằm trong CreateSosAlertDto theo API_DOCS — không gửi
      // vì backend có thể bật forbidNonWhitelisted và trả 400 cho field lạ.
      // triggerReason: BE default là MANUAL nếu không truyền, nhưng truyền
      // tường minh để dễ debug và khớp contract mới (2026-08-18).
      final created = await ApiClient.instance
          .post('/families/$fid/sos/alerts', {
            'sourceType': sourceType,
            'triggerReason': triggerReason,
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
  Future<void> resolveAlert(
    String alertId, {
    String? resolutionNote,
    bool isFalseAlarm = false,
  }) => _patchAlert(
    alertId,
    'resolve',
    resolutionNote,
    isFalseAlarm: isFalseAlarm,
  );

  // PATCH /families/{familyId}/sos/alerts/{alertId}/cancel — chỉ
  // FAMILY_MANAGER / DEPUTY_MEMBER.
  Future<void> cancelAlert(String alertId, {String? resolutionNote}) =>
      _patchAlert(alertId, 'cancel', resolutionNote);

  Future<void> _patchAlert(
    String alertId,
    String action,
    String? resolutionNote, {
    bool isFalseAlarm = false,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance
          .patch('/families/$fid/sos/alerts/$alertId/$action', {
            if (resolutionNote != null && resolutionNote.isNotEmpty)
              'resolutionNote': resolutionNote,
            if (action == 'resolve' && isFalseAlarm) 'isFalseAlarm': true,
          });
      _responderLocationsByAlert.remove(alertId);
      await fetchAlerts();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/sos/alerts/{alertId}/responses — thành viên
  // khác phản hồi cảnh báo. Enum BE (verify 19/07): VIEWED | ON_THE_WAY |
  // CONFIRM_SAFE | NEED_HELP (RESOLVED/CANCELED do manager qua endpoint riêng).
  Future<void> respond(
    String alertId,
    String responseType, {
    String? message,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    _ensureNoActionInProgress();
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance
          .post('/families/$fid/sos/alerts/$alertId/responses', {
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
      await ApiClient.instance.post(
        '/families/$fid/sos/alerts/$alertId/confirm-safety',
        {},
      );
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
  /// [sourceType] theo `PushSosLocationDto`: `MOBILE_GPS | WEARABLE_GPS |
  /// SIMULATED_GPS`. Đồng hồ phải gửi `WEARABLE_GPS` kèm [deviceId] để người
  /// nhận phân biệt được điểm nào do thiết bị đeo báo về.
  Future<bool> pushLocation(
    String alertId,
    double latitude,
    double longitude, {
    double? accuracy,
    String sourceType = 'MOBILE_GPS',
    String? deviceId,
  }) async {
    final fid = _fid;
    if (fid == null) return false;
    try {
      await ApiClient.instance
          .post('/families/$fid/sos/alerts/$alertId/locations', {
            'latitude': latitude,
            'longitude': longitude,
            'sourceType': sourceType,
            'accuracy': ?accuracy,
            'deviceId': ?deviceId,
          });
      return true;
    } catch (e) {
      debugPrint('SosProvider: pushLocation failed: $e');
      return false;
    }
  }

  bool pushLocationRealtime(
    String alertId,
    double latitude,
    double longitude, {
    double? accuracy,
    String sourceType = 'MOBILE_GPS',
    String? deviceId,
    DateTime? recordedAt,
  }) {
    final fid = _fid;
    if (fid == null || fid.isEmpty) return false;
    return SosRealtimeService.instance.pushLocation(
      workspaceId: fid,
      alertId: alertId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      sourceType: sourceType,
      recordedAt: recordedAt,
      deviceId: deviceId,
    );
  }

  bool pushResponderLocationRealtime(
    String alertId,
    double latitude,
    double longitude, {
    double? accuracy,
    String sourceType = 'MOBILE_GPS',
    DateTime? recordedAt,
  }) {
    final fid = _fid;
    if (fid == null || fid.isEmpty) return false;
    return SosRealtimeService.instance.pushResponderLocation(
      workspaceId: fid,
      alertId: alertId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      sourceType: sourceType,
      recordedAt: recordedAt,
    );
  }

  // GET .../sos/alerts/{alertId}/location/current — vị trí MỚI NHẤT của alert
  // (BE bổ sung 2026-07-10, dành cho người theo dõi vừa vào xem). Trả null nếu
  // alert chưa có điểm vị trí nào hoặc gọi lỗi — caller tự fallback.
  Future<({double lat, double lng, String? sourceType})?> fetchCurrentLocation(
    String alertId,
  ) async {
    final realtime = _latestRealtimeLocations[alertId];
    if (realtime != null) {
      return (
        lat: realtime.lat,
        lng: realtime.lng,
        sourceType: realtime.sourceType,
      );
    }
    final fid = _fid;
    if (fid == null) return null;
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/sos/alerts/$alertId/location/current',
      );
      if (data is Map) {
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          return (
            lat: lat,
            lng: lng,
            sourceType: data['sourceType']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('SosProvider: fetchCurrentLocation failed: $e');
    }
    return null;
  }

  // POST .../sos/alerts/{alertId}/locations/batch — gửi nhiều điểm vị trí một
  // lần (BE bổ sung 2026-07-10; thiết bị buffer khi offline rồi flush — dành
  // cho Wear OS / mất mạng tạm thời). Trả `bool` như `pushLocation` để caller
  // biết flush thành công hay chưa (còn giữ buffer để thử lại lần sau).
  Future<bool> pushLocationBatch(
    String alertId,
    List<({double lat, double lng, double? accuracy, DateTime? recordedAt})>
    points, {
    String sourceType = 'MOBILE_GPS',
  }) async {
    final fid = _fid;
    if (fid == null || points.isEmpty) return false;
    try {
      await ApiClient.instance.post(
        '/families/$fid/sos/alerts/$alertId/locations/batch',
        {
          'points': [
            for (final p in points)
              {
                'latitude': p.lat,
                'longitude': p.lng,
                'sourceType': sourceType,
                if (p.accuracy != null) 'accuracy': p.accuracy,
                if (p.recordedAt != null)
                  'recordedAt': p.recordedAt!.toUtc().toIso8601String(),
              },
          ],
        },
      );
      return true;
    } catch (e) {
      debugPrint('SosProvider: pushLocationBatch failed: $e');
      return false;
    }
  }

  // GET /families/{familyId}/sos/alerts/{alertId} — chi tiết 1 alert (kèm
  // phản hồi + vị trí, theo mô tả API_DOCS.md). List hiện tại đủ cho UI
  // chính, gọi thêm khi cần xem đầy đủ responses/locations lịch sử.
  Future<Map<String, dynamic>> fetchAlertDetail(String alertId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.get(
      '/families/$fid/sos/alerts/$alertId',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  void _ensureNoActionInProgress() {
    if (_sending) {
      throw Exception('Một thao tác SOS khác đang được xử lý, vui lòng chờ.');
    }
  }
}
