import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

/// Log TẠM để dò luồng "responder đang tới" đầu-cuối (thêm 2026-08-17).
///
/// Gắn một nhãn duy nhất để lọc log bằng đúng một lệnh:
/// `adb logcat | grep SOS-RESPONDER`
///
/// Chỉ chạy ở debug — bản release không được đẩy toạ độ GPS vào logcat.
///
/// XÓA TOÀN BỘ sau khi chốt được nguyên nhân: xóa hàm này rồi xóa mọi nơi gọi
/// (grep `sosResponderLog` là ra hết).
void sosResponderLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[SOS-RESPONDER] $message');
}

class SosTrackStartEvent {
  const SosTrackStartEvent({
    required this.alertId,
    required this.workspaceId,
    required this.intervalSec,
  });

  final String alertId;
  final String workspaceId;
  final int intervalSec;

  factory SosTrackStartEvent.fromJson(Map<String, dynamic> json) {
    return SosTrackStartEvent(
      alertId:
          json['alertId']?.toString() ??
          json['sosAlertId']?.toString() ??
          json['id']?.toString() ??
          '',
      workspaceId:
          json['workspaceId']?.toString() ??
          json['familyId']?.toString() ??
          ApiClient.instance.familyId ??
          '',
      intervalSec: (json['intervalSec'] as num?)?.toInt() ?? 5,
    );
  }
}

class SosResponderLocationEvent {
  const SosResponderLocationEvent({
    required this.sosAlertId,
    required this.responderMemberId,
    required this.responderMember,
    required this.point,
  });

  final String sosAlertId;
  final String responderMemberId;
  final Map<String, dynamic> responderMember;
  final Map<String, dynamic> point;

  factory SosResponderLocationEvent.fromJson(Map<String, dynamic> json) {
    final member = SosRealtimeService.asMap(json['responderMember']);
    return SosResponderLocationEvent(
      sosAlertId:
          json['sosAlertId']?.toString() ??
          json['alertId']?.toString() ??
          json['id']?.toString() ??
          '',
      responderMemberId:
          json['responderMemberId']?.toString() ??
          member?['id']?.toString() ??
          '',
      responderMember: member ?? const <String, dynamic>{},
      point: SosRealtimeService.asMap(json['point']) ?? json,
    );
  }
}

/// Transport Socket.IO cho namespace `/sos`.
///
/// Chỉ lo kết nối/auth/join/emit/nhận event thô. State nghiệp vụ nằm trong
/// `SosProvider` và màn SOS/Map. Namespace này tách biệt với `/notifications`.
class SosRealtimeService {
  SosRealtimeService._();
  static final SosRealtimeService instance = SosRealtimeService._();

  io.Socket? _socket;
  bool _wantConnected = false;
  Timer? _retryTimer;
  int _retryMs = 2000;

  bool get connected => _socket?.connected ?? false;

  void Function(Map<String, dynamic> alert, Map<String, dynamic>? lastLocation)?
  onSnapshot;
  void Function(Map<String, dynamic> alert)? onNewAlert;
  void Function(String alertId, Map<String, dynamic> point)? onLocation;
  void Function(Map<String, dynamic> payload)? onResponse;
  void Function(String alertId, Map<String, dynamic> payload)? onResolved;
  void Function(SosTrackStartEvent event)? onTrackStart;
  void Function(String alertId)? onTrackStop;
  void Function(SosTrackStartEvent event)? onResponderTrackStart;
  void Function(String alertId)? onResponderTrackStop;
  void Function(SosResponderLocationEvent event)? onResponderLocation;
  void Function(String workspaceId)? onKicked;
  void Function(String message)? onError;

  @visibleForTesting
  static const responderTrackStartEventName = 'sos:responder:track:start';

  @visibleForTesting
  static const responderTrackStopEventName = 'sos:responder:track:stop';

  @visibleForTesting
  static const responderLocationEventName = 'sos:responder:location';

  @visibleForTesting
  static const responderLocationPushEventName = 'sos:responder:location:push';

  void connect() {
    _wantConnected = true;
    _retryTimer?.cancel();
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) return;

