import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/ai_chatbot_provider.dart';

/// Swagger khai `page` và `limit` cho hai endpoint GET của AI Chatbot, nhưng
/// trước 2026-08-07 FE cứng `page=1`: quá 20 hội thoại hoặc quá 50 tin nhắn là
/// không còn đường lấy phần còn lại.
void main() {
  group('trạng thái phân trang khi chưa tải gì', () {
    test('danh sách rỗng thì không mời tải thêm', () {
      final provider = AiChatbotProvider();
      expect(provider.conversations, isEmpty);
      expect(provider.messages, isEmpty);
      expect(provider.hasMoreConversations, isFalse);
      expect(provider.hasMoreMessages, isFalse);
      expect(provider.loadingMoreConversations, isFalse);
      expect(provider.loadingMoreMessages, isFalse);
    });

    test('loadMore khi không còn trang thì không làm gì, không văng', () async {
      final provider = AiChatbotProvider();
      await provider.loadMoreConversations();
      await provider.loadMoreMessages();
      expect(provider.conversations, isEmpty);
      expect(provider.messages, isEmpty);
    });
  });

  group('đổi hội thoại và đăng xuất phải reset con trỏ trang', () {
    test('tạo hội thoại mới thì con trỏ tin nhắn về đầu', () {
      final provider = AiChatbotProvider();
      provider.startNewConversation();
      expect(provider.currentConversationId, isNull);
      expect(provider.messages, isEmpty);
      expect(
        provider.hasMoreMessages,
        isFalse,
        reason:
            'Giữ con trỏ trang của hội thoại cũ là tải nhầm trang cho hội '
            'thoại mới',
      );
    });

    test('dọn phiên đưa mọi cờ phân trang về mặc định', () {
      final provider = AiChatbotProvider();
      provider.resetForNewSession();
      expect(provider.hasMoreConversations, isFalse);
      expect(provider.hasMoreMessages, isFalse);
      expect(provider.loadingMoreConversations, isFalse);
      expect(provider.loadingMoreMessages, isFalse);
    });
  });

  group('gửi tin nhắn không được đụng vào dữ liệu đang có', () {
    test('ghép response vào danh sách không xóa tin nhắn cũ', () {
      final provider = AiChatbotProvider();

      provider.appendSendResponse({
        'aiMessage': {'id': 'a1', 'senderType': 'AI', 'content': 'câu một'},
      });
      provider.appendSendResponse({
        'aiMessage': {'id': 'a2', 'senderType': 'AI', 'content': 'câu hai'},
      });

      expect(
        provider.messages.map((m) => m.id),
        containsAll(<String>['a1', 'a2']),
        reason: 'Tin nhắn trước đó phải còn nguyên sau mỗi lần gửi',
      );
    });
  });
}
