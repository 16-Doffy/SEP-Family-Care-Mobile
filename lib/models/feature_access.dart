/// Đọc map `featureAccess` mà BE trả kèm gói đăng ký.
///
/// **Tên key phải khớp danh sách chính thức.** BE khai enum 26 key trong
/// `CreateSubscriptionPlanDto.featureAccess` / `UpdateSubscriptionPlanDto`
/// (Swagger, bản dump `family-care-api.json`). [flag] trả `false` cả khi key
/// KHÔNG TỒN TẠI, nên gõ sai tên key nhìn giống hệt "gói này không có quyền" —
/// im lặng, không lỗi, không log. Trước 2026-08-07 FE đọc `ai.enabled`,
/// `ai.chatbot`, `finance.advanced`, `reports.advanced`, `sos.enabled`,
/// `storage.unlimited`, `families.max`; không key nào trong số đó nằm trong 26
/// key chính thức, nên các dòng tính năng phụ thuộc chúng ở màn Gói đăng ký
/// không bao giờ hiện, kể cả với gói trả phí.
class FeatureAccess {
  /// 26 key chính thức, giữ đúng thứ tự BE khai để đối chiếu nhanh khi BE đổi.
  static const officialKeys = <String>[
    'calendar.enabled',
    'calendar.reminders',
    'calendar.recurringEvents',
    'finance.budgetPlanning',
    'finance.financialGoals',
    'finance.budgetAlerts',
    'finance.supportRequests',
    'finance.reportExport',
    'finance.aiOcrSuggestion',
    'tasks.recurringTasks',
    'tasks.proofUpload',
    'tasks.rewardSettlement',
    'tasks.rewardAllocation',
    'album.videoUpload',
    'album.faceSuggestions',
    'ai.assistant',
    'ai.financeSummary',
    'ai.taskSummary',
    'ai.savingSuggestions',
    'sos.wearablePairing',
    'sos.fallDetection',
    'sos.liveLocation',
    'sos.routeHistory',
    'chat.privateChat',
    'chat.attachments',
    'chat.announcements',
  ];

  /// Nhãn tiếng Việt để render danh sách quyền lợi ở màn Gói đăng ký. Chỉ chứa
  /// key chính thức — thêm dòng mới thì thêm vào đây, đừng bịa key mới.
  static const officialKeyLabels = <String, String>{
    'calendar.enabled': 'Lịch gia đình',
    'calendar.reminders': 'Nhắc lịch',
    'calendar.recurringEvents': 'Lịch lặp lại',
    'finance.budgetPlanning': 'Lập kế hoạch ngân sách',
    'finance.financialGoals': 'Mục tiêu tài chính',
    'finance.budgetAlerts': 'Cảnh báo ngân sách',
    'finance.supportRequests': 'Yêu cầu hỗ trợ chi tiêu',
    'finance.reportExport': 'Xuất báo cáo tài chính',
    'finance.aiOcrSuggestion': 'Quét hoá đơn bằng AI',
    'tasks.recurringTasks': 'Công việc lặp lại',
    'tasks.proofUpload': 'Bằng chứng công việc',
    'tasks.rewardSettlement': 'Quyết toán phần thưởng',
    'tasks.rewardAllocation': 'Phân bổ phần thưởng',
    'album.videoUpload': 'Tải video album',
    'album.faceSuggestions': 'Gợi ý khuôn mặt AI',
    'ai.assistant': 'Trợ lý AI',
    'ai.financeSummary': 'Tóm tắt tài chính AI',
    'ai.taskSummary': 'Tóm tắt công việc AI',
    'ai.savingSuggestions': 'Gợi ý tiết kiệm AI',
    'sos.wearablePairing': 'Kết nối thiết bị đeo',
    'sos.fallDetection': 'Phát hiện té ngã',
    'sos.liveLocation': 'SOS vị trí trực tiếp',
    'sos.routeHistory': 'Lịch sử hành trình',
    'chat.privateChat': 'Chat riêng tư',
    'chat.attachments': 'Đính kèm chat',
    'chat.announcements': 'Thông báo gia đình',
  };

