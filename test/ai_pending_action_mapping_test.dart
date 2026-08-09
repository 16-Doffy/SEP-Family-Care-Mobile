import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/ai_chatbot.dart';

/// Khoá contract parse của `AiPendingAction` — đề xuất hành động ghi của trợ lý
/// AI (tạo giao dịch / nhiệm vụ / sự kiện lịch).
///
/// OpenAPI 2026-08-07 đã có `AiPendingActionResponseDto`, `AiActionType` và
/// `AiActionStatus`. Parser vẫn đọc phòng thủ vài tên field legacy để không vỡ
/// nếu gặp dữ liệu cũ, còn các test dưới đây khóa contract chính thức.
///
/// Điểm quan trọng nhất: `isPending` là thứ quyết định có hiện nút xác nhận hay
/// không. Sai chỗ này thì người dùng bấm vào chỉ nhận 409 (đã xử lý) hoặc 410
/// (đã hết hạn).
void main() {
  group('AiPendingAction — đọc field', () {
    test('đọc actionType, status, preview và expiresAt', () {
      final a = AiPendingAction.fromJson({
        'messageId': 'msg-1',
        'actionType': 'CREATE_LEDGER_ENTRY',
        'status': 'PENDING',
        'preview': {'amount': 250000, 'description': 'Mua thực phẩm'},
        'expiresAt': '2030-01-01T00:00:00.000Z',
      });

      expect(a.messageId, 'msg-1');
      expect(a.actionType, 'CREATE_LEDGER_ENTRY');
      expect(a.status, 'PENDING');
      expect(a.preview['amount'], 250000);
      expect(a.expiresAt, isNotNull);
    });

    test('preview đọc được cả `payload` và `data`', () {
      Map<String, dynamic> preview(Map<String, dynamic> j) =>
          AiPendingAction.fromJson(j).preview;

      expect(
        preview({
          'preview': {'a': 1},
        })['a'],
        1,
      );
      expect(
        preview({
          'payload': {'b': 2},
        })['b'],
        2,
      );
      expect(
        preview({
          'data': {'c': 3},
        })['c'],
        3,
      );
    });

    test('preview không phải Map thì trả map rỗng, không ném lỗi', () {
      expect(
        AiPendingAction.fromJson({'preview': 'không phải map'}).preview,
        isEmpty,
      );
      expect(AiPendingAction.fromJson({}).preview, isEmpty);
    });

    test('thiếu status thì mặc định PENDING', () {
      expect(
        AiPendingAction.fromJson({'actionType': 'CREATE_TASK'}).status,
        'PENDING',
      );
    });
  });

  group('AiPendingAction — messageId là thứ gọi confirm-action', () {
    // Endpoint xác nhận là
    // POST .../conversations/{conversationId}/messages/{messageId}/confirm-action
    // nên messageId sai là không xác nhận được đề xuất nào.
    test('ưu tiên messageId, rồi aiMessageId, rồi id', () {
      String id(Map<String, dynamic> j) =>
          AiPendingAction.fromJson(j).messageId;

      expect(id({'messageId': 'a', 'aiMessageId': 'b', 'id': 'c'}), 'a');
      expect(id({'aiMessageId': 'b', 'id': 'c'}), 'b');
      expect(id({'id': 'c'}), 'c');
    });

    test('action không có id riêng thì lấy id của chính tin nhắn', () {
      final a = AiPendingAction.fromJson({
        'actionType': 'CREATE_TASK',
      }, fallbackMessageId: 'msg-99');
      expect(a.messageId, 'msg-99');
    });

    test(
      'AiMessage tự truyền id của mình xuống cho pendingAction lồng bên trong',
      () {
        final m = AiMessage.fromJson({
          'id': 'msg-7',
          'senderType': 'AI',
          'content': 'Tôi có thể tạo giao dịch này giúp bạn.',
          'pendingAction': {'actionType': 'CREATE_LEDGER_ENTRY'},
        });

        expect(m.pendingAction, isNotNull);
        expect(
          m.pendingAction!.messageId,
          'msg-7',
          reason: 'thiếu fallback thì nút Xác nhận gọi vào messageId rỗng',
        );
      },
    );
  });

  group('AiPendingAction — isPending quyết định có hiện nút Xác nhận', () {
    AiPendingAction make({required String status, DateTime? expiresAt}) =>
        AiPendingAction.fromJson({
          'messageId': 'msg-1',
          'actionType': 'CREATE_TASK',
          'status': status,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        });

    test('PENDING và chưa hết hạn → còn xác nhận được', () {
      final a = make(
        status: 'PENDING',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(a.isPending, isTrue);
    });

    test('PENDING nhưng đã quá expiresAt → KHÔNG còn (BE sẽ trả 410)', () {
      final a = make(
        status: 'PENDING',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(
        a.isPending,
        isFalse,
        reason: 'để nút bấm được thì người dùng chỉ nhận lỗi hết hạn',
      );
    });

    test('không có expiresAt thì coi như chưa hết hạn', () {
      expect(make(status: 'PENDING').isPending, isTrue);
    });

    test('đã xử lý rồi → KHÔNG còn (BE sẽ trả 409)', () {
      expect(make(status: 'CONFIRMED').isPending, isFalse);
      expect(make(status: 'REJECTED').isPending, isFalse);
      expect(make(status: 'EXPIRED').isPending, isFalse);
    });
  });

  group('AiPendingAction — nhãn hiển thị theo loại hành động', () {
    String label(String type) =>
        AiPendingAction.fromJson({'actionType': type}).actionLabel;

    test('giao dịch tài chính', () {
      expect(label('CREATE_LEDGER_ENTRY'), 'Tạo thu/chi');
      expect(label('CREATE_TRANSACTION'), 'Tạo thu/chi');
      expect(label('FINANCE_LEDGER_CREATE'), 'Tạo thu/chi');
    });

    test('nhiệm vụ và lịch', () {
      expect(label('CREATE_TASK'), 'Tạo nhiệm vụ');
      expect(label('TASK_CREATE'), 'Tạo nhiệm vụ');
      expect(label('CREATE_CALENDAR_EVENT'), 'Tạo sự kiện lịch');
      expect(label('CALENDAR_EVENT_CREATE'), 'Tạo sự kiện lịch');
    });

    test('không phân biệt hoa thường', () {
      expect(label('create_task'), 'Tạo nhiệm vụ');
    });

    test('loại lạ vẫn hiện nhãn chung, không để trống nút', () {
      expect(label('SOMETHING_NEW_FROM_BE'), 'Thực hiện đề xuất');
      expect(label(''), 'Thực hiện đề xuất');
    });
  });

  group('AiMessage — tin nhắn không kèm đề xuất', () {
    test('không có pendingAction thì để null, UI không hiện thẻ xác nhận', () {
      final m = AiMessage.fromJson({
        'id': 'msg-1',
        'senderType': 'AI',
        'content': 'Tháng này nhà mình tiêu 9.700.000đ.',
      });
      expect(m.pendingAction, isNull);
    });

    test('pendingAction không phải Map thì bỏ qua an toàn', () {
      final m = AiMessage.fromJson({
        'id': 'msg-1',
        'content': 'x',
        'pendingAction': 'không phải map',
      });
      expect(m.pendingAction, isNull);
    });

    test('phân biệt tin của người dùng và của AI', () {
      bool isUser(String type) => AiMessage.fromJson({
        'id': 'm',
        'senderType': type,
        'content': 'x',
      }).isUser;

      expect(isUser('USER'), isTrue);
      expect(isUser('MEMBER'), isTrue);
      expect(isUser('HUMAN'), isTrue);
      expect(isUser('AI'), isFalse);
      expect(isUser('ASSISTANT'), isFalse);
    });

    test(
      'thiếu senderType thì mặc định là AI, không nhận nhầm là người dùng',
      () {
        expect(AiMessage.fromJson({'id': 'm', 'content': 'x'}).isUser, isFalse);
      },
    );
  });
}
