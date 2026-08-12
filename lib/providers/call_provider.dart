import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/chat_socket_service.dart';

// ════════════════════════════════════════════════════════════════════════
// CallProvider — module Calls (gọi video qua LiveKit), BE ship 2026-08-10.
//
// ⚠️ HAI ĐIỂM KHÁC HẲN CÁC MODULE KHÁC, sai là silent fail:
//
// 1. Endpoint **top-level `/calls/...`**, KHÔNG nằm dưới `/families/{familyId}`
//    như hầu hết API còn lại → tuyệt đối KHÔNG dùng `ApiClient.familyPath()`.
//    BE tự suy ra family/quyền từ `conversationId` hoặc `callId`; điều kiện duy
//    nhất là người gọi đang là participant còn hoạt động của hội thoại đó.
//
// 2. Cuộc gọi là luồng thời gian thực: người dùng đang hoảng/đang chờ, không
//    có cơ hội "thử lại". Nên mọi chỗ đọc JSON ở đây đều có fallback và tuyệt
//    đối không ném lỗi khi thiếu field — hiển thị thiếu còn hơn sập màn.
//
// Đối chiếu schema: bản Swagger 237 path (11/08 đợt 2) **đã khai đủ** cho cả 7
// endpoint — `CallResponseDto`, `InitiateCallResponseDto`, `JoinCallResponseDto`,
// `CallActionResponseDto`, `CallHistoryResponseDto`, `CallStatus`,
// `CallParticipantStatus` + 11 mã lỗi. Model dưới đây khớp field-for-field với
// các DTO đó, không còn `[VERIFY]` nào treo.
//
// GĐ1: tầng REST + model. GĐ2: signaling Socket.IO `/chat` (`ChatSocketService`).
// GĐ3: LiveKit (`incoming_call_screen.dart`/`active_call_screen.dart`). GĐ4:
// nối `startRealtime()`/`onIncomingCall` vào `family_shell.dart`, đăng ký
// provider này ở `main.dart` — xong đủ 4 giai đoạn.
// ════════════════════════════════════════════════════════════════════════

/// Trạng thái cuộc gọi. Giữ **chuỗi gốc** của BE thay vì enum Dart cứng: đây
/// đúng bài học từ `referenceType` — enum cứng gặp giá trị lạ sẽ ném lỗi giữa
/// lúc đang gọi, còn giữ chuỗi thì chỉ là không tô đúng màu.
///
/// Khớp enum `CallStatus` trong `schema.prisma`:
/// RINGING | ONGOING | ENDED | MISSED | DECLINED | CANCELED.
///
/// - `MISSED`: **đã hoạt động từ 11/08 đợt 2** — BE có job timeout **30 giây**
///   kể từ `POST /calls`, không ai bắt máy thì tự chuyển `MISSED` và **giải
///   phóng hội thoại**. Trước đó cuộc gọi nằm `RINGING` vô thời hạn và khoá
///   luôn hội thoại (không gọi lại được vì `POST /calls` trả 400) — bug thật,
///   đã được sửa sau khi FE hỏi.
/// - `CANCELED`: người gọi tự huỷ trước khi có ai bắt máy — **qua `end` hoặc
///   `leave` đều được**, BE xử lý như nhau.
class CallStatus {
  const CallStatus._();

  static const ringing = 'RINGING';
  static const ongoing = 'ONGOING';
  static const ended = 'ENDED';
  static const missed = 'MISSED';
  static const declined = 'DECLINED';
  static const canceled = 'CANCELED';

  /// Các trạng thái cuộc gọi đã kết thúc — dùng để biết có nên rời phòng
  /// LiveKit / đóng màn gọi hay không.
  static const finished = {ended, missed, declined, canceled};

  static bool isFinished(String status) => finished.contains(status);

  /// Đang đổ chuông hoặc đang nói chuyện — cuộc gọi còn "sống".
  static bool isLive(String status) => status == ringing || status == ongoing;
}

/// Trạng thái của một người trong cuộc gọi — khớp enum `CallParticipantStatus`
/// trong `schema.prisma`: INVITED | JOINED | DECLINED | LEFT | NO_ANSWER.
///
/// ⚠️ `NO_ANSWER` **vẫn chưa được BE set bao giờ** (xác nhận 11/08 đợt 2):
/// timeout hiện xử lý ở cấp **cả cuộc gọi** (`Call.status` → `MISSED`), chưa
/// đánh dấu riêng từng người không trả lời trong gọi nhóm. Đừng làm UI cho
/// trạng thái này tới khi BE bật lên.
class CallParticipantStatus {
  const CallParticipantStatus._();

