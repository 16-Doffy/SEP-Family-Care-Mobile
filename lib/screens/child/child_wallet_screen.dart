import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/money_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/money_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/request_money_sheet.dart';

class ChildWalletScreen extends StatefulWidget {
  const ChildWalletScreen({super.key});
  @override
  State<ChildWalletScreen> createState() => _ChildWalletScreenState();
}

class _ChildWalletScreenState extends State<ChildWalletScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ring;
  late Animation<double> _bal;

  static const _balance = 250000;
  static const _allowance = 500000;
  static const _spent = 250000;
  static const _pct = _spent / _allowance; // 0.5

  final _txns = const [
    (icon: '🍜', title: 'Ăn sáng', amount: -15000, date: 'Hôm nay'),
    (icon: '📚', title: 'Mua sách', amount: -35000, date: 'Hôm qua'),
    (icon: '💸', title: 'Tiền tiêu vặt tháng 5', amount: 200000, date: '01/05'),
    (icon: '🎮', title: 'Thưởng hoàn thành task', amount: 50000, date: '28/04'),
    (icon: '🍦', title: 'Kem buổi chiều', amount: -20000, date: '27/04'),
    (icon: '💸', title: 'Tiền tiêu vặt tháng 4', amount: 200000, date: '01/04'),
  ];

  String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${n < 0 ? '-' : '+'}${buf.toString()} ₫';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _ring = Tween<double>(begin: 0, end: _pct).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _bal = Tween<double>(begin: 0, end: _balance.toDouble()).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final myRequests = context.watch<MoneyProvider>().requests.where(
      (r) => r.senderId == context.read<AuthProvider>().user?.id
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Text('💰 Ví của tôi', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 20),

            // Balance card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary600, AppColors.primary500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primary500.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Số dư hiện tại', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('${_bal.value.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫',
                      style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tiêu dùng', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                      Text('250,000 ₫', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hạn mức tháng', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                      Text('500,000 ₫', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ])),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Spending gauge
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _ring,
                  builder: (_, __) => SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
                    RingChart(progress: _ring.value, color: AppColors.planned, size: 80),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(_ring.value * 100).round()}%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ]),
                  ])),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Đã tiêu 50% hạn mức', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('250,000 / 500,000 ₫ · Còn lại 250,000 ₫', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
                    child: Text('✅ Trong ngưỡng an toàn', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.safe))),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            // Request money button
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

            if (myRequests.isNotEmpty) ...[
              Text('Lịch sử yêu cầu', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...myRequests.map((req) => _requestCard(req)),
              const SizedBox(height: 20),
            ],

            Text('Lịch sử giao dịch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            ..._txns.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(t.icon, style: const TextStyle(fontSize: 22))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(t.date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ])),
                Text(_fmt(t.amount), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.amount > 0 ? AppColors.safe : AppColors.textPrimary)),
              ]),
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(MoneyRequest req) {
    Color statusColor;
    String statusText;
    switch (req.status) {
      case MoneyRequestStatus.pending:
        statusColor = AppColors.planned;
        statusText = 'Chờ duyệt';
        break;
      case MoneyRequestStatus.approved:
        statusColor = AppColors.success;
        statusText = 'Đã duyệt';
        break;
      case MoneyRequestStatus.rejected:
        statusColor = AppColors.danger;
        statusText = 'Từ chối';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle), alignment: Alignment.center, child: const Text('📨', style: TextStyle(fontSize: 20))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${req.amount.round().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ₫', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(req.reason, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(statusText, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
        ),
      ]),
    );
  }

}
