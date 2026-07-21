import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/calendar_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_chatbot_icon.dart';

const _assistantSurface = AppColors.primary50;
const _assistantBorder = AppColors.progressTrack;

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _msgs = <({bool isMe, String text})>[
    (
      isMe: false,
      text:
          'Xin chào! Tôi là trợ lý FamilyCare.\nBạn có thể hỏi nhanh về chi tiêu, nhiệm vụ, tiết kiệm hoặc lịch gia đình.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final finance = context.read<FinanceProvider>();
      if (finance.models.isEmpty &&
          finance.budgetPlans.isEmpty &&
          finance.goals.isEmpty &&
          finance.monthlyFinance == null) {
        finance.fetchAll();
      }

      final tasks = context.read<TaskProvider>();
      if (tasks.tasks.isEmpty && tasks.myAssignments.isEmpty) {
        tasks.fetchTasks();
        tasks.fetchMyAssignments();
      }

      final calendar = context.read<CalendarProvider>();
      if (calendar.events.isEmpty) {
        calendar.fetchBootstrap(DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_inputCtrl.text.trim().isEmpty) return;
    final q = _inputCtrl.text.trim();
    _inputCtrl.clear();
    setState(() {
      _msgs.add((isMe: true, text: q));
      _msgs.add((isMe: false, text: _autoReply(context, q)));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _autoReply(BuildContext context, String q) {
    final query = q.toLowerCase();
    if (_matches(query, [
      'chi',
      'tiêu',
      'tài chính',
      'tai chinh',
      'ví',
      'ví tiền',
    ])) {
      return _financeReply(context.read<FinanceProvider>());
    }
    if (_matches(query, ['task', 'việc', 'viec', 'nhiệm vụ', 'nhiem vu'])) {
      return _taskReply(context.read<TaskProvider>());
    }
    if (_matches(query, [
      'lịch',
      'lich',
      'tuần',
      'tuan',
      'sự kiện',
      'su kien',
    ])) {
      return _calendarReply(context.read<CalendarProvider>());
    }
    if (_matches(query, ['tiết kiệm', 'tiet kiem', 'save', 'mẹo', 'meo'])) {
      return _savingReply(context.read<FinanceProvider>());
    }
    // Câu fallback hướng người dùng tới thứ trợ lý làm được, KHÔNG lộ chi tiết
    // kỹ thuật nội bộ ("chưa có API backend") ra người dùng cuối.
    return 'Mình có thể giúp bạn xem nhanh về chi tiêu, nhiệm vụ, lịch và mục '
        'tiêu tiết kiệm của gia đình. Bạn muốn hỏi mục nào?';
  }

  bool _matches(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword));
  }

  String _money(num value) {
    // Tách dấu âm ra trước khi nhóm 3 chữ số. Nếu để nguyên chuỗi có '-',
    // dấu trừ bị tính là 1 "chữ số" → -100000 ra "-.100.000đ".
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return '${rounded < 0 ? '-' : ''}$bufferđ';
  }

  String _financeReply(FinanceProvider finance) {
    if (finance.loading) {
      return 'Tôi đang tải dữ liệu tài chính thật của gia đình. Bạn thử hỏi lại sau vài giây nhé.';
    }
    final monthly = finance.monthlyFinance;
    final income = monthly?.actualIncome ?? monthly?.expectedIncome;
    final personalExpense =
        monthly?.actualPersonalExpense ?? monthly?.expectedPersonalExpense;
    final sharedContribution =
        monthly?.actualSharedContribution ??
        monthly?.expectedSharedContribution;

    if (income == null &&
        personalExpense == null &&
        sharedContribution == null) {
      return 'Tháng này chưa có khai báo tài chính để tóm tắt. Tôi sẽ không hiển thị số mô phỏng để tránh nhầm với dữ liệu thật.';
    }

    final totalExpense = (personalExpense ?? 0) + (sharedContribution ?? 0);
    final balance = income == null ? null : income - totalExpense;
    return [
      'Tóm tắt tài chính tháng này từ dữ liệu đã khai báo:',
      if (income != null) '• Thu nhập: ${_money(income)}',
      if (personalExpense != null)
        '• Chi tiêu cá nhân: ${_money(personalExpense)}',
      if (sharedContribution != null)
        '• Đóng góp quỹ chung: ${_money(sharedContribution)}',
      if (balance != null) '• Còn lại ước tính: ${_money(balance)}',
    ].join('\n');
  }

  String _taskReply(TaskProvider tasks) {
    if (tasks.loading) {
      return 'Tôi đang tải dữ liệu nhiệm vụ thật. Bạn thử hỏi lại sau vài giây nhé.';
    }
    // Enum thật của TaskAssignment (task_provider.dart:214):
    // ASSIGNED | IN_PROGRESS | SUBMITTED | APPROVED | REJECTED | CANCELED |
    // UNAVAILABLE. KHÔNG có 'PENDING' hay 'COMPLETED'.
    final assignments = tasks.myAssignments;
    if (assignments.isNotEmpty) {
      // Loại việc đã hủy / báo bận khỏi mẫu số, nếu không tỉ lệ hoàn thành
      // sẽ bị pha loãng bởi việc user không còn trách nhiệm làm.
      final counted = assignments
          .where((a) => a.status != 'CANCELED' && a.status != 'UNAVAILABLE')
          .toList();
      if (counted.isEmpty) {
        return 'Bạn không có nhiệm vụ nào đang mở (tất cả đã hủy hoặc đã báo bận).';
      }
      final done = counted.where((a) => a.status == 'APPROVED').length;
      final pendingReview = counted
          .where((a) => a.status == 'SUBMITTED')
          .length;
      final active = counted
          .where((a) => a.status == 'ASSIGNED' || a.status == 'IN_PROGRESS')
          .length;
      final rejected = counted.where((a) => a.status == 'REJECTED').length;
      return [
        'Tình hình nhiệm vụ của bạn:',
        '• Hoàn thành: $done/${counted.length}',
        '• Đang/chờ làm: $active',
        if (pendingReview > 0) '• Chờ duyệt: $pendingReview',
        if (rejected > 0) '• Bị từ chối, cần làm lại: $rejected',
      ].join('\n');
    }

    if (tasks.tasks.isEmpty) {
      return 'Chưa có dữ liệu nhiệm vụ được tải về, nên tôi chưa thể tóm tắt chính xác.';
    }
    // Enum thật của FamilyTask: ACTIVE | COMPLETED | CANCELED.
    final done = tasks.tasks.where((t) => t.status == 'COMPLETED').length;
    final active = tasks.tasks.where((t) => t.status == 'ACTIVE').length;
    return [
      'Tình hình nhiệm vụ gia đình:',
      '• Hoàn thành: $done/${tasks.tasks.length}',
      '• Đang hoạt động: $active',
    ].join('\n');
  }

  String _calendarReply(CalendarProvider calendar) {
    if (calendar.loading) {
      return 'Tôi đang tải lịch gia đình thật. Bạn thử hỏi lại sau vài giây nhé.';
    }
    if (calendar.events.isEmpty) {
      return 'Tuần này chưa có sự kiện lịch nào được tải về.';
    }
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final upcoming = calendar.events
        .where((e) => e.startTime.isAfter(now) && e.startTime.isBefore(weekEnd))
        .toList();
    if (upcoming.isEmpty) {
      return 'Trong 7 ngày tới chưa có sự kiện gia đình nào.';
    }
    final lines = upcoming.take(3).map((e) => '• ${e.title} - ${e.timeLabel}');
    return [
      'Trong 7 ngày tới có ${upcoming.length} sự kiện:',
      ...lines,
    ].join('\n');
  }

  String _savingReply(FinanceProvider finance) {
    final activeGoals = finance.activeGoals;
    if (activeGoals.isEmpty) {
      return 'Chưa có mục tiêu tiết kiệm đang hoạt động. Bạn có thể tạo mục tiêu tài chính trước, rồi tôi sẽ tóm tắt tiến độ dựa trên dữ liệu thật.';
    }
    final lines = activeGoals.take(3).map((g) {
      final progress = g.progressPercent == null
          ? 'chưa có tiến độ'
          : '${g.progressPercent!.toStringAsFixed(0)}%';
      return '• ${g.goalName}: ${_money(g.targetAmount)} ($progress)';
    });
    return ['Các mục tiêu tiết kiệm đang theo dõi:', ...lines].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: _assistantBorder),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                final bubble = Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: m.isMe ? AppColors.link : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(m.isMe ? 18 : 4),
                      bottomRight: Radius.circular(m.isMe ? 4 : 18),
                    ),
                    boxShadow: m.isMe
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    m.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: m.isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                );
                if (m.isMe) {
                  return Align(alignment: Alignment.centerRight, child: bubble);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: AiChatbotIcon(size: 28),
                    ),
                    Flexible(child: bubble),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children:
                  const [
                    (label: 'Chi tiêu tháng này', prompt: 'Chi tiêu tháng này'),
                    (label: 'Tình hình nhiệm vụ', prompt: 'Tình hình tasks'),
                    (label: 'Mục tiêu tiết kiệm', prompt: 'Mẹo tiết kiệm'),
                    (label: 'Lịch tuần này', prompt: 'Lịch tuần này'),
                  ].map((q) {
                    return GestureDetector(
                      onTap: () {
                        _inputCtrl.text = q.prompt;
                        _send();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          q.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: _assistantBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _assistantSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: 'Hỏi về chi tiêu, tasks...',
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.link,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
