import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/task_provider.dart';
import 'package:family_care/services/api_client.dart';
import 'package:family_care/screens/shared/task_submission_recap.dart';

void main() {
  _overdueContractTests();
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

/// Contract BE 19/08: nộp bài quá hạn trả 400 kèm `code: "SUBMISSION_OVERDUE"`.
/// Bắt theo MÃ, không dò chuỗi message (message gốc là tiếng Anh).
void _overdueContractTests() {
  group('submitProofErrorMessage', () {
    test('mã SUBMISSION_OVERDUE ra câu tiếng Việt nói rõ phải làm gì', () {
      final msg = submitProofErrorMessage(
        ApiException(
          400,
          'Assignment is overdue and cannot accept submissions',
          code: 'SUBMISSION_OVERDUE',
        ),
      );
      expect(msg, contains('quá hạn'));
      expect(msg, contains('gia hạn'));
      expect(msg, isNot(contains('Assignment is overdue')));
    });

    test('đọc được cả khi BE để mã ở errorCode', () {
      // ApiClient gom `code` và `errorCode` về cùng một chỗ khi dựng exception.
      final msg = submitProofErrorMessage(
        ApiException(400, 'bất kỳ', code: 'SUBMISSION_OVERDUE'),
      );
      expect(msg, contains('quá hạn'));
    });

    test('lỗi khác giữ nguyên message của BE', () {
      final msg = submitProofErrorMessage(
        ApiException(400, 'Minh chứng không hợp lệ', code: 'OTHER'),
      );
      expect(msg, 'Minh chứng không hợp lệ');
    });

    test('exception thường thì cắt tiền tố Exception:', () {
      expect(submitProofErrorMessage(Exception('mất mạng')), 'mất mạng');
    });
  });
}
