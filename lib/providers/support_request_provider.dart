import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SupportRequest {
  final String id;

  /// Tên người gửi yêu cầu — **rỗng nếu BE không trả tên**. Dùng [displayName]
  /// để hiển thị, hoặc tra theo [requesterMemberId] trong danh sách thành viên.
  final String requesterName;

  /// `FamilyMember.id` của người gửi, để tra tên khi BE chỉ trả id.
  final String? requesterMemberId;
  final double amount;
  final String purpose;
  final String status;
  final DateTime createdAt;
  final String? decisionNote;

  const SupportRequest({
    required this.id,
    required this.requesterName,
    this.requesterMemberId,
    required this.amount,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.decisionNote,
  });

  /// Tên để hiển thị khi không tra được gì thêm.
  String get displayName =>
      requesterName.trim().isEmpty ? 'Thành viên' : requesterName.trim();

  factory SupportRequest.fromJson(Map<String, dynamic> json) {
    // BE dùng `requesterMemberId` cho filter, nên object lồng gần như chắc là
    // `requesterMember` theo đúng khuôn các DTO member khác
    // (`{ id, displayName, user: { fullName } }`). Bản cũ chỉ đọc `requester`/
    // `user` và chỉ lấy field TRỰC TIẾP → không bao giờ ra tên, luôn rơi về
    // 'Thành viên'. Đọc phòng thủ cả 4 biến thể + tầng `user` lồng bên trong.
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final member =
        asMap(json['requesterMember']) ??
        asMap(json['requester']) ??
        asMap(json['member']) ??
        asMap(json['user']) ??
        const <String, dynamic>{};
    final user = asMap(member['user']) ?? asMap(member['userAccount']) ?? const {};

    String? pick(List<String?> values) {
      for (final v in values) {
        final s = v?.trim();
        if (s != null && s.isNotEmpty) return s;
      }
      return null;
    }

    return SupportRequest(
      id: json['id']?.toString() ?? '',
      requesterMemberId: pick([
        json['requesterMemberId']?.toString(),
        member['id']?.toString(),
      ]),
      // Để RỖNG khi không có tên thật, thay vì nhồi sẵn 'Thành viên': UI cần
      // phân biệt "BE không trả tên" với "tên đúng là vậy" để còn tra lại theo
      // requesterMemberId. Hiển thị dùng [displayName].
      requesterName:
          pick([
            user['fullName']?.toString(),
            member['displayName']?.toString(),
            user['name']?.toString(),
            member['fullName']?.toString(),
            member['name']?.toString(),
            json['requesterName']?.toString(),
          ]) ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      decisionNote: json['decisionNote']?.toString(),
    );
  }

  bool get isPending => status == 'PENDING';
}

class SupportRequestProvider extends ChangeNotifier {
  SupportRequestProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    _requests = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }

  List<SupportRequest> _requests = [];
  bool _loading = false;
  String? _error;

  List<SupportRequest> get requests => _requests;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingCount => _requests.where((r) => r.isPending).length;

  Future<void> fetchRequests() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/finance/support-requests',
      );
      final list = data is List
          ? data
          : (data['items'] as List? ?? data['data'] as List? ?? []);
      _requests = list
          .whereType<Map<String, dynamic>>()
          .map(SupportRequest.fromJson)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest({
    required double amount,
    required String purpose,
    String? categoryId,
  }) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final body = <String, dynamic>{
      'amount': amount,
      'purpose': purpose,
      'categoryId': ?categoryId,
    };
    await ApiClient.instance.post(
      '/families/$fid/finance/support-requests',
      body,
    );
    await fetchRequests();
  }

  Future<void> review({
    required String requestId,
    required String decision,
    String? decisionNote,
  }) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;
    final body = <String, dynamic>{
      'decision': decision,
      if (decisionNote != null && decisionNote.isNotEmpty)
        'decisionNote': decisionNote,
      // Giữ semantic cũ: local wall-clock + `Z` cho tới khi BE chốt UTC thật.
      'occurredAt': ApiClient.localIsoMs(),
    };
    await ApiClient.instance.patch(
      '/families/$fid/finance/support-requests/$requestId/review',
      body,
    );
    await fetchRequests();
  }

  // GET /families/{familyId}/finance/support-requests/{requestId} — chi
  // tiết 1 yêu cầu (list đã đủ hầu hết field hiển thị, gọi thêm để lấy field
  // audit như reviewedBy/reviewedAt nếu BE có mà list không trả về).
  Future<Map<String, dynamic>> fetchRequestDetail(String requestId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.get(
      '/families/$fid/finance/support-requests/$requestId',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> cancel(String requestId) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$fid/finance/support-requests/$requestId/cancel',
      {},
    );
    await fetchRequests();
  }
}
