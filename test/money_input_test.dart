import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/widgets/money_input.dart';

TextEditingValue _type(TextInputFormatter f, String text) =>
    f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    test('mặc định vẫn dùng dấu chấm — không đổi hành vi các màn cũ', () {
      const f = ThousandsSeparatorInputFormatter();
      expect(_type(f, '456789').text, '456.789');
      expect(_type(f, '1234567').text, '1.234.567');
    });

    test('dấu phẩy cho màn hiển thị theo dấu phẩy (456789 → 456,789)', () {
      const f = ThousandsSeparatorInputFormatter(separator: ',');
      expect(_type(f, '456789').text, '456,789');
      expect(_type(f, '1234567').text, '1,234,567');
      expect(_type(f, '50000').text, '50,000');
    });

    test('bỏ ký tự không phải số, rỗng thì trả rỗng', () {
      const f = ThousandsSeparatorInputFormatter(separator: ',');
      expect(_type(f, '4a5b6789').text, '456,789');
      expect(_type(f, 'abc').text, '');
    });

    test('con trỏ luôn ở cuối sau khi format', () {
      const f = ThousandsSeparatorInputFormatter(separator: ',');
      final v = _type(f, '456789');
      expect(v.selection.baseOffset, v.text.length);
    });
  });

  group('parseMoneyInput', () {
    test('đọc được cả dấu chấm lẫn dấu phẩy', () {
      expect(parseMoneyInput('456,789'), 456789);
      expect(parseMoneyInput('456.789'), 456789);
      expect(parseMoneyInput('1,234,567'), 1234567);
      expect(parseMoneyInput(' 50 000 '), 50000);
    });

    test('rỗng hoặc rác thì trả 0 để caller chặn được', () {
      expect(parseMoneyInput(''), 0);
      expect(parseMoneyInput('abc'), 0);
    });
  });
}
