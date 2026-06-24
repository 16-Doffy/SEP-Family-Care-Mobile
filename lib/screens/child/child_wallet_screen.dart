import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/money_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/money_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/request_money_sheet.dart';
import '../../widgets/ring_chart.dart';

String _fmtMoney(double value) {
  final rounded = value.abs().round();
  final text = rounded.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '$text d';
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
      context.read<MoneyProvider>().fetchRequests();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<FinanceProvider>().fetchAll(),
      context.read<MoneyProvider>().fetchRequests(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final money = context.watch<MoneyProvider>();
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final myRequests = money.requests.where((r) => r.senderId == myId).toList();

    final mf = finance.monthlyFinance;
    final spent = mf?.actualPersonalExpense ?? 0;
    final limit = mf?.expectedPersonalExpense ?? 0;
    final income = mf?.actualIncome ?? 0;
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final remaining = (limit - spent).clamp(0.0, double.infinity).toDouble();
    final isSafe = limit == 0 || pct < 0.8;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: finance.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'So thu chi ca nhan',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Man nay chi hien thu/chi ca nhan cua ban. Tong quy gia dinh va so du thanh vien do quan ly xem/ghi nhan, nen member se khong thay tien quy chung neu BE chua cap quyen endpoint rieng.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summaryCard(
                      spent: spent,
                      limit: limit,
                      income: income,
                    ),
                    const SizedBox(height: 16),
                    if (limit > 0) ...[
                      _progressCard(
                        pct: pct,
                        spent: spent,
                        limit: limit,
                        remaining: remaining,
                        isSafe: isSafe,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _monthlyFinanceTile(hasData: mf != null),
                    const SizedBox(height: 14),
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
                        onPressed: () => RequestMoneySheet.show(context),
                        icon: const Icon(Icons.volunteer_activism_rounded),
                        label: Text(
                          'Gui yeu cau ho tro chi tieu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lich su yeu cau cua toi',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (myRequests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Chua co yeu cau nao',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ...myRequests.map(_requestCard),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard({
    required double spent,
    required double limit,
    required double income,
  }) {
    return Container(
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
            color: AppColors.primary500.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Da chi trong thang nay',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtMoney(spent),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryMetric('Han muc thang',
                    limit > 0 ? _fmtMoney(limit) : 'Chua dat'),
              ),
              Expanded(
                child: _summaryMetric(
                    'Thu nhap ca nhan', income > 0 ? _fmtMoney(income) : 'Chua khai bao'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      );

  Widget _progressCard({
    required double pct,
    required double spent,
    required double limit,
    required double remaining,
    required bool isSafe,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RingChart(
                  progress: pct,
                  color: isSafe ? AppColors.planned : AppColors.danger,
                  size: 80,
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Da dung ${(pct * 100).round()}% han muc',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtMoney(spent)} / ${_fmtMoney(limit)} - Con lai ${_fmtMoney(remaining)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyFinanceTile({required bool hasData}) {
    return GestureDetector(
      onTap: () => context.push('/monthly-finance'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasData ? AppColors.white : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasData ? AppColors.progressTrack : const Color(0xFFF59E0B),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              hasData ? Icons.edit_note_rounded : Icons.note_add_rounded,
              color: hasData ? AppColors.textMuted : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasData
                        ? 'Cap nhat khai bao thu/chi'
                        : 'Khai bao tai chinh thang nay',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasData
                          ? AppColors.textPrimary
                          : const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'Thu nhap, chi tieu ca nhan va muc hien thi voi gia dinh',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: hasData
                          ? AppColors.textMuted
                          : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hasData ? AppColors.textMuted : const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(MoneyRequest request) {
    final status = _requestStatus(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            child: const Icon(Icons.request_quote_rounded, color: AppColors.link),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtMoney(request.amount),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  request.reason,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
              ),
              if (request.status == MoneyRequestStatus.pending) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    try {
                      await context.read<MoneyProvider>().cancelRequest(request.id);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Huy',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _requestStatus(MoneyRequestStatus status) {
    return switch (status) {
      MoneyRequestStatus.pending => (label: 'Cho duyet', color: AppColors.planned),
      MoneyRequestStatus.approved => (label: 'Da duyet', color: AppColors.success),
      MoneyRequestStatus.rejected => (label: 'Tu choi', color: AppColors.danger),
      MoneyRequestStatus.canceled => (label: 'Da huy', color: AppColors.textMuted),
    };
  }
}
