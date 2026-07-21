import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_input.dart';

// UC — Kế hoạch đóng góp mục tiêu theo tháng (Financial Goals — lớp
// contribution sâu). Workflow 3 bước: Manager/Deputy "Xác nhận kế hoạch"
// (confirm) → Member "Tôi đã đóng góp" (submit) → Manager/Deputy
// "Duyệt/Từ chối" (approve/reject). Xem finance_provider.dart mục Goal
// Contribution Plans — status enum là suy luận, chưa verify BE thật.
class GoalContributionScreen extends StatefulWidget {
  final String goalId;
  const GoalContributionScreen({super.key, required this.goalId});

  @override
  State<GoalContributionScreen> createState() => _GoalContributionScreenState();
}

class _GoalContributionScreenState extends State<GoalContributionScreen> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  bool _loading = true;
  String? _error;
  List<ContributionSuggestion> _suggestions = [];
  List<GoalContributionPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FamilyProvider>().fetchMembers();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final provider = context.read<FinanceProvider>();
    try {
      final results = await Future.wait([
        provider.fetchContributionSuggestions(widget.goalId, _month, _year),
        provider.fetchContributionPlans(widget.goalId, _month, _year),
      ]);
      if (mounted) {
        setState(() {
          _suggestions = results[0] as List<ContributionSuggestion>;
          _plans = results[1] as List<GoalContributionPlan>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      if (m < 1) { m = 12; y -= 1; }
      if (m > 12) { m = 1; y += 1; }
      _month = m; _year = y;
    });
    _load();
  }

  String _fmt(double v) {
    return '${ThousandsSeparatorInputFormatter.formatThousands(v.round().toString())} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final goal = context.watch<FinanceProvider>().goals
        .where((g) => g.id == widget.goalId).firstOrNull;
    final user = context.watch<AuthProvider>().user;
    final currentMemberId = context.watch<FamilyProvider>().members
        .where((member) => member.userId == user?.id)
        .firstOrNull
        ?.id;
    final canManage = user?.canManageFinance ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(goal?.goalName ?? 'Đóng góp mục tiêu',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 40),
            ]),
          ),

          // Month selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Text('Tháng $_month/$_year', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
          ),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_error != null)
                      _card(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),

                    // ── Gợi ý đóng góp ──
                    if (_suggestions.isNotEmpty) ...[
                      _sectionLabel('Gợi ý đóng góp / tháng'),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _suggestions.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text(s.memberName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
                              Text(_fmt(s.suggestedAmount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.link)),
                            ]),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Kế hoạch đóng góp ──
                    _sectionLabel('Kế hoạch đóng góp tháng này'),
                    if (_plans.isEmpty)
                      _card(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Chưa có kế hoạch đóng góp cho tháng này',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          if (canManage) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => _showConfirmPlanSheet(context),
                                child: Text('Xác nhận kế hoạch tháng này', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ],
                        ]),
                      )
                    else
                      ..._plans.map(
                        (p) => _planCard(
                          context,
                          p,
                          user?.id,
                          currentMemberId,
                          canManage,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Thiếu hụt ──
                    _sectionLabel('Thiếu hụt tháng này'),
                    _shortageCard(),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ]),
        child: child,
      );

  Widget _shortageCard() {
    if (_plans.isEmpty) {
      return _card(
        child: Text(
          'Chưa có kế hoạch để tính thiếu hụt tháng này.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    final planned = _plans.fold<double>(
      0,
      (total, plan) => total + plan.plannedAmount,
    );
    final actual = _plans.fold<double>(
      0,
      (total, plan) => total + (plan.actualAmount ?? 0),
    );
    final shortage = (planned - actual).clamp(0, double.infinity).toDouble();

    Widget row(String label, double amount, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            Text(
              _fmt(amount),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ]),
        );

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          shortage > 0
              ? 'Cần bổ sung để đủ kế hoạch tháng $_month/$_year'
              : 'Đã đủ kế hoạch đóng góp tháng này',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        row('Kế hoạch', planned, AppColors.textPrimary),
        row('Đã được ghi nhận', actual, AppColors.income),
        row('Còn thiếu', shortage, shortage > 0 ? AppColors.danger : AppColors.success),
      ]),
    );
  }

  Widget _planCard(
    BuildContext context,
    GoalContributionPlan plan,
    String? currentUserId,
    String? currentMemberId,
    bool canManage,
  ) {
    // Contribution-plan APIs identify a family member by membership record ID,
    // while some older BE responses expose userId. Accept either shape so the
    // correct member can submit their own plan.
    final isMine = plan.memberId == currentMemberId ||
        plan.memberId == currentUserId;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(plan.memberName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: plan.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(plan.statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: plan.statusColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kế hoạch', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(_fmt(plan.plannedAmount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Đã đóng', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(plan.actualAmount != null ? _fmt(plan.actualAmount!) : '—',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.income)),
            ]),
          ),
        ]),
        if (isMine && (plan.isPending || plan.isRejected)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
              onPressed: () => _showSubmitSheet(context, plan),
              child: Text('Tôi đã đóng góp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
        if (canManage && plan.isSubmitted) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
                  onPressed: () => _review(plan, 'approve'),
                  child: Text('Duyệt', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                  onPressed: () => _review(plan, 'reject'),
                  child: Text('Từ chối', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _review(GoalContributionPlan plan, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().reviewContributionPlan(widget.goalId, plan.id, action);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  void _showSubmitSheet(BuildContext context, GoalContributionPlan plan) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        plan.plannedAmount.round().toString(),
      ),
    );
    final noteCtrl = TextEditingController();
    bool submitting = false;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💰 Xác nhận đã đóng góp', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _inputBox(amountCtrl, 'Số tiền (₫)', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _inputBox(noteCtrl, 'Ghi chú (tùy chọn)'),
            if (sheetError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: submitting ? null : () async {
                  final amt = parseMoneyInput(amountCtrl.text);
                  if (amt <= 0) {
                    setSheet(() => sheetError = 'Nhập số tiền hợp lệ');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().submitContributionPlan(
                      widget.goalId, plan.id, amt,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Xác nhận', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showConfirmPlanSheet(BuildContext context) {
    final members = context.read<FamilyProvider>().members.where((m) => m.isActive).toList();
    // `members[].memberId` in ConfirmGoalContributionPlanDto is the
    // FamilyMember membership record ID, not the nested User ID. Sending
    // userId makes BE fail with "Không tìm thấy thành viên đang hoạt động".
    final amountCtrls = {for (final m in members) m.id: TextEditingController()};
    // Prefill từ gợi ý nếu có
    for (final s in _suggestions) {
      final member = members.where(
        (m) => m.id == s.memberId || m.userId == s.memberId,
      ).firstOrNull;
      if (member != null && s.suggestedAmount > 0) {
        amountCtrls[member.id]!.text =
            ThousandsSeparatorInputFormatter.formatThousands(
          s.suggestedAmount.round().toString(),
        );
      }
    }
    DateTime dueDate = DateTime(_year, _month + 1, 0); // cuối tháng
    bool submitting = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📋 Xác nhận kế hoạch tháng $_month/$_year', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              if (members.isEmpty)
                Text('Không có thành viên nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
              else
                ...members.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _inputBox(amountCtrls[m.id]!, 'Số tiền kế hoạch (₫)', keyboardType: TextInputType.number),
                  ]),
                )),
              Text('Hạn đóng góp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: dueDate,
                    firstDate: DateTime(_year, _month, 1),
                    lastDate: DateTime(_year, _month + 2, 0),
                  );
                  if (picked != null) setSheet(() => dueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                  ]),
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                  child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: submitting || members.isEmpty ? null : () async {
                    final entries = <({String memberId, double plannedAmount})>[];
                    for (final m in members) {
                      final amt = parseMoneyInput(amountCtrls[m.id]!.text);
                      if (amt > 0) {
                        entries.add((memberId: m.id, plannedAmount: amt));
                      }
                    }
                    if (entries.isEmpty) {
                      setSheet(() => sheetError = 'Nhập ít nhất 1 số tiền kế hoạch');
                      return;
                    }
                    setSheet(() { submitting = true; sheetError = null; });
                    try {
                      await context.read<FinanceProvider>().confirmContributionPlan(
                        widget.goalId,
                        periodMonth: _month, periodYear: _year,
                        dueDate: dueDate, members: entries,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    } catch (e) {
                      setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                    }
                  },
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Xác nhận kế hoạch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _inputBox(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number
              ? const [ThousandsSeparatorInputFormatter()]
              : null,
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      );
}
