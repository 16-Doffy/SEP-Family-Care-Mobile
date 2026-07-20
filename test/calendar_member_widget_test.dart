import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/providers/auth_provider.dart';
import 'package:family_care/providers/calendar_provider.dart';
import 'package:family_care/providers/family_provider.dart';
import 'package:family_care/screens/parent/calendar_screen.dart';

/// Chặn mọi lời gọi mạng: màn hình gọi fetchBootstrap trong postFrameCallback.
class _FakeCalendarProvider extends CalendarProvider {
  _FakeCalendarProvider(List<FamilyCalendarEvent> seed) {
    events = seed;
  }

  @override
  Future<void> fetchBootstrap(DateTime month) async {}
}

AppUser _user(UserRole role) => AppUser(
  id: 'u1',
  name: 'Người dùng',
  email: 'u@x.com',
  familyName: 'Nhà X',
  familyId: 'f1',
  role: role,
  avatarInitials: 'NX',
  avatarColor: 0,
);

FamilyCalendarEvent _eventToday() {
  final now = DateTime.now();
  return FamilyCalendarEvent(
    id: 'e1',
    title: 'Họp gia đình',
    startTime: DateTime(now.year, now.month, now.day, 9),
  );
}

Future<void> _pump(WidgetTester tester, UserRole role) async {
  // Khung test mặc định 800x600 quá thấp: lưới lịch chiếm gần hết, thẻ sự kiện
  // rơi ra ngoài viewport và ListView lazy nên không dựng → find không thấy.
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final auth = AuthProvider()..debugSetState(user: _user(role));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<CalendarProvider>(
          create: (_) => _FakeCalendarProvider([_eventToday()]),
        ),
        ChangeNotifierProvider<FamilyProvider>(create: (_) => FamilyProvider()),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  // Lỗ hổng đã vá: BE tự tạo participants khi Manager tạo event và gửi
  // notification CALENDAR cho họ, nhưng trước đây Member không có màn nào để
  // phản hồi. Nay Member xem được và bấm Tham gia/Có thể/Từ chối, nhưng KHÔNG
  // được tạo/sửa/hủy — BE cũng chặn tương ứng.
  testWidgets('Member KHÔNG thấy nút tạo sự kiện', (tester) async {
    await _pump(tester, UserRole.member);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Manager và Deputy vẫn thấy nút tạo sự kiện', (tester) async {
    for (final role in [UserRole.manager, UserRole.deputy]) {
      await _pump(tester, role);
      expect(
        find.byType(FloatingActionButton),
        findsOneWidget,
        reason: '$role phải tạo được sự kiện',
      );
    }
  });

  testWidgets('Member phản hồi được nhưng không hủy được sự kiện', (
    tester,
  ) async {
    await _pump(tester, UserRole.member);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Tham gia'), findsOneWidget);
    expect(find.text('Có thể'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
    expect(
      find.text('Hủy sự kiện'),
      findsNothing,
      reason: 'Member không có quyền hủy',
    );
  });

  testWidgets('Manager thấy đủ cả phản hồi lẫn hủy sự kiện', (tester) async {
    await _pump(tester, UserRole.manager);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Tham gia'), findsOneWidget);
    expect(find.text('Hủy sự kiện'), findsOneWidget);
  });

  testWidgets('Member chạm vào sự kiện KHÔNG mở form sửa', (tester) async {
    await _pump(tester, UserRole.member);
    await tester.tap(find.text('Họp gia đình'));
    await tester.pumpAndSettle();

    // Form sửa là bottom sheet có tiêu đề 'Cập nhật sự kiện'.
    expect(find.text('Cập nhật sự kiện'), findsNothing);
  });
}
