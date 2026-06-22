import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/app_router.dart';

void main() {
  group('computeRedirect', () {
    test('while restoring, stays on /splash regardless of target', () {
      expect(
        computeRedirect(
          restoring: true, loggedIn: false, hasFamily: false,
          role: null, loc: '/manager/home',
        ),
        '/splash',
      );
      expect(
        computeRedirect(
          restoring: true, loggedIn: false, hasFamily: false,
          role: null, loc: '/splash',
        ),
        isNull,
      );
    });

    test('not logged in is redirected to /login', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: false, hasFamily: false,
          role: null, loc: '/manager/home',
        ),
        '/login',
      );
    });

    test('member is blocked from /manager/* and /deputy/* and sent to /member/home', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/manager/tasks',
        ),
        '/member/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/deputy/tasks',
        ),
        '/member/home',
      );
    });

    test('manager can access /manager/* routes including manager-only ones', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.manager, loc: '/manager/home',
        ),
        isNull,
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.manager, loc: '/manager/subscription',
        ),
        isNull,
      );
    });

    test('deputy can access shared /manager/* management routes', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/tasks',
        ),
        isNull,
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/members',
        ),
        isNull,
      );
    });

    test('deputy is blocked from manager-only routes (subscription/invite)', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/subscription',
        ),
        '/deputy/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/invite',
        ),
        '/deputy/home',
      );
    });

    test('logged in without family is redirected to /family-setup', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          role: UserRole.manager, loc: '/manager/home',
        ),
        '/family-setup',
      );
    });

    test('logged in on /login is redirected to home by role', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.manager, loc: '/login',
        ),
        '/manager/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/login',
        ),
        '/deputy/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/login',
        ),
        '/member/home',
      );
    });

    test('member can access non-manager routes without redirect', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/member/tasks',
        ),
        isNull,
      );
    });

    test('member can view shared /manager/members (read-only)', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/manager/members',
        ),
        isNull,
      );
    });

    test('deputy is blocked from Manager-only shell tabs (calendar/album) and Member shell', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/calendar',
        ),
        '/deputy/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/album',
        ),
        '/deputy/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/member/home',
        ),
        '/deputy/home',
      );
    });

    test('deputy can still access shared flat management routes outside any shell', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/finance-model',
        ),
        isNull,
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.deputy, loc: '/manager/wallet',
        ),
        isNull,
      );
    });

    test('manager is blocked from Deputy/Member shell tabs', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.manager, loc: '/deputy/home',
        ),
        '/manager/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.manager, loc: '/member/home',
        ),
        '/manager/home',
      );
    });
  });
}
