import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/notification_router.dart';

// Bối cảnh: BE tự tạo participants khi Manager tạo event và gửi notification
// CALENDAR_EVENT cho họ. Trước đây router trả null cho Deputy/Member nên chính
// người được mời không bấm được vào thông báo để phản hồi → API respond
// (ACCEPTED|DECLINED|MAYBE) không ai dùng được.
void main() {
  String? routeFor(UserRole role) => NotificationRouter.routeFor(
    referenceType: 'CALENDAR_EVENT',
    referenceId: 'evt-1',
    role: role,
  );

  test('thông báo CALENDAR_EVENT có màn đích cho MỌI role', () {
    for (final role in UserRole.values) {
      expect(
        routeFor(role),
        isNotNull,
        reason: 'role $role không có màn đích để phản hồi lời mời',
      );
    }
  });

  test('Manager giữ tab shell, Deputy/Member đi route phẳng /calendar', () {
    expect(routeFor(UserRole.manager), '/manager/calendar');
    expect(routeFor(UserRole.deputy), '/calendar');
    expect(routeFor(UserRole.member), '/calendar');
  });

  test(
    '/manager/calendar là shell branch → phải go(); /calendar thì push()',
    () {
      // push() lên shell branch sẽ dựng 2 shell trùng GlobalKey → crash.
      expect(NotificationRouter.isShellBranch('/manager/calendar'), isTrue);
      expect(NotificationRouter.isShellBranch('/calendar'), isFalse);
    },
  );

  test('chỉ Manager/Deputy được quản lý lịch, Member thì không', () {
    AppUser user(UserRole r) => AppUser(
      id: '1',
      name: 'x',
      email: 'x@x.com',
      familyName: 'Nhà x',
      role: r,
      avatarInitials: 'X',
      avatarColor: 0,
    );

    expect(user(UserRole.manager).canManageCalendar, isTrue);
    expect(user(UserRole.deputy).canManageCalendar, isTrue);
    expect(user(UserRole.member).canManageCalendar, isFalse);
  });
}
