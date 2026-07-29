import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/chat_provider.dart';

void main() {
  group('ChatProvider.searchMessages — guard trước khi gọi mạng', () {
    test('chưa mở hội thoại nào thì trả rỗng, không gọi API', () async {
      final chat = ChatProvider();
      expect(chat.conversationId, isNull);

      // Không có conversationId → phải thoát sớm. Nếu guard sai, test này sẽ
      // ném lỗi mạng thay vì trả rỗng.
      await expectLater(chat.searchMessages('bất kỳ'), completion(isEmpty));
    });

    test('từ khóa rỗng hoặc chỉ khoảng trắng thì trả rỗng', () async {
      final chat = ChatProvider();

      await expectLater(chat.searchMessages(''), completion(isEmpty));
      await expectLater(chat.searchMessages('   '), completion(isEmpty));
    });
  });

  group('ChatMessage cho màn tìm kiếm', () {
    test('tin đã thu hồi được nhận biết để lọc khỏi kết quả', () {
      final deleted = ChatMessage.fromJson({
        'id': 'm1',
        'content': 'nội dung cũ',
        'isDeleted': true,
      });

      expect(deleted.isDeleted, isTrue);
    });

    test('tin chỉ có đính kèm thì content rỗng, vẫn giữ được attachment', () {
      final m = ChatMessage.fromJson({
        'id': 'm2',
        'content': '',
        'messageType': 'IMAGE',
        'attachments': [
          {'id': 'a1', 'fileType': 'image/jpeg', 'fileUrl': 'https://x/y.jpg'},
        ],
      });

      expect(m.content, isEmpty);
      expect(m.attachments.single.isImage, isTrue);
    });
  });
}
