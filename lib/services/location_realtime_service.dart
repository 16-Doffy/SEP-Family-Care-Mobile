import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

/// Transport Socket.IO cho namespace `/locations`.
///
/// Dùng riêng cho chia sẻ vị trí thường ngày trên bản đồ gia đình. SOS không đi
/// qua kênh này mà dùng namespace `/sos`.
class LocationRealtimeService {
  LocationRealtimeService._();
  static final LocationRealtimeService instance = LocationRealtimeService._();

  io.Socket? _socket;
  bool _wantConnected = false;
  Timer? _retryTimer;
  int _retryMs = 2000;

  bool get connected => _socket?.connected ?? false;

  void Function(Map<String, dynamic> payload)? onLocationUpdated;
  void Function(Map<String, dynamic> payload)? onSharingChanged;
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
      '${ApiClient.origin}/locations',
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
    s.on('location:updated', (data) {
      final m = _asMap(data);
      if (m != null) onLocationUpdated?.call(m);
    });
    s.on('location:sharing_changed', (data) {
      final m = _asMap(data);
      if (m != null) onSharingChanged?.call(m);
    });
    s.on('location:error', (data) {
      final msg = _asMap(data)?['message']?.toString() ?? 'Lỗi realtime vị trí';
      debugPrint('LocationSocket: error $msg');
      onError?.call(msg);
      _scheduleRetry();
    });
    s.onConnectError((e) {
      debugPrint('LocationSocket: connect_error $e');
      _scheduleRetry();
    });
    s.onDisconnect((_) {
      debugPrint('LocationSocket: disconnected');
      _scheduleRetry();
    });

    _socket = s;
    s.connect();
  }

  void _join(io.Socket s) {
    final workspaceId = ApiClient.instance.familyId;
    if (workspaceId == null || workspaceId.isEmpty) {
      debugPrint('LocationSocket: connected nhưng chưa có workspaceId');
      return;
    }
    s.emit('location:join', {'workspaceId': workspaceId});
    debugPrint(
      'LocationSocket: connected + location:join workspaceId=$workspaceId',
    );
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
