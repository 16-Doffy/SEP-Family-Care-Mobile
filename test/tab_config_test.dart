import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/tab_option.dart';
import 'package:family_care/models/user.dart';
import 'package:family_care/providers/tab_config_provider.dart';

class _FakeStore implements TabConfigStore {
  final Map<UserRole, List<TabOption>> data = {};
  int writes = 0;

  @override
  Future<List<TabOption>?> read(UserRole role) async => data[role];

  @override
  Future<void> write(UserRole role, List<TabOption> tabs) async {
    writes++;
    data[role] = [...tabs];
  }
}

void main() {
  test('branch index khớp thứ tự branch khai trong router', () {
    // 0 home │ 1..6 kShellBranchOrder │ 7 sos │ 8 profile
    expect(TabOption.chat.branchIndex, 1);
    expect(TabOption.calendar.branchIndex, 2);
    expect(TabOption.map.branchIndex, 3);
    expect(TabOption.tasks.branchIndex, 4);
    expect(TabOption.wallet.branchIndex, 5);
    expect(TabOption.album.branchIndex, 6);
    expect(kSosBranchIndex, 7);
    expect(kProfileBranchIndex, 8);
  });

  test('mặc định giữ nguyên thanh nav cũ của từng role', () {
    final p = TabConfigProvider(store: _FakeStore());
    expect(p.tabsFor(UserRole.manager), [
      TabOption.chat,
      TabOption.calendar,
      TabOption.album,
    ]);
    expect(p.tabsFor(UserRole.member), [
      TabOption.tasks,
      TabOption.wallet,
      TabOption.chat,
    ]);
  });

  test('vị trí cố định luôn đúng chỗ: 0 home, 3 SOS, 5 hồ sơ', () {
    final p = TabConfigProvider(store: _FakeStore());
    final order = p.branchOrderFor(UserRole.manager);
    expect(order.length, 6);
    expect(order[0], kHomeBranchIndex);
    expect(order[3], kSosBranchIndex);
    expect(order[5], kProfileBranchIndex);
  });

  test(
    'chọn mục đang ở vị trí khác thì HOÁN ĐỔI, không tạo tab trùng',
    () async {
      final p = TabConfigProvider(store: _FakeStore());
      // Manager mặc định [chat, calendar, album]; đặt album vào vị trí 0.
      await p.setTabAt(UserRole.manager, 0, TabOption.album);

      final tabs = p.tabsFor(UserRole.manager);
      expect(tabs, [TabOption.album, TabOption.calendar, TabOption.chat]);
      expect(tabs.toSet().length, kCustomTabCount, reason: 'không được trùng');
    },
  );

  test('chọn mục mới (chưa có trên thanh) thì thay thế đúng vị trí', () async {
    final p = TabConfigProvider(store: _FakeStore());
    await p.setTabAt(UserRole.manager, 1, TabOption.map);
    expect(p.tabsFor(UserRole.manager), [
      TabOption.chat,
      TabOption.map,
      TabOption.album,
    ]);
  });

  test('cấu hình được ghi xuống store và đọc lại đúng', () async {
    final store = _FakeStore();
    final p = TabConfigProvider(store: store);
    await p.setTabAt(UserRole.member, 2, TabOption.map);
    expect(store.writes, 1);

    final fresh = TabConfigProvider(store: store);
    await fresh.load(UserRole.member);
    expect(fresh.tabsFor(UserRole.member), [
      TabOption.tasks,
      TabOption.wallet,
      TabOption.map,
    ]);
  });

  test('cấu hình lưu theo role, không rò sang role khác', () async {
    final store = _FakeStore();
    final p = TabConfigProvider(store: store);
    await p.setTabAt(UserRole.manager, 0, TabOption.map);
    expect(p.tabsFor(UserRole.member), kDefaultTabs[UserRole.member]);
  });

  test('id lưu theo tên enum, không theo index', () {
    // Lưu index thì thêm/bớt option sẽ làm lệch cấu hình đã lưu của người dùng.
    expect(TabOption.calendar.id, 'calendar');
    expect(TabOptionX.fromId('calendar'), TabOption.calendar);
    expect(TabOptionX.fromId('khong-ton-tai'), isNull);
  });

  test('reset trả về mặc định của role', () async {
    final p = TabConfigProvider(store: _FakeStore());
    await p.setTabAt(UserRole.manager, 0, TabOption.map);
    await p.resetToDefault(UserRole.manager);
    expect(p.tabsFor(UserRole.manager), kDefaultTabs[UserRole.manager]);
  });
}
