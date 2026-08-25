import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/finance_jar_label.dart';

void main() {
  group('jarDisplayName', () {
    test('dịch theo jarCode — nguồn tin cậy nhất vì BE định nghĩa cố định', () {
      expect(jarDisplayName('NECESSITIES', 'Necessities'), 'Nhu cầu thiết yếu');
      expect(jarDisplayName('SAVINGS', 'Savings'), 'Tiết kiệm');
      expect(jarDisplayName('EDUCATION', 'Education'), 'Giáo dục');
      expect(jarDisplayName('ENJOYMENT', 'Enjoyment'), 'Vui chơi');
      expect(jarDisplayName('GIVING', 'Giving'), 'Cho đi / Biếu tặng');
      expect(jarDisplayName('SPENDING', 'Spending'), 'Chi tiêu');
    });

    test('response thiếu jarCode thì dịch theo tên tiếng Anh của BE', () {
      expect(jarDisplayName('', 'Giving'), 'Cho đi / Biếu tặng');
      expect(jarDisplayName(null, 'savings'), 'Tiết kiệm');
    });

    test('gia đình tự đặt tên hũ thì GIỮ NGUYÊN, không dịch bừa', () {
      expect(jarDisplayName('CUSTOM_1', 'Quỹ cưới em gái'), 'Quỹ cưới em gái');
      expect(jarDisplayName('', 'Tiền học thêm'), 'Tiền học thêm');
    });

    test('thiếu cả tên lẫn mã thì có chữ mặc định, không để trống', () {
      expect(jarDisplayName('', ''), 'Hũ tài chính');
      expect(jarDisplayName(null, null), 'Hũ tài chính');
    });

    test('mã lạ BE thêm sau này mà có tên thì hiện tên, không hiện mã', () {
      expect(jarDisplayName('INVESTMENT', 'Đầu tư'), 'Đầu tư');
    });
  });

  group('localizeJarNamesInText', () {
    test('dịch tên hũ nằm trong câu BE ghép sẵn (đo thật ở Sổ thu chi)', () {
      expect(
        localizeJarNamesInText('Chia quỹ vào hũ Giving'),
        'Chia quỹ vào hũ Cho đi / Biếu tặng',
      );
      expect(
        localizeJarNamesInText('Chia quỹ vào hũ Savings'),
        'Chia quỹ vào hũ Tiết kiệm',
      );
    });

    test('chỉ thay trọn từ, không cắt nhầm chữ nằm trong từ khác', () {
      // "Givingham" không phải tên hũ — không được thành "Cho đi / Biếu tặngham"
      expect(localizeJarNamesInText('Givingham'), 'Givingham');
    });

    test('câu thuần tiếng Việt giữ nguyên', () {
      expect(localizeJarNamesInText('Mua đồ ăn'), 'Mua đồ ăn');
    });

    test('chuỗi rỗng/null không nổ', () {
      expect(localizeJarNamesInText(''), '');
      expect(localizeJarNamesInText(null), '');
    });
  });
}
