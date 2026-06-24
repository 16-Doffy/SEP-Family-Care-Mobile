import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() {
    return context.read<TaskProvider>().fetchTasks();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
    _loadMonth();
  }

  DateTime? _taskDay(TaskItem task) {
    final raw = task.dueDate ?? task.startAt;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Map<DateTime, List<TaskItem>> _groupTasks(List<TaskItem> tasks) {
    final result = <DateTime, List<TaskItem>>{};
    for (final task in tasks) {
      final day = _taskDay(task);
      if (day == null) continue;
      if (day.year != _visibleMonth.year || day.month != _visibleMonth.month) {
        continue;
      }
      result.putIfAbsent(day, () => <TaskItem>[]).add(task);
    }
    return result;
  }

  List<DateTime?> _calendarCells() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final last = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final leading = first.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      for (var day = 1; day <= last.day; day++)
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _statusLabel(String status) => switch (status.toUpperCase()) {
        'ACTIVE' => 'Đang làm',
        'COMPLETED' || 'DONE' || 'APPROVED' => 'Hoàn thành',
        'SUBMITTED' => 'Chờ duyệt',
        'CANCELED' || 'CANCELLED' => 'Đã hủy',
        'TODO' => 'Cần làm',
        _ => status,
      };

  Color _statusColor(String status) => switch (status.toUpperCase()) {
        'COMPLETED' || 'DONE' || 'APPROVED' => AppColors.success,
        'SUBMITTED' => AppColors.link,
        'CANCELED' || 'CANCELLED' => AppColors.danger,
        _ => AppColors.heroOrange,
      };

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final grouped = _groupTasks(taskState.tasks);
    final selectedTasks = grouped[_selectedDay] ?? const <TaskItem>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMonth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              _header(),
              const SizedBox(height: 14),
              _monthCard(grouped),
              const SizedBox(height: 16),
              _selectedDayCard(selectedTasks, taskState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Text(
            'Lịch gia đình',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _roundButton(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
          const SizedBox(width: 8),
          _roundButton(Icons.chevron_right_rounded, () => _shiftMonth(1)),
        ],
      );

  Widget _roundButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      );

  Widget _monthCard(Map<DateTime, List<TaskItem>> grouped) {
    final cells = _calendarCells();
    final monthLabel = 'Tháng ${_visibleMonth.month}/${_visibleMonth.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final day = cells[index];
              if (day == null) return const SizedBox.shrink();

              final hasTasks = (grouped[day] ?? const <TaskItem>[]).isNotEmpty;
              final selected = _sameDay(day, _selectedDay);
              final today = _sameDay(day, DateTime.now());

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.link : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: today && !selected
                        ? Border.all(color: AppColors.link.withOpacity(0.5))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasTasks
                              ? (selected ? Colors.white : AppColors.heroOrange)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _selectedDayCard(List<TaskItem> tasks, TaskProvider taskState) {
    final label = '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Công việc ngày $label',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/manager/tasks'),
                child: const Icon(Icons.add_circle_rounded, color: AppColors.link),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (taskState.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (taskState.error != null)
            _emptyMessage(taskState.error!)
          else if (tasks.isEmpty)
            _emptyMessage('Không có công việc nào trong ngày này')
          else
            ...tasks.map(_taskTile),
        ],
      ),
    );
  }

  Widget _emptyMessage(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _taskTile(TaskItem task) {
    final color = _statusColor(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(_statusLabel(task.status), color),
                    if (task.assigneeName.isNotEmpty)
                      _chip(task.assigneeName, AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}
