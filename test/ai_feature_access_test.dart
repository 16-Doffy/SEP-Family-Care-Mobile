import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';
import 'package:family_care/models/feature_access.dart';

void main() {
  group('FeatureAccess — key AI phải khớp danh sách chính thức của BE', () {
    test('đọc được ai.assistant, tên key FE từng dùng đã sai chuẩn', () {
      final access = FeatureAccess.fromJson({'ai.assistant': true});
      expect(access.aiAssistant, isTrue);
      // Đây là hai tên FE đọc trước 2026-08-07. Không nằm trong 26 key chính
      // thức nên gói trả phí vẫn cho ra false — lỗi im lặng đã fix.
      expect(FeatureAccess.officialKeys, isNot(contains('ai.enabled')));
      expect(FeatureAccess.officialKeys, isNot(contains('ai.chatbot')));
    });

    test('gói không bật thì false, không fail-open ở tầng model', () {
      final access = FeatureAccess.fromJson({'ai.assistant': false});
      expect(access.aiAssistant, isFalse);
    });

    test(
      'vẫn đọc được plan cũ trong DB còn dùng key ai.enabled / ai.chatbot',
      () {
        expect(
          FeatureAccess.fromJson({'ai.enabled': true}).aiAssistant,
          isTrue,
        );
        expect(
          FeatureAccess.fromJson({'ai.chatbot': true}).aiAssistant,
          isTrue,
        );
      },
    );

    test('key lồng dạng object cũng đọc được', () {
      final access = FeatureAccess.fromJson({
        'ai': {'assistant': true, 'financeSummary': true},
      });
      expect(access.aiAssistant, isTrue);
      expect(access.aiFinanceSummary, isTrue);
    });

    test('featureAccess rỗng là KHÔNG BIẾT, nơi gọi phải fail-open', () {
      final access = FeatureAccess.fromJson({});
      expect(access.isUnknown, isTrue);
      expect(access.aiAssistant, isFalse);
    });

    test('3 key AI phụ chưa có endpoint vẫn phải đọc đúng tên', () {
      final access = FeatureAccess.fromJson({
        'ai.financeSummary': true,
        'ai.taskSummary': true,
        'ai.savingSuggestions': true,
      });
      expect(access.aiFinanceSummary, isTrue);
      expect(access.aiTaskSummary, isTrue);
      expect(access.aiSavingSuggestions, isTrue);
    });

    test('đủ 26 key chính thức và mỗi key đều có nhãn tiếng Việt', () {
      expect(FeatureAccess.officialKeys, hasLength(26));
      for (final key in FeatureAccess.officialKeys) {
        expect(
          FeatureAccess.officialKeyLabels[key],
          isNotNull,
          reason: 'Thiếu nhãn cho key $key — màn Gói đăng ký sẽ hiện tên thô',
        );
      }
    });
  });

  group('AiPendingAction — actionType lạ không được im lặng', () {
    AiPendingAction parse(String type) =>
        AiPendingAction.fromJson({'messageId': 'm1', 'actionType': type});

    test('nhận diện được các loại FE đã map', () {
      for (final type in AiPendingAction.knownActionTypes) {
        expect(parse(type).isKnownActionType, isTrue, reason: type);
      }
    });

    test('BE thêm loại mới thì FE biết là mình chưa biết', () {
      final action = parse('CREATE_FUND_ALLOCATION');
      expect(action.isKnownActionType, isFalse);
      // Nhãn vẫn rơi về chung, nhưng actionType thô được giữ nguyên để UI hiện
      // ra và người dùng/dev thấy BE vừa gửi cái gì.
      expect(action.actionLabel, 'Thực hiện đề xuất');
      expect(action.actionType, 'CREATE_FUND_ALLOCATION');
    });

    test('so khớp không phân biệt hoa thường', () {
      expect(parse('create_task').isKnownActionType, isTrue);
    });

    test('BE không gửi actionType thì coi như lạ, không crash', () {
      final action = AiPendingAction.fromJson({'messageId': 'm1'});
      expect(action.actionType, isEmpty);
      expect(action.isKnownActionType, isFalse);
    });

    test('đề xuất hết hạn thì không còn PENDING', () {
      final action = AiPendingAction.fromJson({
        'messageId': 'm1',
        'actionType': 'CREATE_TASK',
        'status': 'PENDING',
        'expiresAt': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });
      expect(action.isPending, isFalse);
    });
  });
}
