import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class FamilyMember {
  final String id; // familyMember.id (membership record)
  final String userId; // user.id
  final String name;
  final String email;
  final String role; // MANAGER | DEPUTY | MEMBER
  final String relation;
  final String status; // ACTIVE | REMOVED | ...
  final int avatarColor;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.relation,
    required this.status,
    required this.avatarColor,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get avatarInitials => name.length >= 2
      ? name.substring(0, 2).toUpperCase()
      : name.toUpperCase();

  bool get isManager => role.toUpperCase().contains('MANAGER');
  bool get isDeputy => role.toUpperCase().contains('DEPUTY');

  String get roleLabel {
    final r = role.toUpperCase();
    if (r.contains('MANAGER')) return 'Trưởng nhóm';
    if (r.contains('DEPUTY')) return 'Phó nhóm';
    return 'Thành viên';
  }

  String get relationLabel => switch (relation.toUpperCase()) {
    'FATHER' => 'Bố',
    'MOTHER' => 'Mẹ',
    'PARENT' => 'Cha / Mẹ',
    'SPOUSE' => 'Vợ / Chồng',
    'CHILD' => 'Con',
    'SISTER' => 'Chị / Em gái',
    'BROTHER' => 'Anh / Em trai',
    'SIBLING' => 'Anh / Chị / Em',
    'GRANDPARENT' => 'Ông / Bà',
    'OTHER' => 'Khác',
    '' => '',
    _ => relation,
  };

  Color get roleColor {
    final r = role.toUpperCase();
    if (r.contains('MANAGER') || r.contains('DEPUTY')) {
      return AppColors.primary500;
    }
    return AppColors.textSecondary;
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final colors = [0xFF3B82F6, 0xFFA78BFA, 0xFFFB923C, 0xFF2DD4BF, 0xFFEC4899];
    // BE trả về member record: { id, userId, familyRole, relationship, user: { id, fullName, email } }
    final userMap = json['user'] is Map
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final userId =
        userMap['id']?.toString() ?? json['userId']?.toString() ?? '';
    final idx = userId.hashCode.abs() % colors.length;
    final name =
        userMap['fullName']?.toString() ??
        userMap['displayName']?.toString() ??
        userMap['name']?.toString() ??
        json['displayName']?.toString() ??
        json['fullName']?.toString() ??
        json['name']?.toString() ??
        '';
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      userId: userId,
      name: name,
      email: userMap['email']?.toString() ?? json['email']?.toString() ?? '',
      role:
          json['familyRole']?.toString() ??
          json['role']?.toString() ??
          'MEMBER',
      relation:
          json['relationship']?.toString() ??
          json['relation']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'ACTIVE',
      avatarColor: json['avatarColor'] is int
          ? json['avatarColor'] as int
          : colors[idx],
    );
  }
}

