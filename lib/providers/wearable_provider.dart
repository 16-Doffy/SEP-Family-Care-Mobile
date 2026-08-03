import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

String _str(dynamic v) => v?.toString() ?? '';
bool _bool(dynamic v) => v == true;
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class WearableDevice {
  final String id;
  final String deviceName;
  final String deviceType;
  final String deviceIdentifier;
  final bool gpsEnabled;
  final bool sosEnabled;
  final String pairingStatus;
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
          ? 'Thiết bị đeo'
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
      lastSeenAt: _date(j['lastSeenAt'] ?? j['lastEventAt'] ?? j['updatedAt']),
      raw: j,
    );
  }
}

class WearableEvent {
  final String id;
  final String eventType;
  final String severity;
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

class WearableEventResult {
  final WearableEvent? event;
  final String? alertId;
  final bool alertCreated;
  final Map<String, dynamic> raw;

  const WearableEventResult({
    this.event,
    this.alertId,
    this.alertCreated = false,
    this.raw = const {},
  });

  factory WearableEventResult.fromJson(Map<String, dynamic> j) {
    final rawEvent = j['event'];
    return WearableEventResult(
      event: rawEvent is Map
          ? WearableEvent.fromJson(Map<String, dynamic>.from(rawEvent))
          : null,
      alertId: _str(j['alertId']).isEmpty ? null : _str(j['alertId']),
      alertCreated: j['alertCreated'] == true,
      raw: j,
    );
  }
}

class WearableProvider extends ChangeNotifier {
  WearableDevice? _currentDevice;
  List<WearableDevice> _familyDevices = [];
  bool _loading = false;
  String? _error;

  WearableDevice? get currentDevice => _currentDevice;
  List<WearableDevice> get devices =>
      _currentDevice == null ? const [] : [_currentDevice!];
  List<WearableDevice> get familyDevices => _familyDevices;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConnected => _currentDevice?.isPaired == true;

  String? get _fid => ApiClient.instance.familyId;

  static const duplicateWearableMessage =
      'Tài khoản này đã kết nối một wearable. Vui lòng ngắt kết nối thiết bị hiện tại trước.';

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

  static WearableDevice? _deviceFrom(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['wearable'] ?? map['device'];
      if (nested is Map) return WearableDevice.fromJson(Map.from(nested));
      return WearableDevice.fromJson(map);
    }
    return null;
  }

  Future<void> fetchCurrentDevice() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/wearables/me');
      _currentDevice = _deviceFrom(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDevices() => fetchCurrentDevice();

  Future<List<WearableDevice>> fetchFamilyDevices() async {
    final fid = _fid;
    if (fid == null) return const [];
    final data = await ApiClient.instance.get('/families/$fid/wearables');
    _familyDevices = _list(
      data,
    ).map(WearableDevice.fromJson).where((d) => d.id.isNotEmpty).toList();
    notifyListeners();
    return _familyDevices;
  }

  Future<WearableDevice?> pairDevice({
    required String deviceName,
    required String deviceType,
    required String deviceIdentifier,
    bool gpsEnabled = true,
    bool sosEnabled = true,
    String? ownerMemberId,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    try {
      final data = await ApiClient.instance.post('/families/$fid/wearables', {
        'deviceName': deviceName.trim(),
        'deviceType': deviceType,
        'deviceIdentifier': deviceIdentifier.trim(),
        'gpsEnabled': gpsEnabled,
        'sosEnabled': sosEnabled,
        if (ownerMemberId != null && ownerMemberId.isNotEmpty)
          'ownerMemberId': ownerMemberId,
      });
      _currentDevice = _deviceFrom(data);
      if (_currentDevice == null) await fetchCurrentDevice();
      notifyListeners();
      return _currentDevice;
    } on ApiException catch (e) {
      if (e.statusCode == 409) throw Exception(duplicateWearableMessage);
      rethrow;
    }
  }

  Future<void> updateDevice(
    String deviceId, {
    String? deviceName,
    bool? gpsEnabled,
    bool? sosEnabled,
    String? pairingStatus,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final prev = _currentDevice;
    final cleanDeviceName = deviceName?.trim();
    if (prev != null && prev.id == deviceId) {
      _currentDevice = WearableDevice.fromJson({
        ...prev.raw,
        'deviceId': prev.id,
        'deviceName': ?cleanDeviceName,
        'gpsEnabled': ?gpsEnabled,
        'sosEnabled': ?sosEnabled,
        'pairingStatus': ?pairingStatus,
      });
      notifyListeners();
    }
    try {
      final data = await ApiClient.instance
          .patch('/families/$fid/wearables/$deviceId', {
            'deviceName': ?cleanDeviceName,
            'gpsEnabled': ?gpsEnabled,
            'sosEnabled': ?sosEnabled,
            'pairingStatus': ?pairingStatus,
          });
      _currentDevice = pairingStatus == 'UNPAIRED' ? null : _deviceFrom(data);
      if (_currentDevice == null && pairingStatus != 'UNPAIRED') {
        await fetchCurrentDevice();
      }
      notifyListeners();
    } catch (e) {
      _currentDevice = prev;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unpairDevice(String deviceId) async {
    await updateDevice(deviceId, pairingStatus: 'UNPAIRED');
  }

  Future<void> removeDevice(String deviceId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.delete('/families/$fid/wearables/$deviceId');
    if (_currentDevice?.id == deviceId) _currentDevice = null;
    _familyDevices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
  }

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

  Future<WearableEventResult> createEvent(
    String deviceId, {
    required String eventType,
    String? severity,
    Map<String, dynamic>? rawValue,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance
        .post('/families/$fid/wearables/$deviceId/events', {
          'eventType': eventType,
          'severity': ?severity,
          'rawValue': ?rawValue,
          'detectedAt': DateTime.now().toUtc().toIso8601String(),
        });
    return WearableEventResult.fromJson(data);
  }
}
