import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Chỉ dùng khi BE trả 409 mà **không kèm message** — không được đè lên
  /// message thật của BE (trước đây mọi 409 đều bị thay bằng câu cứng, nên
  /// không ai đọc được BE thực sự báo gì).
  ///
  /// Quy tắc BE: **một tài khoản chỉ được có một wearable đang PAIRED**. Bản ghi
  /// `UNPAIRED` **không** chiếm chỗ — BE xác nhận ghép lại cùng
  /// `deviceIdentifier` cũ sẽ pair lại chính record đó, còn identifier mới thì
  /// tạo record mới. Vì vậy 409 nghĩa là **thực sự vẫn còn một record PAIRED**,
  /// tức lần gỡ trước chưa thành công trên server.
  static const duplicateWearableMessage =
      'Tài khoản này vẫn còn một wearable đang kết nối trên máy chủ. '
      'Hãy ngắt kết nối thiết bị đó rồi thử lại.';

  static const _storage = FlutterSecureStorage();
  static const _identifierKey = 'wearable_device_identifier';

  /// Mã định danh **riêng cho từng bản cài app**, tạo một lần rồi giữ nguyên.
  ///
  /// `PairWearableDto.deviceIdentifier` được BE mô tả là "unique within a
  /// family", trong khi FE trước đây gửi hằng số `wearos-emulator-001` cho mọi
  /// máy. Đây **không phải** nguyên nhân của lỗi 409 hiện tại (nguyên nhân là
  /// quy tắc một-tài-khoản-một-wearable, xem [duplicateWearableMessage]), nhưng
  /// hai máy trong cùng một gia đình mà gửi trùng identifier là sai contract —
  /// giữ mã riêng để không đụng ràng buộc đó về sau.
  static Future<String> deviceIdentifier() async {
    final saved = await _storage.read(key: _identifierKey);
    if (saved != null && saved.isNotEmpty) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final suffix = List.generate(
      10,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
    final id = 'familycare-$suffix';
    await _storage.write(key: _identifierKey, value: id);
    return id;
  }

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
      // Giữ message thật của BE (ApiClient.toString() trả đúng message BE, đã
      // là tiếng Việt) — chỉ thay khi BE không nói gì.
      if (e.statusCode == 409 && e.message.trim().isEmpty) {
        throw Exception(duplicateWearableMessage);
      }
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
    // Cập nhật lạc quan chỉ dành cho các thay đổi nhẹ (đổi tên, bật/tắt GPS/SOS).
    // Với gỡ ghép nối thì KHÔNG: đây là thao tác mà việc hiển thị sai trạng thái
    // khiến người dùng kẹt (tưởng đã gỡ, ghép lại thì 409).
    if (pairingStatus != 'UNPAIRED' && prev != null && prev.id == deviceId) {
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
      if (pairingStatus == 'UNPAIRED') {
        // KHÔNG tự kết luận "đã gỡ" từ phía client. Trước đây dòng này gán thẳng
        // `_currentDevice = null` theo trạng thái ĐƯỢC YÊU CẦU, bỏ qua response
        // của BE — nên nếu PATCH không thực sự áp dụng thì UI vẫn hiện "Chưa kết
        // nối" trong khi BE còn record PAIRED, và lần ghép sau nhận 409 mà người
        // dùng không hiểu vì sao. Lấy GET /wearables/me làm nguồn sự thật.
        await fetchCurrentDevice();
        if (_currentDevice != null && _currentDevice!.isPaired) {
          throw Exception(
            'Máy chủ vẫn ghi nhận thiết bị đang kết nối. Chưa gỡ được, '
            'vui lòng thử lại.',
          );
        }
      } else {
        _currentDevice = _deviceFrom(data);
        if (_currentDevice == null) await fetchCurrentDevice();
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
