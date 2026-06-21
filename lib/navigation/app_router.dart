import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../screens/shared/ai_assistant_screen.dart';

// New screens
import '../screens/parent/subscription_screen.dart';
import '../screens/parent/invite_member_screen.dart';
import '../screens/parent/member_list_screen.dart';
import '../screens/parent/finance_model_screen.dart';
import '../screens/auth/join_family_screen.dart';
import '../screens/auth/family_setup_screen.dart';
import '../screens/shared/edit_profile_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/parent/finance_alerts_screen.dart';
import '../screens/parent/support_request_screen.dart';
import '../screens/shared/family_map_screen.dart';
import '../screens/parent/budget_plan_screen.dart';
import '../screens/parent/financial_goal_screen.dart';

// Shells
import 'manager_shell.dart';
import 'member_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _managerKey = GlobalKey<NavigatorState>(debugLabel: 'manager');
final _memberKey  = GlobalKey<NavigatorState>(debugLabel: 'member');

// Logic redirect thuần (không phụ thuộc BuildContext/GoRouterState) — tách
// riêng để unit test được mà không cần render cây widget thật.
String? computeRedirect({
  required bool restoring,
  required bool loggedIn,
  required bool hasFamily,
  required bool isAdministrative,
  required String loc,
}) {
  // Đang khôi phục session đã lưu (đọc token + gọi /auth/me) — giữ ở
  // splash để tránh nháy về /login rồi lại vào home.
  if (restoring) {
    return loc == '/splash' ? null : '/splash';
  }

  final onAuth  = loc == '/login' || loc == '/register' || loc == '/splash';
  final onSetup = loc == '/family-setup';

  // Chưa đăng nhập → login
  if (!loggedIn && !onAuth) return '/login';
  if (!loggedIn && loc == '/splash') return '/login';

  if (loggedIn) {
    // Đã đăng nhập, đang ở auth/splash screen → home (dựa theo role + family)
    if (onAuth) {
      if (!hasFamily) return '/family-setup';
      return isAdministrative ? '/manager/home' : '/member/home';
    }

    // Đã đăng nhập, chưa có gia đình, không ở setup → bắt về setup
    // (covers deep-link hoặc manual URL vào các route cần family)
    if (!hasFamily && !onSetup) return '/family-setup';
  }
  // Role guard: member không được vào /manager/* routes
  if (loggedIn && hasFamily && loc.startsWith('/manager/')) {
    if (!isAdministrative) return '/member/home';
  }

  // Các trường hợp còn lại — không redirect.
  return null;
}

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => computeRedirect(
      restoring:         auth.restoring,
      loggedIn:          auth.isLoggedIn,
      hasFamily:         auth.hasFamily,
      isAdministrative:  auth.isLoggedIn && auth.user!.isAdministrative,
      loc:               state.matchedLocation,
    ),
    routes: [
      // ── Auth ──────────────────────────────────────────────
      GoRoute(path: '/splash',       builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login',        builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register',     builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/family-setup', builder: (_, _) => const FamilySetupScreen()),

      // ── Shared overlays (full-screen) ──────────────────────
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/ai',            builder: (_, _) => const AIAssistantScreen()),

      // ── Manager/Deputy Shell ──────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, _, shell) => ManagerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _managerKey, routes: [
            GoRoute(path: '/manager/home',  builder: (_, _) => const HomeDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/chat',  builder: (_, _) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/calendar', builder: (_, _) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/sos',   builder: (_, _) => const SOSScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/album', builder: (_, _) => const AlbumScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Member Shell ──────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, _, shell) => MemberShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _memberKey, routes: [
            GoRoute(path: '/member/home',   builder: (_, _) => const ChildHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/tasks',  builder: (_, _) => const ChildTasksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/wallet', builder: (_, _) => const ChildWalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/sos',    builder: (_, _) => const SOSScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/chat',   builder: (_, _) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Manager Specific Routes ───────────────────────────
      GoRoute(path: '/manager/wallet',        builder: (_, _) => const WalletScreen()),
      GoRoute(path: '/manager/tasks',         builder: (_, _) => const TaskManagementScreen()),
      GoRoute(path: '/manager/subscription',  builder: (_, _) => const SubscriptionScreen()),
      GoRoute(path: '/manager/invite',        builder: (_, _) => const InviteMemberScreen()),
      GoRoute(path: '/manager/members',       builder: (_, _) => const MemberListScreen()),
      GoRoute(path: '/manager/finance-model', builder: (_, _) => const FinanceModelScreen()),
      GoRoute(path: '/profile/edit',          builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/manager/finance-alerts', builder: (_, _) => const FinanceAlertsScreen()),
      GoRoute(path: '/finance/support-requests', builder: (_, _) => const SupportRequestScreen()),
      GoRoute(path: '/map', builder: (_, _) => const FamilyMapScreen()),
      GoRoute(path: '/manager/budget-plans', builder: (_, _) => const BudgetPlanScreen()),
      GoRoute(path: '/manager/financial-goals', builder: (_, _) => const FinancialGoalScreen()),
      GoRoute(
        path: '/join',
        builder: (_, state) => JoinFamilyScreen(
          // Link mời tạo bởi invite_member_screen dùng query param "token"
          // (không phải "code") — phải khớp tên ở cả 2 nơi.
          initialCode: state.uri.queryParameters['token'] ?? state.uri.queryParameters['code'],
        ),
      ),
    ],
  );
}
