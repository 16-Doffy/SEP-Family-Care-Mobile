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
        json['conversationTitle'] ??
            json['title'] ??
            json['conversationName'],
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
    final parsedAction = pendingAction ??
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

  bool get isPending {
    if (status.toUpperCase() != 'PENDING') return false;
    final expires = expiresAt;
    return expires == null || expires.isAfter(DateTime.now());
  }

  String get actionLabel => switch (actionType.toUpperCase()) {
        'CREATE_LEDGER_ENTRY' ||
        'CREATE_TRANSACTION' ||
        'FINANCE_LEDGER_CREATE' =>
          'Tạo giao dịch',
        'CREATE_TASK' || 'TASK_CREATE' => 'Tạo nhiệm vụ',
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
