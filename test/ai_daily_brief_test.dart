import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/ai_chatbot.dart';

/// `GET /families/{id}/ai-chatbot/daily-brief` — Sprint 2, BE không cho tên
/// field con cụ thể (task/calendar/finance/insights) nên `raw` được render qua
/// `JsonReportView` (quy ước repo cho response chưa rõ schema) thay vì đoán
/// tên field. Chỉ `suggestedPrompts` được tách riêng vì BE có nói rõ hình dạng.
void main() {
  group('AiDailyBrief.fromJson', () {
    test('giữ nguyên raw, trừ suggestedPrompts', () {
      final brief = AiDailyBrief.fromJson({
        'task': {'overdue': 2},
        'calendar': {'upcoming': 1},
        'suggestedPrompts': [
          {'label': 'Hôm nay có gì?', 'prompt': 'Hôm nay có gì?'},
        ],
      });

      expect(brief.raw.containsKey('task'), isTrue);
      expect(brief.raw.containsKey('calendar'), isTrue);
      expect(
        brief.raw.containsKey('suggestedPrompts'),
        isFalse,
        reason:
            'suggestedPrompts render riêng thành chip, không lẫn vào '
            'JsonReportView chung',
      );
    });

    test('parse suggestedPrompts thành AiQuickAction', () {
      final brief = AiDailyBrief.fromJson({
        'suggestedPrompts': [
          {'label': 'Việc hôm nay', 'prompt': 'Việc quan trọng hôm nay?'},
          {'prompt': 'Nhắc tôi hôm nay'},
        ],
      });

      expect(brief.suggestedPrompts, hasLength(2));
      expect(brief.suggestedPrompts.first.label, 'Việc hôm nay');
      expect(brief.suggestedPrompts.last.label, 'Nhắc tôi hôm nay');
    });

    test('response rỗng thì raw rỗng, suggestedPrompts rỗng, không crash', () {
      final brief = AiDailyBrief.fromJson({});
      expect(brief.raw, isEmpty);
      expect(brief.suggestedPrompts, isEmpty);
    });

    test('suggestedPrompts không phải List thì bỏ qua an toàn', () {
      final brief = AiDailyBrief.fromJson({
        'suggestedPrompts': 'không phải list',
      });
      expect(brief.suggestedPrompts, isEmpty);
    });
  });
}
