import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/money_input.dart';

// GET .../budget-plans/{id} (chi tiết + lines), PATCH plan, PATCH/DELETE
// budget-lines — các endpoint BE có sẵn nhưng trước đây FE chưa gọi.
class BudgetPlanDetailScreen extends StatefulWidget {
  final String planId;
  const BudgetPlanDetailScreen({super.key, required this.planId});

  @override
  State<BudgetPlanDetailScreen> createState() => _BudgetPlanDetailScreenState();
}

class _BudgetPlanDetailScreenState extends State<BudgetPlanDetailScreen> {
  bool _loading = true;
  String? _error;
  BudgetPlan? _plan;
  List<BudgetLine> _lines = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll(); // đảm bảo categories/jars sẵn cho form
      _load();
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final (plan, lines) = await context.read<FinanceProvider>().fetchBudgetPlanDetail(widget.planId);
      if (mounted) setState(() { _plan = plan; _lines = lines; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double? v) {
    if (v == null) return '—';
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
    final plan = _plan;
    return Scaffold(
      backgroundColor: context.colors.background,
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
                  child: Text(plan?.planName ?? 'Chi tiết kế hoạch',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
              if (plan != null && plan.status == 'DRAFT')
                GestureDetector(
                  onTap: () => _showEditPlanSheet(context, plan),
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
          else if (plan == null)
            const Expanded(child: SizedBox())
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _summaryCard(plan),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Các dòng ngân sách', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      if (plan.status == 'DRAFT')
                        TextButton.icon(
                          onPressed: () => _showAddLineSheet(context),
                          icon: const Icon(Icons.add, size: 16, color: AppColors.link),
                          label: Text('Thêm dòng', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link)),
                        ),
                    ]),
                    if (_lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('Chưa có dòng ngân sách nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                      )
                    else
                      ..._lines.map((l) => _lineCard(context, l, plan.status == 'DRAFT')),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _summaryCard(BudgetPlan plan) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(plan.planName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: plan.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(plan.statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: plan.statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Thu nhập dự kiến', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text(_fmt(plan.expectedSharedIncome), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.income)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chi tiêu dự kiến', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text(_fmt(plan.expectedSharedExpense), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
            ),
          ]),
        ]),
      );

  Widget _lineCard(BuildContext context, BudgetLine line, bool editable) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
      ]),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.categoryName ?? 'Danh mục', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (line.note != null && line.note!.isNotEmpty)
              Text(line.note!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('Kế hoạch: ${_fmt(line.plannedAmount)}${line.actualAmount != null ? ' · Thực tế: ${_fmt(line.actualAmount)}' : ''}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            if (line.thresholdAmount != null)
              Text(
                'Cảnh báo khi vượt: ${_fmt(line.thresholdAmount)}',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.danger),
              ),
          ]),
        ),
        if (editable) ...[
          GestureDetector(
            onTap: () => _showEditLineSheet(context, line),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 16, color: AppColors.link)),
          ),
          GestureDetector(
            onTap: () => _deleteLine(context, line),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger)),
          ),
        ],
      ]),
    );
  }

  Future<void> _deleteLine(BuildContext context, BudgetLine line) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().deleteBudgetLine(line.id);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
    }
  }

  void _showAddLineSheet(BuildContext context) {
    final categories = context
        .read<FinanceProvider>()
        .categories
        .where((category) =>
            category.categoryType == 'EXPENSE' && category.isActive)
        .toList();
    String? categoryId = categories.isNotEmpty ? categories.first.id : null;
    final amountCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController();
    var essentialType = 'NEUTRAL';
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
            Text('➕ Thêm dòng ngân sách', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              Text('Chưa có danh mục nào — tạo danh mục trước.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
            else ...[
              Text('Danh mục', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setSheet(() => categoryId = v),
              ),
              const SizedBox(height: 12),
              _inputBox(amountCtrl, 'Số tiền kế hoạch (₫)', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _inputBox(
                thresholdCtrl,
                'Ngưỡng cảnh báo (₫, tùy chọn)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Text('Loại chi tiêu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ('ESSENTIAL', 'Thiết yếu'),
                  ('NON_ESSENTIAL', 'Không thiết yếu'),
                  ('NEUTRAL', 'Trung lập'),
                ].map((item) => ChoiceChip(
                  label: Text(item.$2),
                  selected: essentialType == item.$1,
                  onSelected: (_) => setSheet(() => essentialType = item.$1),
                )).toList(),
              ),
            ],
            if (sheetError != null) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: submitting || categories.isEmpty ? null : () async {
                  final amt = parseMoneyInput(amountCtrl.text);
                  if (categoryId == null || amt <= 0) {
                    setSheet(() => sheetError = 'Chọn danh mục và nhập số tiền hợp lệ');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().addBudgetLine(
                      widget.planId,
                      categoryId: categoryId!,
                      plannedAmount: amt,
                      thresholdAmount: thresholdCtrl.text.trim().isEmpty
                          ? null
                          : parseMoneyInput(thresholdCtrl.text),
                      essentialType: essentialType,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Thêm dòng', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditLineSheet(BuildContext context, BudgetLine line) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        line.plannedAmount.round().toString(),
      ),
    );
    final thresholdCtrl = TextEditingController(
      text: line.thresholdAmount == null
          ? ''
          : ThousandsSeparatorInputFormatter.formatThousands(
              line.thresholdAmount!.round().toString(),
            ),
    );
    final noteCtrl = TextEditingController(text: line.note ?? '');
    var essentialType = line.essentialType ?? 'NEUTRAL';
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
            Text('✏️ Sửa dòng ngân sách', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _inputBox(amountCtrl, 'Số tiền kế hoạch (₫)', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _inputBox(
              thresholdCtrl,
              'Ngưỡng cảnh báo (₫, tùy chọn)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ('ESSENTIAL', 'Thiết yếu'),
                ('NON_ESSENTIAL', 'Không thiết yếu'),
                ('NEUTRAL', 'Trung lập'),
              ].map((item) => ChoiceChip(
                label: Text(item.$2),
                selected: essentialType == item.$1,
                onSelected: (_) => setSheet(() => essentialType = item.$1),
              )).toList(),
            ),
            const SizedBox(height: 12),
            _inputBox(noteCtrl, 'Ghi chú (tùy chọn)'),
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
                    await context.read<FinanceProvider>().updateBudgetLine(
                      line.id, plannedAmount: amt,
                      thresholdAmount: thresholdCtrl.text.trim().isEmpty
                          ? null
                          : parseMoneyInput(thresholdCtrl.text),
                      essentialType: essentialType,
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
                    : Text('Lưu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditPlanSheet(BuildContext context, BudgetPlan plan) {
    final nameCtrl = TextEditingController(text: plan.planName);
    final incomeCtrl = TextEditingController(
      text: plan.expectedSharedIncome == null
          ? ''
          : ThousandsSeparatorInputFormatter.formatThousands(
              plan.expectedSharedIncome!.round().toString(),
            ),
    );
    final expenseCtrl = TextEditingController(
      text: plan.expectedSharedExpense == null
          ? ''
          : ThousandsSeparatorInputFormatter.formatThousands(
              plan.expectedSharedExpense!.round().toString(),
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✏️ Sửa kế hoạch ngân sách', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text('Tên kế hoạch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(nameCtrl, 'Tên kế hoạch'),
              const SizedBox(height: 12),
              Text('Thu nhập dự kiến (₫)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(incomeCtrl, 'VD: 20000000', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Text('Chi tiêu dự kiến (₫)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(expenseCtrl, 'VD: 15000000', keyboardType: TextInputType.number),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: submitting ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setSheet(() => sheetError = 'Nhập tên kế hoạch');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<FinanceProvider>().updateBudgetPlan(
                      widget.planId,
                      planName: nameCtrl.text.trim(),
                      expectedSharedIncome: incomeCtrl.text.trim().isEmpty
                          ? null
                          : parseMoneyInput(incomeCtrl.text),
                      expectedSharedExpense: expenseCtrl.text.trim().isEmpty
                          ? null
                          : parseMoneyInput(expenseCtrl.text),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Lưu thay đổi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
