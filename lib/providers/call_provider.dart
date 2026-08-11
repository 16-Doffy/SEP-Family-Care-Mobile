import 'package:flutter/material.dart';

import '../services/api_client.dart';

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
// 2. Swagger (bản 236 path ngày 11/08) **chưa khai response schema cho cả 6
//    endpoint** — chỉ có mỗi request DTO `InitiateCallDto`. Tên field dưới đây
//    lấy từ tài liệu bàn giao của BE (VQuanCT, Discord #CallVideo 10/08), tức
//    là nguồn của BE chứ không phải FE tự đoán, nhưng **chưa đối chiếu được
//    với schema chính thức** → xem `[VERIFY]` trong `API_DOCS.md` mục Calls.
//    Vì vậy mọi chỗ đọc JSON ở đây đều có fallback và không được ném lỗi khi
//    thiếu field.
//
// Giai đoạn 1 chỉ làm tầng REST + model. Chưa gắn LiveKit (`token`/`livekitUrl`
// được giữ nguyên để giai đoạn 3 dùng), chưa có signaling Socket.IO `/chat`,
// và provider này CHƯA được đăng ký vào cây provider ở `main.dart`.
// ════════════════════════════════════════════════════════════════════════

/// Trạng thái cuộc gọi. Giữ **chuỗi gốc** của BE thay vì enum Dart cứng: đây
/// đúng bài học từ `referenceType` — enum cứng gặp giá trị lạ sẽ ném lỗi giữa
/// lúc đang gọi, còn giữ chuỗi thì chỉ là không tô đúng màu.
///
/// Giá trị BE mô tả: RINGING | ONGOING | ENDED | MISSED | DECLINED | CANCELED.
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

/// Trạng thái của một người trong cuộc gọi.
/// BE mô tả: INVITED | JOINED | LEFT | DECLINED | NO_ANSWER.
/// `NO_ANSWER` dành cho gọi nhóm + timeout, BE ghi rõ **bản hiện tại chưa dùng**.
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
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final CallMemberSummary? member;

  const CallParticipant({
    required this.id,
    required this.callId,
    required this.memberId,
    required this.status,
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

class CallProvider extends ChangeNotifier {
  CallProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất — provider ở app scope nên sống
  /// suốt vòng đời app, không dọn thì người đăng nhập sau thấy lịch sử gọi của
  /// người trước.
  void resetForNewSession() {
    _history = [];
    _historyCursor = null;
    _busy = false;
    _error = null;
    notifyListeners();
  }

  List<Call> _history = [];
  String? _historyCursor;
  bool _busy = false;
  String? _error;

  List<Call> get history => _history;

  /// Cursor trang kế của lịch sử; null = hết trang.
  String? get historyCursor => _historyCursor;
  bool get busy => _busy;
  String? get error => _error;

  /// BE trả 503 khi server chưa cấu hình `LIVEKIT_API_KEY/SECRET/URL`. Đây là
  /// lỗi cấu hình phía server, không phải mạng của người dùng — phải hiện câu
  /// khác hẳn để khỏi bắt người dùng đi thử lại vô ích.
  static const _livekitUnconfigured =
      'Máy chủ chưa bật tính năng gọi video. Vui lòng báo quản trị viên.';

  static String messageOf(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 503) return _livekitUnconfigured;
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

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

  /// POST /calls/{callId}/decline — từ chối cuộc gọi đến, không cần đụng
  /// LiveKit.
  Future<void> decline(String callId) =>
      _run(() => ApiClient.instance.post('/calls/$callId/decline', const {}));

  /// POST /calls/{callId}/leave — tự rời cuộc gọi đang diễn ra.
  ///
  /// Đây chỉ là **báo cho BE**; việc rời phòng media là `room.disconnect()`
  /// phía LiveKit, hai việc độc lập nhau và giai đoạn 3 phải gọi cả hai.
  Future<void> leave(String callId) =>
      _run(() => ApiClient.instance.post('/calls/$callId/leave', const {}));

  /// POST /calls/{callId}/end — kết thúc cho tất cả. **Chỉ người khởi tạo**
  /// gọi được, người khác nhận 403.
  Future<void> end(String callId) =>
      _run(() => ApiClient.instance.post('/calls/$callId/end', const {}));

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

  /// Cuộc gọi còn sống gần nhất của một hội thoại.
  ///
  /// BE **không có** `GET /calls/{callId}`, nên khi socket rớt đúng lúc đang đổ
  /// chuông thì đây là cách duy nhất lấy lại trạng thái: đọc trang đầu lịch sử
  /// rồi soi item mới nhất (đúng cách BE hướng dẫn).
  Future<Call?> fetchActiveCall(String conversationId) async {
    await fetchHistory(conversationId, limit: 1);
    if (_history.isEmpty) return null;
    final latest = _history.first;
    return latest.isLive ? latest : null;
  }
}
