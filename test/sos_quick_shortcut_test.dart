import 'package:flutter/widgets.dart';
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

  group('sosQuickFreshPath — lỗi 2: bấm lối tắt lần hai không phản hồi', () {
    // Đo 11/08 trên OPPO: bấm lối tắt → hủy → bấm lại = KHÔNG có gì xảy ra.
    // go_router thấy vị trí trùng nên không dựng lại widget, initState không
    // chạy, đếm ngược không bắt đầu. Token đổi mỗi lần là để chặn đúng chỗ đó.
    test('mỗi lần gọi ra một vị trí KHÁC nhau', () {
      final paths = {for (var i = 0; i < 50; i++) sosQuickFreshPath()};
      expect(
        paths.length,
        50,
        reason: 'trùng đường dẫn là go_router sẽ không dựng lại màn hình',
      );
    });

    test('vẫn nằm dưới /sos-quick/ để khớp route đã khai', () {
      expect(sosQuickFreshPath(), startsWith('/sos-quick/'));
    });

    for (final (role, label) in [
      (UserRole.manager, 'Trưởng nhóm'),
      (UserRole.deputy, 'Phó nhóm'),
      (UserRole.member, 'Thành viên'),
    ]) {
      test('$label vào được đường dẫn có token, không bị chặn', () {
        // Thêm một đoạn path mới rất dễ vô tình lọt vào các tập chặn của
        // computeRedirect; khoá lại để đổi chỗ đó là test đỏ ngay.
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: role,
            loc: sosQuickFreshPath(),
          ),
          isNull,
        );
      });
    }
  });

  group('shouldSendSosOnPause — lỗi 1: tắt màn hình là mất cảnh báo', () {
    // Đo 11/08: tắt màn hình lúc đếm ngược còn ~2 giây thì người thân KHÔNG
    // nhận được gì; cùng thao tác với màn hình sáng thì nhận ngay.
    test('đang đếm ngược tự động mà app xuống nền → gửi ngay', () {
      expect(
        shouldSendSosOnPause(
          state: AppLifecycleState.paused,
          autoCountdown: true,
          countdown: 2,
        ),
        isTrue,
      );
    });

    test('không đếm ngược thì xuống nền cũng không gửi', () {
      // Người dùng chỉ mở màn SOS xem rồi thoát ra — không được tự gửi.
      expect(
        shouldSendSosOnPause(
          state: AppLifecycleState.paused,
          autoCountdown: false,
          countdown: null,
        ),
        isFalse,
      );
    });

    test('giữ nút bằng tay (không phải tự động) thì xuống nền không gửi', () {
      // Nhấc tay ra là hủy — hành vi cũ, không được đổi.
      expect(
        shouldSendSosOnPause(
          state: AppLifecycleState.paused,
          autoCountdown: false,
          countdown: 2,
        ),
        isFalse,
      );
    });

    test('đếm ngược đã kết thúc thì không gửi thêm lần nữa', () {
      expect(
        shouldSendSosOnPause(
          state: AppLifecycleState.paused,
          autoCountdown: true,
          countdown: null,
        ),
        isFalse,
      );
    });

    test('các trạng thái vòng đời khác KHÔNG kích hoạt gửi', () {
      // inactive xảy ra thoáng qua khi kéo thanh thông báo, khi có cuộc gọi
      // đến, khi chuyển app — gửi ở đây là tạo báo động giả hàng loạt.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ]) {
        expect(
          shouldSendSosOnPause(
            state: s,
            autoCountdown: true,
            countdown: 2,
          ),
          isFalse,
          reason: '$s không được coi là "bỏ máy vào túi"',
        );
      }
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
