import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'subscription_provider.dart';

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

  /// Trạng thái phản hồi của **chính người đang đăng nhập**.
  ///
  /// BE bổ sung `myResponseStatus` phẳng (`INVITED | ACCEPTED | DECLINED |
  /// MAYBE | null`) + `myParticipant` từ 19/08 — [responseStatus] đọc sẵn ở
  /// [fromJson] nên đường nhanh chỉ là trả thẳng nó về.
  ///
  /// Vẫn giữ đường quét `participants[]`: đây là bản build dựng trước khi BE
  /// push, và BE nói rõ member không nằm trong participants thì
  /// `myResponseStatus = null` — không phân biệt được "chưa deploy" với "không
  /// được mời" nếu bỏ hẳn nhánh cũ. Quét chỉ chạy khi field phẳng vắng mặt nên
  /// BE lên là tự tắt.
  ///
  /// So khớp bằng cả `familyMember.id` lẫn `user.id` vì BE không nhất quán
  /// khoá participant theo cái nào.
  String? myResponseStatus(Set<String> myIdAliases) {
    if (responseStatus != null) return responseStatus;
    if (myIdAliases.isEmpty) return null;
    final participants = raw['participants'];
    if (participants is! List) return null;
    for (final entry in participants.whereType<Map>()) {
      final member = entry['member'];
      final user = entry['user'];
      final ids = <String?>[
        _str(entry['memberId']),
        _str(entry['familyMemberId']),
        _str(entry['userId']),
        member is Map ? _str(member['id']) : null,
        member is Map && member['user'] is Map
            ? _str((member['user'] as Map)['id'])
            : null,
        user is Map ? _str(user['id']) : null,
      ];
      if (ids.whereType<String>().any(myIdAliases.contains)) {
        return _str(entry['responseStatus']) ?? _str(entry['status']);
      }
    }
    return null;
  }

  factory FamilyCalendarEvent.fromJson(Map<String, dynamic> j) {
    // `myParticipant` là field BE bổ sung 19/08 cho đúng người đang gọi;
    // `participant` là tên cũ, giữ lại vì bản build này chạy trước khi BE push.
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
      // `myResponseStatus` là field chính thức của BE từ 19/08 — đọc trước
      // `responseStatus` (tên cũ, chưa bao giờ được BE trả trên máy thật).
      responseStatus:
          _str(j['myResponseStatus']) ??
          _str(j['responseStatus']) ??
          _str(participant['responseStatus']),
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
    if (c == AppColors.primary500) return 'Nhiệm vụ';
    return 'Sự kiện';
  }
}

/// Quy `INVITED` về null.
///
/// BE bổ sung `INVITED` vào enum `myResponseStatus` từ 19/08: đã được mời
/// nhưng **chưa trả lời** — với người dùng thì không khác gì chưa có phản hồi.
/// Không quy về null thì chip nhỏ mất nhánh "chưa trả lời" nên hiện chuỗi dài
/// "Chưa phản hồi" thay vì "Chưa", và nút Tham gia/Có thể/Từ chối lại có thể
/// hiểu nhầm là đã chọn cái gì đó.
String? normalizeResponseStatus(String? raw) {
  final v = raw?.trim();
  if (v == null || v.isEmpty || v == 'INVITED') return null;
  return v;
}

