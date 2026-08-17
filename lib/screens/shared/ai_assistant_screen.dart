import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ai_chatbot.dart';
import '../../providers/ai_chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/ai_chatbot_icon.dart';
import '../../widgets/json_report_view.dart';

/// Định dạng một field trong `preview` của đề xuất AI để người dùng đọc được.
///
/// `preview` là thứ DUY NHẤT người dùng dựa vào để kiểm tra trước khi bấm xác
/// nhận, nên không được in dữ liệu thô. BE trả thời gian dạng ISO UTC
/// (`2026-07-25T02:00:00.000Z` = 9h sáng giờ VN) và số tiền dạng số trần. In
/// nguyên xi thì người dùng thấy chuỗi UTC lệch 7 tiếng so với giờ họ vừa nói
/// với AI, và con số không có dấu phân cách.
///
/// Tách ra top-level để test được — xem
/// `test/ai_pending_action_contract_test.dart`.
String formatAiPreviewValue(String key, dynamic value) {
  if (value == null) return '-';
  if (value is List) {
    if (value.isEmpty) return '-';
    return value.map((e) => formatAiPreviewValue(key, e)).join(', ');
  }
  if (value is Map) {
    // Ưu tiên tên hiển thị nếu BE lồng object thay vì trả chuỗi.
    final named = value['name'] ?? value['title'] ?? value['fullName'];
    if (named != null) return named.toString();
    if (value.isEmpty) return '-';
    return value.values.take(3).join(' · ');
  }
  if (_isMoneyKey(key)) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    if (amount != null) return _formatPreviewMoney(amount);
  }
  if (_isTimeKey(key)) {
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return formatAiPreviewDateTime(parsed.toLocal());
  }
  // `uiHints.fields` (Sprint 2) dùng key tự do do BE đặt (`start`, `end`...),
  // không chắc lúc nào cũng khớp bộ khóa cứng ở `_isTimeKey` — quan sát thật
  // 2026-08-08: field "Bắt đầu"/"Kết thúc" của sự kiện lịch hiện nguyên văn
  // `2026-08-09T09:00:00+07:00` vì key không nằm trong danh sách trên. Nhận
  // diện thêm theo HÌNH DẠNG giá trị (chuỗi ISO 8601 đủ giờ phút) bất kể key
  // là gì — an toàn vì tiêu đề/địa điểm dạng chữ thường không khớp định dạng
  // này nên không bị định dạng nhầm.
  if (value is String && _looksLikeIsoDateTime(value)) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return formatAiPreviewDateTime(parsed.toLocal());
  }
  return value.toString();
}

final _isoDateTimePattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');

bool _looksLikeIsoDateTime(String value) => _isoDateTimePattern.hasMatch(value);

bool _isMoneyKey(String key) => const {
  'amount',
  'totalamount',
  'price',
  'reward',
  'rewardamount',
}.contains(key.toLowerCase());

bool _isTimeKey(String key) => const {
  'starttime',
  'endtime',
  'dueat',
  'duedate',
  'entrydate',
  'date',
  'remindat',
}.contains(key.toLowerCase());

String _formatPreviewMoney(double amount) {
  final grouped = amount.round().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return '$grouped ₫';
}

String formatAiPreviewDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Quan sát thật 2026-08-09: các field ID (`categoryId`, và sau đó phát hiện
/// thêm `goalId`, model tài chính, người nhận nhiệm vụ) hiện nguyên UUID thô
/// ("Danh mục: 0a3d7df8-517a-...") — không ai đọc hiểu được. Các danh sách
/// tương ứng (`FinanceProvider.categories/goals/models`, `FamilyProvider.members`)
/// đã tải sẵn ở app scope, tra ngược ID → tên hiển thị ngay tại đây; không
/// tìm thấy (đã xóa, hoặc chưa tải kịp) thì đành hiện lại ID thô — còn hơn
/// giả vờ có tên. Dùng chung cho cả `_PendingActionCard` (đang chờ xác nhận)
/// lẫn `_ResultCard` (đã xử lý xong).
String resolveCategoryName(BuildContext context, dynamic value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) return '-';
  final categories = context.read<FinanceProvider>().categories;
  for (final c in categories) {
    if (c.id == id) return c.name;
  }
  return id;
}

String resolveGoalName(BuildContext context, dynamic value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) return '-';
  final goals = context.read<FinanceProvider>().goals;
  for (final g in goals) {
    if (g.id == id) return g.goalName;
  }
  return id;
}

String resolveFinanceModelName(BuildContext context, dynamic value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) return '-';
  final models = context.read<FinanceProvider>().models;
  for (final m in models) {
    if (m.id == id) return m.name;
  }
  return id;
}

String resolveMemberName(BuildContext context, dynamic value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) return '-';
  final members = context.read<FamilyProvider>().members;
  for (final m in members) {
    if (m.id == id || m.userId == id) return m.name;
  }
  return id;
}

/// Điều phối theo key *và nhãn hiển thị* tới đúng resolver ID → tên ở trên.
///
/// `uiHints.fields` do BE soạn có thể dùng key kỹ thuật bất kỳ, trong khi nhãn
/// tiếng Việt vẫn nói rõ ngữ nghĩa (vd. "Người nhận"). Chỉ nhìn key khiến
/// preview nhiệm vụ rơi về UUID dù `FamilyProvider.members` đã có dữ liệu.
/// Field không khớp loại ID nào thì rơi về `formatAiPreviewValue` như cũ.
String resolveAiPreviewField(
  BuildContext context,
  String key,
  dynamic value, {
  String? label,
}) {
  final k = key.toLowerCase();
  final fieldIdentity = '$k ${label ?? ''}'.toLowerCase();
  // `uiHints.fields` đôi lúc đặt key trình bày thay vì `categoryId`, nhưng
  // nhãn vẫn là "Danh mục". Nhận theo cả hai để không in UUID thô.
  if (k == 'categoryid' ||
      fieldIdentity.contains('category') ||
      fieldIdentity.contains('danh mục') ||
      fieldIdentity.contains('danh muc')) {
    return resolveCategoryName(context, value);
  }
  if (k == 'goalid' || fieldIdentity.contains('mục tiêu')) {
    return resolveGoalName(context, value);
  }
  if (k == 'financialmodelid' ||
      k == 'modelid' ||
      fieldIdentity.contains('mô hình') ||
      fieldIdentity.contains('mo hinh')) {
    return resolveFinanceModelName(context, value);
  }
  // Tên field thực tế của BE cho người nhận chưa ổn định giữa preview cũ và
  // uiHints mới. Nhận cả key kỹ thuật lẫn nhãn tiếng Việt để chịu được
  // `assignedToMemberId`, `recipientId`, hoặc key lạ kèm "Người nhận".
  if (fieldIdentity.contains('assign') ||
      fieldIdentity.contains('recipient') ||
      fieldIdentity.contains('member') ||
      fieldIdentity.contains('người nhận') ||
      fieldIdentity.contains('nguoi nhan')) {
    return resolveMemberName(context, value);
  }
  return formatAiPreviewValue(key, value);
}

