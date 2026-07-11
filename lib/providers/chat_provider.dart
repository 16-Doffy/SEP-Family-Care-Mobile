import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

// ════════════════════════════════════════════════════════════════════════
// ChatProvider — module Chat của BE (18 endpoints, ship 2026-07-11), gán ĐỦ.
// Response thật (verified live): id theo convention <bảng>_id
// (conversationId/messageId/attachmentId/reactionId), sender/participant có
// member.user.fullName nested, list messages DESC + cursor, upload trả
// {fileUrl, fileName, mimeType, size} (R2 public URL).
// ════════════════════════════════════════════════════════════════════════

class ChatAttachment {
  final String id;
  final String fileType; // MIME
  final String fileUrl;
  final String? fileName;

  const ChatAttachment({required this.id, required this.fileType, required this.fileUrl, this.fileName});

  bool get isImage => fileType.startsWith('image/');

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        id: j['attachmentId']?.toString() ?? j['id']?.toString() ?? '',
        fileType: j['fileType']?.toString() ?? '',
        fileUrl: j['fileUrl']?.toString() ?? '',
        fileName: j['fileName']?.toString(),
      );

  Map<String, dynamic> toSendJson() => {
        'fileType': fileType,
        'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
      };
}

class ChatReaction {
  final String emoji;
  final String memberId;
  final String userId;
  final String memberName;

  const ChatReaction({required this.emoji, required this.memberId, required this.userId, required this.memberName});

