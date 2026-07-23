import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/json_report_view.dart';
import '../../widgets/ring_chart.dart';

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Báo cáo tài chính',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.link,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.link,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
          ],
        ),
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
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: child,
);

class _ReportMetric {
  final String label;
  final double value;
  final Color color;

  const _ReportMetric(this.label, this.value, this.color);
}

class _ReportVisualSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportVisualSummary({required this.data});

  static const _colors = [
    AppColors.link,
    AppColors.shared,
    AppColors.success,
    Color(0xFFF97316),
    Color(0xFF7C3AED),
    AppColors.sos,
  ];

  @override
  Widget build(BuildContext context) {
    final ratio = _bestRatio(data);
    final metrics = _moneyMetrics(data).take(6).toList();
    if (ratio == null && metrics.isEmpty) {
      return _card(
        child: Text(
          'Báo cáo này chưa có số liệu tiền/tỷ lệ đủ rõ để vẽ biểu đồ.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insert_chart_outlined_rounded,
                size: 18,
                color: AppColors.link,
              ),
              const SizedBox(width: 8),
              Text(
                'Trực quan hoá',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                RingChart(
                  progress: ratio.value.clamp(0, 1),
                  size: 92,
                  strokeWidth: 12,
                  color: ratio.color,
                  trackColor: ratio.color.withValues(alpha: 0.16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(ratio.value * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'tỷ lệ',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ratio.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ratio.description,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MetricBars(metrics: metrics),
          ],
        ],
      ),
    );
  }

  static ({String label, String description, double value, Color color})?
  _bestRatio(Map<String, dynamic> data) {
    final nonEssential = _firstNumber(data, const [
      'nonEssentialExpense',
      'nonEssentialSpending',
    ]);
    final totalExpense = _firstNumber(data, const ['totalExpense']);
    if (nonEssential != null && totalExpense != null && totalExpense > 0) {
      return (
        label: 'Chi không thiết yếu',
        description:
            '${_fmtMoney(nonEssential)} trên tổng chi ${_fmtMoney(totalExpense)}',
        value: nonEssential / totalExpense,
        color: AppColors.sos,
      );
    }

    final actualExpense = _firstNumber(data, const ['actualExpense']);
    final actualIncome = _firstNumber(data, const ['actualIncome']);
    if (actualExpense != null && actualIncome != null && actualIncome > 0) {
      return (
        label: 'Tỷ lệ chi tiêu thực tế',
        description:
            '${_fmtMoney(actualExpense)} đã chi trên ${_fmtMoney(actualIncome)} thu nhập',
        value: actualExpense / actualIncome,
        color: AppColors.shared,
      );
    }

    final current = _firstNumber(data, const ['currentAmount']);
    final target = _firstNumber(data, const ['targetAmount']);
    if (current != null && target != null && target > 0) {
      return (
        label: 'Tiến độ mục tiêu',
        description:
            '${_fmtMoney(current)} đã góp trên mục tiêu ${_fmtMoney(target)}',
        value: current / target,
        color: AppColors.success,
      );
    }
    return null;
  }

  static List<_ReportMetric> _moneyMetrics(Map<String, dynamic> data) {
    final values = <_ReportMetric>[];
    var colorIndex = 0;
    void walk(dynamic node, [String key = '']) {
      if (node is Map) {
        for (final entry in node.entries) {
          walk(entry.value, entry.key.toString());
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, key);
        }
      } else if (node is num && _looksLikeMoney(key) && node.abs() > 0) {
        final label = _label(key);
        if (values.any((m) => m.label == label && m.value == node.toDouble())) {
          return;
        }
        values.add(
          _ReportMetric(
            label,
            node.toDouble(),
            _colors[colorIndex++ % _colors.length],
          ),
        );
      }
    }

    walk(data);
    values.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return values;
  }

  static double? _firstNumber(dynamic node, List<String> keys) {
    if (node is Map) {
      for (final key in keys) {
        final value = node[key];
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      for (final value in node.values) {
        final found = _firstNumber(value, keys);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _firstNumber(value, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  static bool _looksLikeMoney(String key) {
    final k = key.toLowerCase();
    return k.contains('amount') ||
        k.contains('income') ||
        k.contains('expense') ||
        k.contains('spending') ||
        k.contains('balance') ||
        k.contains('contribution') ||
        k.contains('planned') ||
        k.contains('actual') ||
        k.contains('remaining') ||
        k.contains('target');
  }
}

class _MetricBars extends StatelessWidget {
  final List<_ReportMetric> metrics;
  const _MetricBars({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final maxValue = metrics
        .map((m) => m.value.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxValue <= 0) return const SizedBox.shrink();
    return Column(
      children: [
        for (final metric in metrics) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtMoney(metric.value),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (metric.value.abs() / maxValue).clamp(0, 1),
              minHeight: 8,
              color: metric.color,
              backgroundColor: metric.color.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReportExportButton extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _ReportExportButton({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.link),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          final csv = _toCsv(data);
          await Clipboard.setData(ClipboardData(text: csv));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã tạo CSV cho "$title" và sao chép vào clipboard',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        },
        icon: const Icon(Icons.file_download_outlined, color: AppColors.link),
        label: Text(
          'Xuất CSV',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.link,
          ),
        ),
      ),
    );
  }

  static String _toCsv(Map<String, dynamic> data) {
    final rows = <List<String>>[
      ['Trường dữ liệu', 'Giá trị'],
    ];
    void walk(dynamic node, String path) {
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key.toString();
          walk(
            entry.value,
            path.isEmpty ? _label(key) : '$path > ${_label(key)}',
          );
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], '$path #${i + 1}');
        }
      } else {
        rows.add([path, _formatScalar(node)]);
      }
    }

    walk(data, '');
    return rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
  }

  static String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

String _formatScalar(dynamic value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  return value.toString();
}

String _fmtMoney(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final raw = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
    buf.write(raw[i]);
  }
  return '$sign${buf.toString()} ₫';
}

String _label(String key) => switch (key) {
  'plannedIncome' || 'expectedSharedIncome' => 'Thu nhập kế hoạch',
  'plannedExpense' || 'expectedSharedExpense' => 'Chi tiêu kế hoạch',
  'actualIncome' => 'Thu nhập thực tế',
  'actualExpense' => 'Chi tiêu thực tế',
  'plannedBalance' => 'Số dư kế hoạch',
  'actualBalance' => 'Số dư thực tế',
  'varianceIncome' => 'Chênh lệch thu',
  'varianceExpense' => 'Chênh lệch chi',
  'nonEssentialExpense' || 'nonEssentialSpending' => 'Chi không thiết yếu',
  'totalExpense' => 'Tổng chi',
  'targetAmount' => 'Số tiền mục tiêu',
  'currentAmount' => 'Đã góp',
  'remainingAmount' => 'Còn thiếu',
  'monthlyContributionTarget' => 'Mục tiêu góp mỗi tháng',
  _ =>
    key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' '),
};

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
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final r = await context.read<FinanceProvider>().fetchBudgetPlanReport(
        planId,
      );
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPlans = context.watch<FinanceProvider>().budgetPlans;
    // Báo cáo của plan CLOSED vẫn có giá trị lịch sử. Plan CANCELED chưa từng
    // là kế hoạch áp dụng hợp lệ nên không làm nhiễu dropdown báo cáo mặc định.
    final plans = allPlans.where((plan) => plan.status != 'CANCELED').toList()
      ..sort((a, b) {
        if (a.status == 'ACTIVE' && b.status != 'ACTIVE') return -1;
        if (a.status != 'ACTIVE' && b.status == 'ACTIVE') return 1;
        return b.periodStart.compareTo(a.periodStart);
      });
    if (plans.isEmpty) {
      return Center(
        child: Text(
          'Chưa có kế hoạch ngân sách nào',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    if (_selectedPlanId == null ||
        !plans.any((plan) => plan.id == _selectedPlanId)) {
      _selectedPlanId = plans.first.id;
    }

    return ListView(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'So sánh số tiền đã đặt kế hoạch với giao dịch thực tế.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chọn kế hoạch',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPlanId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: plans
                    .map(
                      (plan) => DropdownMenuItem(
                        value: plan.id,
                        child: Text(
                          '${plan.planName} · ${plan.statusLabel}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading || _selectedPlanId == null
                      ? null
                      : () => _load(_selectedPlanId!),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Xem báo cáo',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          _card(
            child: Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger),
            ),
          ),
        if (_report != null) _ReportVisualSummary(data: _report!),
        if (_report != null)
          _ReportExportButton(title: 'Báo cáo ngân sách', data: _report!),
        if (_report != null)
          _card(child: JsonReportView(data: _report, financeReportMode: true)),
      ],
    );
  }
}

// ── Tab 2: Chi tiêu không thiết yếu ─────────────────────────────────────────

class _NonEssentialSpendingTab extends StatefulWidget {
  const _NonEssentialSpendingTab();
  @override
  State<_NonEssentialSpendingTab> createState() =>
      _NonEssentialSpendingTabState();
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context
          .read<FinanceProvider>()
          .fetchNonEssentialSpendingReport();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          _card(
            child: Text(
              'Cho biết trong tháng có bao nhiêu tiền được chi cho các danh mục đã đánh dấu “Không thiết yếu”.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_error != null)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          else if (_report != null)
            _ReportVisualSummary(data: _report!),
          if (_report != null)
            _ReportExportButton(
              title: 'Báo cáo chi không thiết yếu',
              data: _report!,
            ),
          if (_report != null)
            _card(
              child: JsonReportView(data: _report, financeReportMode: true),
            ),
        ],
      ),
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<FinanceProvider>().fetchBudgetGoalReport();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          _card(
            child: Text(
              'Theo dõi từng mục tiêu tiết kiệm: đã góp, còn thiếu, tiến độ và số tiền nên góp mỗi tháng để kịp hạn.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_error != null)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          else if (_report != null)
            _ReportVisualSummary(data: _report!),
          if (_report != null)
            _ReportExportButton(
              title: 'Báo cáo ngân sách và mục tiêu',
              data: _report!,
            ),
          if (_report != null)
            _card(
              child: JsonReportView(data: _report, financeReportMode: true),
            ),
        ],
      ),
    );
  }
}