class CalendarProvider extends ChangeNotifier {
  CalendarProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    events = [];
    _sub = null;
    loading = false;
    error = null;
    _lastMonth = null;
    // Phản hồi là của riêng từng người — không dọn thì người đăng nhập sau
    // thấy "Tham gia" do người trước bấm.
    _pendingResponses.clear();
    notifyListeners();
  }

  List<FamilyCalendarEvent> events = [];
  bool loading = false;
  String? error;

  /// Tháng đang hiển thị — dùng làm mốc refetch khi lời gọi không nói rõ tháng,
  /// tránh nhảy về tháng hiện tại và làm event vừa sửa biến mất khỏi danh sách.
  DateTime? _lastMonth;

  /// Gắn ở [fetchBootstrap] — nguồn `featureAccess` dùng chung cho cả app
  /// (`SubscriptionProvider`), xem ghi chú ở đó. `null` cho tới khi màn Lịch
  /// bootstrap lần đầu; fail-open trong lúc đó, không tự chặn người dùng khỏi
  /// tính năng mà gói của họ vốn có (Free Plan có "Calendar view/create basic
  /// event" theo mô tả của Nhật).
  SubscriptionProvider? _sub;

  bool get canCreateEvents => _sub?.canCreateEvents ?? true;
  bool get canUseReminders => _sub?.canUseReminders ?? true;
  bool get canUseRecurring => _sub?.canUseRecurring ?? true;

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

  /// [sub] là `SubscriptionProvider` (nguồn `featureAccess` dùng chung cho cả
  /// app, xem `lib/providers/subscription_provider.dart`) — trước đây
  /// `CalendarProvider` tự gọi `GET .../subscription` ở đây, giờ chỉ đọc lại
  /// dữ liệu đã có, và tự fetch hộ nếu `SubscriptionProvider` chưa kịp có gì
  /// (ví dụ mở thẳng màn Lịch trước khi `family_shell` fetch xong).
  Future<void> fetchBootstrap(DateTime month, SubscriptionProvider sub) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (sub.isUnknown) await sub.fetch();
      _sub = sub;
      await fetchEvents(month, notify: false);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
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

  /// Phản hồi vừa gửi thành công, giữ theo eventId.
  ///
  /// Không phải mock: chỉ ghi lại kết quả của một request đã trả 2xx. Cần vì
  /// response danh sách sự kiện không phải lúc nào cũng nói được trạng thái
  /// của riêng người đang đăng nhập (xem [FamilyCalendarEvent.myResponseStatus])
  /// — thiếu lớp này thì bấm "Tham gia" xong chip vẫn đứng ở "Chưa". Xoá khi
  /// người dùng đăng xuất khỏi gia đình hoặc khi BE đã nói rõ trạng thái.
  final Map<String, String> _pendingResponses = {};

  /// Trạng thái phản hồi hiển thị cho [event]: ưu tiên thứ BE nói, chưa nói
  /// được thì mới dùng thứ vừa gửi.
  String? responseStatusOf(
    FamilyCalendarEvent event,
    Set<String> myIdAliases,
  ) => normalizeResponseStatus(
    event.myResponseStatus(myIdAliases) ?? _pendingResponses[event.id],
  );

  Future<void> respond(String eventId, String responseStatus) async {
    final data = await ApiClient.instance.post(
      '/families/$_fid/calendar/events/$eventId/respond',
      {'responseStatus': responseStatus},
    );
    // BE trả sự kiện đã cập nhật ngay ở top-level của `data` (contract 19/08).
    // Dùng luôn thì chip đổi mà không cần gọi lại danh sách.
    final updated = _eventFromRespond(data);
    if (updated != null) {
      final at = events.indexWhere((e) => e.id == updated.id);
      if (at >= 0) {
        events[at] = updated;
      }
      // Đã có nguồn thật cho sự kiện này → bỏ bản giữ tạm.
      _pendingResponses.remove(eventId);
    } else {
      // Bản BE cũ không trả event → giữ tạm để chip không đứng ở "Chưa".
      _pendingResponses[eventId] = responseStatus;
    }
    notifyListeners();
  }

  /// Sự kiện trong response của POST respond.
  ///
  /// [ApiClient] đã bóc envelope `{success, data}` nên `data` chính là sự
  /// kiện. Vẫn dò `data.event` / `data.calendarEvent` vì đó là hình dạng cũ mà
  /// BE vừa bỏ — bản build này chạy trước khi họ push. Không có id thì coi như
  /// BE chưa trả sự kiện, không dựng object rỗng đè lên dữ liệu đang đúng.
  static FamilyCalendarEvent? _eventFromRespond(dynamic data) {
    if (data is! Map) return null;
    final root = Map<String, dynamic>.from(data);
    final nested = root['event'] ?? root['calendarEvent'];
    final map = nested is Map ? Map<String, dynamic>.from(nested) : root;
    final parsed = FamilyCalendarEvent.fromJson(map);
    return parsed.id.isEmpty ? null : parsed;
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
