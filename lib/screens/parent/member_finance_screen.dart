import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

// UC gap #5 — Manager/Deputy xem tài chính tháng của thành viên
// (BE ship 2026-07-13: GET .../finance/monthly-summary/members/{memberId}).
// memberId rỗng → xem của chính mình qua .../monthly-summary/me.
// Field private của member khác được BE trả null sẵn → hiển thị "Riêng tư".
class MemberFinanceScreen extends StatefulWidget {
  final String memberId; // '' = chính mình
  final String memberName;
  const MemberFinanceScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<MemberFinanceScreen> createState() => _MemberFinanceScreenState();
}

class _MemberFinanceScreenState extends State<MemberFinanceScreen> {
  late int _month;
  late int _year;
  MonthlySummary? _summary;
  bool _loading = true;
  String? _error;

  bool get _isMe => widget.memberId.isEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final finance = context.read<FinanceProvider>();
      final s = _isMe
          ? await finance.fetchMonthlySummaryMe(month: _month, year: _year)
          : await finance.fetchMemberMonthlySummary(widget.memberId,
              month: _month, year: _year);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    // Không cho xem tương lai
    final now = DateTime.now();
    if (y > now.year || (y == now.year && m > now.month)) return;
    setState(() {
      _month = m;
      _year = y;
    });
    _fetch();
  }

  static String _fmtNum(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // null từ BE = field private (khi xem member khác) hoặc chưa nhập
  String _money(double? v, {required bool privateWhenNull}) {
    if (v == null) return privateWhenNull && !_isMe ? '🔒 Riêng tư' : '—';
    return '${_fmtNum(v)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final atCurrentMonth = _year == now.year && _month == now.month;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tài chính tháng',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(_isMe ? 'Của bạn' : widget.memberName,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                    ]),
              ),
            ]),
          ),

          // ── Chọn tháng ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textSecondary),
                ),
                Text('Tháng $_month/$_year',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                IconButton(
                  onPressed: atCurrentMonth ? null : () => _shiftMonth(1),
                  icon: Icon(Icons.chevron_right_rounded,
                      color: atCurrentMonth
                          ? const Color(0xFFE5E7EB)
                          : AppColors.textSecondary),
                ),
              ],
            ),
          ),

          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _fetch, child: const Text('Thử lại')),
        ]),
      );
    }
    final s = _summary;
    if (s == null) {
      return Center(
        child: Text('Không có dữ liệu tháng này',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
      );
    }
    final mf = s.monthlyFinance;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Khai báo thu chi tháng ───────────────────────────
          _card(
            title: '📋 Khai báo thu chi',
            child: mf == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        _isMe
                            ? 'Bạn chưa khai báo tài chính tháng này'
                            : 'Thành viên chưa khai báo tài chính tháng này',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted)),
                  )
                : Column(children: [
                    _row('Thu nhập dự kiến',
                        _money(mf.expectedIncome, privateWhenNull: mf.incomeVisibility == 'PRIVATE')),
                    _row('Thu nhập thực tế',
                        _money(mf.actualIncome, privateWhenNull: mf.incomeVisibility == 'PRIVATE')),
                    _row('Chi tiêu dự kiến',
                        _money(mf.expectedPersonalExpense, privateWhenNull: mf.expenseVisibility == 'PRIVATE')),
                    _row('Chi tiêu thực tế',
                        _money(mf.actualPersonalExpense, privateWhenNull: mf.expenseVisibility == 'PRIVATE')),
                    _row('Đóng góp chung dự kiến',
                        _money(mf.expectedSharedContribution, privateWhenNull: false)),
                    _row('Đóng góp chung thực tế',
                        _money(mf.actualSharedContribution, privateWhenNull: false)),
                    if (mf.note != null && mf.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Ghi chú: ${mf.note}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textMuted)),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 14),

          // ── Đóng góp quỹ gia đình ────────────────────────────
          _card(
            title: '🏦 Đóng góp quỹ gia đình',
            child: Column(children: [
              _row('Kế hoạch', _money(s.fundPlanned, privateWhenNull: false)),
              _row('Tự khai báo', _money(s.fundDeclared, privateWhenNull: false)),
              _row('Ghi nhận sổ quỹ', '${_fmtNum(s.fundLedgerActual)} ₫'),
              _row('Thực tế', '${_fmtNum(s.fundActual)} ₫', bold: true),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Đóng góp mục tiêu tài chính ──────────────────────
          _card(
            title: '🎯 Đóng góp mục tiêu',
            child: Column(children: [
              _row('Tổng kế hoạch', '${_fmtNum(s.goalPlanned)} ₫'),
              _row('Tổng đã góp', '${_fmtNum(s.goalActual)} ₫', bold: true),
              if (s.goalShortage > 0)
                _row('Còn thiếu', '${_fmtNum(s.goalShortage)} ₫',
                    valueColor: AppColors.danger),
              if (s.goalItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Chưa có kế hoạch đóng góp mục tiêu nào',
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: AppColors.textMuted)),
                )
              else ...[
                const Divider(height: 20),
                ...s.goalItems.map((g) {
                  final name = g['goalName']?.toString() ??
                      g['name']?.toString() ??
                      'Mục tiêu';
                  final planned =
                      double.tryParse(g['plannedAmount']?.toString() ?? '');
                  final actual =
                      double.tryParse(g['actualAmount']?.toString() ?? '');
                  return _row(
                    name,
                    '${actual == null ? '—' : _fmtNum(actual)} / ${planned == null ? '—' : _fmtNum(planned)} ₫',
                  );
                }),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _row(String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ]),
      );
}
