import 'package:flutter/foundation.dart';

import '../models/ai_chatbot.dart';
import '../models/feature_access.dart';
import '../services/api_client.dart';

class AiChatbotProvider extends ChangeNotifier {
  final List<AiConversation> _conversations = [];
  final List<AiMessage> _messages = [];
  final Set<String> _actionBusy = {};

  String? _currentConversationId;
  bool _loadingConversations = false;
  bool _loadingMessages = false;
  bool _loadingAccess = false;
  bool _sending = false;
  String? _error;
  FeatureAccess? _featureAccess;

  List<AiConversation> get conversations => List.unmodifiable(_conversations);
  List<AiMessage> get messages => List.unmodifiable(_messages);
  String? get currentConversationId => _currentConversationId;
  bool get loadingConversations => _loadingConversations;
  bool get loadingMessages => _loadingMessages;
  bool get loadingAccess => _loadingAccess;
  bool get sending => _sending;
  String? get error => _error;

  /// BE chưa trả lời, hoặc trả `featureAccess` rỗng → coi như KHÔNG BIẾT.
  bool get accessUnknown => _featureAccess == null || _featureAccess!.isUnknown;

  /// Gói có Trợ lý AI hay không.
  ///
  /// Fail-open khi chưa biết: map rỗng mà coi là cấm thì chặn nhầm cả gói vốn
  /// có quyền. Khi đã biết chắc là `false` thì chặn tại FE để người dùng thấy
  /// màn mời nâng cấp, thay vì bấm vào rồi mới ăn 403 từ BE.
  bool get canUseAssistant => accessUnknown || _featureAccess!.aiAssistant;

  bool isActionBusy(String messageId) => _actionBusy.contains(messageId);

  Future<void> bootstrap() async {
    await fetchFeatureAccess();
    // Gói không có quyền thì đừng gọi tiếp — mọi endpoint ai-chatbot đều 403,
    // chỉ tổ hiện banner đỏ thay vì lời mời nâng gói.
    if (!canUseAssistant) return;
    await fetchConversations();
    if (_conversations.isNotEmpty && _currentConversationId == null) {
      await selectConversation(_conversations.first.id);
    }
  }

