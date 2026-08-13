import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';
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
    test('Sprint 3 giữ đủ pendingActions[] ở response gửi tin', () {
      final provider = AiChatbotProvider();
      provider.appendSendResponse({
        'aiMessage': {
          'id': 'plan-1',
          'senderType': 'AI',
          'content': 'Tôi đã chuẩn bị kế hoạch.',
          'uiHints': {'displayStyle': 'ACTION_PLAN_CARD'},
        },
        // Theo contract: pendingAction chỉ là alias của phần tử đầu; mảng này
        // mới là nguồn đầy đủ để người dùng xác nhận/từ chối từng bước.
        'pendingAction': {
          'messageId': 'plan-1',
          'actionIndex': 0,
          'actionType': 'CREATE_CALENDAR_EVENT',
        },
        'pendingActions': [
          {
            'messageId': 'plan-1',
            'actionIndex': 0,
            'actionType': 'CREATE_CALENDAR_EVENT',
          },
          {
            'messageId': 'plan-1',
            'actionIndex': 1,
            'actionType': 'CREATE_LEDGER_ENTRY',
          },
        ],
      });

      final message = provider.messages.single;
      expect(message.pendingActions, hasLength(2));
      expect(message.pendingActions[1].actionIndex, 1);
      expect(message.pendingActions[1].actionType, 'CREATE_LEDGER_ENTRY');
    });

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

    test('calendar pending action giữ nguyên content chuẩn BE 2026-08-10', () {
      final provider = AiChatbotProvider();
      const content =
          'Mình đã tạo đề xuất lịch. Vui lòng kiểm tra thông tin và xác nhận '
          'trên ứng dụng để hoàn tất nhé.';

      provider.appendSendResponse({
        'aiMessage': {
          'id': 'calendar-pending-1',
          'senderType': 'AI',
          'content': content,
          'uiHints': {'displayStyle': 'ACTION_CARD'},
        },
        'pendingAction': {
          'messageId': 'calendar-pending-1',
          'actionType': 'CREATE_CALENDAR_EVENT',
          'status': 'PENDING',
          'preview': {
            'title': 'Đi dã ngoại',
            'startTime': '2026-08-15T15:00:00+07:00',
            'endTime': '2026-08-15T18:00:00+07:00',
            'location': 'Công viên Ánh Sáng',
          },
        },
      });

      final message = provider.messages.single;
      expect(message.content, content);
      expect(message.pendingAction?.actionType, 'CREATE_CALENDAR_EVENT');
      expect(message.pendingAction?.status, 'PENDING');
      expect(message.effectiveDisplayStyle, AiDisplayStyle.actionCard);
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
