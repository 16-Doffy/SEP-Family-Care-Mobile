import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/finance_period.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_alert_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../theme/app_ui_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/month_start_checklist.dart';
import '../../widgets/month_switcher.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/retry_state.dart';
import '../../widgets/waffle_chart.dart';
import '../../widgets/money_input.dart';

String _fmt(int n) =>
    '${n.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ₫';

class _JarOverviewRow {
  const _JarOverviewRow({
    required this.name,
    required this.pct,
    required this.target,
    required this.actual,
    required this.status,
    this.isSavingLike = false,
  });

  final String name;
  final double pct;
  final double target;
  final double actual;
  final String status;

  /// Hũ tích luỹ — vượt tỷ lệ là chuyện tốt, không tô đỏ.
  final bool isSavingLike;

  bool get isAboveTarget =>
      status == 'OVER_TARGET' || (target > 0 && actual > target);

  /// Chỉ hũ **chi tiêu** vượt tỷ lệ mới đáng báo động. Tiết kiệm nhiều hơn dự
  /// định mà tô đỏ như tiêu quá tay là gán sai ý nghĩa cho dữ liệu.
  bool get isOverBudget => isAboveTarget && !isSavingLike;

  /// Nhãn ngắn cho phần chênh lệch so với mô hình.
  String? get deltaLabel {
    if (pct <= 0) return null;
    if (isAboveTarget) return isSavingLike ? 'trên mức' : 'vượt mức';
    return null;
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _tab = 0;
  JarTargetActualReport? _jarTargetReport;
  bool _jarTargetReportLoading = false;
  String? _jarTargetReportError;
  String? _jarTargetReportModelId;

  /// Số dư chưa phân bổ của **kỳ liền trước kỳ đang xem** — nguồn dữ liệu cho
  /// card "Kết chuyển tháng trước".
  SurplusAvailability? _carrySurplus;
  bool _carrySurplusLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final family = context.read<FamilyProvider>();
    await Future.wait([
      context.read<WalletProvider>().fetchWallets(),
      context.read<SupportRequestProvider>().fetchRequests(),
      context.read<FinanceProvider>().fetchAll(),
      // Cảnh báo tài chính trước đây CHỈ được nạp bên trong màn cảnh báo, mà
      // lối vào duy nhất lại nằm sâu trong menu Hồ sơ → vượt ngân sách xong
      // không ai biết. Nạp ở đây để dựng được thẻ cảnh báo ngay trên màn Ví.
      context.read<FinanceAlertProvider>().fetchAlerts(),
      if (family.members.isEmpty) family.fetchMembers(),
    ]);
    if (!mounted) return;
    await _loadJarTargetActualReport();
    if (!mounted) return;
    await _loadCarrySurplus();
  }

  /// Đổi kỳ: sổ chung do `WalletProvider` giữ, còn báo cáo theo hũ và số dư kỳ
  /// trước là state cục bộ của màn này nên phải nạp lại thủ công.
  Future<void> _changePeriod(FinancePeriod period) async {
    await context.read<WalletProvider>().fetchWallets(period: period);
    if (!mounted) return;
    await _loadJarTargetActualReport();
    if (!mounted) return;
    await _loadCarrySurplus();
  }

  /// Đọc `surplus-availability` của kỳ liền trước.
  ///
  /// Chỉ Manager/Deputy gọi được — BE trả 403 với thành viên thường, nên chặn
  /// từ FE thay vì để lỗi rơi vào catch và hiện card trống.
  Future<void> _loadCarrySurplus() async {
    if (context.read<AuthProvider>().user?.canManageFinance != true) {
      if (_carrySurplus != null && mounted) {
        setState(() => _carrySurplus = null);
      }
      return;
    }
    final previous = context.read<WalletProvider>().period.previous;
    final finance = context.read<FinanceProvider>();
    setState(() => _carrySurplusLoading = true);
    try {
      final res = await finance.fetchSurplusAvailability(
        previous.month,
        previous.year,
      );
      if (mounted) setState(() => _carrySurplus = res);
    } catch (e) {
      // Kỳ chưa có dữ liệu là chuyện bình thường (gia đình mới lập) — ẩn card
      // chứ không dựng banner lỗi ở màn tổng quan.
      debugPrint('WalletScreen: loadCarrySurplus failed: $e');
      if (mounted) setState(() => _carrySurplus = null);
    } finally {
      if (mounted) setState(() => _carrySurplusLoading = false);
    }
  }

