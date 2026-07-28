import 'package:flutter/services.dart';

/// Tự thêm dấu ngăn cách hàng nghìn khi nhập tiền: 1234567 → 1.234.567
///
/// [separator] mặc định là dấu chấm để giữ nguyên hành vi các màn đã dùng
/// formatter này từ trước. Màn nào hiển thị số bằng dấu phẩy (ví dụ sổ chi tiêu
/// cá nhân) thì truyền `separator: ','` cho khớp phần hiển thị của chính nó.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter({this.separator = '.'});

  final String separator;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = formatThousands(digits, separator: separator);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatThousands(String digits, {String separator = '.'}) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(separator);
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

/// Đọc số từ ô nhập tiền có dấu ngăn cách ("1.234.567" hoặc "1,234,567" →
/// 1234567). Bỏ cả hai loại dấu để không phụ thuộc màn đó dùng dấu nào.
double parseMoneyInput(String text) =>
    double.tryParse(text.replaceAll(RegExp(r'[.,\s]'), '').trim()) ?? 0;
