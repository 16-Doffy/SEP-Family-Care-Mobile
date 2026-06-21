import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';

const _barData    = [40, 80, 60, 100, 75, 50, 90]; // placeholder weekly XP
const _dayLabels  = ['T2','T3','T4','T5','T6','T7','CN'];

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});
  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late List<Animation<double>> _barAnims;
  Timer? _xpTimer;
  int _displayXp = 0;
  double _ringP   = 0;

  // placeholder XP until gamification API is available
  static const _xp      = 0;
  static const _xpToNext = 500;
  static const _level   = 1;

  AuthProvider? _authListener;

  @override
  void initState() {
    super.initState();

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _barAnims = _barData
        .map((v) => Tween<double>(begin: 0, end: v / 100.0).animate(
              CurvedAnimation(
                  parent: _barCtrl,
                  curve: const Interval(0, 1, curve: Curves.easeOut)),
            ))
        .toList();
    Future.delayed(
        const Duration(milliseconds: 200), () => _barCtrl.forward());

    final start = DateTime.now();
    const dur = Duration(milliseconds: 900);
    _xpTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final elapsed  = DateTime.now().difference(start);
      final progress =
          (elapsed.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        _displayXp = (_xp * progress).round();
        _ringP     = (_xp / _xpToNext) * progress;
      });
      if (progress >= 1.0) t.cancel();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      _authListener =
          context.read<AuthProvider>()..addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    if (mounted && context.read<AuthProvider>().hasFamily) _fetchAll();
  }

  void _fetchAll() {
    if (!mounted) return;
    context.read<TaskProvider>().fetchMyAssignments();
    context.read<WalletProvider>().fetchWallets();
  }

  @override
  void dispose() {
    _barCtrl.dispose();
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
    final user        = context.watch<AuthProvider>().user;
    final taskState   = context.watch<TaskProvider>();
    final walletState = context.watch<WalletProvider>();

    final myTasks   = taskState.myAssignments;
    final doneTasks = myTasks.where((t) => t.status == 'APPROVED').length;
    final pending   = myTasks.where((t) => t.status != 'APPROVED').toList();
    final balance   = walletState.totalBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    end: Alignment.bottomCenter),
              ),
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              child: Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Chào ${user?.name ?? "bạn"}! 🔥',
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(user?.familyName ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white60)),
                    ]),
                    const Spacer(),
                    Stack(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15)),
                          alignment: Alignment.center,
                          child: const Text('🔔',
                              style: TextStyle(fontSize: 20))),
                      Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.danger))),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekly XP bar chart (placeholder)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('XP tuần này',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _barCtrl,
                      builder: (_, _) => SizedBox(
                        height: 80,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(_barData.length, (i) {
                            final pct   = _barAnims[i].value;
                            final xpVal = (_barData[i] * 0.8).round();
                            return Expanded(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                Text('${xpVal}XP',
                                    style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white70)),
                                const SizedBox(height: 2),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: pct.clamp(0.02, 1.0),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.heroOrange,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(_dayLabels[i],
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: Colors.white38)),
                              ]),
                            );
                          }),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── XP Ring + balance ────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(children: [
                RingChart(
                  progress: _ringP,
                  size: 140, strokeWidth: 14,
                  color: AppColors.heroOrange,
                  trackColor: const Color(0xFFF3F4F6),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text('$_displayXp',
                        style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('XP',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('⭐ Cấp $_level',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$_displayXp / $_xpToNext XP',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    Text('Còn ${_xpToNext - _xp} XP → Cấp ${_level + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/member/wallet'),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [
                              const Text('💰',
                                  style: TextStyle(fontSize: 18)),
                              Text(
                                  walletState.isLoading
                                      ? '...'
                                      : _fmtBalance(balance),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.link)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/ai'),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [
                              const Text('🤖',
                                  style: TextStyle(fontSize: 18)),
                              Text('AI',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD97706))),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),

            // ── Tasks section ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('Tasks hôm nay',
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (taskState.loading)
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Text('${pending.length} còn lại',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                ]),
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
                              offset: const Offset(0, 4))
                        ]),
                    child: Center(
                      child: Column(children: [
                        const Text('📋', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text('Chưa có task nào được giao',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted)),
                      ]),
                    ),
                  )
                else
                  ...myTasks.take(5).map((t) => _taskCard(t)),

                if (doneTasks > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text('✅ Đã hoàn thành $doneTasks task',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
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
                width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(task.taskTitle ?? task.task?.title ?? '',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if ((task.rewardSetting ?? task.task?.rewardSetting) != null)
                _chip(
                    '💰 ${(task.rewardSetting ?? task.task!.rewardSetting!).label}',
                    const Color(0xFFDCFCE7),
                    const Color(0xFF16A34A)),
              if (task.task?.schedule != null)
                _chip('🕐 ${task.task!.schedule!.label}',
                    const Color(0xFFEFF6FF), AppColors.link),
              if (task.status == 'SUBMITTED')
                _chip('⏳ Chờ duyệt',
                    const Color(0xFFFEF3C7), const Color(0xFFD97706)),
            ]),
          ]),
        ),
        if (isDone)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFDCFCE7)),
            alignment: Alignment.center,
            child: const Text('✓',
                style: TextStyle(
                    color: AppColors.success, fontSize: 20)),
          )
        else
          GestureDetector(
            onTap: () => context.push('/member/tasks'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.heroOrange,
                  borderRadius: BorderRadius.circular(999)),
              child: Text('Làm ngay →',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  Widget _chip(String label, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}
