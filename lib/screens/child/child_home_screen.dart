import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';

const _barData = [40, 80, 60, 100, 75, 50, 90];
const _dayLabels = ['T2','T3','T4','T5','T6','T7','CN'];
const _xp = 360;
const _xpToNext = 500;
const _level = 3;

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});
  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late List<Animation<double>> _barAnims;
  int _displayXp = 0;
  double _ringP = 0;
  Timer? _xpTimer;

  final _tasks = [
    _TaskItem('1', 'Dọn phòng ngủ', 50, 20000, 'Nhà cửa', AppColors.planned, false, false),
    _TaskItem('2', 'Rửa bát sau bữa tối', 30, 10000, 'Nhà cửa', AppColors.planned, true, false),
    _TaskItem('3', 'Học bài 1 tiếng', 80, 30000, 'Học tập', const Color(0xFFF59E0B), false, false),
  ];

  @override
  void initState() {
    super.initState();

    // Bar grow animation
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _barAnims = _barData.map((v) => Tween<double>(begin: 0, end: v / 100.0).animate(
      CurvedAnimation(parent: _barCtrl, curve: const Interval(0, 1, curve: Curves.easeOut)),
    )).toList();

    Future.delayed(const Duration(milliseconds: 200), () => _barCtrl.forward());

    // XP count-up + ring
    final start = DateTime.now();
    const dur = Duration(milliseconds: 900);
    _xpTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final elapsed = DateTime.now().difference(start);
      final progress = (elapsed.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        _displayXp = (_xp * progress).round();
        _ringP = (_xp / _xpToNext) * progress;
      });
      if (progress >= 1.0) t.cancel();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    _xpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        children: [
          // Dark header with bar chart
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF111827)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Chào ${user?.name ?? "An"}! 🔥', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(999)),
                        child: Text('🔥 5 ngày liên tiếp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ]),
                    const Spacer(),
                    Stack(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)), alignment: Alignment.center, child: const Text('🔔', style: TextStyle(fontSize: 20))),
                      Positioned(top: 6, right: 6, child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger))),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Bar chart with animation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('XP tuần này', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _barCtrl,
                        builder: (_, _) => SizedBox(
                          height: 80,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(_barData.length, (i) {
                              final pct = _barAnims[i].value;
                              final xpVal = (_barData[i] * 0.8).round();
                              return Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${xpVal}XP', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          heightFactor: pct.clamp(0.02, 1.0),
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

          // XP Ring + Level
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
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$_displayXp', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('XP', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⭐ Cấp $_level', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('$_displayXp / $_xpToNext XP', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      Text('Còn ${_xpToNext - _xp} XP → Cấp ${_level + 1}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: GestureDetector(onTap: () => context.push('/member/wallet'), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)), child: Column(children: [const Text('💰', style: TextStyle(fontSize: 18)), Text('120K ₫', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.link))])))),
                        const SizedBox(width: 8),
                        Expanded(child: GestureDetector(onTap: () => context.push('/ai'), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)), child: Column(children: [const Text('🤖', style: TextStyle(fontSize: 18)), Text('AI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)))])))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Tasks hôm nay', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('${_tasks.where((t) => !t.submitted).length} còn lại', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ]),
                const SizedBox(height: 12),
                ..._tasks.map((task) => _taskCard(task)),
              ],
            ),
          ),

          // Rewards
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phần thưởng gần đây', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ...[
                  ('⭐', 'Dọn phòng ngủ', '+50 XP', '+20,000 ₫', 'Hôm qua'),
                  ('📚', 'Học bài 2 tiếng', '+80 XP', '+30,000 ₫', '19/05'),
                ].map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                  child: Row(children: [
                    Text(r.$1, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.$2, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(r.$5, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(r.$3, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
                      Text(r.$4, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ]),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _taskCard(_TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: task.categoryColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
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
                  _chip('⚡ ${task.xp} XP', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                  _chip('💰 ${(task.reward/1000).toStringAsFixed(0)}K', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                  if (task.submitted) _chip('⏳ Chờ duyệt', const Color(0xFFEFF6FF), AppColors.planned),
                ]),
              ],
            ),
          ),
          if (!task.submitted)
            GestureDetector(
              onTap: () => setState(() { final idx = _tasks.indexOf(task); _tasks[idx] = _TaskItem(task.id, task.title, task.xp, task.reward, task.category, task.categoryColor, !task.doing, task.doing); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: task.doing ? AppColors.link : AppColors.heroOrange, borderRadius: BorderRadius.circular(999)),
                child: Text(task.doing ? 'Nộp bài ✓' : 'Làm ngay →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else
            Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDCFCE7)), alignment: Alignment.center, child: const Text('✓', style: TextStyle(color: AppColors.success, fontSize: 20))),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
  }
}

class _TaskItem {
  final String id, title, category;
  final int xp, reward;
  final Color categoryColor;
  final bool doing, submitted;
  const _TaskItem(this.id, this.title, this.xp, this.reward, this.category, this.categoryColor, this.doing, this.submitted);
}
