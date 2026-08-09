import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';

/// Khóa contract `uiHints` — BE Sprint 2. Thay hoàn toàn cách cũ FE tự đoán
/// qua `actionType`/chữ trong `content`: mọi quyết định render giờ dựa vào
/// `uiHints` (cấu trúc), không phải nội dung chữ.
void main() {
  group('AiDisplayStyle — parse đủ 5 kiểu BE chốt', () {
    AiMessage msg(String? displayStyle, {AiPendingAction? pendingAction}) =>
        AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'nội dung bất kỳ',
          if (displayStyle != null) 'uiHints': {'displayStyle': displayStyle},
        }, pendingAction: pendingAction);

    test('TEXT', () {
      expect(msg('TEXT').effectiveDisplayStyle, AiDisplayStyle.text);
    });

    test('INSIGHT_CARD', () {
      expect(
        msg('INSIGHT_CARD').effectiveDisplayStyle,
        AiDisplayStyle.insightCard,
      );
    });

    test('ACTION_CARD', () {
      expect(
        msg('ACTION_CARD').effectiveDisplayStyle,
        AiDisplayStyle.actionCard,
      );
    });

    test('PERMISSION_NOTICE', () {
      expect(
        msg('PERMISSION_NOTICE').effectiveDisplayStyle,
        AiDisplayStyle.permissionNotice,
      );
    });

    test('RESULT_CARD', () {
      expect(
        msg('RESULT_CARD').effectiveDisplayStyle,
        AiDisplayStyle.resultCard,
      );
    });

    test('PERMISSION_NOTICE không có pendingAction vẫn giữ đúng style, không '
        'rơi về text dù không có action đi kèm', () {
      final action = msg('PERMISSION_NOTICE');
      expect(action.pendingAction, isNull);
      expect(action.effectiveDisplayStyle, AiDisplayStyle.permissionNotice);
    });
  });

  group('effectiveDisplayStyle — fallback khi thiếu uiHints (dữ liệu cũ)', () {
    test(
      'không có uiHints, có pendingAction → actionCard (đúng hành vi cũ)',
      () {
        final m = AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'Tôi có thể tạo giao dịch này giúp bạn.',
          'pendingAction': {'actionType': 'CREATE_LEDGER_ENTRY'},
        });
        expect(m.effectiveDisplayStyle, AiDisplayStyle.actionCard);
      },
    );

    test(
      'không có uiHints, không có pendingAction → text (đúng hành vi cũ)',
      () {
        final m = AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'Tháng này nhà mình chi 690.122đ.',
        });
        expect(m.effectiveDisplayStyle, AiDisplayStyle.text);
      },
    );

    test('displayStyle lạ/không nhận diện được cũng rơi về fallback theo cấu '
        'trúc, không throw', () {
      final withAction = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'uiHints': {'displayStyle': 'SOMETHING_NEW'},
        'pendingAction': {'actionType': 'CREATE_TASK'},
      });
      expect(withAction.effectiveDisplayStyle, AiDisplayStyle.actionCard);
    });

    test(
      'đề xuất ĐÃ TỪ CHỐI tin thẳng uiHints.displayStyle = RESULT_CARD — BE '
      'xác nhận sửa tận gốc 2026-08-09: REJECTED/CONFIRMED/EXPIRED giờ luôn '
      'trả đúng RESULT_CARD (trước đó có lúc trả nhầm INSIGHT_CARD, FE từng '
      'phải ép cứng actionCard để vá tạm — lớp vá đó đã bỏ)',
      () {
        final rejected = AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'Bạn đã từ chối đề xuất ghi khoản chi này.',
          'uiHints': {'displayStyle': 'RESULT_CARD'},
          'pendingAction': {
            'actionType': 'CREATE_LEDGER_ENTRY',
            'status': 'REJECTED',
          },
        });
        expect(rejected.effectiveDisplayStyle, AiDisplayStyle.resultCard);
      },
    );

    test('đề xuất ĐÃ XÁC NHẬN cũng tin thẳng uiHints.displayStyle', () {
      final confirmed = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'Đã ghi sổ.',
        'uiHints': {'displayStyle': 'RESULT_CARD'},
        'pendingAction': {
          'actionType': 'CREATE_LEDGER_ENTRY',
          'status': 'CONFIRMED',
        },
      });
      expect(confirmed.effectiveDisplayStyle, AiDisplayStyle.resultCard);
    });

    test('đề xuất còn PENDING thì vẫn tôn trọng uiHints như cũ (không đổi '
        'hành vi bình thường)', () {
      final pending = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'uiHints': {'displayStyle': 'INSIGHT_CARD'},
        'pendingAction': {
          'actionType': 'CREATE_LEDGER_ENTRY',
          'status': 'PENDING',
        },
      });
      expect(pending.effectiveDisplayStyle, AiDisplayStyle.insightCard);
    });
  });

  group('Test #9 của BE — không được đoán qua chữ trong content', () {
    test('content có chữ "xác nhận" nhưng không có pendingAction và không có '
        'uiHints ACTION_CARD → vẫn là text, không tự vẽ nút', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'Bạn cần xác nhận lại thông tin trên ứng dụng nhé.',
      });
      expect(m.effectiveDisplayStyle, AiDisplayStyle.text);
      expect(m.pendingAction, isNull);
    });

    test(
      'PERMISSION_NOTICE dù content chứa chữ "xác nhận" vẫn giữ nguyên style, '
      'không lẫn sang actionCard',
      () {
        final m = AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'Bạn không có quyền, cần Trưởng nhóm xác nhận giúp.',
          'uiHints': {'displayStyle': 'PERMISSION_NOTICE'},
        });
        expect(m.effectiveDisplayStyle, AiDisplayStyle.permissionNotice);
      },
    );
  });

  group('AiQuickAction — chip gợi ý, bấm gửi prompt chứ không gửi label', () {
    test('đọc đủ label và prompt', () {
      final q = AiQuickAction.fromJson({
        'label': 'Xem chi tiêu tháng này',
        'prompt': 'Tháng này nhà mình đã chi bao nhiêu?',
      });
      expect(q.label, 'Xem chi tiêu tháng này');
      expect(q.prompt, 'Tháng này nhà mình đã chi bao nhiêu?');
    });

    test('thiếu label thì rơi về prompt — luôn có chữ để hiện trên chip', () {
      final q = AiQuickAction.fromJson({'prompt': 'Hôm nay có gì?'});
      expect(q.label, 'Hôm nay có gì?');
    });

    test('quickActions rỗng/thiếu thì trả list rỗng, không crash', () {
      final m = AiMessage.fromJson({
        'id': 'm1',
        'senderType': 'AI',
        'content': 'x',
        'uiHints': {'displayStyle': 'INSIGHT_CARD'},
      });
      expect(m.uiHints!.quickActions, isEmpty);
    });

    test(
      'quickActions thiếu prompt bị lọc bỏ — chip không được rỗng hành động',
      () {
        final m = AiMessage.fromJson({
          'id': 'm1',
          'senderType': 'AI',
          'content': 'x',
          'uiHints': {
            'displayStyle': 'INSIGHT_CARD',
            'quickActions': [
              {'label': 'Không có prompt'},
              {'label': 'Có prompt', 'prompt': 'Tuần này có lịch gì?'},
            ],
          },
        });
        expect(m.uiHints!.quickActions, hasLength(1));
        expect(m.uiHints!.quickActions.single.prompt, 'Tuần này có lịch gì?');
      },
    );
  });

  group('AiPendingAction.displayFields — ưu tiên uiHints.fields', () {
    test('có uiHints.fields thì dùng thẳng, không suy từ preview', () {
      final action = AiPendingAction.fromJson({
        'messageId': 'm1',
        'actionType': 'CREATE_LEDGER_ENTRY',
        'preview': {'amount': 999999}, // phải bị bỏ qua
        'uiHints': {
          'title': 'Xác nhận tạo giao dịch',
          'fields': [
            {'key': 'amount', 'label': 'Số tiền', 'value': 200000},
            {'key': 'note', 'label': 'Nội dung', 'value': 'Tiền chợ'},
          ],
        },
      });
      expect(action.displayTitle, 'Xác nhận tạo giao dịch');
      expect(action.displayFields, hasLength(2));
      expect(action.displayFields.first.value, 200000);
    });

    test(
      'không có uiHints thì rơi về preview cũ — đúng hành vi trước Sprint 2',
      () {
        final action = AiPendingAction.fromJson({
          'messageId': 'm1',
          'actionType': 'CREATE_LEDGER_ENTRY',
          'preview': {'amount': 200000, 'note': 'Tiền chợ'},
        });
        expect(action.displayTitle, action.actionLabel);
        final fields = action.displayFields;
        expect(fields.map((f) => f.key), contains('amount'));
        expect(fields.firstWhere((f) => f.key == 'amount').label, 'Số tiền');
      },
    );

    test(
      'uiHints có nhưng fields rỗng vẫn rơi về preview, không hiện trống trơn',
      () {
        final action = AiPendingAction.fromJson({
          'messageId': 'm1',
          'actionType': 'CREATE_TASK',
          'preview': {'task': 'Dọn phòng khách'},
          'uiHints': {'title': 'Xác nhận tạo công việc', 'fields': []},
        });
        expect(action.displayFields, isNotEmpty);
        expect(action.displayFields.first.key, 'task');
      },
    );

    test(
      'primaryActionLabel/secondaryActionLabel/editActionLabel đọc đúng',
      () {
        final action = AiPendingAction.fromJson({
          'messageId': 'm1',
          'actionType': 'CREATE_TASK',
          'uiHints': {
            'primaryActionLabel': 'Tạo ngay',
            'secondaryActionLabel': 'Bỏ qua',
            'editActionLabel': 'Sửa lại',
          },
        });
        expect(action.uiHints!.primaryActionLabel, 'Tạo ngay');
        expect(action.uiHints!.secondaryActionLabel, 'Bỏ qua');
        expect(action.uiHints!.editActionLabel, 'Sửa lại');
      },
    );
  });

  group('isPending vẫn là nguồn duy nhất quyết định hiện nút — không đổi', () {
    test('ACTION_CARD nhưng status không PENDING thì isPending false', () {
      final action = AiPendingAction.fromJson({
        'messageId': 'm1',
        'actionType': 'CREATE_TASK',
        'status': 'CONFIRMED',
        'uiHints': {'primaryActionLabel': 'Tạo ngay'},
      });
      expect(action.isPending, isFalse);
    });
  });
}
