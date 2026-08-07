class AiConversation {
  final String id;
  final String title;
  final String? lastMessage;
  final DateTime? createdAt;

  const AiConversation({
    required this.id,
    required this.title,
    this.lastMessage,
    this.createdAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    final rawLast = json['lastMessage'];
    return AiConversation(
      id: _str(json['id'] ?? json['conversationId']),
      title: _str(
        json['conversationTitle'] ?? json['title'] ?? json['conversationName'],
        fallback: 'Cuộc trò chuyện mới',
      ),
      lastMessage: rawLast is Map
          ? _str(rawLast['content'], fallback: '')
          : _str(rawLast, fallback: ''),
      createdAt: _date(json['createdAt'] ?? json['updatedAt']),
    );
  }
}

class AiMessage {
  final String id;
  final String senderType;
  final String content;
  final String? relatedModule;
  final DateTime? createdAt;
  final AiPendingAction? pendingAction;
  final bool isLocal;

  const AiMessage({
    required this.id,
    required this.senderType,
    required this.content,
    this.relatedModule,
    this.createdAt,
    this.pendingAction,
    this.isLocal = false,
  });

  factory AiMessage.fromJson(
    Map<String, dynamic> json, {
    AiPendingAction? pendingAction,
  }) {
    final id = _str(json['id'] ?? json['messageId']);
    final rawAction = json['pendingAction'];
    final parsedAction =
        pendingAction ??
        (rawAction is Map
            ? AiPendingAction.fromJson(
                Map<String, dynamic>.from(rawAction),
                fallbackMessageId: id,
              )
            : null);
    return AiMessage(
      id: id,
      senderType: _str(json['senderType'] ?? json['role'], fallback: 'AI'),
      content: _str(json['content'] ?? json['message']),
      relatedModule: json['relatedModule']?.toString(),
      createdAt: _date(json['createdAt']),
      pendingAction: parsedAction,
    );
  }

  factory AiMessage.localUser(String content) => AiMessage(
    id: 'local-${DateTime.now().microsecondsSinceEpoch}',
    senderType: 'USER',
    content: content,
    createdAt: DateTime.now(),
    isLocal: true,
  );

  bool get isUser {
    final type = senderType.toUpperCase();
    return type == 'USER' || type == 'MEMBER' || type == 'HUMAN';
  }

  AiMessage copyWith({AiPendingAction? pendingAction}) => AiMessage(
    id: id,
    senderType: senderType,
    content: content,
    relatedModule: relatedModule,
    createdAt: createdAt,
    pendingAction: pendingAction ?? this.pendingAction,
    isLocal: isLocal,
  );
}

/// Kết cục của một đề xuất AI. Xem [AiPendingAction.outcome].
enum AiActionOutcome { pending, completed, rejected, expired, failed }

class AiPendingAction {
  final String messageId;
  final String actionType;
  final String status;
  final Map<String, dynamic> preview;
  final DateTime? expiresAt;

  const AiPendingAction({
    required this.messageId,
    required this.actionType,
    required this.status,
    required this.preview,
    this.expiresAt,
  });

  factory AiPendingAction.fromJson(
    Map<String, dynamic> json, {
    String? fallbackMessageId,
  }) {
    final rawPreview = json['preview'] ?? json['payload'] ?? json['data'];
    return AiPendingAction(
      messageId: _str(
        json['messageId'] ?? json['aiMessageId'] ?? json['id'],
        fallback: fallbackMessageId ?? '',
      ),
      actionType: _str(json['actionType'] ?? json['type']),
      status: _str(json['status'], fallback: 'PENDING'),
      preview: rawPreview is Map
          ? Map<String, dynamic>.from(rawPreview)
          : <String, dynamic>{},
      expiresAt: _date(json['expiresAt']),
    );
  }

  /// Ba `actionType` BE đã chốt bằng tin nhắn contract (bản FE nhận 2026-08-07).
  ///
  /// Swagger vẫn chưa khai enum này, nên đây là nguồn đúng duy nhất hiện có.
  static const confirmedActionTypes = <String>{
    'CREATE_TASK',
    'CREATE_LEDGER_ENTRY',
    'CREATE_CALENDAR_EVENT',
  };

  /// Biến thể tên FE từng đoán trước khi BE chốt. Giữ lại vì vô hại và đỡ được
  /// trường hợp BE đổi quy ước đặt tên; không phải tên chính thức.
  static const legacyActionTypeAliases = <String>{
    'CREATE_TRANSACTION',
    'FINANCE_LEDGER_CREATE',
    'TASK_CREATE',
    'CALENDAR_EVENT_CREATE',
  };

  /// Các `actionType` FE biết cách hiển thị preview và refresh sau khi xác nhận.
  static const knownActionTypes = <String>{
    ...confirmedActionTypes,
    ...legacyActionTypeAliases,
  };

  /// Bốn `status` BE đã chốt bằng văn bản contract (2026-08-07).
  ///
  /// `PENDING` → `CONFIRMED` (confirm thành công) / `REJECTED` (người dùng từ
  /// chối) / `EXPIRED` (quá hạn). BE nói rõ **chưa có `CANCELED` và `FAILED`**.
  /// Swagger vẫn chưa khai enum này nên đây là nguồn đúng duy nhất.
  static const confirmedStatuses = <String>{
    'PENDING',
    'CONFIRMED',
    'REJECTED',
    'EXPIRED',
  };

  /// Kết cục của đề xuất.
  ///
  /// Phải phân biệt "đã thực hiện xong" với "hết hạn". Trước 2026-08-07 UI chỉ
  /// hỏi `isPending` rồi gộp cả hai vào một dòng chữ đỏ "Đề xuất đã hết hạn
  /// hoặc đã được xử lý" — xác nhận thành công vẫn hiện cảnh báo đỏ, người dùng
  /// tưởng hỏng trong khi giao dịch đã vào sổ. Quan sát runtime trên emulator
  /// ngày 2026-08-07.
  ///
  /// Các nhánh ngoài [confirmedStatuses] (`CANCELED`, `FAILED`…) giữ lại làm
  /// lớp phòng thủ phòng khi BE thêm status mới, hiện KHÔNG bao giờ chạy.
  AiActionOutcome get outcome {
    switch (status.toUpperCase()) {
      case 'REJECTED':
      case 'CANCELED': // ngoài contract — phòng thủ
      case 'CANCELLED': // ngoài contract — phòng thủ
      case 'DECLINED': // ngoài contract — phòng thủ
        return AiActionOutcome.rejected;
      case 'EXPIRED':
        return AiActionOutcome.expired;
      case 'FAILED': // ngoài contract — phòng thủ
      case 'ERROR': // ngoài contract — phòng thủ
        return AiActionOutcome.failed;
      case 'PENDING':
        final expires = expiresAt;
        return expires != null && !expires.isAfter(DateTime.now())
            ? AiActionOutcome.expired
            : AiActionOutcome.pending;
      case 'CONFIRMED':
        return AiActionOutcome.completed;
      default:
        // Status lạ vẫn coi là đã thực hiện thay vì mặc định báo đỏ: BE chỉ đổi
        // status khỏi PENDING sau khi đã ghi dữ liệu thật.
        return AiActionOutcome.completed;
    }
  }

  bool get isPending => outcome == AiActionOutcome.pending;

  /// `false` khi BE gửi loại đề xuất FE chưa biết. Nơi gọi phải xử lý phòng thủ
  /// (nhãn chung + refresh rộng) chứ không được im lặng bỏ qua.
  bool get isKnownActionType =>
      knownActionTypes.contains(actionType.toUpperCase());

  String get actionLabel => switch (actionType.toUpperCase()) {
    'CREATE_LEDGER_ENTRY' ||
    'CREATE_TRANSACTION' ||
    'FINANCE_LEDGER_CREATE' => 'Tạo giao dịch',
    'CREATE_TASK' || 'TASK_CREATE' => 'Tạo nhiệm vụ',
    'CREATE_CALENDAR_EVENT' || 'CALENDAR_EVENT_CREATE' => 'Tạo sự kiện lịch',
    _ => 'Thực hiện đề xuất',
  };
}

String _str(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

DateTime? _date(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
