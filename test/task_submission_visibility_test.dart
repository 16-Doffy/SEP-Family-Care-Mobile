import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/task_provider.dart';
import 'package:family_care/services/api_client.dart';
import 'package:family_care/screens/shared/task_submission_recap.dart';

void main() {
  _isOverdueFromServerTests();
  _notStartedAssignmentTests();
  _overdueAssignmentTests();
  _pickSubmissionTests();
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

void _notStartedAssignmentTests() {
  final now = DateTime.parse('2026-08-28T10:00:00Z');
  TaskAssignment assignment(String? startAt) => TaskAssignment(
    id: 'a1',
    taskId: 't1',
    assignedToMemberId: 'm1',
    status: 'ASSIGNED',
    startAt: startAt == null ? null : DateTime.parse(startAt),
  );

  group('isAssignmentNotStarted', () {
    test('khóa lần định kỳ ở ngày/giờ tương lai', () {
      expect(
        isAssignmentNotStarted(assignment('2026-08-29T08:00:00Z'), now: now),
        isTrue,
      );
    });

    test('đúng mốc bắt đầu và sau đó được làm', () {
      expect(
        isAssignmentNotStarted(assignment('2026-08-28T10:00:00Z'), now: now),
        isFalse,
      );
      expect(
        isAssignmentNotStarted(assignment('2026-08-28T09:59:00Z'), now: now),
        isFalse,
      );
    });

    test('không có startAt vẫn giữ hành vi task cũ', () {
      expect(isAssignmentNotStarted(assignment(null), now: now), isFalse);
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

TaskSubmission _sub(String id, String status, String? at) => TaskSubmission(
  id: id,
  assignmentId: 'a1',
  status: status,
  submittedAt: at == null ? null : DateTime.parse(at),
);

/// Bug máy thật 19/08: mở sheet duyệt lại bốc trúng bài nộp CŨ đã xử lý xong,
/// bấm Duyệt thì BE trả "Chỉ có thể duyệt minh chứng đang chờ xem xét". Gốc là
/// code lấy `list.last` — phần tử cuối mảng, không phải bài mới nhất.
void _pickSubmissionTests() {
  group('pickSubmissionToShow', () {
    test('BE trả mới-nhất-trước: KHÔNG được lấy phần tử cuối', () {
      final picked = pickSubmissionToShow([
        _sub('moi', TaskSubmission.waitingReview, '2026-08-19T13:00:00Z'),
        _sub('cu', 'REJECTED', '2026-08-18T09:00:00Z'),
      ]);
      expect(picked!.id, 'moi');
    });

    test('BE trả cũ-trước: vẫn ra bài mới nhất', () {
      final picked = pickSubmissionToShow([
        _sub('cu', 'REJECTED', '2026-08-18T09:00:00Z'),
        _sub('moi', TaskSubmission.waitingReview, '2026-08-19T13:00:00Z'),
      ]);
      expect(picked!.id, 'moi');
    });

    test('ưu tiên bài đang chờ duyệt dù có bài đã duyệt mới hơn', () {
      // Người duyệt cần xử lý bài còn chờ, không phải bài đã xong.
      final picked = pickSubmissionToShow([
        _sub('da-duyet', 'APPROVED', '2026-08-19T15:00:00Z'),
        _sub('cho-duyet', TaskSubmission.waitingReview, '2026-08-19T10:00:00Z'),
      ]);
      expect(picked!.id, 'cho-duyet');
    });

    test('nhiều bài chờ duyệt thì lấy bài chờ mới nhất', () {
      final picked = pickSubmissionToShow([
        _sub('cho-cu', TaskSubmission.waitingReview, '2026-08-19T08:00:00Z'),
        _sub('cho-moi', TaskSubmission.waitingReview, '2026-08-19T12:00:00Z'),
      ]);
      expect(picked!.id, 'cho-moi');
    });

    test('không còn bài chờ duyệt thì lấy bài mới nhất để xem lại', () {
      final picked = pickSubmissionToShow([
        _sub('cu', 'REJECTED', '2026-08-18T09:00:00Z'),
        _sub('moi', 'APPROVED', '2026-08-19T09:00:00Z'),
      ]);
      expect(picked!.id, 'moi');
      expect(picked.isWaitingReview, isFalse);
    });

    test('thiếu submittedAt thì coi là cũ hơn bài có mốc', () {
      final picked = pickSubmissionToShow([
        _sub('khong-moc', 'APPROVED', null),
        _sub('co-moc', 'APPROVED', '2026-08-19T09:00:00Z'),
      ]);
      expect(picked!.id, 'co-moc');
    });

    test('danh sách rỗng trả null', () {
      expect(pickSubmissionToShow(const []), isNull);
    });
  });

  group('TaskSubmission — enum và isLate theo Swagger 19/08', () {
    test('mặc định là WAITING_REVIEW, không phải PENDING', () {
      final s = TaskSubmission.fromJson({'id': 's1'});
      expect(s.status, 'WAITING_REVIEW');
      expect(s.isWaitingReview, isTrue);
    });

    test('đọc isLate và submittedAt của BE', () {
      final s = TaskSubmission.fromJson({
        'id': 's1',
        'status': 'APPROVED',
        'isLate': true,
        'submittedAt': '2026-08-19T13:40:00Z',
      });
      expect(s.isLate, isTrue);
      expect(s.isWaitingReview, isFalse);
      expect(s.submittedAt, isNotNull);
    });

    test('BE chưa trả isLate thì mặc định false, không nổ', () {
      expect(TaskSubmission.fromJson({'id': 's1'}).isLate, isFalse);
      expect(TaskSubmission.fromJson({'id': 's1'}).submittedAt, isNull);
    });
  });
}

TaskAssignment _asg(String status, String? due) => TaskAssignment(
  id: 'a1',
  taskId: 't1',
  assignedToMemberId: 'm1',
  status: status,
  dueAt: due == null ? null : DateTime.parse(due),
);

/// Quá hạn quyết định: member có nộp được không, và manager có thấy nút
/// "Giao lại + hạn mới" không. Sai chỗ này là phân công chết cứng.
void _overdueAssignmentTests() {
  final now = DateTime.parse('2026-08-19T15:00:00Z');

  group('isAssignmentOverdue', () {
    test('hạn đã qua và việc còn sống thì tính là quá hạn', () {
      for (final s in ['ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'PENDING']) {
        expect(
          isAssignmentOverdue(_asg(s, '2026-08-19T14:58:00Z'), now: now),
          isTrue,
          reason: s,
        );
      }
    });

    test('việc đã kết thúc thì hạn hết ý nghĩa', () {
      for (final s in ['APPROVED', 'CANCELED', 'REJECTED']) {
        expect(
          isAssignmentOverdue(_asg(s, '2026-08-18T00:00:00Z'), now: now),
          isFalse,
          reason: s,
        );
      }
    });

    test('chưa tới hạn thì không phải quá hạn', () {
      expect(
        isAssignmentOverdue(_asg('ASSIGNED', '2026-08-19T15:50:00Z'), now: now),
        isFalse,
      );
    });

    test('không có hạn thì không bao giờ quá hạn', () {
      expect(isAssignmentOverdue(_asg('ASSIGNED', null), now: now), isFalse);
    });

    test('đúng mốc hạn chưa tính là trễ', () {
      expect(
        isAssignmentOverdue(_asg('ASSIGNED', '2026-08-19T15:00:00Z'), now: now),
        isFalse,
      );
    });
  });
}

/// BE bổ sung `isOverdue` vào TaskAssignmentResponseDto (19/08). Đây mới là
/// nguồn quyết định có chặn nộp bài hay không, nên phải thắng phép tự tính.
void _isOverdueFromServerTests() {
  final now = DateTime.parse('2026-08-19T15:00:00Z');

  TaskAssignment fromBe({required bool? isOverdue, String? due}) =>
      TaskAssignment.fromJson({
        'id': 'a1',
        'taskId': 't1',
        'assignedToMemberId': 'm1',
        'status': 'ASSIGNED',
        'isOverdue': ?isOverdue,
        'dueAt': ?due,
      });

  group('isAssignmentOverdue — ưu tiên isOverdue của BE', () {
    test('BE nói quá hạn thì tin BE dù hạn còn ở tương lai', () {
      final a = fromBe(isOverdue: true, due: '2026-08-20T00:00:00Z');
      expect(isAssignmentOverdue(a, now: now), isTrue);
    });

    test('BE nói chưa quá hạn thì tin BE dù hạn đã qua', () {
      final a = fromBe(isOverdue: false, due: '2026-08-18T00:00:00Z');
      expect(isAssignmentOverdue(a, now: now), isFalse);
    });

    test('BE cũ không trả field thì tự tính từ dueAt như trước', () {
      expect(
        isAssignmentOverdue(
          fromBe(isOverdue: null, due: '2026-08-18T00:00:00Z'),
          now: now,
        ),
        isTrue,
      );
      expect(
        isAssignmentOverdue(
          fromBe(isOverdue: null, due: '2026-08-20T00:00:00Z'),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
