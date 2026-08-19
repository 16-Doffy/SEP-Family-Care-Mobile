import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/task_provider.dart';
import 'package:family_care/screens/shared/task_submission_recap.dart';

void main() {
  group('TaskAssignment.labelOf', () {
    // Sheet giao việc cảnh báo "đã được giao (…)" khi chỉ cầm chuỗi status,
    // chưa có object assignment — nhãn phải khớp hệt statusLabel của instance.
    test('nhãn rời khớp statusLabel của instance', () {
      for (final status in [
        'PENDING',
        'ASSIGNED',
        'IN_PROGRESS',
        'SUBMITTED',
        'APPROVED',
        'REJECTED',
        'CANCELED',
        'UNAVAILABLE',
        'STATUS_LA',
      ]) {
        final a = TaskAssignment(
          id: 'a',
          taskId: 't',
          assignedToMemberId: 'm',
          status: status,
        );
        expect(TaskAssignment.labelOf(status), a.statusLabel, reason: status);
      }
    });
  });

  group('TaskSubmissionRecap.autoLoad', () {
    // Bị từ chối thì lý do phải hiện ngay, không bắt bấm mới thấy. Các trạng
    // thái khác nạp khi mở để danh sách nhiều thẻ không bắn ngần ấy request.
    test('chỉ tự nạp khi bị từ chối', () {
      bool auto(String status) => TaskSubmissionRecap(
        assignmentId: 'a',
        assignmentStatus: status,
      ).autoLoad;

      expect(auto('REJECTED'), isTrue);
      expect(auto('SUBMITTED'), isFalse);
      expect(auto('APPROVED'), isFalse);
    });
  });
}
