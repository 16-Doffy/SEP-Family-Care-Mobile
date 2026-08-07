import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';
import 'package:family_care/screens/shared/ai_assistant_screen.dart';

/// Khóa contract `pendingAction` theo tin nhắn BE gửi ngày 2026-08-07.
/// Swagger vẫn chưa khai schema cho nó, nên test này là chỗ duy nhất ghi lại
/// hình dạng đã thống nhất — BE đổi là test đỏ.
void main() {
  // Payload lấy nguyên văn từ ví dụ BE gửi.
  const beExample = {
    'messageId': 'ai-message-id',
    'actionType': 'CREATE_CALENDAR_EVENT',
    'preview': {
      'title': 'Khám sức khỏe',
      'startTime': '2026-07-25T02:00:00.000Z',
      'location': 'Bệnh viện Gia Định',
    },
    'expiresAt': '2026-07-24T06:00:00.000Z',
  };

  group('pendingAction — đúng ví dụ BE gửi', () {
    test('parse đủ 4 field, không rơi field nào', () {
      final action = AiPendingAction.fromJson(
        Map<String, dynamic>.from(beExample),
      );
      expect(action.messageId, 'ai-message-id');
      expect(action.actionType, 'CREATE_CALENDAR_EVENT');
      expect(action.preview['title'], 'Khám sức khỏe');
      expect(action.preview['location'], 'Bệnh viện Gia Định');
      expect(action.expiresAt, isNotNull);
    });

    test(
      'BE không gửi status thì mặc định PENDING, không mất nút xác nhận',
      () {
        final action = AiPendingAction.fromJson({
          ...beExample,
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        });
        expect(action.status, 'PENDING');
        expect(action.isPending, isTrue);
      },
    );

    test('đủ 3 actionType BE đã chốt và FE nhận diện được cả ba', () {
      expect(AiPendingAction.confirmedActionTypes, {
        'CREATE_TASK',
        'CREATE_LEDGER_ENTRY',
        'CREATE_CALENDAR_EVENT',
      });
      for (final type in AiPendingAction.confirmedActionTypes) {
        final action = AiPendingAction.fromJson({
          'messageId': 'm1',
          'actionType': type,
        });
        expect(action.isKnownActionType, isTrue, reason: type);
        expect(action.actionLabel, isNot('Thực hiện đề xuất'), reason: type);
      }
    });

    test('nhãn thẻ xác nhận đúng theo từng nhóm', () {
      String labelOf(String type) => AiPendingAction.fromJson({
        'messageId': 'm1',
        'actionType': type,
      }).actionLabel;

      expect(labelOf('CREATE_TASK'), 'Tạo nhiệm vụ');
      expect(labelOf('CREATE_LEDGER_ENTRY'), 'Tạo giao dịch');
      expect(labelOf('CREATE_CALENDAR_EVENT'), 'Tạo sự kiện lịch');
    });
  });

  group('kết cục đề xuất — xác nhận xong không được báo như lỗi', () {
    AiPendingAction withStatus(String status, {DateTime? expiresAt}) =>
        AiPendingAction.fromJson({
          'messageId': 'm1',
          'actionType': 'CREATE_LEDGER_ENTRY',
          'status': status,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        });

    test('xác nhận thành công là completed, không phải expired', () {
      // Quan sát runtime 2026-08-07: sau confirm-action thành công, thẻ vẫn
      // hiện chữ đỏ "Đề xuất đã hết hạn hoặc đã được xử lý" vì UI chỉ hỏi
      // isPending. Status thật BE trả chưa được chốt trong Swagger nên mọi
      // giá trị kết thúc không-phải-từ-chối đều phải rơi vào completed.
      for (final status in ['COMPLETED', 'CONFIRMED', 'EXECUTED', 'DONE']) {
        expect(
          withStatus(status).outcome,
          AiActionOutcome.completed,
          reason: status,
        );
      }
    });

    test('từ chối là rejected, không lẫn với hết hạn', () {
      for (final status in ['REJECTED', 'CANCELED', 'CANCELLED']) {
        expect(
          withStatus(status).outcome,
          AiActionOutcome.rejected,
          reason: status,
        );
      }
    });

    test('còn PENDING mà quá expiresAt mới là hết hạn thật', () {
      final expired = withStatus(
        'PENDING',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(expired.outcome, AiActionOutcome.expired);
      expect(expired.isPending, isFalse);
    });

    test('PENDING còn hạn thì vẫn bấm được', () {
      final alive = withStatus(
        'PENDING',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(alive.outcome, AiActionOutcome.pending);
      expect(alive.isPending, isTrue);
    });

    test('BE báo lỗi thì tách riêng khỏi hết hạn', () {
      expect(withStatus('FAILED').outcome, AiActionOutcome.failed);
    });
  });

  group('preview phải đọc được, không in dữ liệu thô', () {
    test(
      'thời gian ISO UTC đổi sang giờ địa phương, không in nguyên chuỗi',
      () {
        final raw = beExample['preview'] as Map;
        final shown = formatAiPreviewValue('startTime', raw['startTime']);
        expect(shown, isNot(contains('T')));
        expect(shown, isNot(contains('Z')));
        // 02:00 UTC = 09:00 giờ VN. Không hard-code múi giờ để test chạy được ở
        // mọi máy CI: so với chính giá trị đã đổi sang local.
        final expected = formatAiPreviewDateTime(
          DateTime.parse(raw['startTime'] as String).toLocal(),
        );
        expect(shown, expected);
      },
    );

    test('số tiền có dấu phân cách và đơn vị', () {
      expect(formatAiPreviewValue('amount', 200000), '200.000 ₫');
      expect(formatAiPreviewValue('amount', '1500000'), '1.500.000 ₫');
      expect(formatAiPreviewValue('amount', 5000.4), '5.000 ₫');
    });

    test('field chữ giữ nguyên, không bị format nhầm', () {
      expect(formatAiPreviewValue('title', 'Khám sức khỏe'), 'Khám sức khỏe');
      expect(
        formatAiPreviewValue('location', 'Bệnh viện Gia Định'),
        'Bệnh viện Gia Định',
      );
    });

    test('BE lồng object thì lấy tên hiển thị thay vì đổ cả map', () {
      expect(
        formatAiPreviewValue('assignee', {'id': 'uuid-1', 'name': 'Minh'}),
        'Minh',
      );
    });

    test('null và rỗng không làm vỡ thẻ preview', () {
      expect(formatAiPreviewValue('amount', null), '-');
      expect(formatAiPreviewValue('assignee', const []), '-');
      expect(
        formatAiPreviewValue('startTime', 'không-phải-ngày'),
        'không-phải-ngày',
      );
    });
  });

  group('reload lịch sau khi xác nhận', () {
    test('lấy đúng tháng của sự kiện, không phải tháng hiện tại', () {
      final month = calendarMonthToReload({
        'startTime': '2026-07-25T02:00:00.000Z',
      });
      final expected = DateTime.parse('2026-07-25T02:00:00.000Z').toLocal();
      expect(month.year, expected.year);
      expect(month.month, expected.month);
    });

    test('sự kiện sang tháng sau vẫn tải đúng tháng đó', () {
      final month = calendarMonthToReload({
        'startTime': '2026-09-01T01:00:00.000Z',
      });
      final expected = DateTime.parse('2026-09-01T01:00:00.000Z').toLocal();
      expect(month.month, expected.month);
    });

    test('preview thiếu thời gian thì lùi về tháng hiện tại, không crash', () {
      final month = calendarMonthToReload(const {'title': 'Khám sức khỏe'});
      final now = DateTime.now();
      expect(month.year, now.year);
      expect(month.month, now.month);
    });
  });
}
