import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Khoá contract: **mọi provider mà màn hình trong `lib/wear/` đọc đều phải được
/// khai ở CẢ HAI entrypoint** — `lib/wear/main_wear.dart` (app đồng hồ) và
/// `lib/main.dart` (app điện thoại, vì `main.dart` tự chuyển sang cây widget
/// đồng hồ khi phát hiện màn hình cỡ watch).
///
/// Vì sao cần test này: `WearQuickMessageProvider` từng chỉ được khai trong
/// `main.dart`. Chạy `flutter run` thì không sao, nhưng chạy đúng entrypoint
/// đồng hồ (`--target lib/wear/main_wear.dart`) là nổ `ProviderNotFoundException`
/// ngay trong `build()` của màn "Nhắn nhanh". `flutter analyze` không thấy
/// (lỗi runtime) và không test nào bắt được (repo chưa có widget test cho wear).
///
/// Test đọc thẳng source thay vì dựng widget — dựng cây wear trong test cần
/// mock sensor/secure storage/socket, đắt hơn nhiều mà vẫn không phủ hết màn.
void main() {
  final providerUsage = RegExp(r'(?:read|watch)<(\w+Provider)>');
  final providerRegistration = RegExp(r'create: \(_\) => (\w+Provider)\(');

  Set<String> providersUsedByWearScreens() {
    final used = <String>{};
    final dir = Directory('lib/wear');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in providerUsage.allMatches(entity.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    return used;
  }

  Set<String> providersRegisteredIn(String path) => providerRegistration
      .allMatches(File(path).readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();

  test('lib/wear đọc được ít nhất một provider (test không tự vô hiệu)', () {
    expect(providersUsedByWearScreens(), isNotEmpty);
  });

  for (final entrypoint in const ['lib/wear/main_wear.dart', 'lib/main.dart']) {
    test('$entrypoint khai đủ provider mà màn wear đọc', () {
      final missing =
          providersUsedByWearScreens()
              .difference(providersRegisteredIn(entrypoint))
              .toList()
            ..sort();

      expect(
        missing,
        isEmpty,
        reason:
            'Màn trong lib/wear/ đọc $missing nhưng $entrypoint không khai. '
            'Chạy entrypoint này sẽ nổ ProviderNotFoundException lúc runtime. '
            'Thêm ChangeNotifierProvider tương ứng vào $entrypoint.',
      );
    });
  }
}
