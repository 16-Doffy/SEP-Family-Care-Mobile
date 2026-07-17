import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

/// Transport Socket.IO cho namespace **`/notifications`** (realtime foreground).
///
/// Theo hợp đồng WS của BE:
/// - Handshake gửi `auth: { token: accessToken }` (JWT 15').
/// - Server **tự join** room `user:<userId>` từ token — KHÔNG join thủ công
///   (khác `/sos` cần `sos:join`).
/// - 3 event server→client: `notification:new`, `notification:unread-count`,
///   `notification:error`.
/// - Không có event client→server (list/mark-read đi REST).
///
/// Reconnect + refresh token: **tự quản** (tắt reconnection built-in) để mỗi
/// lần thử lại đều đọc **token mới nhất** từ [ApiClient] (được REST/poll giữ
/// tươi). Token 15' hết hạn → disconnect → backoff → reconnect với token mới.
class NotificationSocketService {
  NotificationSocketService._();
  static final NotificationSocketService instance =
      NotificationSocketService._();

  io.Socket? _socket;
  bool _wantConnected = false;
  Timer? _retryTimer;
  int _retryMs = 2000;

  // Provider gắn callback vào đây (transport-only, không giữ state).
  void Function(Map<String, dynamic> payload)? onNotification;
  void Function(String? familyId, int count)? onUnreadCount;
  void Function(String message)? onAuthError;

  bool get connected => _socket?.connected ?? false;

  void connect() {
    _wantConnected = true;
    _retryTimer?.cancel();
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) return;

    _teardownSocket();
    final s = io.io(
      '${ApiClient.origin}/notifications',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableReconnection() // tự quản để luôn dùng token mới nhất
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      _retryMs = 2000;
      debugPrint('NotifSocket: connected');
    });
    s.on('notification:new', (data) {
      if (data is Map) {
        onNotification?.call(Map<String, dynamic>.from(data));
      }
    });
    s.on('notification:unread-count', (data) {
      if (data is Map) {
        onUnreadCount?.call(
          data['familyId']?.toString(),
          (data['count'] as num?)?.toInt() ?? 0,
        );
      }
    });
    s.on('notification:error', (data) {
      final msg = (data is Map ? data['message']?.toString() : null) ??
          'Lỗi kết nối thông báo';
      debugPrint('NotifSocket: error $msg');
      onAuthError?.call(msg);
      _scheduleRetry();
    });
    s.onConnectError((e) {
      debugPrint('NotifSocket: connect_error $e');
      _scheduleRetry();
    });
    s.onDisconnect((_) {
      debugPrint('NotifSocket: disconnected');
      _scheduleRetry();
    });

    _socket = s;
    s.connect();
  }

  void _scheduleRetry() {
    if (!_wantConnected) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: _retryMs), () {
      _retryMs = (_retryMs * 2).clamp(2000, 20000);
      if (_wantConnected) connect(); // đọc lại token mới nhất từ ApiClient
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