  static const invited = 'INVITED';
  static const joined = 'JOINED';
  static const left = 'LEFT';
  static const declined = 'DECLINED';
  static const noAnswer = 'NO_ANSWER';
}

/// Thông tin người trong cuộc gọi, gộp sẵn `member` + `member.user` để UI khỏi
/// lặp lại việc bóc 2 tầng lồng nhau (cùng cách `ChatParticipant` đang làm).
class CallMemberSummary {
  final String memberId;
  final String userId;
  final String name;
  final String familyRole;
  final String? avatarUrl;

  const CallMemberSummary({
    required this.memberId,
    required this.userId,
    required this.name,
    required this.familyRole,
    this.avatarUrl,
  });

  factory CallMemberSummary.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final display = j['displayName']?.toString();
    return CallMemberSummary(
      memberId: j['id']?.toString() ?? j['memberId']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      name: (display != null && display.isNotEmpty)
          ? display
          : user['fullName']?.toString() ?? 'Thành viên',
      familyRole: j['familyRole']?.toString() ?? '',
      avatarUrl: user['avatarUrl']?.toString(),
    );
  }
}

class CallParticipant {
  final String id;
  final String callId;
  final String memberId;

  /// Chuỗi gốc của BE — xem [CallParticipantStatus].
  final String status;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final CallMemberSummary? member;

  const CallParticipant({
    required this.id,
    required this.callId,
    required this.memberId,
    required this.status,
    this.invitedAt,
    this.joinedAt,
    this.leftAt,
    this.member,
  });

  bool get isInCall => status == CallParticipantStatus.joined;

  /// Tên hiển thị, có lùi về memberId để UI không bao giờ hiện ô trống.
  String get displayName {
    final n = member?.name;
    return (n != null && n.isNotEmpty) ? n : 'Thành viên';
  }

  factory CallParticipant.fromJson(Map<String, dynamic> j) => CallParticipant(
    id: j['id']?.toString() ?? '',
    callId: j['callId']?.toString() ?? '',
    memberId: j['memberId']?.toString() ?? '',
    status: j['status']?.toString() ?? CallParticipantStatus.invited,
    invitedAt: DateTime.tryParse(j['invitedAt']?.toString() ?? '')?.toLocal(),
    joinedAt: DateTime.tryParse(j['joinedAt']?.toString() ?? '')?.toLocal(),
    leftAt: DateTime.tryParse(j['leftAt']?.toString() ?? '')?.toLocal(),
    member: j['member'] is Map
        ? CallMemberSummary.fromJson(Map<String, dynamic>.from(j['member'] as Map))
        : null,
  );
}

class Call {
  final String id;
  final String conversationId;
  final String initiatedByMemberId;
  final String roomName;

  /// Chuỗi gốc của BE — xem [CallStatus].
  final String status;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  /// BE khai enum 4 giá trị (chữ THƯỜNG, khác hẳn các enum còn lại viết HOA):
  /// `hangup` | `timeout` | `all_left` | `declined`.
  /// `timeout` = hết 30 giây không ai bắt máy (đi kèm `status = MISSED`).
  final String? endedReason;
  final CallMemberSummary? initiatedByMember;
  final List<CallParticipant> participants;

  const Call({
    required this.id,
    required this.conversationId,
    required this.initiatedByMemberId,
    required this.roomName,
    required this.status,
    this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.endedReason,
    this.initiatedByMember,
    this.participants = const [],
  });

  bool get isLive => CallStatus.isLive(status);
  bool get isFinished => CallStatus.isFinished(status);

  /// Thời lượng cuộc gọi — tính từ lúc **thật sự có người bắt máy**
  /// (`connectedAt`) chứ không phải từ lúc bắt đầu đổ chuông (`startedAt`),
  /// nếu không thì cuộc gọi nhỡ 30 giây đổ chuông sẽ hiện thành "gọi 30 giây".
  /// Trả null khi chưa ai bắt máy.
  Duration? get duration {
    final start = connectedAt;
    if (start == null) return null;
    return (endedAt ?? DateTime.now()).difference(start);
  }

