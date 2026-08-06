import 'dart:convert';

import 'package:family_care/providers/wear_quick_message_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('dùng đúng danh sách mặc định cho wearable', () async {
    final provider = WearQuickMessageProvider();

    await provider.load();

    expect(provider.messages, [
      'Đang về nhà',
      'Đã đến nơi',
      'Đang chạy xe',
      'Đang bận',
      'Về trễ một chút',
    ]);
  });

  test('thêm, sửa, xóa và reset tin nhắn nhanh', () async {
    final provider = WearQuickMessageProvider();
    await provider.load();

    await provider.updateAt(2, 'Đang ở trường');
    expect(provider.messages[2], 'Đang ở trường');

    await provider.removeAt(3);
    expect(provider.messages, isNot(contains('Đang bận')));

    await provider.add('Sắp gọi lại');
    expect(provider.messages.last, 'Sắp gọi lại');

    await provider.reset();
    expect(provider.messages, WearQuickMessageProvider.defaultMessages);
  });

  test(
    'sanitize dữ liệu đã lưu: bỏ trống, bỏ trùng và giới hạn 5 câu',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'wear_quick_messages_v1': jsonEncode([
          '  A  ',
          '',
          'A',
          'B',
          'C',
          'D',
          'E',
          'F',
        ]),
      });
      final provider = WearQuickMessageProvider();

      await provider.load();

      expect(provider.messages, ['A', 'B', 'C', 'D', 'E']);
    },
  );
}