    final existing = _socket;
    if (existing != null && existing.connected) {
      _join(existing);
      return;
    }

    _teardownSocket();
    final s = io.io(
      '${ApiClient.origin}/sos',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableReconnection()
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      _retryMs = 2000;
      _join(s);
    });

    s.on('sos:snapshot', (data) {
      final m = _asMap(data);
      if (m == null) return;
      final alert = _asMap(m['alert']);
      if (alert == null) return;
      onSnapshot?.call(alert, _asMap(m['lastLocation']));
    });
    s.on('sos:new', (data) {
      final m = _asMap(data);
      if (m == null) return;
      onNewAlert?.call(_asMap(m['alert']) ?? m);
    });
    s.on('sos:location', (data) {
      final m = _asMap(data);
      if (m == null) return;
      final alertId =
          m['sosAlertId']?.toString() ??
          m['alertId']?.toString() ??
          m['id']?.toString() ??
          '';
      final point = _asMap(m['point']) ?? m;
      if (alertId.isNotEmpty) onLocation?.call(alertId, point);
    });
    s.on('sos:response', (data) {
      final m = _asMap(data);
      if (m != null) onResponse?.call(m);
    });
    s.on('sos:resolved', (data) {
      final m = _asMap(data);
      if (m == null) return;
      final alertId =
          m['sosAlertId']?.toString() ??
          m['alertId']?.toString() ??
          m['id']?.toString() ??
          '';
      if (alertId.isNotEmpty) onResolved?.call(alertId, m);
    });
    s.on('sos:track:start', (data) {
      final m = _asMap(data);
      if (m != null) onTrackStart?.call(SosTrackStartEvent.fromJson(m));
    });
    s.on('sos:track:stop', (data) {
      final m = _asMap(data);
      final alertId =
          m?['alertId']?.toString() ??
          m?['sosAlertId']?.toString() ??
          m?['id']?.toString() ??
          '';
      if (alertId.isNotEmpty) onTrackStop?.call(alertId);
    });
    s.on(responderTrackStartEventName, (data) {
      final m = _asMap(data);
      sosResponderLog(
        'NHẬN track:start '
        '${m == null ? 'payload KHÔNG PHẢI Map: $data' : 'alertId=${m['alertId']} intervalSec=${m['intervalSec']}'}'
        ' | listener gắn=${onResponderTrackStart != null}',
      );
      if (m != null) {
        onResponderTrackStart?.call(SosTrackStartEvent.fromJson(m));
      }
    });
    s.on(responderTrackStopEventName, (data) {
      final m = _asMap(data);
      final alertId =
          m?['alertId']?.toString() ??
          m?['sosAlertId']?.toString() ??
          m?['id']?.toString() ??
          '';
      sosResponderLog(
        'NHẬN track:stop alertId=$alertId'
        ' | listener gắn=${onResponderTrackStop != null}',
      );
      if (alertId.isNotEmpty) onResponderTrackStop?.call(alertId);
    });
    s.on(responderLocationEventName, (data) {
      final m = _asMap(data);
      if (m == null) {
        sosResponderLog(
          'NHẬN responder:location nhưng payload không phải Map: $data',
        );
        return;
      }
      final event = SosResponderLocationEvent.fromJson(m);
      sosResponderLog(
        'NHẬN responder:location keys=${m.keys.toList()} '
        'sosAlertId="${event.sosAlertId}" responderMemberId="${event.responderMemberId}" '
        'point=${event.point} | listener gắn=${onResponderLocation != null}',
      );
      if (event.sosAlertId.isEmpty || event.responderMemberId.isEmpty) {
        // Bỏ qua ở đây là một trong hai chỗ event "biến mất" không dấu vết.
        sosResponderLog(
          'BỎ QUA responder:location vì thiếu sosAlertId hoặc responderMemberId',
        );
        return;
      }
      onResponderLocation?.call(event);
    });
    s.on('sos:kicked', (data) {
      final workspaceId =
          _asMap(data)?['workspaceId']?.toString() ??
          ApiClient.instance.familyId ??
          '';
      if (workspaceId.isNotEmpty) onKicked?.call(workspaceId);
      disconnect();
    });
    s.on('sos:error', (data) {
      final msg = (_asMap(data)?['message']?.toString()) ?? 'Lỗi realtime SOS';
      debugPrint('SosSocket: error $msg');
      onError?.call(msg);
      _scheduleRetry();
    });
    s.onConnectError((e) {
      debugPrint('SosSocket: connect_error $e');
      _scheduleRetry();
    });
    s.onDisconnect((_) {
      debugPrint('SosSocket: disconnected');
      _scheduleRetry();
    });

    _socket = s;
    s.connect();
  }

  void _join(io.Socket s) {
    final workspaceId = ApiClient.instance.familyId;
    if (workspaceId == null || workspaceId.isEmpty) {
      debugPrint('SosSocket: connected nhưng chưa có workspaceId');
      return;
    }
    s.emit('sos:join', {'workspaceId': workspaceId});
    debugPrint('SosSocket: connected + sos:join workspaceId=$workspaceId');
  }

  bool pushLocation({
    required String workspaceId,
    required String alertId,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? sourceType,
    DateTime? recordedAt,
    String? deviceId,
  }) {
    if (!connected) return false;
    if (!isValidCoordinate(latitude, longitude)) {
      return false;
    }
    final payload = buildLocationPayload(
      workspaceId: workspaceId,
      alertId: alertId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      sourceType: sourceType,
      recordedAt: recordedAt,
      deviceId: deviceId,
    );
    _socket?.emit('sos:location:push', payload);
    return true;
  }

  bool pushResponderLocation({
    required String workspaceId,
    required String alertId,
    required double latitude,
    required double longitude,
    double? accuracy,
    String sourceType = 'MOBILE_GPS',
    DateTime? recordedAt,
  }) {
    // Hai lệnh return dưới đây trước giờ thất bại HOÀN TOÀN IM LẶNG — nơi gọi
    // chỉ nhận về false và không ai in ra. Phải log rõ lý do, vì "B không gửi
    // được vị trí" và "BE không nhận được" nhìn từ ngoài giống hệt nhau.
    if (!connected) {
      sosResponderLog(
        'KHÔNG emit push: socket /sos CHƯA KẾT NỐI (alertId=$alertId)',
      );
      return false;
    }
    if (!isValidCoordinate(latitude, longitude)) {
      sosResponderLog(
        'KHÔNG emit push: toạ độ không hợp lệ lat=$latitude lng=$longitude',
      );
      return false;
    }
    final payload = buildLocationPayload(
      workspaceId: workspaceId,
      alertId: alertId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      sourceType: sourceType,
      recordedAt: recordedAt,
    );
    sosResponderLog('EMIT push keys=${payload.keys.toList()} payload=$payload');
    _socket?.emit(responderLocationPushEventName, payload);
    return true;
  }

  @visibleForTesting
  static bool isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  @visibleForTesting
  static Map<String, dynamic> buildLocationPayload({
    required String workspaceId,
    required String alertId,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? sourceType,
    DateTime? recordedAt,
    String? deviceId,
  }) {
    final payload = <String, dynamic>{
      'workspaceId': workspaceId,
      'alertId': alertId,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (accuracy != null) payload['accuracy'] = accuracy;
    if (sourceType != null && sourceType.isNotEmpty) {
      payload['sourceType'] = sourceType;
    }
    if (recordedAt != null) {
      payload['recordedAt'] = recordedAt.toUtc().toIso8601String();
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      payload['deviceId'] = deviceId;
    }
    return payload;
  }

  @visibleForTesting
  static Map<String, dynamic>? asMap(dynamic data) {
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    return asMap(data);
  }

  void _scheduleRetry() {
    if (!_wantConnected) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: _retryMs), () {
      _retryMs = (_retryMs * 2).clamp(2000, 20000);
      if (_wantConnected) connect();
    });
  }

  void _teardownSocket() {
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _wantConnected = false;
    _retryTimer?.cancel();
    _teardownSocket();
  }
}
