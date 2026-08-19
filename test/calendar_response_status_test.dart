import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/calendar_provider.dart';

FamilyCalendarEvent _event(Map<String, dynamic> json) =>
    FamilyCalendarEvent.fromJson({
      'id': 'e1',
      'title': 'đi dã ngoại',
      'startTime': '2026-08-20T09:00:00.000Z',
      ...json,
    });

void main() {
  _contract19082026Tests();
  group('myResponseStatus', () {
    // Bug máy thật 19/08: bấm Tham gia, POST respond trả 2xx, nhưng chip vẫn
    // đứng ở "Chưa" vì parser chỉ moi id ra khỏi mảng participants chứ không
    // đọc responseStatus của chính người đang đăng nhập.
    test('đọc trạng thái của mình trong mảng participants', () {
      final event = _event({
        'participants': [
          {'memberId': 'mem-khac', 'responseStatus': 'DECLINED'},
          {'memberId': 'mem-toi', 'responseStatus': 'ACCEPTED'},
        ],
      });
      expect(event.responseStatus, isNull, reason: 'BE không trả field phẳng');
      expect(event.myResponseStatus({'mem-toi'}), 'ACCEPTED');
    });

    test('khớp được cả khi BE khoá participant theo userId', () {
      final event = _event({
        'participants': [
          {
            'member': {
              'id': 'mem-toi',
              'user': {'id': 'user-toi'},
            },
            'responseStatus': 'MAYBE',
          },
        ],
      });
      expect(event.myResponseStatus({'user-toi'}), 'MAYBE');
    });

    test('field phẳng của BE luôn thắng mảng participants', () {
      final event = _event({
        'responseStatus': 'DECLINED',
        'participants': [
          {'memberId': 'mem-toi', 'responseStatus': 'ACCEPTED'},
        ],
      });
      expect(event.myResponseStatus({'mem-toi'}), 'DECLINED');
    });

    test(
      'không tìm thấy mình trong danh sách thì trả null, không đoán bừa',
      () {
        final event = _event({
          'participants': [
            {'memberId': 'mem-khac', 'responseStatus': 'ACCEPTED'},
          ],
        });
        expect(event.myResponseStatus({'mem-toi'}), isNull);
        expect(event.myResponseStatus(const {}), isNull);
      },
    );

    test('BE chưa trả participants thì vẫn an toàn', () {
      expect(_event({}).myResponseStatus({'mem-toi'}), isNull);
      expect(
        _event({'participants': 'khong-phai-mang'}).myResponseStatus({'m'}),
        isNull,
      );
    });
  });
}

/// Contract BE 19/08: GET events / GET event trả thêm `myResponseStatus` phẳng
/// (`INVITED | ACCEPTED | DECLINED | MAYBE | null`) + `myParticipant`.
void _contract19082026Tests() {
  group('contract BE 19/08 — myResponseStatus phẳng', () {
    test('đọc myResponseStatus, không cần quét participants', () {
      final event = _event({
        'myResponseStatus': 'ACCEPTED',
        // Mảng participants nói ngược lại — field phẳng phải thắng.
        'participants': [
          {'memberId': 'mem-toi', 'responseStatus': 'DECLINED'},
        ],
      });
      expect(event.responseStatus, 'ACCEPTED');
      expect(event.myResponseStatus(const {}), 'ACCEPTED');
    });

    test('đọc được myParticipant khi field phẳng vắng', () {
      final event = _event({
        'myParticipant': {'responseStatus': 'MAYBE', 'reminderEnabled': true},
      });
      expect(event.responseStatus, 'MAYBE');
      expect(event.reminderEnabled, isTrue);
    });

    test('không nằm trong participants thì null, không rơi về quét mảng', () {
      // BE nói rõ: không được mời ⇒ myResponseStatus = null.
      final event = _event({
        'myResponseStatus': null,
        'participants': [
          {'memberId': 'mem-khac', 'responseStatus': 'ACCEPTED'},
        ],
      });
      expect(event.myResponseStatus({'mem-toi'}), isNull);
    });
  });

  group('normalizeResponseStatus', () {
    // INVITED = đã mời, CHƯA trả lời. Với người dùng không khác gì null; để lọt
    // ra UI thì chip nhỏ hiện "Chưa phản hồi" thay vì "Chưa", và nút phản hồi
    // có thể trông như đã chọn.
    test('INVITED quy về null', () {
      expect(normalizeResponseStatus('INVITED'), isNull);
    });

    test('null và chuỗi rỗng cũng về null', () {
      expect(normalizeResponseStatus(null), isNull);
      expect(normalizeResponseStatus(''), isNull);
      expect(normalizeResponseStatus('   '), isNull);
    });

    test('ba trạng thái thật giữ nguyên', () {
      for (final s in ['ACCEPTED', 'DECLINED', 'MAYBE']) {
        expect(normalizeResponseStatus(s), s);
      }
    });
  });
}
