import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
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

  // Dữ liệu từ API monthly-finances/me
  double? _allowance; // expectedPersonalExpense
  double? _actualSpent; // actualPersonalExpense (nếu BE trả về)
  bool _loadingFinance = false;
  String? _financeError;

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
        context.read<WalletProvider>().fetchWallets();
      }
    });
  }

  void _onAuthChanged() {
    if (mounted && context.read<AuthProvider>().hasFamily) {
      _fetchMonthlyFinance();
      context.read<WalletProvider>().fetchWallets();
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

      final allowance = _parseNum(data, 'expectedPersonalExpense');
      final spent = _parseNum(data, 'actualPersonalExpense');

      if (mounted) {
        final pct = (allowance != null && allowance > 0 && spent != null)
            ? (spent / allowance).clamp(0.0, 1.0)
            : 0.0;
        setState(() {
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

  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchMonthlyFinance(),
      context.read<WalletProvider>().fetchWallets(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>(); // rebuild khi auth thay đổi
    final wallet = context.watch<WalletProvider>();

    final spent = _actualSpent ?? 0;
    final allowance = _allowance ?? 0;
    final pct = allowance > 0 ? (spent / allowance).clamp(0.0, 1.0) : 0.0;
    final remaining = allowance - spent;
    final isOver = spent > allowance && allowance > 0;
    final isSafe = pct <= 0.7;
    final hasData = _allowance != null && _allowance! > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '💰 Tài chính của tôi',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                    Text(
                      'Số dư hiện tại',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Balance vẫn mock — chưa có API
                    Text(
                      '— ₫',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Số dư thực chưa có API',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đã tiêu tháng này',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                              Text(
                                _actualSpent != null
                                    ? '${_fmtNum(_actualSpent!)} ₫'
                                    : '—',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hạn mức tháng',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                              _loadingFinance
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      hasData
                                          ? '${_fmtNum(_allowance!)} ₫'
                                          : 'Chưa khai báo',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Gauge card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
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
                                      color: AppColors.textPrimary,
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
                                      ? 'Đã vượt hạn mức!'
                                      : 'Đã tiêu ${(pct * 100).round()}% hạn mức',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fmtNum(spent)} / ${_fmtNum(allowance)} ₫'
                                  ' · ${isOver ? 'Vượt ${_fmtNum(-remaining)} ₫' : 'Còn ${_fmtNum(remaining)} ₫'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOver
                                        ? const Color(0xFFFEE2E2)
                                        : isSafe
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isOver
                                        ? '🔴 Vượt ngưỡng an toàn'
                                        : isSafe
                                        ? '✅ Trong ngưỡng an toàn'
                                        : '⚠️ Gần đến hạn mức',
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
                  icon: const Text('💸', style: TextStyle(fontSize: 18)),
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

              // ── Lịch sử (sổ tài chính chung gia đình) ─────────
              Row(
                children: [
                  Text(
                    'Lịch sử',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (wallet.isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (!wallet.isLoading && wallet.transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  // BE chặn member đọc sổ quỹ chung (403 — chỉ MANAGER/DEPUTY,
                  // verified live) nên đừng hiện "chưa có giao dịch" gây hiểu lầm
                  child: Text(
                    context.watch<AuthProvider>().user?.isAdministrative ==
                            false
                        ? 'Sổ quỹ chung chỉ Trưởng/Phó nhóm xem được.\nLịch sử xin tiền của bạn nằm ở mục "Yêu cầu hỗ trợ" phía trên.'
                        : 'Chưa có giao dịch nào',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                )
              else
                ...wallet.transactions.map((e) => _LedgerCard(entry: e)),
              if (wallet.hasMoreEntries)
                Center(
                  child: TextButton(
                    onPressed: wallet.isLoadingMoreEntries
                        ? null
                        : () =>
                              context.read<WalletProvider>().fetchMoreEntries(),
                    child: wallet.isLoadingMoreEntries
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tải thêm'),
                  ),
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
        const Text('📋', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          'Chưa khai báo hạn mức tháng',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vào Hồ sơ → Tài chính tháng để khai báo\nhạn mức chi tiêu cá nhân.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMuted,
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
          title: Text(
            '💸 Xin hỗ trợ chi tiêu',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
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
                      child: const Text('📨', style: TextStyle(fontSize: 20)),
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

// ── Ledger entry card (GET /finance/ledger/entries) ───────────────────────────

class _LedgerCard extends StatelessWidget {
  final LedgerEntry entry;
  const _LedgerCard({required this.entry});

  static const _icons = {
    'INCOME': '💸',
    'EXPENSE': '🧾',
    'TRANSFER_IN': '⬇️',
    'TRANSFER_OUT': '⬆️',
  };

  @override
  Widget build(BuildContext context) {
    final isPos = entry.signedAmount >= 0;
    return Container(
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
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _icons[entry.entryType] ?? '💰',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description.isNotEmpty
                      ? entry.description
                      : (entry.categoryName ?? 'Giao dịch'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _fmtDate(entry.entryDate),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPos ? '+' : '-'}${_fmtAbs(entry.signedAmount)} ₫',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPos ? AppColors.safe : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _fmtAbs(double v) {
    final s = v.abs().round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
