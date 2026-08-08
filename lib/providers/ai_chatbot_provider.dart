import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_chatbot.dart';
import '../models/feature_access.dart';
import '../services/api_client.dart';

class AiChatbotProvider extends ChangeNotifier {
  static const _conversationsLimit = 20;
  static const _messagesLimit = 50;

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

  int _conversationsPage = 1;
  int? _conversationsTotalPages;
  bool _loadingMoreConversations = false;
  int _messagesPage = 1;
  int? _messagesTotalPages;
  bool _loadingMoreMessages = false;

  AiDailyBrief? _dailyBrief;
  bool _dailyBriefDismissed = false;

  /// Id hội thoại vừa `DELETE` xong, lọc khỏi ĐÚNG một lần `fetchConversations`
  /// kế tiếp.
  ///
  /// Báo lỗi runtime 2026-08-08: xóa hội thoại xong, back ra rồi quay lại vẫn
  /// còn thấy nó. Nghi vấn hợp lý nhất không cần giả lập lại được: DELETE trả
  /// 200 nhưng GET danh sách ngay sau đó đọc dữ liệu chưa kịp đồng bộ (đọc
  /// từ read-replica/cache trễ hơn write) — id vừa xóa vẫn có trong response.
  /// Lọc cứng ở FE cho lần refetch ngay sau xóa để không phụ thuộc BE đồng bộ
  /// kịp trong khoảng thời gian đó.
  String? _justDeletedConversationId;

  List<AiConversation> get conversations => List.unmodifiable(_conversations);
  List<AiMessage> get messages => List.unmodifiable(_messages);
  String? get currentConversationId => _currentConversationId;
  bool get loadingConversations => _loadingConversations;
  bool get loadingMessages => _loadingMessages;
  bool get loadingAccess => _loadingAccess;
  bool get sending => _sending;
  String? get error => _error;
  bool get loadingMoreConversations => _loadingMoreConversations;
  bool get loadingMoreMessages => _loadingMoreMessages;

  /// `null` khi BE chưa bật Sprint 2 cho gia đình này, hoặc gọi lỗi — tính
  /// năng phụ, không được chặn khung chat chính vì thiếu nó.
  AiDailyBrief? get dailyBrief => _dailyBriefDismissed ? null : _dailyBrief;

  /// Còn trang sau hay không.
  ///
  /// Swagger có `page`/`limit` cho hai endpoint GET nhưng không mô tả khối
  /// phân trang trong response, nên đọc phòng thủ giống `WalletProvider`: ưu
  /// tiên `totalPages`/`total`/`hasNext`, không có thì suy từ số bản ghi nhận
  /// được bằng đúng `limit`.
  bool get hasMoreConversations => _conversationsTotalPages == null
      ? _conversations.length >= _conversationsLimit * _conversationsPage
      : _conversationsPage < _conversationsTotalPages!;

  bool get hasMoreMessages => _messagesTotalPages == null
      ? _messages.length >= _messagesLimit * _messagesPage
      : _messagesPage < _messagesTotalPages!;

  /// BE chưa trả lời, hoặc trả `featureAccess` rỗng → coi như KHÔNG BIẾT.
  bool get accessUnknown => _featureAccess == null || _featureAccess!.isUnknown;

  /// Gói có Trợ lý AI hay không.
  ///
  /// Fail-open khi chưa biết: map rỗng mà coi là cấm thì chặn nhầm cả gói vốn
  /// có quyền. Khi đã biết chắc là `false` thì chặn tại FE để người dùng thấy
  /// màn mời nâng cấp, thay vì bấm vào rồi mới ăn 403 từ BE.
  bool get canUseAssistant => accessUnknown || _featureAccess!.aiAssistant;

