import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

const _calendarTaskColor = AppColors.primary500;
const _calendarEventColor = AppColors.shared;
const _calendarTravelColor = AppColors.calTravel;
const _calendarBirthdayColor = AppColors.accent500;
const _calendarHealthColor = AppColors.sos;
const _calendarDarkBg = Colors.black;
const _calendarDarkSurface = Color(0xFF1C1C1E);
const _calendarDarkSurface2 = Color(0xFF2C2C2E);
const _calendarIosRed = Color(0xFFFF3B4A);

enum _CalendarViewMode { compact, stacked, details, list }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focus;
  int? _selected;
  bool _showLegend = false;
  _CalendarViewMode _viewMode = _CalendarViewMode.details;

  int get _daysInMonth => DateUtils.getDaysInMonth(_focus.year, _focus.month);
  int get _firstWeekday => DateTime(_focus.year, _focus.month, 1).weekday % 7;

  /// Manager/Deputy mới được tạo/sửa/hủy event. Member chỉ xem và phản hồi
  /// tham gia — BE cũng chặn tương ứng, gate ở FE để không hiện nút chết.
  bool get _canManage =>
      context.read<AuthProvider>().user?.canManageCalendar ?? false;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _calendarBg => _dark ? _calendarDarkBg : context.colors.background;
  Color get _calendarSurface =>
      _dark ? _calendarDarkSurface : context.colors.surface;
  Color get _calendarSurface2 =>
      _dark ? _calendarDarkSurface2 : context.colors.inputFill;
  Color get _calendarText => _dark ? Colors.white : context.colors.textPrimary;
  Color get _calendarSecondary =>
      _dark ? Colors.white70 : context.colors.textSecondary;
  Color get _calendarMuted =>
      _dark ? Colors.white54 : context.colors.textMuted;
  Color get _calendarFaint =>
      _dark ? Colors.white38 : context.colors.textMuted;
  Color get _calendarBorder => _dark
      ? Colors.white.withValues(alpha: 0.08)
      : context.colors.divider;
  Color _calendarDivider([double alpha = 0.12]) => _dark
      ? Colors.white.withValues(alpha: alpha)
      : context.colors.divider.withValues(alpha: 0.9);

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
      backgroundColor: _calendarSurface,
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
                            color: _calendarText,
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
                event.reminderEnabled
                    ? 'Đã bật nhắc lịch'
                    : 'Chưa bật nhắc lịch',
              ),
              if (event.isRecurring)
                _detailRow(Icons.repeat_rounded, 'Sự kiện lặp lại'),
              const SizedBox(height: 18),
              Text(
                'Phản hồi của bạn',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _calendarText,
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
          Icon(icon, size: 18, color: _calendarMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _calendarSecondary,
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
        backgroundColor: selected ? color : _calendarSurface,
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
      backgroundColor: _calendarSurface,
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

          Future<void> save() async {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) {
              _showMessage('Vui lòng nhập tên sự kiện', isError: true);
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
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sheetCircleButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(ctx),
                        ),
                        Expanded(
                          child: Text(
                            event == null ? 'Mới' : 'Sửa',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _sheetCircleButton(
                          icon: Icons.check_rounded,
                          filled: true,
                          onTap: save,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _segmentedHeader(),
                    const SizedBox(height: 24),
                    _formGroup([
                      _field(titleCtrl, 'Tiêu đề'),
                      _groupDivider(),
                      _field(locationCtrl, 'Vị trí hoặc cuộc gọi video'),
                    ]),
                    const SizedBox(height: 18),
                    _formGroup([
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: _sheetLabel('Cả ngày'),
                        value: false,
                        onChanged: (_) {},
                        activeThumbColor: _calendarIosRed,
                      ),
                      _groupDivider(),
                      _sheetPickerRow(
                        label: 'Bắt đầu',
                        children: [
                          _pickerButton(
                            icon: Icons.calendar_today_rounded,
                            label: '${start.day}/${start.month}/${start.year}',
                            onTap: pickDate,
                          ),
                          _pickerButton(
                            icon: Icons.schedule_rounded,
                            label: _timeLabel(start),
                            onTap: () => pickTime(forEnd: false),
                          ),
                        ],
                      ),
                      _groupDivider(),
                      _sheetPickerRow(
                        label: 'Kết thúc',
                        children: [
                          _pickerButton(
                            icon: Icons.timelapse_rounded,
                            label: end == null ? '--:--' : _timeLabel(end!),
                            onTap: () => pickTime(forEnd: true),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 18),
                    _formGroup([
                      _sheetPickerRow(
                        label: 'Lặp lại',
                        mutedValue: provider.canUseRecurring
                            ? 'Không'
                            : 'Cần gói',
                        children: [
                          Switch(
                            value: recurring,
                            onChanged: provider.canUseRecurring
                                ? (v) => setSheet(() => recurring = v)
                                : null,
                            activeThumbColor: _calendarIosRed,
                          ),
                        ],
                      ),
                    ]),
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _sheetLabel('Người tham gia'),
                      const SizedBox(height: 6),
                      Text(
                        selectedMembers.isEmpty
                            ? 'Chưa chọn — mặc định cả gia đình'
                            : 'Đã chọn ${selectedMembers.length} thành viên',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
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
                            selectedColor: _calendarIosRed.withValues(
                              alpha: 0.22,
                            ),
                            backgroundColor: _calendarDarkSurface2,
                            labelStyle: GoogleFonts.inter(color: Colors.white),
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
                    const SizedBox(height: 18),
                    _formGroup([
                      _field(descCtrl, 'Ghi chú', maxLines: 3),
                      _groupDivider(),
                      _sheetPickerRow(
                        label: 'Cảnh báo',
                        mutedValue: provider.canUseReminders
                            ? 'Không'
                            : 'Cần gói',
                        children: [
                          Switch(
                            value: reminder,
                            onChanged: provider.canUseReminders
                                ? (v) => setSheet(() => reminder = v)
                                : null,
                            activeThumbColor: _calendarIosRed,
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
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
      backgroundColor: _calendarDarkBg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                children: [
                  _header(),
                  if (_showLegend) _legend(),
                  _calendarGrid(today, eventsByDay),
                  if (_viewMode == _CalendarViewMode.list ||
                      _selected != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _sectionTitle(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: provider.loading
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : provider.error != null
                          ? _empty(provider.error!, isError: true)
                          : Column(children: _eventList(eventsByDay)),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: _bottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(28, 10, 28, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _capsuleButton(
              icon: Icons.chevron_left_rounded,
              label: '${_focus.year}',
              onTap: () => _moveMonth(-1),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _calendarDarkSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modeMenuButton(),
                  _roundToolbarButton(
                    tooltip: 'Tìm kiếm',
                    icon: Icons.search_rounded,
                    onTap: () => _showMessage('Tìm kiếm lịch sẽ được bổ sung'),
                  ),
                  if (_canManage)
                    _roundToolbarButton(
                      tooltip: 'Tạo sự kiện',
                      icon: Icons.add_rounded,
                      onTap: () => _showEventForm(),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120) _moveMonth(1);
            if (velocity > 120) _moveMonth(-1);
          },
          child: Text(
            _monthName(_focus.month),
            style: GoogleFonts.inter(
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _legend() {
    const items = [
      ('Nhiệm vụ', _calendarTaskColor),
      ('Sự kiện', _calendarEventColor),
      ('Du lịch', _calendarTravelColor),
      ('Sinh nhật', _calendarBirthdayColor),
      ('Sức khỏe', _calendarHealthColor),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 14),
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
                      color: Colors.white70,
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
    final totalCells = _firstWeekday + _daysInMonth;
    final rows = (totalCells / 7).ceil();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        for (var row = 0; row < rows; row++)
          _calendarWeek(row, today, eventsByDay),
      ],
    );
  }

  Widget _calendarWeek(
    int row,
    DateTime today,
    Map<int, List<FamilyCalendarEvent>> eventsByDay,
  ) {
    return Container(
      height: _viewMode == _CalendarViewMode.compact ? 72 : 118,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: List.generate(7, (col) {
          final cell = row * 7 + col;
          if (cell < _firstWeekday) return const Expanded(child: SizedBox());
          final day = cell - _firstWeekday + 1;
          if (day > _daysInMonth) return const Expanded(child: SizedBox());
          return Expanded(
            child: _dayCell(day, today, eventsByDay[day] ?? const []),
          );
        }),
      ),
    );
  }

  Widget _dayCell(int day, DateTime today, List<FamilyCalendarEvent> events) {
    final isToday =
        today.year == _focus.year &&
        today.month == _focus.month &&
        today.day == day;
    final isSelected = _selected == day;
    final dayColor = isSelected || isToday
        ? Colors.white
        : day < today.day &&
              today.year == _focus.year &&
              today.month == _focus.month
        ? Colors.white38
        : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = _selected == day ? null : day),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected || isToday ? _calendarIosRed : null,
              ),
              child: Text(
                '$day',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: dayColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _dayEvents(events, selected: isSelected || isToday),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayEvents(
    List<FamilyCalendarEvent> events, {
    required bool selected,
  }) {
    if (events.isEmpty) return const SizedBox.shrink();
    if (_viewMode == _CalendarViewMode.compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: events.take(3).map((e) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
          );
        }).toList(),
      );
    }
    final max = _viewMode == _CalendarViewMode.stacked ? 2 : 3;
    return Column(
      children: events.take(max).map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: _eventPill(event, dimmed: selected),
        );
      }).toList(),
    );
  }

  Widget _eventPill(FamilyCalendarEvent event, {bool dimmed = false}) {
    return GestureDetector(
      onTap: () =>
          _canManage ? _showEventForm(event: event) : _showEventDetail(event),
      child: Container(
        height: 19,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: event.color.withValues(alpha: dimmed ? 0.42 : 0.34),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.remove_circle_outline_rounded,
              size: 10,
              color: event.color,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: event.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      _selected != null
          ? 'Ngày $_selected tháng ${_focus.month}'
          : 'Danh sách sự kiện',
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.white,
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
          color: _calendarDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: event.color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.startTime.day}/${event.startTime.month} · ${event.timeLabel}'
                      '${event.location == null ? '' : ' · ${event.location}'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
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
                  color: event.reminderEnabled ? event.color : Colors.white54,
                ),
              ),
              PopupMenuButton<String>(
                color: _calendarDarkSurface2,
                iconColor: Colors.white70,
                onSelected: (value) => _handleMenu(event, value),
                // Phản hồi tham gia: mọi role (đây là lý do Member cần màn này).
                // Hủy sự kiện: chỉ Manager/Deputy.
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'ACCEPTED',
                    child: _popupText('Tham gia'),
                  ),
                  PopupMenuItem(value: 'MAYBE', child: _popupText('Có thể')),
                  PopupMenuItem(
                    value: 'DECLINED',
                    child: _popupText('Từ chối'),
                  ),
                  if (_canManage) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'cancel',
                      child: _popupText('Hủy sự kiện'),
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

  Text _popupText(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _sheetCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF5E5E66)
              : _calendarDarkSurface2.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 31),
      ),
    );
  }

  Widget _segmentedHeader() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF34343A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _segmentLabel('Sự kiện', selected: true)),
          Expanded(child: _segmentLabel('Nhắc việc')),
        ],
      ),
    );
  }

  Widget _segmentLabel(String label, {bool selected = false}) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF77777F) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _formGroup(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _calendarDarkSurface2,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }

  Widget _groupDivider() {
    return Divider(height: 1, color: Colors.white.withValues(alpha: 0.11));
  }

  Text _sheetLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _sheetPickerRow({
    required String label,
    String? mutedValue,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _sheetLabel(label),
          const Spacer(),
          if (mutedValue != null)
            Text(
              mutedValue,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white54),
            ),
          const SizedBox(width: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white38),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
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
      icon: Icon(icon, size: 14),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF47474D),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
          color: isError ? AppColors.danger : Colors.white54,
        ),
      ),
    ),
  );

  BoxDecoration _surfaceDecoration() => BoxDecoration(
    color: _calendarDarkSurface.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
  );

  Widget _capsuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          color: _calendarDarkSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundToolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _modeMenuButton() {
    return PopupMenuButton<_CalendarViewMode>(
      tooltip: 'Kiểu hiển thị',
      color: _calendarDarkSurface,
      icon: const Icon(
        Icons.view_agenda_outlined,
        color: Colors.white,
        size: 27,
      ),
      onSelected: (mode) => setState(() => _viewMode = mode),
      itemBuilder: (_) => [
        _modeItem(
          _CalendarViewMode.compact,
          Icons.view_week_outlined,
          'Gọn',
        ),
        _modeItem(
          _CalendarViewMode.stacked,
          Icons.view_stream_outlined,
          'Xếp chồng',
        ),
        _modeItem(
          _CalendarViewMode.details,
          Icons.view_agenda_outlined,
          'Chi tiết',
        ),
        const PopupMenuDivider(),
        _modeItem(_CalendarViewMode.list, Icons.list_alt_rounded, 'Danh sách'),
      ],
    );
  }

  PopupMenuEntry<_CalendarViewMode> _modeItem(
    _CalendarViewMode mode,
    IconData icon,
    String label,
  ) {
    final selected = _viewMode == mode;
    return PopupMenuItem<_CalendarViewMode>(
      value: mode,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
          Icon(icon, color: Colors.white70, size: 21),
          const SizedBox(width: 14),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _bottomControls() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            final now = DateTime.now();
            setState(() {
              _focus = DateTime(now.year, now.month);
              _selected = now.day;
            });
            _reload();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _calendarDarkSurface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Hôm nay',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _calendarDarkSurface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Chú thích',
                onPressed: () => setState(() => _showLegend = !_showLegend),
                icon: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.inbox_outlined, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return names[month - 1];
  }

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
