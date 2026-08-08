import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ai_chatbot.dart';
import '../../providers/ai_chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
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
  return value.toString();
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiChatbotProvider>().bootstrap();
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatbotProvider>(
      builder: (context, ai, _) {
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
                                  onTap: () {
                                    ai.selectConversation(c.id);
                                    Navigator.of(sheetContext).pop();
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
    if (ai.loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget body;
    final messages = ai.messages;
    if (messages.isEmpty) {
      body = _EmptyStateSuggestions(onPick: onPickPrompt);
    } else {
      // Hàng "Tải thêm" nằm trên cùng vì tin cũ hơn thuộc về phía trên.
      final leading = ai.hasMoreMessages ? 1 : 0;
      body = ListView.builder(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: leading + messages.length + (ai.sending ? 1 : 0),
        itemBuilder: (_, i) {
          if (leading == 1 && i == 0) {
            return _LoadMoreTile(
              label: 'Tải thêm tin nhắn',
              loading: ai.loadingMoreMessages,
              onTap: ai.loadMoreMessages,
            );
          }
          final index = i - leading;
          if (index >= messages.length) return const _TypingBubble();
          return _MessageBubble(
            message: messages[index],
            onPickPrompt: onPickPrompt,
          );
        },
      );
    }

    if (brief == null) return body;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _DailyBriefCard(brief: brief, onPick: onPickPrompt),
        ),
        Expanded(child: body),
      ],
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
        'Ghi khoản chi 200.000đ tiền ăn uống hôm nay',
        'Ghi khoản thu 5.000.000đ lương tháng này',
        'Tạo nhiệm vụ rửa bát tối nay',
        'Tạo lịch khám sức khỏe 9h sáng mai',
      ],
    ),
  ];
}

class _EmptyStateSuggestions extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _EmptyStateSuggestions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final canManageFinance =
        context.watch<AuthProvider>().user?.canManageFinance ?? false;
    final groups = aiPromptGroupsFor(canManageFinance: canManageFinance);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      children: [
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
  if (key.contains('finance') || key.contains('money') || key.contains('wallet')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (key.contains('task') || key.contains('chore')) return Icons.task_alt_rounded;
  if (key.contains('calendar') || key.contains('event')) {
    return Icons.event_available_outlined;
  }
  if (key.contains('sos') || key.contains('safety') || key.contains('warning')) {
    return Icons.shield_outlined;
  }
  if (key.contains('saving') || key.contains('goal')) return Icons.savings_outlined;
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
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.35,
          color: isMe ? Colors.white : context.colors.textPrimary,
        ),
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
          Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textPrimary,
            ),
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
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.4,
                color: context.colors.textSecondary,
              ),
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
    final title = message.uiHints?.title?.trim();
    final fields = message.pendingAction?.displayFields ?? const [];
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              if (title != null && title.isNotEmpty)
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: context.colors.textPrimary,
            ),
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final f in fields) _detailRow(f.label, f.key, f.value),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String key, dynamic value) => Padding(
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
            formatAiPreviewValue(key, value),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
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
          messageId: action.messageId.isNotEmpty ? action.messageId : message.id,
          action: action,
        ),
      ],
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final String messageId;
  final AiPendingAction action;

  const _PendingActionCard({required this.messageId, required this.action});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiChatbotProvider>();
    final busy = ai.isActionBusy(messageId);
    final enabled = action.isPending && !busy;
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
                    if (action.uiHints?.description?.trim().isNotEmpty ??
                        false)
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
              _previewRow(f.key, f.label, f.value),
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
                        ? () => context.read<AiChatbotProvider>().rejectAction(
                            messageId,
                          )
                        : null,
                    child: Text(action.uiHints?.secondaryActionLabel ?? 'Hủy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: enabled
                        ? () => _confirmAndReload(context)
                        : null,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(action.uiHints?.primaryActionLabel ?? 'Xác nhận'),
                  ),
                ),
              ],
            ),
            // BE chưa cho endpoint/cơ chế riêng cho "sửa" đề xuất — chỉ có
            // nhãn nút. Tạm xử lý bằng 2 khả năng đã có sẵn: từ chối đề xuất
            // hiện tại rồi điền sẵn ô nhập một câu sửa để người dùng chỉnh và
            // gửi lại cho AI. Đây là suy luận tạm, cần hỏi lại BE nếu sai.
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
    await ai.rejectAction(messageId);
  }

  /// Câu trạng thái dưới thẻ. Xác nhận thành công phải nói rõ là **đã xong**,
  /// không được dùng chung một câu cảnh báo với đề xuất hết hạn.
  String get _outcomeMessage => switch (action.outcome) {
    AiActionOutcome.completed => 'Đã thực hiện xong.',
    AiActionOutcome.rejected => 'Bạn đã từ chối đề xuất này.',
    AiActionOutcome.expired =>
      'Đề xuất đã hết hạn. Hãy nhắn lại để AI tạo đề xuất mới.',
    AiActionOutcome.failed => 'Thực hiện đề xuất không thành công.',
    AiActionOutcome.pending => '',
  };

  Color get _outcomeColor => switch (action.outcome) {
    AiActionOutcome.completed => AppColors.success,
    AiActionOutcome.rejected => AppColors.textMuted,
    AiActionOutcome.expired || AiActionOutcome.failed => AppColors.danger,
    AiActionOutcome.pending => AppColors.textSecondary,
  };

  IconData get _outcomeIcon => switch (action.outcome) {
    AiActionOutcome.completed => Icons.check_circle_rounded,
    AiActionOutcome.rejected => Icons.do_not_disturb_on_outlined,
    AiActionOutcome.expired => Icons.timer_off_outlined,
    AiActionOutcome.failed => Icons.error_outline_rounded,
    AiActionOutcome.pending => Icons.schedule_rounded,
  };

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

  Widget _previewRow(String key, String label, dynamic value) => Padding(
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
            formatAiPreviewValue(key, value),
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
    _ => Icons.fact_check_outlined,
  };

  Color get _actionColor => switch (action.actionType.toUpperCase()) {
    'CREATE_TASK' || 'TASK_CREATE' => AppColors.link,
    'CREATE_LEDGER_ENTRY' ||
    'CREATE_TRANSACTION' ||
    'FINANCE_LEDGER_CREATE' => AppColors.success,
    'CREATE_CALENDAR_EVENT' || 'CALENDAR_EVENT_CREATE' => AppColors.calTravel,
    _ => AppColors.primary600,
  };

  Future<void> _confirmAndReload(BuildContext context) async {
    final ai = context.read<AiChatbotProvider>();
    final tasks = context.read<TaskProvider>();
    final wallet = context.read<WalletProvider>();
    final calendar = context.read<CalendarProvider>();
    final ok = await ai.confirmAction(messageId);
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
        ? const [
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
            (
              label: 'Tạo thu/chi',
              prompt: 'Ghi nhận khoản chi 200000 cho ăn uống hôm nay',
            ),
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
