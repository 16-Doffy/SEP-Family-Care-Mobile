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
