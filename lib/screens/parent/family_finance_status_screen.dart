import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/finance_period.dart';
import '../../models/finance_jar_label.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';

/// Monthly, management-only view of actual family finances.  This deliberately
/// does not alter the finance model: jars below describe tagged spending, not
/// money that has been physically moved into jars.
class FamilyFinanceStatusScreen extends StatefulWidget {
  const FamilyFinanceStatusScreen({super.key});

  @override
  State<FamilyFinanceStatusScreen> createState() =>
      _FamilyFinanceStatusScreenState();
}

class _FamilyFinanceStatusScreenState extends State<FamilyFinanceStatusScreen> {
  JarTargetActualReport? _jarReport;
  SurplusAvailability? _surplus;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({FinancePeriod? period}) async {
    final wallet = context.read<WalletProvider>();
    final finance = context.read<FinanceProvider>();
    await Future.wait([
      wallet.fetchWallets(period: period),
      finance.fetchAll(),
    ]);
    final selected = wallet.period;
    FinanceModel? model;
    for (final item in finance.models) {
      if (item.isActive) {
        model = item;
      }
    }
    if (!mounted) return;
    setState(() => _loadingDetails = true);
    try {
      final values = await Future.wait([
        model == null
            ? Future<JarTargetActualReport?>.value(null)
            : finance.fetchJarTargetActualReport(
                periodStart: selected.start,
                periodEnd: selected.end,
                financeModelId: model.id,
              ),
        finance.fetchSurplusAvailability(selected.month, selected.year),
      ]);
      if (mounted) {
        setState(() {
          _jarReport = values[0] as JarTargetActualReport?;
          _surplus = values[1] as SurplusAvailability?;
        });
      }
    } catch (_) {
      // The main overview remains useful if an optional drill-down is absent.
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static String _money(double value) =>
      '${value.round().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => '${m[1]},')} ₫';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user?.canManageFinance != true) {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền xem màn này.')),
      );
    }
    final wallet = context.watch<WalletProvider>();
    final summary = wallet.financeSummary ?? const <String, dynamic>{};
    final budget = _map(summary['budget']);
    final income = _number(
      budget['actualIncome'] ?? budget['totalIncome'] ?? wallet.monthlyIncome,
    );
    final expense = _number(
      budget['actualExpense'] ??
          budget['totalExpense'] ??
          wallet.monthlyExpense,
    );
    final remaining = income - expense;
    final health = income <= 0 || remaining < 0
        ? ('Cần chú ý', AppColors.danger)
        : expense / income > .9
        ? ('Cần chú ý', AppColors.urgent)
        : ('Ổn', AppColors.success);
    final contributions = _list(
      (wallet.memberContributionSummary ?? const {})['items'],
    );
    final atRiskGoals = context.watch<FinanceProvider>().goals.where((g) {
      final progress = g.targetAmount <= 0
          ? 1
          : (g.displayCurrentAmount ?? 0) / g.targetAmount;
      final deadline = DateTime.tryParse(g.deadline ?? '');
      return progress < .5 &&
          deadline != null &&
          deadline.isBefore(DateTime.now().add(const Duration(days: 60)));
    }).toList();
    final overJars = (_jarReport?.items ?? const <JarTargetActualItem>[])
        .where(
          (j) =>
              !j.isSavingLike &&
              (j.status == 'OVER_TARGET' ||
                  j.actualPercentage > j.targetPercentage),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Tình hình tài chính gia đình',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              _periodBar(wallet.period),
              const SizedBox(height: 16),
              _card(
                'Tổng quan tháng này',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thu, chi và số tiền còn lại trong ${wallet.period.label.toLowerCase()}.',
                            style: _muted,
                          ),
                        ),
                        _badge(health.$1, health.$2),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _metric('Thu', income, AppColors.success),
                        _metric('Chi', expense, AppColors.danger),
                        _metric('Còn lại', remaining, health.$2),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                'Việc cần xử lý',
                Column(
                  children: [
                    if (overJars.isNotEmpty)
                      _insight(
                        Icons.pie_chart_rounded,
                        'Chi vượt tỷ trọng',
                        '${overJars.first.jarName} đang cao hơn tỷ lệ đặt trong mô hình.',
                        AppColors.urgent,
                      ),
                    if (atRiskGoals.isNotEmpty)
                      _insight(
                        Icons.flag_rounded,
                        'Mục tiêu có nguy cơ chậm',
                        '${atRiskGoals.first.goalName} mới đạt ${(((atRiskGoals.first.displayCurrentAmount ?? 0) / atRiskGoals.first.targetAmount) * 100).round()}%.',
                        AppColors.danger,
                      ),
                    if ((_surplus?.availableSurplus ?? 0) > 0)
                      _insight(
                        Icons.account_balance_wallet_rounded,
                        'Tiền dư chưa phân bổ',
                        'Còn ${_money(_surplus!.availableSurplus)} có thể kết chuyển vào mục tiêu.',
                        AppColors.link,
                      ),
                    if (overJars.isEmpty &&
                        atRiskGoals.isEmpty &&
                        (_surplus?.availableSurplus ?? 0) <= 0)
                      Text(
                        'Chưa có việc cần xử lý nổi bật trong kỳ này.',
                        style: _muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                'Chi theo kế hoạch',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chi tiêu đã được gán danh mục/hũ; không phải tiền thật đã chia vào quỹ.',
                      style: _muted,
                    ),
                    const SizedBox(height: 12),
                    if (_loadingDetails) const LinearProgressIndicator(),
                    ...(_jarReport?.items ?? const <JarTargetActualItem>[])
                        .take(5)
                        .map((j) => _jarRow(j)),
                    if ((_jarReport?.items ?? const []).isEmpty &&
                        !_loadingDetails)
                      Text(
                        'Chưa có dữ liệu chi theo hũ trong kỳ này.',
                        style: _muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                'Đóng góp gia đình',
                contributions.isEmpty
                    ? Text(
                        'Chưa có dữ liệu đóng góp theo thành viên.',
                        style: _muted,
                      )
                    : Column(
                        children: contributions.take(5).map((c) {
                          final planned = _number(
                            c['plannedAmount'] ?? c['targetAmount'],
                          );
                          final actual = _number(
                            c['actualAmount'] ?? c['contributedAmount'],
                          );
                          final name =
                              c['memberName']?.toString() ??
                              c['name']?.toString() ??
                              'Thành viên';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Kế hoạch ${_money(planned)} · Thực tế ${_money(actual)}',
                              style: _muted,
                            ),
                            trailing: Text(
                              _money(actual - planned),
                              style: TextStyle(
                                color: actual >= planned
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _card(
                'Mục tiêu và tiền dư',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...context.watch<FinanceProvider>().goals.take(3).map((g) {
                      final current = g.displayCurrentAmount ?? 0;
                      final pct = g.targetAmount <= 0
                          ? 0.0
                          : (current / g.targetAmount).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.goalName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: pct,
                              color: AppColors.link,
                            ),
                            Text(
                              '${_money(current)} / ${_money(g.targetAmount)}',
                              style: _muted,
                            ),
                          ],
                        ),
                      );
                    }),
                    if ((_surplus?.availableSurplus ?? 0) > 0)
                      Text(
                        'Khả dụng để phân bổ: ${_money(_surplus!.availableSurplus)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodBar(FinancePeriod p) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: () => _load(period: p.previous),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(p.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      IconButton(
        onPressed: p.isCurrent ? null : () => _load(period: p.next),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
  TextStyle get _muted =>
      GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted);
  Widget _card(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
  Widget _metric(String label, double value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _muted),
        const SizedBox(height: 4),
        Text(
          _money(value),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
  Widget _insight(IconData icon, String title, String body, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: _muted,
                  children: [
                    TextSpan(
                      text: '$title: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(text: body),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  Widget _jarRow(JarTargetActualItem j) {
    final over = !j.isSavingLike && j.actualPercentage > j.targetPercentage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  jarDisplayName(j.jarCode, j.jarName),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${j.actualPercentage.toStringAsFixed(0)}% / ${j.targetPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: over ? AppColors.danger : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: (j.actualPercentage / 100).clamp(0.0, 1.0),
            color: over ? AppColors.danger : AppColors.link,
          ),
        ],
      ),
    );
  }
}
