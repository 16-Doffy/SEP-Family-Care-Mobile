import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';

// Auth
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';

// Manager/Deputy (Dùng chung bộ UI quản lý)
import '../screens/parent/home_dashboard_screen.dart';
import '../screens/parent/wallet_screen.dart';
import '../screens/parent/task_management_screen.dart';
import '../screens/parent/calendar_screen.dart';

// Member
import '../screens/child/child_home_screen.dart';
import '../screens/child/child_tasks_screen.dart';
import '../screens/child/child_wallet_screen.dart';

// Shared
import '../screens/shared/chat_screen.dart';
import '../screens/shared/sos_screen.dart';
import '../screens/shared/album_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/tab_settings_screen.dart';
import '../screens/shared/wearables_screen.dart';
import '../screens/shared/ai_assistant_screen.dart';
import '../screens/shared/change_password_screen.dart';

// New screens
import '../screens/parent/subscription_screen.dart';
import '../screens/parent/invite_member_screen.dart';
import '../screens/parent/member_list_screen.dart';
import '../screens/parent/finance_model_screen.dart';
import '../screens/auth/join_family_screen.dart';
import '../screens/auth/family_setup_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/shared/edit_profile_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/shared/payment_result_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/parent/finance_alerts_screen.dart';
import '../screens/parent/support_request_screen.dart';
import '../screens/parent/invitation_requests_screen.dart';
import '../screens/shared/family_map_screen.dart';
import '../screens/parent/budget_plan_screen.dart';
import '../screens/parent/budget_plan_detail_screen.dart';
import '../screens/parent/financial_goal_screen.dart';
import '../screens/parent/finance_reports_screen.dart';
import '../screens/parent/goal_contribution_screen.dart';
import '../screens/parent/goal_detail_screen.dart';
import '../screens/parent/reward_management_screen.dart';
import '../screens/parent/member_finance_screen.dart';
import '../screens/parent/member_detail_screen.dart';

// Shell
import 'family_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _managerKey = GlobalKey<NavigatorState>(debugLabel: 'manager');
final _deputyKey = GlobalKey<NavigatorState>(debugLabel: 'deputy');
final _memberKey = GlobalKey<NavigatorState>(debugLabel: 'member');

// Mỗi role khai đủ 9 branch theo thứ tự CỐ ĐỊNH:
//   0 home │ 1 chat │ 2 calendar │ 3 map │ 4 tasks │ 5 wallet │ 6 album
//   │ 7 sos │ 8 profile
// (khớp kShellBranchOrder + kSosBranchIndex/kProfileBranchIndex trong
// models/tab_option.dart — đổi bên nào phải đổi bên kia).
//
// Phải khai đủ cả 9 dù thanh nav chỉ hiện 6, vì StatefulShellRoute.indexedStack
// cố định branch lúc dựng router, không đổi được lúc chạy. Thanh nav chỉ ánh xạ
// vị trí hiển thị → branch index theo cấu hình người dùng (TabConfigProvider).
//
// chat/calendar/map/album/sos/profile dùng chung màn cho mọi role; home/tasks/
// wallet khác nhau nên nhận qua tham số — Member mở ChildWalletScreen (khai báo
// tài chính cá nhân), Manager/Deputy mở WalletScreen (ví & sổ quỹ CHUNG).
List<StatefulShellBranch> _roleBranches({
  required String seg,
  required GlobalKey<NavigatorState> homeKey,
  required Widget home,
  required Widget tasks,
  required Widget wallet,
}) {
  StatefulShellBranch branch(
    String path,
    Widget child, {
    GlobalKey<NavigatorState>? key,
  }) => StatefulShellBranch(
    navigatorKey: key,
    routes: [GoRoute(path: '/$seg/$path', builder: (_, _) => child)],
  );

  return [
    branch('home', home, key: homeKey),
    branch('chat', const ChatScreen()),
    branch('calendar', const CalendarScreen()),
    branch('map', const FamilyMapScreen()),
    branch('tasks', tasks),
    branch('wallet', wallet),
    branch('album', const AlbumScreen()),
    branch('sos', const SOSScreen()),
    branch('profile', const ProfileScreen()),
  ];
}

// Route Manager-only — Deputy KHÔNG được vào dù dùng chung namespace
// /manager/* với các màn hình quản lý khác. Đã verify bằng tài khoản Deputy
// thật trên BE thật (2026-06-22): cả 2 endpoint phía sau đều trả 403 cho
// Deputy. Xem AppUser.canManageSubscription / canInviteMembers.
const _managerOnlyPaths = {
  '/manager/subscription',
  '/manager/invite',
  '/manager/invite-requests',
};

