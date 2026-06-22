import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/user.dart';

AppUser _user(UserRole role) => AppUser(
      id: 'u1',
      name: 'Test User',
      email: 'test@example.com',
      familyName: 'Test Family',
      familyId: 'f1',
      role: role,
      avatarInitials: 'TU',
      avatarColor: 0xFF000000,
    );

void main() {
  final manager = _user(UserRole.manager);
  final deputy = _user(UserRole.deputy);
  final member = _user(UserRole.member);

  group('Ma trận quyền — Manager/Deputy/Member', () {
    test('canManageTasks: manager + deputy, không member', () {
      expect(manager.canManageTasks, isTrue);
      expect(deputy.canManageTasks, isTrue);
      expect(member.canManageTasks, isFalse);
    });

    test('canManageFinance: manager + deputy, không member', () {
      expect(manager.canManageFinance, isTrue);
      expect(deputy.canManageFinance, isTrue);
      expect(member.canManageFinance, isFalse);
    });

    test('canApproveSupportRequests: manager + deputy, không member', () {
      expect(manager.canApproveSupportRequests, isTrue);
      expect(deputy.canApproveSupportRequests, isTrue);
      expect(member.canApproveSupportRequests, isFalse);
    });

    test('canManageCalendar: manager + deputy, không member', () {
      expect(manager.canManageCalendar, isTrue);
      expect(deputy.canManageCalendar, isTrue);
      expect(member.canManageCalendar, isFalse);
    });

    test('canResolveSos: manager + deputy, không member', () {
      expect(manager.canResolveSos, isTrue);
      expect(deputy.canResolveSos, isTrue);
      expect(member.canResolveSos, isFalse);
    });

    test('canManageMemberRoles: chỉ manager — Deputy KHÔNG được cấp/thu quyền Phó nhóm', () {
      expect(manager.canManageMemberRoles, isTrue);
      expect(deputy.canManageMemberRoles, isFalse);
      expect(member.canManageMemberRoles, isFalse);
    });

    test('canRemoveMembers: chỉ manager — Deputy KHÔNG được xoá thành viên', () {
      expect(manager.canRemoveMembers, isTrue);
      expect(deputy.canRemoveMembers, isFalse);
      expect(member.canRemoveMembers, isFalse);
    });

    test('canManageSubscription: chỉ manager — Deputy KHÔNG được quản lý gói đăng ký', () {
      expect(manager.canManageSubscription, isTrue);
      expect(deputy.canManageSubscription, isFalse);
      expect(member.canManageSubscription, isFalse);
    });

    test('canInviteMembers: chỉ manager — đã verify BE thật trả 403 cho Deputy', () {
      expect(manager.canInviteMembers, isTrue);
      expect(deputy.canInviteMembers, isFalse);
      expect(member.canInviteMembers, isFalse);
    });
  });
}
