import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

String _str(dynamic v) => v?.toString() ?? '';
bool _bool(dynamic v) => v == true;
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Thiết bị đeo đã ghép với gia đình. Response schema của GET/POST wearables
/// để trống trong Swagger tuần 10 → parse phòng thủ, chấp nhận nhiều alias key.
class WearableDevice {
  final String id;
  final String deviceName;
  final String
  deviceType; // SMARTWATCH | GPS_TRACKER | BLE_DEVICE | SIMULATED_DEVICE
  final String deviceIdentifier;
  final bool gpsEnabled;
  final bool sosEnabled;
  final String pairingStatus; // PAIRED | UNPAIRED | LOST
  final String? ownerMemberId;
  final String? ownerName;
  final DateTime? lastSeenAt;
  final Map<String, dynamic> raw;

  const WearableDevice({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.deviceIdentifier,
    this.gpsEnabled = false,
    this.sosEnabled = false,
    this.pairingStatus = 'PAIRED',
    this.ownerMemberId,
    this.ownerName,
    this.lastSeenAt,
    this.raw = const {},
  });

  bool get isPaired => pairingStatus.toUpperCase() == 'PAIRED';
  bool get isLost => pairingStatus.toUpperCase() == 'LOST';

  factory WearableDevice.fromJson(Map<String, dynamic> j) {
    final owner = j['ownerMember'] is Map
        ? Map<String, dynamic>.from(j['ownerMember'] as Map)
        : const <String, dynamic>{};
    final ownerUser = owner['user'] is Map
        ? Map<String, dynamic>.from(owner['user'] as Map)
        : const <String, dynamic>{};
    return WearableDevice(
      id: _str(j['deviceId'] ?? j['id']),
      deviceName: _str(j['deviceName']).isEmpty
          ? 'Thiết bị'
          : _str(j['deviceName']),
      deviceType: _str(j['deviceType']).isEmpty
          ? 'SMARTWATCH'
          : _str(j['deviceType']),
      deviceIdentifier: _str(j['deviceIdentifier']),
      gpsEnabled: _bool(j['gpsEnabled']),
      sosEnabled: _bool(j['sosEnabled']),
      pairingStatus: _str(j['pairingStatus']).isEmpty
          ? 'PAIRED'
          : _str(j['pairingStatus']),
      ownerMemberId: _str(j['ownerMemberId'] ?? owner['id']).isEmpty
          ? null
          : _str(j['ownerMemberId'] ?? owner['id']),
      ownerName:
          _str(
            owner['displayName'] ?? ownerUser['fullName'] ?? j['ownerName'],
          ).isEmpty
          ? null
          : _str(
              owner['displayName'] ?? ownerUser['fullName'] ?? j['ownerName'],
            ),
      lastSeenAt: _date(j['lastSeenAt'] ?? j['lastEventAt']),
      raw: j,
    );
  }
}

/// Sự kiện cảm biến từ thiết bị đeo (té ngã, va đập, nút SOS...).
class WearableEvent {
  final String id;
  final String
  eventType; // SOS_BUTTON_PRESSED | FALL_DETECTED | HARD_IMPACT | ABNORMAL_MOVEMENT
  final String severity; // LOW | MEDIUM | HIGH | CRITICAL
  final DateTime? detectedAt;

  const WearableEvent({
    required this.id,
    required this.eventType,
    this.severity = 'LOW',
    this.detectedAt,
  });

  factory WearableEvent.fromJson(Map<String, dynamic> j) => WearableEvent(
    id: _str(j['eventId'] ?? j['id']),
    eventType: _str(j['eventType']),
    severity: _str(j['severity']).isEmpty ? 'LOW' : _str(j['severity']),
    detectedAt: _date(j['detectedAt'] ?? j['createdAt']),
  );
}

class WearableProvider extends ChangeNotifier {
  List<WearableDevice> _devices = [];
  bool _loading = false;
  String? _error;

  List<WearableDevice> get devices => _devices;
  bool get loading => _loading;
  String? get error => _error;

  String? get _fid => ApiClient.instance.familyId;

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : (data is Map && data['items'] is List
              ? data['items'] as List
              : (data is Map && data['data'] is List
                    ? data['data'] as List
                    : <dynamic>[]));
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // GET /families/{familyId}/wearables
  Future<void> fetchDevices() async {
    final fid = _fid;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/wearables');
      _devices = _list(
        data,
      ).map(WearableDevice.fromJson).where((d) => d.id.isNotEmpty).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // POST /families/{familyId}/wearables
  Future<void> pairDevice({
    required String deviceName,
    required String deviceType,
    required String deviceIdentifier,
    bool gpsEnabled = true,
    bool sosEnabled = true,
    String? ownerMemberId,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$fid/wearables', {
      'deviceName': deviceName.trim(),
      'deviceType': deviceType,
      'deviceIdentifier': deviceIdentifier.trim(),
      'gpsEnabled': gpsEnabled,
      'sosEnabled': sosEnabled,
      if (ownerMemberId != null && ownerMemberId.isNotEmpty)
        'ownerMemberId': ownerMemberId,
    });
    await fetchDevices();
  }

  // PATCH /families/{familyId}/wearables/{deviceId}
  Future<void> updateDevice(
    String deviceId, {
    String? deviceName,
    bool? gpsEnabled,
    bool? sosEnabled,
    String? pairingStatus,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    // Cập nhật lạc quan cờ gps/sos cho công tắc mượt, rollback nếu BE lỗi.
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    final prev = idx >= 0 ? _devices[idx] : null;
    if (prev != null && (gpsEnabled != null || sosEnabled != null)) {
      _devices[idx] = WearableDevice.fromJson({
        ...prev.raw,
        'deviceId': prev.id,
        'gpsEnabled': gpsEnabled ?? prev.gpsEnabled,
        'sosEnabled': sosEnabled ?? prev.sosEnabled,
      });
      notifyListeners();
    }
    try {
      await ApiClient.instance.patch('/families/$fid/wearables/$deviceId', {
        if (deviceName != null) 'deviceName': deviceName.trim(),
        'gpsEnabled': ?gpsEnabled,
        'sosEnabled': ?sosEnabled,
        'pairingStatus': ?pairingStatus,
      });
      await fetchDevices();
    } catch (e) {
      if (prev != null && idx >= 0) {
        _devices[idx] = prev;
        notifyListeners();
      }
      rethrow;
    }
  }

  // DELETE /families/{familyId}/wearables/{deviceId}
  Future<void> unpairDevice(String deviceId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.delete('/families/$fid/wearables/$deviceId');
    _devices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
  }

  // GET /families/{familyId}/wearables/{deviceId}/events
  Future<List<WearableEvent>> fetchEvents(String deviceId) async {
    final fid = _fid;
    if (fid == null) return [];
    final data = await ApiClient.instance.get(
      '/families/$fid/wearables/$deviceId/events',
    );
    return _list(data)
        .map(WearableEvent.fromJson)
        .where((e) => e.id.isNotEmpty || e.eventType.isNotEmpty)
        .toList();
  }

  // POST /families/{familyId}/wearables/{deviceId}/events — thường do thiết bị
  // gửi lên; giữ ở đây để test với SIMULATED_DEVICE. Chưa gắn UI.
  Future<void> createEvent(
    String deviceId, {
    required String eventType,
    String? severity,
    Map<String, dynamic>? rawValue,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$fid/wearables/$deviceId/events', {
      'eventType': eventType,
      'severity': ?severity,
      'rawValue': ?rawValue,
      'detectedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
