import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/user.dart';
import 'package:family_care/navigation/app_router.dart';

void main() {
  _financeAlertsAccessTests();
  _memberGoalAccessTests();
  group('computeRedirect', () {
    test('while restoring, stays on /splash regardless of target', () {
      expect(
        computeRedirect(
          restoring: true,
          loggedIn: false,
          hasFamily: false,
          role: null,
          loc: '/manager/home',
        ),
        '/splash',
      );
      expect(
        computeRedirect(
          restoring: true,
          loggedIn: false,
          hasFamily: false,
          role: null,
          loc: '/splash',
        ),
        isNull,
      );
    });

    test('not logged in is redirected to /login', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: false,
          hasFamily: false,
          role: null,
          loc: '/manager/home',
        ),
        '/login',
      );
    });

    test(
      'not logged in CAN access /join (public invite lookup) without redirect',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: false,
            hasFamily: false,
            role: null,
            loc: '/join',
          ),
          isNull,
        );
      },
    );

    test(
      'logged in just after login with pending invite token → back to /join, not home',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.member,
            loc: '/login',
            pendingInviteToken: 'abc-123',
          ),
          '/join?token=abc-123',
        );
      },
    );

    test('logged in on /login WITHOUT pending token → home by role như cũ', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.member,
          loc: '/login',
        ),
        '/member/home',
      );
    });

    test(
      'logged in already on /join with pending token → không redirect lặp',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.member,
            loc: '/join',
            pendingInviteToken: 'abc-123',
          ),
          isNull,
        );
      },
    );

    test(
      'member is blocked from /manager/* and /deputy/* and sent to /member/home',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.member,
            loc: '/manager/tasks',
          ),
          '/member/home',
        );
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.member,
            loc: '/deputy/tasks',
          ),
          '/member/home',
        );
      },
    );

    test(
      'manager can access /manager/* routes including manager-only ones',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.manager,
            loc: '/manager/home',
          ),
          isNull,
        );
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.manager,
            loc: '/manager/subscription',
          ),
          isNull,
        );
      },
    );

    // /manager/tasks và /manager/wallet TRƯỚC ĐÂY là route phẳng dùng chung nên
    // Deputy vào được. Từ khi thanh tab tùy chỉnh ra đời, mỗi role khai đủ 9
    // branch nên chúng thành shell path riêng của Manager — Deputy dùng
    // /deputy/tasks, /deputy/wallet (cùng màn hình, không mất chức năng nào).
    test('deputy bị chặn khỏi shell của Manager, đi shell của mình', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.deputy,
          loc: '/manager/tasks',
        ),
        '/deputy/home',
      );
      for (final loc in ['/deputy/tasks', '/deputy/wallet', '/deputy/map']) {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: loc,
          ),
          isNull,
          reason: '$loc là shell của chính Deputy',
        );
      }
    });

    test('deputy can access shared /manager/* management routes', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.deputy,
          loc: '/manager/members',
        ),
        isNull,
      );
    });

    test(
      'deputy is blocked from manager-only routes (subscription/invite)',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/subscription',
          ),
          '/deputy/home',
        );
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/invite',
          ),
          '/deputy/home',
        );
      },
    );

    test(
      'just registered, pending email verification → /verify-email, not /family-setup',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: false,
            role: UserRole.manager,
            loc: '/register',
            pendingEmailVerification: true,
          ),
          '/verify-email',
        );
      },
    );

    test('already on /verify-email while pending → không redirect lặp', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: false,
          role: UserRole.manager,
          loc: '/verify-email',
          pendingEmailVerification: true,
        ),
        isNull,
      );
    });

    test(
      'unverified user may still open /join because BE allows join requests',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: false,
            role: UserRole.member,
            loc: '/join',
            pendingEmailVerification: true,
          ),
          isNull,
        );
      },
    );

    test('verified user without family may open /join from family setup', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: false,
          role: UserRole.member,
          loc: '/join',
        ),
        isNull,
      );
    });

    test(
      'deep-link to /family-setup while pending verification → bắt về /verify-email',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: false,
            role: UserRole.manager,
            loc: '/family-setup',
            pendingEmailVerification: true,
          ),
          '/verify-email',
        );
      },
    );

    test(
      'pending verification but ALREADY has family (joined via claim) → không bị giam ở /verify-email',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.member,
            loc: '/member/home',
            pendingEmailVerification: true,
          ),
          isNull,
        );
      },
    );

    test(
      'verification done (pending=false) → về /family-setup như luồng cũ',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: false,
            role: UserRole.manager,
            loc: '/verify-email',
          ),
          '/family-setup',
        );
      },
    );

    test('logged in without family is redirected to /family-setup', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: false,
          role: UserRole.manager,
          loc: '/manager/home',
        ),
        '/family-setup',
      );
    });

    test('logged in on /login is redirected to home by role', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.manager,
          loc: '/login',
        ),
        '/manager/home',
      );
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.deputy,
          loc: '/login',
        ),
        '/deputy/home',
      );
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.member,
          loc: '/login',
        ),
        '/member/home',
      );
    });

    test('member can access non-manager routes without redirect', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.member,
          loc: '/member/tasks',
        ),
        isNull,
      );
    });

    test('member can view shared /manager/members (read-only)', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.member,
          loc: '/manager/members',
        ),
        isNull,
      );
    });

    test(
      'deputy is blocked from Manager-only shell tabs (calendar/album) and Member shell',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/calendar',
          ),
          '/deputy/home',
        );
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/album',
          ),
          '/deputy/home',
        );
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/member/home',
          ),
          '/deputy/home',
        );
      },
    );

    test(
      'deputy can still access shared flat management routes outside any shell',
      () {
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/finance-model',
          ),
          isNull,
        );
        // /manager/wallet KHÔNG còn ở đây — đã thành shell branch của Manager,
        // xem test 'deputy bị chặn khỏi shell của Manager' phía trên.
        expect(
          computeRedirect(
            restoring: false,
            loggedIn: true,
            hasFamily: true,
            role: UserRole.deputy,
            loc: '/manager/member-finance',
          ),
          isNull,
        );
      },
    );

    test('manager is blocked from Deputy/Member shell tabs', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.manager,
          loc: '/deputy/home',
        ),
        '/manager/home',
      );
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.manager,
          loc: '/member/home',
        ),
        '/manager/home',
      );
    });
  });
}

