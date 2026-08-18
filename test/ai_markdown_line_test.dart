import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/screens/shared/ai_assistant_screen.dart';

/// BE trả câu trả lời AI dạng markdown; FE trước đây chỉ xử lý `**đậm**` nên
/// `###` và `-` lọt thẳng ra màn hình (quan sát runtime 2026-08-17). BE xác
/// nhận không đổi output, FE tự bóc.
void main() {
  group('parseAiMarkdownLines — tiêu đề', () {
    test('bóc dấu # và giữ đúng cấp', () {
      final lines = parseAiMarkdownLines('### Kết luận:');
      expect(lines, hasLength(1));
      expect(lines.first.kind, AiLineKind.heading);
      expect(lines.first.headingLevel, 3);
      expect(lines.first.text, 'Kết luận:');
    });

    test('nhận đủ cấp 1 tới 6', () {
      for (var level = 1; level <= 6; level++) {
        final line = parseAiMarkdownLines('${'#' * level} Tiêu đề').first;
        expect(line.kind, AiLineKind.heading);
        expect(line.headingLevel, level);
      }
    });

    test('hashtag không có khoảng trắng KHÔNG phải tiêu đề', () {
      // Nếu bắt lỏng thì "#giadinh" sẽ bị nuốt mất dấu #.
      final line = parseAiMarkdownLines('#giadinh vui vẻ').first;
      expect(line.kind, AiLineKind.normal);
      expect(line.text, '#giadinh vui vẻ');
    });

    test('quá 6 dấu # thì coi là chữ thường', () {
      final line = parseAiMarkdownLines('####### bảy dấu').first;
      expect(line.kind, AiLineKind.normal);
    });
  });

  group('parseAiMarkdownLines — gạch đầu dòng', () {
    test('bóc "- " và "* "', () {
      expect(
        parseAiMarkdownLines('- Tổng chi tiêu: 6.370.122 VND').first.kind,
        AiLineKind.bullet,
      );
      expect(parseAiMarkdownLines('* Mục hai').first.kind, AiLineKind.bullet);
      expect(
        parseAiMarkdownLines('- Tổng chi tiêu: 6.370.122 VND').first.text,
        'Tổng chi tiêu: 6.370.122 VND',
      );
    });

    test('số âm KHÔNG bị hiểu thành gạch đầu dòng', () {
      // "-500.000đ" không có khoảng trắng sau dấu trừ.
      final line = parseAiMarkdownLines('-500.000đ tiền chợ').first;
      expect(line.kind, AiLineKind.normal);
      expect(line.text, '-500.000đ tiền chợ');
    });

    test('danh sách đánh số giữ nguyên, vốn đã đọc được', () {
      final line = parseAiMarkdownLines('1. Giao dịch 1').first;
      expect(line.kind, AiLineKind.normal);
      expect(line.text, '1. Giao dịch 1');
    });
  });

  group('parseAiMarkdownLines — nguyên câu trả lời thật', () {
    test('giữ đúng số dòng và phân loại từng dòng', () {
      // Copy từ log runtime 2026-08-17.
      const raw =
          '### Tháng 8/2026, gia đình bạn đã tiêu hết:\n'
          '\n'
          '- **Tổng chi tiêu**: 6.370.122 VND\n'
          '\n'
          '### Kết luận:\n'
          'Tháng này, gia đình bạn đã tiêu hơn 6 triệu đồng.';

      final lines = parseAiMarkdownLines(raw);
      expect(lines, hasLength(6));
      expect(lines[0].kind, AiLineKind.heading);
      expect(lines[1].kind, AiLineKind.normal);
      expect(lines[2].kind, AiLineKind.bullet);
      expect(lines[4].kind, AiLineKind.heading);
      expect(lines[5].kind, AiLineKind.normal);

      // Không còn ký hiệu # nào sót lại ở đầu dòng.
      for (final line in lines) {
        expect(line.text.startsWith('#'), isFalse);
      }
      // `**đậm**` KHÔNG bị hàm này đụng tới — widget xử lý riêng.
      expect(lines[2].text, contains('**Tổng chi tiêu**'));
    });

    test('chuỗi rỗng ra đúng một dòng rỗng, không sập', () {
      final lines = parseAiMarkdownLines('');
      expect(lines, hasLength(1));
      expect(lines.first.kind, AiLineKind.normal);
      expect(lines.first.text, '');
    });
  });
}
