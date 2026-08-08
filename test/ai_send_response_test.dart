import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/ai_chatbot_provider.dart';

/// Đọc response của `POST .../ai-chatbot/conversations/:id/messages`.
///
/// OpenAPI 2026-08-07 đã khai `AiSendMessageApiResponseDto`. Test này giữ lại
/// case response chỉ có `pendingAction`, không kèm câu trả lời, vì đây từng là
/// chỗ UI nuốt mất thẻ xác nhận.
void main() {
  group('response chỉ có pendingAction', () {
    test('vẫn hiện thẻ đề xuất, không nuốt mất', () {
      final provider = AiChatbotProvider();

      // Đúng nguyên văn ví dụ backend gửi.
      provider.appendSendResponse({
        'pendingAction': {
          'messageId': 'ai-message-id',
          'actionType': 'CREATE_CALENDAR_EVENT',
          'preview': {
            'title': 'Khám sức khỏe',
            'startTime': '2026-07-25T02:00:00.000Z',
            'location': 'Bệnh viện Gia Định',
          },
          'expiresAt': '2030-01-01T00:00:00.000Z',
        },
      });

      expect(
        provider.messages,
        hasLength(1),
        reason:
            'Không đỡ ca này thì người dùng gửi tin xong màn hình trống '
            'trơn, dù server đã tạo đề xuất chờ xác nhận',
      );
      final action = provider.messages.single.pendingAction;
      expect(action, isNotNull);
      expect(action!.actionType, 'CREATE_CALENDAR_EVENT');
      expect(action.messageId, 'ai-message-id');
      expect(action.preview['title'], 'Khám sức khỏe');
      expect(provider.messages.single.content.trim(), isNotEmpty);
    });
  });

  group('các hình dạng response khác vẫn đọc được', () {
    test('có aiMessage kèm pendingAction ở gốc', () {
      final provider = AiChatbotProvider();
      provider.appendSendResponse({
        'userMessage': {'id': 'u1', 'senderType': 'USER', 'content': 'ghi chi'},
        'aiMessage': {'id': 'a1', 'senderType': 'AI', 'content': 'Đã tạo'},
        'pendingAction': {
          'messageId': 'a1',
          'actionType': 'CREATE_LEDGER_ENTRY',
          'preview': {'amount': 200000},
        },
      });

      expect(provider.messages, hasLength(2));
      expect(provider.messages.first.isUser, isTrue);
      expect(
        provider.messages.last.pendingAction?.actionType,
        'CREATE_LEDGER_ENTRY',
      );
    });

    test('chỉ có content phẳng ở gốc', () {
      final provider = AiChatbotProvider();
      provider.appendSendResponse({
        'id': 'a1',
        'content': 'Tháng này nhà mình chưa chi khoản nào.',
      });

      expect(provider.messages, hasLength(1));
      expect(provider.messages.single.pendingAction, isNull);
    });

    test('response rỗng thì không thêm bong bóng rác', () {
      final provider = AiChatbotProvider();
      provider.appendSendResponse({});
      expect(provider.messages, isEmpty);
    });
  });
}
