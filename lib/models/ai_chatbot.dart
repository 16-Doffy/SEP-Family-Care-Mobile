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
      // `AiConversationLastMessageResponseDto` dùng tên `messageContent`, KHÔNG
      // phải `content` như `AiMessageResponseDto`. Đọc sai tên thì dòng xem
      // trước dưới mỗi hội thoại trống trơn — lỗi im lặng, không exception.
      // Giữ `content` làm alias phòng dữ liệu cũ.
      lastMessage: rawLast is Map
          ? _str(rawLast['messageContent'] ?? rawLast['content'], fallback: '')
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
  final AiMessageUiHints? uiHints;
  final bool isLocal;

  const AiMessage({
    required this.id,
    required this.senderType,
    required this.content,
    this.relatedModule,
    this.createdAt,
    this.pendingAction,
    this.uiHints,
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
    final rawHints = json['uiHints'];
    return AiMessage(
      id: id,
      senderType: _str(json['senderType'] ?? json['role'], fallback: 'AI'),
      content: _str(json['content'] ?? json['message']),
      relatedModule: json['relatedModule']?.toString(),
      createdAt: _date(json['createdAt']),
      pendingAction: parsedAction,
      uiHints: rawHints is Map
          ? AiMessageUiHints.fromJson(Map<String, dynamic>.from(rawHints))
          : null,
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

  /// Kiểu hiển thị thật sự dùng để render — không bao giờ `null`.
  ///
  /// Tin nhắn cũ lưu từ trước Sprint 2 (hoặc BE tạm không gửi `uiHints`) không
  /// có field này. Suy theo CẤU TRÚC đã có sẵn (có/không có `pendingAction`),
  /// KHÔNG đoán qua chữ trong `content` — giữ đúng hành vi hiển thị cũ cho dữ
  /// liệu cũ, không phá test/màn hình đang chạy đúng.
  AiDisplayStyle get effectiveDisplayStyle =>
      uiHints?.displayStyle ??
      (pendingAction != null ? AiDisplayStyle.actionCard : AiDisplayStyle.text);

  AiMessage copyWith({AiPendingAction? pendingAction}) => AiMessage(
    id: id,
    senderType: senderType,
    content: content,
    relatedModule: relatedModule,
    createdAt: createdAt,
    pendingAction: pendingAction ?? this.pendingAction,
    uiHints: uiHints,
    isLocal: isLocal,
  );
}

/// Kiểu hiển thị BE chỉ định cho một tin nhắn AI — Sprint 2 (2026-08-xx).
///
/// Thay hoàn toàn cách cũ (FE tự đoán qua `actionType`/chữ trong `content`).
/// BE nhắc đi nhắc lại: mọi quyết định render phải dựa vào `uiHints` và
/// `pendingAction`, không được suy qua nội dung chữ.
enum AiDisplayStyle { text, insightCard, actionCard, permissionNotice, resultCard }

AiDisplayStyle? _parseDisplayStyle(dynamic value) {
  switch (value?.toString().toUpperCase()) {
    case 'TEXT':
      return AiDisplayStyle.text;
    case 'INSIGHT_CARD':
      return AiDisplayStyle.insightCard;
    case 'ACTION_CARD':
      return AiDisplayStyle.actionCard;
    case 'PERMISSION_NOTICE':
      return AiDisplayStyle.permissionNotice;
    case 'RESULT_CARD':
      return AiDisplayStyle.resultCard;
    default:
      // Thiếu hoặc lạ — để nơi gọi (AiMessage.effectiveDisplayStyle) tự suy
      // theo pendingAction, không mặc định liều một kiểu cụ thể ở đây.
      return null;
  }
}

/// Chip gợi ý dưới tin nhắn AI. Bấm vào gửi `prompt` như tin nhắn mới —
/// KHÔNG gửi `label`.
class AiQuickAction {
  final String label;
  final String prompt;

  const AiQuickAction({required this.label, required this.prompt});

  factory AiQuickAction.fromJson(Map<String, dynamic> json) {
    final prompt = _str(json['prompt']);
    // Label rơi về chính prompt nếu BE không gửi label riêng — luôn có chữ để
    // hiện trên chip, không để trống.
    return AiQuickAction(
      label: _str(json['label'] ?? json['title'], fallback: prompt),
      prompt: prompt,
    );
  }
}

List<AiQuickAction> _quickActionsFrom(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => AiQuickAction.fromJson(Map<String, dynamic>.from(e)))
      .where((q) => q.prompt.isNotEmpty)
      .toList();
}

/// `aiMessage.uiHints` — chỉ định cách render một tin nhắn AI.
class AiMessageUiHints {
  final AiDisplayStyle? displayStyle;
  final String? title;
  final String? icon;
  final String? confidenceLabel;
  final List<AiQuickAction> quickActions;

  const AiMessageUiHints({
    this.displayStyle,
    this.title,
    this.icon,
    this.confidenceLabel,
    this.quickActions = const [],
  });

  factory AiMessageUiHints.fromJson(Map<String, dynamic> json) =>
      AiMessageUiHints(
        displayStyle: _parseDisplayStyle(json['displayStyle']),
        title: json['title']?.toString(),
        icon: json['icon']?.toString(),
        confidenceLabel: json['confidenceLabel']?.toString(),
        quickActions: _quickActionsFrom(json['quickActions']),
      );
}

/// Một dòng trong thẻ xác nhận hành động — thay cho việc đọc thẳng `preview`.
///
/// Giữ `value` thô (`dynamic`) và `key` gốc, KHÔNG format ở model — model
/// không nên phụ thuộc UI. Format thật sự dùng `formatAiPreviewValue(key,
/// value)` sẵn có trong `ai_assistant_screen.dart` lúc render.
class AiActionField {
  final String key;
  final String label;
  final dynamic value;

  const AiActionField({required this.key, required this.label, this.value});

  factory AiActionField.fromJson(Map<String, dynamic> json) {
    final key = _str(json['key'] ?? json['name'] ?? json['field']);
    return AiActionField(
      key: key,
      label: _str(json['label'] ?? json['name'], fallback: key),
      value: json['value'] ?? json['content'],
    );
  }
}

/// `pendingAction.uiHints` — chỉ định cách render thẻ xác nhận.
class AiActionUiHints {
  final String? title;
  final String? description;
  final List<AiActionField> fields;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;

  /// BE chưa cho biết endpoint/cơ chế "sửa" đề xuất — chỉ có nhãn nút. Xem
  /// cách FE tạm xử lý ở `_PendingActionCard._handleEdit` trong
  /// `ai_assistant_screen.dart`.
  final String? editActionLabel;

  const AiActionUiHints({
    this.title,
    this.description,
    this.fields = const [],
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.editActionLabel,
  });

  factory AiActionUiHints.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    return AiActionUiHints(
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      fields: rawFields is List
          ? rawFields
                .whereType<Map>()
                .map((e) => AiActionField.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      primaryActionLabel: json['primaryActionLabel']?.toString(),
      secondaryActionLabel: json['secondaryActionLabel']?.toString(),
      editActionLabel: json['editActionLabel']?.toString(),
    );
  }
}

/// "Tổng quan hôm nay" — `GET /families/{id}/ai-chatbot/daily-brief`.
///
/// BE mô tả nội dung gồm task quá hạn, lịch sắp tới, tình hình tài chính, cảnh
/// báo ngân sách, mục tiêu tài chính — nhưng KHÔNG cho tên field cụ thể của
/// từng mục con. Theo đúng quy ước repo cho response chưa rõ schema (xem
/// `JsonReportView`, CLAUDE.md Rule 4): giữ nguyên `raw` để render đệ quy
/// key-value, không đoán tên field con. Chỉ tách riêng `suggestedPrompts` vì
/// BE có nói rõ hình dạng của nó (list prompt để làm chip).
class AiDailyBrief {
  final Map<String, dynamic> raw;
  final List<AiQuickAction> suggestedPrompts;

  const AiDailyBrief({required this.raw, required this.suggestedPrompts});

  factory AiDailyBrief.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(json)..remove('suggestedPrompts');
    return AiDailyBrief(
      raw: raw,
      suggestedPrompts: _quickActionsFrom(json['suggestedPrompts']),
    );
  }
}

