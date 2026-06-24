import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';
import 'budget_plan_detail_screen.dart';

double _numValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _fmt(double n) => '${n.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

class FinancePlansScreen extends StatefulWidget {
  const FinancePlansScreen({super.key});
  @override
  State<FinancePlansScreen> createState() => _FinancePlansScreenState();
}

class _FinancePlansScreenState extends State<FinancePlansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll();
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                ),
              ),
              Expanded(child: Center(child: Text('Kế hoạch & Mục tiêu',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              const SizedBox(width: 40),
            ]),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(12)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Kế hoạch'),
                Tab(text: 'Mục tiêu'),
                Tab(text: 'Cảnh báo'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(controller: _tab, children: const [
              _BudgetPlansTab(),
              _GoalsTab(),
              _AlertsTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Budget Plans Tab ─────────────────────────────────────────────────────────

class _BudgetPlansTab extends StatefulWidget {
  const _BudgetPlansTab();
  @override
  State<_BudgetPlansTab> createState() => _BudgetPlansTabState();
}

class _BudgetPlansTabState extends State<_BudgetPlansTab> {
  bool _showCreate = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _expenseCtrl = TextEditingController();
  String _periodType = 'MONTHLY';
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  static const _statusCfg = {
    'ACTIVE':    (label: 'Active',    bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    'DRAFT':     (label: 'Bản nháp', bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    'COMPLETED': (label: 'Hoàn thành', bg: Color(0xFFEFF6FF), color: Color(0xFF2563EB)),
    'CANCELLED': (label: 'Đã hủy',   bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
  };

  @override
  void dispose() {
    _nameCtrl.dispose(); _incomeCtrl.dispose(); _expenseCtrl.dispose();
    _startCtrl.dispose(); _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<FinanceProvider>().budgetPlans;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: () => context.read<FinanceProvider>().fetchAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          children: [
            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📋', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Chưa có kế hoạch nào', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  Text('Tạo kế hoạch để theo dõi ngân sách', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ])),
              )
            else
              ...plans.map((p) {
                final st = _statusCfg[p.status] ?? _statusCfg['DRAFT']!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(p.planName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(8)),
                        child: Text(st.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: st.color)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('${p.periodStart.length >= 10 ? p.periodStart.substring(0, 10) : p.periodStart} → ${p.periodEnd.length >= 10 ? p.periodEnd.substring(0, 10) : p.periodEnd}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    if (p.expectedSharedIncome != null || p.expectedSharedExpense != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        if (p.expectedSharedIncome != null)
                          _infoChip('Thu ${_fmt(p.expectedSharedIncome!)}', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                        if (p.expectedSharedExpense != null) ...[
                          const SizedBox(width: 8),
                          _infoChip('Chi ${_fmt(p.expectedSharedExpense!)}', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                        ],
                      ]),
                    ],
                    if (p.status == 'DRAFT') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.link,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: () => _doAction(p, 'activate'),
                            child: Text('Kích hoạt', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: () => _doAction(p, 'cancel'),
                            child: Text('Hủy', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
                          ),
                        ),
                      ]),
                    ] else if (p.status == 'ACTIVE') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.link),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: () => _viewReport(p.id, p.planName),
                            child: Text('Xem báo cáo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.link)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.textMuted),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: () => _doAction(p, 'close'),
                            child: Text('Đóng kế hoạch', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.push(
                          '/finance-plans/budget/${p.id}',
                          extra: {'planName': p.planName, 'status': p.status},
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Quản lý dòng ngân sách', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.link)),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.link),
                        ]),
                      ),
                    ),
                  ]),
                );
              }),
          ],
        ),
      ),
      Positioned(
        right: 20, bottom: 20,
        child: FloatingActionButton(
          backgroundColor: AppColors.link,
          heroTag: 'plan_fab',
          onPressed: () => setState(() => _showCreate = true),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      if (_showCreate) _sheet(context),
    ]);
  }

  Widget _infoChip(String text, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Future<void> _doAction(BudgetPlan plan, String action) async {
    try {
      if (action == 'activate') {
        final detail = await context.read<FinanceProvider>().fetchBudgetPlanDetail(plan.id);
        final lines = detail['lines'] is List
            ? detail['lines'] as List
            : detail['budgetLines'] is List
                ? detail['budgetLines'] as List
                : const [];
        if (lines.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm ít nhất một dòng ngân sách trước khi kích hoạt.'),
              backgroundColor: AppColors.danger,
            ),
          );
          context.push(
            '/finance-plans/budget/${plan.id}',
            extra: {'planName': plan.planName, 'status': plan.status},
          );
          return;
        }
      }
      await context.read<FinanceProvider>().budgetPlanAction(plan.id, action);
      context.read<FinanceProvider>().fetchAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _viewReport(String planId, String planName) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierColor: Colors.black54,
    );
    Map<String, dynamic>? report;
    String? error;
    try {
      report = await context.read<FinanceProvider>().fetchBudgetPlanReport(planId);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // đóng loading dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Báo cáo: $planName', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (error != null)
            Text('Không tải được báo cáo: $error', style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger))
          else if (report == null || report.isEmpty)
            Text('Chưa có dữ liệu báo cáo.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
          else
            ..._reportRows(report),
        ]),
      ),
    );
  }

  // BE chưa document response schema cho /budget-plans/{id}/report nên đọc
  // defensive theo vài tên field hay gặp (planned/actual theo từng dòng).
  List<Widget> _reportRows(Map<String, dynamic> report) {
    final lines = report['lines'] is List
        ? report['lines'] as List
        : report['items'] is List
            ? report['items'] as List
            : const [];
    if (lines.isEmpty) {
      return [Text('Kế hoạch chưa có dòng ngân sách nào để báo cáo.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))];
    }
    return lines.whereType<Map>().map((l) {
      final name = l['categoryName']?.toString() ?? l['jarName']?.toString() ?? l['note']?.toString() ?? 'Mục';
      final planned = _numValue(l['plannedAmount']);
      final actual = _numValue(l['actualAmount']);
      final over = actual > planned && planned > 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
          Text('${_fmt(actual)} / ${_fmt(planned)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: over ? AppColors.danger : AppColors.textSecondary)),
        ]),
      );
    }).toList();
  }

  Widget _sheet(BuildContext context) {
    final now = DateTime.now();
    if (_startCtrl.text.isEmpty) {
      _startCtrl.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final end = DateTime(now.year, now.month + 1, 0);
      _endCtrl.text = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }
    return _BottomOverlay(
      onDismiss: () => setState(() => _showCreate = false),
      child: StatefulBuilder(builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tạo kế hoạch ngân sách', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _lbl('Tên kế hoạch'),
        _inp(_nameCtrl, 'VD: Ngân sách tháng 6/2026'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Từ ngày'),
            _inp(_startCtrl, 'YYYY-MM-DD'),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Đến ngày'),
            _inp(_endCtrl, 'YYYY-MM-DD'),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Thu nhập dự kiến'),
            _moneyInp(_incomeCtrl),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Chi tiêu dự kiến'),
            _moneyInp(_expenseCtrl),
          ])),
        ]),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _saving ? null : () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            setS(() => _saving = true);
            try {
              await context.read<FinanceProvider>().createBudgetPlan(
                planName: _nameCtrl.text.trim(),
                periodType: _periodType,
                periodStart: _startCtrl.text.trim(),
                periodEnd: _endCtrl.text.trim(),
                expectedSharedIncome: double.tryParse(_incomeCtrl.text),
                expectedSharedExpense: double.tryParse(_expenseCtrl.text),
              );
              context.read<FinanceProvider>().fetchAll();
              if (mounted) setState(() => _showCreate = false);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
            }
            setS(() => _saving = false);
          },
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Tạo kế hoạch', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        TextButton(onPressed: () => setState(() => _showCreate = false),
            child: Center(child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textMuted)))),
      ])),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)));
  Widget _inp(TextEditingController c, String hint) => Container(
        height: 48, margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: TextField(controller: c, decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
      );
  Widget _moneyInp(TextEditingController c) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: '0', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
        ),
      );
}

