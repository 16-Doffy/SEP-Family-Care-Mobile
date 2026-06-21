import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/user.dart';
import 'package:family_care/providers/auth_provider.dart';

AppUser _user({required UserRole role, String? familyId}) => AppUser(
      id: 'u1',
      name: 'Test User',
      email: 'test@example.com',
      familyName: 'Test Family',
      familyId: familyId,
      role: role,
      avatarInitials: 'TU',
      avatarColor: 0xFF000000,
    );

void main() {
  group('AppUser role logic', () {
    test('manager is administrative', () {
      final u = _user(role: UserRole.manager);
      expect(u.isAdministrative, isTrue);
      expect(u.canManageTasks, isTrue);
    });

    test('deputy is administrative', () {
      final u = _user(role: UserRole.deputy);
      expect(u.isAdministrative, isTrue);
    });

    test('member is not administrative', () {
      final u = _user(role: UserRole.member);
      expect(u.isAdministrative, isFalse);
      expect(u.canManageTasks, isFalse);
      expect(u.canApproveWithdrawals, isFalse);
    });
  });

  group('AppUser.fromJson role resolution', () {
    test('familyRole MANAGER wins over account-level role', () {
      final u = AppUser.fromJson(
        {'id': '1', 'fullName': 'A', 'email': 'a@a.com', 'role': 'MEMBER'},
        familyRole: 'MANAGER',
      );
      expect(u.role, UserRole.manager);
    });

    test('falls back to member when no role info present', () {
      final u = AppUser.fromJson({'id': '1', 'fullName': 'A', 'email': 'a@a.com'});
      expect(u.role, UserRole.member);
    });
  });

  group('AuthProvider state', () {
    test('isLoggedIn/hasFamily reflect current user', () {
      final auth = AuthProvider();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.hasFamily, isFalse);

      auth.debugSetState(user: _user(role: UserRole.member, familyId: 'f1'));
      expect(auth.isLoggedIn, isTrue);
      expect(auth.hasFamily, isTrue);

      auth.debugSetState(user: _user(role: UserRole.member));
      expect(auth.hasFamily, isFalse);
    });
  });
}