class FamilyProvider extends ChangeNotifier {
  FamilyProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    _members = [];
    _familyName = '';
    _loading = false;
    _error = null;
    notifyListeners();
  }

  List<FamilyMember> _members = [];
  String _familyName = '';
  bool _loading = false;
  String? _error;

  List<FamilyMember> get members => _members;
  String get familyName => _familyName;
  bool get isLoading => _loading;
  String? get error => _error;

  // UC20 — Lấy danh sách thành viên: GET /families/{familyId}
  Future<void> fetchMembers() async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) return;
    _loading = true;
    _error = null;
    _members = [];
    notifyListeners();
    try {
      final data =
          await ApiClient.instance.get('/families/$familyId')
              as Map<String, dynamic>;
      _familyName = data['name']?.toString() ?? '';
      final list = data['members'] as List? ?? [];
      _members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          // BE soft-delete: thành viên bị xoá vẫn nằm trong members nhưng
          // status = REMOVED → chỉ hiện thành viên đang ACTIVE.
          .where((m) => m.isActive)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // UC19 — Xoá thành viên: DELETE /families/{familyId}/members/{userId}
  // BE soft-delete (status → REMOVED). Endpoint nhận user.id, KHÔNG phải
  // membership-record id.
  Future<void> removeMember(String userId) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    try {
      await ApiClient.instance.delete('/families/$familyId/members/$userId');
    } on ApiException catch (e) {
      // 404 = thành viên đã bị xoá trước đó (soft-delete) — vẫn dọn khỏi list
      // local thay vì ném lỗi gây bối rối cho người dùng.
      if (e.statusCode != 404) rethrow;
    }
    _members.removeWhere((m) => m.userId == userId);
    notifyListeners();
  }

  // PATCH /families/{familyId}/members/{userId}/role — Manager bổ nhiệm/gỡ
  // Phó nhóm. Endpoint nhận user.id và enum DEPUTY_MEMBER | FAMILY_MEMBER.
  Future<void> updateRole(String userId, String newRole) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    await ApiClient.instance.patch('/families/$familyId/members/$userId/role', {
      'familyRole': newRole,
    });
    await fetchMembers();
  }

  /// Quan hệ mà BE giới hạn mỗi gia đình chỉ được có đúng 1 người.
  static const exclusiveRelations = {'FATHER', 'MOTHER'};

  /// Các quan hệ độc nhất đã có người giữ → `{'FATHER': 'Ba An'}`.
  ///
  /// Hàm thuần, tách khỏi provider để unit test được
  /// (`test/member_relationship_test.dart`).
  ///
  /// Chỉ để chặn trước ở UI cho người dùng hiểu lý do; **BE mới là nguồn sự
  /// thật** (409 `FAMILY_ALREADY_HAS_FATHER` / `FAMILY_ALREADY_HAS_MOTHER`),
  /// vì danh sách này chỉ là bản chụp trong bộ nhớ và có thể đã cũ.
  /// [exceptUserId] = người đang được sửa, không tự chặn chính mình.
  static Map<String, String> takenExclusiveRelationsIn(
    List<FamilyMember> members, {
    String? exceptUserId,
  }) {
    final taken = <String, String>{};
    for (final m in members) {
      // Member bị xóa mềm vẫn nằm trong danh sách BE trả về; tính cả họ thì
      // vai trò Bố/Mẹ bị khóa vĩnh viễn dù thực tế không còn ai giữ.
      if (m.status != 'ACTIVE' || m.userId == exceptUserId) continue;
      final relation = m.relation.toUpperCase();
      if (exclusiveRelations.contains(relation)) {
        taken[relation] = m.name.isEmpty ? 'Thành viên khác' : m.name;
      }
    }
    return taken;
  }

  Map<String, String> takenExclusiveRelations({String? exceptUserId}) =>
      takenExclusiveRelationsIn(_members, exceptUserId: exceptUserId);

  // PATCH /families/{familyId}/members/{userId}/relationship — Manager sửa quan
  // hệ gia đình của 1 thành viên (MANAGER only, Deputy nhận 403).
  // Trước khi có endpoint này, chọn nhầm lúc duyệt vào nhà là kẹt vĩnh viễn.
  Future<void> updateRelationship(String userId, String relationship) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    await ApiClient.instance.patch(
      '/families/$familyId/members/$userId/relationship',
      {'relationship': relationship},
    );
    await fetchMembers();
  }

  // POST /families/{familyId}/transfer-ownership — trao quyền Trưởng nhóm cho
  // thành viên khác (FAMILY_MANAGER only). Body { targetUserId, confirm }.
  // Sau khi trao, người gọi không còn là Trưởng nhóm → refetch để cập nhật role.
  Future<void> transferOwnership(String targetUserId) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    await ApiClient.instance.post('/families/$familyId/transfer-ownership', {
      'targetUserId': targetUserId,
      'confirm': true,
    });
    await fetchMembers();
  }

  // PATCH /families/{familyId} — đổi tên gia đình (Manager only).
  Future<void> updateFamilyName(String name) async {
    final familyId = ApiClient.instance.familyId;
    if (familyId == null) throw Exception('Chưa có familyId');
    await ApiClient.instance.patch('/families/$familyId', {
      'name': name.trim(),
    });
    _familyName = name.trim();
    notifyListeners();
  }

  Future<void> grantDeputy(String userId) =>
      updateRole(userId, 'DEPUTY_MEMBER');
  Future<void> revokeDeputy(String userId) =>
      updateRole(userId, 'FAMILY_MEMBER');
}
