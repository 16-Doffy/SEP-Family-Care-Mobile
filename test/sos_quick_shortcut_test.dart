import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/app_router.dart';
import 'package:family_care/screens/shared/sos_screen.dart';

/// Lối tắt SOS ngoài màn hình chính (`res/xml/shortcuts.xml` → deep link
/// `familycare://app/sos-quick`).
///
/// Rủi ro thật cần khoá bằng test: `/sos-quick` là route PHẲNG, cố ý không nằm
/// trong shell nào để cả 3 role dùng chung. Nếu sau này ai đó thêm nó vào
/// `_managerOnlyPaths` / một tập shell, hoặc đổi điều kiện chặn trong
/// `computeRedirect`, thì lối tắt sẽ im lặng đá người dùng về home giữa lúc
/// khẩn cấp — không crash, không log, chỉ đơn giản là không gửi được SOS.
void main() {
  group('/sos-quick đi qua được computeRedirect', () {
    for (final (role, label) in [
      (UserRole.manager, 'Trưởng nhóm'),
      (UserRole.deputy, 'Phó nhóm'),
      (UserRole.member, 'Thành viên'),
    ]) {
      test('$label đã đăng nhập + có gia đình → không bị redirect', () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: role,
            loc: '/sos-quick',
          ),
          isNull,
          reason: 'Lối tắt SOS phải mở được cho mọi role',
        );
      });
    }

    test('chưa đăng nhập → về /login (không mở thẳng màn gửi SOS)', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: false,
          hasFamily: false,
          role: null,
          loc: '/sos-quick',
        ),
        '/login',
      );
    });

    test('đang khôi phục phiên → giữ ở /splash để deep link được phát lại', () {
      // createRouter lưu URI vào pendingDeepLink khi auth.restoring rồi phát
      // lại sau splash — nếu bước này trả về gì khác /splash thì lối tắt lúc
      // app khởi động lạnh sẽ bị nuốt mất.
      expect(
        computeRedirect(
          restoring: true,
          loggedIn: false,
          hasFamily: false,
          role: null,
          loc: '/sos-quick',
        ),
        '/splash',
      );
    });

    test('đã đăng nhập nhưng chưa có gia đình → về /family-setup', () {
      // SOS gọi endpoint theo familyId nên không có gia đình thì không gửi
      // được; đưa về setup đúng hơn là mở màn SOS rồi lỗi lúc bấm.
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: false,
          role: UserRole.member,
          loc: '/sos-quick',
        ),
        '/family-setup',
      );
    });
  });

  group('homePathForRole', () {
    test('khớp bảng ánh xạ của computeRedirect', () {
      expect(homePathForRole(UserRole.manager), '/manager/home');
      expect(homePathForRole(UserRole.deputy), '/deputy/home');
      expect(homePathForRole(UserRole.member), '/member/home');
    });

    test('role null (chưa tải xong user) vẫn ra path hợp lệ, không crash', () {
      // backOrHome dùng hàm này lúc stack rỗng; trả null/chuỗi rỗng sẽ làm
      // context.go ném lỗi ngay trên màn khẩn cấp.
      expect(homePathForRole(null), '/member/home');
    });
  });
}
