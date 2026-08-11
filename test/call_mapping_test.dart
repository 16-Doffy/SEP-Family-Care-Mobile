import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/call_provider.dart';
import 'package:family_care/services/api_client.dart';

/// Mapping JSON cho module Calls (gọi video).
///
/// Khoá lại contract theo schema chính thức của BE (`CallResponseDto`,
/// `CallActionResponseDto`, `CallHistoryResponseDto`... — Swagger 237 path,
/// 11/08 đợt 2). Đây đúng loại chỗ đã nhiều lần sinh bug enum/DTO sai trong
/// repo này, nên đổi tên field hay đổi kiểu là test đỏ ngay, không đợi tới lúc
/// demo mới lộ.
void main() {
  // Payload mẫu lấy từ tài liệu BE bàn giao (Discord #CallVideo, 10/08/2026).
  Map<String, dynamic> fullCallJson() => {
    'id': 'call-1',
    'conversationId': 'conv-1',
    'initiatedByMemberId': 'member-1',
    'roomName': 'call-uuid',
    'status': 'RINGING',
    'startedAt': '2026-08-10T12:23:11.000Z',
    'connectedAt': null,
    'endedAt': null,
    'endedReason': null,
    'initiatedByMember': {
      'id': 'member-1',
      'displayName': 'Ba',
      'familyRole': 'FAMILY_MANAGER',
      'user': {
        'id': 'user-1',
        'fullName': 'Nguyen Van A',
        'email': 'a@example.com',
        'avatarUrl': null,
      },
    },
    'participants': [
      {
        'id': 'p-1',
        'callId': 'call-1',
        'memberId': 'member-2',
        'status': 'INVITED',
        'invitedAt': '2026-08-10T12:23:11.000Z',
        'joinedAt': null,
        'leftAt': null,
        'member': {
          'id': 'member-2',
          'displayName': 'Mẹ',
          'familyRole': 'FAMILY_MEMBER',
          'user': {'id': 'user-2', 'fullName': 'Nguyen Thi B'},
        },
      },
    ],
  };

  group('Call.fromJson', () {
    test('đọc đủ field của payload BE mô tả', () {
      final c = Call.fromJson(fullCallJson());
      expect(c.id, 'call-1');
      expect(c.conversationId, 'conv-1');
      expect(c.initiatedByMemberId, 'member-1');
      expect(c.roomName, 'call-uuid');
      expect(c.status, CallStatus.ringing);
      expect(c.startedAt, isNotNull);
      expect(c.connectedAt, isNull);
      expect(c.initiatedByMember?.name, 'Ba');
      expect(c.initiatedByMember?.userId, 'user-1');
      expect(c.participants, hasLength(1));
      expect(c.participants.first.memberId, 'member-2');
      expect(c.participants.first.member?.name, 'Mẹ');
    });

    test('nhận cả `callId` khi không có `id`', () {
      // join/decline/leave/end theo tài liệu trả `{ "callId": ... }`, khác
      // POST /calls trả object call có `id`.
      final c = Call.fromJson({'callId': 'call-9'});
      expect(c.id, 'call-9');
    });

    test('payload rỗng không ném lỗi, không sinh field null bất ngờ', () {
      // Cuộc gọi là luồng khẩn của người dùng — thiếu field phải suy biến êm
      // chứ không được crash giữa màn đang gọi.
      final c = Call.fromJson(const {});
      expect(c.id, '');
      expect(c.status, CallStatus.ringing);
      expect(c.participants, isEmpty);
      expect(c.initiatedByMember, isNull);
      expect(c.duration, isNull);
    });

    test('participants sai kiểu (không phải List) vẫn ra danh sách rỗng', () {
      final c = Call.fromJson({'id': 'x', 'participants': 'oops'});
      expect(c.participants, isEmpty);
    });
  });

  group('CallStatus', () {
    test('phân loại đúng còn sống / đã kết thúc', () {
      expect(CallStatus.isLive('RINGING'), isTrue);
      expect(CallStatus.isLive('ONGOING'), isTrue);
      for (final s in ['ENDED', 'MISSED', 'DECLINED', 'CANCELED']) {
        expect(CallStatus.isFinished(s), isTrue, reason: s);
        expect(CallStatus.isLive(s), isFalse, reason: s);
      }
    });

    test('giá trị lạ không crash và không bị coi là đang gọi', () {
      // Giữ chuỗi gốc thay vì enum cứng — bài học từ `referenceType`: BE thêm
      // giá trị mới bất cứ lúc nào mà không báo FE.
      const unknown = 'SOMETHING_NEW';
      expect(CallStatus.isLive(unknown), isFalse);
      expect(CallStatus.isFinished(unknown), isFalse);
      expect(Call.fromJson({'status': unknown}).status, unknown);
    });
  });

  group('Call.duration', () {
    test('tính từ connectedAt, KHÔNG phải startedAt', () {
      // Nếu tính từ startedAt thì cuộc gọi đổ chuông 5 phút rồi mới bắt máy
      // sẽ hiện sai hẳn thời lượng trong lịch sử.
      final c = Call.fromJson({
        'id': 'c',
        'startedAt': '2026-08-10T12:00:00.000Z',
        'connectedAt': '2026-08-10T12:05:00.000Z',
        'endedAt': '2026-08-10T12:07:30.000Z',
      });
      expect(c.duration, const Duration(minutes: 2, seconds: 30));
    });

    test('chưa ai bắt máy (cuộc gọi nhỡ) → null, không phải Duration.zero', () {
      final c = Call.fromJson({
        'id': 'c',
        'startedAt': '2026-08-10T12:00:00.000Z',
        'endedAt': '2026-08-10T12:00:40.000Z',
        'status': 'MISSED',
      });
      expect(c.duration, isNull);
    });
  });

  group('CallSession.fromJson', () {
    test('đọc vé vào phòng LiveKit kèm object call lồng trong', () {
      final s = CallSession.fromJson({
        'callId': 'call-1',
        'roomName': 'call-uuid',
        'token': 'eyJhbGciOi...',
        'livekitUrl': 'wss://family-care-xxxxx.livekit.cloud',
        'call': fullCallJson(),
      });
      expect(s.callId, 'call-1');
      expect(s.token, isNotEmpty);
      expect(s.livekitUrl, startsWith('wss://'));
      expect(s.canConnect, isTrue);
      expect(s.call?.conversationId, 'conv-1');
    });

    test('thiếu token hoặc livekitUrl → canConnect false', () {
      // Chặn ngay tại đây thay vì để room.connect() ném lỗi khó hiểu.
      expect(
        CallSession.fromJson({'callId': 'c', 'livekitUrl': 'wss://x'}).canConnect,
        isFalse,
      );
      expect(
        CallSession.fromJson({'callId': 'c', 'token': 'abc'}).canConnect,
        isFalse,
      );
    });

    test('join không kèm object call → call null nhưng vẫn kết nối được', () {
      final s = CallSession.fromJson({
        'callId': 'call-1',
        'roomName': 'r',
        'token': 't',
        'livekitUrl': 'wss://x',
      });
      expect(s.call, isNull);
      expect(s.canConnect, isTrue);
    });
  });

  group('CallParticipant', () {
    test('isInCall chỉ đúng với JOINED', () {
      bool inCall(String s) =>
          CallParticipant.fromJson({'status': s}).isInCall;
      expect(inCall(CallParticipantStatus.joined), isTrue);
      for (final s in ['INVITED', 'LEFT', 'DECLINED', 'NO_ANSWER']) {
        expect(inCall(s), isFalse, reason: s);
      }
    });

    test('thiếu member vẫn có tên hiển thị, không ra ô trống', () {
      expect(CallParticipant.fromJson(const {}).displayName, 'Thành viên');
    });

    test('không có displayName thì lùi về fullName của user', () {
      final p = CallParticipant.fromJson({
        'member': {
          'id': 'm',
          'user': {'id': 'u', 'fullName': 'Nguyen Van C'},
        },
      });
      expect(p.displayName, 'Nguyen Van C');
    });

    test('đọc invitedAt (schema khai required, từng bị bỏ sót)', () {
      final p = CallParticipant.fromJson({
        'invitedAt': '2026-08-10T12:23:11.000Z',
      });
      expect(p.invitedAt, isNotNull);
    });
  });

  group('CallProvider.messageOf — bắt theo code, không theo message', () {
    // BE bổ sung 11 mã lỗi ổn định ngày 11/08 (đợt 2). Trước đó FE chỉ có
    // message tiếng Việt thô; so chuỗi thì BE sửa một dấu chính tả là hỏng.
    test('mỗi mã lỗi ra một câu riêng, không lẫn nhau', () {
      final codes = [
        CallErrorCode.alreadyActive,
        CallErrorCode.conversationArchived,
        CallErrorCode.tooFewMembers,
        CallErrorCode.alreadyEnded,
        CallErrorCode.notFamilyMember,
        CallErrorCode.notInvited,
        CallErrorCode.notInCall,
        CallErrorCode.notInitiator,
        CallErrorCode.callNotFound,
        CallErrorCode.conversationNotFound,
        CallErrorCode.livekitNotConfigured,
      ];
      final seen = <String>{};
      for (final c in codes) {
        final msg = CallProvider.messageOf(
          ApiException(400, 'message thô của BE', code: c),
        );
        expect(msg, isNot('message thô của BE'), reason: c);
        expect(seen.add(msg), isTrue, reason: 'câu bị trùng cho $c');
      }
    });

    test('mã lạ (BE thêm sau) → lùi về message của BE, không nuốt lỗi', () {
      expect(
        CallProvider.messageOf(
          ApiException(400, 'Lỗi mới nào đó', code: 'CALL_SOMETHING_NEW'),
        ),
        'Lỗi mới nào đó',
      );
    });

    test('isLivekitUnconfigured chỉ đúng với đúng mã đó', () {
      expect(
        CallProvider.isLivekitUnconfigured(
          ApiException(503, '', code: CallErrorCode.livekitNotConfigured),
        ),
        isTrue,
      );
      // 503 nhưng mã khác → không được coi là chưa cấu hình LiveKit.
      expect(
        CallProvider.isLivekitUnconfigured(ApiException(503, 'timeout')),
        isFalse,
      );
    });
  });
}