/// Member cần xem mục tiêu chung và nộp phần góp của chính mình. Hai route
/// dùng namespace /manager vì tái sử dụng UI, nhưng không được bị router đá về
/// Trang chủ; các nút quản trị được UI/BE gate riêng.
void _memberGoalAccessTests() {
  group('Member access to contribution goals', () {
    String? redirect(String loc) => computeRedirect(
      restoring: false,
      loggedIn: true,
      hasFamily: true,
      role: UserRole.member,
      loc: loc,
    );

    test('can open the read-only goal list', () {
      expect(redirect('/manager/financial-goals'), isNull);
    });

    test('can submit their monthly contribution', () {
      expect(redirect('/manager/goal-contribution'), isNull);
    });

    test('still cannot open the administrative goal detail', () {
      expect(redirect('/manager/goal-detail'), '/member/home');
    });
  });
}

/// Member nhận notification `BUDGET_ALERT` nên phải vào được màn cảnh báo tài
/// chính. Trước 19/08 route này nằm ngoài `_memberSharedPaths` nên Member bị
/// đá về home, và NotificationRouter trả null → bấm thông báo không đi đâu cả.
void _financeAlertsAccessTests() {
  group('/manager/finance-alerts — mọi role đều đọc được', () {
    String? redirect(UserRole role) => computeRedirect(
      restoring: false,
      loggedIn: true,
      hasFamily: true,
      role: role,
      loc: '/manager/finance-alerts',
    );

    test('Member không bị đá về home', () {
      expect(redirect(UserRole.member), isNull);
    });

    test('Deputy vào được', () {
      expect(redirect(UserRole.deputy), isNull);
    });

    test('Manager vào được', () {
      expect(redirect(UserRole.manager), isNull);
    });

    test('route manager-only vẫn chặn Member như cũ', () {
      expect(
        computeRedirect(
          restoring: false,
          loggedIn: true,
          hasFamily: true,
          role: UserRole.member,
          loc: '/manager/subscription',
        ),
        isNotNull,
      );
    });
  });
}
