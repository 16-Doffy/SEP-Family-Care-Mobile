import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

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
      context.read<TaskProvider>().fetchTasks();
    });
  }

  String _fmtBalance(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final user        = context.watch<AuthProvider>().user;
    final walletState = context.watch<WalletProvider>();
    final taskState   = context.watch<TaskProvider>();

    final balance      = walletState.familyWallet?.balance ?? 0.0;
    final transactions = walletState.transactions;
    final tasks        = taskState.tasks;
    final doneTasks    = tasks.where((t) => t.status == 'DONE').length;
    final totalTasks   = tasks.length;
    final taskPct      = totalTasks > 0 ? doneTasks / totalTasks : 0.0;

    // income delta từ tháng trước — tính từ income transactions
    final totalIn = transactions
        .where((t) => t.amount > 0)
        .fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            right: -60, bottom: 120,
            child: Container(
              width: 220, height: 220,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.accentGlow),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  context.read<WalletProvider>().fetchWallets(),
                  context.read<TaskProvider>().fetchTasks(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),

                  // ── Header ──────────────────────────────────────
                  Row(
                    children: [
                      AvatarWidget(
                        initial: user?.avatarInitials ?? 'BA',
                        color: AppColors.avatarBlue,
                        size: 44,
                        showPresence: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào, ${user?.name ?? "Trưởng nhóm"} 👋',
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              'Gia đình ${user?.familyName ?? "Nguyễn"} · Hôm nay',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  size: 20, color: AppColors.textPrimary),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.notification),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Hero Wallet Card ────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/manager/wallet'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.heroOrange, AppColors.heroPurple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 44,
                              offset: const Offset(0, 18))
                        ],
                      ),
                      child: walletState.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quỹ Gia Đình',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: Colors.white70)),
                                const SizedBox(height: 8),
                                Text(
                                  _fmtBalance(balance),
                                  style: GoogleFonts.inter(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 8),
                                if (totalIn > 0)
                                  Text(
                                    '↑ +${_fmtBalance(totalIn)} tháng này',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFDCFCE7)),
                                  )
                                else
                                  Text('Tap để xem chi tiết ví',
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: Colors.white54)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick Actions ───────────────────────────────
                  Row(
                    children: [
                      _quickCard('📋', 'Tasks',
                          () => context.push('/manager/tasks')),
                      const SizedBox(width: 12),
                      _quickCard('👨‍👩‍👧', 'Thành viên',
                          () => context.push('/manager/members')),
                      const SizedBox(width: 12),
                      _quickCard('🫙', 'Ngân sách',
                          () => context.push('/manager/finance-model')),
                      const SizedBox(width: 12),
                      _quickCard('👥', 'Mời',
                          () => context.push('/manager/invite')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Stats Row ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/manager/tasks'),
                          child: _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.assignment_outlined,
                                      size: 16,
                                      color: AppColors.textPrimary),
                                  const SizedBox(width: 8),
                                  Text('Tasks',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ]),
                                const SizedBox(height: 4),
                                taskState.isLoading
                                    ? Text('Đang tải...',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMuted))
                                    : Text(
                                        '$doneTasks / $totalTasks hoàn thành',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMuted),
                                      ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: taskPct,
                                          minHeight: 8,
                                          backgroundColor:
                                              AppColors.progressTrack,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  AppColors.success),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${(taskPct * 100).round()}%',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/manager/members'),
                          child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.people_outline,
                                    size: 16,
                                    color: AppColors.textPrimary),
                                const SizedBox(width: 8),
                                Text(
                                  '${walletState.memberWallets.length} thành viên',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text('Trong gia đình',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  AvatarWidget(
                                      initial: 'M',
                                      color: AppColors.avatarPurple,
                                      size: 28,
                                      showPresence: true),
                                  Transform.translate(
                                    offset: const Offset(-10, 0),
                                    child: AvatarWidget(
                                        initial: 'A',
                                        color: AppColors.avatarOrange,
                                        size: 28,
                                        showPresence: true),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(-20, 0),
                                    child: AvatarWidget(
                                        initial: 'B',
                                        color: AppColors.avatarBlue,
                                        size: 28,
                                        showPresence: true),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── AI Teaser ───────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/ai'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text('🤖',
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trợ lý AI',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                Text(
                                    'Hỏi về chi tiêu, tasks hay mẹo tiết kiệm…',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Text('→',
                              style: TextStyle(
                                  fontSize: 18, color: AppColors.link)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Giao dịch gần đây ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Giao dịch gần đây',
                          style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      GestureDetector(
                        onTap: () => context.push('/manager/wallet'),
                        child: Text('Xem tất cả →',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.link)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _card(
                    child: walletState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          )
                        : transactions.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    'Chưa có giao dịch nào',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              )
                            : Column(
                                children: transactions
                                    .take(5)
                                    .map(
                                      (tx) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38, height: 38,
                                              decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFFF3F4F6)),
                                              alignment: Alignment.center,
                                              child: Text(
                                                tx.amount > 0 ? '💵' : '💸',
                                                style: const TextStyle(
                                                    fontSize: 18),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tx.description,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .textPrimary),
                                                  ),
                                                  Text(
                                                    tx.entryDate,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${tx.amount > 0 ? '+' : ''}${_fmtBalance(tx.amount)}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: tx.amount > 0
                                                      ? AppColors.success
                                                      : AppColors.danger),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
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
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }
}
