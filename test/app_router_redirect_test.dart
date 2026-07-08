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

    test('not logged in CAN access /join (public invite lookup) without redirect', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: false, hasFamily: false,
          role: null, loc: '/join',
        ),
        isNull,
      );
    });

    test('logged in just after login with pending invite token → back to /join, not home', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/login',
          pendingInviteToken: 'abc-123',
        ),
        '/join?token=abc-123',
      );
    });

    test('logged in on /login WITHOUT pending token → home by role như cũ', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/login',
        ),
        '/member/home',
      );
    });

    test('logged in already on /join with pending token → không redirect lặp', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/join',
          pendingInviteToken: 'abc-123',
        ),
        isNull,
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

    test('just registered, pending email verification → /verify-email, not /family-setup', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          role: UserRole.manager, loc: '/register',
          pendingEmailVerification: true,
        ),
        '/verify-email',
      );
    });

    test('already on /verify-email while pending → không redirect lặp', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          role: UserRole.manager, loc: '/verify-email',
          pendingEmailVerification: true,
        ),
        isNull,
      );
    });

    test('deep-link to /family-setup while pending verification → KHÔNG bị ép về /verify-email nữa (verify không bắt buộc)', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          role: UserRole.manager, loc: '/family-setup',
          pendingEmailVerification: true,
        ),
        isNull,
      );
    });

    test('pending verification but ALREADY has family (joined via claim) → không bị giam ở /verify-email', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: true,
          role: UserRole.member, loc: '/member/home',
          pendingEmailVerification: true,
        ),
        isNull,
      );
    });

    test('chủ động ở /verify-email dù chưa có family và pending=false → không bị đẩy đi (màn tự context.go sau khi verify xong, router không ép)', () {
      expect(
        computeRedirect(
          restoring: false, loggedIn: true, hasFamily: false,
          role: UserRole.manager, loc: '/verify-email',
        ),
        isNull,
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