  /// Nhóm hiển thị cho từng key — khớp `group` bên
  /// `apps/web/src/lib/feature-catalog.ts` để màn Gói đăng ký (mobile) và
  /// trang Admin (web) chia danh sách quyền lợi theo cùng một cách, thay vì
  /// mobile hiện một danh sách phẳng 21 dòng khó quét mắt.
  static const officialKeyGroups = <String, String>{
    'calendar.enabled': 'Lịch gia đình',
    'calendar.reminders': 'Lịch gia đình',
    'calendar.recurringEvents': 'Lịch gia đình',
    'finance.budgetPlanning': 'Tài chính',
    'finance.financialGoals': 'Tài chính',
    'finance.budgetAlerts': 'Tài chính',
    'finance.supportRequests': 'Tài chính',
    'finance.reportExport': 'Tài chính',
    'finance.aiOcrSuggestion': 'Tài chính',
    'tasks.recurringTasks': 'Nhiệm vụ và phần thưởng',
    'tasks.proofUpload': 'Nhiệm vụ và phần thưởng',
    'tasks.rewardSettlement': 'Nhiệm vụ và phần thưởng',
    'tasks.rewardAllocation': 'Nhiệm vụ và phần thưởng',
    'album.videoUpload': 'Album',
    'album.faceSuggestions': 'Album',
    'ai.assistant': 'Trợ lý AI',
    'ai.financeSummary': 'Trợ lý AI',
    'ai.taskSummary': 'Trợ lý AI',
    'ai.savingSuggestions': 'Trợ lý AI',
    'sos.wearablePairing': 'SOS và an toàn',
    'sos.fallDetection': 'SOS và an toàn',
    'sos.liveLocation': 'SOS và an toàn',
    'sos.routeHistory': 'SOS và an toàn',
    'chat.privateChat': 'Nhắn tin',
    'chat.attachments': 'Nhắn tin',
    'chat.announcements': 'Nhắn tin',
  };

  final Map<String, dynamic> raw;

  const FeatureAccess(this.raw);

  /// BE chưa nói gì về quyền (thiếu field, hoặc trả `{}` — quan sát thật
  /// 2026-07-20 trên `GET /families/{id}/subscription`).
  ///
  /// Phải phân biệt với "đã trả lời và quyền = false": map rỗng mà coi là
  /// không-có-quyền thì gating fail-CLOSED, chặn cả tính năng gói Free vốn
  /// được dùng. Nơi gọi nên fail-open và để BE trả 403 quyết định.
  bool get isUnknown => raw.isEmpty;

  factory FeatureAccess.fromJson(dynamic json) {
    if (json is Map) {
      return FeatureAccess(Map<String, dynamic>.from(json));
    }
    return const FeatureAccess({});
  }

  bool get calendarEnabled =>
      flag('calendar.enabled', aliases: const ['calendarEnabled']);

  bool get calendarReminders =>
      flag('calendar.reminders', aliases: const ['calendarReminders']);

  bool get calendarRecurringEvents => flag(
    'calendar.recurringEvents',
    aliases: const ['calendarRecurringEvents'],
  );

  bool get albumFaceSuggestions =>
      flag('album.faceSuggestions', aliases: const ['albumFaceSuggestions']);

  bool get albumVideoUpload =>
      flag('album.videoUpload', aliases: const ['albumVideoUpload']);

  /// Trợ lý AI (chatbot). Alias giữ lại các tên FE từng đọc nhầm và tên phẳng,
  /// phòng khi BE còn plan cũ trong DB chưa migrate sang key chính thức.
  bool get aiAssistant => flag(
    'ai.assistant',
    aliases: const [
      'aiAssistant',
      'ai.enabled',
      'aiEnabled',
      'ai.chatbot',
      'aiChatbot',
    ],
  );

  bool get aiFinanceSummary =>
      flag('ai.financeSummary', aliases: const ['aiFinanceSummary']);

  bool get aiTaskSummary =>
      flag('ai.taskSummary', aliases: const ['aiTaskSummary']);

  bool get aiSavingSuggestions =>
      flag('ai.savingSuggestions', aliases: const ['aiSavingSuggestions']);

  bool flag(String path, {List<String> aliases = const []}) {
    final v = value(path, aliases: aliases);
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'enabled';
  }

  dynamic value(String path, {List<String> aliases = const []}) {
    final candidates = [path, ...aliases];
    for (final key in candidates) {
      if (raw.containsKey(key)) return raw[key];
      final nested = _nestedValue(key);
      if (nested != null) return nested;
    }
    return null;
  }

  dynamic _nestedValue(String path) {
    dynamic current = raw;
    for (final part in path.split('.')) {
      if (current is! Map || !current.containsKey(part)) return null;
      current = current[part];
    }
    return current;
  }
}
