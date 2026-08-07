import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/ai_chatbot_provider.dart';
import 'package:family_care/services/api_client.dart';

/// Rò rỉ dữ liệu giữa hai tài khoản trên cùng một máy.
///
/// Quan sát runtime 2026-08-07 trên emulator: đăng xuất Trưởng nhóm, đăng nhập
/// Thành viên, mở màn Trợ lý AI thì thấy nguyên hội thoại của Trưởng nhóm —
/// kể cả nội dung tài chính. Backend KHÔNG sai: danh sách hội thoại trả về cho
/// Thành viên là rỗng. Lỗi ở app: provider nằm ở app scope nên sống qua cả lần
/// đăng xuất, dữ liệu cũ vẫn nằm trong RAM.
void main() {
  group('Đổi tài khoản không được để lộ dữ liệu người trước', () {
    test('clearSession phải kích hoạt dọn provider đã đăng ký', () {
      var resetCount = 0;
      ApiClient.addSessionResetListener(() => resetCount++);

      ApiClient.instance.clearSession();

      expect(
        resetCount,
        greaterThan(0),
        reason: 'Đăng xuất mà không dọn provider là rò dữ liệu sang tài khoản '
            'đăng nhập sau',
      );
    });

    test('listener đăng ký một lần phải sống qua nhiều lần đăng xuất', () {
      var resetCount = 0;
      ApiClient.addSessionResetListener(() => resetCount++);

      ApiClient.instance.clearSession();
      final afterFirst = resetCount;
      ApiClient.instance.clearSession();

      expect(
        resetCount,
        greaterThan(afterFirst),
        reason: 'clearSession không được xóa danh sách listener, nếu không thì '
            'chỉ lần đăng xuất đầu tiên được dọn',
      );
    });

    test('một listener lỗi không được chặn các listener còn lại', () {
      var reachedLast = false;
      ApiClient.addSessionResetListener(() => throw Exception('lỗi giả lập'));
      ApiClient.addSessionResetListener(() => reachedLast = true);

      ApiClient.instance.clearSession();

      expect(
        reachedLast,
        isTrue,
        reason: 'Sót một provider là rò đúng provider đó',
      );
    });

    test('AiChatbotProvider dọn sạch state khi phiên kết thúc', () {
      final provider = AiChatbotProvider();

      provider.resetForNewSession();

      expect(provider.messages, isEmpty);
      expect(provider.conversations, isEmpty);
      expect(provider.currentConversationId, isNull);
      expect(provider.error, isNull);
      expect(provider.sending, isFalse);
      expect(provider.loadingMessages, isFalse);
      expect(provider.loadingConversations, isFalse);
      // Quyền của gói phải quay về "chưa biết" để fail-open, không giữ quyền
      // của gia đình cũ áp cho gia đình mới.
      expect(provider.accessUnknown, isTrue);
    });

    test('AiChatbotProvider tự đăng ký, không cần màn Đăng xuất nhớ gọi', () {
      final provider = AiChatbotProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      // Có 3 đường gọi clearSession: bấm đăng xuất, phiên hết hạn, và bị buộc
      // đăng xuất khi 401. Đăng ký trong constructor thì cả ba đều dọn được.
      ApiClient.instance.clearSession();

      expect(
        notified,
        isTrue,
        reason: 'Provider phải tự dọn khi clearSession, không phụ thuộc nơi gọi',
      );
    });
  });
}
