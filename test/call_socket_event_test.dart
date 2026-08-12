import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/call_provider.dart';

/// Payload của 5 event `call:*` trên namespace Socket.IO `/chat`.
///
/// Vì sao cần khoá bằng test: đây là **hợp đồng WebSocket**, không nằm trong
/// Swagger nên không có schema nào để đối chiếu — chỉ có mô tả bằng lời của BE.
/// Đọc sai một field thì màn cuộc gọi hiện thiếu thông tin hoặc trống trơn mà
/// **không crash, không log**, đúng kiểu bug tới lúc demo mới lộ.
void main() {
  group('CallIncomingEvent', () {
    test('đọc đủ field theo mô tả của BE', () {
      final e = CallIncomingEvent.fromJson({
        'callId': 'call-1',
        'conversationId': 'conv-1',
        'roomName': 'call-uuid',
        'initiatedByMemberId': 'member-1',
        'callerName': 'Ba',
        'participants': [
          {
            'id': 'p-1',
            'callId': 'call-1',
            'memberId': 'member-2',
            'status': 'INVITED',
            'member': {
              'id': 'member-2',
              'displayName': 'Mẹ',
              'user': {'id': 'user-2', 'fullName': 'Nguyen Thi B'},
            },
          },
        ],
      });
      expect(e.callId, 'call-1');
      expect(e.conversationId, 'conv-1');
      expect(e.roomName, 'call-uuid');
      expect(e.initiatedByMemberId, 'member-1');
      expect(e.callerName, 'Ba');
      expect(e.participants, hasLength(1));
      expect(e.participants.first.displayName, 'Mẹ');
    });

    test('participants là mảng OBJECT, không phải mảng memberId', () {
      // BE nói rõ điểm này. Nếu BE đổi sang mảng chuỗi thì phải biết ngay:
      // whereType<Map>() sẽ lọc sạch và danh sách người trong cuộc gọi rỗng
      // trơn — màn cuộc gọi đến không hiện ai cả mà không có lỗi nào.
      final e = CallIncomingEvent.fromJson({
        'callId': 'c',
        'participants': ['member-2', 'member-3'],
      });
      expect(
        e.participants,
        isEmpty,
        reason: 'mảng chuỗi = BE đã đổi contract, phải sửa parser',
      );
    });

    test('thiếu callerName vẫn có tên hiển thị, không ra ô trống', () {
      expect(CallIncomingEvent.fromJson(const {}).callerName, 'Thành viên');
    });

    test('participants sai kiểu (không phải List) không ném lỗi', () {
      final e = CallIncomingEvent.fromJson({'participants': 'oops'});
      expect(e.participants, isEmpty);
    });
  });

  group('CallParticipantUpdateEvent', () {
    test('đọc status JOINED/LEFT', () {
      for (final s in ['JOINED', 'LEFT']) {
        final e = CallParticipantUpdateEvent.fromJson({
          'callId': 'c',
          'memberId': 'm',
          'status': s,
        });
        expect(e.status, s);
        expect(e.memberId, 'm');
      }
    });

    test('call:accepted / call:declined không có status → chuỗi rỗng', () {
      // Hai event này chỉ mang callId + memberId. Dùng chung model nên phải
      // chắc chắn thiếu status không thành null gây crash chỗ so sánh.
      final e = CallParticipantUpdateEvent.fromJson({
        'callId': 'c',
        'memberId': 'm',
      });
      expect(e.status, '');
    });
  });

  group('CallEndedEvent', () {
    test('đọc đủ status, endedReason, endedAt', () {
      final e = CallEndedEvent.fromJson({
        'callId': 'c',
        'status': 'MISSED',
        'endedReason': 'timeout',
        'endedAt': '2026-08-10T12:30:00.000Z',
      });
      expect(e.status, CallStatus.missed);
      expect(e.endedReason, 'timeout');
      expect(e.endedAt, isNotNull);
    });

    test('endedReason viết THƯỜNG, khác mọi enum khác viết HOA', () {
      // Dễ bị "chuẩn hoá" nhầm thành chữ hoa cho đồng bộ rồi so sánh trượt.
      for (final r in ['hangup', 'timeout', 'all_left', 'declined']) {
        expect(CallEndedEvent.fromJson({'endedReason': r}).endedReason, r);
      }
    });

    test('payload rỗng không ném lỗi, mặc định coi như đã kết thúc', () {
      final e = CallEndedEvent.fromJson(const {});
      expect(e.callId, '');
      expect(CallStatus.isFinished(e.status), isTrue);
      expect(e.endedAt, isNull);
    });
  });
}