  AiChatbotProvider() {
    // Tự đăng ký dọn khi phiên kết thúc, thay vì trông chờ màn Đăng xuất nhớ
    // gọi. Có 3 đường gọi clearSession (bấm đăng xuất, session hết hạn, buộc
    // đăng xuất khi 401) — đăng ký ở đây thì cả ba đều được dọn.
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  bool isActionBusy(String messageId) => _actionBusy.contains(messageId);

  /// Xóa sạch dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này sống ở app scope nên không bị hủy khi đổi tài khoản. Không
  /// dọn thì tài khoản đăng nhập sau mở màn Trợ lý AI ra là thấy nguyên hội
  /// thoại của người trước.
  void resetForNewSession() {
    _conversations.clear();
    _messages.clear();
    _actionBusy.clear();
    _currentConversationId = null;
    _featureAccess = null;
    _error = null;
    _loadingConversations = false;
    _loadingMessages = false;
    _loadingAccess = false;
    _sending = false;
    _conversationsPage = 1;
    _conversationsTotalPages = null;
    _loadingMoreConversations = false;
    _messagesPage = 1;
    _messagesTotalPages = null;
    _loadingMoreMessages = false;
    _dailyBrief = null;
    _dailyBriefDismissed = false;
    _justDeletedConversationId = null;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    await fetchFeatureAccess();
    // Gói không có quyền thì đừng gọi tiếp — mọi endpoint ai-chatbot đều 403,
    // chỉ tổ hiện banner đỏ thay vì lời mời nâng gói.
    if (!canUseAssistant) return;
    await fetchConversations();
    // Tính năng phụ Sprint 2, không chặn hiển thị hội thoại nếu lỗi/chưa bật.
    unawaited(fetchDailyBrief());
    // Lớp phòng thủ thứ hai sau resetForNewSession: vào lại màn mà hội thoại
    // đang mở không còn thuộc danh sách server trả về thì tin nhắn đang giữ
    // không phải của người dùng này — xóa ngay.
    //
    // Chỉ kiểm ở bootstrap, KHÔNG kiểm trong fetchConversations. `sendMessage`
    // cũng gọi fetchConversations; đặt ở đó thì hội thoại vừa tạo mà chưa lọt
    // vào 20 bản ghi đầu sẽ làm xóa sạch tin nhắn người dùng vừa gửi.
    final current = _currentConversationId;
    if (current != null && !_conversations.any((c) => c.id == current)) {
      _currentConversationId = null;
      _messages.clear();
    }
    if (_conversations.isNotEmpty && _currentConversationId == null) {
      await selectConversation(_conversations.first.id);
    }
  }

  /// "Tổng quan hôm nay" — Sprint 2, BE nói rõ FE không bắt buộc làm ngay.
  ///
  /// Tính năng phụ, cố tình KHÔNG set [_error]: gia đình chưa được BE bật
  /// Sprint 2 sẽ nhận 404/500 ở đây, không được để lỗi đó hiện thành banner đỏ
  /// che mất khung chat chính vẫn đang hoạt động bình thường.
  Future<void> fetchDailyBrief() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/ai-chatbot/daily-brief',
      );
      _dailyBrief = data is Map
          ? AiDailyBrief.fromJson(Map<String, dynamic>.from(data))
          : null;
      _dailyBriefDismissed = false;
    } catch (e) {
      debugPrint('AiChatbotProvider: fetchDailyBrief bỏ qua lỗi: $e');
      _dailyBrief = null;
    } finally {
      notifyListeners();
    }
  }

  void dismissDailyBrief() {
    if (_dailyBriefDismissed) return;
    _dailyBriefDismissed = true;
    notifyListeners();
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

  Future<void> fetchConversations({bool refresh = true}) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    if (refresh) {
      _loadingConversations = true;
      _error = null;
      notifyListeners();
    }
    try {
      final page = refresh ? 1 : _conversationsPage + 1;
      final data = await ApiClient.instance.get(
        '/families/$fid/ai-chatbot/conversations'
        '?page=$page&limit=$_conversationsLimit',
      );
      var parsed = _parseList(data).map(AiConversation.fromJson).toList();
      final justDeleted = _justDeletedConversationId;
      if (justDeleted != null) {
        // Chỉ lọc đúng một lần — nếu BE thật sự chưa đồng bộ kịp và người
        // dùng bấm tải lại lần nữa sau đó, phải tin response mới nhất, không
        // lọc mãi mãi (nếu không sẽ không bao giờ thấy lại hội thoại trùng id
        // này, dù đó là điều gần như không xảy ra vì id không tái sử dụng).
        parsed = parsed.where((c) => c.id != justDeleted).toList();
        _justDeletedConversationId = null;
      }
      if (refresh) {
        _conversations
          ..clear()
          ..addAll(parsed);
      } else {
        // Trang sau có thể lặp lại bản ghi nếu người dùng vừa tạo hội thoại
        // mới làm lệch thứ tự — lọc theo id thay vì nối mù.
        final seen = _conversations.map((c) => c.id).toSet();
        _conversations.addAll(parsed.where((c) => !seen.contains(c.id)));
      }
      _conversationsPage = page;
      _conversationsTotalPages = _readTotalPages(
        data,
        parsed.length,
        page,
        _conversationsLimit,
      );
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      if (refresh) _loadingConversations = false;
      notifyListeners();
    }
  }

  /// Tải thêm hội thoại cũ hơn.
  ///
  /// Trước 2026-08-07 FE cứng `page=1`, quá 20 hội thoại là không còn đường
  /// xem lại những cái cũ hơn.
  Future<void> loadMoreConversations() async {
    if (_loadingMoreConversations || !hasMoreConversations) return;
    _loadingMoreConversations = true;
    notifyListeners();
    try {
      await fetchConversations(refresh: false);
    } finally {
      _loadingMoreConversations = false;
      notifyListeners();
    }
  }

  /// Đọc tổng số trang từ response.
  ///
  /// Swagger khai `page`/`limit` nhưng không mô tả khối phân trang trả về, nên
  /// thử lần lượt `meta`, `pagination` rồi tới chính gốc response. Không tìm
  /// thấy gì thì suy từ số bản ghi: nhận về ít hơn `limit` nghĩa là đã hết.
  int? _readTotalPages(dynamic data, int fetched, int page, int limit) {
    if (data is! Map) return fetched < limit ? page : null;
    final meta = data['meta'] is Map
        ? data['meta'] as Map
        : data['pagination'] is Map
        ? data['pagination'] as Map
        : data;
    final totalPages = (meta['totalPages'] as num?)?.toInt();
    if (totalPages != null) return totalPages;
    final total = (meta['total'] as num?)?.toInt();
    if (total != null) return (total / limit).ceil().clamp(1, 1 << 30);
    final hasNext = meta['hasNext'] == true || meta['hasNextPage'] == true;
    if (hasNext) return null;
    return fetched < limit ? page : null;
  }

  Future<void> selectConversation(String conversationId) async {
    if (_currentConversationId == conversationId && _messages.isNotEmpty) {
      return;
    }
    _currentConversationId = conversationId;
    // Đổi hội thoại thì con trỏ trang của hội thoại cũ không còn nghĩa gì.
    _messagesPage = 1;
    _messagesTotalPages = null;
    await fetchMessages();
  }

  void startNewConversation() {
    _currentConversationId = null;
    _messages.clear();
    _messagesPage = 1;
    _messagesTotalPages = null;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchMessages({bool refresh = true}) async {
    final fid = ApiClient.instance.familyId;
    final cid = _currentConversationId;
    if (fid == null || cid == null) return;
    if (refresh) {
      _loadingMessages = true;
      _error = null;
      notifyListeners();
    }
    try {
      final page = refresh ? 1 : _messagesPage + 1;
      final data = await ApiClient.instance.get(
        '/families/$fid/ai-chatbot/conversations/$cid/messages'
        '?page=$page&limit=$_messagesLimit',
      );
      final parsed = _parseList(data).map(AiMessage.fromJson).toList();
      if (refresh) {
        _messages
          ..clear()
          ..addAll(parsed);
      } else {
        // Không biết BE sắp xếp mới nhất hay cũ nhất trước (Swagger không nói),
        // nên gộp theo id rồi sắp lại theo thời gian — đúng ở cả hai chiều.
        final seen = _messages.map((m) => m.id).toSet();
        _messages.addAll(parsed.where((m) => !seen.contains(m.id)));
      }
      _messagesPage = page;
      _messagesTotalPages = _readTotalPages(
        data,
        parsed.length,
        page,
        _messagesLimit,
      );
      _messages.sort((a, b) {
        final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aa.compareTo(bb);
      });
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      if (refresh) _loadingMessages = false;
      notifyListeners();
    }
  }

  /// Tải thêm tin nhắn của hội thoại đang mở.
  ///
  /// Trước 2026-08-07 FE cứng `page=1&limit=50`, hội thoại dài hơn 50 tin là
  /// mất hẳn phần còn lại, không có đường lấy về.
  Future<void> loadMoreMessages() async {
    if (_loadingMoreMessages || !hasMoreMessages) return;
    _loadingMoreMessages = true;
    notifyListeners();
    try {
      await fetchMessages(refresh: false);
    } finally {
      _loadingMoreMessages = false;
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
    // Xóa ngay khỏi danh sách đang có trong RAM — không đợi fetchConversations
    // mới thấy hội thoại biến mất. Đồng thời đánh dấu để lọc khỏi lần refetch
    // kế tiếp phòng BE chưa kịp đồng bộ (xem [_justDeletedConversationId]).
    _conversations.removeWhere((c) => c.id == cid);
    _justDeletedConversationId = cid;
    _currentConversationId = null;
    _messages.clear();
    notifyListeners();
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

  @visibleForTesting
  void appendSendResponse(Map<String, dynamic> data) =>
      _appendSendResponse(data);

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
    } else if (pendingAction != null) {
      // Ví dụ trong contract BE gửi chỉ có đúng `pendingAction`, không kèm câu
      // trả lời nào. Không đỡ ca này thì đề xuất bị nuốt mất: người dùng gửi
      // tin xong màn hình không hiện gì, dù server đã tạo đề xuất chờ xác nhận.
      _messages.add(
        AiMessage(
          id: pendingAction.messageId,
          senderType: 'AI',
          content: 'Tôi đã chuẩn bị một đề xuất, bạn xem và xác nhận giúp nhé.',
          createdAt: DateTime.now(),
          pendingAction: pendingAction,
        ),
      );
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
          // Contract 2026-08-07: propose_create_ledger_entry mở cho CẢ
          // FAMILY_MANAGER và DEPUTY_MEMBER, không riêng Trưởng nhóm.
          'Bạn không có quyền tạo dữ liệu này. Hãy nhờ Trưởng nhóm hoặc Phó '
              'nhóm thực hiện.',
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
