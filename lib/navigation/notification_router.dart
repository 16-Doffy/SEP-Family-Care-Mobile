import '../models/user.dart';

/// Map `referenceType` + `referenceId` của 1 notification → path go_router để
/// điều hướng khi bấm. Trả `null` = không có màn đích (chỉ dismiss / giữ ở
/// màn danh sách) — theo quy ước hợp đồng WS của BE.
///
/// Route đích khớp `app_router.dart` thật (role-aware). `referenceType` lạ
/// (bản build cũ hơn backend) → `null` để **fallback về list, không crash**.
class NotificationRouter {
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
        return '/album'; // route phẳng, mọi role vào được
      case 'JOIN_REQUEST':
        return isMgr ? '/manager/invite-requests' : null;
      case 'FAMILY': // vừa được duyệt vào / bị xoá khỏi family
        return '/$shell/home';
      case 'FAMILY_MEMBER':
        return (role == UserRole.manager && id.isNotEmpty)
            ? '/manager/member/$id'
            : (isMgr ? '/manager/members' : null);
      case 'TASK_ASSIGNMENT':
        return isMgr ? '/manager/tasks' : '/member/tasks';
      case 'CALENDAR_EVENT':
        return role == UserRole.manager ? '/manager/calendar' : null;
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
