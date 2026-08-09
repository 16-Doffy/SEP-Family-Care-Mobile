import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';

/// BE Sprint 3 (2026-08-09, backward-compatible): một message giờ có thể có
/// NHIỀU đề xuất (`pendingActions[]`), hiển thị dạng `ACTION_PLAN_CARD`.
/// `pendingAction` (số ít) vẫn còn — BE nói rõ nó là alias của
/// `pendingActions[0]` để FE cũ không vỡ. Test này khóa đúng 2 điều: dữ liệu
/// MỚI parse đúng, và hành vi CŨ (message chỉ có `pendingAction`) không đổi.
void main() {
  group('pendingActions[] — dữ liệu mới Sprint 3', () {
    test('parse đủ nhiều step, actionIndex lấy từ vị trí mảng khi JSON không '
        'tự có field actionIndex', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'Kế hoạch 2 bước',
        'uiHints': {'displayStyle': 'ACTION_PLAN_CARD'},
        'pendingActions': [
          {'actionType': 'CREATE_TASK', 'status': 'PENDING'},
          {'actionType': 'CREATE_LEDGER_ENTRY', 'status': 'PENDING'},
        ],
      });
      expect(m.pendingActions, hasLength(2));
      expect(m.pendingActions[0].actionIndex, 0);
      expect(m.pendingActions[0].actionType, 'CREATE_TASK');
      expect(m.pendingActions[1].actionIndex, 1);
      expect(m.pendingActions[1].actionType, 'CREATE_LEDGER_ENTRY');
    });

    test('BE tự gửi actionIndex thì ưu tiên đọc trực tiếp, không dùng vị trí '
        'mảng', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'pendingActions': [
          {'actionType': 'CREATE_TASK', 'actionIndex': 7},
        ],
      });
      expect(m.pendingActions.single.actionIndex, 7);
    });

    test('pendingAction (số ít) là alias của pendingActions[0]', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'pendingActions': [
          {'actionType': 'CREATE_TASK'},
          {'actionType': 'CREATE_LEDGER_ENTRY'},
        ],
      });
      expect(m.pendingAction, same(m.pendingActions.first));
      expect(m.pendingAction!.actionType, 'CREATE_TASK');
    });

    test('displayStyle ACTION_PLAN_CARD được nhận diện và ưu tiên hơn quy '
        'tắc "đã xử lý thì ép actionCard" của action đơn lẻ', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'uiHints': {'displayStyle': 'ACTION_PLAN_CARD'},
        'pendingActions': [
          {'actionType': 'CREATE_TASK', 'status': 'REJECTED'},
        ],
      });
      expect(m.effectiveDisplayStyle, AiDisplayStyle.actionPlanCard);
    });

    test('pendingActions rỗng thì coi như không có đề xuất nào, không throw', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'pendingActions': <Map<String, dynamic>>[],
      });
      expect(m.pendingActions, isEmpty);
      expect(m.pendingAction, isNull);
    });
  });

  group('pendingAction — dữ liệu cũ trước Sprint 3, không được đổi hành vi', () {
    test('message chỉ có pendingAction số ít vẫn parse đúng, tự bọc thành '
        'pendingActions 1 phần tử', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'pendingAction': {'actionType': 'CREATE_CALENDAR_EVENT'},
      });
      expect(m.pendingActions, hasLength(1));
      expect(m.pendingAction!.actionType, 'CREATE_CALENDAR_EVENT');
      expect(m.pendingAction!.actionIndex, 0);
    });

    test('message không có pendingAction lẫn pendingActions thì cả hai đều '
        'rỗng/null, không throw', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'Tháng này nhà mình chi 690.122đ.',
      });
      expect(m.pendingActions, isEmpty);
      expect(m.pendingAction, isNull);
    });

    test('tham số pendingAction truyền tay (dùng khi BE gửi envelope kiểu '
        'cũ, pendingAction nằm ngoài aiMessage) vẫn ưu tiên và bọc đúng', () {
      final override = AiPendingAction.fromJson({
        'messageId': 'm1',
        'actionType': 'CREATE_TASK',
      });
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'Tôi đã chuẩn bị một đề xuất.',
      }, pendingAction: override);
      expect(m.pendingActions, [same(override)]);
      expect(m.pendingAction, same(override));
    });
  });
}
