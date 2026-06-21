import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_alert_provider.dart';
import '../../theme/app_colors.dart';

class FinanceAlertsScreen extends StatefulWidget {
  const FinanceAlertsScreen({super.key});
  @override
  State<FinanceAlertsScreen> createState() => _FinanceAlertsScreenState();
}

class _FinanceAlertsScreenState extends State<FinanceAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceAlertProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceAlertProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)
                      ]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Cảnh báo tài chính',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              if (provider.newCount > 0)
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                    child: Text('${provider.newCount}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                )
              else
                const SizedBox(width: 40),
            ]),
          ),

          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? _errorView(provider)
                    : provider.alerts.isEmpty
                        ? _emptyView()
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchAlerts(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: provider.alerts.length,
                              itemBuilder: (ctx, i) =>
                                  _AlertCard(alert: provider.alerts[i], provider: provider),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('✅', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text('Không có cảnh báo nào',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('Tài chính gia đình đang ổn định',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
    ]),
  );

  Widget _errorView(FinanceAlertProvider provider) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
      const SizedBox(height: 16),
      Text('Không tải được dữ liệu',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () => provider.fetchAlerts(),
        child: const Text('Thử lại'),
      ),
    ]),
  );
}

class _AlertCard extends StatelessWidget {
  final FinanceAlert alert;
  final FinanceAlertProvider provider;

  const _AlertCard({required this.alert, required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    final emoji = _typeEmoji(alert.alertType);
    final isNew  = alert.isNew;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNew ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                      : Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_typeLabel(alert.alertType),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(_formatDate(alert.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999)),
            child: Text(_severityLabel(alert.severity),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(alert.message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),

        if (isNew) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: () => provider.acknowledge(alert.id),
                child: Text('Đã xem',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: () => provider.resolve(alert.id),
                child: Text('Đã xử lý',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  static Color _severityColor(String s) => switch (s) {
        'HIGH'   => AppColors.danger,
        'MEDIUM' => const Color(0xFFF59E0B),
        _        => const Color(0xFF6B7280),
      };

  static String _severityLabel(String s) => switch (s) {
        'HIGH'   => 'Nghiêm trọng',
        'MEDIUM' => 'Trung bình',
        _        => 'Thấp',
      };

  static String _typeEmoji(String t) => switch (t) {
        'OVER_BUDGET'            => '🔴',
        'GOAL_AT_RISK'           => '⚠️',
        'NON_ESSENTIAL_TOO_HIGH' => '💸',
        _                        => '📊',
      };

  static String _typeLabel(String t) => switch (t) {
        'OVER_BUDGET'            => 'Vượt ngân sách',
        'GOAL_AT_RISK'           => 'Mục tiêu có nguy cơ',
        'NON_ESSENTIAL_TOO_HIGH' => 'Chi không thiết yếu cao',
        _                        => 'Cảnh báo tài chính',
      };

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
    return '${d.day}/${d.month}/${d.year}';
  }
}
