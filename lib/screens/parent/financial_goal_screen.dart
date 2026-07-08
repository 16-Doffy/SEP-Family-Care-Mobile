import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';

class FinancialGoalScreen extends StatefulWidget {
  const FinancialGoalScreen({super.key});
  @override
  State<FinancialGoalScreen> createState() => _FinancialGoalScreenState();
}

class _FinancialGoalScreenState extends State<FinancialGoalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll();
    });
  }

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final goals = provider.goals;

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
              const Expanded(child: Center(child: Text('Mục tiêu tiết kiệm', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              GestureDetector(
                onTap: () => _showCreateSheet(context),
                child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), child: const Icon(Icons.add, color: Colors.white)),
              ),
            ]),
          ),

          if (provider.loading && goals.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error != null && goals.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Lỗi tải dữ liệu', style: GoogleFonts.inter(fontSize: 14, color: AppColors.danger)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => provider.fetchAll(), child: const Text('Thử lại')),
                ]),
              ),
            )
          else if (goals.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎯', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('Chưa có mục tiêu tiết kiệm', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                ]),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchAll(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: goals.length,
                  itemBuilder: (_, i) => _goalCard(context, goals[i]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _goalCard(BuildContext context, FinancialGoal goal) {
    final pct = ((goal.progressPercent ?? 0) / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => context.push('/manager/goal-detail?goalId=${goal.id}'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ]),
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
          Text('Hạn: ${goal.deadline}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(goal.statusColor),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).round()}% · Mục tiêu ${_fmt(goal.targetAmount)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        if (goal.status == 'ACTIVE') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, padding: EdgeInsets.zero),
                  onPressed: () => _showContributeSheet(context, goal),
                  child: Text('💰 Góp tiền', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                  onPressed: () => context.read<FinanceProvider>().cancelGoal(goal.id),
                  child: Text('Hủy', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, side: const BorderSide(color: Color(0xFFE5E7EB))),
              onPressed: () => context.push('/manager/goal-contribution?goalId=${goal.id}'),
              icon: const Icon(Icons.checklist_rtl_rounded, size: 15, color: AppColors.link),
              label: Text('Kế hoạch đóng góp theo tháng', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.link)),
            ),
          ),
        ],
      ]),
      ),
    );
  }

  void _showContributeSheet(BuildContext context, FinancialGoal goal) {
    final amountCtrl = TextEditingController();
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
            Text('💰 Góp tiền cho mục tiêu', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(goal.goalName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _inputBox(amountCtrl, 'Số tiền (₫)', keyboardType: TextInputType.number),
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
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (amt == null || amt <= 0) {
                    setSheet(() => sheetError = 'Nhập số tiền hợp lệ');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().contributeToGoal(goal.id, amt);
                    if (ctx.mounted) Navigator.pop(ctx);
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

  void _showCreateSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();
    DateTime? deadline;
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
              Text('🎯 Tạo mục tiêu tiết kiệm', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text('Tên mục tiêu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(nameCtrl, 'VD: Du lịch Đà Lạt, Mua xe...'),
              const SizedBox(height: 12),
              Text('Số tiền mục tiêu (₫)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(targetCtrl, 'VD: 10000000', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Text('Góp hàng tháng dự kiến (₫, tùy chọn)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(monthlyCtrl, 'VD: 1000000', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Text('Hạn hoàn thành (tùy chọn)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setSheet(() => deadline = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Text(
                      deadline != null ? '${deadline!.day}/${deadline!.month}/${deadline!.year}' : 'Chọn ngày',
                      style: GoogleFonts.inter(fontSize: 14, color: deadline != null ? AppColors.textPrimary : AppColors.textMuted),
                    ),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: submitting ? null : () async {
                  final target = double.tryParse(targetCtrl.text.trim());
                  if (nameCtrl.text.trim().isEmpty || target == null || target <= 0) {
                    setSheet(() => sheetError = 'Nhập tên và số tiền mục tiêu hợp lệ');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().createGoal(
                      goalName: nameCtrl.text.trim(),
                      targetAmount: target,
                      deadline: deadline,
                      monthlyContributionTarget: double.tryParse(monthlyCtrl.text.trim()),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Tạo mục tiêu', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      );
}
