import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/navigation/app_router.dart';

void main() {
  group('computeRedirect', () {
    test('while restoring, stays on /splash regardless of target', () {
      expect(
        computeRedirect(
          restoring: true, loggedIn: false, hasFamily: false,
          isAdministrative: false, loc: '/manager/home',
        ),
        '/splash',
      );
      expect(
        computeRedirect(
          restoring: true, loggedIn: false, hasFamily: false,
          isAdministrative: false, loc: '/splash',
        ),
        isNull,
      );
    });

    test('not logged in is redirected to /login', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: false, hasFamily: false,
          isAdministrative: false, loc: '/manager/home',
        ),
        '/login',
      );
    });

    test('member is blocked from /manager/* and sent to /member/home', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          isAdministrative: false, loc: '/manager/tasks',
        ),
        '/member/home',
      );
    });

    test('manager can access /manager/* routes', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          isAdministrative: true, loc: '/manager/home',
        ),
        isNull,
      );
    });

    test('logged in without family is redirected to /family-setup', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          isAdministrative: true, loc: '/manager/home',
        ),
        '/family-setup',
      );
    });

    test('logged in on /login is redirected to home by role', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          isAdministrative: true, loc: '/login',
        ),
        '/manager/home',
      );
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          isAdministrative: false, loc: '/login',
        ),
        '/member/home',
      );
    });

    test('member can access non-manager routes without redirect', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          isAdministrative: false, loc: '/member/tasks',
        ),
        isNull,
      );
    });
  });
}
