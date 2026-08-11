import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../providers/call_provider.dart';
import 'api_client.dart';

/// Transport Socket.IO cho namespace **`/chat`** — nơi BE phát tín hiệu cuộc
/// gọi video (`call:*`) và tin nhắn realtime.
///
/// Viết theo đúng khuôn [NotificationSocketService] (namespace
/// `/notifications`): tự quản reconnect/backoff thay vì dùng reconnection có
/// sẵn, để **mỗi lần thử lại đều đọc token mới nhất** từ [ApiClient] — JWT chỉ
/// sống 15 phút nên giữ token cũ là kết nối lại thất bại im lặng.
///
/// ## Khác `/notifications` ở một điểm dễ sai
///
/// `/notifications` **server tự join** room `user:<userId>` từ token, client
/// không phải làm gì. Còn `/chat` thì client **phải tự** gửi:
///
/// ```
/// emit('chat:join', { 'workspaceId': <familyId> })
/// ```
///
/// ⚠️ Field tên **`workspaceId`**, KHÔNG phải `familyId` hay `conversationId`
/// (BE xác nhận 11/08). Giá trị vẫn là familyId — BE gọi family là workspace,
/// thấy rõ trong các DTO SOS (`SosAlertResponseDto.workspaceId`). Tên lệch nhau
/// nên rất dễ truyền nhầm, mà truyền nhầm thì **kết nối vẫn thành công nhưng
/// không nhận được event nào** — hỏng im lặng.
///
/// **Join một lần là đủ cho MỌI hội thoại** trong gia đình; không cần join
/// từng cuộc hội thoại, và không cần đang mở màn chat mới nhận được cuộc gọi.
///
/// ## Phạm vi
///
/// Chỉ là **transport**: nhận gói tin, parse, gọi callback. Không giữ state,
/// không quyết định gì. Giai đoạn 3 mới nối vào provider + LiveKit + UI.
///
/// BE cho biết `/chat` là namespace chat **đầy đủ** (tin nhắn, typing, presence,
/// reaction, pin...), nên sau này bỏ được `ChatProvider.startPolling()`. Đó là
/// thay đổi lớn, cố ý để sau đợt bảo vệ.
class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  bool _wantConnected = false;
  Timer? _retryTimer;
  int _retryMs = 2000;

  /// Đã nhận được gói tin nào từ server chưa. Dùng để phân biệt hai kiểu hỏng
  /// rất khác nhau: "không kết nối được" và "kết nối được nhưng join sai nên
  /// chẳng bao giờ có event". Cái thứ hai nhìn từ ngoài giống hệt lúc bình
  /// thường không có cuộc gọi nào.
  bool _receivedAnyEvent = false;

  bool get connected => _socket?.connected ?? false;
  bool get receivedAnyEvent => _receivedAnyEvent;

  // Nơi gọi gắn callback vào (transport-only, không giữ state).
  void Function(CallIncomingEvent event)? onCallIncoming;
  void Function(CallParticipantUpdateEvent event)? onCallAccepted;
  void Function(CallParticipantUpdateEvent event)? onCallDeclined;
  void Function(CallParticipantUpdateEvent event)? onCallParticipantUpdate;
  void Function(CallEndedEvent event)? onCallEnded;

  /// Tin nhắn mới trong hội thoại — gồm cả loại `CALL` (dòng tóm tắt cuộc gọi
  /// BE tự sinh, ví dụ "Cuộc gọi video · 5:32"). Để `Map` thô vì `ChatProvider`
  /// đã có sẵn `ChatMessage.fromJson`, tránh nhân bản model.
  void Function(Map<String, dynamic> message)? onChatMessage;

  void connect() {
    _wantConnected = true;
    _retryTimer?.cancel();
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) return;

    _teardownSocket();
    final s = io.io(
      '${ApiClient.origin}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableReconnection() // tự quản để luôn dùng token mới nhất
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      _retryMs = 2000;
      // Kết nối xong CHƯA nhận được gì cả — phải join room trước.
      final familyId = ApiClient.instance.familyId;
      if (familyId == null || familyId.isEmpty) {
        debugPrint('ChatSocket: connected nhưng chưa có familyId, không join');
        return;
      }
      s.emit('chat:join', {'workspaceId': familyId});
      debugPrint('ChatSocket: connected + chat:join workspaceId=$familyId');
    });

    s.on('call:incoming', (data) {
      final m = _asMap(data);
      if (m != null) onCallIncoming?.call(CallIncomingEvent.fromJson(m));
    });
    s.on('call:accepted', (data) {
      final m = _asMap(data);
      if (m != null) {
        onCallAccepted?.call(CallParticipantUpdateEvent.fromJson(m));
      }
    });
    s.on('call:declined', (data) {
      final m = _asMap(data);
      if (m != null) {
        onCallDeclined?.call(CallParticipantUpdateEvent.fromJson(m));
      }
    });
    s.on('call:participant-update', (data) {
      final m = _asMap(data);
      if (m != null) {
        onCallParticipantUpdate?.call(CallParticipantUpdateEvent.fromJson(m));
      }
    });
    s.on('call:ended', (data) {
      final m = _asMap(data);
      if (m != null) onCallEnded?.call(CallEndedEvent.fromJson(m));
    });
    s.on('chat:message:new', (data) {
      final m = _asMap(data);
      if (m != null) onChatMessage?.call(m);
    });

    s.onConnectError((e) {
      debugPrint('ChatSocket: connect_error $e');
      _scheduleRetry();
    });
    s.onDisconnect((_) {
      debugPrint('ChatSocket: disconnected');
      _scheduleRetry();
    });

    _socket = s;
    s.connect();
  }

  /// Gói tin đầu tiên là bằng chứng `chat:join` đã đúng — log đúng một lần để
  /// lúc thử trên máy thật biết ngay dừng ở khâu nào, không phải đoán.
  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is! Map) return null;
    if (!_receivedAnyEvent) {
      _receivedAnyEvent = true;
      debugPrint('ChatSocket: nhận được event đầu tiên — chat:join OK');
    }
    return Map<String, dynamic>.from(data);
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
    _receivedAnyEvent = false;
  }
}
