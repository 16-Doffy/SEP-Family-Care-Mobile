import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

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
  void Function(String workspaceId)? onKicked;
  void Function(String message)? onError;

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
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }
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

    _socket?.emit('sos:location:push', payload);
    return true;
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
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
