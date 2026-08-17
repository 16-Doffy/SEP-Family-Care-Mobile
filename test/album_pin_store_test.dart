import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/services/album_pin_store.dart';

void main() {
  group('AlbumPinStore.keyFor', () {
    test('tách khóa theo cả user lẫn family', () {
      // Hai tài khoản dùng chung một máy, hoặc một tài khoản ở hai gia đình,
      // đều không được đọc trúng ghim của nhau.
      final a = AlbumPinStore.keyFor('user-1', 'fam-1');
      final b = AlbumPinStore.keyFor('user-2', 'fam-1');
      final c = AlbumPinStore.keyFor('user-1', 'fam-2');
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(a, 'album_pinned_user-1_fam-1');
    });
  });

  group('AlbumPinStore.parse', () {
    test('chưa từng ghim hoặc đã bỏ ghim hết đều ra tập rỗng', () {
      expect(AlbumPinStore.parse(null), isEmpty);
      expect(AlbumPinStore.parse(''), isEmpty);
    });

    test('đọc lại đúng các id đã lưu', () {
      expect(AlbumPinStore.parse('a,b,c'), {'a', 'b', 'c'});
    });

    test('bỏ qua khoảng trắng và phần tử rỗng do dữ liệu cũ để lại', () {
      expect(AlbumPinStore.parse(' a , ,b,'), {'a', 'b'});
    });

    test('id trùng chỉ tính một lần', () {
      expect(AlbumPinStore.parse('a,a,b').length, 2);
    });
  });
}
