import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/waffle_chart.dart';

String _fmt(int n) => '${n.toString().replaceAllMapped(
      RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"),
      (m) => "${m[1]},",
    )} ₫';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState     = context.watch<WalletProvider>();
    final pendingRequests = context.watch<MoneyProvider>().pendingRequests;

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
                      child: Text('Quỹ Gia Đình', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: walletState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : walletState.error != null
                      ? _errorView(walletState.error!, () => walletState.fetchWallets())
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
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  _tabItem(0, 'Tổng quan'),
                                  _tabItem(1, 'Lịch sử'),
                                  _tabItem(2, 'Yêu cầu', badge: pendingRequests.length),
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
    final family   = state.familyWallet;
    final totalIn  = state.transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount);
    final totalOut = state.transactions.where((t) => t.amount < 0).fold(0.0, (s, t) => s + t.amount).abs();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.heroOrange, AppColors.heroPurple], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng quỹ gia đình', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            _fmt(family?.balance.round() ?? 0),
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
          ),
          Text(
            'Tháng này +${_fmt(totalIn.round())} / -${_fmt(totalOut.round())}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: () => _showDepositSheet(context), child: _heroBtn('➕', 'Ghi thu'))),
              Container(width: 1, height: 36, color: Colors.white30),
              Expanded(child: GestureDetector(onTap: () => _showExpenseSheet(context), child: _heroBtn('📝', 'Ghi chi'))),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverview(BuildContext context, WalletProvider state) {
    final income    = state.transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount);
    final expense   = state.transactions.where((t) => t.amount < 0).fold(0.0, (s, t) => s + t.amount).abs();
    final remaining = income - expense;
    final spentRatio = income > 0 ? expense / income : 0.0;
    final bufferPct  = income > 0 ? ((remaining / income) * 100).round() : 0;
    final expenseFlex = expense.round().clamp(1, 999999999).toInt();
    final remainingFlex = remaining.round().clamp(1, 999999999).toInt();
    final badgeBg    = bufferPct < 10 ? const Color(0xFFFEE2E2) : bufferPct < 30 ? const Color(0xFFFFFBEB) : const Color(0xFFDCFCE7);
    final badgeTxt   = bufferPct < 10 ? const Color(0xFF991B1B) : bufferPct < 30 ? const Color(0xFF92400E) : const Color(0xFF166534);

    return [
      _sectionCard(
        title: 'Ngân sách tháng này',
        child: Column(
          children: [
            Row(
              children: [
                RingChart(
                  progress: spentRatio.clamp(0.0, 1.0).toDouble(),
                  size: 110, strokeWidth: 14,
                  color: AppColors.shared, trackColor: const Color(0xFFDCFCE7),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${(spentRatio * 100).round()}%', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('đã chi', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_fmt(expense.round()), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                    Text('đã chi / ${_fmt(income.round())} thu nhập', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('Dư ${_fmt(remaining.round())} · $bufferPct%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: badgeTxt)),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
                Flexible(flex: expenseFlex, fit: FlexFit.tight, child: Container(height: 12, color: AppColors.shared)),
                Flexible(flex: remainingFlex, fit: FlexFit.tight, child: Container(height: 12, color: AppColors.safe)),
              ]),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _barLegend('Chi tiêu', AppColors.shared, _fmt(expense.round())),
                _barLegend('Dư',       AppColors.safe,   _fmt(remaining.round())),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      _sectionCard(
        title: 'Phân bổ thu nhập',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaffleChart(segments: [
              WaffleSegment(color: AppColors.income, pct: income > 0 ? 50 : 0,       label: 'Thu nhập', amount: income.round()),
              WaffleSegment(color: AppColors.shared, pct: income > 0 ? (expense / income * 100).round() : 0, label: 'Chi tiêu', amount: expense.round()),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _waffleLegend('Thu nhập', AppColors.income,          _fmt(income.round()),    '100%'),
                const SizedBox(height: 10),
                _waffleLegend('Chi tiêu', AppColors.shared,          _fmt(expense.round()),   income > 0 ? '${(expense / income * 100).round()}%' : '0%'),
                const SizedBox(height: 10),
                _waffleLegend('Dư',       const Color(0xFFE5E7EB),   _fmt(remaining.round()), '$bufferPct%'),
              ]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      _alertBar(remaining.round(), bufferPct),

      // Finance quick links
      _sectionCard(
        title: 'Công cụ tài chính',
        child: Column(children: [
          _financeLink(context, '🏺', 'Mô hình tài chính', 'Cấu hình 5 hũ / 80-20 / tùy chỉnh', '/finance-model'),
          const SizedBox(height: 8),
          _financeLink(context, '📋', 'Kế hoạch & Mục tiêu', 'Budget plan · Mục tiêu · Cảnh báo', '/finance-plans'),
        ]),
      ),
      const SizedBox(height: 16),

      _sectionCard(
        title: 'Ví thành viên',
        child: Column(
          children: state.memberWallets.isEmpty
              ? [Text('Chưa có ví thành viên', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))]
              : state.memberWallets.map((w) {
                  final initials = w.ownerName.isNotEmpty ? w.ownerName.substring(0, 1).toUpperCase() : '?';
                  return _memberRow(initials, AppColors.avatarOrange, w.ownerName, w.type, _fmt(w.balance.round()), onTransfer: () => _showExpenseSheet(context));
                }).toList(),
        ),
      ),
    ];
  }

  List<Widget> _buildHistory(WalletProvider state) {
    if (state.transactions.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(child: Text('Chưa có giao dịch nào', style: TextStyle(color: AppColors.textMuted))),
      ];
    }
    return [
      _sectionCard(
        title: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: state.transactions.map((tx) {
            final isPos = tx.amount > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)), alignment: Alignment.center, child: Text(isPos ? '💵' : '💸', style: const TextStyle(fontSize: 18))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tx.description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(tx.createdAt,   style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ])),
                Text(
                  '${isPos ? '+' : ''}${_fmt(tx.amount.round())}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isPos ? AppColors.success : AppColors.danger),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    ];
  }

  List<Widget> _buildRequests(BuildContext context) {
    final pending = context.watch<MoneyProvider>().pendingRequests;
    if (pending.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(child: Text('🎉 Không có yêu cầu chờ duyệt', style: TextStyle(color: AppColors.textMuted))),
      ];
    }
    return pending.map((req) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Row(children: [
        AvatarWidget(initial: req.senderAvatarInitial, color: Color(req.senderAvatarColor), size: 44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${req.senderName} · ${_fmt(req.amount.round())}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(req.reason, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        Row(children: [
          GestureDetector(
            onTap: () async {
              try {
                await context.read<MoneyProvider>().reviewRequest(req.id, approved: true);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã duyệt cho ${req.senderName} ✅'), backgroundColor: AppColors.safe));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFDCFCE7), borderRadius: BorderRadius.all(Radius.circular(8))), child: const Icon(Icons.check, size: 18, color: AppColors.success)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              try {
                await context.read<MoneyProvider>().reviewRequest(req.id, approved: false);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã từ chối yêu cầu của ${req.senderName} ❌'), backgroundColor: AppColors.danger));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFFEE2E2), borderRadius: BorderRadius.all(Radius.circular(8))), child: const Icon(Icons.close, size: 18, color: AppColors.danger)),
          ),
        ]),
      ]),
    )).toList();
  }

  void _showDepositSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ghi thu nhập vào quỹ', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Số tiền (VD: 1000000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final amount = double.tryParse(ctrl.text);
                if (amount == null || amount <= 0) return;
                try {
                  await context.read<WalletProvider>().deposit(amount);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
              child: Text('Xác nhận ghi thu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showExpenseSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl   = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ghi chi tiêu', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Số tiền (VD: 500000)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: InputDecoration(hintText: 'Mô tả (VD: Tiền điện tháng 6)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                final desc   = descCtrl.text.trim();
                if (amount == null || amount <= 0 || desc.isEmpty) return;
                try {
                  await context.read<WalletProvider>().addExpense(amount, description: desc);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
              child: Text('Xác nhận ghi chi', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _errorView(String msg, VoidCallback onRetry) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Lỗi tải dữ liệu', style: GoogleFonts.inter(fontSize: 15, color: AppColors.danger)),
      const SizedBox(height: 8),
      Text(msg, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );

  Widget _financeLink(BuildContext context, String icon, String title, String desc, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title.isNotEmpty) ...[Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 4)],
      child,
    ]),
  );

  Widget _barLegend(String label, Color color, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted))]),
    Padding(padding: const EdgeInsets.only(left: 12, top: 2), child: Text(val, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
  ]);

  Widget _waffleLegend(String label, Color color, String amount, String pct) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 2, right: 8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      Text(amount, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(pct,    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]),
  ]);

  Widget _alertBar(int remaining, int bufferPct) {
    final String icon; final Color bg, tc, sc; final String title, sub;
    if (bufferPct < 10) {
      icon = '🚨'; bg = const Color(0xFFFEE2E2); tc = const Color(0xFF991B1B); sc = const Color(0xFFB91C1C);
      title = 'Cảnh báo ngân sách'; sub = 'Chỉ còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else if (bufferPct < 30) {
      icon = '⚠️'; bg = const Color(0xFFFFFBEB); tc = const Color(0xFF92400E); sc = const Color(0xFFB45309);
      title = 'Thu gần Chi'; sub = 'Còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else {
      icon = '✅'; bg = const Color(0xFFF0FDF4); tc = const Color(0xFF166634); sc = const Color(0xFF15803D);
      title = 'Dư ${_fmt(remaining)} — Tháng tốt!'; sub = 'Còn $bufferPct% dự phòng 🎉';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: tc)),
          Text(sub,   style: GoogleFonts.inter(fontSize: 11, color: sc)),
        ])),
      ]),
    );
  }

  Widget _memberRow(String init, Color color, String name, String role, String balance, {required VoidCallback onTransfer}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      AvatarWidget(initial: init, color: color, size: 40),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(role,    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      ])),
      Text(balance, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onTransfer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: AppColors.link, width: 1.5), borderRadius: BorderRadius.circular(8)),
          child: Text('Chuyển', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.link)),
        ),
      ),
    ]),
  );

  Widget _heroBtn(String icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(children: [
      Text(icon,  style: const TextStyle(fontSize: 18, color: Colors.white)),
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );

  Widget _tabItem(int index, String label, {int badge = 0}) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: active ? AppColors.link : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textMuted)),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle), child: Text(badge.toString(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.pop(),
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
    ),
  );
}
