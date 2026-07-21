import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';

const _calendarDivider = AppColors.progressTrack;
const _calendarInputFill = AppColors.background;
const _calendarInputBorder = AppColors.progressTrack;

const _calendarTaskColor = AppColors.primary500;
const _calendarEventColor = AppColors.shared;
const _calendarTravelColor = AppColors.calTravel;
const _calendarBirthdayColor = AppColors.accent500;
const _calendarHealthColor = AppColors.sos;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focus;
  int? _selected;
  bool _showLegend = false;

  int get _daysInMonth => DateUtils.getDaysInMonth(_focus.year, _focus.month);
  int get _firstWeekday => DateTime(_focus.year, _focus.month, 1).weekday % 7;

  /// Manager/Deputy mới được tạo/sửa/hủy event. Member chỉ xem và phản hồi
  /// tham gia — BE cũng chặn tương ứng, gate ở FE để không hiện nút chết.
  bool get _canManage =>
      context.read<AuthProvider>().user?.canManageCalendar ?? false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focus = DateTime(now.year, now.month);
    _selected = now.day;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final family = context.read<FamilyProvider>();
    await Future.wait([
      context.read<CalendarProvider>().fetchBootstrap(_focus),
      // Cần cho ô chọn người tham gia; chỉ tải một lần vì danh sách ít đổi.
      if (family.members.isEmpty) family.fetchMembers(),
    ]);
  }

  /// Bị chặn vì gói → dialog kèm CTA nâng cấp. Lỗi khác → SnackBar như cũ.
  Future<void> _handleError(Object e) async {
    if (!CalendarProvider.isFeatureLocked(e)) {
      _showMessage(e.toString(), isError: true);
      return;
    }
    if (!mounted) return;
    // /manager/subscription là manager-only (xem _managerOnlyPaths trong
    // app_router). Deputy/Member bấm vào sẽ bị redirect về home → dead-end.
    // Với họ chỉ báo để nhờ Trưởng nhóm nâng cấp, không hiện nút.
    final canUpgrade =
        context.read<AuthProvider>().user?.canManageSubscription ?? false;
    // Message của BE đã có dấu chấm cuối câu — KHÔNG nối thêm '.' vào $base,
    // trước đây làm hiện "…nâng cấp gói.." trên máy thật.
    final base = e is FeatureLockedException
        ? '${e.toString()}.'
        : 'Gói hiện tại không cho phép thao tác này.\n\n$e';
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần nâng cấp gói'),
        content: Text(
          canUpgrade
              ? '$base\n\nNâng cấp gói để mở tính năng này cho cả gia đình.'
              : '$base\n\nVui lòng liên hệ Trưởng nhóm để nâng cấp gói.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(canUpgrade ? 'Để sau' : 'Đã hiểu'),
          ),
          if (canUpgrade)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nâng cấp gói'),
            ),
        ],
      ),
    );
    if (upgrade == true && mounted) context.push('/manager/subscription');
  }

  Future<void> _moveMonth(int delta) async {
    setState(() {
      _focus = DateTime(_focus.year, _focus.month + delta);
      _selected = null;
    });
    await _reload();
  }

  Map<int, List<FamilyCalendarEvent>> _eventsByDay(
    List<FamilyCalendarEvent> events,
  ) {
    final map = <int, List<FamilyCalendarEvent>>{};
    for (final e in events) {
      if (e.startTime.year != _focus.year ||
          e.startTime.month != _focus.month) {
        continue;
      }
      map.putIfAbsent(e.startTime.day, () => []).add(e);
    }
    return map;
  }

  String _responseLabel(String? status) => switch (status) {
    'ACCEPTED' => 'Tham gia',
    'MAYBE' => 'Có thể',
    'DECLINED' => 'Từ chối',
    _ => 'Chưa phản hồi',
  };

  Color _responseColor(String? status) => switch (status) {
    'ACCEPTED' => AppColors.safe,
    'MAYBE' => AppColors.accent500,
    'DECLINED' => AppColors.danger,
    _ => AppColors.textMuted,
  };

  IconData _responseIcon(String? status) => switch (status) {
    'ACCEPTED' => Icons.check_circle_rounded,
    'MAYBE' => Icons.help_rounded,
    'DECLINED' => Icons.cancel_rounded,
    _ => Icons.radio_button_unchecked_rounded,
  };

  Widget _responseChip(String? status, {bool compact = false}) {
    final color = _responseColor(status);
    final label = compact && (status == null || status.isEmpty)
        ? 'Chưa'
        : _responseLabel(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_responseIcon(status), size: compact ? 12 : 15, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToEvent(
    FamilyCalendarEvent event,
    String responseStatus,
  ) async {
    final provider = context.read<CalendarProvider>();
    try {
      await provider.respond(event.id, responseStatus);
      await provider.fetchEvents(_focus);
      _showMessage('Đã cập nhật phản hồi');
    } catch (e) {
      await _handleError(e);
    }
  }

  void _showEventDetail(FamilyCalendarEvent event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: event.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: event.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _typeChip(event),
                            _responseChip(event.responseStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _detailRow(
                Icons.schedule_rounded,
                '${event.startTime.day}/${event.startTime.month}/${event.startTime.year} · ${event.timeLabel}',
              ),
              if (event.location != null && event.location!.isNotEmpty)
                _detailRow(Icons.place_outlined, event.location!),
              if (event.description != null && event.description!.isNotEmpty)
                _detailRow(Icons.notes_rounded, event.description!),
              _detailRow(
                event.reminderEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                event.reminderEnabled ? 'Đã bật nhắc lịch' : 'Chưa bật nhắc lịch',
              ),
              if (event.isRecurring)
                _detailRow(Icons.repeat_rounded, 'Sự kiện lặp lại'),
              const SizedBox(height: 18),
              Text(
                'Phản hồi của bạn',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _responseButton(
                      label: 'Tham gia',
                      icon: Icons.check_rounded,
                      status: 'ACCEPTED',
                      event: event,
                      sheetContext: ctx,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _responseButton(
                      label: 'Có thể',
                      icon: Icons.help_outline_rounded,
                      status: 'MAYBE',
                      event: event,
                      sheetContext: ctx,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _responseButton(
                      label: 'Từ chối',
                      icon: Icons.close_rounded,
                      status: 'DECLINED',
                      event: event,
                      sheetContext: ctx,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responseButton({
    required String label,
    required IconData icon,
    required String status,
    required FamilyCalendarEvent event,
    required BuildContext sheetContext,
  }) {
    final selected = event.responseStatus == status;
    final color = _responseColor(status);
    return OutlinedButton.icon(
      onPressed: () async {
        Navigator.pop(sheetContext);
        await _respondToEvent(event, status);
      },
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : AppColors.white,
        side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _typeChip(FamilyCalendarEvent event) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        event.typeLabel,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: event.color,
        ),
      ),
    );
  }

  Future<void> _showEventForm({FamilyCalendarEvent? event}) async {
    final provider = context.read<CalendarProvider>();
    if (event == null && !provider.canCreateEvents) {
      await _handleError(const FeatureLockedException('calendar.enabled'));
      return;
    }
    final members = context.read<FamilyProvider>().members;
    final selectedMembers = {
      ...event?.participantMemberIds ?? const <String>[],
    };

    final titleCtrl = TextEditingController(text: event?.title ?? '');
    final locationCtrl = TextEditingController(text: event?.location ?? '');
    final descCtrl = TextEditingController(text: event?.description ?? '');
    final fallbackDay = (_selected ?? DateTime.now().day)
        .clamp(1, DateUtils.getDaysInMonth(_focus.year, _focus.month))
        .toInt();
    final baseDate =
        event?.startTime ?? DateTime(_focus.year, _focus.month, fallbackDay, 9);
    DateTime start = baseDate;
    DateTime? end = event?.endTime ?? baseDate.add(const Duration(hours: 1));
    bool reminder = event?.reminderEnabled ?? false;
    bool recurring = event?.isRecurring ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: start,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked == null) return;
            setSheet(() {
              start = DateTime(
                picked.year,
                picked.month,
                picked.day,
                start.hour,
                start.minute,
              );
              end = end == null
                  ? null
                  : DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      end!.hour,
                      end!.minute,
                    );
            });
          }

          Future<void> pickTime({required bool forEnd}) async {
            final source = forEnd ? end ?? start : start;
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(source),
            );
            if (picked == null) return;
            setSheet(() {
              final updated = DateTime(
                start.year,
                start.month,
                start.day,
                picked.hour,
                picked.minute,
              );
              if (forEnd) {
                end = updated;
              } else {
                start = updated;
              }
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event == null ? 'Thêm sự kiện' : 'Cập nhật sự kiện',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(titleCtrl, 'Tên sự kiện'),
                  const SizedBox(height: 12),
                  _field(locationCtrl, 'Địa điểm'),
                  const SizedBox(height: 12),
                  _field(descCtrl, 'Ghi chú', maxLines: 2),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _pickerButton(
                          icon: Icons.calendar_today_rounded,
                          label: '${start.day}/${start.month}/${start.year}',
                          onTap: pickDate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _pickerButton(
                          icon: Icons.schedule_rounded,
                          label: _timeLabel(start),
                          onTap: () => pickTime(forEnd: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _pickerButton(
                          icon: Icons.timelapse_rounded,
                          label: end == null ? '--:--' : _timeLabel(end!),
                          onTap: () => pickTime(forEnd: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nhắc lịch'),
                    subtitle: provider.canUseReminders
                        ? null
                        : const Text('Cần quyền calendar.reminders'),
                    value: reminder,
                    onChanged: provider.canUseReminders
                        ? (v) => setSheet(() => reminder = v)
                        : null,
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Người tham gia',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedMembers.isEmpty
                          ? 'Chưa chọn — mặc định cả gia đình'
                          : 'Đã chọn ${selectedMembers.length} thành viên',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members.map((m) {
                        final picked = selectedMembers.contains(m.id);
                        return FilterChip(
                          label: Text(m.name.isEmpty ? m.email : m.name),
                          selected: picked,
                          onSelected: (v) => setSheet(() {
                            if (v) {
                              selectedMembers.add(m.id);
                            } else {
                              selectedMembers.remove(m.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lặp lại'),
                    subtitle: provider.canUseRecurring
                        ? null
                        : const Text('Cần quyền calendar.recurringEvents'),
                    value: recurring,
                    onChanged: provider.canUseRecurring
                        ? (v) => setSheet(() => recurring = v)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.link,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          _showMessage(
                            'Vui lòng nhập tên sự kiện',
                            isError: true,
                          );
                          return;
                        }
                        try {
                          if (event == null) {
                            await provider.createEvent(
                              title: title,
                              location: locationCtrl.text,
                              description: descCtrl.text,
                              startTime: start,
                              endTime: end,
                              reminderEnabled: reminder,
                              isRecurring: recurring,
                              participantMemberIds: selectedMembers.toList(),
                            );
                          } else {
                            await provider.updateEvent(
                              event.id,
                              title: title,
                              location: locationCtrl.text,
                              description: descCtrl.text,
                              startTime: start,
                              endTime: end,
                              reminderEnabled: reminder,
                              isRecurring: recurring,
                              participantMemberIds: selectedMembers.toList(),
                              month: DateTime(start.year, start.month),
                            );
                          }
                          if (!mounted || !ctx.mounted) return;
                          Navigator.pop(ctx);
                          setState(() {
                            _focus = DateTime(start.year, start.month);
                            _selected = start.day;
                          });
                          _showMessage('Đã lưu sự kiện');
                        } catch (e) {
                          await _handleError(e);
                        }
                      },
                      child: Text(
                        'Lưu',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    final today = DateTime.now();
    final eventsByDay = _eventsByDay(provider.events);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (_showLegend) _legend(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    const SizedBox(height: 10),
                    _calendarGrid(today, eventsByDay),
                    const SizedBox(height: 16),
                    _sectionTitle(),
                    if (provider.loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (provider.error != null)
                      _empty(provider.error!, isError: true)
                    else
                      ..._eventList(eventsByDay),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Member không có quyền tạo → ẩn hẳn FAB thay vì để bấm rồi ăn 403.
      floatingActionButton: !_canManage
          ? null
          : FloatingActionButton(
              heroTag: 'calendar_fab',
              onPressed: () => _showEventForm(),
              backgroundColor: provider.canCreateEvents
                  ? AppColors.link
                  : AppColors.textMuted,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
    );
  }

  // Tách 2 dòng: trước đây tiêu đề + "Chú thích" + điều hướng tháng nằm chung
  // một Row, trong đó Flexible(tiêu đề) và Spacer() cùng chia phần dư nên tiêu
  // đề bị ép còn "L…" trên máy thật (quan sát 2026-07-20).
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.link),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lịch gia đình',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showLegend = !_showLegend),
              child: const Text('Chú thích'),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                'Tháng ${_focus.month}/${_focus.year}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _moveMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _legend() {
    const items = [
      ('Task', _calendarTaskColor),
      ('Sự kiện', _calendarEventColor),
      ('Du lịch', _calendarTravelColor),
      ('Sinh nhật', _calendarBirthdayColor),
      ('Sức khỏe', _calendarHealthColor),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _surfaceDecoration(),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: items
            .map(
              (i) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    i.$1,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _calendarGrid(
    DateTime today,
    Map<int, List<FamilyCalendarEvent>> eventsByDay,
  ) {
    return Container(
      decoration: _surfaceDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == 'CN'
                                ? AppColors.sos
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: _calendarDivider),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: _firstWeekday + _daysInMonth,
              itemBuilder: (_, i) {
                if (i < _firstWeekday) return const SizedBox();
                final day = i - _firstWeekday + 1;
                final isToday =
                    today.year == _focus.year &&
                    today.month == _focus.month &&
                    today.day == day;
                final isSelected = _selected == day;
                final dayEvents = eventsByDay[day] ?? const [];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected = _selected == day ? null : day;
                  }),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.link
                          : isToday
                          ? AppColors.link.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? AppColors.link
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (dayEvents.isNotEmpty)
                          Positioned(
                            bottom: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: dayEvents.take(3).map((e) {
                                return Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.white : e.color,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      _selected != null
          ? 'Ngày $_selected tháng ${_focus.month}'
          : 'Sự kiện tháng ${_focus.month}',
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    ),
  );

  List<Widget> _eventList(Map<int, List<FamilyCalendarEvent>> eventsByDay) {
    final visible = _selected == null
        ? eventsByDay
        : {_selected!: eventsByDay[_selected] ?? const <FamilyCalendarEvent>[]};
    if (visible.isEmpty || visible.values.every((list) => list.isEmpty)) {
      return [_empty('Không có sự kiện')];
    }

    final widgets = <Widget>[];
    final days = visible.keys.toList()..sort();
    for (final day in days) {
      for (final event in visible[day]!) {
        widgets.add(_eventCard(event));
      }
    }
    return widgets;
  }

  Widget _eventCard(FamilyCalendarEvent event) {
    final provider = context.read<CalendarProvider>();
    return InkWell(
      onTap: _canManage
          ? () => _showEventForm(event: event)
          : () => _showEventDetail(event),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: event.color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _typeChip(event),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.startTime.day}/${event.startTime.month} · ${event.timeLabel}'
                      '${event.location == null ? '' : ' · ${event.location}'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _responseChip(event.responseStatus, compact: true),
                  ],
                ),
              ),
              IconButton(
                tooltip: provider.canUseReminders
                    ? 'Nhắc lịch'
                    : 'Nhắc lịch — cần nâng cấp gói',
                // Cố ý KHÔNG disable khi thiếu quyền: bấm vào sẽ ném
                // FeatureLockedException → dialog nâng cấp, rõ hơn nút chết.
                onPressed: () async {
                  try {
                    await provider.updateReminder(
                      event.id,
                      !event.reminderEnabled,
                      _focus,
                    );
                  } catch (e) {
                    await _handleError(e);
                  }
                },
                icon: Icon(
                  event.reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: event.reminderEnabled
                      ? event.color
                      : AppColors.textMuted,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenu(event, value),
                // Phản hồi tham gia: mọi role (đây là lý do Member cần màn này).
                // Hủy sự kiện: chỉ Manager/Deputy.
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'ACCEPTED',
                    child: Text('Tham gia'),
                  ),
                  const PopupMenuItem(value: 'MAYBE', child: Text('Có thể')),
                  const PopupMenuItem(
                    value: 'DECLINED',
                    child: Text('Từ chối'),
                  ),
                  if (_canManage) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Hủy sự kiện'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenu(FamilyCalendarEvent event, String value) async {
    final provider = context.read<CalendarProvider>();
    try {
      if (value == 'cancel') {
        await provider.cancelEvent(event.id, _focus);
        _showMessage('Đã hủy sự kiện');
      } else {
        await _respondToEvent(event, value);
      }
    } catch (e) {
      await _handleError(e);
    }
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _calendarInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _calendarInputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _calendarInputBorder),
        ),
      ),
    );
  }

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _empty(String text, {bool isError = false}) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isError ? AppColors.danger : AppColors.textMuted,
        ),
      ),
    ),
  );

  BoxDecoration _surfaceDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: isError ? AppColors.danger : AppColors.link,
      ),
    );
  }

  static String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
