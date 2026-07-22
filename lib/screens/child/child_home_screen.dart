import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/ai_chatbot_icon.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/family_status_card.dart';
import '../../widgets/ring_chart.dart';

// Nhãn badge chuông: quá 99 thì rút gọn để không phá layout.
String _unreadLabel(int n) => n > 99 ? '99+' : '$n';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});
  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  Timer? _xpTimer;
  int _displayXp = 0;
  double _ringP = 0;

  // placeholder XP until gamification API is available
  static const _xp = 0;
  static const _xpToNext = 500;
  static const _level = 1;

  AuthProvider? _authListener;

  @override
  void initState() {
    super.initState();

    final start = DateTime.now();
    const dur = Duration(milliseconds: 900);
    _xpTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final elapsed = DateTime.now().difference(start);
      final progress = (elapsed.inMilliseconds / dur.inMilliseconds).clamp(
        0.0,
        1.0,
      );
      setState(() {
        _displayXp = (_xp * progress).round();
        _ringP = (_xp / _xpToNext) * progress;
      });
      if (progress >= 1.0) t.cancel();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      _authListener = context.read<AuthProvider>()..addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    if (mounted && context.read<AuthProvider>().hasFamily) _fetchAll();
  }

  void _fetchAll() {
    if (!mounted) return;
    context.read<TaskProvider>().fetchMyAssignments();
    context.read<WalletProvider>().fetchWallets();
    context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
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
    final taskState = context.watch<TaskProvider>();
    final walletState = context.watch<WalletProvider>();

    final myTasks = taskState.myAssignments;
    final doneTasks = myTasks.where((t) => t.status == 'APPROVED').length;
    final pending = myTasks.where((t) => t.status != 'APPROVED').toList();
    final balance = walletState.totalBalance;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<TaskProvider>().fetchMyAssignments(),
          context.read<WalletProvider>().fetchWallets(),
        ]),
        child: ListView(
          children: [
            // ── Dark header ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào ${user?.name ?? "bạn"}!',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.familyName ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                            if (context
                                    .watch<NotificationProvider>()
                                    .unreadCount >
                                0)
                              Positioned(
                                top: 2,
                                right: 2,
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
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white,
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
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // (Đã bỏ chart "XP tuần này" — dữ liệu placeholder hardcode,
                  // mâu thuẫn với vòng XP thật 0/500 bên dưới. Làm lại khi BE
                  // có API gamification.)
                ],
              ),
            ),
            if (context.watch<AuthProvider>().pendingEmailVerification)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _verifyEmailBanner(context),
              ),

            // ── Trạng thái gia đình (ai đang SOS) ────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: FamilyStatusCard(),
            ),

            // ── XP Ring + balance ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  RingChart(
                    progress: _ringP,
                    size: 140,
                    strokeWidth: 14,
                    color: AppColors.heroOrange,
                    trackColor: const Color(0xFFF3F4F6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_displayXp',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'điểm',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: AppColors.accent500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cấp $_level',
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
                          '$_displayXp / $_xpToNext điểm',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Còn ${_xpToNext - _xp} điểm để lên Cấp ${_level + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                // go() chứ KHÔNG push(): đây là branch của
                                // shell, push sẽ dựng shell thứ hai dùng chung
                                // GlobalKey của nhánh → crash Navigator.
                                onTap: () => context.go('/member/wallet'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const AppFeatureIcon(
                                        icon: Icons.account_balance_wallet_outlined,
                                        color: AppColors.link,
                                        backgroundColor: Colors.transparent,
                                        size: 26,
                                        iconSize: 22,
                                        radius: 10,
                                      ),
                                      Text(
                                        walletState.isLoading
                                            ? '...'
                                            : _fmtBalance(balance),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.link,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context.push('/ai'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const AiChatbotIcon(size: 24),
                                      Text(
                                        'Trợ lý',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context.push('/album'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const AppFeatureIcon(
                                        icon: Icons.photo_library_outlined,
                                        color: AppColors.link,
                                        backgroundColor: Colors.transparent,
                                        size: 26,
                                        iconSize: 22,
                                        radius: 10,
                                      ),
                                      Text(
                                        'Ảnh',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.link,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Lịch — route phẳng, Member vào để xem sự kiện gia
                            // đình và phản hồi tham gia (Tham gia/Có thể/Từ
                            // chối). Không có quyền tạo/sửa/hủy.
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context.go('/member/calendar'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const AppFeatureIcon(
                                        icon: Icons.calendar_month_outlined,
                                        color: AppColors.link,
                                        backgroundColor: Colors.transparent,
                                        size: 26,
                                        iconSize: 22,
                                        radius: 10,
                                      ),
                                      Text(
                                        'Lịch',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.link,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Nhiệm vụ hôm nay ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nhiệm vụ hôm nay',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (taskState.loading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          '${pending.length} còn lại',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (taskState.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (myTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Center(
                        child: Column(
                          children: [
                            const AppFeatureIcon(
                              icon: Icons.task_alt_rounded,
                              color: AppColors.link,
                              size: 48,
                              iconSize: 26,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có nhiệm vụ nào được giao',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...myTasks.take(5).map((t) => _taskCard(t)),

                  if (doneTasks > 0) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Đã hoàn thành $doneTasks nhiệm vụ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(TaskAssignment task) {
    final isDone = task.status == 'APPROVED';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
            color: isDone ? AppColors.success : AppColors.heroOrange,
            width: 4,
          ),
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle ?? task.task?.title ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if ((task.rewardSetting ?? task.task?.rewardSetting) !=
                        null)
                      _chip(
                        'Thưởng: ${(task.rewardSetting ?? task.task!.rewardSetting!).label}',
                        const Color(0xFFDCFCE7),
                        const Color(0xFF16A34A),
                      ),
                    if (task.task?.schedule != null)
                      _chip(
                        'Lịch: ${task.task!.schedule!.label}',
                        const Color(0xFFEFF6FF),
                        AppColors.link,
                      ),
                    if (task.status == 'SUBMITTED')
                      _chip(
                        'Chờ duyệt',
                        const Color(0xFFFEF3C7),
                        const Color(0xFFD97706),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isDone)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCFCE7),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 22,
              ),
            )
          else
            GestureDetector(
              onTap: () => context.go('/member/tasks'), // shell branch → go()
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.heroOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Làm ngay →',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

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
