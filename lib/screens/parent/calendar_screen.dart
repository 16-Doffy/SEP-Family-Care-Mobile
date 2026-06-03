import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

// ── EventType enum — color-coding theo FAMILY_CARE_SYSTEM.md Section 9 ─────
// 5 loại sự kiện, mỗi loại một màu riêng để phân biệt trên Calendar
enum EventType {
  task(     '📋 Task',          Color(0xFF2563EB)), // calTask   = planned
  event(    '📅 Sự kiện',       Color(0xFF7C3AED)), // calEvent  = shared
  travel(   '✈️ Du lịch',       Color(0xFF0EA5E9)), // calTravel = cyan (token mới)
  birthday( '🎂 Sinh nhật',     Color(0xFFF59E0B)), // calBirthday = accent/500
  health(   '🏥 Sức khỏe',      Color(0xFFEF4444)); // calHealth = sos

  final String label;
  final Color color;
  const EventType(this.label, this.color);
}

class CalendarEvent {
  final String title;
  final EventType type;
  const CalendarEvent({required this.title, required this.type});
  Color get color => type.color;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focus = DateTime(2026, 5);
  int? _selected;
  bool _showLegend = false;

  // Mock events — colors từ EventType enum (không hard-code màu)
  static const _events = <int, List<CalendarEvent>>{
    3:  [CalendarEvent(title: 'Khám sức khỏe định kỳ',  type: EventType.health)],
    8:  [CalendarEvent(title: 'Sinh nhật Mẹ 🎂',         type: EventType.birthday)],
    15: [
          CalendarEvent(title: 'Họp phụ huynh',          type: EventType.event),
          CalendarEvent(title: 'Dọn nhà cuối tuần',       type: EventType.task),
        ],
    20: [CalendarEvent(title: 'Dã ngoại gia đình 🏕️',   type: EventType.travel)],
    25: [CalendarEvent(title: 'Hạn đóng học phí',        type: EventType.task)],
    28: [CalendarEvent(title: 'Tiệc sinh nhật An 🎉',    type: EventType.birthday)],
  };

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_focus.year, _focus.month);
  int get _firstWeekday =>
      DateTime(_focus.year, _focus.month, 1).weekday % 7; // Sun=0

  // ── Add event dialog ────────────────────────────────────────────────────
  void _showAddEvent() {
    final titleCtrl = TextEditingController();
    EventType selectedType = EventType.event;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('➕  Thêm sự kiện',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              if (_selected != null)
                Text(
                    'Ngày $_selected tháng ${_focus.month}/${_focus.year}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),

              // Tên sự kiện
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.5),
                    borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tên sự kiện...',
                    hintStyle:
                        GoogleFonts.inter(color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),

              // Loại sự kiện (color picker)
              Text('Loại sự kiện',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: EventType.values.map((t) {
                  final sel = selectedType == t;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedType = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? t.color
                            : t.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: sel
                            ? null
                            : Border.all(
                                color: t.color.withValues(alpha: 0.3)),
                      ),
                      child: Text(t.label,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : t.color)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: selectedType.color,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    // TODO: gọi API POST /calendar
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${selectedType.label} "${titleCtrl.text}" đã thêm ✅'),
                        backgroundColor: selectedType.color,
                      ),
                    );
                  },
                  child: Text('Thêm sự kiện',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Text('📅', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Lịch gia đình',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              // Legend toggle
              GestureDetector(
                onTap: () => setState(() => _showLegend = !_showLegend),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _showLegend
                          ? AppColors.link
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _showLegend
                              ? AppColors.link
                              : const Color(0xFFE5E7EB))),
                  child: Text('Chú thích',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showLegend
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() =>
                    _focus = DateTime(_focus.year, _focus.month - 1)),
                child: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.textSecondary),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Tháng ${_focus.month}/${_focus.year}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() =>
                    _focus = DateTime(_focus.year, _focus.month + 1)),
                child: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ),
            ]),
          ),

          // ── Legend (collapsible) ───────────────────────────────
          if (_showLegend)
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]),
              child: Wrap(
                spacing: 16, runSpacing: 8,
                children: EventType.values.map((t) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: t.color,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(t.label,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                )).toList(),
              ),
            ),
          if (_showLegend) const SizedBox(height: 10),

          // ── Calendar grid ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ]),
            child: Column(children: [
              // Day-of-week headers
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: d == 'CN'
                                          ? AppColors.sos
                                          : AppColors.textMuted)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              // Days grid
              Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7, childAspectRatio: 1),
                  itemCount: _firstWeekday + _daysInMonth,
                  itemBuilder: (_, i) {
                    if (i < _firstWeekday) return const SizedBox();
                    final day = i - _firstWeekday + 1;
                    final isToday = today.year == _focus.year &&
                        today.month == _focus.month &&
                        today.day == day;
                    final evts = _events[day] ?? [];
                    final isSel = _selected == day;

                    return GestureDetector(
                      onTap: () => setState(() =>
                          _selected = _selected == day ? null : day),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? AppColors.link
                              : isToday
                                  ? AppColors.link
                                      .withValues(alpha: 0.1)
                                  : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text('$day',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isToday || isSel
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSel
                                        ? Colors.white
                                        : isToday
                                            ? AppColors.link
                                            : AppColors.textPrimary)),
                            // Dot indicators cho mỗi event type (max 3)
                            if (evts.isNotEmpty)
                              Positioned(
                                bottom: 3,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: evts
                                      .take(3)
                                      .map((e) => Container(
                                            width: 4, height: 4,
                                            margin: const EdgeInsets
                                                .symmetric(horizontal: 1),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSel
                                                  ? Colors.white
                                                  : e.color,
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Event list ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selected != null
                        ? 'Ngày $_selected tháng ${_focus.month}'
                        : 'Sự kiện tháng ${_focus.month}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted),
                  ),
                ),
                ..._buildEventList(),
              ],
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEvent,
        backgroundColor: AppColors.link,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  List<Widget> _buildEventList() {
    final map = _selected != null
        ? {_selected!: _events[_selected] ?? <CalendarEvent>[]}
        : _events;

    if (map.isEmpty ||
        (map.length == 1 && map.values.first.isEmpty)) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text('Không có sự kiện',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textMuted)),
          ),
        )
      ];
    }

    final List<Widget> widgets = [];
    final sortedDays = map.keys.toList()..sort();

    for (final day in sortedDays) {
      final evts = map[day]!;
      if (evts.isEmpty) continue;
      for (final e in evts) {
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: e.color, width: 4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(e.type.label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: e.color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(
                          'Ngày $day tháng ${_focus.month}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            ]),
          ),
        ));
      }
    }
    return widgets;
  }
}
