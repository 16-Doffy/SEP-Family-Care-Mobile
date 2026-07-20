import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tab_option.dart';
import '../models/user.dart';

/// Nơi cất cấu hình thanh nav. Tách khỏi provider để khi BE có API user
/// preferences (Swagger hiện KHÔNG có endpoint nào) thì chỉ thay lớp này,
/// không đụng UI. Xem VERIFY với Nhật.
abstract class TabConfigStore {
  Future<List<TabOption>?> read(UserRole role);
  Future<void> write(UserRole role, List<TabOption> tabs);
}

/// Lưu cục bộ trên máy. Dùng `flutter_secure_storage` vì repo đã có sẵn
/// (auth_provider dùng), tránh thêm phụ thuộc chỉ để cất 3 chuỗi.
class SecureTabConfigStore implements TabConfigStore {
  static const _storage = FlutterSecureStorage();

  // Tách theo role: một tài khoản có thể đổi vai trò, và cấu hình hợp lý cho
  // Manager chưa chắc hợp lý cho Member.
  String _key(UserRole role) => 'tab_config_${role.name}';

  @override
  Future<List<TabOption>?> read(UserRole role) async {
    final raw = await _storage.read(key: _key(role));
    if (raw == null || raw.isEmpty) return null;
    final tabs = raw
        .split(',')
        .map(TabOptionX.fromId)
        .whereType<TabOption>()
        .toList();
    // Cấu hình cũ có thể chứa option đã bị gỡ khỏi app, hoặc bị cắt cụt →
    // coi như không hợp lệ, quay về mặc định thay vì dựng thanh nav thiếu ô.
    return tabs.length == kCustomTabCount ? tabs : null;
  }

  @override
  Future<void> write(UserRole role, List<TabOption> tabs) =>
      _storage.write(key: _key(role), value: tabs.map((t) => t.id).join(','));
}

class TabConfigProvider extends ChangeNotifier {
  TabConfigProvider({TabConfigStore? store})
    : _store = store ?? SecureTabConfigStore();

  final TabConfigStore _store;
  final Map<UserRole, List<TabOption>> _cache = {};

  /// Đã đọc xong storage chưa. Shell chờ cờ này để không nháy thanh nav mặc
  /// định rồi mới đổi sang cấu hình của người dùng.
  bool loaded = false;

  List<TabOption> tabsFor(UserRole role) =>
      _cache[role] ?? kDefaultTabs[role] ?? kDefaultTabs[UserRole.member]!;

  Future<void> load(UserRole role) async {
    try {
      final saved = await _store.read(role);
      if (saved != null) _cache[role] = saved;
    } catch (e) {
      // Hỏng storage thì dùng mặc định — không đáng làm sập app vì thanh nav.
      debugPrint('TabConfigProvider: đọc cấu hình thất bại: $e');
    }
    loaded = true;
    notifyListeners();
  }

  /// Đặt option cho một vị trí. Nếu option đó đang nằm ở vị trí khác thì
  /// **hoán đổi** hai vị trí, không để trùng — thanh nav có 2 ô giống hệt nhau
  /// vừa vô nghĩa vừa làm 1 branch không bao giờ tới được.
  Future<void> setTabAt(UserRole role, int slot, TabOption option) async {
    final tabs = [...tabsFor(role)];
    if (slot < 0 || slot >= tabs.length) return;
    if (tabs[slot] == option) return;

    final existing = tabs.indexOf(option);
    if (existing != -1) {
      tabs[existing] = tabs[slot];
    }
    tabs[slot] = option;

    _cache[role] = tabs;
    notifyListeners();
    try {
      await _store.write(role, tabs);
    } catch (e) {
      debugPrint('TabConfigProvider: lưu cấu hình thất bại: $e');
    }
  }

  Future<void> resetToDefault(UserRole role) async {
    final tabs = kDefaultTabs[role] ?? kDefaultTabs[UserRole.member]!;
    _cache[role] = [...tabs];
    notifyListeners();
    try {
      await _store.write(role, tabs);
    } catch (e) {
      debugPrint('TabConfigProvider: lưu cấu hình thất bại: $e');
    }
  }

  /// Branch index cho từng vị trí trên thanh nav (6 ô, thứ tự cố định).
  List<int> branchOrderFor(UserRole role) {
    final tabs = tabsFor(role);
    return [
      kHomeBranchIndex,
      tabs[0].branchIndex,
      tabs[1].branchIndex,
      kSosBranchIndex,
      tabs[2].branchIndex,
      kProfileBranchIndex,
    ];
  }
}
