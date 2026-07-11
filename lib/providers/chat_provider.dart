import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

// ════════════════════════════════════════════════════════════════════════
// ChatProvider — module Chat BE bổ sung 2026-07-11 (18 endpoints).
// Phạm vi hiện tại: nhóm chat mặc định của gia đình (BE tự tạo isDefault),
// gửi/nhận TEXT + polling 5s + mark read. PRIVATE 1-1, ảnh, reaction, pin
// để đợt sau — provider đã chừa sẵn id/type để mở rộng.
// Response thật (verified live): id là "conversationId"/"messageId" (theo
// convention <bảng>_id của ERD), sender ở "senderMember.user.fullName",
// list messages DESC (mới nhất trước), phân trang cursor.
// ════════════════════════════════════════════════════════════════════════

class ChatMessage {
  final String id;
  final String senderMemberId;
  final String senderUserId;
  final String senderName;
  final String content;
  final String messageType; // TEXT | IMAGE | FILE | LOCATION | SOS_QUICK_MESSAGE
  final DateTime? sentAt;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.senderMemberId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    this.messageType = 'TEXT',
    this.sentAt,
    this.isDeleted = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['senderMember'] is Map ? j['senderMember'] as Map : const {};
    final user = sender['user'] is Map ? sender['user'] as Map : const {};
    final display = sender['displayName']?.toString();
    return ChatMessage(
      id: j['messageId']?.toString() ?? j['id']?.toString() ?? '',
      senderMemberId: j['senderMemberId']?.toString() ?? '',
      senderUserId: user['id']?.toString() ?? '',
      senderName: (display != null && display.isNotEmpty)
          ? display
          : user['fullName']?.toString() ?? 'Thành viên',
      content: j['content']?.toString() ?? '',
      messageType: j['messageType']?.toString() ?? 'TEXT',
      sentAt: DateTime.tryParse(j['sentAt']?.toString() ?? '')?.toLocal(),
      isDeleted: j['isDeleted'] == true || j['deletedAt'] != null,
    );
  }
}

class ChatProvider extends ChangeNotifier {
  String? _conversationId;
  String _conversationName = 'Gia đình';
  List<ChatMessage> _messages = []; // DESC — mới nhất ở index 0 (khớp ListView reverse)
  bool _loading = false;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  String? get conversationId => _conversationId;
  String get conversationName => _conversationName;
  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  String? get _fid => ApiClient.instance.familyId;

  // GET /chat/conversations — lấy nhóm mặc định của gia đình (BE tự tạo,
  // isDefault=true, mọi thành viên đều là participant).
  Future<void> openDefaultConversation() async {
    final fid = _fid;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/chat/conversations');
      final list = data is List
          ? data
          : (data is Map && data['items'] is List ? data['items'] as List : <dynamic>[]);
      final maps = list.whereType<Map>().toList();
      final def = maps.firstWhere(
        (c) => c['isDefault'] == true,
        orElse: () => maps.isNotEmpty ? maps.first : <String, dynamic>{},
      );
      _conversationId = def['conversationId']?.toString() ?? def['id']?.toString();
      final name = def['conversationName']?.toString();
      if (name != null && name.isNotEmpty) _conversationName = name;
      if (_conversationId != null) {
        await fetchMessages();
        await markRead();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('ChatProvider: openDefaultConversation failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // GET .../messages?limit=50 — BE trả DESC (mới nhất trước), giữ nguyên thứ
  // tự để dùng với ListView(reverse: true).
  Future<void> fetchMessages() async {
    final fid = _fid;
    final cid = _conversationId;
    if (fid == null || cid == null) return;
    try {
      final data = await ApiClient.instance
          .get('/families/$fid/chat/conversations/$cid/messages?limit=50');
      final list = data is List
          ? data
          : (data is Map && data['items'] is List ? data['items'] as List : <dynamic>[]);
      final hadNewest = _messages.isNotEmpty ? _messages.first.id : null;
      _messages = list
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.id.isNotEmpty)
          .toList();
      notifyListeners();
      // Có tin mới từ người khác → đánh dấu đã đọc luôn (đang mở màn chat)
      if (_messages.isNotEmpty && _messages.first.id != hadNewest) {
        await markRead();
      }
    } catch (e) {
      debugPrint('ChatProvider: fetchMessages failed: $e');
    }
  }

  // POST .../messages — gửi TEXT rồi refetch để lấy bản ghi chuẩn của server
  Future<void> sendMessage(String content) async {
    final fid = _fid;
    final cid = _conversationId;
    final text = content.trim();
    if (fid == null || cid == null || text.isEmpty) return;
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post(
        '/families/$fid/chat/conversations/$cid/messages',
        {'content': text},
      );
      await fetchMessages();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // POST .../read — cập nhật lastReadAt của mình trong conversation
  Future<void> markRead() async {
    final fid = _fid;
    final cid = _conversationId;
    if (fid == null || cid == null) return;
    try {
      await ApiClient.instance.post('/families/$fid/chat/conversations/$cid/read', {});
    } catch (e) {
      debugPrint('ChatProvider: markRead failed: $e');
    }
  }

  // Polling 5s khi màn chat đang mở — BE chưa có websocket/push cho chat
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => fetchMessages(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    stopPolling();
    _conversationId = null;
    _messages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
