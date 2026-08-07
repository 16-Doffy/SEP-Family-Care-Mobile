import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Khoá contract: **mọi provider giữ dữ liệu người dùng khai ở `lib/main.dart`
/// đều phải tự đăng ký dọn khi kết thúc phiên** qua
/// `ApiClient.addSessionResetListener`.
///
/// Vì sao cần test này: các provider ở app scope sống suốt vòng đời ứng dụng,
/// không bị hủy khi đổi tài khoản. Đăng xuất chỉ xóa token, dữ liệu vẫn nằm
/// trong RAM. Quan sát runtime 2026-08-07 trên emulator: đăng xuất Trưởng nhóm,
/// đăng nhập Thành viên, màn Trợ lý AI hiện nguyên hội thoại của Trưởng nhóm
/// kèm số liệu tài chính — dù backend trả danh sách RỖNG cho Thành viên.
///
/// `flutter analyze` không thấy, không test nào khác bắt được, và trên máy của
/// một người dùng duy nhất thì không bao giờ lộ. Thêm provider mới vào
/// `main.dart` mà quên đăng ký là test này đỏ.
void main() {
  /// Không giữ dữ liệu người dùng nên không cần dọn:
  /// - `AuthProvider` tự quản phiên, dọn nó ở đây là đệ quy.
  /// - `ThemeModeController`, `TabConfigProvider`, `WearQuickMessageProvider`
  ///   là tùy chọn giao diện lưu cục bộ theo thiết bị, không phải dữ liệu gia
  ///   đình. Đổi tài khoản vẫn giữ là đúng mong đợi.
  const exempt = {
    'AuthProvider',
    'ThemeModeController',
    'TabConfigProvider',
    'WearQuickMessageProvider',
  };

  final registration = RegExp(r'create: \(_\) => (\w+)\(');

  test('mọi provider dữ liệu trong main.dart đều đăng ký dọn phiên', () {
    final main = File('lib/main.dart').readAsStringSync();
    final declared = registration
        .allMatches(main)
        .map((m) => m.group(1)!)
        .where((name) => !exempt.contains(name))
        .toSet();

    expect(
      declared,
      isNotEmpty,
      reason: 'Không đọc được provider nào từ main.dart — regex đã lỗi thời',
    );

    final missing = <String>[];
    for (final cls in declared) {
      final file = File('lib/providers/${_snake(cls)}.dart');
      if (!file.existsSync()) {
        missing.add('$cls (không tìm thấy ${file.path})');
        continue;
      }
      final src = file.readAsStringSync();
      final registers = src.contains('addSessionResetListener');
      final hasReset = src.contains('void resetForNewSession()');
      if (!registers || !hasReset) {
        missing.add(
          '$cls (đăng ký=$registers, có resetForNewSession=$hasReset)',
        );
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Provider sau chưa dọn dữ liệu khi đổi tài khoản, người đăng nhập '
          'sau sẽ thấy dữ liệu của người trước:\n  ${missing.join('\n  ')}',
    );
  });

  test('clearSession phải gọi listener, không chỉ xóa token', () {
    final src = File('lib/services/api_client.dart').readAsStringSync();
    final body = src.substring(src.indexOf('void clearSession()'));
    expect(
      body.contains('_sessionResetListeners'),
      isTrue,
      reason: 'clearSession không kích listener thì mọi reset đều vô nghĩa',
    );
  });
}

String _snake(String className) => className
    .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m.group(1)}')
    .toLowerCase();