  Future<void> fetchFeatureAccess() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loadingAccess = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$fid/subscription');
      final plan = data is Map && data['plan'] is Map
          ? Map<String, dynamic>.from(data['plan'] as Map)
          : const <String, dynamic>{};
      final access = data is Map
          ? data['featureAccess'] ?? plan['featureAccess']
          : plan['featureAccess'];
      _featureAccess = FeatureAccess.fromJson(access);
      // flag() trả false cả khi key không tồn tại, nên "gói không có quyền" và
      // "FE gõ sai tên key" nhìn giống hệt nhau nếu không log raw ra đây.
      debugPrint(
        'AiChatbotProvider: featureAccess=${_featureAccess!.raw} '
        '(unknown=${_featureAccess!.isUnknown}) → assistant=$canUseAssistant',
      );
    } catch (e) {
      // Không đọc được gói thì giữ trạng thái "không biết" và fail-open.
      debugPrint('AiChatbotProvider: fetchFeatureAccess failed: $e');
    } finally {
      _loadingAccess = false;
      notifyListeners();
    }
  }

  Future<void> fetchConversations() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loadingConversations = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/ai-chatbot/conversations?page=1&limit=20',
      );
      _conversations
        ..clear()
        ..addAll(_parseList(data).map(AiConversation.fromJson));
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    if (_currentConversationId == conversationId && _messages.isNotEmpty) {
      return;
    }
    _currentConversationId = conversationId;
    await fetchMessages();
  }

  void startNewConversation() {
    _currentConversationId = null;
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> fetchMessages() async {
    final fid = ApiClient.instance.familyId;
    final cid = _currentConversationId;
    if (fid == null || cid == null) return;
    _loadingMessages = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/ai-chatbot/conversations/$cid/messages?page=1&limit=50',
      );
      _messages
        ..clear()
        ..addAll(_parseList(data).map(AiMessage.fromJson));
      _messages.sort((a, b) {
        final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aa.compareTo(bb);
      });
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty || _sending) return;
    final fid = ApiClient.instance.familyId;
    if (fid == null) {
      _error = 'Bạn cần vào một gia đình trước khi dùng Trợ lý AI.';
      notifyListeners();
      return;
    }

    _sending = true;
    _error = null;
    final local = AiMessage.localUser(text);
    _messages.add(local);
    notifyListeners();

    try {
      final cid = _currentConversationId ?? await _createConversation(text);
      _currentConversationId = cid;
      final data = await ApiClient.instance.postWithTimeout(
        '/families/$fid/ai-chatbot/conversations/$cid/messages',
        {'content': text},
        timeout: const Duration(seconds: 30),
      );
      _messages.removeWhere((m) => m.id == local.id);
      _appendSendResponse(data);
      await fetchConversations();
    } catch (e) {
      // 502 = BE đã lưu tin của user nhưng AI chưa trả lời kịp. Tải lại lịch sử
      // để giữ tin vừa gửi (đừng xóa bong bóng), user có thể thử lại.
      if (e is ApiException &&
          e.statusCode == 502 &&
          _currentConversationId != null) {
        await fetchMessages();
      } else {
        _messages.removeWhere((m) => m.id == local.id);
      }
      _error = _friendlyError(e);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> confirmAction(String messageId) async {
    return _handleAction(messageId, confirm: true);
  }

  Future<bool> rejectAction(String messageId) async {
    return _handleAction(messageId, confirm: false);
  }

  Future<void> deleteCurrentConversation() async {
    final fid = ApiClient.instance.familyId;
    final cid = _currentConversationId;
    if (fid == null || cid == null) return;
    await ApiClient.instance.delete(
      '/families/$fid/ai-chatbot/conversations/$cid',
    );
    _currentConversationId = null;
    _messages.clear();
    await fetchConversations();
    if (_conversations.isNotEmpty) {
      await selectConversation(_conversations.first.id);
    } else {
      notifyListeners();
    }
  }

  Future<String> _createConversation(String firstMessage) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final title = firstMessage.length > 80
        ? '${firstMessage.substring(0, 80)}...'
        : firstMessage;
    final data = await ApiClient.instance.post(
      '/families/$fid/ai-chatbot/conversations',
      {'title': title},
    );
    final raw = data['conversation'];
    final conversation = AiConversation.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : data,
    );
    if (conversation.id.isEmpty) {
      throw Exception('Không lấy được hội thoại AI từ server.');
    }
    return conversation.id;
  }

  Future<bool> _handleAction(String messageId, {required bool confirm}) async {
    final fid = ApiClient.instance.familyId;
    final cid = _currentConversationId;
    if (fid == null || cid == null || _actionBusy.contains(messageId)) {
      return false;
    }
    _actionBusy.add(messageId);
    _error = null;
    notifyListeners();
    try {
      final action = confirm ? 'confirm-action' : 'reject-action';
      await ApiClient.instance.post(
        '/families/$fid/ai-chatbot/conversations/$cid/messages/$messageId/$action',
        {},
      );
      await fetchMessages();
      return true;
    } catch (e) {
      _error = _friendlyError(e, isAction: true);
      // 409 (đã xử lý rồi) và 410 (hết hạn) đều nghĩa là trạng thái thật ở
      // server đã khác cái FE đang vẽ. Không tải lại thì thẻ đề xuất kẹt ở
      // "Chờ xác nhận" và người dùng bấm mãi cũng chỉ ra đúng lỗi đó.
      if (e is ApiException && (e.statusCode == 409 || e.statusCode == 410)) {
        await fetchMessages();
      }
      return false;
    } finally {
      _actionBusy.remove(messageId);
      notifyListeners();
    }
  }

  void _appendSendResponse(Map<String, dynamic> data) {
    final rawAction = data['pendingAction'];
    final pendingAction = rawAction is Map
        ? AiPendingAction.fromJson(Map<String, dynamic>.from(rawAction))
        : null;
    final rawUser = data['userMessage'];
    if (rawUser is Map) {
      _messages.add(AiMessage.fromJson(Map<String, dynamic>.from(rawUser)));
    }
    final rawAi = data['aiMessage'] ?? data['message'];
    if (rawAi is Map) {
      final ai = AiMessage.fromJson(
        Map<String, dynamic>.from(rawAi),
        pendingAction: pendingAction,
      );
      _messages.add(ai);
    } else if (data['content'] != null) {
      _messages.add(AiMessage.fromJson(data, pendingAction: pendingAction));
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    final raw = data is Map
        ? (data['items'] ??
              data['data'] ??
              data['messages'] ??
              data['conversations'])
        : data;
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// [isAction] phân biệt lỗi lúc chat với lỗi lúc xác nhận/từ chối đề xuất.
  ///
  /// Cùng mã 403 nhưng hai ngữ cảnh khác hẳn nhau: lúc chat là gói cước chưa có
  /// Trợ lý AI, còn lúc confirm-action là **vai trò của người dùng không được
  /// phép tạo** dữ liệu đó (BE nói rõ trong contract 2026-08-07). Gộp chung một
  /// câu thì Member bị từ chối tạo giao dịch lại tưởng phải đi nâng gói.
  String _friendlyError(Object error, {bool isAction = false}) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        403 when isAction =>
          'Bạn không có quyền tạo dữ liệu này. Hãy nhờ Trưởng nhóm thực hiện.',
        403 => 'Bạn chưa có quyền dùng Trợ lý AI trong gói hiện tại.',
        409 => 'Đề xuất này đã được xử lý trước đó.',
        410 => 'Đề xuất đã hết hạn. Hãy nhắn lại để AI tạo đề xuất mới.',
        502 =>
          'AI chưa phản hồi kịp. Tin nhắn đã được lưu, bạn có thể thử lại.',
        503 => 'Trợ lý AI chưa được bật trên server.',
        _ => error.message,
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
