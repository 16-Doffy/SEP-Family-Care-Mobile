import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focus = DateTime(2026, 5);
  int? _selected;

  static const _events = <int, List<({String title, Color color})>>{
    3:  [(title: 'Khám sức khỏe định kỳ', color: AppColors.planned)],
    8:  [(title: 'Sinh nhật Mẹ 🎂', color: AppColors.income)],
    15: [(title: 'Họp phụ huynh', color: AppColors.shared), (title: 'Dọn nhà cuối tuần', color: AppColors.safe)],
    20: [(title: 'Dã ngoại gia đình 🏕️', color: AppColors.income)],
    25: [(title: 'Hạn đóng học phí', color: AppColors.sos)],
    28: [(title: 'Tiệc sinh nhật An 🎉', color: AppColors.avatarOrange)],
  };

  int get _daysInMonth => DateUtils.getDaysInMonth(_focus.year, _focus.month);
  int get _firstWeekday => DateTime(_focus.year, _focus.month, 1).weekday % 7; // Sun=0

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Text('📅', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Flexible(child: Text('Lịch gia đình', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _focus = DateTime(_focus.year, _focus.month - 1)),
                  child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Tháng ${_focus.month}/${_focus.year}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _focus = DateTime(_focus.year, _focus.month + 1)),
                  child: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ),
              ]),
            ),

            // Calendar grid
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
              child: Column(children: [
                // Day-of-week headers
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'].map((d) => Expanded(
                      child: Center(child: Text(d, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: d == 'CN' ? AppColors.sos : AppColors.textMuted))),
                    )).toList(),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                // Days grid
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
                    itemCount: _firstWeekday + _daysInMonth,
                    itemBuilder: (_, i) {
                      if (i < _firstWeekday) return const SizedBox();
                      final day = i - _firstWeekday + 1;
                      final isToday = today.year == _focus.year && today.month == _focus.month && today.day == day;
                      final hasEvent = _events.containsKey(day);
                      final isSel = _selected == day;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = _selected == day ? null : day),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? AppColors.link : isToday ? AppColors.link.withOpacity(0.1) : null,
                          ),
                          child: Stack(alignment: Alignment.center, children: [
                            Text('$day', style: GoogleFonts.inter(fontSize: 13, fontWeight: isToday || isSel ? FontWeight.w700 : FontWeight.w400, color: isSel ? Colors.white : isToday ? AppColors.link : AppColors.textPrimary)),
                            if (hasEvent) Positioned(bottom: 4, child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? Colors.white : (_events[day]!.first.color)))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Event list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_selected != null ? 'Ngày $_selected tháng ${_focus.month}' : 'Sự kiện tháng ${_focus.month}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                  ..._buildEventList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.link,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  List<Widget> _buildEventList() {
    final map = _selected != null
        ? {_selected!: _events[_selected] ?? []}
        : _events;

    if (map.isEmpty || (map.length == 1 && map.values.first.isEmpty)) {
      return [Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text('Không có sự kiện', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))))];
    }

    final List<Widget> widgets = [];
    final sortedDays = map.keys.toList()..sort();
    for (final day in sortedDays) {
      final evts = map[day]!;
      if (evts.isEmpty) continue;
      for (final e in evts) {
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: e.color, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('Ngày $day tháng ${_focus.month}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ]),
        ));
      }
    }
    return widgets;
  }
}
