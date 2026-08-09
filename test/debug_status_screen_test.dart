import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/screens/shared/debug_status_screen.dart';

void main() {
  group('debugMaskedToken', () {
    test('che token và chỉ giữ 6 ký tự đầu', () {
      const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      final masked = debugMaskedToken(token);

      expect(masked, startsWith('eyJhbG…'));
      expect(masked, contains('(${token.length} ký tự)'));
      expect(masked, isNot(contains(token)));
    });

    test('hiển thị trạng thái rỗng khi chưa có token', () {
      expect(debugMaskedToken(null), 'Không có');
      expect(debugMaskedToken(''), 'Không có');
    });
  });
}
