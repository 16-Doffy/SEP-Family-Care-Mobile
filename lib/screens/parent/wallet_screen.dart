import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/money_request.dart';
import '../../providers/money_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/waffle_chart.dart';

// Budget constants
const _income     = 50000000;
const _sharedExp  = 20000000;
const _privateExp = 15000000;
const _totalExp   = _sharedExp + _privateExp;
const _remaining  = _income - _totalExp;
const _bufferPct  = (_remaining * 100) ~/ _income;

String _fmt(int n) => '${n.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ₫';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _tab = 0;

  final _allTx = const [
    _TxItem('💵', 'Lương tháng 5', 'thu', '+50,000,000 ₫', true, 'Hôm nay'),
    _TxItem('🏆', 'Thưởng task · An', 'chi', '+20,000 ₫', true, 'Hôm nay'),
    _TxItem('🛒', 'Siêu thị gia đình', 'chi', '-420,000 ₫', false, 'Hôm nay'),
    _TxItem('🍦', 'Ăn tối gia đình', 'chi', '-280,000 ₫', false, 'Hôm qua'),
    _TxItem('📚', 'Học phí tháng 5', 'chi', '-2,500,000 ₫', false, 'Hôm qua'),
    _TxItem('💊', 'Thuốc gia đình', 'chi', '-150,000 ₫', false, '19/05'),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingRequests = context.watch<MoneyProvider>().pendingRequests;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _backBtn(context),
                  const Expanded(child: Center(child: Text('Ví Gia Đình', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Hero balance card
                  Container(
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
                        Text('12,500,000 ₫', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                        Text('Tháng 5 · +3.2M so với tháng trước ↑', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: _heroBtn('➕', 'Nạp tiền')),
                            Container(width: 1, height: 36, color: Colors.white30),
                            Expanded(child: _heroBtn('↗', 'Chuyển')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                    child: Row(
                      children: [
                        _tabItem(0, 'Tổng quan'),
                        _tabItem(1, 'Lịch sử'),
                        _tabItem(2, 'Yêu cầu', badge: pendingRequests.length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_tab == 0) ..._buildOverview(),
                  if (_tab == 1) ..._buildHistory(),
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

  List<Widget> _buildOverview() {
    final spentRatio = _totalExp / _income;
    final badgeBg = _bufferPct < 10 ? const Color(0xFFFEE2E2) : _bufferPct < 30 ? const Color(0xFFFFFBEB) : const Color(0xFFDCFCE7);
    final badgeTxt = _bufferPct < 10 ? const Color(0xFF991B1B) : _bufferPct < 30 ? const Color(0xFF92400E) : const Color(0xFF166534);

    return [
      // Budget Gauge card
      _sectionCard(
        title: 'Ngân sách tháng 5',
        child: Column(
          children: [
            Row(
              children: [
                RingChart(
                  progress: spentRatio,
                  size: 110,
                  strokeWidth: 14,
                  color: AppColors.shared,
                  trackColor: const Color(0xFFDCFCE7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${(spentRatio * 100).round()}%', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('đã chi', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmt(_totalExp), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                      Text('đã chi / ${_fmt(_income)} thu nhập', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text('Dư ${_fmt(_remaining)} · $_bufferPct%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: badgeTxt)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Flexible(flex: _sharedExp,  fit: FlexFit.tight, child: Container(height: 12, color: AppColors.shared)),
                  Flexible(flex: _privateExp, fit: FlexFit.tight, child: Container(height: 12, color: AppColors.sos)),
                  Flexible(flex: _remaining,  fit: FlexFit.tight, child: Container(height: 12, color: AppColors.safe)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _barLegend('Chi chung', AppColors.shared, _fmt(_sharedExp)),
                _barLegend('Chi riêng', AppColors.sos,    _fmt(_privateExp)),
                _barLegend('Dư',        AppColors.safe,   _fmt(_remaining)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Waffle chart
      _sectionCard(
        title: 'Phân bổ thu nhập',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaffleChart(segments: const [
              WaffleSegment(color: AppColors.income, pct: 50, label: 'Thu nhập',  amount: _income),
              WaffleSegment(color: AppColors.shared, pct: 20, label: 'Chi chung', amount: _sharedExp),
              WaffleSegment(color: AppColors.sos,    pct: 15, label: 'Chi riêng', amount: _privateExp),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _waffleLegend('Thu nhập',  AppColors.income, _fmt(_income),     '50%'),
                  const SizedBox(height: 10),
                  _waffleLegend('Chi chung', AppColors.shared, _fmt(_sharedExp),  '20%'),
                  const SizedBox(height: 10),
                  _waffleLegend('Chi riêng', AppColors.sos,    _fmt(_privateExp), '15%'),
                  const SizedBox(height: 10),
                  _waffleLegend('Dư',        const Color(0xFFE5E7EB), _fmt(_remaining), '$_bufferPct%'),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Alert bar
      _alertBar(),
      const SizedBox(height: 0),

      // Members wallet
      _sectionCard(
        title: 'Ví thành viên',
        child: Column(
          children: [
            _memberRow('AN', AppColors.avatarOrange, 'An',  'Con',    '120,000 ₫'),
            _memberRow('BI', AppColors.avatarPurple, 'Bi',  'Con',    '80,000 ₫'),
            _memberRow('ME', AppColors.avatarBlue,   'Mẹ', 'Phó nhóm', '5,000,000 ₫'),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildHistory() {
    String? lastDate;
    return [
      _sectionCard(
        title: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _allTx.map((tx) {
            final showDate = lastDate != tx.date;
            if (showDate) lastDate = tx.date;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDate) Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(tx.date, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(width: 38, height: 38, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)), alignment: Alignment.center, child: Text(tx.emoji, style: const TextStyle(fontSize: 18))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tx.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(tx.cat, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ])),
                      Text(tx.amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: tx.positive ? AppColors.success : AppColors.danger)),
                    ],
                  ),
                ),
              ],
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

    return pending.map((req) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            AvatarWidget(initial: req.senderAvatarInitial, color: Color(req.senderAvatarColor), size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${req.senderName} · ${_fmt(req.amount.round())}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(req.reason, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ])),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<MoneyProvider>().updateStatus(req.id, MoneyRequestStatus.approved);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã duyệt ${_fmt(req.amount.round())} cho ${req.senderName} ✅'), backgroundColor: AppColors.safe));
                  },
                  child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFDCFCE7), borderRadius: BorderRadius.all(Radius.circular(8))), child: const Icon(Icons.check, size: 18, color: AppColors.success)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    context.read<MoneyProvider>().updateStatus(req.id, MoneyRequestStatus.rejected);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã từ chối yêu cầu của ${req.senderName} ❌'), backgroundColor: AppColors.danger));
                  },
                  child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFFEE2E2), borderRadius: BorderRadius.all(Radius.circular(8))), child: const Icon(Icons.close, size: 18, color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 4)],
          child,
        ],
      ),
    );
  }

  Widget _barLegend(String label, Color color, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted))]),
        Padding(padding: const EdgeInsets.only(left: 12, top: 2), child: Text(val, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _waffleLegend(String label, Color color, String amount, String pct) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 2, right: 8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            Text(amount, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(pct, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _alertBar() {
    final String icon;
    final Color bg, tc, sc;
    final String title, sub;
    if (_bufferPct < 10) {
      icon = '🚨'; bg = const Color(0xFFFEE2E2); tc = const Color(0xFF991B1B); sc = const Color(0xFFB91C1C);
      title = 'Cảnh báo ngân sách'; sub = 'Chỉ còn ${_fmt(_remaining)} ($_bufferPct% dự phòng)';
    } else if (_bufferPct < 30) {
      icon = '⚠️'; bg = const Color(0xFFFFFBEB); tc = const Color(0xFF92400E); sc = const Color(0xFFB45309);
      title = 'Thu gần Chi'; sub = 'Còn ${_fmt(_remaining)} ($_bufferPct% dự phòng)';
    } else {
      icon = '✅'; bg = const Color(0xFFF0FDF4); tc = const Color(0xFF166534); sc = const Color(0xFF15803D);
      title = 'Dư ${_fmt(_remaining)} — Tháng tốt!'; sub = 'Còn $_bufferPct% dự phòng · Tiết kiệm thêm 5M nữa nhé 🎉';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: tc)),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, color: sc)),
          ])),
        ],
      ),
    );
  }

  Widget _memberRow(String init, Color color, String name, String role, String balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AvatarWidget(initial: init, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(role, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ])),
          Text(balance, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: AppColors.link, width: 1.5), borderRadius: BorderRadius.circular(8)),
            child: Text('Chuyển', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.link)),
          ),
        ],
      ),
    );
  }

  Widget _heroBtn(String icon, String label) {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 18, color: Colors.white)),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _tabItem(int index, String label, {int badge = 0}) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
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
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textMuted)),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Text(badge.toString(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext ctx) {
    return GestureDetector(
      onTap: () => ctx.pop(),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TxItem {
  final String emoji, title, cat, amount, date;
  final bool positive;
  const _TxItem(this.emoji, this.title, this.cat, this.amount, this.positive, this.date);
}
