import '../models/user.dart';

/// Map `referenceType` + `referenceId` của 1 notification → path go_router để
/// điều hướng khi bấm. Trả `null` = không có màn đích (chỉ dismiss / giữ ở
/// màn danh sách) — theo quy ước hợp đồng WS của BE.
///
/// Route đích khớp `app_router.dart` thật (role-aware). `referenceType` lạ
/// (bản build cũ hơn backend) → `null` để **fallback về list, không crash**.
class NotificationRouter {
  /// Các path là **nhánh của StatefulShellRoute** (xem `app_router.dart`).
  /// ⚠️ Bắt buộc điều hướng bằng `context.go()` — `context.push()` sẽ dựng
  /// THÊM một shell chồng lên shell đang có, làm 2 shell dùng chung
  /// `navigatorKey` GlobalKey của nhánh → crash Navigator
  /// `'!keyReservation.contains(key)'`.
  /// Sinh từ danh sách branch thay vì liệt kê tay — mỗi role có đủ 9 branch
  /// (xem `_roleBranches` trong app_router.dart), liệt kê 27 dòng bằng tay thì
  /// sớm muộn cũng lệch.
  static final _shellBranchPaths = {
    for (final seg in ['manager', 'deputy', 'member'])
      for (final p in [
        'home',
        'chat',
        'calendar',
        'map',
        'tasks',
        'wallet',
        'album',
        'sos',
        'profile',
      ])
        '/$seg/$p',
  };

  /// true → dùng `context.go(path)`; false → `context.push(path)` (giữ back).
  static bool isShellBranch(String path) =>
      _shellBranchPaths.contains(path.split('?').first);

  static String? routeFor({
    required String? referenceType,
    required String? referenceId,
    required UserRole role,
  }) {
    if (referenceType == null || referenceType.isEmpty) return null;

    final shell = switch (role) {
      UserRole.manager => 'manager',
      UserRole.deputy => 'deputy',
      _ => 'member',
    };
    final isMgr = role == UserRole.manager || role == UserRole.deputy;
    final id = referenceId ?? '';

    switch (referenceType) {
      case 'SOS_ALERT':
        return '/$shell/sos';
      case 'ALBUM_MEDIA':
        return '/$shell/album';
      case 'JOIN_REQUEST':
        return isMgr ? '/manager/invite-requests' : null;
      case 'FAMILY': // vừa được duyệt vào / bị xoá khỏi family
        return '/$shell/home';
      case 'FAMILY_MEMBER':
        return (role == UserRole.manager && id.isNotEmpty)
            ? '/manager/member/$id'
            : (isMgr ? '/manager/members' : null);
      case 'TASK_ASSIGNMENT':
        return '/$shell/tasks';
      case 'CALENDAR_EVENT':
        // Mọi role đều có branch calendar riêng. Trước đây trả null cho
        // non-manager → chính người được mời tham gia lại không bấm được vào
        // thông báo để phản hồi (ACCEPTED|DECLINED|MAYBE).
        return '/$shell/calendar';
      case 'BUDGET_ALERT':
        return isMgr ? '/manager/finance-alerts' : null;
      case 'FINANCIAL_GOAL':
        return isMgr
            ? (id.isNotEmpty
                  ? '/manager/goal-detail?goalId=$id'
                  : '/manager/financial-goals')
            : null;
      case 'CONVERSATION':
        return '/$shell/chat';
      default:
        return null; // GENERAL / referenceType chưa hỗ trợ → giữ ở list
    }
  }
}