  factory ChatReaction.fromJson(Map<String, dynamic> j) {
    final member = j['member'] is Map ? j['member'] as Map : const {};
    final user = member['user'] is Map ? member['user'] as Map : const {};
    return ChatReaction(
      emoji: j['emoji']?.toString() ?? '',
      memberId: j['memberId']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      memberName: member['displayName']?.toString() ?? user['fullName']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String senderMemberId;
  final String senderUserId;
  final String senderName;
  final String content;
  final String messageType; // TEXT | IMAGE | FILE | LOCATION | SOS_QUICK_MESSAGE
  final DateTime? sentAt;
  final bool isDeleted;
  final bool isEdited;
  final bool isPinned;
  final List<ChatAttachment> attachments;
  final List<ChatReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.senderMemberId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    this.messageType = 'TEXT',
    this.sentAt,
    this.isDeleted = false,
    this.isEdited = false,
    this.isPinned = false,
    this.attachments = const [],
    this.reactions = const [],
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
      isEdited: j['editedAt'] != null,
      isPinned: j['pinnedAt'] != null,
      attachments: (j['attachments'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reactions: (j['reactions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ChatReaction.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChatParticipant {
  final String memberId;
  final String userId;
  final String name;
  final String familyRole;

  const ChatParticipant({required this.memberId, required this.userId, required this.name, required this.familyRole});

  factory ChatParticipant.fromJson(Map<String, dynamic> j) {
    final member = j['member'] is Map ? j['member'] as Map : const {};
    final user = member['user'] is Map ? member['user'] as Map : const {};
    return ChatParticipant(
      memberId: j['memberId']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      name: member['displayName']?.toString() ?? user['fullName']?.toString() ?? 'Thành viên',
      familyRole: member['familyRole']?.toString() ?? '',
    );
  }
}

class ChatConversation {
  final String id;
  final String name;
  final String type; // GROUP | PRIVATE
  final bool isDefault;
  final String status; // ACTIVE | ARCHIVED
  final List<ChatParticipant> participants;

  const ChatConversation({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
    this.status = 'ACTIVE',
    this.participants = const [],
  });

  bool get isArchived => status == 'ARCHIVED';

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
        id: j['conversationId']?.toString() ?? j['id']?.toString() ?? '',
        name: j['conversationName']?.toString() ?? '',
        type: j['conversationType']?.toString() ?? 'GROUP',
        isDefault: j['isDefault'] == true,
        status: j['status']?.toString() ?? 'ACTIVE',
        participants: (j['participants'] as List? ?? [])
            .whereType<Map>()
            .where((p) => p['leftAt'] == null && p['participantStatus'] != 'LEFT')
            .map((e) => ChatParticipant.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  // Tên hiển thị chat 1-1 = tên người còn lại
  String displayName(String myUserId) {
    if (type == 'PRIVATE') {
      final other = participants.where((p) => p.userId != myUserId).toList();
      if (other.isNotEmpty) return other.first.name;
    }
    return name.isNotEmpty ? name : 'Gia đình';
  }
}

class ChatProvider extends ChangeNotifier {
  List<ChatConversation> _conversations = [];
  ChatConversation? _active;
  List<ChatMessage> _messages = []; // DESC — mới nhất index 0 (ListView reverse)
  bool _loading = false;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  List<ChatConversation> get conversations => _conversations;
  ChatConversation? get active => _active;
  String? get conversationId => _active?.id;
  String get conversationName => _active?.name.isNotEmpty == true ? _active!.name : 'Gia đình';
  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  String? get _fid => ApiClient.instance.familyId;

  // ── Conversations ─────────────────────────────────────────────────────────

  // GET /chat/conversations
  Future<void> fetchConversations() async {
    final fid = _fid;
    if (fid == null) return;
    final data = await ApiClient.instance.get('/families/$fid/chat/conversations');
    final list = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : <dynamic>[]);
    _conversations = list
        .whereType<Map>()
        .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty)
        .toList();
    notifyListeners();
  }

  // Mở nhóm mặc định của gia đình (BE tự tạo isDefault=true)
  Future<void> openDefaultConversation() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fetchConversations();
      final def = _conversations.where((c) => c.isDefault).toList();
      final target = def.isNotEmpty
          ? def.first
          : (_conversations.isNotEmpty ? _conversations.first : null);
      if (target != null) await openConversation(target);
    } catch (e) {
      _error = e.toString();
      debugPrint('ChatProvider: openDefaultConversation failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> openConversation(ChatConversation c) async {
    _active = c;
    _messages = [];
    notifyListeners();
    await fetchMessages();
    await markRead();
  }

  // POST /chat/conversations — GROUP (name + memberIds) | PRIVATE (targetMemberId)
  Future<void> createGroup(String name, List<String> memberIds) async {
    final fid = _fid;
    if (fid == null) return;
    final data = await ApiClient.instance.post('/families/$fid/chat/conversations', {
      'conversationType': 'GROUP',
      'conversationName': name,
      'memberIds': memberIds,
    });
    await fetchConversations();
    await _openCreated(data);
  }

  Future<void> createPrivate(String targetMemberId) async {
    final fid = _fid;
    if (fid == null) return;
    final data = await ApiClient.instance.post('/families/$fid/chat/conversations', {
      'conversationType': 'PRIVATE',
      'targetMemberId': targetMemberId,
    });
    await fetchConversations();
    await _openCreated(data);
  }

  Future<void> _openCreated(dynamic data) async {
    final id = data is Map
        ? (data['conversationId']?.toString() ??
            (data['conversation'] is Map
                ? (data['conversation'] as Map)['conversationId']?.toString()
                : null))
        : null;
    final match = _conversations.where((c) => c.id == id).toList();
    if (match.isNotEmpty) {
      await openConversation(match.first);
    } else if (_conversations.isNotEmpty) {
      await openConversation(_conversations.first);
    }
  }

  // PATCH /chat/conversations/{id} — đổi tên hoặc lưu trữ/mở lại
  Future<void> updateConversation({String? name, String? status}) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.patch('/families/$fid/chat/conversations/$cid', {
      if (name != null && name.isNotEmpty) 'conversationName': name,
      if (status != null) 'status': status,
    });
    await fetchConversations();
    final updated = _conversations.where((c) => c.id == cid).toList();
    if (updated.isNotEmpty) _active = updated.first;
    notifyListeners();
  }

  // POST .../participants — thêm thành viên vào nhóm
  Future<void> addParticipants(List<String> memberIds) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null || memberIds.isEmpty) return;
    await ApiClient.instance.post(
        '/families/$fid/chat/conversations/$cid/participants', {'memberIds': memberIds});
    await _refreshActive();
  }

  // DELETE .../participants/{memberId} — xóa thành viên khỏi nhóm
  Future<void> removeParticipant(String memberId) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance
        .delete('/families/$fid/chat/conversations/$cid/participants/$memberId');
    await _refreshActive();
  }

  // POST .../leave — rời nhóm (quay về nhóm mặc định)
  Future<void> leaveConversation() async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.post('/families/$fid/chat/conversations/$cid/leave', {});
    _active = null;
    await openDefaultConversation();
  }

