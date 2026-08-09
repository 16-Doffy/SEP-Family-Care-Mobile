import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';

/// Khoá contract theo `AiConversationListItemResponseDto` trong OpenAPI
/// 2026-08-07 (bản BE ship kèm response DTO đầy đủ cho module AI Chatbot).
void main() {
  group('AiConversation — đúng schema BE vừa ship', () {
    test('đọc được lastMessage qua tên thật messageContent', () {
      // AiConversationLastMessageResponseDto dùng `messageContent`, KHÔNG phải
      // `content`. Đọc sai tên thì dòng xem trước dưới mỗi hội thoại trống
      // trơn — lỗi im lặng, không exception, không test nào khác bắt được.
      final c = AiConversation.fromJson({
        'id': 'conv-1',
        'conversationTitle': 'Hỏi về chi tiêu tháng 8',
        'createdAt': '2026-08-07T10:00:00.000Z',
        'lastMessage': {
          'senderType': 'AI',
          'messageContent': 'Tháng này nhà mình đã chi 200.000 VND.',
          'createdAt': '2026-08-07T10:01:00.000Z',
        },
      });

      expect(c.id, 'conv-1');
      expect(c.title, 'Hỏi về chi tiêu tháng 8');
      expect(c.lastMessage, 'Tháng này nhà mình đã chi 200.000 VND.');
      expect(c.createdAt, isNotNull);
    });

    test('vẫn đọc được dữ liệu cũ dùng tên content', () {
      final c = AiConversation.fromJson({
        'id': 'conv-2',
        'lastMessage': {'content': 'câu cũ'},
      });
      expect(c.lastMessage, 'câu cũ');
    });

    test('conversationTitle null thì có tên mặc định, không để trống', () {
      final c = AiConversation.fromJson({
        'id': 'conv-3',
        'conversationTitle': null,
        'createdAt': '2026-08-07T10:00:00.000Z',
      });
      expect(c.title, 'Cuộc trò chuyện mới');
    });

    test('lastMessage null thì không vỡ danh sách hội thoại', () {
      final c = AiConversation.fromJson({'id': 'conv-4', 'lastMessage': null});
      expect(c.lastMessage, isEmpty);
    });
  });
}
