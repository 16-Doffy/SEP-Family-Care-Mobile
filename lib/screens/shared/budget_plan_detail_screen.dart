import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';

double _numValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _fmt(num n) => '${n.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

/// Quản lý dòng ngân sách (budget line) bên trong 1 kế hoạch.
/// Trước đây budgetPlan chỉ tạo được "vỏ" (planName + tổng thu/chi dự kiến)
/// nhưng không có nơi nào thêm/sửa/xóa từng dòng theo category/jar — đây là
/// phần lõi của "lập ngân sách" (UC-FIN, Report 3 mục 3.5.6 → 3.5.8).
class BudgetPlanDetailScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final String status; // DRAFT | ACTIVE | CLOSED | CANCELED
  const BudgetPlanDetailScreen({
    super.key, required this.planId, required this.planName, required this.status,
  });

  @override
  State<BudgetPlanDetailScreen> createState() => _BudgetPlanDetailScreenState();
}

class _BudgetPlanDetailScreenState extends State<BudgetPlanDetailScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _lines = [];
  String? _error;

  bool get _editable => widget.status == 'DRAFT';

  @override
  void initState() {
    super.initState();
    context.read<FinanceProvider>().fetchAll(); // đảm bảo có categories/jars cho dropdown
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await context.read<FinanceProvider>().fetchBudgetPlanDetail(widget.planId);
      final raw = detail['lines'] is List
          ? detail['lines'] as List
          : detail['budgetLines'] is List
              ? detail['budgetLines'] as List
              : const [];
      _lines = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteLine(String lineId) async {
    try {
      await context.read<FinanceProvider>().deleteBudgetLine(lineId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  void _openLineForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: _LineForm(
          planId: widget.planId,
          existing: existing,
          onSaved: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPlanned = _lines.fold<double>(0, (s, l) => s + _numValue(l['plannedAmount']));
    final totalActual = _lines.fold<double>(0, (s, l) => s + _numValue(l['actualAmount']));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        ),
        title: Text(widget.planName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: false,
      ),
      floatingActionButton: _editable
          ? FloatingActionButton(
              backgroundColor: AppColors.link,
              onPressed: () => _openLineForm(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
                    ),

                  // Tổng hợp
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dự kiến', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        Text(_fmt(totalPlanned), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ])),
                      Container(width: 1, height: 32, color: AppColors.progressTrack),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Thực tế', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                          Text(_fmt(totalActual),
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                                  color: totalActual > totalPlanned && totalPlanned > 0 ? AppColors.danger : AppColors.textPrimary)),
                        ]),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  Text('Dòng ngân sách', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),

                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(child: Column(children: [
                        const Text('🧾', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          _editable ? 'Chưa có dòng nào. Bấm + để thêm.' : 'Kế hoạch này chưa có dòng ngân sách.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ])),
                    )
                  else
                    ..._lines.map((l) {
                      final name = l['categoryName']?.toString() ?? l['jarName']?.toString() ?? l['note']?.toString() ?? 'Dòng ngân sách';
                      final planned = _numValue(l['plannedAmount']);
                      final actual = _numValue(l['actualAmount']);
                      final over = actual > planned && planned > 0;
                      final pct = planned > 0 ? (actual / planned).clamp(0.0, 1.5).toDouble() : 0.0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white, borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                            Text('${_fmt(actual)} / ${_fmt(planned)}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: over ? AppColors.danger : AppColors.textSecondary)),
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct > 1 ? 1.0 : pct,
                              minHeight: 5,
                              backgroundColor: AppColors.progressTrack,
                              color: over ? AppColors.danger : AppColors.link,
                            ),
                          ),
                          if (_editable) ...[
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              GestureDetector(
                                onTap: () => _openLineForm(existing: l),
                                child: Text('Sửa', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link)),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => _deleteLine(l['id']?.toString() ?? ''),
                                child: Text('Xóa', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                              ),
                            ]),
                          ],
                        ]),
                      );
                    }),

                  if (!_editable) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Kế hoạch không ở trạng thái Bản nháp nên không thể thêm/sửa/xóa dòng ngân sách.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LineForm extends StatefulWidget {
  final String planId;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _LineForm({required this.planId, this.existing, required this.onSaved});

  @override
  State<_LineForm> createState() => _LineFormState();
}

class _LineFormState extends State<_LineForm> {
  String? _categoryId;
  String? _jarId;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _essentialType;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _categoryId = widget.existing!['categoryId']?.toString();
      _jarId = widget.existing!['jarId']?.toString();
      _amountCtrl.text = _numValue(widget.existing!['plannedAmount']).round().toString();
      _noteCtrl.text = widget.existing!['note']?.toString() ?? '';
      _essentialType = widget.existing!['essentialType']?.toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      final provider = context.read<FinanceProvider>();
      if (_isEdit) {
        await provider.updateBudgetLine(
          widget.existing!['id']?.toString() ?? '',
          plannedAmount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      } else {
        await provider.createBudgetLine(
          widget.planId,
          categoryId: _categoryId,
          jarId: _jarId,
          plannedAmount: amount,
          essentialType: _essentialType,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isEdit ? 'Sửa dòng ngân sách' : 'Thêm dòng ngân sách',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),

        if (!_isEdit) ...[
          Text('Danh mục', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dropdown(
            value: _categoryId,
            hint: 'Chọn danh mục (tùy chọn)',
            items: finance.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          Text('Hũ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dropdown(
            value: _jarId,
            hint: 'Chọn hũ (tùy chọn)',
            items: finance.activeJars.map((j) => DropdownMenuItem(value: j.id, child: Text(j.name))).toList(),
            onChanged: (v) => setState(() => _jarId = v),
          ),
          const SizedBox(height: 12),
          Text('Loại chi tiêu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dropdown(
            value: _essentialType,
            hint: 'Chọn loại (tùy chọn)',
            items: const [
              DropdownMenuItem(value: 'ESSENTIAL', child: Text('Thiết yếu')),
              DropdownMenuItem(value: 'NON_ESSENTIAL', child: Text('Không thiết yếu')),
              DropdownMenuItem(value: 'NEUTRAL', child: Text('Khác')),
            ],
            onChanged: (v) => setState(() => _essentialType = v),
          ),
          const SizedBox(height: 12),
        ],

        Text('Số tiền dự kiến', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: '0 ₫', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
        ),
        const SizedBox(height: 12),
        Text('Ghi chú', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
          child: TextField(controller: _noteCtrl, decoration: InputDecoration(hintText: 'Tùy chọn...', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted))),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_isEdit ? 'Lưu thay đổi' : 'Thêm dòng', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
