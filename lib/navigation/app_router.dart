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
import '../screens/shared/profile_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/ai_assistant_screen.dart';

// Shells
import 'manager_shell.dart';
import 'member_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _managerKey = GlobalKey<NavigatorState>(debugLabel: 'manager');
final _memberKey  = GlobalKey<NavigatorState>(debugLabel: 'member');

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final onAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) {
        // Trưởng/Phó nhóm vào luồng quản lý, Thành viên vào luồng riêng
        return auth.user!.isAdministrative ? '/manager/home' : '/member/home';
      }
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ── Shared overlays (full-screen) ──────────────────────
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/ai',            builder: (_, __) => const AIAssistantScreen()),

      // ── Manager/Deputy Shell ──────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, __, shell) => ManagerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _managerKey, routes: [
            GoRoute(path: '/manager/home',  builder: (_, __) => const HomeDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/chat',  builder: (_, __) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/calendar', builder: (_, __) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/sos',   builder: (_, __) => const SOSScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/finance', builder: (_, __) => const WalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/manager/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Member Shell ──────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, __, shell) => MemberShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _memberKey, routes: [
            GoRoute(path: '/member/home',   builder: (_, __) => const ChildHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/tasks',  builder: (_, __) => const ChildTasksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/wallet', builder: (_, __) => const ChildWalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/sos',    builder: (_, __) => const SOSScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/chat',   builder: (_, __) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Manager Specific Routes ───────────────────────────
      GoRoute(path: '/manager/tasks',   builder: (_, __) => const TaskManagementScreen()),
    ],
  );
}
