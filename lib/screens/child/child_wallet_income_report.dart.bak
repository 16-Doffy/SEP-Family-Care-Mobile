import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/money_input.dart';
import '../../widgets/ring_chart.dart';

class ChildWalletScreen extends StatefulWidget {
  const ChildWalletScreen({super.key});
  @override
  State<ChildWalletScreen> createState() => _ChildWalletScreenState();
}

class _ChildWalletScreenState extends State<ChildWalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ring;

  // Dữ liệu từ API monthly-finances/me (model khai-báo-tháng của thành viên;
  // KHÔNG có ví/số dư cá nhân — by design).
  double? _income; // expectedIncome — thu nhập tháng
  double? _allowance; // expectedPersonalExpense — chi tiêu dự đoán
  double? _actualSpent; // actualPersonalExpense (nếu BE trả về)
  bool _loadingFinance = false;
  String? _financeError;

  bool get _hasDeclared => _income != null || _allowance != null;

  // Lịch sử 6 tháng — không có API "list nhiều tháng" nên query từng tháng.
  List<_MonthPoint> _history = const [];
  bool _loadingHistory = false;

  // AuthProvider listener — fix StatefulShellRoute pre-build
  AuthProvider? _authListener;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ring = Tween<double>(begin: 0, end: 0).animate(_ctrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authListener = context.read<AuthProvider>()..addListener(_onAuthChanged);
      if (context.read<AuthProvider>().hasFamily) {
        _fetchMonthlyFinance();
        _fetchHistory();
      }
    });
  }

  void _onAuthChanged() {
    if (mounted && context.read<AuthProvider>().hasFamily) {
      _fetchMonthlyFinance();
      _fetchHistory();
    }
  }

  @override
  void dispose() {
    _authListener?.removeListener(_onAuthChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthlyFinance() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    setState(() {
      _loadingFinance = true;
      _financeError = null;
    });

    try {
      final now = DateTime.now();
      final data = await ApiClient.instance.get(
        '/families/$fid/finance/monthly-finances/me'
        '?month=${now.month}&year=${now.year}',
      );

      final income = _parseNum(data, 'expectedIncome');
      final allowance = _parseNum(data, 'expectedPersonalExpense');
      final spent = _parseNum(data, 'actualPersonalExpense');

      if (mounted) {
        final pct = (allowance != null && allowance > 0 && spent != null)
            ? (spent / allowance).clamp(0.0, 1.0)
            : 0.0;
        setState(() {
          _income = income;
          _allowance = allowance;
          _actualSpent = spent;
        });
        _ring = Tween<double>(
          begin: 0,
          end: pct,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
        _ctrl
          ..reset()
          ..forward();
      }
    } catch (e) {
      if (mounted) setState(() => _financeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingFinance = false);
    }
  }

  // Query monthly-finances/me cho 6 tháng gần nhất (không có API list).
  Future<void> _fetchHistory() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    setState(() => _loadingHistory = true);
    final now = DateTime.now();
    final points = <_MonthPoint>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      try {
        final data = await ApiClient.instance.get(
          '/families/$fid/finance/monthly-finances/me'
          '?month=${d.month}&year=${d.year}',
        );
        points.add(
          _MonthPoint(
            month: d.month,
            income: _parseNum(data, 'expectedIncome') ?? 0,
            expense: _parseNum(data, 'expectedPersonalExpense') ?? 0,
          ),
        );
      } catch (_) {
        points.add(_MonthPoint(month: d.month, income: 0, expense: 0));
      }
    }
    if (mounted) {
      setState(() {
        _history = points;
        _loadingHistory = false;
      });
    }
  }

  Widget _monthlyChart() {
    if (_history.isEmpty) {
      return SizedBox(
        height: 110,
        child: Center(
          child: _loadingHistory
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Text(
                  'Chưa có dữ liệu',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textMuted,
                  ),
                ),
        ),
      );
    }
    double maxV = 1;
    for (final p in _history) {
      maxV = [maxV, p.income, p.expense].reduce((a, b) => a > b ? a : b);
    }
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _history
                .map(
                  (p) => Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _chartBar(p.income / maxV, AppColors.calTravel),
                            const SizedBox(width: 4),
                            _chartBar(p.expense / maxV, AppColors.link),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'T${p.month}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(AppColors.calTravel, 'Thu nhập'),
            _legend(AppColors.link, 'Chi tiêu'),
          ],
        ),
      ],
    );
  }

  Widget _chartBar(double frac, Color color) => Container(
    width: 8,
    height: frac.clamp(0.0, 1.0) * 88,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
      ),
    ],
  );

  static double? _parseNum(dynamic data, String key) {
    if (data is! Map) return null;
    final v = data[key];
    if (v == null) return null;
    // BE trả số dạng string ("3000000") — ép as num sẽ throw và màn hình
    // hiện "Chưa khai báo" oan dù đã khai báo (verified live)
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _fmtNum(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // Một dòng trong thẻ "Tổng quan tháng" (trên nền gradient rose).
  Widget _overviewRow(IconData icon, String label, double? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white70),
            ),
          ],
        ),
        Text(
          value != null ? '${_fmtNum(value)} ₫' : '—',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _overviewDivider() => const Divider(height: 1, color: Colors.white24);

  Widget _moneyField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsSeparatorInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixText: '₫',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  // Form khai báo/cập nhật tài chính tháng. Ràng buộc: chi tiêu dự đoán +
  // đóng góp quỹ KHÔNG vượt thu nhập tháng (chốt theo team).
  Future<void> _showDeclareSheet() async {
    final incomeCtrl = TextEditingController(
      text: _income != null ? _fmtNum(_income!) : '',
    );
    final expenseCtrl = TextEditingController(
      text: _allowance != null ? _fmtNum(_allowance!) : '',
    );
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.link,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tài chính tháng ${DateTime.now().month}/${DateTime.now().year}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Chi tiêu dự đoán không được vượt thu nhập tháng.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _moneyField(
                incomeCtrl,
                'Thu nhập tháng',
                Icons.arrow_upward_rounded,
              ),
              const SizedBox(height: 12),
              _moneyField(
                expenseCtrl,
                'Chi tiêu dự đoán',
                Icons.arrow_downward_rounded,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.sos,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sos,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final income = parseMoneyInput(incomeCtrl.text);
                    final expense = parseMoneyInput(expenseCtrl.text);
                    if (income <= 0) {
                      setSheet(() => error = 'Vui lòng nhập thu nhập tháng.');
                      return;
                    }
                    if (expense > income) {
                      setSheet(
                        () => error =
                            'Chi tiêu dự đoán (${_fmtNum(expense)}) không được '
                            'vượt thu nhập (${_fmtNum(income)}) ₫.',
                      );
                      return;
                    }
                    try {
                      await context.read<AuthProvider>().saveMonthlyFinance(
                        expectedIncome: income,
                        expectedExpense: expense,
                      );
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      await _fetchMonthlyFinance();
                    } catch (e) {
                      setSheet(
                        () => error = e.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Lưu',
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
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait([_fetchMonthlyFinance(), _fetchHistory()]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>(); // rebuild khi auth thay đổi

    final spent = _actualSpent ?? 0;
    final allowance = _allowance ?? 0;
    final pct = allowance > 0 ? (spent / allowance).clamp(0.0, 1.0) : 0.0;
    final remaining = allowance - spent;
    final isOver = spent > allowance && allowance > 0;
    final isSafe = pct <= 0.7;
    final hasData = _allowance != null && _allowance! > 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 24,
                    color: context.colors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tài chính của tôi',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_loadingFinance)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Balance / Allowance card ──────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary600, AppColors.primary500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary500.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tổng quan tháng ${DateTime.now().month}/${DateTime.now().year}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _overviewRow(
                      Icons.arrow_upward_rounded,
                      'Thu nhập',
                      _income,
                    ),
                    _overviewDivider(),
                    _overviewRow(
                      Icons.arrow_downward_rounded,
                      'Chi tiêu dự đoán',
                      _allowance,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Còn lại dự kiến',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _hasDeclared
                                ? '${_fmtNum((_income ?? 0) - (_allowance ?? 0))} ₫'
                                : 'Chưa khai báo',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _showDeclareSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    _hasDeclared ? Icons.edit_outlined : Icons.add_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _hasDeclared
                        ? 'Cập nhật tài chính tháng'
                        : 'Khai báo tài chính tháng',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Gauge card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.divider),
                ),
                child: hasData
                    ? Row(
                        children: [
                          AnimatedBuilder(
                            animation: _ring,
                            builder: (_, _) => SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  RingChart(
                                    progress: _ring.value,
                                    color: isOver
                                        ? AppColors.danger
                                        : isSafe
                                        ? AppColors.planned
                                        : AppColors.accent500,
                                    size: 80,
                                  ),
                                  Text(
                                    '${(_ring.value * 100).round()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOver
                                      ? 'Đã chi vượt dự đoán'
                                      : 'Đã chi ${(pct * 100).round()}% dự đoán',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fmtNum(spent)} / ${_fmtNum(allowance)} ₫'
                                  ' · ${isOver ? 'Vượt ${_fmtNum(-remaining)} ₫' : 'Còn ${_fmtNum(remaining)} ₫'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isOver
                                                ? AppColors.danger
                                                : isSafe
                                                ? AppColors.safe
                                                : AppColors.accent500)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOver
                                            ? Icons.error_outline_rounded
                                            : isSafe
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.warning_amber_rounded,
                                        size: 13,
                                        color: isOver
                                            ? AppColors.danger
                                            : isSafe
                                            ? AppColors.safe
                                            : AppColors.accent500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOver
                                            ? 'Vượt dự đoán'
                                            : isSafe
                                            ? 'Trong dự đoán'
                                            : 'Gần chạm dự đoán',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOver
                                              ? AppColors.danger
                                              : isSafe
                                              ? AppColors.safe
                                              : AppColors.accent500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _noAllowanceCard(),
              ),
              const SizedBox(height: 20),

              // ── Request money button ───────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _showRequestMoneyDialog(context),
                  icon: const Icon(
                    Icons.volunteer_activism_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'Xin tiền từ Trưởng/Phó nhóm',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Xem yêu cầu hỗ trợ ───────────────────────────
              _SupportRequestSection(),

              const SizedBox(height: 24),

              // ── Lịch sử thu chi theo tháng (6 tháng gần nhất) ──
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: context.colors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lịch sử thu chi theo tháng',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_loadingHistory)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.divider),
                ),
                child: _monthlyChart(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Số liệu do bạn khai báo mỗi tháng. Quỹ chung chỉ Trưởng/Phó nhóm xem.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: context.colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noAllowanceCard() {
    return Column(
      children: [
        const Icon(
          Icons.receipt_long_rounded,
          size: 32,
          color: AppColors.primary500,
        ),
        const SizedBox(height: 8),
        Text(
          'Chưa khai báo tài chính tháng',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nhấn "Khai báo tài chính tháng" phía trên\n'
          'để nhập thu nhập và chi tiêu dự đoán.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.colors.textMuted,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (_financeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _financeError!,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.danger),
          ),
        ],
      ],
    );
  }

  void _showRequestMoneyDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final provider = context.read<SupportRequestProvider>();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.volunteer_activism_outlined,
                size: 20,
                color: AppColors.link,
              ),
              const SizedBox(width: 8),
              Text(
                'Xin hỗ trợ chi tiêu',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tiền (₫)',
                  hintText: 'VD: 50000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: purposeCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Mục đích',
                  hintText: 'VD: Tiền ăn trưa',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.link,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final amt = double.tryParse(
                        amountCtrl.text.replaceAll(',', '').replaceAll('.', ''),
                      );
                      if (amt == null || amt <= 0) return;
                      if (purposeCtrl.text.trim().isEmpty) return;
                      setS(() => submitting = true);
                      try {
                        await provider.createRequest(
                          amount: amt,
                          purpose: purposeCtrl.text.trim(),
                        );
                        if (dCtx.mounted) Navigator.of(dCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã gửi yêu cầu!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setS(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Gửi',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Support request section ───────────────────────────────────────────────────

class _SupportRequestSection extends StatefulWidget {
  @override
  State<_SupportRequestSection> createState() => _SupportRequestSectionState();
}

class _SupportRequestSectionState extends State<_SupportRequestSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportRequestProvider>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportRequestProvider>();
    // Chỉ hiện yêu cầu của bản thân
    final myReqs = provider.requests
        .where((r) => r.requesterName.isNotEmpty)
        .toList();

    if (myReqs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Yêu cầu hỗ trợ',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (provider.pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${provider.pendingCount} chờ duyệt',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...myReqs
            .take(3)
            .map(
              (req) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        size: 20,
                        color: AppColors.link,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_fmtAmt(req.amount)} ₫',
                            style: GoogleFonts.inter(
                              fontSize: 15,
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
                    _statusChip(req.status),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final (color, label) = switch (status) {
      'APPROVED' => (AppColors.success, 'Đã duyệt'),
      'REJECTED' => (AppColors.danger, 'Từ chối'),
      _ => (AppColors.accent500, 'Chờ duyệt'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _fmtAmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Điểm dữ liệu 1 tháng cho biểu đồ lịch sử ──────────────────────────────────

class _MonthPoint {
  final int month;
  final double income;
  final double expense;
  const _MonthPoint({
    required this.month,
    required this.income,
    required this.expense,
  });
}
