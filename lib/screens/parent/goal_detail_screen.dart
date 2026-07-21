import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_input.dart';

// GET .../financial-goals/{id}, PATCH, GET .../progress, GET/PATCH/DELETE
// .../allocations — các endpoint BE có sẵn nhưng trước đây FE chưa gọi.
class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  bool _loading = true;
  String? _error;
  FinancialGoal? _goal;
  Map<String, dynamic>? _progress;
  List<GoalAllocation> _allocations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final provider = context.read<FinanceProvider>();
    try {
      final results = await Future.wait([
        provider.fetchGoalDetail(widget.goalId),
        provider.fetchGoalProgress(widget.goalId),
        provider.fetchGoalAllocations(widget.goalId),
      ]);
      if (mounted) {
        setState(() {
          _goal = results[0] as FinancialGoal;
          _progress = results[1] as Map<String, dynamic>;
          _allocations = results[2] as List<GoalAllocation>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
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
                  child: Text(goal?.goalName ?? 'Chi tiết mục tiêu',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
              if (goal != null)
                GestureDetector(
                  onTap: () => _showEditGoalSheet(context, goal),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                    child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.link),
                  ),
                )
              else
                const SizedBox(width: 40),
            ]),
          ),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                ]),
              ),
            )
          else if (goal == null)
            const Expanded(child: SizedBox())
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _summaryCard(goal, _progress),
                    const SizedBox(height: 16),
                    _sectionLabel('Tiến độ chi tiết'),
                    _progressCard(goal, _progress),
                    const SizedBox(height: 16),
                    _sectionLabel('Lịch sử đóng góp'),
                    if (_allocations.isEmpty)
                      _card(child: Text('Chưa có lần góp nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)))
                    else
                      ..._allocations.map((a) => _allocationCard(context, a)),
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

  Widget _summaryCard(FinancialGoal goal, Map<String, dynamic>? rawProgress) {
    final pct = ((goal.progressPercent ?? 0) / 100).clamp(0.0, 1.0);
    final nestedProgress = _asMap(rawProgress?['progress']);
    final currentAmount = goal.currentAmount ??
        _number(nestedProgress['currentAmount']);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(goal.goalName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: goal.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(goal.statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: goal.statusColor)),
          ),
        ]),
        if (goal.deadline != null) ...[
          const SizedBox(height: 4),
          Text('Hạn: ${_formatDate(goal.deadline!)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: const Color(0xFFE5E7EB), valueColor: AlwaysStoppedAnimation<Color>(goal.statusColor)),
        ),
        const SizedBox(height: 6),
        Text(
          'Đã góp ${_fmt(currentAmount)} / ${_fmt(goal.targetAmount)} · ${(pct * 100).round()}%',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
        if (goal.canContribute) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.link,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showContributeSheet(context, goal),
              icon: const Icon(Icons.savings_rounded, size: 18),
              label: Text(
                'Góp tiền vào mục tiêu',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Widget _progressCard(FinancialGoal goal, Map<String, dynamic>? raw) {
    final root = raw ?? const <String, dynamic>{};
    final progress = _asMap(root['progress']);
    final values = progress.isEmpty ? root : progress;
    final current = _number(values['currentAmount']);
    final remaining = _number(values['remainingAmount']);
    final percent = _number(values['progressPercent']);
    final days = values['daysRemaining'];
    final months = values['monthsRemaining'];
    final recommended = _number(values['recommendedMonthlyContribution']);

    Widget row(String label, String value, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  )),
            ),
            Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                )),
          ]),
        );

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row('Đã góp', _fmt(current), valueColor: AppColors.income),
        row('Mục tiêu', _fmt(goal.targetAmount)),
        row('Còn thiếu', _fmt(remaining)),
        row('Tiến độ', '${percent.round()}%'),
        if (goal.deadline != null) row('Hạn hoàn thành', _formatDate(goal.deadline!)),
        if (days != null) row('Số ngày còn lại', '$days ngày'),
        if (months != null) row('Số tháng còn lại', '$months tháng'),
        if (!goal.isAchieved && recommended > 0)
          row('Nên góp mỗi tháng', _fmt(recommended), valueColor: AppColors.link),
        const Divider(height: 20),
        row(
          'Tình trạng',
          goal.statusLabel,
          valueColor: goal.statusColor,
        ),
      ]),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showContributeSheet(BuildContext context, FinancialGoal goal) {
    final amountCtrl = TextEditingController();
    bool submitting = false;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💰 Góp tiền cho mục tiêu',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                goal.goalName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _inputBox(
                amountCtrl,
                'Số tiền góp (₫)',
                keyboardType: TextInputType.number,
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(
                  sheetError!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = parseMoneyInput(amountCtrl.text);
                          if (amount <= 0) {
                            setSheet(() => sheetError =
                                'Nhập số tiền góp lớn hơn 0.');
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context
                                .read<FinanceProvider>()
                                .contributeToGoal(goal.id, amount);
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            setSheet(() {
                              submitting = false;
                              sheetError = e
                                  .toString()
                                  .replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Xác nhận góp tiền',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allocationCard(BuildContext context, GoalAllocation a) {
    return _card(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmt(a.amount), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.income)),
            if (a.note != null && a.note!.isNotEmpty)
              Text(a.note!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            if (a.createdAt != null)
              Text(a.createdAt!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        GestureDetector(
          onTap: () => _showEditAllocationSheet(context, a),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 16, color: AppColors.link)),
        ),
        GestureDetector(
          onTap: () => _deleteAllocation(context, a),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger)),
        ),
      ]),
    );
  }

  Future<void> _deleteAllocation(BuildContext context, GoalAllocation a) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().deleteGoalAllocation(a.id);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
    }
  }

  void _showEditAllocationSheet(BuildContext context, GoalAllocation a) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        a.amount.round().toString(),
      ),
    );
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
            Text('✏️ Sửa số tiền đã góp', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _inputBox(amountCtrl, 'Số tiền (₫)', keyboardType: TextInputType.number),
            if (sheetError != null) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
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
                    await context.read<FinanceProvider>().updateGoalAllocation(a.id, amt);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Lưu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditGoalSheet(BuildContext context, FinancialGoal goal) {
    final nameCtrl = TextEditingController(text: goal.goalName);
    final targetCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        goal.targetAmount.round().toString(),
      ),
    );
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
            Text('✏️ Sửa mục tiêu', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _inputBox(nameCtrl, 'Tên mục tiêu'),
            const SizedBox(height: 12),
            _inputBox(targetCtrl, 'Số tiền mục tiêu (₫)', keyboardType: TextInputType.number),
            if (sheetError != null) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: submitting ? null : () async {
                  final target = parseMoneyInput(targetCtrl.text);
                  if (nameCtrl.text.trim().isEmpty || target <= 0) {
                    setSheet(() => sheetError = 'Nhập tên và số tiền hợp lệ');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().updateGoal(
                      widget.goalId,
                      goalName: nameCtrl.text.trim(),
                      targetAmount: target,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Lưu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
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
