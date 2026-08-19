import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/providers/auth_provider.dart';
import 'package:family_care/providers/calendar_provider.dart';
import 'package:family_care/providers/family_provider.dart';
import 'package:family_care/providers/subscription_provider.dart';
import 'package:family_care/screens/parent/calendar_screen.dart';

/// Chặn mọi lời gọi mạng: màn hình gọi fetchBootstrap trong postFrameCallback.
class _FakeCalendarProvider extends CalendarProvider {
  _FakeCalendarProvider(List<FamilyCalendarEvent> seed) {
    events = seed;
  }

  @override
  Future<void> fetchBootstrap(DateTime month, SubscriptionProvider sub) async {}
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
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => SubscriptionProvider(),
        ),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  _pastDateGuardTests();
  _headerOverflowTests();
  // Lỗ hổng đã vá: BE tự tạo participants khi Manager tạo event và gửi
  // notification CALENDAR cho họ, nhưng trước đây Member không có màn nào để
  // phản hồi. Nay Member xem được và bấm Tham gia/Có thể/Từ chối, nhưng KHÔNG
  // được tạo/sửa/hủy — BE cũng chặn tương ứng.
  testWidgets('Member KHÔNG thấy nút tạo sự kiện', (tester) async {
    await _pump(tester, UserRole.member);
    expect(find.byTooltip('Tạo sự kiện'), findsNothing);
  });

  testWidgets('Manager và Deputy vẫn thấy nút tạo sự kiện', (tester) async {
    for (final role in [UserRole.manager, UserRole.deputy]) {
      await _pump(tester, role);
      expect(
        find.byTooltip('Tạo sự kiện'),
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
    await tester.tap(find.text('Họp gia đình').last);
    await tester.pumpAndSettle();

    // Form sửa là bottom sheet có tiêu đề 'Cập nhật sự kiện'.
    expect(find.text('Cập nhật sự kiện'), findsNothing);
  });
}

/// Header màn Lịch từng TRÀN 71px trên máy thật khi đang xem tháng khác tháng
/// hiện tại — lúc đó thanh công cụ có thêm nút "Về hôm nay" (4 nút thay vì 3).
///
/// Các test cũ không bắt được vì chúng luôn dừng ở THÁNG HIỆN TẠI, nút đó
/// không hiện. Nhóm test này lùi tháng trước rồi mới kiểm, đúng trạng thái đã
/// vỡ ngoài thực tế.
void _headerOverflowTests() {
  group('Header màn Lịch không tràn', () {
    Future<void> expectNoOverflow(WidgetTester tester) async {
      final ex = tester.takeException();
      expect(ex, isNull, reason: 'Header tràn layout: $ex');
    }

    testWidgets('không tràn ở tháng hiện tại', (tester) async {
      await _pump(tester, UserRole.manager);
      await expectNoOverflow(tester);
    });

    testWidgets('không tràn sau khi lùi về tháng trước', (tester) async {
      await _pump(tester, UserRole.manager);
      await tester.tap(find.byTooltip('Tháng trước').first);
      await tester.pumpAndSettle();
      await expectNoOverflow(tester);
    });

    testWidgets('có nút tiến tháng — trước đây chỉ lùi được', (tester) async {
      await _pump(tester, UserRole.manager);
      expect(find.byTooltip('Tháng sau'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Tháng trước'), findsAtLeastNWidgets(1));
    });

    testWidgets('lạc khỏi tháng hiện tại thì luôn có đường quay về', (
      tester,
    ) async {
      await _pump(tester, UserRole.manager);
      // Ở đúng tháng này thì nhãn năm mang tooltip "Tháng hiện tại".
      expect(find.byTooltip('Tháng hiện tại'), findsAtLeastNWidgets(1));

      await tester.tap(find.byTooltip('Tháng trước').first);
      await tester.pumpAndSettle();

      // Lạc đi rồi thì phải có ít nhất một lối về — nhãn năm luôn có, nút
      // tròn chỉ thêm khi đủ chỗ. Đây chính là thứ bug gốc thiếu.
      expect(find.byTooltip('Về hôm nay'), findsAtLeastNWidgets(1));

      await tester.tap(find.byTooltip('Về hôm nay').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tháng hiện tại'), findsAtLeastNWidgets(1));
      await expectNoOverflow(tester);
    });
  });
}

/// Không cho TẠO sự kiện cho ngày đã qua, nhưng vẫn phải SỬA được sự kiện cũ.
///
/// Bug user báo 19/08: bộ chọn ngày để `firstDate: DateTime(2020)` nên lùi
/// tới 2020 được, và hàm lưu chỉ kiểm tên chứ không kiểm ngày. Tệ hơn: đang
/// xem tháng cũ rồi bấm "+" thì ngày mặc định ĐÃ nằm trong quá khứ, bấm Lưu
/// luôn là tạo nhầm mà không hề chọn ngày.
void _pastDateGuardTests() {
  group('Chặn tạo sự kiện ngày đã qua', () {
    testWidgets('mở form từ tháng CŨ thì ngày mặc định không rơi vào quá khứ', (
      tester,
    ) async {
      await _pump(tester, UserRole.manager);
      // Lùi 2 tháng rồi mới mở form tạo.
      await tester.tap(find.byTooltip('Tháng trước').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng trước').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tạo sự kiện').first);
      await tester.pumpAndSettle();

      // Ngày hiện trên nút chọn phải là HÔM NAY, không phải ngày của tháng cũ.
      final now = DateTime.now();
      expect(
        find.text('${now.day}/${now.month}/${now.year}'),
        findsAtLeastNWidgets(1),
        reason: 'Ngày mặc định phải bị kéo về hôm nay khi mở từ tháng cũ',
      );
    });

    testWidgets('mở form ở tháng hiện tại thì giữ nguyên ngày đang chọn', (
      tester,
    ) async {
      await _pump(tester, UserRole.manager);
      await tester.tap(find.byTooltip('Tạo sự kiện').first);
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(
        find.text('${now.day}/${now.month}/${now.year}'),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
