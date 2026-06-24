import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';

/// UC22 Khai báo thu nhập cá nhân
/// UC27 Khai báo chi tiêu cá nhân hàng tháng
///
/// Form 4 ô input (Expected/Actual Income, Expected/Actual Expense)
/// + 2 switch chọn visibility riêng cho income / expense.
/// Gọi upsertMonthlyFinance() → PUT nếu đã có, POST nếu chưa.
class MonthlyFinanceScreen extends StatefulWidget {
  const MonthlyFinanceScreen({super.key});

  @override
  State<MonthlyFinanceScreen> createState() => _MonthlyFinanceScreenState();
}

class _MonthlyFinanceScreenState extends State<MonthlyFinanceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _expectedIncomeCtrl    = TextEditingController();
  final _actualIncomeCtrl      = TextEditingController();
  final _expectedExpenseCtrl   = TextEditingController();
  final _actualExpenseCtrl     = TextEditingController();

  String _incomeVisibility  = 'FAMILY';
  String _expenseVisibility = 'PRIVATE';

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final mf = context.read<FinanceProvider>().monthlyFinance;
    if (mf != null) {
      if (mf.expectedIncome != null)          _expectedIncomeCtrl.text  = mf.expectedIncome!.round().toString();
      if (mf.actualIncome != null)            _actualIncomeCtrl.text    = mf.actualIncome!.round().toString();
      if (mf.expectedPersonalExpense != null) _expectedExpenseCtrl.text = mf.expectedPersonalExpense!.round().toString();
      if (mf.actualPersonalExpense != null)   _actualExpenseCtrl.text   = mf.actualPersonalExpense!.round().toString();
    }
  }

  @override
  void dispose() {
    _expectedIncomeCtrl.dispose();
    _actualIncomeCtrl.dispose();
    _expectedExpenseCtrl.dispose();
    _actualExpenseCtrl.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final s = text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', ''));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<FinanceProvider>().upsertMonthlyFinance(
        expectedIncome:          _parse(_expectedIncomeCtrl.text),
        actualIncome:            _parse(_actualIncomeCtrl.text),
        expectedPersonalExpense: _parse(_expectedExpenseCtrl.text),
        actualPersonalExpense:   _parse(_actualExpenseCtrl.text),
        incomeVisibility:        _incomeVisibility,
        expenseVisibility:       _expenseVisibility,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu khai báo tài chính tháng này'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        ),
        title: Text(
          'Khai báo thu/chi tháng ${now.month}/${now.year}',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _save,
                    child: Text('Lưu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary500)),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.sos.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.sos)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Thu nhập ──────────────────────────────────────────────────────
            _sectionHeader('💰 Thu nhập', Icons.trending_up_rounded, AppColors.safe),
            const SizedBox(height: 12),
            _moneyField(
              controller: _expectedIncomeCtrl,
              label: 'Dự kiến nhận được (₫)',
              hint: 'Ví dụ: 5000000',
            ),
            const SizedBox(height: 12),
            _moneyField(
              controller: _actualIncomeCtrl,
              label: 'Thực tế đã nhận (₫)',
              hint: 'Ví dụ: 4800000',
            ),
            const SizedBox(height: 12),
            _visibilitySwitch(
              label: 'Chia sẻ thu nhập với gia đình',
              sublabel: 'Tắt = chỉ mình bạn thấy',
              value: _incomeVisibility == 'FAMILY',
              onChanged: (v) => setState(() => _incomeVisibility = v ? 'FAMILY' : 'PRIVATE'),
            ),

            const SizedBox(height: 28),

            // ── Chi tiêu ──────────────────────────────────────────────────────
            _sectionHeader('💸 Chi tiêu cá nhân', Icons.trending_down_rounded, AppColors.sos),
            const SizedBox(height: 12),
            _moneyField(
              controller: _expectedExpenseCtrl,
              label: 'Hạn mức dự kiến (₫)',
              hint: 'Ví dụ: 3000000',
            ),
            const SizedBox(height: 12),
            _moneyField(
              controller: _actualExpenseCtrl,
              label: 'Đã chi thực tế (₫)',
              hint: 'Ví dụ: 1500000',
            ),
            const SizedBox(height: 12),
            _visibilitySwitch(
              label: 'Chia sẻ chi tiêu với gia đình',
              sublabel: 'Tắt = chỉ mình bạn thấy (mặc định)',
              value: _expenseVisibility == 'FAMILY',
              onChanged: (v) => setState(() => _expenseVisibility = v ? 'FAMILY' : 'PRIVATE'),
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Lưu khai báo tháng ${now.month}/${now.year}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          suffixText: '₫',
          suffixStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
        validator: (v) {
          if (v != null && v.isNotEmpty) {
            final n = double.tryParse(v.replaceAll(',', ''));
            if (n == null || n < 0) return 'Vui lòng nhập số hợp lệ';
          }
          return null;
        },
      ),
    );
  }

  Widget _visibilitySwitch({
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(sublabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary500,
          ),
        ],
      ),
    );
  }
}
