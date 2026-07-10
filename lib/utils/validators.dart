/// Bộ validator dùng chung cho form toàn app — trả về message lỗi hoặc null.
class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRe.hasMatch(s)) return 'Email không đúng định dạng';
    return null;
  }

  /// Chuẩn BE: ≥8 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt
  static String? strongPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (s.length < 8) return 'Mật khẩu phải từ 8 ký tự';
    if (!s.contains(RegExp(r'[A-Z]'))) return 'Cần ít nhất 1 chữ hoa';
    if (!s.contains(RegExp(r'[a-z]'))) return 'Cần ít nhất 1 chữ thường';
    if (!s.contains(RegExp(r'[0-9]'))) return 'Cần ít nhất 1 chữ số';
    if (!s.contains(RegExp(r'[^A-Za-z0-9]'))) return 'Cần ít nhất 1 ký tự đặc biệt (@, #, !...)';
    return null;
  }

  static String? notEmpty(String? v, [String field = 'trường này']) {
    if ((v?.trim() ?? '').isEmpty) return 'Vui lòng nhập $field';
    return null;
  }

  static String? minLength(String? v, int len, [String field = 'Trường này']) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng nhập $field';
    if (s.length < len) return '$field phải từ $len ký tự';
    return null;
  }

  /// Cho ô đã format tiền 1.234.567 — bắt buộc > 0
  static String? positiveMoney(String? v) {
    final n = double.tryParse((v ?? '').replaceAll('.', '').trim()) ?? 0;
    if (n <= 0) return 'Vui lòng nhập số tiền hợp lệ';
    return null;
  }
}
