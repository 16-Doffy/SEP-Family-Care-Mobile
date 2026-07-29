import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/support_request_provider.dart';

void main() {
  group('SupportRequest — tên người gửi yêu cầu xin tiền', () {
    test('đọc từ requesterMember.user.fullName (khuôn DTO member của BE)', () {
      final r = SupportRequest.fromJson({
        'id': 'r1',
        'amount': 456789,
        'purpose': 'gw',
        'requesterMemberId': 'mem-1',
        'requesterMember': {
          'id': 'mem-1',
          'displayName': 'Con',
          'user': {'fullName': 'Zap MEM 2'},
        },
      });

      expect(r.requesterName, 'Zap MEM 2');
      expect(r.displayName, 'Zap MEM 2');
      expect(r.requesterMemberId, 'mem-1');
    });

    test('không có user.fullName thì lấy displayName của member', () {
      final r = SupportRequest.fromJson({
        'id': 'r1',
        'requesterMember': {'id': 'mem-1', 'displayName': 'Con út'},
      });

      expect(r.displayName, 'Con út');
    });

    test('vẫn đọc được biến thể cũ `requester` phẳng', () {
      final r = SupportRequest.fromJson({
        'id': 'r1',
        'requester': {'fullName': 'Bố'},
      });

      expect(r.displayName, 'Bố');
    });

    test('BE chỉ trả id → requesterName rỗng để UI còn tra được theo id', () {
      final r = SupportRequest.fromJson({
        'id': 'r1',
        'requesterMemberId': 'mem-1',
      });

      expect(
        r.requesterName,
        isEmpty,
        reason: 'nhồi sẵn "Thành viên" sẽ chặn mất đường tra theo id',
      );
      expect(r.requesterMemberId, 'mem-1');
      expect(r.displayName, 'Thành viên', reason: 'chỉ là fallback hiển thị');
    });

    test('BE không trả gì về người gửi thì displayName mới là Thành viên', () {
      final r = SupportRequest.fromJson({'id': 'r1', 'amount': 1000});

      expect(r.requesterName, isEmpty);
      expect(r.requesterMemberId, isNull);
      expect(r.displayName, 'Thành viên');
    });

    test('tên chỉ có khoảng trắng cũng coi như không có', () {
      final r = SupportRequest.fromJson({
        'id': 'r1',
        'requesterMember': {
          'user': {'fullName': '   '},
        },
      });

      expect(r.requesterName, isEmpty);
      expect(r.displayName, 'Thành viên');
    });
  });
}
