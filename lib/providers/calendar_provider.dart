import 'package:flutter/material.dart';

import '../models/feature_access.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

String? _str(dynamic v) => v?.toString();
DateTime? _date(dynamic v) {
  final parsed = v == null ? null : DateTime.tryParse(v.toString());
  return parsed?.toLocal();
}

/// Thao tác bị khóa vì gói dịch vụ hiện tại, KHÔNG phải vì role hay lỗi mạng.
/// Màn hình bắt riêng loại này để hiện dialog nâng cấp gói thay vì SnackBar lỗi.
///
/// BE cũng trả 403 cho cùng tình huống — xem [CalendarProvider.isFeatureLocked]
/// để nhận diện cả hai nguồn.
class FeatureLockedException implements Exception {
  /// Key trong `featureAccess`, vd `calendar.reminders`.
  final String feature;
  const FeatureLockedException(this.feature);

  String get label => switch (feature) {
    'calendar.enabled' => 'tạo và sửa sự kiện lịch',
    'calendar.reminders' => 'nhắc lịch',
    'calendar.recurringEvents' => 'sự kiện lặp lại',
    _ => feature,
  };

  @override
  String toString() => 'Gói hiện tại chưa hỗ trợ $label';
}

class FamilyCalendarEvent {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final bool isRecurring;
  final bool reminderEnabled;
  final String? responseStatus;

  /// `familyMember.id` (membership record), khớp `participantMemberIds` của DTO.
  final List<String> participantMemberIds;
  final Map<String, dynamic> raw;

