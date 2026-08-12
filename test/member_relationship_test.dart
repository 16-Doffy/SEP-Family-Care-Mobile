import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/user.dart';
import 'package:family_care/providers/family_provider.dart';
import 'package:family_care/screens/parent/member_detail_screen.dart';
import 'package:family_care/services/api_client.dart';

// Bối cảnh: BE ship PATCH /families/{familyId}/members/{userId}/relationship
// ngày 09/08/2026. Trước đó chọn nhầm quan hệ lúc duyệt join request là kẹt
// vĩnh viễn, chỉ SYSTEM_ADMIN sửa được trong DB.
//
// Hai ràng buộc dễ vỡ nhất được ghim ở đây:
//   1. Endpoint là MANAGER-only (BE trả 403 cho Deputy) → phải gate bằng
//      canManageMemberRoles, KHÔNG được quay lại isAdministrative.
//   2. Mỗi gia đình chỉ 1 FATHER và 1 MOTHER; BE trả 409 kèm code ổn định.
void main() {
  AppUser user(UserRole role) => AppUser(
    id: 'u1',
    name: 'x',
    email: 'x@x.com',
    familyName: 'Nhà x',
    role: role,
    avatarInitials: 'X',
    avatarColor: 0,
  );

  FamilyMember member({
    required String userId,
    required String relation,
    String status = 'ACTIVE',
    String name = 'Người nhà',
  }) => FamilyMember.fromJson({
    'id': 'm-$userId',
    'userId': userId,
    'relationship': relation,
    'status': status,
    'user': {'id': userId, 'fullName': name},
  });

  group('phân quyền', () {
    test('chỉ Manager sửa được quan hệ — Deputy KHÔNG', () {
      // BE trả 403 cho Deputy. Dự án đã từng có lỗ hổng vì gate nhầm bằng
      // isAdministrative (Manager || Deputy) nên test này chốt lại.
      expect(user(UserRole.manager).canManageMemberRoles, isTrue);
      expect(user(UserRole.deputy).canManageMemberRoles, isFalse);
      expect(user(UserRole.member).canManageMemberRoles, isFalse);
    });

    test('isAdministrative KHÔNG được dùng làm cổng cho việc này', () {
      // Nếu ai đó đổi gate sang isAdministrative, Deputy sẽ thấy nút rồi ăn
      // 403 — test này nêu rõ hai thứ đó khác nhau.
      expect(user(UserRole.deputy).isAdministrative, isTrue);
      expect(user(UserRole.deputy).canManageMemberRoles, isFalse);
    });
  });

  group('chặn trước 1 FATHER / 1 MOTHER', () {
    Map<String, String> taken(
      List<FamilyMember> members, {
      String? exceptUserId,
    }) => FamilyProvider.takenExclusiveRelationsIn(
      members,
      exceptUserId: exceptUserId,
    );

    test('bắt đúng FATHER và MOTHER đang có người giữ', () {
      final result = taken([
        member(userId: 'u1', relation: 'FATHER', name: 'Ba An'),
        member(userId: 'u2', relation: 'MOTHER', name: 'Má Bình'),
        member(userId: 'u3', relation: 'CHILD', name: 'Bé Cúc'),
      ]);
      expect(result, {'FATHER': 'Ba An', 'MOTHER': 'Má Bình'});
      expect(result.containsKey('CHILD'), isFalse);
    });

    test('cho phép nhiều GRANDPARENT và các quan hệ còn lại', () {
      expect(
        taken([
          member(userId: 'u1', relation: 'GRANDPARENT', name: 'Ông'),
          member(userId: 'u2', relation: 'GRANDPARENT', name: 'Bà'),
          member(userId: 'u3', relation: 'CHILD', name: 'Con cả'),
          member(userId: 'u4', relation: 'CHILD', name: 'Con út'),
        ]),
        isEmpty,
      );
    });

    test('bỏ qua thành viên không ACTIVE', () {
      // Member bị xóa mềm vẫn nằm trong danh sách BE trả về; nếu tính cả họ
      // thì vai trò Bố sẽ bị khóa vĩnh viễn dù không còn ai giữ.
      expect(
        taken([
          member(
            userId: 'u1',
            relation: 'FATHER',
            status: 'REMOVED',
            name: 'Ba cũ',
          ),
          member(
            userId: 'u2',
            relation: 'MOTHER',
            status: 'INACTIVE',
            name: 'Má cũ',
          ),
        ]),
        isEmpty,
      );
    });

    test('không tự chặn chính người đang được sửa', () {
      // Đang sửa Ba An mà lại báo "Ba An đang giữ vai trò này" thì vô lý.
      final members = [member(userId: 'u1', relation: 'FATHER', name: 'Ba An')];
      expect(taken(members, exceptUserId: 'u1'), isEmpty);
      expect(taken(members, exceptUserId: 'u9'), {'FATHER': 'Ba An'});
    });
  });

  group('thông báo lỗi', () {
    test('bắt theo code của BE, không theo message', () {
      // Message là tiếng Việt do BE viết và sẽ đổi; code thì ổn định.
      expect(
        relationshipErrorMessage(
          ApiException(409, 'thông điệp bất kỳ', code: 'FAMILY_ALREADY_HAS_FATHER'),
        ),
        contains('vai trò Bố'),
      );
      expect(
        relationshipErrorMessage(
          ApiException(409, 'thông điệp bất kỳ', code: 'FAMILY_ALREADY_HAS_MOTHER'),
        ),
        contains('vai trò Mẹ'),
      );
    });

    test('lỗi khác vẫn hiện message của BE', () {
      expect(
        relationshipErrorMessage(ApiException(403, 'Bạn không có quyền')),
        'Bạn không có quyền',
      );
      expect(
        relationshipErrorMessage(Exception('Mất kết nối')),
        'Mất kết nối',
      );
    });
  });

  group('danh sách lựa chọn', () {
    test('khớp đúng 8 giá trị của UpdateMemberRelationshipDto', () {
      expect(kRelationshipOptions.keys.toSet(), {
        'FATHER',
        'MOTHER',
        'SPOUSE',
        'CHILD',
        'SISTER',
        'BROTHER',
        'GRANDPARENT',
        'OTHER',
      });
    });

    test('không chứa giá trị cũ PARENT/SIBLING', () {
      // relationLabel vẫn dịch được 2 giá trị này để hiển thị dữ liệu cũ,
      // nhưng gửi lên BE sẽ ăn 400 "relationship không hợp lệ".
      expect(kRelationshipOptions.containsKey('PARENT'), isFalse);
      expect(kRelationshipOptions.containsKey('SIBLING'), isFalse);
      expect(
        FamilyMember.fromJson({'relationship': 'PARENT'}).relationLabel,
        'Cha / Mẹ',
      );
    });

    test('hai quan hệ độc nhất khớp ràng buộc BE', () {
      expect(FamilyProvider.exclusiveRelations, {'FATHER', 'MOTHER'});
    });
  });
}