/// Tháng cần tải lại sau khi xác nhận đề xuất tạo sự kiện lịch.
///
/// `CalendarProvider.fetchEvents` chỉ tải đúng MỘT tháng. Sự kiện AI vừa tạo
/// không nhất thiết nằm trong tháng hiện tại — "9h sáng mai" vào ngày cuối
/// tháng là đã sang tháng sau — nên phải lấy tháng từ `startTime` trong
/// preview, nếu không người dùng xác nhận xong mở lịch ra không thấy gì.
DateTime calendarMonthToReload(Map<String, dynamic> preview) {
  for (final key in const ['startTime', 'startAt', 'date', 'endTime']) {
    final raw = preview[key];
    if (raw == null) continue;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.now();
}

/// Câu trạng thái dưới thẻ đề xuất. Xác nhận thành công phải nói rõ là **đã
/// xong**, không được dùng chung một câu cảnh báo với đề xuất hết hạn. Tách
/// top-level (không phải instance getter) để `_PendingActionCard` và
/// `_ResultCard` dùng chung — từ 2026-08-09, BE trả `RESULT_CARD` cho cả 3
/// trạng thái đã xử lý (REJECTED/CONFIRMED/EXPIRED), nên `_ResultCard` cũng
/// cần đúng màu/icon/câu chữ theo outcome thay vì mặc định "thành công".
String outcomeMessageFor(AiActionOutcome outcome) => switch (outcome) {
  AiActionOutcome.completed => 'Đã thực hiện xong.',
  AiActionOutcome.rejected => 'Bạn đã từ chối đề xuất này.',
  AiActionOutcome.expired =>
    'Đề xuất đã hết hạn. Hãy nhắn lại để AI tạo đề xuất mới.',
  AiActionOutcome.failed => 'Thực hiện đề xuất không thành công.',
  AiActionOutcome.pending => '',
};

Color outcomeColorFor(AiActionOutcome outcome) => switch (outcome) {
  AiActionOutcome.completed => AppColors.success,
  AiActionOutcome.rejected => AppColors.textMuted,
  AiActionOutcome.expired || AiActionOutcome.failed => AppColors.danger,
  AiActionOutcome.pending => AppColors.textSecondary,
};

IconData outcomeIconFor(AiActionOutcome outcome) => switch (outcome) {
  AiActionOutcome.completed => Icons.check_circle_rounded,
  AiActionOutcome.rejected => Icons.do_not_disturb_on_outlined,
  AiActionOutcome.expired => Icons.timer_off_outlined,
  AiActionOutcome.failed => Icons.error_outline_rounded,
  AiActionOutcome.pending => Icons.schedule_rounded,
};

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Quan sát runtime 2026-08-09: mở thẳng màn này (chưa từng ghé Sổ thu
      // chi/Ngân sách/Thành viên trong phiên) khiến `resolveAiPreviewField`
      // luôn rơi về ID thô vì `FinanceProvider.categories/goals/models` rỗng
      // — trước đó các resolver này ngầm dựa vào màn khác tải hộ. Tự tải ở
      // đây, không chặn bootstrap chat (fire-and-forget, chỉ phục vụ hiển
      // thị tên thay ID nên không cần đợi).
      final finance = context.read<FinanceProvider>();
      if (finance.categories.isEmpty ||
          finance.goals.isEmpty ||
          finance.models.isEmpty) {
        unawaited(finance.fetchAll());
      }
      final family = context.read<FamilyProvider>();
      if (family.members.isEmpty) {
        unawaited(family.fetchMembers());
      }
      await context.read<AiChatbotProvider>().bootstrap();
      // Bootstrap chọn sẵn hội thoại gần nhất, nhưng ListView mặc định đứng ở
      // đầu danh sách (đầu là Daily Brief nếu có). Không cuộn xuống thì người
      // dùng mở Trợ lý AI lên chỉ thấy "Tổng quan hôm nay" chứ không thấy
      // ngay đoạn chat đang dở — phải tự kéo xuống mới thấy.
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await context.read<AiChatbotProvider>().sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _sendPrompt(String prompt) async {
    if (context.read<AiChatbotProvider>().sending) return;
    _inputCtrl.text = prompt;
    await _send();
  }

  // Gửi tin nhắn ĐẦU TIÊN của hội thoại chuyển `_MessageList` từ
  // `_EmptyStateSuggestions` (ListView riêng, không gắn `_scrollCtrl`) sang
  // `ListView.builder` thật (mới gắn `_scrollCtrl`) — quan sát thật
  // 2026-08-08: `Future.delayed(80ms)` cũ chạy đúng lúc controller chưa kịp
  // gắn vào Scrollable mới, `animateTo` chạy trên vị trí cũ nên không cuộn
  // được, người dùng thấy màn đứng ở đầu trang dù đã có tin nhắn mới.
  // `addPostFrameCallback` đợi đúng sau khi frame build/layout xong (controller
  // đã chắc chắn gắn vào Scrollable hiện tại) thay vì đoán một mốc thời gian
  // cố định — đúng cả với chuyển tiếp state lẫn tin nhắn giữa hội thoại dài.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // Trước đây bấm ☀️ xong tự cuộn lên đầu để "xem" Daily Brief — đúng ý muốn
  // ban đầu nhưng UX bất tiện thật: xem xong lại phải tự kéo xuống mới về
  // được đoạn chat đang dở, trong khi thoát màn rồi mở lại thì mặc định vẫn
  // đứng ở cuối (đúng ý hơn). Đổi thành KHÔNG đổi vị trí cuộn — chỉ bỏ ẩn rồi
  // báo bằng SnackBar, người dùng tự kéo lên xem khi muốn, không bị kéo đi
  // khỏi chỗ đang đọc.
  Future<void> _showDailyBriefAgain() async {
    await context.read<AiChatbotProvider>().showDailyBrief();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hiện lại "Tổng quan hôm nay" — kéo lên đầu để xem'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe cả FamilyProvider: preview task có thể mở trước khi danh sách
    // thành viên tải xong. Nếu chỉ Consumer AiChatbotProvider, dữ liệu member
    // về sau sẽ không kích hoạt build lại và UUID "Người nhận" bị kẹt trên
    // thẻ cho tới khi có một thay đổi chat khác.
    return Consumer2<AiChatbotProvider, FamilyProvider>(
      builder: (context, ai, _, __) {
        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            backgroundColor: context.colors.surface,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: context.colors.textPrimary,
              ),
            ),
            title: Row(
              children: [
                const AiChatbotIcon(size: 30),
                const SizedBox(width: 8),
                Text(
                  'Trợ lý AI',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              if (ai.dailyBrief == null)
                IconButton(
                  tooltip: 'Xem tổng quan hôm nay',
                  onPressed: _showDailyBriefAgain,
                  icon: Icon(
                    Icons.wb_sunny_outlined,
                    color: context.colors.textPrimary,
                  ),
                ),
              IconButton(
                tooltip: 'Hội thoại',
                onPressed: () => _showConversationSheet(context),
                icon: Icon(
                  Icons.forum_outlined,
                  color: context.colors.textPrimary,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: context.colors.textPrimary,
                ),
                onSelected: (value) {
                  if (value == 'new') {
                    context.read<AiChatbotProvider>().startNewConversation();
                  } else if (value == 'delete') {
                    _confirmDeleteConversation(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'new',
                    child: Text('Hội thoại mới'),
                  ),
                  if (ai.currentConversationId != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa hội thoại này'),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Divider(height: 1, color: context.colors.divider),
              if (ai.loadingAccess && ai.messages.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!ai.canUseAssistant)
                // Đã biết chắc gói không có ai.assistant → chặn tại đây, không
                // gọi API để rồi hiện banner đỏ 403.
                const Expanded(child: _UpgradePanel())
              else ...[
                if (ai.error != null) _ErrorBanner(message: ai.error!),
                Expanded(
                  child: _MessageList(
                    scrollCtrl: _scrollCtrl,
                    onPickPrompt: _sendPrompt,
                  ),
                ),
                // Màn rỗng đã có bảng gợi ý đầy đủ, không cần lặp lại dải chip.
                if (ai.messages.isNotEmpty) _QuickPrompts(onPick: _sendPrompt),
                _Composer(
                  controller: _inputCtrl,
                  sending: ai.sending,
                  onSend: _send,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showConversationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) {
        return Consumer<AiChatbotProvider>(
          builder: (context, ai, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hội thoại AI',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_comment_outlined),
                      title: const Text('Tạo hội thoại mới'),
                      onTap: () {
                        ai.startNewConversation();
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                    Flexible(
                      child: ai.loadingConversations
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              shrinkWrap: true,
                              // +1 cho hàng "Tải thêm" ở cuối khi còn trang sau.
                              itemCount:
                                  ai.conversations.length +
                                  (ai.hasMoreConversations ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= ai.conversations.length) {
                                  return _LoadMoreTile(
                                    label: 'Tải thêm hội thoại',
                                    loading: ai.loadingMoreConversations,
                                    onTap: ai.loadMoreConversations,
                                  );
                                }
                                final c = ai.conversations[i];
                                final selected =
                                    c.id == ai.currentConversationId;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: selected
                                        ? AppColors.primary500
                                        : context.colors.textMuted,
                                  ),
                                  title: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      c.lastMessage == null ||
                                          c.lastMessage!.isEmpty
                                      ? null
                                      : Text(
                                          c.lastMessage!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  onTap: () async {
                                    Navigator.of(sheetContext).pop();
                                    await ai.selectConversation(c.id);
                                    if (!mounted) return;
                                    _scrollToBottom();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteConversation(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hội thoại?'),
        content: const Text('Toàn bộ tin nhắn trong hội thoại này sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AiChatbotProvider>().deleteCurrentConversation();
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final ValueChanged<String> onPickPrompt;

  const _MessageList({required this.scrollCtrl, required this.onPickPrompt});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiChatbotProvider>();
    final brief = ai.dailyBrief;
    // Chỉ chặn cả màn bằng spinner khi CHƯA có gì để xem (tải lần đầu). Xác
    // nhận/từ chối đề xuất gọi `fetchMessages()` để làm mới trạng thái —
    // trước đây điều kiện này không loại trừ trường hợp đã có `messages`,
    // nên mỗi lần bấm Xác nhận/Hủy, `ListView.builder` bị thay hẳn bằng
    // `Center` rồi dựng lại — mất luôn vị trí cuộn cũ, người dùng thấy đoạn
    // chat "nhảy" về đầu trang dù không hề cuộn.
    if (ai.loadingMessages && ai.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = ai.messages;
    if (messages.isEmpty) {
      return _EmptyStateSuggestions(onPick: onPickPrompt, dailyBrief: brief);
    }

    // Daily Brief và hàng "Tải thêm" đều nằm TRONG danh sách cuộn được, không
    // phải sibling cố định của nó.
    //
    // Bug thật đã gặp: từng đặt `_DailyBriefCard` làm phần tử cố định phía
    // trên `Expanded(child: ListView)` trong một `Column`. Nội dung Daily
    // Brief (JsonReportView đệ quy nhiều nhóm: Family/Scope/Task/Calendar/
    // Finance…) cao hơn hẳn một bubble chat thường, và phần tử cố định trong
    // `Column` không tự co khi thiếu chỗ — Flutter báo tràn layout (vạch
    // vàng-đen "RenderFlex overflowed") ngay khi nội dung dài hơn khoảng trống
    // còn lại phía trên composer. Đưa thẳng vào làm item đầu của
    // `ListView.builder` thì nó cuộn được như mọi item khác, không bao giờ
    // tràn nữa — đúng cách `_LoadMoreTile` đã làm từ trước.
    final leadingBrief = brief != null ? 1 : 0;
    final leadingLoadMore = ai.hasMoreMessages ? 1 : 0;
    final leading = leadingBrief + leadingLoadMore;
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: leading + messages.length + (ai.sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (brief != null && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DailyBriefCard(brief: brief, onPick: onPickPrompt),
          );
        }
        final afterBrief = i - leadingBrief;
        if (leadingLoadMore == 1 && afterBrief == 0) {
          return _LoadMoreTile(
            label: 'Tải thêm tin nhắn',
            loading: ai.loadingMoreMessages,
            onTap: ai.loadMoreMessages,
          );
        }
        final index = afterBrief - leadingLoadMore;
        if (index >= messages.length) return const _TypingBubble();
        return _MessageBubble(
          message: messages[index],
          onPickPrompt: onPickPrompt,
        );
      },
    );
  }
}

/// Card "Tổng quan hôm nay" — `GET .../ai-chatbot/daily-brief` (Sprint 2, tùy
/// chọn). BE không cho tên field con cụ thể nên dùng `JsonReportView` — quy
/// ước sẵn có của repo cho response chưa rõ schema (xem `CLAUDE.md` Rule 4).
class _DailyBriefCard extends StatelessWidget {
  final AiDailyBrief brief;
  final ValueChanged<String> onPick;

  const _DailyBriefCard({required this.brief, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 16,
                color: AppColors.primary600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tổng quan hôm nay',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary600,
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    context.read<AiChatbotProvider>().dismissDailyBrief(),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          JsonReportView(data: brief.raw),
          if (brief.suggestedPrompts.isNotEmpty)
            _QuickActionChips(actions: brief.suggestedPrompts, onPick: onPick),
        ],
      ),
    );
  }
}

/// Nhóm gợi ý cho màn rỗng.
///
/// Phần hỏi đáp tra cứu dữ liệu gia đình vốn đã chạy được đầu-cuối, nhưng hầu
/// như không ai dùng vì mở màn ra chỉ thấy ô nhập trống. Bộ gợi ý này chia rõ
/// hai loại: câu chỉ TRA CỨU (trả lời ngay) và câu khiến AI TẠO đề xuất (phải
/// bấm xác nhận mới ghi dữ liệu) — để người dùng biết trước điều gì sẽ xảy ra.
/// Câu gợi ý "nhờ AI ghi khoản chi" trước đây cố định `200.000đ tiền ăn uống`
/// — bấm hoài chỉ tạo đúng một khoản y hệt, test không thấy AI xử lý số/danh
/// mục khác nhau thế nào. Random một câu trong vài mẫu thực tế mỗi lần dựng
/// widget để mỗi lần mở màn/mỗi lần thấy chip là một khoản khác nhau.
///
/// Gộp chung chi lẫn thu trong một chip "Tạo thu/chi" thay vì tách 2 nút
/// riêng hay làm submenu chọn loại — đây chỉ là 1 gợi ý mở đầu câu chat, AI
/// đã hiểu được cả hai qua câu tự nhiên, tách thêm nút chỉ chật chỗ dải chip
/// mà không giúp AI "thông minh" hơn. Trộn cả ví dụ thu vào bộ random để
/// người dùng tự khám phá được cả hai khả năng khi bấm lại nhiều lần.
const _ledgerPromptSamples = [
  'Ghi khoản chi 45.000đ tiền cà phê sáng nay',
  'Ghi khoản chi 120.000đ tiền chợ hôm nay',
  'Ghi khoản chi 60.000đ tiền xăng xe hôm nay',
  'Ghi khoản chi 250.000đ tiền sửa xe tuần này',
  'Ghi khoản chi 85.000đ tiền ăn trưa hôm nay',
  'Ghi khoản chi 500.000đ tiền học phí tháng này',
  'Ghi khoản thu 2.000.000đ tiền thưởng tháng này',
  'Ghi khoản thu 500.000đ tiền lì xì hôm nay',
  'Ghi khoản thu 1.500.000đ tiền làm thêm tuần này',
];

String _randomLedgerPrompt() =>
    _ledgerPromptSamples[Random().nextInt(_ledgerPromptSamples.length)];

class AiPromptGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> prompts;

  const AiPromptGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.prompts,
  });
}

/// Gợi ý câu hỏi cho màn Trợ lý AI, chia theo quyền của người đang đăng nhập.
///
/// Gợi ý phải theo vai trò, không dùng chung một danh sách cứng. Thành viên
/// thường bị chặn ở sổ quỹ chung (`GET /finance/ledger/entries` trả 403 — đã
/// chốt là đúng thiết kế) và không có quyền tạo giao dịch, nhiệm vụ hay sự kiện
/// lịch. Đưa những câu đó vào màn của họ là dẫn thẳng vào ngõ cụt: quan sát
/// runtime 2026-08-07, Thành viên nhờ ghi khoản chi thì AI trả lời "vui lòng
/// xác nhận trên ứng dụng" nhưng backend KHÔNG kèm `pendingAction`, nên không
/// có nút nào để bấm.
///
/// `canManageFinance` đúng với Trưởng nhóm và Phó nhóm (`isAdministrative`).
List<AiPromptGroup> aiPromptGroupsFor({required bool canManageFinance}) {
  if (!canManageFinance) {
    return [
      AiPromptGroup(
        title: 'Việc của tôi',
        icon: Icons.checklist_rounded,
        color: AppColors.link,
        prompts: [
          'Tôi còn nhiệm vụ nào chưa hoàn thành?',
          'Nhiệm vụ nào của tôi sắp tới hạn?',
          'Tôi được bao nhiêu điểm thưởng tháng này?',
        ],
      ),
      AiPromptGroup(
        title: 'Chi tiêu của tôi',
        icon: Icons.savings_outlined,
        color: AppColors.success,
        prompts: [
          'Tháng này tôi đã tiêu bao nhiêu?',
          'Hạn mức chi tiêu của tôi còn lại bao nhiêu?',
        ],
      ),
      AiPromptGroup(
        title: 'Lịch gia đình',
        icon: Icons.event_note_rounded,
        color: AppColors.calTravel,
        prompts: ['Tuần này nhà mình có lịch gì?'],
      ),
    ];
  }

  return [
    AiPromptGroup(
      title: 'Tra cứu tài chính',
      icon: Icons.query_stats_rounded,
      color: AppColors.success,
      prompts: [
        'Tháng này nhà mình đã chi bao nhiêu?',
        'Khoản chi lớn nhất tháng này là gì?',
        'So sánh chi tiêu tháng này với tháng trước',
        'Mục tiêu tiết kiệm của nhà mình còn thiếu bao nhiêu?',
      ],
    ),
    AiPromptGroup(
      title: 'Mô hình tài chính & ngân sách',
      icon: Icons.account_balance_rounded,
      color: AppColors.primary600,
      prompts: [
        'Nhà mình đang áp dụng mô hình tài chính nào?',
        'Hũ nào đang chi vượt mục tiêu?',
        'Kế hoạch ngân sách tháng này còn lại bao nhiêu?',
        'Tháng này đã chia quỹ theo mô hình chưa?',
      ],
    ),
    AiPromptGroup(
      title: 'Tra cứu nhiệm vụ & lịch',
      icon: Icons.event_note_rounded,
      color: AppColors.link,
      prompts: [
        'Ai đang còn nhiệm vụ chưa hoàn thành?',
        'Nhiệm vụ nào sắp tới hạn?',
        'Tuần này nhà mình có lịch gì?',
      ],
    ),
    AiPromptGroup(
      title: 'Nhờ AI tạo (bạn xác nhận rồi mới ghi)',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.calTravel,
      prompts: [
        _randomLedgerPrompt(),
        'Ghi khoản thu 5.000.000đ lương tháng này',
        'Tạo nhiệm vụ rửa bát tối nay',
        'Tạo lịch khám sức khỏe 9h sáng mai',
      ],
    ),
  ];
}

class _EmptyStateSuggestions extends StatelessWidget {
  final ValueChanged<String> onPick;
  final AiDailyBrief? dailyBrief;

  const _EmptyStateSuggestions({required this.onPick, this.dailyBrief});

  @override
  Widget build(BuildContext context) {
    final canManageFinance =
        context.watch<AuthProvider>().user?.canManageFinance ?? false;
    final groups = aiPromptGroupsFor(canManageFinance: canManageFinance);
    final brief = dailyBrief;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      children: [
        // `ListView` này vốn đã cuộn được — Daily Brief nằm ngay trong danh
        // sách children như mọi mục khác, không phải sibling cố định, nên
        // không có nguy cơ tràn layout dù nội dung có dài (xem bug đã sửa ở
        // `_MessageList`, cùng nguyên nhân, khác chỗ đặt).
        if (brief != null) ...[
          _DailyBriefCard(brief: brief, onPick: onPick),
          const SizedBox(height: 16),
        ],
        Center(
          child: Column(
            children: [
              const AiChatbotIcon(size: 64),
              const SizedBox(height: 12),
              Text(
                'Xin chào, tôi là trợ lý FamilyCare.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tôi trả lời dựa trên dữ liệu gia đình bạn được phép xem. '
                'Thử một câu bên dưới, hoặc gõ câu của bạn.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (final group in groups) ...[
          Row(
            children: [
              Icon(group.icon, size: 16, color: group.color),
              const SizedBox(width: 6),
              Text(
                group.title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: group.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final prompt in group.prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onPick(prompt),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          prompt,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.35,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.north_east_rounded,
                        size: 14,
                        color: context.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        // Nói thẳng giới hạn thay vì để người dùng hỏi rồi mới biết mình không
        // có quyền. Thành viên không thấy nhóm "Nhờ AI tạo" nên phải giải thích
        // vì sao, nếu không họ tưởng tính năng bị lỗi.
        if (!canManageFinance)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ghi thu chi vào quỹ chung, tạo nhiệm vụ hay tạo lịch là '
                    'việc của Trưởng nhóm và Phó nhóm. Bạn vẫn xem được phần '
                    'của mình và hỏi tôi bất cứ điều gì.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.45,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hiện khi BE đã nói rõ gói không có `ai.assistant`.
class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel();

  @override
  Widget build(BuildContext context) {
    final canManage =
        context.read<AuthProvider>().user?.canManageSubscription ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'Gói hiện tại chưa có Trợ lý AI',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canManage
                  ? 'Nâng gói đăng ký để hỏi đáp về chi tiêu, nhiệm vụ và lịch '
                        'gia đình bằng ngôn ngữ tự nhiên.'
                  : 'Trưởng nhóm gia đình có thể nâng gói để mở tính năng này.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.push('/manager/subscription'),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Xem gói đăng ký'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Map tên icon BE gửi trong `uiHints.icon` sang `IconData`.
///
/// BE chưa chốt format chuỗi (material icon name? emoji? từ khoá module?) —
/// đọc phòng thủ theo từ khoá module, không throw khi gặp tên lạ.
/// [fallback] nên khớp `displayStyle` của nơi gọi.
IconData _resolveHintIcon(String? icon, {required IconData fallback}) {
  final key = icon?.toLowerCase().trim() ?? '';
  if (key.isEmpty) return fallback;
  if (key.contains('finance') ||
      key.contains('money') ||
      key.contains('wallet')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (key.contains('task') || key.contains('chore')) {
    return Icons.task_alt_rounded;
  }
  if (key.contains('calendar') || key.contains('event')) {
    return Icons.event_available_outlined;
  }
  if (key.contains('sos') ||
      key.contains('safety') ||
      key.contains('warning')) {
    return Icons.shield_outlined;
  }
  if (key.contains('saving') || key.contains('goal')) {
    return Icons.savings_outlined;
  }
  if (key.contains('insight') || key.contains('analysis')) {
    return Icons.insights_rounded;
  }
  return fallback;
}

/// Chip gợi ý dưới tin nhắn AI (`uiHints.quickActions` hoặc
/// `dailyBrief.suggestedPrompts`) — bấm gửi `prompt`, không gửi `label`.
class _QuickActionChips extends StatelessWidget {
  final List<AiQuickAction> actions;
  final ValueChanged<String> onPick;

  const _QuickActionChips({required this.actions, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (a) => ActionChip(
                label: Text(a.label),
                onPressed: () => onPick(a.prompt),
                backgroundColor: context.colors.background,
                side: BorderSide(color: context.colors.divider),
                labelStyle: GoogleFonts.inter(fontSize: 12.5),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final ValueChanged<String> onPickPrompt;

  const _MessageBubble({required this.message, required this.onPickPrompt});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isUser;
    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: _TextBubble(text: message.content, isMe: true),
      );
    }

    final quickActions = message.uiHints?.quickActions ?? const [];
    final Widget content = switch (message.effectiveDisplayStyle) {
      AiDisplayStyle.insightCard => _InsightCard(message: message),
      AiDisplayStyle.permissionNotice => _PermissionNoticeCard(
        content: message.content,
      ),
      AiDisplayStyle.resultCard => _ResultCard(message: message),
      AiDisplayStyle.actionPlanCard => _ActionPlanCard(message: message),
      AiDisplayStyle.actionCard when message.pendingAction != null =>
        _ActionCardWithIntro(message: message),
      // ACTION_CARD mà thiếu pendingAction không nên xảy ra theo contract —
      // rơi về bubble text an toàn thay vì vẽ nút giả, có log để phát hiện.
      AiDisplayStyle.actionCard => Builder(
        builder: (_) {
          debugPrint(
            'AIAssistantScreen: displayStyle=ACTION_CARD nhưng không có '
            'pendingAction, msgId=${message.id} — hiện bubble text thay vì '
            'vẽ nút giả.',
          );
          return _TextBubble(text: message.content, isMe: false);
        },
      ),
      AiDisplayStyle.text => _TextBubble(text: message.content, isMe: false),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: AiChatbotIcon(size: 28),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              if (quickActions.isNotEmpty)
                _QuickActionChips(actions: quickActions, onPick: onPickPrompt),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bubble chữ thường — dùng cho `TEXT` và cho tin nhắn của người dùng.
/// AI trả nguyên văn markdown `**chữ đậm**` để nhấn tiêu đề/số liệu (ví dụ
/// `**Nhận định:**`, `**Đề xuất:**`). Trước đây vẽ bằng `Text` trơn nên người
/// dùng thấy cả cặp dấu `**` xấu xí thay vì chữ đậm. Không kéo cả thư viện
/// markdown chỉ để bôi đậm — parse tối thiểu bằng regex, phần nằm giữa
/// `**...**` in đậm + tô màu nổi bật, phần còn lại giữ nguyên.
/// Kiểu của một dòng trong câu trả lời AI sau khi bóc ký hiệu markdown.
enum AiLineKind { heading, bullet, normal }

/// Một dòng đã bóc ký hiệu markdown: [text] là phần chữ sạch, không còn `#`
/// hay `-` đứng đầu.
class AiTextLine {
  const AiTextLine(this.kind, this.text, {this.headingLevel = 0});

  final AiLineKind kind;
  final String text;

  /// 1..6 với [AiLineKind.heading], 0 với các kiểu còn lại.
  final int headingLevel;

  @override
  String toString() => '$kind($headingLevel): $text';
}

/// Tách câu trả lời AI thành từng dòng đã bóc ký hiệu markdown.
///
/// BE trả nội dung dạng markdown nhưng FE chỉ từng xử lý `**đậm**`, nên các ký
/// hiệu còn lại lọt thẳng ra màn hình (quan sát runtime 2026-08-17: câu trả lời
/// hiện nguyên `### Tháng 8/2026, gia đình bạn đã tiêu hết:`). BE xác nhận đây
/// là phần FE tự xử lý, không đổi output phía họ.
///
/// Cố ý **không** thêm package markdown: chỉ cần đúng 2 ký hiệu, mà
/// `flutter_markdown` kéo theo cả bộ style riêng khó khớp design system.
///
/// Quy tắc bám chuẩn markdown để không nhận nhầm:
/// - Tiêu đề phải là `#` đầu dòng **và có khoảng trắng ngay sau** → hashtag
///   kiểu `#giadinh` không bị hiểu thành tiêu đề.
/// - Gạch đầu dòng cũng phải có khoảng trắng sau `-`/`*` → dấu trừ trong
///   `-500.000đ` không bị đổi thành bullet.
List<AiTextLine> parseAiMarkdownLines(String raw) {
  final headingPattern = RegExp(r'^ {0,3}(#{1,6})[ \t]+(.*)$');
  final bulletPattern = RegExp(r'^ {0,3}[-*][ \t]+(.*)$');

  return raw.split('\n').map((line) {
    final heading = headingPattern.firstMatch(line);
    if (heading != null) {
      return AiTextLine(
        AiLineKind.heading,
        heading.group(2)!.trim(),
        headingLevel: heading.group(1)!.length,
      );
    }
    final bullet = bulletPattern.firstMatch(line);
    if (bullet != null) {
      return AiTextLine(AiLineKind.bullet, bullet.group(1)!.trim());
    }
    return AiTextLine(AiLineKind.normal, line);
  }).toList();
}

class _AiRichText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color boldColor;

  const _AiRichText({
    required this.text,
    required this.style,
    required this.boldColor,
  });

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

  /// Bóc `**đậm**` trong MỘT dòng thành các span.
  List<InlineSpan> _inlineSpans(String line, TextStyle lineStyle) {
    if (!line.contains('**')) return [TextSpan(text: line)];
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _boldPattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: lineStyle.copyWith(
            fontWeight: FontWeight.w800,
            color: boldColor,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = parseAiMarkdownLines(text);
    // Không có ký hiệu nào cần xử lý thì giữ nguyên đường cũ cho nhẹ.
    final plain =
        !text.contains('**') && lines.every((l) => l.kind == AiLineKind.normal);
    if (plain) return Text(text, style: style);

    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      switch (line.kind) {
        case AiLineKind.heading:
          // Tiêu đề đậm và to hơn một nấc; cấp càng sâu thì càng nhỏ lại,
          // nhưng không bao giờ nhỏ hơn chữ thường.
          final bump = line.headingLevel <= 2 ? 2.0 : 1.0;
          final headingStyle = style.copyWith(
            fontSize: (style.fontSize ?? 15) + bump,
            fontWeight: FontWeight.w800,
            color: boldColor,
          );
          spans.add(
            TextSpan(
              style: headingStyle,
              children: _inlineSpans(line.text, headingStyle),
            ),
          );
        case AiLineKind.bullet:
          spans.add(const TextSpan(text: '  •  '));
          spans.add(
            TextSpan(style: style, children: _inlineSpans(line.text, style)),
          );
        case AiLineKind.normal:
          spans.addAll(_inlineSpans(line.text, style));
      }
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _TextBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.link : context.colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _AiRichText(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.35,
          color: isMe ? Colors.white : context.colors.textPrimary,
        ),
        boldColor: isMe ? Colors.white : AppColors.primary600,
      ),
    );
  }
}

/// `INSIGHT_CARD` — phân tích/gợi ý, không có nút xác nhận.
class _InsightCard extends StatelessWidget {
  final AiMessage message;

  const _InsightCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final hints = message.uiHints;
    final color = AppColors.primary600;
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _resolveHintIcon(hints?.icon, fallback: Icons.insights_rounded),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (hints?.title?.trim().isNotEmpty ?? false)
                      ? hints!.title!
                      : 'Phân tích',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (hints?.confidenceLabel?.trim().isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hints!.confidenceLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _AiRichText(
            text: message.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textPrimary,
            ),
            boldColor: color,
          ),
        ],
      ),
    );
  }
}

/// `PERMISSION_NOTICE` — không đủ quyền. Không có nút xác nhận/từ chối nào,
/// bất kể `content` có chữ gì.
class _PermissionNoticeCard extends StatelessWidget {
  final String content;

  const _PermissionNoticeCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: context.colors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AiRichText(
              text: content,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.4,
                color: context.colors.textSecondary,
              ),
              boldColor: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `RESULT_CARD` — kết quả sau khi một đề xuất đã được confirm. Không có nút.
class _ResultCard extends StatelessWidget {
  final AiMessage message;

  const _ResultCard({required this.message});

  @override
  Widget build(BuildContext context) {
    // BE xác nhận 2026-08-09: RESULT_CARD giờ dùng cho cả 3 trạng thái đã xử
    // lý (REJECTED/CONFIRMED/EXPIRED), không chỉ xác nhận thành công — không
    // còn được mặc định tô xanh "thành công" cho mọi trường hợp. Không có
    // `pendingAction` đính kèm (result thuần thông tin) thì coi như thành
    // công, giữ đúng hành vi hiển thị cũ trước khi có outcome đa dạng.
    final outcome = message.pendingAction?.outcome ?? AiActionOutcome.completed;
    final color = outcomeColorFor(outcome);
    final icon = outcomeIconFor(outcome);
    final title = message.uiHints?.title?.trim();
    final fields = message.pendingAction?.displayFields ?? const [];
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              if (title != null && title.isNotEmpty)
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _AiRichText(
            text: message.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textPrimary,
            ),
            boldColor: color,
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final f in fields)
              _detailRow(context, f.label, f.key, f.value),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String key,
    dynamic value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            resolveAiPreviewField(context, key, value, label: label),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// `ACTION_PLAN_CARD` — kế hoạch nhiều bước (BE Sprint 3, 2026-08-09). Mỗi
/// bước là một phần tử `message.pendingActions[n]`; tái dùng nguyên
/// `_PendingActionCard` cho từng bước (đã có `stepIndex` để gọi đúng
/// endpoint theo bước: `confirmStep`/`rejectStep`) thay vì viết lại UI thẻ.
class _ActionPlanCard extends StatelessWidget {
  final AiMessage message;

  const _ActionPlanCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final steps = message.pendingActions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.trim().isNotEmpty)
          _TextBubble(text: message.content, isMe: false),
        // Không nên xảy ra theo contract (BE nói ACTION_PLAN_CARD luôn kèm
        // pendingActions[]) — phòng thủ, đừng vẽ khung rỗng nếu thiếu.
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PendingActionCard(
              messageId: step.messageId.isNotEmpty
                  ? step.messageId
                  : message.id,
              action: step,
              stepIndex: step.actionIndex,
            ),
          ),
      ],
    );
  }
}

/// Bong bóng lời giới thiệu của AI (`message.content`) + thẻ xác nhận bên
/// dưới — giữ đúng bố cục cũ (`ACTION_CARD` luôn có một câu dẫn của AI trước
/// khi tới thẻ).
class _ActionCardWithIntro extends StatelessWidget {
  final AiMessage message;

  const _ActionCardWithIntro({required this.message});

  @override
  Widget build(BuildContext context) {
    final action = message.pendingAction!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.trim().isNotEmpty)
          _TextBubble(text: message.content, isMe: false),
        _PendingActionCard(
          messageId: action.messageId.isNotEmpty
              ? action.messageId
              : message.id,
          action: action,
        ),
      ],
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final String messageId;
  final AiPendingAction action;

  /// Khác `null` khi thẻ này là MỘT BƯỚC trong kế hoạch nhiều bước
  /// (`ACTION_PLAN_CARD`, BE Sprint 3 2026-08-09) — khi đó Xác nhận/Hủy phải
  /// gọi endpoint theo `actionIndex` (`confirmStep`/`rejectStep`) thay vì
  /// theo message (`confirmAction`/`rejectAction`). `null` = hành vi cũ y
  /// nguyên, dùng cho thẻ hành động đơn lẻ.
  final int? stepIndex;

  const _PendingActionCard({
    required this.messageId,
    required this.action,
    this.stepIndex,
  });

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiChatbotProvider>();
    // `ALLOCATE_FUND_BY_MODEL` chỉ có thể chạy khi family đã có model ACTIVE.
    // AI/BE vẫn là nguồn quyết định cuối cùng, nhưng chặn sớm ở đây để một
    // family mới không nhận thẻ "Xác nhận chia quỹ" rồi mới gặp lỗi sau khi
    // bấm. Dùng `any(isActive)` thay vì `activeModel`: getter đó có fallback
    // sang model đầu tiên cho một số màn Finance, còn API allocation yêu cầu
    // đúng model đang áp dụng.
    final requiresActiveFinanceModel =
        action.actionType.toUpperCase() == 'ALLOCATE_FUND_BY_MODEL';
    final hasActiveFinanceModel = context.watch<FinanceProvider>().models.any(
      (model) => model.isActive,
    );
    final blockedByMissingFinanceModel =
        requiresActiveFinanceModel && !hasActiveFinanceModel;
    final busy = stepIndex != null
        ? ai.isStepBusy(messageId, stepIndex!)
        : ai.isActionBusy(messageId);
    final enabled = action.isPending && !busy;
    final canConfirm = enabled && !blockedByMissingFinanceModel;
    final color = _actionColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_actionIcon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.displayTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (action.uiHints?.description?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          action.uiHints!.description!,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    // Loại đề xuất FE chưa biết thì hiện luôn mã BE gửi. Nếu
                    // không, mọi tên lạ đều rơi vào nhãn chung "Thực hiện đề
                    // xuất" và không ai biết BE vừa gửi cái gì.
                    if (!action.isKnownActionType &&
                        action.actionType.isNotEmpty)
                      Text(
                        action.actionType,
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _statusChip(color),
            ],
          ),
          if (action.displayFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final f in action.displayFields)
              _previewRow(context, f.key, f.label, f.value),
          ],
          const SizedBox(height: 10),
          if (!action.isPending)
            Row(
              children: [
                Icon(_outcomeIcon, size: 14, color: _outcomeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _outcomeMessage,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _outcomeColor,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled
                        ? () {
                            final provider = context.read<AiChatbotProvider>();
                            if (stepIndex != null) {
                              provider.rejectStep(messageId, stepIndex!);
                            } else {
                              provider.rejectAction(messageId);
                            }
                          }
                        : null,
                    child: Text(action.uiHints?.secondaryActionLabel ?? 'Hủy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: canConfirm
                        ? () => _confirmAndReload(context)
                        : null,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            action.uiHints?.primaryActionLabel ?? 'Xác nhận',
                          ),
                  ),
                ),
              ],
            ),
            if (blockedByMissingFinanceModel)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cần tạo và áp dụng mô hình tài chính trước khi chia quỹ. '
                  'Hãy vào Mô hình tài chính, sau đó nhắn AI tạo đề xuất mới.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.danger,
                  ),
                ),
              ),
            // BE xác nhận 2026-08-09: KHÔNG có endpoint "sửa" pending action.
            // Luồng chính thức là mở form tạo dữ liệu tương ứng, điền sẵn từ
            // `pendingAction.preview`, cho người dùng chỉnh trước khi lưu —
            // FE chưa có màn prefill riêng cho từng actionType nên áp dụng
            // đúng fallback BE xác nhận là hợp lệ: từ chối đề xuất hiện tại
            // rồi để người dùng tự gõ lại câu mới cho AI.
            if (enabled &&
                (action.uiHints?.editActionLabel?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _handleEdit(context),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(action.uiHints!.editActionLabel!),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context) async {
    final ai = context.read<AiChatbotProvider>();
    if (stepIndex != null) {
      await ai.rejectStep(messageId, stepIndex!);
    } else {
      await ai.rejectAction(messageId);
    }
  }

  /// Câu trạng thái dưới thẻ. Xác nhận thành công phải nói rõ là **đã xong**,
  /// không được dùng chung một câu cảnh báo với đề xuất hết hạn.
  String get _outcomeMessage => outcomeMessageFor(action.outcome);

  Color get _outcomeColor => outcomeColorFor(action.outcome);

  IconData get _outcomeIcon => outcomeIconFor(action.outcome);

  Widget _statusChip(Color color) {
    final text = switch (action.outcome) {
      AiActionOutcome.pending => 'Chờ xác nhận',
      AiActionOutcome.completed => 'Đã thực hiện',
      AiActionOutcome.rejected => 'Đã từ chối',
      AiActionOutcome.expired => 'Hết hạn',
      AiActionOutcome.failed => 'Thất bại',
    };
    // Hết hạn/thất bại phải đổi màu chip, không dùng màu của loại đề xuất.
    final chipColor = switch (action.outcome) {
      AiActionOutcome.expired || AiActionOutcome.failed => AppColors.danger,
      AiActionOutcome.rejected => AppColors.textMuted,
      _ => color,
    };
    return _chip(text, chipColor);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // Thứ tự/nhãn field theo actionType đã dời sang
  // `AiPendingAction.displayFields` trong `models/ai_chatbot.dart` — dùng
  // chung cho cả nguồn `uiHints.fields` (Sprint 2) lẫn `preview` cũ.

  Widget _previewRow(
    BuildContext context,
    String key,
    String label,
    dynamic value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            resolveAiPreviewField(context, key, value, label: label),
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );

  IconData get _actionIcon => switch (action.actionType.toUpperCase()) {
    'CREATE_TASK' || 'TASK_CREATE' => Icons.task_alt_rounded,
    'CREATE_LEDGER_ENTRY' ||
    'CREATE_TRANSACTION' ||
    'FINANCE_LEDGER_CREATE' => Icons.account_balance_wallet_outlined,
    'CREATE_CALENDAR_EVENT' ||
    'CALENDAR_EVENT_CREATE' => Icons.event_available_outlined,
    'CREATE_BUDGET_PLAN' => Icons.pie_chart_outline_rounded,
    'CREATE_BUDGET_LINE' => Icons.playlist_add_rounded,
    'CREATE_FINANCIAL_GOAL' => Icons.flag_outlined,
    'CREATE_GOAL_ALLOCATION' ||
    'CREATE_GOAL_CONTRIBUTION_PLAN' => Icons.savings_outlined,
    'ALLOCATE_FUND_BY_MODEL' => Icons.account_tree_outlined,
    _ => Icons.fact_check_outlined,
  };

  Color get _actionColor => switch (action.actionType.toUpperCase()) {
    'CREATE_TASK' || 'TASK_CREATE' => AppColors.link,
    'CREATE_LEDGER_ENTRY' ||
    'CREATE_TRANSACTION' ||
    'FINANCE_LEDGER_CREATE' => AppColors.success,
    'CREATE_CALENDAR_EVENT' || 'CALENDAR_EVENT_CREATE' => AppColors.calTravel,
    'CREATE_BUDGET_PLAN' ||
    'CREATE_BUDGET_LINE' ||
    'CREATE_FINANCIAL_GOAL' ||
    'CREATE_GOAL_ALLOCATION' ||
    'CREATE_GOAL_CONTRIBUTION_PLAN' ||
    'ALLOCATE_FUND_BY_MODEL' => AppColors.accent500,
    _ => AppColors.primary600,
  };

  Future<void> _confirmAndReload(BuildContext context) async {
    final ai = context.read<AiChatbotProvider>();
    final tasks = context.read<TaskProvider>();
    final wallet = context.read<WalletProvider>();
    final calendar = context.read<CalendarProvider>();
    final finance = context.read<FinanceProvider>();
    final ok = stepIndex != null
        ? await ai.confirmStep(messageId, stepIndex!)
        : await ai.confirmAction(messageId);
    if (!ok) return;

    // BE tạo dữ liệu thật rồi, giờ phải kéo lại màn tương ứng. Nếu BE thêm một
    // actionType mới mà FE chưa biết thì KHÔNG được bỏ qua: người dùng bấm xác
    // nhận, BE tạo thật, mà app không đổi gì thì nhìn như chẳng có chuyện gì
    // xảy ra. Trường hợp đó refresh cả ba nguồn — tốn thêm vài request nhưng
    // không bao giờ hiện dữ liệu cũ.
    final type = action.actionType.toUpperCase();
    final refreshTasks =
        !action.isKnownActionType ||
        const {'CREATE_TASK', 'TASK_CREATE'}.contains(type);
    final refreshWallet =
        !action.isKnownActionType ||
        const {
          'CREATE_LEDGER_ENTRY',
          'CREATE_TRANSACTION',
          'FINANCE_LEDGER_CREATE',
        }.contains(type);
    final refreshCalendar =
        !action.isKnownActionType ||
        const {'CREATE_CALENDAR_EVENT', 'CALENDAR_EVENT_CREATE'}.contains(type);
    // BE xác nhận CREATE_BUDGET_PLAN là actionType chính thức 2026-08-09, yêu
    // cầu FE refresh Wallet/Budget/finance overview sau khi xác nhận —
    // `FinanceProvider.fetchAll()` kéo lại đúng nhóm này (models/jars/
    // categories/budgetPlans/goals/monthlyFinance) trong 1 lần gọi.
    final refreshFinance =
        !action.isKnownActionType ||
        AiPendingAction.financeActionTypes.contains(type);

    if (!action.isKnownActionType) {
      debugPrint(
        'AIAssistantScreen: actionType lạ "${action.actionType}" — '
        'refresh toàn bộ. Cần bổ sung vào AiPendingAction.knownActionTypes.',
      );
    }

    Future<void> guarded(String what, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        // Một nguồn lỗi không được chặn hai nguồn còn lại.
        debugPrint('AIAssistantScreen: refresh $what sau xác nhận lỗi: $e');
      }
    }

    if (refreshTasks) await guarded('tasks', tasks.fetchTasks);
    if (refreshWallet) await guarded('wallet', wallet.fetchWallets);
    if (refreshCalendar) {
      await guarded(
        'calendar',
        () => calendar.fetchEvents(calendarMonthToReload(action.preview)),
      );
    }
    if (refreshFinance) await guarded('finance', finance.fetchAll);
  }
}

/// Hàng "Tải thêm" dùng chung cho danh sách hội thoại và khung tin nhắn.
class _LoadMoreTile extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreTile({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.history_rounded, size: 16),
                label: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: AiChatbotIcon(size: 28),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang trả lời...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _QuickPrompts({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final canManageFinance =
        context.watch<AuthProvider>().user?.canManageFinance ?? false;
    // Cùng lý do với bảng gợi ý ở màn rỗng: Thành viên không có quyền ghi quỹ
    // chung nên không được mời làm việc đó.
    final prompts = canManageFinance
        ? [
            (
              label: 'Chi tiêu tháng này',
              prompt: 'Tháng này nhà mình tiêu hết bao nhiêu?',
            ),
            (
              label: 'Mô hình đang dùng',
              prompt: 'Nhà mình đang áp dụng mô hình tài chính nào?',
            ),
            (
              label: 'Hũ vượt mục tiêu',
              prompt: 'Hũ nào đang chi vượt mục tiêu?',
            ),
            (label: 'Tạo thu/chi', prompt: _randomLedgerPrompt()),
            (
              label: 'Tình hình nhiệm vụ',
              prompt: 'Tóm tắt nhiệm vụ của gia đình',
            ),
            (label: 'Lịch tuần này', prompt: 'Tuần này nhà mình có lịch gì?'),
          ]
        : const [
            (
              label: 'Nhiệm vụ của tôi',
              prompt: 'Tôi còn nhiệm vụ nào chưa hoàn thành?',
            ),
            (
              label: 'Chi tiêu của tôi',
              prompt: 'Tháng này tôi đã tiêu bao nhiêu?',
            ),
            (label: 'Lịch tuần này', prompt: 'Tuần này nhà mình có lịch gì?'),
          ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: prompts.map((q) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(q.label),
              onPressed: () => onPick(q.prompt),
              backgroundColor: context.colors.surface,
              side: BorderSide(color: context.colors.divider),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!sending) onSend();
                },
                decoration: InputDecoration(
                  hintText: 'Hỏi về chi tiêu, nhiệm vụ...',
                  filled: true,
                  fillColor: context.colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.link,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.20)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