  factory Call.fromJson(Map<String, dynamic> j) => Call(
    id: j['id']?.toString() ?? j['callId']?.toString() ?? '',
    conversationId: j['conversationId']?.toString() ?? '',
    initiatedByMemberId: j['initiatedByMemberId']?.toString() ?? '',
    roomName: j['roomName']?.toString() ?? '',
    status: j['status']?.toString() ?? CallStatus.ringing,
    startedAt: DateTime.tryParse(j['startedAt']?.toString() ?? '')?.toLocal(),
    connectedAt: DateTime.tryParse(j['connectedAt']?.toString() ?? '')?.toLocal(),
    endedAt: DateTime.tryParse(j['endedAt']?.toString() ?? '')?.toLocal(),
    endedReason: j['endedReason']?.toString(),
    initiatedByMember: j['initiatedByMember'] is Map
        ? CallMemberSummary.fromJson(
            Map<String, dynamic>.from(j['initiatedByMember'] as Map),
          )
        : null,
    // `as List?` sẽ NÉM TypeError nếu BE trả về kiểu khác (chuỗi, object...),
    // chứ không trả null như tên gọi gợi ý — phải kiểm tra kiểu tường minh.
    participants: switch (j['participants']) {
      final List l => l
          .whereType<Map>()
          .map((e) => CallParticipant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      _ => const <CallParticipant>[],
    },
  );
}

/// Kết quả của `POST /calls` và `POST /calls/{callId}/join` — vé vào phòng
/// LiveKit. [token] và [livekitUrl] chưa dùng ở giai đoạn 1, để dành cho giai
/// đoạn 3 (`room.connect(livekitUrl, token)`).
class CallSession {
  final String callId;
  final String roomName;
  final String token;
  final String livekitUrl;

  /// Chỉ có ở `POST /calls`; `join` không trả lại object call đầy đủ.
  final Call? call;

  const CallSession({
    required this.callId,
    required this.roomName,
    required this.token,
    required this.livekitUrl,
    this.call,
  });

  /// Đủ dữ liệu để kết nối phòng chưa. Thiếu là BE chưa cấu hình LiveKit hoặc
  /// đổi tên field — phải chặn ngay chứ không để `room.connect` lỗi mơ hồ.
  bool get canConnect => token.isNotEmpty && livekitUrl.isNotEmpty;

  factory CallSession.fromJson(Map<String, dynamic> j) => CallSession(
    callId: j['callId']?.toString() ?? '',
    roomName: j['roomName']?.toString() ?? '',
    token: j['token']?.toString() ?? '',
    livekitUrl: j['livekitUrl']?.toString() ?? '',
    call: j['call'] is Map
        ? Call.fromJson(Map<String, dynamic>.from(j['call'] as Map))
        : null,
  );
}

// ── Payload của 5 event `call:*` trên namespace Socket.IO `/chat` ─────────
//
// Không có schema trong Swagger (đây là hợp đồng WebSocket, không phải REST),
// nên parse phòng thủ như phần REST ở trên: thiếu field thì suy biến êm chứ
// không ném lỗi giữa lúc đang có cuộc gọi.

/// `call:incoming` — bắn ngay sau khi người gọi tạo cuộc gọi thành công.
class CallIncomingEvent {
  final String callId;
  final String conversationId;
  final String roomName;
  final String initiatedByMemberId;

  /// Tên người gọi do BE dựng sẵn — hiển thị thẳng, không tự ghép lại.
  final String callerName;

  /// ⚠️ BE xác nhận đây là mảng **object đầy đủ**, KHÔNG phải mảng `memberId`.
  /// Đọc nhầm thành chuỗi thì màn cuộc gọi đến hiện trống trơn mà không báo lỗi.
  final List<CallParticipant> participants;

  const CallIncomingEvent({
    required this.callId,
    required this.conversationId,
    required this.roomName,
    required this.initiatedByMemberId,
    required this.callerName,
    this.participants = const [],
  });

  factory CallIncomingEvent.fromJson(Map<String, dynamic> j) =>
      CallIncomingEvent(
        callId: j['callId']?.toString() ?? '',
        conversationId: j['conversationId']?.toString() ?? '',
        roomName: j['roomName']?.toString() ?? '',
        initiatedByMemberId: j['initiatedByMemberId']?.toString() ?? '',
        callerName: j['callerName']?.toString() ?? 'Thành viên',
        participants: switch (j['participants']) {
          final List l => l
              .whereType<Map>()
              .map(
                (e) => CallParticipant.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
          _ => const <CallParticipant>[],
        },
      );
}

/// `call:participant-update` — một người vừa vào/rời phòng LiveKit thật sự
/// (BE xác nhận qua webhook), hoặc vừa gọi `.../leave`.
///
/// Dùng chung khuôn cho `call:accepted` và `call:declined` vì cả ba đều chỉ
/// mang `callId` + `memberId`; riêng hai cái sau không có `status`.
class CallParticipantUpdateEvent {
  final String callId;
  final String memberId;

