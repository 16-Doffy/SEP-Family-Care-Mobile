import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/calendar_provider.dart';
import '../wear_widgets.dart';

class WearCalendarScreen extends StatefulWidget {
  const WearCalendarScreen({super.key});

  @override
  State<WearCalendarScreen> createState() => _WearCalendarScreenState();
}

class _WearCalendarScreenState extends State<WearCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CalendarProvider>().fetchBootstrap(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final now = DateTime.now();
    final upcoming = calendar.events
        .where((e) => e.status != 'CANCELED' && e.startTime.isAfter(now))
        .take(6)
        .toList();

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            color: WearPalette.violet,
            trailing: calendar.loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.violet,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (calendar.error != null) ...[
            Text(
              calendar.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 6),
          ],
          if (calendar.loading && upcoming.isEmpty)
            const WearEmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang tải lịch',
              color: WearPalette.violet,
            )
          else if (upcoming.isEmpty)
            const WearEmptyState(
              icon: Icons.event_available_rounded,
              title: 'Không có lịch',
              subtitle: 'Mở mobile để xem tháng',
              color: WearPalette.green,
            )
          else
            ...upcoming.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: WearTile(
                  icon: Icons.event_note_rounded,
                  title: event.title,
                  subtitle: _subtitle(event),
                  color: _eventColor(event),
                  filled: _isToday(event.startTime),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle(FamilyCalendarEvent event) {
    final date = _dateLabel(event.startTime);
    final location = event.location;
    if (location != null && location.isNotEmpty) {
      return '$date - ${event.timeLabel} - $location';
    }
    return '$date - ${event.timeLabel}';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Hôm nay';
    if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Ngày mai';
    return '${date.day}/${date.month}';
  }

  bool _isToday(DateTime date) => _sameDay(date, DateTime.now());

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _eventColor(FamilyCalendarEvent event) {
    return switch (event.typeLabel) {
      'Task' => WearPalette.amber,
      'Sức khỏe' => WearPalette.sosSoft,
      'Du lịch' => WearPalette.blue,
      'Sinh nhật' => WearPalette.green,
      _ => WearPalette.violet,
    };
  }
}
