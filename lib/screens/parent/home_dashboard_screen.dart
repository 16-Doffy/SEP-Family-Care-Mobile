import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/active_sos_banner.dart';

String _fmt(double n) => '${n.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWallets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user    = context.watch<AuthProvider>().user;
    final wallet  = context.watch<WalletProvider>();
    final finance = context.watch<FinanceProvider>();

    final balance  = wallet.familyWallet?.balance ?? 0;
    final txs      = wallet.transactions.take(3).toList();
    final newAlerts = finance.newAlerts.length;

    final weekdays = ['', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final today    = weekdays[DateTime.now().weekday];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(right: -60, bottom: 120, child: Container(width: 220, height: 220, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentGlow))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 8),

                // Header
                Row(
                  children: [
                    AvatarWidget(initial: user?.avatarInitials ?? 'BA', color: AppColors.avatarBlue, size: 44, showPresence: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Xin chào, ${user?.name ?? "Ba"} 👋', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('Gia đình ${user?.familyName ?? "Nguyễn"} · $today', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Stack(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(21),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                            child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textPrimary),
                          ),
                          if (newAlerts > 0)
                            Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.notification))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const ActiveSosBanner(),

                // Hero wallet card
                GestureDetector(
                  onTap: () => context.go('/manager/finance'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.heroOrange, AppColors.heroPurple], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 44, offset: const Offset(0, 18))],
                    ),
                    child: wallet.isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quỹ Gia Đình', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(_fmt(balance), style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Text(
                                '↑ ${_fmt(wallet.transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount))} thu tháng này',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFDCFCE7)),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick actions
                Row(
                  children: [
                    _quickCard('💰', 'Quỹ gia đình', () => context.go('/manager/finance')),
                    const SizedBox(width: 12),
                    _quickCard('📝', 'Ghi chi', () => context.go('/manager/finance')),
                    const SizedBox(width: 12),
                    _quickCard('📋', 'Tasks', () => context.push('/manager/tasks')),
                    const SizedBox(width: 12),
                    _quickCard('📅', 'Lịch', () => context.go('/manager/calendar')),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats row — goals + alerts
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/manager/finance'),
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [const Icon(Icons.flag_outlined, size: 16, color: AppColors.textPrimary), const SizedBox(width: 8), Text('Mục tiêu', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
                              const SizedBox(height: 4),
                              Text('${finance.goals.length} mục tiêu đang theo dõi', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: finance.goals.isEmpty ? 0 : (finance.goals.where((g) => g.progressPercent != null && g.progressPercent! >= 100).length / finance.goals.length),
                                  minHeight: 8,
                                  backgroundColor: AppColors.progressTrack,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [const Icon(Icons.warning_amber_outlined, size: 16, color: AppColors.textPrimary), const SizedBox(width: 8), Text('Cảnh báo', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
                            const SizedBox(height: 4),
                            Text(newAlerts > 0 ? '$newAlerts cảnh báo mới' : 'Không có cảnh báo', style: GoogleFonts.inter(fontSize: 12, color: newAlerts > 0 ? AppColors.danger : AppColors.textMuted)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: newAlerts > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(newAlerts > 0 ? 'Cần xử lý' : 'Ổn định', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: newAlerts > 0 ? AppColors.danger : AppColors.success)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // AI teaser
                GestureDetector(
                  onTap: () => context.push('/ai'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trợ lý AI', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text('Hỏi về chi tiêu, tasks hay mẹo tiết kiệm…', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        const Text('→', style: TextStyle(fontSize: 18, color: AppColors.link)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Recent transactions (real data)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Giao dịch gần đây', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    GestureDetector(onTap: () => context.go('/manager/finance'), child: Text('Xem tất cả →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link))),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  child: wallet.isLoading
                      ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      : txs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Chưa có giao dịch nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
                            )
                          : Column(
                              children: txs.map((tx) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38, height: 38,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)),
                                      alignment: Alignment.center,
                                      child: Text(tx.amount > 0 ? '💰' : '💸', style: const TextStyle(fontSize: 18)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(tx.description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(tx.createdAt.length >= 10 ? tx.createdAt.substring(0, 10) : tx.createdAt, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                    ])),
                                    Text(
                                      '${tx.amount > 0 ? '+' : ''}${_fmt(tx.amount.abs())}',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: tx.amount > 0 ? AppColors.success : AppColors.danger),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                ),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}
