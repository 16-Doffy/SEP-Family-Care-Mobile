import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../theme/app_ui_tokens.dart';
import '../../utils/jar_allocation.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/retry_state.dart';
import '../../widgets/waffle_chart.dart';
import '../../widgets/money_input.dart';

String _fmt(int n) =>
    '${n.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ₫';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWallets();
      context.read<SupportRequestProvider>().fetchRequests();
      context.read<FinanceProvider>().fetchAll();
      // Cần để tra tên người gửi yêu cầu khi BE chỉ trả requesterMemberId.
      final family = context.read<FamilyProvider>();
      if (family.members.isEmpty) family.fetchMembers();
    });
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
          Text(
            'Tổng quỹ gia đình',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
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
            'Tháng này +${_fmt(totalIn.round())} / -${_fmt(totalOut.round())}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 18),
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
          ),
        ],
      ),
    );
  }

  /// Một dòng phân bổ theo hũ của mô hình tài chính đang áp dụng.
  ///
  /// `target` = thu nhập × tỷ lệ hũ (kế hoạch), `actual` = tổng chi thực tế của
  /// các ledger entry có `jarId` này. BE chưa trả `byJar` trong finance/summary
  /// (Swagger ghi "Reserved") nên phần thực tế do FE tự cộng từ giao dịch.
  ({JarAllocation allocation, String? note}) _jarBreakdown(
    BuildContext context,
    WalletProvider state,
    double income,
  ) {
    const empty = JarAllocation(rows: [], unassigned: 0);
    final finance = context.watch<FinanceProvider>();
    final model = finance.activeModel;

    // activeModel fallback về model đầu tiên kể cả DRAFT → chỉ coi là đang áp
    // dụng khi status thật là ACTIVE, không thì nói rõ cho user.
    if (model == null || !model.isActive) {
      return (
        allocation: empty,
        note: model == null
            ? 'Gia đình chưa có mô hình tài chính. Tạo mô hình để xem phân bổ theo hũ.'
            : 'Mô hình "${model.name}" chưa được kích hoạt nên chưa có phân bổ theo hũ.',
      );
    }

    // GET /finance/jars trả hũ của MỌI mô hình cho quản lý → phải lọc theo
    // đúng mô hình đang áp dụng, không thì cộng lẫn hũ của mô hình cũ.
    final jars = finance.jars
        .where((j) => j.isActive && j.financeModelId == model.id)
        .toList();
    if (jars.isEmpty) {
      return (
        allocation: empty,
        note: 'Mô hình "${model.name}" chưa có hũ nào đang hoạt động.',
      );
    }

    return (
      allocation: computeJarAllocation(
        jars: jars,
        entries: state.transactions,
        income: income,
      ),
      note: null,
    );
  }

  List<Widget> _buildOverview(BuildContext context, WalletProvider state) {
    final income = state.monthlyIncome;
    final expense = state.monthlyExpense;
    final remaining = income - expense;
    final jarInfo = _jarBreakdown(context, state, income);
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
      _sectionCard(
        title: 'Ngân sách tháng này',
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
            if (jarInfo.allocation.rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.progressTrack),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hạn mức theo tỷ lệ thu nhập — thực chi',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Số bên phải được tính từ tổng thu nhập tháng, không phải số tiền của lần chia quỹ vừa thực hiện.',
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
              ...jarInfo.allocation.rows.asMap().entries.map(
                (e) => _jarRow(e.value, _jarColor(e.key)),
              ),
              // Hiện phần chi không gán hũ để tổng khớp với tổng chi tiêu.
              if (jarInfo.allocation.unassigned > 0)
                _jarRow(
                  JarAllocationRow(
                    jarId: '',
                    name: 'Chưa gán hũ',
                    pct: 0,
                    target: 0,
                    actual: jarInfo.allocation.unassigned,
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
        title: jarInfo.allocation.rows.isEmpty
            ? 'Phân bổ thu nhập'
            : 'Phân bổ thu nhập theo mô hình',
        child: jarInfo.allocation.rows.isEmpty
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
                  WaffleChart(
                    segments: jarInfo.allocation.rows
                        .asMap()
                        .entries
                        .map(
                          (e) => WaffleSegment(
                            color: _jarColor(e.key),
                            pct: e.value.pct.round().clamp(0, 100),
                            label: e.value.name,
                            amount: e.value.target.round(),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e
                            in jarInfo.allocation.rows.asMap().entries) ...[
                          _waffleLegend(
                            e.value.name,
                            _jarColor(e.key),
                            _fmt(e.value.target.round()),
                            '${e.value.pct.round()}%',
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          'Kế hoạch tính trên thu nhập ${_fmt(income.round())}',
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
    final activeJars = _activeFinanceJars(context.read<FinanceProvider>());
    final categories = context
        .read<FinanceProvider>()
        .categories
        .where(
          (category) =>
              category.categoryType == entry.entryType && category.isActive,
        )
        .toList();
    String? categoryId = entry.categoryId;
    String selectedJarId = entry.jarId ?? '';
    if (!activeJars.any((jar) => jar.id == selectedJarId)) {
      selectedJarId = '';
    }
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
              if (entry.entryType == 'EXPENSE' && activeJars.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: selectedJarId,
                  decoration: const InputDecoration(
                    labelText: 'Hũ chi tiêu',
                    helperText:
                        'Giao dịch sẽ được tính vào thực chi của hũ đã chọn.',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Chưa gắn hũ'),
                    ),
                    ...activeJars.map(
                      (jar) => DropdownMenuItem(
                        value: jar.id,
                        child: Text(_financeJarLabel(jar)),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => selectedJarId = value ?? ''),
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
                        jarId:
                            entry.entryType == 'EXPENSE' &&
                                selectedJarId.isNotEmpty
                            ? selectedJarId
                            : null,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
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
                          // Contract mới: gửi categoryId, không gửi jarId để
                          // BE auto-map theo model ACTIVE.
                          jarId: null,
                        );
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

  List<FinanceJar> _activeFinanceJars(FinanceProvider finance) {
    FinanceModel? activeModel;
    for (final model in finance.models) {
      if (model.isActive) {
        activeModel = model;
        break;
      }
    }
    if (activeModel == null) return const [];

    final jarsById = <String, FinanceJar>{};
    for (final jar in activeModel.jars) {
      if (jar.isActive && jar.id.isNotEmpty) jarsById[jar.id] = jar;
    }
    for (final jar in finance.jars) {
      if (jar.isActive &&
          jar.id.isNotEmpty &&
          jar.financeModelId == activeModel.id) {
        jarsById[jar.id] = jar;
      }
    }
    final jars = jarsById.values.toList()
      ..sort(
        (a, b) => b.allocationPercentage.compareTo(a.allocationPercentage),
      );
    return jars;
  }

  String _financeJarLabel(FinanceJar jar) {
    final localizedName = switch (jar.jarCode.toUpperCase()) {
      'NECESSITIES' => 'Nhu cầu thiết yếu',
      'SAVINGS' => 'Tiết kiệm',
      'EDUCATION' => 'Giáo dục',
      'ENJOYMENT' => 'Vui chơi',
      'GIVING' => 'Cho đi / Biếu tặng',
      _ => jar.name,
    };
    final percentage = jar.allocationPercentage.toStringAsFixed(
      jar.allocationPercentage % 1 == 0 ? 0 : 1,
    );
    return '$localizedName · $percentage%';
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
    final goals = context.watch<FinanceProvider>().activeGoals;
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

  /// Chọn mục tiêu rồi mở màn chi tiết với `surplus=1` — sheet nhập số tiền và
  /// kiểm tra số dư khả dụng đã có sẵn ở đó, không nhân bản lại logic.
  void _showSurplusGoalPicker(
    BuildContext context,
    List<FinancialGoal> goals,
  ) {
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
                      context.push(
                        '/manager/goal-detail?goalId=${goal.id}&surplus=1',
                      );
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
  Widget _jarRow(JarAllocationRow row, Color color) {
    final over = row.isOverBudget;
    final ratio = row.target > 0
        ? (row.actual / row.target).clamp(0.0, 1.0)
        : (row.actual > 0 ? 1.0 : 0.0);
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
              Text(
                row.target > 0
                    ? '${_fmt(row.actual.round())} / ${_fmt(row.target.round())}'
                    : _fmt(row.actual.round()),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: over ? AppColors.danger : AppColors.textSecondary,
                ),
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
