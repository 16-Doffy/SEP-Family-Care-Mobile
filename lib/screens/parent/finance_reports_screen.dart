import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/json_report_view.dart';

// UC — Báo cáo kế hoạch vs thực tế (feedback Hội đồng Review 2: "thiếu so
// sánh kế hoạch vs thực tế"). Gộp 3 report endpoint Finance mới (BE 07/07):
//   - Ngân sách theo kế hoạch: GET .../budget-plans/{id}/report
//   - Chi tiêu không thiết yếu: GET .../reports/non-essential-spending
//   - Ngân sách & Mục tiêu:    GET .../reports/budget-goal
class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});
  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const Expanded(child: Center(child: Text('Báo cáo tài chính', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              const SizedBox(width: 40),
            ]),
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.link,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.link,
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Ngân sách'),
              Tab(text: 'Chi không thiết yếu'),
              Tab(text: 'Ngân sách & Mục tiêu'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: const [
                _BudgetPlanReportTab(),
                _NonEssentialSpendingTab(),
                _BudgetGoalReportTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

Widget _card({required Widget child}) => Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: child,
    );

// ── Tab 1: Ngân sách theo kế hoạch (chọn 1 plan) ────────────────────────────

class _BudgetPlanReportTab extends StatefulWidget {
  const _BudgetPlanReportTab();
  @override
  State<_BudgetPlanReportTab> createState() => _BudgetPlanReportTabState();
}

class _BudgetPlanReportTabState extends State<_BudgetPlanReportTab> {
  String? _selectedPlanId;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _report;

  Future<void> _load(String planId) async {
    setState(() { _loading = true; _error = null; _report = null; });
    try {
      final r = await context.read<FinanceProvider>().fetchBudgetPlanReport(planId);
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<FinanceProvider>().budgetPlans;
    if (plans.isEmpty) {
      return Center(
        child: Text('Chưa có kế hoạch ngân sách nào',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
      );
    }
    _selectedPlanId ??= plans.first.id;

    return ListView(children: [
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chọn kế hoạch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedPlanId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: plans.map((p) => DropdownMenuItem(value: p.id, child: Text(p.planName, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedPlanId = v);
              _load(v);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading || _selectedPlanId == null ? null : () => _load(_selectedPlanId!),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Xem báo cáo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
      if (_error != null)
        _card(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
      if (_report != null)
        _card(child: JsonReportView(data: _report)),
    ]);
  }
}

// ── Tab 2: Chi tiêu không thiết yếu ─────────────────────────────────────────

class _NonEssentialSpendingTab extends StatefulWidget {
  const _NonEssentialSpendingTab();
  @override
  State<_NonEssentialSpendingTab> createState() => _NonEssentialSpendingTabState();
}

class _NonEssentialSpendingTabState extends State<_NonEssentialSpendingTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await context.read<FinanceProvider>().fetchNonEssentialSpendingReport();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        if (_error != null)
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ]))
        else if (_report != null)
          _card(child: JsonReportView(data: _report)),
      ]),
    );
  }
}

// ── Tab 3: Ngân sách & Mục tiêu ──────────────────────────────────────────────

class _BudgetGoalReportTab extends StatefulWidget {
  const _BudgetGoalReportTab();
  @override
  State<_BudgetGoalReportTab> createState() => _BudgetGoalReportTabState();
}

class _BudgetGoalReportTabState extends State<_BudgetGoalReportTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await context.read<FinanceProvider>().fetchBudgetGoalReport();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        if (_error != null)
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ]))
        else if (_report != null)
          _card(child: JsonReportView(data: _report)),
      ]),
    );
  }
}