// Route dùng chung dù namespace /manager/* — Member chỉ xem (read-only),
// không có nút quản lý nào hiện ra vì member_list_screen đã tự gate theo
// canManageMemberRoles/canRemoveMembers/canInviteMembers (đều false với
// Member). Không đưa Member vào /manager/* nói chung, chỉ mở lối riêng
// cho đúng path này.
const _memberSharedPaths = {'/manager/members', '/manager/member/:memberId'};

// Path thuộc shell bottom-nav riêng của từng role — chỉ chính role đó được
// vào (Deputy/Member không nên đi sâu vào shell của Manager dù route vẫn nằm
// dưới /manager/*; Manager không có lý do gì vào /deputy/* hay /member/*).
// Các route quản lý dùng chung KHÔNG nằm trong các set này (ví dụ
// /manager/members, /manager/finance-model...) nên vẫn mở cho Deputy.
//
// Sinh từ _roleBranches để không bao giờ lệch: mỗi role có đủ 9 branch, thêm
// branch mới là tự động được chặn đúng, không phải nhớ sửa 3 chỗ.
Set<String> _shellPathsOf(String seg) => {
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

final _managerShellPaths = _shellPathsOf('manager');
final _deputyShellPaths = _shellPathsOf('deputy');
final _memberShellPaths = _shellPathsOf('member');

// Logic redirect thuần (không phụ thuộc BuildContext/GoRouterState) — tách
// riêng để unit test được mà không cần render cây widget thật.
String? computeRedirect({
  required bool restoring,
  required bool loggedIn,
  required bool hasFamily,
  required UserRole? role, // null khi chưa đăng nhập
  required String loc,
  // Token lời mời /join đang chờ (lưu khi user mở link lúc chưa đăng nhập) —
  // null nếu không có gì đang chờ.
  String? pendingInviteToken,
  // true ngay sau register() hoặc khi POST /families trả 403 "chưa verify".
  // /join không yêu cầu verify; create family, regenerate code and approve
  // join request are the actions guarded by BE verification.
  bool pendingEmailVerification = false,
}) {
  // Đang khôi phục session đã lưu (đọc token + gọi /auth/me) — giữ ở
  // splash để tránh nháy về /login rồi lại vào home.
  if (restoring) {
    return loc == '/splash' ? null : '/splash';
  }

  final onAuth =
      loc == '/login' ||
      loc == '/register' ||
      loc == '/splash' ||
      loc == '/forgot-password';
  final onSetup = loc == '/family-setup';
  final onVerify = loc == '/verify-email';
  // JoinFamilyScreen tự xử lý lookup public và gửi join request sau login.
  final onJoin = loc == '/join';

  // Chưa đăng nhập → login (trừ /join, màn hình mời tham gia là public)
  if (!loggedIn && !onAuth && !onJoin) return '/login';
  if (!loggedIn && loc == '/splash') return '/login';
  if (!loggedIn) return null;

  // Vừa đăng nhập/đăng ký xong và có mã mời đang chờ → quay lại /join trước khi
  // route theo role bình thường, để không mất token.
  if (onAuth && pendingInviteToken != null && pendingInviteToken.isNotEmpty) {
    return '/join?token=$pendingInviteToken';
  }

  final homePath = switch (role) {
    UserRole.manager => '/manager/home',
    UserRole.deputy => '/deputy/home',
    _ => '/member/home',
  };

  // Đã đăng nhập, đang ở auth/splash screen → home (dựa theo role + family)
  if (onAuth) {
    if (pendingEmailVerification) return '/verify-email';
    if (!hasFamily) return '/family-setup';
    return homePath;
  }

  // Chưa verify email và chưa có gia đình → bắt về /verify-email trước khi
  // được vào /family-setup (POST /families sẽ 403 nếu chưa verify). Một khi
  // đã có gia đình (vd. được Manager duyệt join request — không yêu cầu
  // verify) thì không chặn nữa, để không giam người dùng hợp lệ.
  if (pendingEmailVerification && !hasFamily && !onJoin) {
    return onVerify ? null : '/verify-email';
  }

  // Đã đăng nhập, chưa có gia đình: cho ở setup hoặc join. /join là flow hợp
  // lệ để xin vào gia đình bằng mã mời; các route cần family vẫn bị kéo về setup.
  if (!hasFamily) return (onSetup || onJoin) ? null : '/family-setup';

  // Member: chỉ vào được /member/* — chặn /manager/* và /deputy/*, trừ vài
  // route dùng chung đã liệt ở _memberSharedPaths (xem màn hình quản lý ở
  // chế độ chỉ xem, không có hành động quản trị nào hiện ra).
  if (role == UserRole.member &&
      !_memberSharedPaths.contains(loc) &&
      !loc.startsWith('/manager/member/') &&
      (loc.startsWith('/manager/') || loc.startsWith('/deputy/'))) {
    return homePath;
  }

  // Deputy: dùng chung UI quản lý ở /manager/* (Nhiệm vụ/Ví/Members/...)
  // trừ các route Manager-only và shell riêng của Manager/Member.
  if (role == UserRole.deputy &&
      (_managerOnlyPaths.contains(loc) ||
          _managerShellPaths.contains(loc) ||
          _memberShellPaths.contains(loc))) {
    return homePath;
  }

  // Manager: không có route quản lý nào nằm dưới /deputy/* hay /member/* —
  // chặn deep-link vào shell của 2 role khác.
  if (role == UserRole.manager &&
      (_deputyShellPaths.contains(loc) || _memberShellPaths.contains(loc))) {
    return homePath;
  }

  // Các trường hợp còn lại — không redirect.
  return null;
}

GoRouter createRouter(AuthProvider auth) {
  // Deep link mở lúc app cold-start bị nuốt mất: redirect đá về /splash chờ
  // khôi phục session rồi đi thẳng home. Lưu lại URI gốc để khôi phục xong
  // quay về đúng đích (payment-success/failed, join...).
  String? pendingDeepLink;
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (auth.restoring && loc != '/splash') {
        pendingDeepLink = state.uri.toString();
      }
      if (!auth.restoring && loc == '/splash' && pendingDeepLink != null) {
        final target = pendingDeepLink!;
        pendingDeepLink = null;
        return target;
      }
      // Lưu lại token mời ngay khi vào /join — phòng trường hợp router cần
      // bắt đăng nhập trước (xem computeRedirect: pendingInviteToken).
      if (loc == '/join') {
        final token =
            state.uri.queryParameters['token'] ??
            state.uri.queryParameters['code'];
        if (token != null && token.isNotEmpty) {
          auth.savePendingInviteToken(token);
        }
      }
      final result = computeRedirect(
        restoring: auth.restoring,
        loggedIn: auth.isLoggedIn,
        hasFamily: auth.hasFamily,
        role: auth.isLoggedIn ? auth.user!.role : null,
        loc: loc,
        pendingInviteToken: auth.pendingInviteToken,
        pendingEmailVerification: auth.pendingEmailVerification,
      );
      // Token đã được dùng để quay lại /join — xoá để không lặp lại lần sau.
      if (result != null &&
          result.startsWith('/join') &&
          auth.pendingInviteToken != null) {
        auth.clearPendingInviteToken();
      }
      // Ở lại /join (result == null): token đã nằm trong query param của màn
      // hình rồi — xoá bản pending trong storage, nếu không nó dính vĩnh viễn
      // và MỌI lần đăng nhập sau đều bị đẩy về trang mời này.
      if (loc == '/join' && result == null && auth.pendingInviteToken != null) {
        auth.clearPendingInviteToken();
      }
      return result;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            VerifyEmailScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/family-setup',
        builder: (_, _) => const FamilySetupScreen(),
      ),

      // ── Shared overlays (full-screen) ──────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/ai', builder: (_, _) => const AIAssistantScreen()),
      GoRoute(
        path: '/settings/tabs',
        builder: (_, _) => const TabSettingsScreen(),
      ),
      GoRoute(path: '/wearables', builder: (_, _) => const WearablesScreen()),

      // ── Manager Shell (Trang chủ/Nhắn tin/Lịch/SOS/Album/Tôi) ──
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, _, shell) => FamilyShell(navigationShell: shell),
        branches: _roleBranches(
          seg: 'manager',
          homeKey: _managerKey,
          home: const HomeDashboardScreen(),
          tasks: const TaskManagementScreen(),
          wallet: const WalletScreen(),
        ),
      ),

      // ── Deputy Shell (Trang chủ/Nhiệm vụ/Ví/SOS/Chat/Tôi — mở màn
      // hình quản lý, không phải màn hình member thông thường) ──
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, _, shell) => FamilyShell(navigationShell: shell),
        branches: _roleBranches(
          seg: 'deputy',
          homeKey: _deputyKey,
          home: const HomeDashboardScreen(),
          tasks: const TaskManagementScreen(),
          wallet: const WalletScreen(),
        ),
      ),

      // ── Member Shell (Trang chủ/Nhiệm vụ/Ví/SOS/Chat/Tôi) ──────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, _, shell) => FamilyShell(navigationShell: shell),
        branches: _roleBranches(
          seg: 'member',
          homeKey: _memberKey,
          home: const ChildHomeScreen(),
          tasks: const ChildTasksScreen(),
          wallet: const ChildWalletScreen(),
        ),
      ),

      // ── Manager Specific Routes ───────────────────────────
      // /manager/wallet và /manager/tasks đã chuyển thành branch của shell (xem
      // _roleBranches) để dùng làm tab được → KHÔNG khai lại ở đây, go_router
      // không cho trùng path. Nơi gọi phải dùng context.go(), không dùng
      // push() — push lên shell branch sẽ dựng shell thứ hai trùng GlobalKey.
      GoRoute(
        path: '/manager/reward-management',
        builder: (_, _) => const RewardManagementScreen(),
      ),
      GoRoute(
        path: '/manager/subscription',
        builder: (_, _) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/manager/invite',
        builder: (_, _) => const InviteMemberScreen(),
      ),
      GoRoute(
        path: '/manager/invite-requests',
        builder: (_, _) => const InvitationRequestsScreen(),
      ),
      GoRoute(
        path: '/manager/members',
        builder: (_, _) => const MemberListScreen(),
      ),
      GoRoute(
        path: '/manager/member/:memberId',
        builder: (_, state) => MemberDetailScreen(
          memberId: state.pathParameters['memberId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/manager/finance-model',
        builder: (_, _) => const FinanceModelScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/manager/finance-alerts',
        builder: (_, _) => const FinanceAlertsScreen(),
      ),
      GoRoute(
        path: '/finance/support-requests',
        builder: (_, _) => const SupportRequestScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (_, state) {
          final latStr = state.uri.queryParameters['lat'];
          final lngStr = state.uri.queryParameters['lng'];
          final lat = latStr != null ? double.tryParse(latStr) : null;
          final lng = lngStr != null ? double.tryParse(lngStr) : null;
          return FamilyMapScreen(initialLat: lat, initialLng: lng);
        },
      ),
      // Album dùng chung mọi role — BE cho mọi thành viên xem/upload (verify
      // live 2026-07-13: member GET media 200), chỉ moderation là Manager/
      // Deputy (album_screen tự gate nút kiểm duyệt theo isAdministrative). Manager
      // vào qua tab shell /manager/album; Deputy/Member vào route phẳng này.
      GoRoute(path: '/album', builder: (_, _) => const AlbumScreen()),
      // Lịch — mọi role vào được. BE tự tạo participants khi Manager tạo event
      // và gửi notification CALENDAR, nên Member/Deputy PHẢI có màn để phản hồi
      // (POST .../respond: ACCEPTED|DECLINED|MAYBE). Trước đây Lịch chỉ là tab
      // của Manager → người được mời không có chỗ nào trả lời, tính năng respond
      // chết. Manager vẫn vào qua tab shell /manager/calendar; Deputy/Member đi
      // route phẳng này. calendar_screen tự gate nút tạo/sửa/hủy theo
      // AppUser.canManageCalendar.
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
      GoRoute(
        path: '/manager/budget-plans',
        builder: (_, _) => const BudgetPlanScreen(),
      ),
      GoRoute(
        path: '/manager/budget-plans/detail',
        builder: (_, state) => BudgetPlanDetailScreen(
          planId: state.uri.queryParameters['planId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/manager/financial-goals',
        builder: (_, _) => const FinancialGoalScreen(),
      ),
      GoRoute(
        path: '/manager/finance-reports',
        builder: (_, _) => const FinanceReportsScreen(),
      ),
      GoRoute(
        path: '/manager/goal-contribution',
        builder: (_, state) => GoalContributionScreen(
          goalId: state.uri.queryParameters['goalId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/manager/goal-detail',
        builder: (_, state) =>
            GoalDetailScreen(goalId: state.uri.queryParameters['goalId'] ?? ''),
      ),
      GoRoute(
        // Manager/Deputy xem tài chính tháng của member (memberId rỗng = của mình)
        path: '/manager/member-finance',
        builder: (_, state) => MemberFinanceScreen(
          memberId: state.uri.queryParameters['memberId'] ?? '',
          memberName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/join',
        builder: (_, state) => JoinFamilyScreen(
          // Link mời tạo bởi invite_member_screen dùng query param "token"
          // (không phải "code") — phải khớp tên ở cả 2 nơi.
          initialCode:
              state.uri.queryParameters['token'] ??
              state.uri.queryParameters['code'],
        ),
      ),
      // Deep link Stripe trả về sau checkout — BE đặt 2 URL này vào env:
      //   familycare://app/payment-success | familycare://app/payment-failed
      GoRoute(
        path: '/payment-success',
        builder: (_, _) => const PaymentResultScreen(success: true),
      ),
      GoRoute(
        path: '/payment-failed',
        builder: (_, _) => const PaymentResultScreen(success: false),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
    ],
  );
}
