import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/money_request.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/request_money_sheet.dart';

String _fmt(double n) {
  final abs = n.abs().round();
  final s = abs.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return n < 0 ? '-$s ₫' : '+$s ₫';
}

String _fmtAbs(double n) {
  final abs = n.abs().round();
  return '${abs.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';
}

class ChildWalletScreen extends StatefulWidget {
  const ChildWalletScreen({super.key});
  @override
  State<ChildWalletScreen> createState() => _ChildWalletScreenState();
}

class _ChildWalletScreenState extends State<ChildWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll();
      context.read<WalletProvider>().fetchWallets();
      context.read<MoneyProvider>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance   = context.watch<FinanceProvider>();
    final wallet    = context.watch<WalletProvider>();
    final money     = context.watch<MoneyProvider>();
    final myId      = context.read<AuthProvider>().user?.id ?? '';
    final myRequests = money.requests.where((r) => r.senderId == myId).toList();

    final mf            = finance.monthlyFinance;
    final spent         = mf?.actualPersonalExpense ?? 0;
    final limit         = mf?.expectedPersonalExpense ?? 0;
    final income        = mf?.actualIncome ?? 0;
    final pct           = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final remaining     = (limit - spent).clamp(0.0, double.infinity);
    final safeThreshold = limit > 0 && pct < 0.8;

    final isLoading = finance.isLoading || wallet.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    context.read<FinanceProvider>().fetchAll(),
                    context.read<WalletProvider>().fetchWallets(),
                    context.read<MoneyProvider>().fetchRequests(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 20),
                    Text('📊 Sổ chi tiêu', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 20),

                    // ── Budget card ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary600, AppColors.primary500], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.primary500.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chi tiêu tháng này', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(_fmtAbs(spent), style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Đã tiêu', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                            Text(_fmtAbs(spent), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ])),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Hạn mức tháng', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                            Text(limit > 0 ? _fmtAbs(limit) : 'Chưa đặt', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ])),
                        ]),
                        if (income > 0) ...[
                          const SizedBox(height: 8),
                          Text('Thu nhập thực tế: ${_fmtAbs(income)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Spending gauge ───────────────────────────────────────
                    if (limit > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                        child: Row(children: [
                          SizedBox(
                            width: 80, height: 80,
                            child: Stack(alignment: Alignment.center, children: [
                              RingChart(progress: pct, color: safeThreshold ? AppColors.planned : AppColors.danger, size: 80),
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('${(pct * 100).round()}%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ]),
                            ]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Đã tiêu ${(pct * 100).round()}% hạn mức', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text('${_fmtAbs(spent)} / ${_fmtAbs(limit)} · Còn lại ${_fmtAbs(remaining)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: safeThreshold ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                safeThreshold ? '✅ Trong ngưỡng an toàn' : '⚠️ Gần vượt hạn mức',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: safeThreshold ? AppColors.safe : AppColors.danger),
                              ),
                            ),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Khai báo tài chính tháng ─────────────────────────────
                    if (mf == null)
                      _setupBudgetBanner(context),
                    const SizedBox(height: 4),

                    // ── Request money button ─────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => RequestMoneySheet.show(context),
                        icon: const Text('💸', style: TextStyle(fontSize: 18)),
                        label: Text('Xin tiền từ Trưởng/Phó nhóm', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Request history ──────────────────────────────────────
                    if (myRequests.isNotEmpty) ...[
                      Text('Lịch sử yêu cầu', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      ...myRequests.map(_requestCard),
                      const SizedBox(height: 20),
                    ],

                    // ── Transaction history ──────────────────────────────────
                    Text('Lịch sử giao dịch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),

                    if (wallet.transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Chưa có giao dịch nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                      )
                    else
                      ...wallet.transactions.map((t) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(t.amount > 0 ? '💰' : '💸', style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text(t.createdAt, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ])),
                          Text(
                            _fmt(t.amount),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.amount > 0 ? AppColors.safe : AppColors.textPrimary),
                          ),
                        ]),
                      )),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _setupBudgetBanner(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      const Text('📝', style: TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Chưa khai báo tài chính tháng này', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
        Text('Đặt hạn mức chi tiêu để theo dõi ngân sách', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309))),
      ])),
    ]),
  );

  Widget _requestCard(MoneyRequest req) {
    final Color statusColor;
    final String statusText;
    switch (req.status) {
      case MoneyRequestStatus.pending:
        statusColor = AppColors.planned; statusText = 'Chờ duyệt';
      case MoneyRequestStatus.approved:
        statusColor = AppColors.success; statusText = 'Đã duyệt';
      case MoneyRequestStatus.rejected:
        statusColor = AppColors.danger; statusText = 'Từ chối';
      case MoneyRequestStatus.canceled:
        statusColor = AppColors.textMuted; statusText = 'Đã hủy';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle), alignment: Alignment.center, child: const Text('📨', style: TextStyle(fontSize: 20))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtAbs(req.amount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(req.reason, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(statusText, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
          ),
          if (req.status == MoneyRequestStatus.pending) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                try {
                  await context.read<MoneyProvider>().cancelRequest(req.id);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                child: Text('Hủy', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