/// Kết cục của một đề xuất AI. Xem [AiPendingAction.outcome].
enum AiActionOutcome { pending, completed, rejected, expired, failed }

class AiPendingAction {
  final String messageId;
  final String actionType;
  final String status;
  final Map<String, dynamic> preview;
  final DateTime? expiresAt;
  final AiActionUiHints? uiHints;

  const AiPendingAction({
    required this.messageId,
    required this.actionType,
    required this.status,
    required this.preview,
    this.expiresAt,
    this.uiHints,
  });

  factory AiPendingAction.fromJson(
    Map<String, dynamic> json, {
    String? fallbackMessageId,
  }) {
    final rawPreview = json['preview'] ?? json['payload'] ?? json['data'];
    final rawHints = json['uiHints'];
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
      uiHints: rawHints is Map
          ? AiActionUiHints.fromJson(Map<String, dynamic>.from(rawHints))
          : null,
    );
  }

  /// Ba `actionType` chính thức trong `AiActionType` của OpenAPI 2026-08-07.
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
  /// BE chốt ngày 2026-08-07: status chính thức hiện có đúng 4 giá trị
  /// `PENDING | CONFIRMED | REJECTED | EXPIRED`. Các nhánh `CANCELED`,
  /// `FAILED` bên dưới chỉ là parser phòng thủ cho dữ liệu legacy hoặc mở rộng
  /// về sau, không phải contract BE hiện tại.
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
    'FINANCE_LEDGER_CREATE' => 'Tạo thu/chi',
    'CREATE_TASK' || 'TASK_CREATE' => 'Tạo nhiệm vụ',
    'CREATE_CALENDAR_EVENT' || 'CALENDAR_EVENT_CREATE' => 'Tạo sự kiện lịch',
    _ => 'Thực hiện đề xuất',
  };

  /// Tiêu đề thẻ xác nhận — ưu tiên `uiHints.title` (Sprint 2), rơi về
  /// [actionLabel] cũ khi BE chưa gửi `uiHints` (dữ liệu cũ, hoặc actionType
  /// lạ chưa có tiêu đề soạn sẵn).
  String get displayTitle {
    final title = uiHints?.title?.trim();
    return title != null && title.isNotEmpty ? title : actionLabel;
  }

  /// Các dòng hiển thị trong thẻ xác nhận.
  ///
  /// Ưu tiên `uiHints.fields` (Sprint 2, BE đã soạn label sẵn). Rỗng thì rơi về
  /// suy diễn từ `preview` cũ — logic này TRƯỚC ĐÂY nằm trong
  /// `_PendingActionCard._previewRows`/`_label` ở `ai_assistant_screen.dart`,
  /// dời nguyên vẹn vào đây để có một nguồn field duy nhất cho UI, không đổi
  /// nội dung bảng nhãn hay thứ tự key.
  List<AiActionField> get displayFields {
    if (uiHints != null && uiHints!.fields.isNotEmpty) return uiHints!.fields;
    return _fieldsFromLegacyPreview();
  }

  List<AiActionField> _fieldsFromLegacyPreview() {
    final keys = switch (actionType.toUpperCase()) {
      // `task` là tên field BE thật sự trả cho CREATE_TASK — quan sát runtime
      // 2026-08-07, không phải `title` như FE đoán ban đầu.
      'CREATE_TASK' || 'TASK_CREATE' => [
        'task',
        'taskTitle',
        'title',
        'description',
        'dueAt',
        'dueDate',
        'assignee',
      ],
      'CREATE_LEDGER_ENTRY' ||
      'CREATE_TRANSACTION' ||
      'FINANCE_LEDGER_CREATE' => [
        'amount',
        'categoryName',
        'category',
        'description',
        'note',
      ],
      'CREATE_CALENDAR_EVENT' ||
      'CALENDAR_EVENT_CREATE' => ['title', 'startTime', 'endTime', 'location'],
      _ => preview.keys.take(6).toList(),
    };
    final fields = <AiActionField>[];
    final used = <String>{};
    for (final key in keys) {
      if (!preview.containsKey(key) || used.contains(key)) continue;
      used.add(key);
      fields.add(
        AiActionField(key: key, label: _legacyFieldLabel(key), value: preview[key]),
      );
    }
    if (fields.isEmpty) {
      fields.addAll(
        preview.entries
            .take(6)
            .map(
              (e) => AiActionField(
                key: e.key,
                label: _legacyFieldLabel(e.key),
                value: e.value,
              ),
            ),
      );
    }
    return fields;
  }

  static String _legacyFieldLabel(String key) => switch (key) {
    'amount' => 'Số tiền',
    'category' || 'categoryName' => 'Danh mục',
    'description' || 'note' => 'Ghi chú',
    'title' => 'Tiêu đề',
    'task' || 'taskTitle' => 'Nhiệm vụ',
    'startTime' => 'Bắt đầu',
    'endTime' => 'Kết thúc',
    'location' => 'Địa điểm',
    'assignee' || 'assignedTo' || 'assignedToName' => 'Người làm',
    'dueAt' || 'dueDate' => 'Hạn',
    _ => key,
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
