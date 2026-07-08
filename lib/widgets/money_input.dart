import 'package:flutter/services.dart';

/// Tự thêm dấu chấm ngăn cách hàng nghìn khi nhập tiền: 1234567 → 1.234.567
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = formatThousands(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatThousands(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

/// Đọc số từ ô nhập tiền có dấu chấm ngăn cách ("1.234.567" → 1234567)
double parseMoneyInput(String text) =>
    double.tryParse(text.replaceAll('.', '').trim()) ?? 0;