  /// `JOINED | LEFT` cho `call:participant-update`; rỗng với accepted/declined.
  final String status;

  const CallParticipantUpdateEvent({
    required this.callId,
    required this.memberId,
    this.status = '',
  });

  factory CallParticipantUpdateEvent.fromJson(Map<String, dynamic> j) =>
      CallParticipantUpdateEvent(
        callId: j['callId']?.toString() ?? '',
        memberId: j['memberId']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
      );
}

/// `call:ended` — cuộc gọi kết thúc vì bất kỳ lý do gì.
class CallEndedEvent {
  final String callId;

  /// Chuỗi gốc — xem [CallStatus]. `MISSED` là hết 30 giây không ai bắt máy.
  final String status;

  /// `hangup | timeout | all_left | declined` — **chữ thường**.
  final String? endedReason;
  final DateTime? endedAt;

  const CallEndedEvent({
    required this.callId,
    required this.status,
    this.endedReason,
    this.endedAt,
  });

  factory CallEndedEvent.fromJson(Map<String, dynamic> j) => CallEndedEvent(
    callId: j['callId']?.toString() ?? '',
    status: j['status']?.toString() ?? CallStatus.ended,
    endedReason: j['endedReason']?.toString(),
    endedAt: DateTime.tryParse(j['endedAt']?.toString() ?? '')?.toLocal(),
  );
}

/// 11 mã lỗi ổn định BE bổ sung ngày 11/08 (đợt 2), khai đủ trong Swagger.
///
/// **Bắt theo `code`, KHÔNG bắt theo `message`** — trước đợt này chỉ có message
/// tiếng Việt thô, mà so chuỗi thì BE sửa một dấu chính tả là FE hỏng im lặng.
class CallErrorCode {
  const CallErrorCode._();

  // 400 — POST /calls
  static const alreadyActive = 'CALL_ALREADY_ACTIVE';
  static const conversationArchived = 'CONVERSATION_ARCHIVED';
  static const tooFewMembers = 'CONVERSATION_TOO_FEW_MEMBERS';

  // 400 — join
  static const alreadyEnded = 'CALL_ALREADY_ENDED';

  // 403
  static const notFamilyMember = 'NOT_FAMILY_MEMBER';
  static const notInvited = 'NOT_INVITED';
  static const notInCall = 'NOT_IN_CALL';
  static const notInitiator = 'NOT_INITIATOR';

  // 404
  static const callNotFound = 'CALL_NOT_FOUND';
  static const conversationNotFound = 'CONVERSATION_NOT_FOUND';

  // 503
  static const livekitNotConfigured = 'LIVEKIT_NOT_CONFIGURED';
}

class CallProvider extends ChangeNotifier {
  CallProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất — provider ở app scope nên sống
  /// suốt vòng đời app, không dọn thì người đăng nhập sau thấy lịch sử gọi của
  /// người trước.
  void resetForNewSession() {
    stopRealtime();
    _history = [];
    _historyCursor = null;
    _busy = false;
    _error = null;
    _lastEndedCallId = null;
    notifyListeners();
  }

  List<Call> _history = [];
  String? _historyCursor;
  bool _busy = false;
  String? _error;
  bool _realtimeOn = false;

  /// `callId` của cuộc gọi vừa nhận `call:ended` — màn hình đang mở cho cuộc
  /// gọi đó (`IncomingCallScreen`/`ActiveCallScreen`) so khớp rồi tự đóng.
  /// Không phải state bền vững, chỉ là tín hiệu một-lần qua `notifyListeners`.
  String? _lastEndedCallId;

  List<Call> get history => _history;

  /// Cursor trang kế của lịch sử; null = hết trang.
  String? get historyCursor => _historyCursor;
  bool get busy => _busy;
  String? get error => _error;
  String? get lastEndedCallId => _lastEndedCallId;

  /// UI tầng shell gắn vào để hiện `IncomingCallScreen` khi có `call:incoming`
  /// — provider không tự điều hướng (không có BuildContext).
  void Function(CallIncomingEvent event)? onIncomingCall;