  Future<void> _loadJarTargetActualReport() async {
    if (!mounted) return;
    setState(() {
      _jarTargetReportLoading = true;
      _jarTargetReportError = null;
    });
    try {
      final finance = context.read<FinanceProvider>();
      // Đọc kỳ trước mọi await — sau await context có thể đã bị unmount.
      final period = context.read<WalletProvider>().period;
      if (finance.models.isEmpty ||
          !finance.models.any((model) => model.isActive)) {
        await finance.fetchAll();
      }

      FinanceModel? activeModel;
      for (final model in finance.models) {
        if (model.isActive) {
          activeModel = model;
          break;
        }
      }

      if (activeModel == null || activeModel.id.isEmpty) {
        if (mounted) {
          setState(() {
            _jarTargetReport = null;
            _jarTargetReportModelId = null;
          });
        }
        return;
      }

      final report = await finance.fetchJarTargetActualReport(
        periodStart: period.start,
        periodEnd: period.end,
        financeModelId: activeModel.id,
      );
      if (mounted) {
        setState(() {
          _jarTargetReport = report;
          _jarTargetReportModelId = activeModel!.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jarTargetReport = null;
          _jarTargetReportError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _jarTargetReportLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = context.watch<WalletProvider>();
    final pendingRequests = context
        .watch<SupportRequestProvider>()
        .pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _backBtn(context),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sổ thu chi gia đình',
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

            Expanded(
              child: walletState.isLoading
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        SkeletonList(items: 4, cardHeight: 116),
                        SizedBox(height: 110),
                      ],
                    )
                  : walletState.error != null
                  ? RetryState(
                      message: walletState.error!,
                      onRetry: () => walletState.fetchWallets(),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        MonthSwitcher(
                          period: walletState.period,
                          enabled: !walletState.isLoading,
                          onChanged: _changePeriod,
                        ),
                        const SizedBox(height: 16),

                        _buildHeroCard(context, walletState),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _tabItem(0, 'Tổng quan'),
                              _tabItem(1, 'Lịch sử'),
                              _tabItem(2, 'Yêu cầu', badge: pendingRequests),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_tab == 0) ..._buildOverview(context, walletState),
                        if (_tab == 1) ..._buildHistory(walletState),
                        if (_tab == 2) ..._buildRequests(context),

                        const SizedBox(height: 110),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, WalletProvider state) {
    final family = state.familyWallet;
    final totalIn = state.monthlyIncome;
    final totalOut = state.monthlyExpense;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.heroOrange, AppColors.heroPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Trước đây ghi "Tổng quỹ gia đình" nhưng con số lấy từ
                  // `/finance/summary` có kèm periodStart/periodEnd — gắn kỳ vào
                  // nhãn để không ai đọc nhầm đây là quỹ luỹ kế mọi thời gian.
                  'Quỹ gia đình · ${state.period.shortLabel}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ),
              GestureDetector(
                onTap: () => _showPeriodExplainerSheet(context, state.period),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(family?.balance.round() ?? 0),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '${state.period.isCurrent ? 'Tháng này' : state.period.label} '
            '+${_fmt(totalIn.round())} / -${_fmt(totalOut.round())}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 18),
          // Ghi giao dịch luôn mang ngày hôm nay → chỉ mở nút khi đang đứng ở
          // tháng hiện tại, tránh cảnh bấm "Thu" trong kỳ cũ rồi không thấy đâu.
          if (state.period.isCurrent)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showRecordSheet(context, isIncome: true),
                    child: _heroBtn(Icons.call_received_rounded, 'Thu'),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white30),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showRecordSheet(context, isIncome: false),
                    child: _heroBtn(Icons.call_made_rounded, 'Chi'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang xem kỳ đã qua. Quay lại "Tháng này" để ghi giao dịch.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Report target/actual theo hu tu BE cho model tai chinh dang active.
  /// Khong tu cong ledger o FE de tranh lech voi mapping category -> jar.
  ({
    List<_JarOverviewRow> rows,
    double unmappedAmount,
    double trackedAmount,
    String? note,
  })
  _jarBreakdown(BuildContext context, double income) {
    const empty = <_JarOverviewRow>[];
    final finance = context.watch<FinanceProvider>();
    FinanceModel? model;
    for (final candidate in finance.models) {
      if (candidate.isActive) {
        model = candidate;
        break;
      }
    }

    if (model == null) {
      return (
        rows: empty,
        unmappedAmount: 0,
        trackedAmount: 0,
        note:
            'Gia \u0111\u00ecnh ch\u01b0a c\u00f3 m\u00f4 h\u00ecnh t\u00e0i ch\u00ednh \u0111ang \u00e1p d\u1ee5ng \u0111\u1ec3 xem b\u00e1o c\u00e1o theo h\u0169.',
      );
    }

    if (_jarTargetReportLoading) {
      return (
        rows: empty,
        unmappedAmount: 0,
        trackedAmount: 0,
        note:
            '\u0110ang t\u1ea3i b\u00e1o c\u00e1o th\u1ef1c chi theo h\u0169 t\u1eeb Backend...',
      );
    }

    if (_jarTargetReportError != null) {
      return (
        rows: empty,
        unmappedAmount: 0,
        trackedAmount: 0,
        note:
            'Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c b\u00e1o c\u00e1o theo h\u0169: $_jarTargetReportError',
      );
    }

    final report = _jarTargetReportModelId == model.id
        ? _jarTargetReport
        : null;
    if (report == null || report.items.isEmpty) {
      return (
        rows: empty,
        unmappedAmount: report?.unmappedAmount ?? 0,
        trackedAmount: 0,
        note:
            'Ch\u01b0a c\u00f3 d\u1eef li\u1ec7u target/actual theo h\u0169 cho k\u1ef3 n\u00e0y.',
      );
    }

    final rows =
        report.items
            .map(
              (item) => _JarOverviewRow(
                name: item.jarName,
                isSavingLike: item.isSavingLike,
                pct: item.targetPercentage,
                target:
                    item.targetAmount ??
                    (income > 0 ? income * item.targetPercentage / 100 : 0),
                actual:
                    item.actualAmount ??
                    (income > 0 ? income * item.actualPercentage / 100 : 0),
                status: item.status,
              ),
            )
            .toList()
          ..sort((a, b) => b.pct.compareTo(a.pct));

    final unmapped = report.unmappedAmount ?? 0;
    // BE chưa trả `trackedAmount` thì cộng bù: tổng thực chi các hũ + phần chưa
    // gán hũ — đúng bằng mẫu số BE dùng để tính targetAmount.
    final tracked =
        report.trackedAmount ??
        (rows.fold<double>(0, (sum, r) => sum + r.actual) + unmapped);
    return (
      rows: rows,
      unmappedAmount: unmapped,
      trackedAmount: tracked,
      note: null,
    );
  }

  List<Widget> _buildOverview(BuildContext context, WalletProvider state) {
    final income = state.monthlyIncome;
    final expense = state.monthlyExpense;
    final remaining = income - expense;
    final jarInfo = _jarBreakdown(context, income);
    final spentRatio = income > 0 ? expense / income : 0.0;
    final bufferPct = income > 0 ? ((remaining / income) * 100).round() : 0;
    final badgeBg = bufferPct < 10
        ? AppColors.dangerLight
        : bufferPct < 30
        ? AppColors.amberLight
        : AppColors.safeLight;
    final badgeTxt = bufferPct < 10
        ? AppColors.dangerDark
        : bufferPct < 30
        ? AppColors.amberDark
        : AppColors.safeDark;

    return [
      MonthStartChecklist(
        period: state.period,
        canManageFinance:
            context.watch<AuthProvider>().user?.canManageFinance == true,
        carrySurplus: _carrySurplus,
        onAllocateSurplus: () {
          final goals = context.read<FinanceProvider>().contributableGoals;
          // `return` trắng ở đây làm dòng checklist "Kết chuyển số dư" bấm vào
          // KHÔNG CÓ GÌ XẢY RA — người dùng tưởng nút hỏng. Không có mục tiêu
          // nào nhận được tiền thì phải nói ra và chỉ đường tạo mục tiêu.
          if (goals.isEmpty) {
            _promptCreateGoalForSurplus(context);
            return;
          }
          _showSurplusGoalPicker(context, goals, period: state.period.previous);
        },
      ),

      ..._financeAlertCard(context),

      ..._carryOverCard(context, state),

      _sectionCard(
        title: state.period.isCurrent
            ? 'Ngân sách tháng này'
            : 'Ngân sách ${state.period.label.toLowerCase()}',
        child: Column(
          children: [
            Row(
              children: [
                RingChart(
                  progress: spentRatio.clamp(0.0, 1.0),
                  size: 110,
                  strokeWidth: 14,
                  color: AppColors.shared,
                  trackColor: AppColors.safeLight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(spentRatio * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'đã chi',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmt(expense.round()),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'đã chi / ${_fmt(income.round())} thu nhập',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Dư ${_fmt(remaining.round())} · $bufferPct%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeTxt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Flexible(
                    flex: expense.round(),
                    fit: FlexFit.tight,
                    child: Container(height: 12, color: AppColors.shared),
                  ),
                  Flexible(
                    flex: remaining.round().clamp(0, 999999999),
                    fit: FlexFit.tight,
                    child: Container(height: 12, color: AppColors.safe),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _barLegend('Chi tiêu', AppColors.shared, _fmt(expense.round())),
                _barLegend('Dư', AppColors.safe, _fmt(remaining.round())),
              ],
            ),
            if (jarInfo.rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.progressTrack),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nhãn cũ ("Hạn mức theo tỷ lệ thu nhập") nói SAI thứ BE
                    // tính. Swagger ghi rõ:
                    //   targetAmount = trackedAmount * targetPercentage / 100
                    // `trackedAmount` là TỔNG CHI đã theo dõi trong kỳ, không
                    // phải thu nhập. Nên đây là "tỷ trọng chi tiêu", không phải
                    // hạn mức — và số bên phải TĂNG THEO mức chi, đúng như
                    // người dùng thấy và tưởng app tính sai.
                    Text(
                      'Tỷ trọng chi tiêu theo hũ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'So sánh tiền đã chi ở mỗi hũ với tỷ lệ của mô hình, tính '
                      'trên TỔNG CHI trong kỳ (${_fmt(jarInfo.trackedAmount.round())}) '
                      '— không phải hạn mức lấy từ thu nhập. Chi càng nhiều thì '
                      'cả hai số đều tăng; điều đáng nhìn là tỷ lệ phần trăm.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...jarInfo.rows.asMap().entries.map(
                (e) => _jarRow(
                  e.value,
                  _jarColor(e.key),
                  trackedAmount: jarInfo.trackedAmount,
                ),
              ),
              // Hũ vượt tỷ lệ mô hình là chuyện đáng biết, NHƯNG nó không tạo
              // cảnh báo tài chính (cảnh báo chỉ sinh từ kế hoạch ngân sách và
              // mục tiêu tiết kiệm). Không nói ra thì người dùng thấy hũ đỏ rồi
              // sang tab Cảnh báo tìm mãi không có, tưởng app hỏng.
              if (jarInfo.rows.any((r) => r.isOverBudget)) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Text(
                    'Vượt tỷ lệ hũ chỉ được báo ở đây, KHÔNG tạo cảnh báo tài '
                    'chính. Muốn được nhắc khi vượt chi thì đặt hạn mức trong '
                    '"Kế hoạch ngân sách" cho đúng kỳ đang chi.',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      height: 1.4,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              // Hiện phần chi không gán hũ để tổng khớp với tổng chi tiêu.
              if (jarInfo.unmappedAmount > 0)
                _jarRow(
                  _JarOverviewRow(
                    name: 'Chưa gán hũ',
                    pct: 0,
                    target: 0,
                    actual: jarInfo.unmappedAmount,
                    status: '',
                  ),
                  AppColors.textMuted,
                ),
            ] else if (jarInfo.note != null) ...[
              const SizedBox(height: 12),
              _emptyFinanceText(jarInfo.note!),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),

      _sectionCard(
        title: jarInfo.rows.isEmpty
            ? 'Phân bổ thu nhập'
            : 'Theo dõi chi tiêu theo mô hình',
        child: jarInfo.rows.isEmpty
            // Chưa có mô hình đang áp dụng → giữ cách chia cũ (thu/chi/dư).
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WaffleChart(
                    segments: [
                      WaffleSegment(
                        color: AppColors.shared,
                        pct: income > 0
                            ? (expense / income * 100).round().clamp(0, 100)
                            : 0,
                        label: 'Chi tiêu',
                        amount: expense.round(),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _waffleLegend(
                          'Thu nhập',
                          AppColors.income,
                          _fmt(income.round()),
                          '100%',
                        ),
                        const SizedBox(height: 10),
                        _waffleLegend(
                          'Chi tiêu',
                          AppColors.shared,
                          _fmt(expense.round()),
                          income > 0
                              ? '${(expense / income * 100).round()}%'
                              : '0%',
                        ),
                        const SizedBox(height: 10),
                        _waffleLegend(
                          'Dư',
                          AppColors.progressTrack,
                          _fmt(remaining.round()),
                          '$bufferPct%',
                        ),
                        if (jarInfo.note != null) ...[
                          const SizedBox(height: 10),
                          _emptyFinanceText(jarInfo.note!),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            // Mỗi ô waffle = 1% thu nhập, chia theo tỷ lệ hũ của mô hình; phần
            // legend hiện số tiền kế hoạch của từng hũ.
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thẻ này vẽ CHI THỰC TẾ, đúng như phụ đề của nó. Trước đây
                  // lại lấy `target` (= tổng chi × tỷ lệ mô hình) rồi chú thích
                  // "Kế hoạch tính trên thu nhập …" — sai cả hai đầu: số không
                  // phải kế hoạch, mà mẫu số cũng không phải thu nhập.
                  WaffleChart(
                    segments: jarInfo.rows
                        .asMap()
                        .entries
                        .map(
                          (e) => WaffleSegment(
                            color: _jarColor(e.key),
                            pct: _actualPct(e.value, jarInfo.trackedAmount),
                            label: e.value.name,
                            amount: e.value.actual.round(),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theo các khoản chi thực tế đã gán danh mục; không phải số tiền đã chia quỹ.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            height: 1.35,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final e in jarInfo.rows.asMap().entries) ...[
                          _waffleLegend(
                            e.value.name,
                            _jarColor(e.key),
                            _fmt(e.value.actual.round()),
                            '${_actualPct(e.value, jarInfo.trackedAmount)}%',
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          'Mô hình đặt mục tiêu '
                          '${jarInfo.rows.map((r) => '${r.name} ${r.pct.round()}%').join(' · ')}. '
                          'Tổng chi trong kỳ ${_fmt(jarInfo.trackedAmount.round())}.',
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
      ),
      const SizedBox(height: 16),

      _financeSummaryCard(state),
      const SizedBox(height: 16),

      _cashFlowCard(state),
      const SizedBox(height: 16),

      _categorySpendingCard(state),
      const SizedBox(height: 16),

      _memberContributionCard(state),
      const SizedBox(height: 16),

      ..._surplusAllocationCard(context),

      _alertBar(remaining.round(), bufferPct),
    ];
  }

  Widget _financeSummaryCard(WalletProvider state) {
    final summary = state.financeSummary ?? const <String, dynamic>{};
    final budget = _asMap(summary['budget']);
    final goals = _asMap(summary['goals']);
    final alerts = _asMap(summary['alerts']);
    final currency = summary['currency']?.toString() ?? 'VND';
    final balance = _moneyFrom(budget, [
      'actualBalance',
      'balance',
      'currentBalance',
      'remainingAmount',
    ], fallback: state.totalBalance);
    final income = _moneyFrom(budget, [
      'actualIncome',
      'totalIncome',
      'income',
    ], fallback: state.monthlyIncome);
    final expense = _moneyFrom(budget, [
      'actualExpense',
      'totalExpense',
      'expense',
    ], fallback: state.monthlyExpense);
    return _sectionCard(
      title: 'Tổng quan Finance API',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill('Số dư', _fmt(balance.round()), AppColors.link),
              _metricPill('Thu', _fmt(income.round()), AppColors.success),
              _metricPill('Chi', _fmt(expense.round()), AppColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Đơn vị: $currency · Cảnh báo mới: ${_number(alerts['totalNew']).round()} · Mục tiêu: ${goals.isEmpty ? 'không tải' : 'đã tải'}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _cashFlowCard(WalletProvider state) {
    final data = state.cashFlowSummary ?? const <String, dynamic>{};
    final totals = _asMap(data['totals']);
    final byMonth = _firstList(data, ['byMonth', 'items', 'data']);
    // API thật trả incomeAmount/expenseAmount/netCashFlow (CashFlowTotalsResponseDto).
    // Thiếu 2 key đầu là lý do "Vào 0đ / Ra 0đ" mà Net vẫn có số — sai tên field
    // thì không có lỗi nào báo, chỉ hiện 0.
    final income = _moneyFrom(totals, [
      'incomeAmount',
      'income',
      'totalIncome',
      'inflow',
    ]);
    final expense = _moneyFrom(totals, [
      'expenseAmount',
      'expense',
      'totalExpense',
      'outflow',
    ]);
    final net = _moneyFrom(totals, [
      'netCashFlow',
      'netIncludingAdjustments',
      'net',
      'balance',
    ]);
    return _sectionCard(
      title: 'Dòng tiền vào - ra',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _miniMetric('Vào', income, AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Ra', expense, AppColors.danger)),
              const SizedBox(width: 8),
              Expanded(child: _miniMetric('Net', net, AppColors.link)),
            ],
          ),
          const SizedBox(height: 12),
          if (byMonth.isEmpty)
            _emptyFinanceText('Chưa có dữ liệu dòng tiền trong kỳ này.')
          else
            ...byMonth.take(4).map((item) {
              final label =
                  item['month']?.toString() ??
                  item['period']?.toString() ??
                  'Kỳ';
              final monthIn = _moneyFrom(item, [
                'incomeAmount',
                'income',
                'totalIncome',
                'inflow',
              ]);
              final monthOut = _moneyFrom(item, [
                'expenseAmount',
                'expense',
                'totalExpense',
                'outflow',
              ]);
              final maxValue = [
                monthIn.abs(),
                monthOut.abs(),
                1.0,
              ].reduce((a, b) => a > b ? a : b);
              return _cashFlowRow(label, monthIn, monthOut, maxValue);
            }),
        ],
      ),
    );
  }

  Widget _categorySpendingCard(WalletProvider state) {
    final data = state.categorySpendingSummary ?? const <String, dynamic>{};
    final totalExpense = _number(data['totalExpense']);
    final items = _firstList(data, [
      'byCategory',
      'categories',
      'items',
      'data',
    ]);
    return _sectionCard(
      title: 'Chi tiêu theo danh mục',
      child: items.isEmpty
          ? _emptyFinanceText('Chưa có chi tiêu theo danh mục trong kỳ này.')
          : Column(
              children: items.take(5).map((item) {
                final name =
                    item['categoryName']?.toString() ??
                    item['name']?.toString() ??
                    item['category']?.toString() ??
                    'Danh mục';
                final amount = _moneyFrom(item, [
                  'amount',
                  'totalAmount',
                  'expense',
                ]);
                final ratioValue = item['ratio'] ?? item['percentage'];
                final ratio = ratioValue == null && totalExpense > 0
                    ? amount / totalExpense
                    : _number(ratioValue);
                return _rankRow(name, amount, ratio, AppColors.danger);
              }).toList(),
            ),
    );
  }

  Widget _memberContributionCard(WalletProvider state) {
    final data = state.memberContributionSummary ?? const <String, dynamic>{};
    final totals = _asMap(data['totals']);
    final totalContribution = _number(totals['totalContribution']);
    final members = _firstList(data, ['members', 'items', 'data']);
    return _sectionCard(
      title: 'Đóng góp theo thành viên',
      child: members.isEmpty
          ? _emptyFinanceText('Chưa có dữ liệu đóng góp thành viên.')
          : Column(
              children: members.take(5).map((item) {
                // API thật để tên trong member.displayName / member.user.fullName
                // (MemberContributionSummaryItemResponseDto), không phải cấp
                // ngoài — đọc sai chỗ nên mọi dòng đều rơi về 'Thành viên'.
                final member = _asMap(item['member']);
                final user = _asMap(member['user']);
                final name =
                    _firstText(member, ['displayName', 'name', 'fullName']) ??
                    _firstText(user, ['fullName', 'displayName', 'name']) ??
                    _firstText(item, ['memberName', 'displayName', 'name']) ??
                    'Thành viên';
                final amount = _moneyFrom(item, [
                  'totalContribution',
                  'amount',
                  'actualAmount',
                  'ledgerActualAmount',
                ]);
                final ratioValue = item['ratio'] ?? item['percentage'];
                final ratio = ratioValue == null && totalContribution > 0
                    ? amount / totalContribution
                    : _number(ratioValue);
                return _rankRow(name, amount, ratio, AppColors.success);
              }).toList(),
            ),
    );
  }

  List<Widget> _buildHistory(WalletProvider state) {
    if (state.transactions.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Chưa có giao dịch nào',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }
    return [
      _sectionCard(
        title: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...state.transactions.map((tx) {
              final signed = tx.signedAmount;
              final isPos = signed >= 0;
              final isAllocation = tx.isFundAllocationAudit;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openLedgerEntry(context, tx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neutralBg,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isAllocation
                              ? Icons.account_balance_wallet_outlined
                              : isPos
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 18,
                          color: isAllocation
                              ? AppColors.link
                              : isPos
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              tx.displayEntryDate,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isAllocation
                            ? '${_fmt(tx.amount.round())} · Phân bổ'
                            : '${isPos ? '+' : ''}${_fmt(signed.abs().round())}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isAllocation
                              ? AppColors.link
                              : isPos
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (state.hasMoreEntries) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: state.isLoadingMoreEntries
                      ? null
                      : () => context.read<WalletProvider>().fetchMoreEntries(),
                  child: state.isLoadingMoreEntries
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tải thêm'),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _openLedgerEntry(BuildContext context, LedgerEntry entry) async {
    try {
      final detail = await context.read<WalletProvider>().fetchEntryDetail(
        entry.id,
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          final editable =
              detail.entryType == 'INCOME' || detail.entryType == 'EXPENSE';
          final signed = detail.signedAmount;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi tiết giao dịch',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ledgerDetailRow(
                    'Loại',
                    detail.isFundAllocationAudit
                        ? 'Phân bổ nội bộ vào hũ'
                        : signed >= 0
                        ? 'Khoản thu'
                        : 'Khoản chi',
                  ),
                  _ledgerDetailRow(
                    'Số tiền',
                    '${_fmt(detail.amount.round())} đ',
                  ),
                  _ledgerDetailRow(
                    'Danh mục',
                    detail.categoryName ?? 'Chưa phân loại',
                  ),
                  _ledgerDetailRow('Thời gian', detail.displayEntryDate),
                  _ledgerDetailRow(
                    'Mô tả',
                    detail.description.isEmpty ? '—' : detail.description,
                  ),
                  if ((detail.note ?? '').isNotEmpty)
                    _ledgerDetailRow('Ghi chú', detail.note!),
                  if (editable) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showEditLedgerSheet(context, detail);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            onPressed: () async {
                              final approved = await _confirmVoidEntry(context);
                              if (!approved || !context.mounted) return;
                              try {
                                await context.read<WalletProvider>().voidEntry(
                                  detail.id,
                                );
                                if (mounted) {
                                  await _loadJarTargetActualReport();
                                }
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showFinanceError(context, e);
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hủy giao dịch'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Giao dịch được tạo từ flow hệ thống nên không sửa trực tiếp ở sổ thu chi.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        _showFinanceError(context, e);
      }
    }
  }

  Widget _ledgerDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<bool> _confirmVoidEntry(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hủy giao dịch?'),
            content: const Text(
              'Giao dịch sẽ bị hủy và không còn được tính vào số liệu tài chính.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Không'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hủy giao dịch'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditLedgerSheet(BuildContext context, LedgerEntry entry) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        entry.amount.round().toString(),
      ),
    );
    final descriptionCtrl = TextEditingController(text: entry.description);
    final noteCtrl = TextEditingController(text: entry.note ?? '');
    final categories = context
        .read<FinanceProvider>()
        .categories
        .where(
          (category) =>
              category.categoryType == entry.entryType && category.isActive,
        )
        .toList();
    String? categoryId = entry.categoryId;
    if (categoryId == null ||
        !categories.any((category) => category.id == categoryId)) {
      categoryId = categories.isNotEmpty ? categories.first.id : null;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chỉnh sửa giao dịch',
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Số tiền (đ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => categoryId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = parseMoneyInput(amountCtrl.text);
                    final description = descriptionCtrl.text.trim();
                    if (amount <= 0 || description.isEmpty) {
                      _showFinanceError(
                        sheetContext,
                        'Nhập số tiền lớn hơn 0 và mô tả giao dịch.',
                      );
                      return;
                    }
                    try {
                      await context.read<WalletProvider>().updateEntry(
                        entry.id,
                        amount: amount,
                        description: description,
                        categoryId: categoryId,
                        // Không truyền jarId: hũ do BE map theo category, sửa
                        // giao dịch không được làm mất liên kết hũ đang có.
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      if (mounted) await _loadJarTargetActualReport();
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    } catch (e) {
                      if (sheetContext.mounted) {
                        _showFinanceError(sheetContext, e);
                      }
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFinanceError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showCategoryManagerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final categories = sheetContext.watch<FinanceProvider>().categories;
        final orderedCategories = [...categories]
          ..sort((a, b) {
            if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Danh mục thu chi',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tạo danh mục',
                        onPressed: () =>
                            _showCreateCategoryDialog(sheetContext),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngưng dùng chỉ ẩn danh mục khỏi các form mới; lịch sử giao dịch và ngân sách vẫn được giữ.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: orderedCategories.isEmpty
                        ? const Center(child: Text('Chưa có danh mục nào'))
                        : ListView.separated(
                            itemCount: orderedCategories.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final category = orderedCategories[index];
                              final isIncome =
                                  category.categoryType == 'INCOME';
                              final essentialLabel =
                                  category.essentialType == 'ESSENTIAL'
                                  ? 'Thiết yếu'
                                  : 'Không thiết yếu';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isIncome
                                      ? AppColors.safeLight
                                      : AppColors.dangerLight,
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isIncome
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                                title: Text(category.name),
                                subtitle: Text(
                                  isIncome
                                      ? 'Khoản thu · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}'
                                      : category.essentialType == null
                                      ? 'Khoản chi · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}'
                                      : 'Khoản chi · $essentialLabel · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      _showEditCategoryDialog(
                                        sheetContext,
                                        category,
                                      );
                                      return;
                                    }
                                    final approved =
                                        await _confirmDeactivateCategory(
                                          sheetContext,
                                          category.name,
                                        );
                                    if (!approved || !sheetContext.mounted) {
                                      return;
                                    }
                                    try {
                                      await sheetContext
                                          .read<FinanceProvider>()
                                          .deactivateCategory(category.id);
                                    } catch (e) {
                                      if (sheetContext.mounted) {
                                        _showFinanceError(sheetContext, e);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Đổi tên'),
                                    ),
                                    PopupMenuItem(
                                      value: 'deactivate',
                                      child: Text('Ngưng dùng'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeactivateCategory(
    BuildContext context,
    String name,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ngưng dùng danh mục?'),
            content: Text(
              'Danh mục “$name” sẽ không thể chọn cho giao dịch hoặc kế hoạch mới.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Không'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Ngưng dùng'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditCategoryDialog(BuildContext context, FinanceCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await context.read<FinanceProvider>().updateCategory(
                  category.id,
                  name: name,
                  essentialType: category.essentialType,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) _showFinanceError(dialogContext, e);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    var categoryType = 'EXPENSE';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Tạo danh mục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryType,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: const [
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Khoản chi')),
                  DropdownMenuItem(value: 'INCOME', child: Text('Khoản thu')),
                ],
                onChanged: (value) =>
                    setDialogState(() => categoryType = value ?? 'EXPENSE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await context.read<FinanceProvider>().createCategory(
                    name: name,
                    categoryType: categoryType,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    _showFinanceError(dialogContext, e);
                  }
                }
              },
              child: const Text('Tạo danh mục'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRequests(BuildContext context) {
    final provider = context.watch<SupportRequestProvider>();
    final pending = provider.requests
        .where((request) => request.isPending)
        .toList();
    if (pending.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Không có yêu cầu chờ duyệt',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: provider.loading
                ? null
                : () => context.read<SupportRequestProvider>().fetchRequests(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(provider.loading ? 'Đang tải…' : 'Tải lại'),
          ),
        ),
      ];
    }
    return pending
        .map(
          (req) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.link.withValues(alpha: .14),
                  child: Text(
                    _requesterName(context, req).substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppColors.link,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_requesterName(context, req)} · ${_fmt(req.amount.round())}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        req.purpose,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          await provider.review(
                            requestId: req.id,
                            decision: 'APPROVE',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã duyệt ${_fmt(req.amount.round())} cho ${_requesterName(context, req)}',
                              ),
                              backgroundColor: AppColors.safe,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          _showFinanceError(context, e);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.safeLight,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await provider.review(
                            requestId: req.id,
                            decision: 'REJECT',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã từ chối yêu cầu của ${_requesterName(context, req)}',
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          _showFinanceError(context, e);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  void _showRecordSheet(BuildContext context, {required bool isIncome}) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? categoryId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final categories = ctx
              .watch<FinanceProvider>()
              .categories
              .where(
                (category) =>
                    category.categoryType ==
                        (isIncome ? 'INCOME' : 'EXPENSE') &&
                    category.isActive,
              )
              .toList();
          if (categoryId == null ||
              !categories.any((c) => c.id == categoryId)) {
            categoryId = categories.isNotEmpty ? categories.first.id : null;
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              28,
              28,
              MediaQuery.of(ctx).viewInsets.bottom + 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIncome
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      size: 24,
                      color: isIncome ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isIncome ? 'Ghi nhận Thu' : 'Ghi nhận Chi',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Số tiền (₫)',
                    hintText: 'VD: 500.000',
                    suffixText: '₫',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (categories.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: InputDecoration(
                      labelText: 'Danh mục',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheet(() => categoryId = value),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Trước đây ô danh mục bị ẩn hẳn khi gia đình chưa có danh
                  // mục nào → giao dịch tạo ra luôn có categoryId = null và báo
                  // cáo dồn hết vào "Chưa phân loại" mà user không hiểu vì sao.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Gia đình chưa có danh mục nào nên giao dịch sẽ bị xếp vào '
                      '"Chưa phân loại". Tạo danh mục để xem được báo cáo chi '
                      'tiêu theo danh mục.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showCategoryManagerSheet(context),
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: Text(
                      categories.isEmpty ? 'Tạo danh mục' : 'Quản lý danh mục',
                    ),
                  ),
                ),
                if (!isIncome) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.link.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      categoryId == null
                          ? 'Chưa chọn danh mục nên Backend không thể tự gán hũ.'
                          : 'Hũ sẽ được Backend tự gán theo danh mục và mô hình '
                                'tài chính đang áp dụng.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mô tả',
                    hintText: isIncome ? 'VD: Lương tháng 6' : 'VD: Tiền chợ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncome
                          ? AppColors.success
                          : AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final amount = parseMoneyInput(amountCtrl.text);
                      if (amount <= 0) return;
                      final desc = descCtrl.text.trim().isNotEmpty
                          ? descCtrl.text.trim()
                          : (isIncome ? 'Thu nhập' : 'Chi tiêu');
                      try {
                        await context.read<WalletProvider>().recordEntry(
                          amount: amount,
                          description: desc,
                          isIncome: isIncome,
                          categoryId: categoryId,
                        );
                        if (mounted) await _loadJarTargetActualReport();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      isIncome ? 'Lưu khoản Thu' : 'Lưu khoản Chi',
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
          );
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _sectionCard({required String title, required Widget child}) =>
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            child,
          ],
        ),
      );

  Widget _metricPill(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _miniMetric(String label, double amount, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _fmt(amount.round()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _cashFlowRow(String label, double income, double expense, double max) {
    final incomeFlex = ((income.abs() / max) * 100).round().clamp(1, 99);
    final expenseFlex = ((expense.abs() / max) * 100).round().clamp(1, 99);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Row(
                    children: [
                      Flexible(
                        flex: incomeFlex,
                        child: Container(height: 8, color: AppColors.success),
                      ),
                      Flexible(
                        flex: 100 - incomeFlex,
                        child: Container(
                          height: 8,
                          color: AppColors.progressTrack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Row(
                    children: [
                      Flexible(
                        flex: expenseFlex,
                        child: Container(height: 8, color: AppColors.danger),
                      ),
                      Flexible(
                        flex: 100 - expenseFlex,
                        child: Container(
                          height: 8,
                          color: AppColors.progressTrack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankRow(String label, double amount, double ratio, Color color) {
    final progress = ratio > 0 ? (ratio / 100).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _fmt(amount.round()),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.progressTrack,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFinanceText(String message) => Text(
    message,
    style: GoogleFonts.inter(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textMuted,
    ),
  );

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _firstList(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    for (final key in keys) {
      final list = _asList(root[key]);
      if (list.isNotEmpty) return list;
    }
    return const <Map<String, dynamic>>[];
  }

  /// Lối vào phân bổ số dư quỹ tháng vào mục tiêu tài chính.
  ///
  /// Chỉ Manager/Deputy (`canManageFinance`) — BE trả 403 với thành viên thường.
  /// Không có mục tiêu ACTIVE thì ẩn hẳn card: mở sheet ra cũng không chọn được
  /// gì để phân bổ.
  List<Widget> _surplusAllocationCard(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user?.canManageFinance != true) return const [];
    final goals = context.watch<FinanceProvider>().contributableGoals;
    if (goals.isEmpty) return const [];

    return [
      _sectionCard(
        title: 'Số dư quỹ tháng',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chuyển phần quỹ còn lại của tháng vào một mục tiêu tài chính. '
              'Đây là phân bổ nội bộ, không tính là khoản thu mới.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.savings_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Phân bổ số dư vào mục tiêu',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => _showSurplusGoalPicker(context, goals),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Giải thích cơ chế kỳ ngay trong app. Câu "qua tháng mới số dư tháng cũ đi
  /// đâu" là câu hỏi đầu tiên người dùng gặp mỗi ngày mùng 1 — trả lời tại chỗ
  /// rẻ hơn nhiều so với để họ đi hỏi Trưởng nhóm.
  void _showPeriodExplainerSheet(BuildContext context, FinancePeriod period) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiền của tháng trước đi đâu?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sheetCtx.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _explainerLine(
                sheetCtx,
                '1',
                'Số liệu trên màn này tính theo kỳ bạn đang chọn '
                    '(${period.label.toLowerCase()}). Sang tháng mới, các số về 0 '
                    'vì kỳ mới chưa có giao dịch — không phải tiền biến mất.',
              ),
              _explainerLine(
                sheetCtx,
                '2',
                'Muốn xem lại kỳ cũ: dùng thanh chuyển tháng ở đầu màn hình. '
                    'Toàn bộ giao dịch, báo cáo và hạn mức của kỳ đó vẫn còn nguyên.',
              ),
              _explainerLine(
                sheetCtx,
                '3',
                'Phần quỹ tháng trước chưa tiêu hết nằm ở mục "Kết chuyển" — '
                    'nó vẫn thuộc quỹ chung cho tới khi được chuyển vào một mục '
                    'tiêu tài chính.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _explainerLine(BuildContext context, String index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card "Kết chuyển tháng trước" — trả lời thẳng câu "số dư tháng cũ đi đâu".
  ///
  /// Cố ý **không** giới hạn theo ngày đầu tháng: số dư chưa phân bổ là một sự
  /// thật đứng yên, BE chưa xác nhận có job tự chốt kỳ nào (xem
  /// `PHAN_TICH_CHUYEN_THANG_TAI_CHINH_2026-08-02.md` mục 5.4). Ẩn card sau ngày
  /// 10 sẽ dựng lại đúng cái bẫy "tiền biến mất" mà nó sinh ra để xử lý.
  List<Widget> _carryOverCard(BuildContext context, WalletProvider state) {
    if (context.watch<AuthProvider>().user?.canManageFinance != true) {
      return const [];
    }
    final carry = _carrySurplus;
    if (_carrySurplusLoading || carry == null || carry.availableSurplus <= 0) {
      return const [];
    }
    final previous = state.period.previous;
    // Không có mục tiêu ACTIVE thì phân bổ đi đâu — vẫn báo số dư nhưng không
    // dựng nút dẫn vào một danh sách rỗng.
    final goals = context.watch<FinanceProvider>().contributableGoals;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.amberLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.savings_outlined,
                  size: 18,
                  color: AppColors.amberDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kết chuyển ${previous.label.toLowerCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amberDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_fmt(carry.availableSurplus.round())} chưa phân bổ',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              carry.allocatedSurplus > 0
                  ? 'Tổng dư ${_fmt(carry.totalSurplus.round())}, đã phân bổ '
                        '${_fmt(carry.allocatedSurplus.round())}. Phần còn lại '
                        'vẫn nằm trong quỹ chung cho tới khi bạn chuyển đi.'
                  : 'Số dư này vẫn nằm trong quỹ chung, chưa mất đi đâu. '
                        'Chuyển vào một mục tiêu để tiền có đích đến rõ ràng.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: AppColors.amberDark,
              ),
            ),
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amberText,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Phân bổ số dư ${previous.shortLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () =>
                      _showSurplusGoalPicker(context, goals, period: previous),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                // Danh sách rỗng giờ chỉ còn nghĩa: mọi mục tiêu đã hoàn thành
                // hoặc đã huỷ. Mục tiêu AT_RISK vẫn nhận góp nên không rơi vào
                // nhánh này nữa.
                'Chưa có mục tiêu nào nhận được số dư này — mọi mục tiêu đều '
                'đã hoàn thành hoặc đã huỷ. Tạo mục tiêu mới ở mục "Mục tiêu '
                'tiết kiệm".',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Thẻ "đang có N cảnh báo tài chính" ngay trên màn Ví.
  ///
  /// Không có thẻ này thì cảnh báo chỉ tồn tại ở màn Hồ sơ → Cảnh báo tài chính
  /// — chỗ không ai nghĩ tới lúc đang xem tiền. Chỉ hiện khi thật sự có cảnh
  /// báo chưa xem, để không thêm nhiễu vào màn vốn đã dày.
  List<Widget> _financeAlertCard(BuildContext context) {
    final count = context.watch<FinanceAlertProvider>().newCount;
    if (count <= 0) return const [];
    return [
      InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/manager/finance-alerts'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notification_important_rounded,
                size: 20,
                color: AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count cảnh báo tài chính chưa xem',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vượt ngân sách hoặc mục tiêu có nguy cơ không đạt.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Không còn mục tiêu nào nhận được số dư → hỏi có tạo mục tiêu mới không.
  ///
  /// Thà mở một hộp thoại còn hơn để cú chạm rơi vào hư không: số dư kết chuyển
  /// là tiền thật đang không có đích đến, im lặng ở đây là bỏ mặc người dùng.
  void _promptCreateGoalForSurplus(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa có mục tiêu để nhận số dư'),
        content: const Text(
          'Mọi mục tiêu tiết kiệm đều đã hoàn thành hoặc đã huỷ, nên số dư này '
          'chưa có chỗ để chuyển vào.\n\n'
          'Tạo một mục tiêu mới rồi quay lại đây nhé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/manager/financial-goals');
            },
            child: const Text('Tạo mục tiêu'),
          ),
        ],
      ),
    );
  }

  /// Chọn mục tiêu rồi mở màn chi tiết với `surplus=1` — sheet nhập số tiền và
  /// kiểm tra số dư khả dụng đã có sẵn ở đó, không nhân bản lại logic.
  ///
  /// [period] null = sheet mở ở tháng hiện tại (lối vào cũ). Card "Kết chuyển"
  /// truyền kỳ cũ vào để không bắt người dùng tự dò lại tháng.
  void _showSurplusGoalPicker(
    BuildContext context,
    List<FinancialGoal> goals, {
    FinancePeriod? period,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              'Chọn mục tiêu nhận số dư',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: goals.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.colors.divider),
                itemBuilder: (_, i) {
                  final goal = goals[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.link,
                    ),
                    title: Text(
                      goal.goalName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Mục tiêu ${_fmt(goal.targetAmount.round())} đ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      final periodQuery = period == null
                          ? ''
                          : '&period=${period.year}-${period.month}';
                      context
                          .push(
                            '/manager/goal-detail'
                            '?goalId=${goal.id}&surplus=1$periodQuery',
                          )
                          // Phân bổ xong thì số dư kỳ đó đã đổi — nạp lại để
                          // card "Kết chuyển" không hiện số cũ.
                          .then((_) {
                            if (mounted) _loadCarrySurplus();
                          });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tên người gửi yêu cầu xin tiền: tên BE trả → tra theo `requesterMemberId`
  /// trong danh sách thành viên → cuối cùng mới 'Thành viên'.
  ///
  /// Duyệt tiền mà không biết duyệt cho ai là không chấp nhận được, nên phải thử
  /// hết các đường trước khi bỏ cuộc.
  String _requesterName(BuildContext context, SupportRequest req) {
    final direct = req.requesterName.trim();
    if (direct.isNotEmpty) return direct;

    final id = req.requesterMemberId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final m in context.read<FamilyProvider>().members) {
        if (m.id == id || m.userId == id) {
          final name = m.name.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return 'Thành viên';
  }

  /// Màu cho hũ thứ [index] — xoay vòng nên số hũ bất kỳ vẫn có màu.
  Color _jarColor(int index) {
    const palette = [
      AppColors.shared,
      AppColors.income,
      AppColors.link,
      AppColors.accent500,
      AppColors.safe,
      AppColors.heroPurple,
    ];
    return palette[index % palette.length];
  }

  /// 1 dòng hũ: tên + % , số thực chi trên số kế hoạch, thanh tiến độ. Vượt kế
  /// hoạch thì đổi sang màu cảnh báo để nhìn ra ngay hũ nào đang quá tay.
  /// Tỷ trọng THỰC TẾ của một hũ trong tổng chi, đúng công thức BE
  /// (`actualPercentage = actualAmount / trackedAmount * 100`).
  int _actualPct(_JarOverviewRow row, double trackedAmount) =>
      trackedAmount > 0 ? (row.actual / trackedAmount * 100).round() : 0;

  Widget _jarRow(_JarOverviewRow row, Color color, {double trackedAmount = 0}) {
    final over = row.isOverBudget;
    final ratio = row.target > 0
        ? (row.actual / row.target).clamp(0.0, 1.0)
        : (row.actual > 0 ? 1.0 : 0.0);
    // Tỷ trọng thực tế của hũ này trong tổng chi — đúng công thức BE:
    // actualPercentage = actualAmount / trackedAmount.
    final ratioActual = trackedAmount > 0 ? row.actual / trackedAmount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.pct > 0 ? '${row.name} · ${row.pct.round()}%' : row.name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Tỷ lệ thực tế mới là con số đáng so với mô hình. Hai số tiền
              // cùng tăng mỗi lần chi thêm (vì mẫu số là tổng chi) nên nhìn
              // vào chúng không kết luận được gì — xem giải thích ở phần đầu
              // mục "Tỷ trọng chi tiêu theo hũ".
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (row.pct > 0)
                    Text(
                      // Hũ tích luỹ vượt mô hình thì tô XANH: tiết kiệm nhiều
                      // hơn dự định là chuyện tốt, không phải cảnh báo.
                      '${(ratioActual * 100).round()}% thực tế'
                      '${row.deltaLabel == null ? '' : ' · ${row.deltaLabel}'}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: over
                            ? AppColors.danger
                            : (row.isAboveTarget && row.isSavingLike
                                  ? AppColors.safe
                                  : AppColors.textPrimary),
                      ),
                    ),
                  Text(
                    row.target > 0
                        ? '${_fmt(row.actual.round())} / ${_fmt(row.target.round())}'
                        : _fmt(row.actual.round()),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              valueColor: AlwaysStoppedAnimation(
                over ? AppColors.danger : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lấy text đầu tiên không rỗng theo danh sách key; null nếu không có key nào
  /// có giá trị dùng được (để caller tự quyết fallback).
  String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final text = map[key]?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  double _moneyFrom(
    Map<String, dynamic> map,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return _number(value);
    }
    return fallback;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _barLegend(String label, Color color, String val) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(left: 12, top: 2),
        child: Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );

  Widget _waffleLegend(String label, Color color, String amount, String pct) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                pct,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _alertBar(int remaining, int bufferPct) {
    final IconData icon;
    final Color bg, tc, sc;
    final String title, sub;
    if (bufferPct < 10) {
      icon = Icons.error_outline_rounded;
      bg = AppColors.dangerLight;
      tc = AppColors.dangerDark;
      sc = AppColors.danger;
      title = 'Cảnh báo ngân sách';
      sub = 'Chỉ còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else if (bufferPct < 30) {
      icon = Icons.warning_amber_rounded;
      bg = AppColors.amberLight;
      tc = AppColors.amberDark;
      sc = AppColors.amberText;
      title = 'Thu gần Chi';
      sub = 'Còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else {
      icon = Icons.check_circle_outline_rounded;
      bg = AppColors.safeLight;
      tc = AppColors.safeDark;
      sc = AppColors.safe;
      title = 'Dư ${_fmt(remaining)} — Tháng tốt!';
      sub = 'Còn $bufferPct% dự phòng';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tc),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tc,
                  ),
                ),
                Text(sub, style: GoogleFonts.inter(fontSize: 11, color: sc)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBtn(IconData icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Icon(icon, size: 18, color: Colors.white),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _tabItem(int index, String label, {int badge = 0}) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = index);
          // Yêu cầu mới do thành viên gửi sau khi màn này đã mở sẽ không tự
          // xuất hiện (trước đây chỉ fetch 1 lần trong initState) → nạp lại mỗi
          // lần mở tab Yêu cầu.
          if (index == 2) {
            context.read<SupportRequestProvider>().fetchRequests();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.link : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext ctx) => GestureDetector(
    // Màn này là branch root của shell khi mở từ thanh tab → không có gì để
    // pop, bấm back sẽ không làm gì. Không pop được thì về home theo role.
    onTap: () {
      if (ctx.canPop()) {
        ctx.pop();
        return;
      }
      final role = ctx.read<AuthProvider>().user?.role;
      ctx.go(switch (role) {
        UserRole.manager => '/manager/home',
        UserRole.deputy => '/deputy/home',
        _ => '/member/home',
      });
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: AppColors.textPrimary,
      ),
    ),
  );
}