// ─── Goals Tab ────────────────────────────────────────────────────────────────

class _GoalsTab extends StatefulWidget {
  const _GoalsTab();
  @override
  State<_GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<_GoalsTab> {
  bool _showCreate = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();

  @override
  void dispose() { _nameCtrl.dispose(); _targetCtrl.dispose(); _deadlineCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<FinanceProvider>().goals;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: () => context.read<FinanceProvider>().fetchAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Mục tiêu là khoản cần dành dụm, ví dụ mua xe hoặc du lịch. Tiến độ chỉ tăng khi manager phân bổ một giao dịch/thưởng vào mục tiêu; app không tự động chuyển tiền thật.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.35),
              ),
            ),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🎯', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Chưa có mục tiêu nào', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  Text('Tạo mục tiêu tài chính để theo dõi tiến độ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ])),
              )
            else
              ...goals.map((g) {
                final pct = ((g.progressPercent ?? 0).clamp(0.0, 100.0) / 100).toDouble();
                final isActive = g.status == 'ACTIVE';
                return GestureDetector(
                  onTap: () => _showGoalDetail(context, g),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
                  ),
                  child: Row(children: [
                    RingChart(
                      progress: pct,
                      size: 72, strokeWidth: 10,
                      color: pct >= 1 ? AppColors.success : AppColors.link,
                      trackColor: const Color(0xFFF3F4F6),
                      child: Text('${(pct * 100).round()}%',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(g.goalName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                            child: Text(g.status, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(_fmt(g.targetAmount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      if (g.deadline != null)
                        Text('Hạn: ${g.deadline!.length >= 10 ? g.deadline!.substring(0, 10) : g.deadline}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ])),
                    if (isActive)
                      GestureDetector(
                        onTap: () => _cancelGoal(g.id),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      ),
                  ]),
                  ),
                );
              }),
          ],
        ),
      ),
      Positioned(
        right: 20, bottom: 20,
        child: FloatingActionButton(
          backgroundColor: AppColors.link,
          heroTag: 'goal_fab',
          onPressed: () => setState(() => _showCreate = true),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      if (_showCreate) _sheet(context),
    ]);
  }

  Future<void> _cancelGoal(String id) async {
    try {
      await context.read<FinanceProvider>().cancelGoal(id);
      context.read<FinanceProvider>().fetchAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _showGoalDetail(BuildContext context, FinancialGoal goal) async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierColor: Colors.black54,
    );
    Map<String, dynamic>? progress;
    List<Map<String, dynamic>> allocations = [];
    String? warning;
    final finance = context.read<FinanceProvider>();
    // Gọi endpoint progress riêng vì list /financial-goals có thể không
    // luôn kèm progressPercent mới nhất.
    try {
      progress = await finance.fetchGoalProgress(goal.id);
    } catch (e) {
      warning = e.toString();
    }
    try {
      allocations = await finance.fetchGoalAllocations(goal.id);
    } catch (e) {
      warning ??= e.toString();
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(goal.goalName, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Mục tiêu: ${_fmt(goal.targetAmount)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text(
            'Tiến độ hiện tại: ${(progress?['progressPercent'] ?? progress?['percent'] ?? goal.progressPercent ?? 0).toString()}%',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.link),
          ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Text('Một phần dữ liệu chưa tải được, đang hiển thị thông tin hiện có.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 12),
          Text('Lịch sử phân bổ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          if (allocations.isEmpty)
            Text('Chưa có giao dịch nào được phân bổ vào mục tiêu này.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
          else
            ...allocations.map((a) {
              final amount = _numValue(a['amount']);
              final date = a['createdAt']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(date.length >= 10 ? date.substring(0, 10) : date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                  Text(_fmt(amount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return _BottomOverlay(
      onDismiss: () => setState(() => _showCreate = false),
      child: StatefulBuilder(builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tạo mục tiêu tài chính', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _lbl('Tên mục tiêu'),
        _inp(_nameCtrl, 'VD: Mua xe máy, Quỹ du lịch...'),
        const SizedBox(height: 12),
        _lbl('Số tiền mục tiêu'),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: '0 ₫', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
        ),
        const SizedBox(height: 12),
        _lbl('Hạn chót (tùy chọn)'),
        _inp(_deadlineCtrl, 'YYYY-MM-DD'),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _saving ? null : () async {
            if (_nameCtrl.text.trim().isEmpty || _targetCtrl.text.isEmpty) return;
            setS(() => _saving = true);
            try {
              await context.read<FinanceProvider>().createGoal(
                goalName: _nameCtrl.text.trim(),
                targetAmount: double.parse(_targetCtrl.text),
                deadline: _deadlineCtrl.text.trim().isEmpty ? null : _deadlineCtrl.text.trim(),
              );
              context.read<FinanceProvider>().fetchAll();
              if (mounted) setState(() => _showCreate = false);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
            }
            setS(() => _saving = false);
          },
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Tạo mục tiêu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        TextButton(onPressed: () => setState(() => _showCreate = false),
            child: Center(child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textMuted)))),
      ])),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)));
  Widget _inp(TextEditingController c, String hint) => Container(
        height: 48, margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: TextField(controller: c, decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
      );
}

// ─── Alerts Tab ───────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  static const _severityCfg = {
    'HIGH':   (icon: '🔴', bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626), label: 'Cao'),
    'MEDIUM': (icon: '🟡', bg: Color(0xFFFFFBEB), color: Color(0xFFD97706), label: 'Trung bình'),
    'LOW':    (icon: '🟢', bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A), label: 'Thấp'),
  };

  Future<void> _recompute(BuildContext context) async {
    try {
      await context.read<FinanceProvider>().recomputeAlerts();
      if (context.mounted) {
        await context.read<FinanceProvider>().fetchAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tính lại cảnh báo ✅'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _resolve(BuildContext context, String alertId) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đánh dấu đã giải quyết', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Ghi chú (không bắt buộc)...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<FinanceProvider>().resolveAlert(alertId, note: noteCtrl.text.trim());
      if (context.mounted) context.read<FinanceProvider>().fetchAll();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<FinanceProvider>().alerts;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: () => context.read<FinanceProvider>().fetchAll(),
        child: alerts.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎉', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Không có cảnh báo nào', style: TextStyle(color: AppColors.textMuted)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final a = alerts[i];
                  final sev = _severityCfg[a.severity] ?? _severityCfg['LOW']!;
                  final isNew = a.status == 'NEW';
                  final isAcknowledged = a.status == 'ACKNOWLEDGED';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isNew ? sev.bg.withValues(alpha: 0.5) : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isNew ? Border.all(color: sev.color.withValues(alpha: 0.3)) : null,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sev.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: sev.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(sev.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: sev.color)),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.notification, shape: BoxShape.circle),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 6),
                          Text(a.message, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(a.createdAt.length >= 10 ? a.createdAt.substring(0, 10) : a.createdAt,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ])),
                        if (isNew)
                          GestureDetector(
                            onTap: () async {
                              await context.read<FinanceProvider>().acknowledgeAlert(a.id);
                              context.read<FinanceProvider>().fetchAll();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(8)),
                              child: Text('Đã xem', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                      ]),
                      if (isAcknowledged) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.success),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _resolve(context, a.id),
                            child: Text('Đánh dấu đã giải quyết', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ),
                        ),
                      ],
                    ]),
                  );
                },
              ),
      ),
      Positioned(
        right: 20, bottom: 20,
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.link,
          heroTag: 'alert_recompute_fab',
          onPressed: () => _recompute(context),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
          label: Text('Tính lại', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]);
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _BottomOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  const _BottomOverlay({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
