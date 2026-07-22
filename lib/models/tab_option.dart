import 'package:flutter/material.dart';

import 'user.dart';

/// Các mục người dùng được chọn cho 3 vị trí tùy chỉnh của thanh điều hướng.
///
/// Thanh nav có 6 vị trí, **thứ tự cố định và không đổi được**:
///
/// | 0 | 1 | 2 | 3 | 4 | 5 |
/// |---|---|---|---|---|---|
/// | Trang chủ | tùy chọn | tùy chọn | SOS | tùy chọn | Tôi |
///
/// Vị trí 0/3/5 cứng (Trang chủ, SOS, Tôi). Vị trí 1, 2, 4 do người dùng chọn.
enum TabOption { chat, calendar, map, tasks, wallet, album }

extension TabOptionX on TabOption {
  /// Khóa lưu xuống storage — dùng tên enum, KHÔNG dùng index, để sau này
  /// thêm/bớt option không làm hỏng cấu hình người dùng đã lưu.
  String get id => name;

  static TabOption? fromId(String? id) {
    for (final o in TabOption.values) {
      if (o.id == id) return o;
    }
    return null;
  }

  IconData get icon => switch (this) {
    TabOption.chat => Icons.chat_bubble_rounded,
    TabOption.calendar => Icons.calendar_month_rounded,
    TabOption.map => Icons.map_rounded,
    TabOption.tasks => Icons.task_alt_rounded,
    TabOption.wallet => Icons.savings_rounded,
    TabOption.album => Icons.photo_library_rounded,
  };

  /// Nhãn phụ thuộc role: cùng một ô "Thu chi" nhưng Manager/Deputy mở ví &
  /// sổ quỹ CHUNG của gia đình, còn Member mở bản khai tài chính cá nhân
  /// (monthly-finances/me) — member không được xem ví chung, by design đã chốt
  /// 2026-07-11. Xem thêm ghi chú ở `app_router.dart`.
  String labelFor(UserRole role) => switch (this) {
    TabOption.chat => 'Nhắn tin',
    TabOption.calendar => 'Lịch',
    TabOption.map => 'Bản đồ',
    TabOption.tasks => 'Nhiệm vụ',
    TabOption.wallet => role == UserRole.member ? 'Sổ chi tiêu' : 'Sổ thu chi',
    TabOption.album => 'Ảnh',
  };

  String descriptionFor(UserRole role) => switch (this) {
    TabOption.chat => 'Trò chuyện nhóm và riêng với gia đình',
    TabOption.calendar => 'Sự kiện gia đình, lời mời tham gia',
    TabOption.map => 'Vị trí các thành viên trên bản đồ',
    TabOption.tasks =>
      role == UserRole.member
          ? 'Nhiệm vụ được giao cho bạn'
          : 'Giao và duyệt nhiệm vụ',
    TabOption.wallet =>
      role == UserRole.member
          ? 'Khai báo thu chi cá nhân hằng tháng'
          : 'Ví và sổ quỹ chung của gia đình',
    TabOption.album => 'Ảnh và video của gia đình',
  };

  /// Vị trí branch trong `StatefulShellRoute` — xem [kShellBranchOrder].
  int get branchIndex => kShellBranchOrder.indexOf(this) + 1;
}

/// Thứ tự branch trong shell của MỌI role, cố định:
///
///     0 home │ 1..6 theo danh sách này │ 7 sos │ 8 profile
///
/// `StatefulShellRoute.indexedStack` khai báo branch lúc dựng router và KHÔNG
/// đổi được lúc chạy, nên mỗi role phải khai đủ cả 9 branch. Thanh nav chỉ
/// ánh xạ vị trí hiển thị → branch index theo cấu hình người dùng.
const kShellBranchOrder = [
  TabOption.chat,
  TabOption.calendar,
  TabOption.map,
  TabOption.tasks,
  TabOption.wallet,
  TabOption.album,
];

const kHomeBranchIndex = 0;
const kSosBranchIndex = 7;
const kProfileBranchIndex = 8;

/// Số mục tùy chỉnh — khớp 3 vị trí trống trên thanh nav (1, 2, 4).
const kCustomTabCount = 3;

/// Mặc định giữ nguyên thanh nav cũ của từng role, để người dùng đang quen
/// không bị đổi giao diện sau khi cập nhật app.
const kDefaultTabs = <UserRole, List<TabOption>>{
  UserRole.manager: [TabOption.chat, TabOption.calendar, TabOption.album],
  UserRole.deputy: [TabOption.tasks, TabOption.wallet, TabOption.chat],
  UserRole.member: [TabOption.tasks, TabOption.wallet, TabOption.chat],
};

/// Option mỗi role được phép chọn. Hiện cả 3 role dùng được cả 6 mục — màn
/// hình phía sau đã tự gate quyền bên trong (vd calendar_screen ẩn nút tạo với
/// Member, album_screen ẩn nút kiểm duyệt với Member). Giữ hàm này làm chỗ
/// móc sẵn để siết theo role khi có yêu cầu, thay vì rải điều kiện khắp UI.
List<TabOption> allowedTabsFor(UserRole role) => TabOption.values;