  // ── Realtime (Socket.IO /chat, event `call:*`) ───────────────────────────
  //
  // Chỉ 2 event cần nối ở tầng app-wide: `call:incoming` (mở màn cuộc gọi
  // đến) và `call:ended` (đóng màn đang mở nếu đúng cuộc gọi). Các event còn
  // lại (`call:accepted`, `call:participant-update`) đã được suy ra từ chính
  // `RoomEvent` của LiveKit ngay trong `ActiveCallScreen` — nối lại ở đây là
  // trùng lặp không cần thiết.
  void startRealtime() {
    if (_realtimeOn) return;
    _realtimeOn = true;
    final svc = ChatSocketService.instance;
    svc.onCallIncoming = (e) => onIncomingCall?.call(e);
    svc.onCallEnded = (e) {
      _lastEndedCallId = e.callId;
      notifyListeners();
    };
    svc.connect();
  }

  void stopRealtime() {
    if (!_realtimeOn) return;
    _realtimeOn = false;
    final svc = ChatSocketService.instance;
    svc.onCallIncoming = null;
    svc.onCallEnded = null;
    svc.disconnect();
  }

  /// Câu tiếng Việt cho từng mã lỗi. Ưu tiên `code` (ổn định) hơn `message` của
  /// BE (có thể đổi chữ bất cứ lúc nào); không khớp mã nào thì mới lùi về
  /// `message` — vốn cũng đã là tiếng Việt.
  ///
  /// `LIVEKIT_NOT_CONFIGURED` là lỗi **cấu hình phía server**, không phải mạng
  /// của người dùng: cố ý không gợi ý "thử lại" vì thử lại cũng vô ích.
  static const _messages = {
    CallErrorCode.alreadyActive: 'Đang có cuộc gọi khác trong hội thoại này.',
    CallErrorCode.conversationArchived:
        'Hội thoại đã lưu trữ nên không gọi được.',
    CallErrorCode.tooFewMembers:
        'Hội thoại cần ít nhất 2 thành viên đang hoạt động để gọi.',
    CallErrorCode.alreadyEnded: 'Cuộc gọi đã kết thúc.',
    CallErrorCode.notFamilyMember: 'Bạn không thuộc gia đình của hội thoại này.',
    CallErrorCode.notInvited: 'Bạn không có trong cuộc gọi này.',
    CallErrorCode.notInCall: 'Bạn không ở trong cuộc gọi này.',
    CallErrorCode.notInitiator:
        'Chỉ người gọi mới kết thúc được cuộc gọi cho tất cả.',
    CallErrorCode.callNotFound: 'Không tìm thấy cuộc gọi.',
    CallErrorCode.conversationNotFound: 'Không tìm thấy hội thoại.',
    CallErrorCode.livekitNotConfigured:
        'Máy chủ chưa bật tính năng gọi video. Vui lòng báo quản trị viên.',
  };