  Future<void> _refreshActive() async {
    final cid = conversationId;
    await fetchConversations();
    final updated = _conversations.where((c) => c.id == cid).toList();
    if (updated.isNotEmpty) _active = updated.first;
    notifyListeners();
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  // GET .../messages?limit=50 — DESC, giữ nguyên cho ListView(reverse: true)
  Future<void> fetchMessages() async {
    final fid = _fid;
    final cid = conversationId;
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
      if (_messages.isNotEmpty && _messages.first.id != hadNewest) {
        await markRead();
      }
    } catch (e) {
      debugPrint('ChatProvider: fetchMessages failed: $e');
    }
  }

  // GET .../pinned-messages
  Future<List<ChatMessage>> fetchPinnedMessages() async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return [];
    final data = await ApiClient.instance
        .get('/families/$fid/chat/conversations/$cid/pinned-messages');
    final list = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : <dynamic>[]);
    return list
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // POST .../messages/upload (multipart) → attachment info để gửi kèm tin
  Future<ChatAttachment?> uploadAttachment(String filePath) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return null;
    final res = await ApiClient.instance.uploadFile(
      path: '/families/$fid/chat/conversations/$cid/messages/upload',
      filePath: filePath,
    );
    if (res.isEmpty) return null;
    return ChatAttachment(
      id: '',
      fileType: res['mimeType']?.toString() ?? res['fileType']?.toString() ?? 'image/jpeg',
      fileUrl: res['fileUrl']?.toString() ?? '',
      fileName: res['fileName']?.toString(),
    );
  }

  // POST .../messages — TEXT hoặc kèm attachments (BE tự suy messageType)
  Future<void> sendMessage(String content, {List<ChatAttachment> attachments = const []}) async {
    final fid = _fid;
    final cid = conversationId;
    final text = content.trim();
    if (fid == null || cid == null || (text.isEmpty && attachments.isEmpty)) return;
    _sending = true;
    notifyListeners();
    try {
      await ApiClient.instance.post('/families/$fid/chat/conversations/$cid/messages', {
        if (text.isNotEmpty) 'content': text,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toSendJson()).toList(),
      });
      await fetchMessages();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // PATCH .../messages/{id} — sửa nội dung tin của mình
  Future<void> editMessage(String messageId, String content) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.patch(
        '/families/$fid/chat/conversations/$cid/messages/$messageId', {'content': content});
    await fetchMessages();
  }

  // DELETE .../messages/{id} — thu hồi tin của mình
  Future<void> deleteMessage(String messageId) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance
        .delete('/families/$fid/chat/conversations/$cid/messages/$messageId');
    await fetchMessages();
  }

  // POST .../reactions | DELETE .../reactions/{emoji}
  Future<void> react(String messageId, String emoji) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.post(
        '/families/$fid/chat/conversations/$cid/messages/$messageId/reactions',
        {'emoji': emoji});
    await fetchMessages();
  }

  Future<void> unreact(String messageId, String emoji) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.delete(
        '/families/$fid/chat/conversations/$cid/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}');
    await fetchMessages();
  }

  // POST/DELETE .../pin — ghim / bỏ ghim
  Future<void> pinMessage(String messageId) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance
        .post('/families/$fid/chat/conversations/$cid/messages/$messageId/pin', {});
    await fetchMessages();
  }

  Future<void> unpinMessage(String messageId) async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance
        .delete('/families/$fid/chat/conversations/$cid/messages/$messageId/pin');
    await fetchMessages();
  }

  // POST .../read — cập nhật lastReadAt
  Future<void> markRead() async {
    final fid = _fid;
    final cid = conversationId;
    if (fid == null || cid == null) return;
    try {
      await ApiClient.instance.post('/families/$fid/chat/conversations/$cid/read', {});
    } catch (e) {
      debugPrint('ChatProvider: markRead failed: $e');
    }
  }

  // ── Polling (BE chưa có websocket/push cho chat) ──────────────────────────

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchMessages());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    stopPolling();
    _active = null;
    _conversations = [];
    _messages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
