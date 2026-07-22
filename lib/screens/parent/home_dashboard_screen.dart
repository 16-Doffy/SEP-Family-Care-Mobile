import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/ai_chatbot_icon.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/family_status_card.dart';

// Nhãn badge chuông: quá 99 thì rút gọn để không phá layout.
String _unreadLabel(int n) => n > 99 ? '99+' : '$n';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  // StatefulShellRoute.indexedStack pre-builds all branches before login,
  // so initState may run when familyId is still null.
  // We keep a listener on AuthProvider to re-fetch once familyId is available.
  AuthProvider? _authListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      _authListener = context.read<AuthProvider>()..addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    if (mounted && (context.read<AuthProvider>().hasFamily)) {
      _fetchAll();
    }
  }

  void _fetchAll() {
    if (!mounted) return;
    context.read<WalletProvider>().fetchWallets();
    context.read<TaskProvider>().fetchTasks();
    context.read<FamilyProvider>().fetchMembers();
    context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  void dispose() {
    _authListener?.removeListener(_onAuthChanged);
    super.dispose();
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
    final user = context.watch<AuthProvider>().user;
    final walletState = context.watch<WalletProvider>();
    final taskState = context.watch<TaskProvider>();

    // Màn này dùng chung cho Manager VÀ Deputy, nên phím tắt phải trỏ vào shell
    // của đúng role: hardcode /manager/* sẽ khiến Deputy bị redirect về home.
    final seg = user?.role == UserRole.deputy ? 'deputy' : 'manager';

    final balance = walletState.familyWallet?.balance ?? 0.0;
    final transactions = walletState.transactions;
    final tasks = taskState.tasks;
    final doneTasks = tasks.where((t) => t.status == 'COMPLETED').length;
    final totalTasks = tasks.length;
    final taskPct = totalTasks > 0 ? doneTasks / totalTasks : 0.0;

    // income delta từ tháng trước — tính từ income transactions
    final totalIn = transactions
        .where((t) => t.entryType == 'INCOME')
        .fold(0.0, (s, t) => s + t.amount.abs());

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: 120,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGlow,
              ),
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
                  if (context
                      .watch<AuthProvider>()
                      .pendingEmailVerification) ...[
                    _verifyEmailBanner(context),
                    const SizedBox(height: 12),
                  ],

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
                              'Xin chào, ${user?.name ?? "Trưởng nhóm"}',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Gia đình ${user?.familyName ?? "Nguyễn"} · Hôm nay',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                size: 20,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (context
                                    .watch<NotificationProvider>()
                                    .unreadCount >
                                0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.notification,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _unreadLabel(
                                      context
                                          .watch<NotificationProvider>()
                                          .unreadCount,
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Trạng thái gia đình (ai đang SOS) ───────────
                  const FamilyStatusCard(),
                  const SizedBox(height: 20),

                  // ── Hero Wallet Card ────────────────────────────
                  GestureDetector(
                    onTap: () => context.go('/$seg/wallet'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.heroOrange, AppColors.heroPurple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 44,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: walletState.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quỹ Gia Đình',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fmtBalance(balance),
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (totalIn > 0)
                                  Text(
                                    '↑ +${_fmtBalance(totalIn)} tháng này',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDCFCE7),
                                    ),
                                  )
                                else
                                  Text(
                                    'Tap để xem chi tiết ví',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white54,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick Actions ───────────────────────────────
                  Row(
                    children: [
                      _quickCard(
                        Icons.task_alt_rounded,
                        'Nhiệm vụ',
                        () => context.go('/$seg/tasks'),
                      ),
                      const SizedBox(width: 12),
                      _quickCard(
                        Icons.groups_2_outlined,
                        'Thành viên',
                        () => context.push('/manager/members'),
                      ),
                      const SizedBox(width: 12),
                      _quickCard(
                        Icons.savings_outlined,
                        'Ngân sách',
                        () => context.push('/manager/finance-model'),
                      ),
                      const SizedBox(width: 12),
                      if (user?.canInviteMembers ?? false) ...[
                        _quickCard(
                          Icons.person_add_alt_rounded,
                          'Mời',
                          () => context.push('/manager/invite'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      _quickCard(
                        Icons.map_outlined,
                        'Bản đồ',
                        () => context.go('/$seg/map'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Stats Row ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.go('/$seg/tasks'),
                          child: _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment_outlined,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Nhiệm vụ',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                taskState.loading
                                    ? Text(
                                        'Đang tải...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      )
                                    : Text(
                                        '$doneTasks / $totalTasks hoàn thành',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: taskPct,
                                          minHeight: 8,
                                          backgroundColor:
                                              AppColors.progressTrack,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                AppColors.success,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${(taskPct * 100).round()}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
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
                            child: Consumer<FamilyProvider>(
                              builder: (_, familyState, _) {
                                final members = familyState.members;
                                final colors = [
                                  AppColors.avatarPurple,
                                  AppColors.avatarOrange,
                                  AppColors.avatarBlue,
                                  AppColors.avatarTeal,
                                ];
                                final shown = members.take(3).toList();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          size: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${members.length} thành viên',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Trong gia đình',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (shown.isEmpty)
                                      Text(
                                        'Chưa có thành viên',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      )
                                    else
                                      Row(
                                        children: shown.asMap().entries.map((
                                          e,
                                        ) {
                                          final offset = e.key * -10.0;
                                          final initial =
                                              (e.value.name.isNotEmpty
                                                      ? e.value.name[0]
                                                      : '?')
                                                  .toUpperCase();
                                          return Transform.translate(
                                            offset: Offset(offset, 0),
                                            child: AvatarWidget(
                                              initial: initial,
                                              color:
                                                  colors[e.key % colors.length],
                                              size: 28,
                                              showPresence: true,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                );
                              },
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
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const AiChatbotIcon(size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trợ lý AI',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Hỏi về chi tiêu, nhiệm vụ hay mẹo tiết kiệm…',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '→',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.link,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Giao dịch gần đây ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao dịch gần đây',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/$seg/wallet'),
                        child: Text(
                          'Xem tất cả →',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.link,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _card(
                    child: walletState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : transactions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Chưa có giao dịch nào',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: transactions
                                .take(5)
                                .map(
                                  (tx) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFFF3F4F6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            tx.signedAmount > 0
                                                ? Icons.trending_up_rounded
                                                : Icons.trending_down_rounded,
                                            size: 20,
                                            color: tx.signedAmount > 0
                                                ? AppColors.success
                                                : AppColors.danger,
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
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                tx.displayEntryDate,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${tx.signedAmount > 0 ? '+' : '-'}${_fmtBalance(tx.signedAmount.abs())}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: tx.signedAmount > 0
                                                ? AppColors.success
                                                : AppColors.danger,
                                          ),
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

  Widget _quickCard(IconData icon, String label, VoidCallback onTap) {
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
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppFeatureIcon(
                icon: icon,
                color: AppColors.link,
                backgroundColor: AppColors.link.withValues(alpha: 0.08),
                size: 38,
                iconSize: 20,
                radius: 12,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _verifyEmailBanner(BuildContext context) {
    final currentUri = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.toString();
    return InkWell(
      onTap: () => context.push(
        '/verify-email?returnTo=${Uri.encodeComponent(currentUri)}',
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 20,
              color: Color(0xFF92400E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Email chưa xác thực. Xác thực ngay để dùng đầy đủ tính năng.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF92400E),
            ),
          ],
        ),
      ),
    );
  }
}