  static String messageOf(Object error) {
    if (error is ApiException) {
      final byCode = _messages[error.code?.toUpperCase()];
      if (byCode != null) return byCode;
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// true khi lỗi là do server chưa bật LiveKit — nơi gọi có thể ẩn hẳn nút gọi
  /// thay vì cho bấm rồi báo lỗi mãi.
  static bool isLivekitUnconfigured(Object error) =>
      error is ApiException &&
      error.code?.toUpperCase() == CallErrorCode.livekitNotConfigured;

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      _error = messageOf(e);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ── Vòng đời cuộc gọi ─────────────────────────────────────────────────────

  /// POST /calls — người gọi tạo cuộc gọi và nhận vé vào phòng ngay, **không
  /// chờ ai bắt máy** (vào phòng trước rồi đợi, theo đúng mô tả của BE).
  ///
  /// 400 khi hội thoại đang có cuộc gọi khác chạy (RINGING/ONGOING), hội thoại
  /// đã ARCHIVED, hoặc có dưới 2 thành viên đang hoạt động.
  Future<CallSession> initiate(String conversationId) => _run(() async {
    final data = await ApiClient.instance.post('/calls', {
      'conversationId': conversationId,
    });
    return CallSession.fromJson(data);
  });

  /// POST /calls/{callId}/join — người nhận bắt máy, lấy vé vào phòng.
  /// 403 nếu không nằm trong danh sách được mời, 400 nếu cuộc gọi đã kết thúc.
  Future<CallSession> join(String callId) => _run(() async {
    final data = await ApiClient.instance.post('/calls/$callId/join', const {});
    return CallSession.fromJson(data);
  });

  /// Ba thao tác dưới đây cùng trả `CallActionResponseDto { callId, status }` —
  /// `status` là trạng thái **sau** thao tác, nên nơi gọi biết ngay kết quả mà
  /// không phải hỏi lại BE.
  Future<String> _action(String callId, String verb) => _run(() async {
    final data = await ApiClient.instance.post('/calls/$callId/$verb', const {});
    return data['status']?.toString() ?? '';
  });

  /// POST /calls/{callId}/decline — từ chối cuộc gọi đến, không cần đụng
  /// LiveKit.
  ///
  /// Gọi 1-1: trả thẳng `DECLINED` vì không còn ai để chờ. Gọi nhóm mà vẫn còn
  /// người chưa trả lời thì `status` vẫn là `RINGING`/`ONGOING`.
  Future<String> decline(String callId) => _action(callId, 'decline');

  /// POST /calls/{callId}/leave — tự rời cuộc gọi đang diễn ra.
  ///
  /// Đây chỉ là **báo cho BE**; việc rời phòng media là `room.disconnect()`
  /// phía LiveKit, hai việc độc lập nhau và giai đoạn 3 phải gọi cả hai.
  ///
  /// ⚠️ Nếu **người khởi tạo** gọi `leave` lúc còn `RINGING` (chưa ai bắt máy)
  /// thì BE coi như huỷ cuộc gọi và trả `CANCELED` — tương đương [end]. Vì vậy
  /// không cần bắt nơi gọi phải chọn đúng `leave` hay `end`, dùng cái nào cũng
  /// an toàn.
  Future<String> leave(String callId) => _action(callId, 'leave');

  /// POST /calls/{callId}/end — kết thúc cho tất cả. **Chỉ người khởi tạo**
  /// gọi được, người khác nhận 403 `NOT_INITIATOR`.
  ///
  /// Trả `ENDED` nếu đã từng có người vào phòng, `CANCELED` nếu chưa ai kết nối.
  Future<String> end(String callId) => _action(callId, 'end');

  /// GET /calls/{callId} — lấy 1 cuộc gọi theo id.
  ///
  /// BE bổ sung 11/08 (đợt 2) đúng cho tình huống socket `/chat` reconnect: rớt
  /// mạng giữa lúc đang đổ chuông thì gọi cái này với `callId` đã lưu để biết
  /// cuộc gọi còn sống hay đã kết thúc. Trước đó phải lách qua
  /// `GET /calls/conversations/{cid}?limit=1`.
  Future<Call> getCall(String callId) => _run(() async {
    final data = await ApiClient.instance.get('/calls/$callId');
    return Call.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
    );
  });

  // ── Lịch sử ───────────────────────────────────────────────────────────────

  /// GET /calls/conversations/{conversationId} — cursor pagination mới → cũ,
  /// cùng kiểu với lịch sử tin nhắn chat.
  ///
  /// [reset] = true để tải lại từ đầu (kéo-làm-mới); false để nối thêm trang kế.
  Future<void> fetchHistory(
    String conversationId, {
    bool reset = true,
    int limit = 30,
  }) => _run(() async {
    final cursor = reset ? null : _historyCursor;
    final query = StringBuffer('?limit=$limit');
    if (cursor != null && cursor.isNotEmpty) query.write('&cursor=$cursor');
    final data = await ApiClient.instance.get(
      '/calls/conversations/$conversationId$query',
    );

    // BE chưa khai schema: chấp nhận cả mảng trần lẫn bọc trong `items`.
    final list = data is List
        ? data
        : (data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[]);
    final page = list
        .whereType<Map>()
        .map((e) => Call.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty)
        .toList();

    _history = reset ? page : [..._history, ...page];
    _historyCursor = data is Map ? data['nextCursor']?.toString() : null;
    notifyListeners();
  });

  /// Cuộc gọi còn sống gần nhất của một hội thoại — dùng khi FE **chưa có**
  /// `callId` nào trong tay (vd vừa mở màn chat, muốn biết có cuộc gọi đang
  /// diễn ra để hiện thanh "Quay lại cuộc gọi").
  ///
  /// Nếu đã có `callId` (rớt mạng giữa cuộc gọi) thì dùng [getCall] — rẻ hơn và
  /// chính xác hơn.
  Future<Call?> fetchActiveCall(String conversationId) async {
    await fetchHistory(conversationId, limit: 1);
    if (_history.isEmpty) return null;
    final latest = _history.first;
    return latest.isLive ? latest : null;
  }
}
