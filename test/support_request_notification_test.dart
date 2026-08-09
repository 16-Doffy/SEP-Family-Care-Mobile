import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/notification_router.dart';

// Bối cảnh: BE bật notification cho yêu cầu hỗ trợ chi tiêu ngày 09/08/2026.
// Tạo yêu cầu → báo Manager/Deputy; duyệt hoặc từ chối → báo lại người gửi
// (thường là Member). Vì `referenceType` phía BE là string tự do chứ không
// phải enum, FE phải hardcode đúng chuỗi 'SUPPORT_REQUEST' — sai một ký tự thì
// bấm vào thông báo KHÔNG mở màn nào và cũng không báo lỗi. Test này ghim lại
// chuỗi đó cùng với ràng buộc "mọi role đều phải tới được màn đích".
void main() {
  String? routeFor(UserRole role, {String? referenceId = 'sr-1'}) =>
      NotificationRouter.routeFor(
        referenceType: 'SUPPORT_REQUEST',
        referenceId: referenceId,
        role: role,
      );

  test('SUPPORT_REQUEST có màn đích cho MỌI role', () {
    // Người gửi yêu cầu là Member; nếu gate theo isMgr thì chính người nhận
    // kết quả duyệt lại không bấm được vào thông báo của mình.
    for (final role in UserRole.values) {
      expect(
        routeFor(role),
        '/finance/support-requests',
        reason: 'role $role không tới được màn yêu cầu hỗ trợ',
      );
    }
  });

  test('không phụ thuộc referenceId — thiếu id vẫn mở được danh sách', () {
    expect(routeFor(UserRole.member, referenceId: null), isNotNull);
    expect(routeFor(UserRole.member, referenceId: ''), isNotNull);
  });

  test('là route phẳng, không phải shell branch → push() được', () {
    // Ngược với /manager/wallet hay /member/tasks: những path đó là nhánh của
    // StatefulShellRoute nên push() sẽ dựng 2 shell trùng GlobalKey và crash.
    expect(
      NotificationRouter.isShellBranch('/finance/support-requests'),
      isFalse,
    );
  });

  test('referenceType lạ vẫn fail-open, không crash', () {
    // BE có thể thêm loại mới bất cứ lúc nào vì referenceType là string tự do.
    expect(
      NotificationRouter.routeFor(
        referenceType: 'LOAI_MOI_CHUA_HO_TRO',
        referenceId: 'x',
        role: UserRole.manager,
      ),
      isNull,
    );
  });
}
