import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/task_provider.dart';

void main() {
  group('RewardSetting.autoCreateSettlement', () {
    test('BE không trả field → hiểu là BẬT (default true của Swagger)', () {
      final setting = RewardSetting.fromJson({
        'rewardType': 'MONEY_RECORD',
        'rewardAmount': 50000,
      });

      expect(
        setting.autoCreateSettlement,
        isTrue,
        reason: 'đọc == true sẽ ra false và báo sai là đang tắt tự tạo',
      );
    });

    test('BE nói rõ false thì tôn trọng', () {
      final setting = RewardSetting.fromJson({
        'rewardType': 'MONEY_RECORD',
        'rewardAmount': 50000,
        'autoCreateSettlement': false,
      });

      expect(setting.autoCreateSettlement, isFalse);
    });

    test('BE nói rõ true thì bật', () {
      final setting = RewardSetting.fromJson({
        'rewardType': 'POINT',
        'rewardAmount': 10,
        'autoCreateSettlement': true,
      });

      expect(setting.autoCreateSettlement, isTrue);
    });
  });

  group('RewardSettlement status', () {
    test('enum thật của BE, không phải PAID/CONFIRMED như bản cũ', () {
      final pending = RewardSettlement.fromJson({
        'id': 's1',
        'status': 'PENDING_SETTLEMENT',
      });
      final waiting = RewardSettlement.fromJson({
        'id': 's2',
        'status': 'WAITING_CONFIRMATION',
      });
      final settled = RewardSettlement.fromJson({
        'id': 's3',
        'status': 'SETTLED',
      });

      expect(pending.needsMarkPaid, isTrue, reason: 'chờ Manager trả thưởng');
      expect(waiting.needsMarkPaid, isFalse);
      expect(settled.needsMarkPaid, isFalse);
      expect(settled.statusLabel, 'Đã nhận');
    });

    test('thiếu status thì mặc định chờ trả thưởng', () {
      final s = RewardSettlement.fromJson({'id': 's1'});
      expect(s.status, 'PENDING_SETTLEMENT');
    });

    test(
      'submissionId đọc được để biết bài nộp nào chưa có ghi nhận thưởng',
      () {
        final s = RewardSettlement.fromJson({
          'id': 's1',
          'submissionId': 'sub-1',
        });
        expect(s.submissionId, 'sub-1');
      },
    );

    test('đọc đúng người nhận từ receiverMember của settlement', () {
      final s = RewardSettlement.fromJson({
        'id': 's1',
        'receiverMemberId': 'member-1',
        'receiverMember': {
          'id': 'member-1',
          'userId': 'user-1',
          'user': {'id': 'user-1', 'fullName': 'Lê Anh Sĩ'},
        },
        'task': {'id': 'task-1', 'title': 'Rửa bát'},
      });

      expect(s.receiverMemberId, 'member-1');
      expect(s.receiverUserId, 'user-1');
      expect(s.memberName, 'Lê Anh Sĩ');
      expect(s.taskTitle, 'Rửa bát');
    });
  });

  group('FamilyTask — người giao', () {
    test('đọc tên người giao từ createdByMember.user.fullName', () {
      final task = FamilyTask.fromJson({
        'id': 't1',
        'title': 'Rửa chén',
        'createdByMember': {
          'id': 'member-1',
          'user': {'fullName': 'Zap HOH'},
        },
      });

      expect(task.createdByMemberId, 'member-1');
      expect(task.createdByName, 'Zap HOH');
    });

    test('BE không trả người giao thì null, UI sẽ ẩn dòng đó', () {
      final task = FamilyTask.fromJson({'id': 't1', 'title': 'Rửa chén'});

      expect(task.createdByMemberId, isNull);
      expect(task.createdByName, isNull);
    });
  });

  group('TaskAssignment — người giao (màn nhiệm vụ của thành viên)', () {
    test('đọc từ assignedByMember ở cấp assignment', () {
      final a = TaskAssignment.fromJson({
        'id': 'as1',
        'taskId': 't1',
        'assignedToMemberId': 'mem-1',
        'assignedByMember': {
          'id': 'hoh-1',
          'user': {'fullName': 'Zap HOH'},
        },
      });

      expect(a.assignedByMemberId, 'hoh-1');
      expect(a.assignedByName, 'Zap HOH');
    });

    test('assignment không có thì lấy từ task lồng bên trong', () {
      final a = TaskAssignment.fromJson({
        'id': 'as1',
        'assignedToMemberId': 'mem-1',
        'task': {
          'id': 't1',
          'title': 'Dọn phòng',
          'createdByMember': {'id': 'hoh-1', 'displayName': 'Bố'},
        },
      });

      expect(a.assignedByName, isNull, reason: 'cấp assignment không có tên');
      expect(a.task?.createdByName, 'Bố', reason: 'UI fallback sang task');
    });

    test(
      'chỉ có id (BE không trả tên) — UI sẽ tra tên qua danh sách thành viên',
      () {
        final a = TaskAssignment.fromJson({
          'id': 'as1',
          'assignedToMemberId': 'mem-1',
          'assignedByMemberId': 'hoh-1',
        });

        expect(a.assignedByMemberId, 'hoh-1');
        expect(a.assignedByName, isNull);
      },
    );

    test('BE không trả gì về người giao thì cả hai đều null', () {
      final a = TaskAssignment.fromJson({
        'id': 'as1',
        'assignedToMemberId': 'mem-1',
      });

      expect(a.assignedByMemberId, isNull);
      expect(a.assignedByName, isNull);
    });
  });
}
