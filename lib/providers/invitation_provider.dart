import 'package:flutter/material.dart';
import '../services/api_client.dart';

// ════════════════════════════════════════════════════════════════════════
// Invitation flow (BE đổi 2026-06: KHÔNG còn "accept" trực tiếp):
//   1. Manager tạo lời mời   → POST /families/{id}/invitations
//   2. Member xin tham gia    → POST /invitations/{token}/claim  (cần đăng nhập)
//      → status: PENDING → CLAIMED (chờ Manager duyệt)
//   3. Manager duyệt          → POST /families/{id}/invitations/{id}/approve
//      → tạo member thật, status → APPROVED/ACCEPTED
//      hoặc từ chối            → POST /families/{id}/invitations/{id}/reject
// ════════════════════════════════════════════════════════════════════════

class Invitation {
  final String id;
  final String email;
  final String familyRole;   // FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER
  final String relationship;
  final String status;       // PENDING|CLAIMED|APPROVED|REJECTED|ACCEPTED|EXPIRED|CANCELED
  final String? claimedById;
  final String? claimerName; // nếu BE trả nested claimedBy.user
  final String? claimerEmail;
  final String? createdAt;
  final String? expiresAt;

  const Invitation({
    required this.id,
    required this.email,
    required this.familyRole,
    required this.relationship,
    required this.status,
    this.claimedById,
    this.claimerName,
    this.claimerEmail,
    this.createdAt,
    this.expiresAt,
  });

  // CLAIMED = có người đã xin vào và đang chờ Manager duyệt
  bool get isAwaitingApproval => status.toUpperCase() == 'CLAIMED';
  bool get isPending          => status.toUpperCase() == 'PENDING';
  bool get isDone => const {'APPROVED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELED'}
      .contains(status.toUpperCase());

  factory Invitation.fromJson(Map<String, dynamic> j) {
    // Tên người claim — thử nhiều shape: claimedBy.user / claimedBy / claimer
    Map<String, dynamic>? claimer;
    for (final k in ['claimedBy', 'claimer', 'claimedByUser']) {
      if (j[k] is Map) { claimer = Map<String, dynamic>.from(j[k] as Map); break; }
    }
    final claimerUser = claimer?['user'] is Map
        ? Map<String, dynamic>.from(claimer!['user'] as Map)
        : claimer;
    return Invitation(
      id:           j['id']?.toString() ?? '',
      email:        j['email']?.toString() ?? '',
      familyRole:   j['familyRole']?.toString() ?? 'FAMILY_MEMBER',
      relationship: j['relationship']?.toString() ?? 'OTHER',
      status:       j['status']?.toString() ?? 'PENDING',
      claimedById:  j['claimedById']?.toString(),
      claimerName:  claimerUser?['fullName']?.toString() ?? claimerUser?['displayName']?.toString(),
      claimerEmail: claimerUser?['email']?.toString(),
      createdAt:    j['createdAt']?.toString(),
      expiresAt:    j['expiresAt']?.toString(),
    );
  }

  String get roleLabel => switch (familyRole) {
        'DEPUTY_MEMBER'  => 'Phó nhóm',
        'FAMILY_MANAGER' => 'Trưởng nhóm',
        _                => 'Thành viên',
      };

  String get relationLabel => switch (relationship) {
        'FATHER' => 'Bố', 'MOTHER' => 'Mẹ', 'SPOUSE' => 'Vợ/Chồng',
        'CHILD' => 'Con', 'SISTER' => 'Chị/Em gái', 'BROTHER' => 'Anh/Em trai',
        'GRANDPARENT' => 'Ông/Bà', _ => 'Khác',
      };

  (Color, String) get statusChip => switch (status.toUpperCase()) {
        'CLAIMED'  => (const Color(0xFFD97706), '⏳ Chờ duyệt'),
        'APPROVED' => (const Color(0xFF16A34A), '✅ Đã duyệt'),
        'ACCEPTED' => (const Color(0xFF16A34A), '✅ Đã vào nhóm'),
        'REJECTED' => (const Color(0xFFDC2626), '❌ Từ chối'),
        'EXPIRED'  => (const Color(0xFF6B7280), '⌛ Hết hạn'),
        'CANCELED' => (const Color(0xFF6B7280), '🚫 Đã hủy'),
        _          => (const Color(0xFF2563EB), '📨 Đã gửi'),
      };
}

class InvitationProvider extends ChangeNotifier {
  List<Invitation> invitations = [];
  bool loading = false;
  String? error;

  // Lời mời đang chờ Manager duyệt (có người đã xin vào)
  List<Invitation> get awaitingApproval =>
      invitations.where((i) => i.isAwaitingApproval).toList();
  int get awaitingCount => awaitingApproval.length;

  String? get _fid => ApiClient.instance.familyId;

  // GET /families/{id}/invitations (Manager)
  Future<void> fetchInvitations() async {
    final fid = _fid;
    if (fid == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      // BE chỉ nhận query `status` (enum), KHÔNG nhận `limit` — gửi thừa sẽ bị
      // validation chặn toàn bộ request ("Trường limit không được phép").
      final data = await ApiClient.instance.get('/families/$fid/invitations');
      invitations = _list(data).map(Invitation.fromJson).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // POST /invitations/{token}/claim — member xin tham gia (cần đăng nhập)
  Future<void> claim(String token) async {
    await ApiClient.instance.post('/invitations/$token/claim', {});
  }

  // POST /invitations/{token}/reject — người ĐƯỢC MỜI tự chối lời mời gửi
  // đến mình (khác reject(invitationId) bên dưới — đó là Manager từ chối
  // yêu cầu đã CLAIMED). Dùng khi user xem preview lời mời và không muốn
  // tham gia.
  Future<void> declineInvitation(String token) async {
    await ApiClient.instance.post('/invitations/$token/reject', {});
  }

  // POST /families/{id}/invitations/{id}/approve — Manager duyệt
  Future<void> approve(String invitationId, {String? familyRole, String? relationship}) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$fid/invitations/$invitationId/approve',
      {
        'familyRole': ?familyRole,
        'relationship': ?relationship,
      },
    );
    await fetchInvitations();
  }

  // POST /families/{id}/invitations/{id}/reject — Manager từ chối
  Future<void> reject(String invitationId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$fid/invitations/$invitationId/reject', {});
    await fetchInvitations();
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : data is Map && data['items'] is List
            ? data['items'] as List
            : data is Map && data['data'] is List
                ? data['data'] as List
                : <dynamic>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