  const FamilyCalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.description,
    this.location,
    this.endTime,
    this.status = 'ACTIVE',
    this.isRecurring = false,
    this.reminderEnabled = false,
    this.responseStatus,
    this.participantMemberIds = const [],
    this.raw = const {},
  });

  /// BE có thể trả `participantMemberIds` phẳng hoặc `participants` dạng object
  /// — chấp nhận cả hai vì schema chưa được Nhật chốt.
  static List<String> _memberIds(Map<String, dynamic> j) {
    final direct = j['participantMemberIds'];
    if (direct is List) {
      return direct
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final participants = j['participants'];
    if (participants is List) {
      return participants
          .whereType<Map>()
          .map((e) {
            final member = e['member'];
            return _str(e['memberId']) ??
                _str(e['familyMemberId']) ??
                (member is Map ? _str(member['id']) : null) ??
                '';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory FamilyCalendarEvent.fromJson(Map<String, dynamic> j) {
    final participant = j['myParticipant'] is Map
        ? Map<String, dynamic>.from(j['myParticipant'] as Map)
        : j['participant'] is Map
        ? Map<String, dynamic>.from(j['participant'] as Map)
        : const <String, dynamic>{};
    return FamilyCalendarEvent(
      id:
          _str(j['id']) ??
          _str(j['eventId']) ??
          _str(j['calendarEventId']) ??
          '',
      title: _str(j['title']) ?? 'Sự kiện',
      description: _str(j['description']),
      location: _str(j['location']),
      startTime:
          _date(j['startTime'] ?? j['startAt'] ?? j['date']) ?? DateTime.now(),
      endTime: _date(j['endTime'] ?? j['endAt']),
      status: _str(j['status']) ?? 'ACTIVE',
      isRecurring: j['isRecurring'] == true,
      reminderEnabled:
          j['reminderEnabled'] == true ||
          j['myReminderEnabled'] == true ||
          participant['reminderEnabled'] == true,
      responseStatus:
          _str(j['responseStatus']) ?? _str(participant['responseStatus']),
      participantMemberIds: _memberIds(j),
      raw: j,
    );
  }

  String get timeLabel {
    String two(int v) => v.toString().padLeft(2, '0');
    final start = '${two(startTime.hour)}:${two(startTime.minute)}';
    if (endTime == null) return start;
    return '$start - ${two(endTime!.hour)}:${two(endTime!.minute)}';
  }

  Color get color {
    final text = '${title.toLowerCase()} ${description?.toLowerCase() ?? ''}';
    if (text.contains('sinh nhật')) return AppColors.accent500;
    if (text.contains('khám') || text.contains('sức khỏe')) {
      return AppColors.sos;
    }
    if (text.contains('du lịch') || text.contains('dã ngoại')) {
      return AppColors.calTravel;
    }
    if (text.contains('hạn') || text.contains('task')) {
      return AppColors.primary500;
    }
    return AppColors.secondary500;
  }

  String get typeLabel {
    final c = color;
    if (c == AppColors.accent500) return 'Sinh nhật';
    if (c == AppColors.sos) return 'Sức khỏe';
    if (c == AppColors.calTravel) return 'Du lịch';
    if (c == AppColors.primary500) return 'Task';
    return 'Sự kiện';
  }
}

class CalendarProvider extends ChangeNotifier {
  List<FamilyCalendarEvent> events = [];
  FeatureAccess? featureAccess;
  bool loading = false;
  String? error;

  /// Tháng đang hiển thị — dùng làm mốc refetch khi lời gọi không nói rõ tháng,
  /// tránh nhảy về tháng hiện tại và làm event vừa sửa biến mất khỏi danh sách.
  DateTime? _lastMonth;

  /// Chưa gọi được, hoặc BE trả `featureAccess` rỗng → coi như KHÔNG BIẾT.
  /// Fail-open và để BE trả 403 quyết định, thay vì tự chặn người dùng khỏi
  /// tính năng mà gói của họ vốn có (Free Plan có "Calendar view/create basic
  /// event" theo mô tả của Nhật).
  bool get _accessUnknown => featureAccess == null || featureAccess!.isUnknown;

  bool get canCreateEvents => _accessUnknown || featureAccess!.calendarEnabled;
  bool get canUseReminders =>
      _accessUnknown || featureAccess!.calendarReminders;
  bool get canUseRecurring =>
      _accessUnknown || featureAccess!.calendarRecurringEvents;

  /// Nhận diện "bị khóa do gói" từ cả hai nguồn: check phía FE
  /// ([FeatureLockedException]) và 403 do BE trả về.
  ///
  /// TODO: khi Nhật chốt `errorCode` (mục VERIFY #4) thì lọc theo errorCode
  /// thay vì coi mọi 403 là do gói — hiện 403 vì role cũng rơi vào nhánh này.
  static bool isFeatureLocked(Object e) =>
      e is FeatureLockedException || (e is ApiException && e.statusCode == 403);

  String get _fid {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    return fid;
  }

  Future<void> fetchBootstrap(DateTime month) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([
        fetchFeatureAccess(notify: false),
        fetchEvents(month, notify: false),
      ]);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFeatureAccess({bool notify = true}) async {
    try {
      final data = await ApiClient.instance.get('/families/$_fid/subscription');
      final plan = data is Map && data['plan'] is Map
          ? Map<String, dynamic>.from(data['plan'] as Map)
          : const <String, dynamic>{};
      final access = data is Map
          ? data['featureAccess'] ?? plan['featureAccess']
          : plan['featureAccess'];
      featureAccess = FeatureAccess.fromJson(access);
      // Schema featureAccess chưa được BE chốt (Swagger khai `type: object`
      // trần) — log raw để đối chiếu key thật với giả định calendar.enabled /
      // calendar.reminders / calendar.recurringEvents. Xem VERIFY #1.
      // ⚠️ flag() trả false CẢ KHI key không tồn tại, nên "không có quyền" và
      // "sai tên key" nhìn giống hệt nhau nếu không có dòng log này.
      debugPrint(
        'CalendarProvider: subscription keys='
        '${data is Map ? data.keys.toList() : data.runtimeType} '
        'plan keys=${plan.keys.toList()} '
        'featureAccess=${featureAccess!.raw} '
        '(unknown=${featureAccess!.isUnknown}) '
        '→ create=$canCreateEvents reminders=$canUseReminders '
        'recurring=$canUseRecurring',
      );
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('CalendarProvider: fetchFeatureAccess failed: $e');
    }
  }

  Future<void> fetchEvents(DateTime month, {bool notify = true}) async {
    final from = DateTime(month.year, month.month, 1).toUtc().toIso8601String();
    final to = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1)).toUtc().toIso8601String();
    final qs =
        '?from=${Uri.encodeQueryComponent(from)}&to=${Uri.encodeQueryComponent(to)}&status=ACTIVE';
    final data = await ApiClient.instance.get(
      '/families/$_fid/calendar/events$qs',
    );
    _lastMonth = DateTime(month.year, month.month);
    events = _list(data).map(FamilyCalendarEvent.fromJson).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (notify) notifyListeners();
  }

  Future<FamilyCalendarEvent?> fetchEventDetail(String eventId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/calendar/events/$eventId',
    );
    return data is Map<String, dynamic>
        ? FamilyCalendarEvent.fromJson(data)
        : null;
  }

  Future<FamilyCalendarEvent?> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    DateTime? endTime,
    bool isRecurring = false,
    bool reminderEnabled = false,
    List<String>? participantMemberIds,
  }) async {
    _checkWriteAccess(
      isRecurring: isRecurring,
      reminderEnabled: reminderEnabled,
    );
    final res = await ApiClient.instance.post(
      '/families/$_fid/calendar/events',
      {
        'title': title.trim(),
        'description': ?_clean(description),
        'location': ?_clean(location),
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': ?endTime?.toUtc().toIso8601String(),
        'isRecurring': isRecurring,
        'reminderEnabled': reminderEnabled,
        // Bỏ trống → BE tự thêm toàn bộ thành viên (theo flow Nhật mô tả).
        'participantMemberIds': ?_ids(participantMemberIds),
      },
    );
    await fetchEvents(startTime);
    return res.isNotEmpty ? FamilyCalendarEvent.fromJson(res) : null;
  }

  Future<void> updateEvent(
    String eventId, {
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isRecurring,
    bool? reminderEnabled,
    List<String>? participantMemberIds,
    DateTime? month,
  }) async {
    _checkWriteAccess(
      isRecurring: isRecurring == true,
      reminderEnabled: reminderEnabled == true,
    );
    await ApiClient.instance.patch('/families/$_fid/calendar/events/$eventId', {
      'title': ?_clean(title),
      'description': ?_clean(description),
      'location': ?_clean(location),
      'startTime': ?startTime?.toUtc().toIso8601String(),
      'endTime': ?endTime?.toUtc().toIso8601String(),
      'isRecurring': ?isRecurring,
      'reminderEnabled': ?reminderEnabled,
      'participantMemberIds': ?_ids(participantMemberIds),
    });
    await fetchEvents(month ?? startTime ?? _lastMonth ?? DateTime.now());
  }

  Future<void> cancelEvent(String eventId, DateTime month) async {
    // BE khóa cancel theo calendar.enabled — chặn sớm để hiện dialog nâng cấp
    // thay vì để người dùng ăn 403 giữa chừng.
    if (!canCreateEvents) {
      throw const FeatureLockedException('calendar.enabled');
    }
    await ApiClient.instance.patch(
      '/families/$_fid/calendar/events/$eventId/cancel',
      {},
    );
    await fetchEvents(month);
  }

  Future<void> respond(String eventId, String responseStatus) async {
    await ApiClient.instance.post(
      '/families/$_fid/calendar/events/$eventId/respond',
      {'responseStatus': responseStatus},
    );
    notifyListeners();
  }

  Future<void> updateReminder(
    String eventId,
    bool reminderEnabled,
    DateTime month,
  ) async {
    if (!canUseReminders) {
      throw const FeatureLockedException('calendar.reminders');
    }
    await ApiClient.instance.patch(
      '/families/$_fid/calendar/events/$eventId/reminder',
      {'reminderEnabled': reminderEnabled},
    );
    await fetchEvents(month);
  }

  void _checkWriteAccess({
    required bool isRecurring,
    required bool reminderEnabled,
  }) {
    if (!canCreateEvents) {
      throw const FeatureLockedException('calendar.enabled');
    }
    if (reminderEnabled && !canUseReminders) {
      throw const FeatureLockedException('calendar.reminders');
    }
    if (isRecurring && !canUseRecurring) {
      throw const FeatureLockedException('calendar.recurringEvents');
    }
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Danh sách rỗng nghĩa là "không đổi participants" → bỏ hẳn field khỏi body
  /// thay vì gửi `[]` (BE sẽ hiểu là xóa sạch người tham gia).
  static List<String>? _ids(List<String>? ids) =>
      ids == null || ids.isEmpty ? null : ids;

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : data is Map && data['data'] is List
        ? data['data'] as List
        : <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
