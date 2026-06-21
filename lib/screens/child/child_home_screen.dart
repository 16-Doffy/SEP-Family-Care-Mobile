import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';

const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});
  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late List<Animation<double>> _barAnims;
  double _ringP = 0;
  Timer? _ringTimer;

  // Sẽ được tính từ tasks thực tế theo ngày trong tuần
  List<double> _barData = List.filled(7, 0);

  @override
  void initState() {
    super.initState();

    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _barAnims = List.generate(7, (_) => Tween<double>(begin: 0, end: 0).animate(_barCtrl));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        context.read<TaskProvider>().fetchMyAssignments(),
        context.read<FinanceProvider>().fetchAll(),
        context.read<NotificationProvider>().fetchNotifications(),
      ]);
      if (mounted) _buildBarData();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    _ringTimer?.cancel();
    super.dispose();
  }

  void _buildBarData() {
    final tasks = context.read<TaskProvider>().tasks;
    final now = DateTime.now();
    // Đếm tasks completed/submitted theo ngày trong tuần (T2=0 ... CN=6)
    final counts = List<int>.filled(7, 0);
    final totals = List<int>.filled(7, 0);
    for (final t in tasks) {
      // updatedAt hoặc dùng index hiện tại
      final dayIdx = (now.weekday - 1) % 7; // 0=Mon..6=Sun
      totals[dayIdx]++;
      if (['APPROVED', 'DONE', 'SUBMITTED'].contains(t.status.toUpperCase())) {
        counts[dayIdx]++;
      }
    }
    final maxTotal = totals.reduce((a, b) => a > b ? a : b);
    setState(() {
      _barData = List.generate(7, (i) => maxTotal > 0 ? totals[i] / maxTotal : 0.05);
      _barAnims = _barData.map((v) => Tween<double>(begin: 0, end: v.clamp(0.05, 1.0)).animate(
        CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut),
      )).toList();
    });
    _barCtrl.forward(from: 0);
  }

  String _fmtMoney(double n) {
    if (n == 0) return '0 ₫';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M ₫';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K ₫';
    return '${n.round()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final taskProv = context.watch<TaskProvider>();
    final finance = context.watch<FinanceProvider>();
    final notifProv = context.watch<NotificationProvider>();

    final allTasks = taskProv.tasks;
    final todayTasks = allTasks.take(3).toList();
    final doneTasks = allTasks.where((t) {
      final u = t.status.toUpperCase();
      return u == 'APPROVED' || u == 'DONE';
    }).toList();

    final mf = finance.monthlyFinance;
    final myIncome = mf?.actualIncome ?? 0;
    final taskProgress = allTasks.isEmpty ? 0.0 : doneTasks.length / allTasks.length;

    final unreadCount = notifProv.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<TaskProvider>().fetchMyAssignments(),
            context.read<FinanceProvider>().fetchAll(),
            context.read<NotificationProvider>().fetchNotifications(),
          ]);
        },
        child: ListView(
          children: [
            // Dark header with bar chart
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
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chào ${user?.name ?? "bạn"}! 🔥', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(999)),
                          child: Text('📋 ${allTasks.length} nhiệm vụ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ]),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                            alignment: Alignment.center,
                            child: const Text('🔔', style: TextStyle(fontSize: 20)),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: 6, right: 6,
                              child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger)),
                            ),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bar chart (decorative activity visualization)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hoạt động tuần này', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        AnimatedBuilder(
                          animation: _barCtrl,
                          builder: (_, __) => SizedBox(
                            height: 80,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) {
                                final pct = _barAnims.length > i ? _barAnims[i].value : 0.05;
                                return Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: pct.clamp(0.05, 1.0),
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                              decoration: BoxDecoration(color: AppColors.heroOrange, borderRadius: BorderRadius.circular(4)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_dayLabels[i], style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress ring + stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  RingChart(
                    progress: taskProgress,
                    size: 140,
                    strokeWidth: 14,
                    color: AppColors.heroOrange,
                    trackColor: const Color(0xFFF3F4F6),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${doneTasks.length}/${allTasks.length}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('tasks', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tiến độ nhiệm vụ', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${doneTasks.length} hoàn thành / ${allTasks.length} tổng', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        Text('${allTasks.length - doneTasks.length} việc còn lại', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.go('/member/wallet'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                                child: Column(children: [
                                  const Text('💰', style: TextStyle(fontSize: 18)),
                                  Text(
                                    myIncome > 0 ? _fmtMoney(myIncome) : 'Sổ chi tiêu',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.link),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/ai'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                                child: Column(children: [
                                  const Text('🤖', style: TextStyle(fontSize: 18)),
                                  Text('AI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
                                ]),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Today's tasks (real data)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Tasks hôm nay', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    GestureDetector(
                      onTap: () => context.go('/member/tasks'),
                      child: Text('Xem tất cả →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (taskProv.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (allTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20)),
                      child: Center(child: Text('Chưa có nhiệm vụ nào 🎉', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                    )
                  else
                    ...todayTasks.map((task) => _taskCard(task)),
                  if (allTasks.length > 3)
                    GestureDetector(
                      onTap: () => context.go('/member/tasks'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('+ ${allTasks.length - 3} nhiệm vụ khác', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.link)),
                      ),
                    ),
                ],
              ),
            ),

            // Completed tasks (recent)
            if (doneTasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đã hoàn thành', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ...doneTasks.take(3).map((t) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        const Text('✅', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          if (t.categoryName != null)
                            Text(t.categoryName!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ])),
                        if (t.reward > 0)
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('+${_fmtMoney(t.reward)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ]),
                      ]),
                    )),
                  ],
                ),
              ),

            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(TaskItem task) {
    final isPending = ['PENDING', 'TODO', 'IN_PROGRESS'].contains(task.status.toUpperCase());
    final isSubmitted = task.status.toUpperCase() == 'SUBMITTED';

    return GestureDetector(
      onTap: () => context.go('/member/tasks'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: isPending ? AppColors.heroOrange : AppColors.safe, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  if (task.reward > 0)
                    _chip('💰 ${_fmtMoney(task.reward)}', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                  if (isSubmitted)
                    _chip('⏳ Chờ duyệt', const Color(0xFFEFF6FF), AppColors.planned),
                ]),
              ],
            ),
          ),
          if (isPending)
            GestureDetector(
              onTap: () => context.go('/member/tasks'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.heroOrange, borderRadius: BorderRadius.circular(999)),
                child: Text('Làm ngay →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDCFCE7)),
              alignment: Alignment.center,
              child: const Text('✓', style: TextStyle(color: AppColors.success, fontSize: 20)),
            ),
        ],
      ),
    ));
  }

  Widget _chip(String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
