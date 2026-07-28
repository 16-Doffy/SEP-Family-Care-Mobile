import 'package:flutter/foundation.dart';

import '../models/feature_access.dart';
import '../services/api_client.dart';

String _str(dynamic v) => v?.toString() ?? '';
Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String _nameFrom(Map<String, dynamic>? map) {
  if (map == null) return '';
  final user =
      _map(map['user']) ??
      _map(map['userAccount']) ??
      _map(map['account']) ??
      _map(map['profile']);
  return _str(
    map['displayName'] ??
        map['fullName'] ??
        map['name'] ??
        map['memberName'] ??
        user?['displayName'] ??
        user?['fullName'] ??
        user?['name'],
  ).trim();
}

/// Trạng thái quét khuôn mặt của một media album. Response schema của
/// GET face-scan để trống trong Swagger → chuẩn hóa nhiều biến thể tên trạng
/// thái mà BE có thể trả (theo flow Nhật: chưa quét / đang quét / đã quét /
/// không phát hiện / có gợi ý / quét thất bại).
enum FaceScanState {
  notScanned,
  processing,
  scanned,
  noFace,
  hasSuggestions,
  failed,
}

FaceScanState _scanStateFrom(String raw) {
  final s = raw.toUpperCase();
  if (s.contains('PROCESS') || s.contains('SCANNING') || s == 'PENDING') {
    return FaceScanState.processing;
  }
  if (s.contains('NO_FACE') || s.contains('NOFACE') || s == 'NONE') {
    return FaceScanState.noFace;
  }
  if (s.contains('SUGGEST')) return FaceScanState.hasSuggestions;
  if (s.contains('FAIL') || s.contains('ERROR')) return FaceScanState.failed;
  if (s.contains('DONE') || s.contains('COMPLETE') || s == 'SCANNED') {
    return FaceScanState.scanned;
  }
  return FaceScanState.notScanned;
}

/// Một đề xuất tag từ face scan. Chỉ giữ field tối thiểu; tên thành viên resolve
/// từ FamilyProvider ở UI vì response chưa chốt có kèm tên hay không.
class FaceSuggestion {
  final String id;
  final String memberId;
  final String memberName;
  final double? confidence; // 0..1 hoặc 0..100 tùy BE — UI tự chuẩn hóa
  final String status; // PENDING | CONFIRMED | REJECTED

  const FaceSuggestion({
    required this.id,
    required this.memberId,
    this.memberName = '',
    this.confidence,
    this.status = 'PENDING',
  });

  /// Confidence chuẩn hóa về thang 0..1 (BE có thể trả 0..1 hoặc 0..100).
  double? get normalizedConfidence {
    final c = confidence;
    if (c == null) return null;
    final v = c > 1 ? c / 100 : c;
    return v.clamp(0, 1).toDouble();
  }

  /// Gợi ý đã được xử lý (xác nhận / từ chối) thì không còn là việc chờ làm.
  /// Response schema của face-suggestions vẫn để trống trong Swagger → loại theo
  /// các trạng thái "đã xử lý" đã biết thay vì chỉ giữ đúng `PENDING`, để status
  /// lạ vẫn hiện ra (fail-open) như phần còn lại của file.
  bool get isResolved {
    final s = status.toUpperCase();
    return s.contains('CONFIRM') ||
        s.contains('ACCEPT') ||
        s.contains('APPROV') ||
        s.contains('TAGGED') ||
        s.contains('REJECT') ||
        s.contains('DECLIN') ||
        s.contains('DISMISS');
  }

  factory FaceSuggestion.fromJson(Map<String, dynamic> j) {
    final member =
        _map(j['suggestedMember']) ??
        _map(j['matchedMember']) ??
        _map(j['familyMember']) ??
        _map(j['taggedMember']) ??
        _map(j['member']) ??
        const <String, dynamic>{};
    final user =
        _map(member['user']) ??
        _map(member['userAccount']) ??
        _map(j['suggestedUser']) ??
        _map(j['user']);
    final directName = _str(
      j['suggestedMemberName'] ??
          j['matchedMemberName'] ??
          j['memberName'] ??
          j['displayName'] ??
          j['fullName'],
    ).trim();
    final nestedMemberName = _nameFrom(member);
    final nestedUserName = _nameFrom(user);
    return FaceSuggestion(
      id: _str(j['suggestionId'] ?? j['faceSuggestionId'] ?? j['id']),
      memberId: _str(
        j['suggestedMemberId'] ??
            j['matchedMemberId'] ??
            j['familyMemberId'] ??
            j['memberId'] ??
            j['userId'] ??
            member['id'],
      ),
      memberName: directName.isNotEmpty
          ? directName
          : (nestedMemberName.isNotEmpty ? nestedMemberName : nestedUserName),
      confidence: _num(
        j['confidence'] ?? j['score'] ?? j['similarity'] ?? j['matchScore'],
      ),
      status: _str(j['status'] ?? j['state']).isEmpty
          ? 'PENDING'
          : _str(j['status'] ?? j['state']),
    );
  }
}

class AlbumFaceProvider extends ChangeNotifier {
  FeatureAccess? _featureAccess;

  String? get _fid => ApiClient.instance.familyId;

  /// Face suggestion là tính năng gói trả phí (key chính thức
  /// `album.faceSuggestions`). Chưa biết quyền → fail-open, để BE trả 403.
  bool get canUseFaceSuggestions =>
      _featureAccess == null ||
      _featureAccess!.isUnknown ||
      _featureAccess!.flag(
        'album.faceSuggestions',
        aliases: const ['albumFaceSuggestions'],
      );

  Future<void> fetchFeatureAccess() async {
    final fid = _fid;
    if (fid == null) return;
    try {
      final data = await ApiClient.instance.get('/families/$fid/subscription');
      final plan = data is Map && data['plan'] is Map
          ? Map<String, dynamic>.from(data['plan'] as Map)
          : const <String, dynamic>{};
      final access = data is Map
          ? data['featureAccess'] ?? plan['featureAccess']
          : plan['featureAccess'];
      _featureAccess = FeatureAccess.fromJson(access);
      notifyListeners();
    } catch (e) {
      debugPrint('AlbumFaceProvider: fetchFeatureAccess failed: $e');
    }
  }

  // POST /albums/media/{mediaId}/face-scan  body {force}
  Future<void> requestScan(String mediaId, {bool force = false}) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$fid/albums/media/$mediaId/face-scan',
      {'force': force},
    );
  }

  // GET /albums/media/{mediaId}/face-scan
  Future<FaceScanState> fetchScanStatus(String mediaId) async {
    final fid = _fid;
    if (fid == null) return FaceScanState.notScanned;
    final data = await ApiClient.instance.get(
      '/families/$fid/albums/media/$mediaId/face-scan',
    );
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    final raw = _str(
      map['scanStatus'] ??
          map['faceScanStatus'] ??
          map['status'] ??
          map['state'],
    );
    return _scanStateFrom(raw);
  }

  // GET /albums/media/{mediaId}/face-suggestions
  Future<List<FaceSuggestion>> fetchSuggestions(String mediaId) async {
    final fid = _fid;
    if (fid == null) return [];
    final data = await ApiClient.instance.get(
      '/families/$fid/albums/media/$mediaId/face-suggestions',
    );
    final raw = data is List
        ? data
        : (data is Map && data['items'] is List
              ? data['items'] as List
              : (data is Map && data['data'] is List
                    ? data['data'] as List
                    : (data is Map && data['results'] is List
                          ? data['results'] as List
                          : (data is Map && data['suggestions'] is List
                                ? data['suggestions'] as List
                                : (data is Map &&
                                          data['faceSuggestions'] is List
                                      ? data['faceSuggestions'] as List
                                      : const <dynamic>[])))));
    return raw
        .whereType<Map>()
        .map((e) => FaceSuggestion.fromJson(Map<String, dynamic>.from(e)))
        // BE vẫn trả cả gợi ý đã xác nhận/từ chối → không lọc thì tag đã gắn
        // xong vẫn hiện lại kèm nút Xác nhận mỗi lần load lại.
        .where((s) => s.id.isNotEmpty && !s.isResolved)
        .toList();
  }

  // POST .../face-suggestions/{suggestionId}/confirm — chỉ khi xác nhận mới
  // tạo tag chính thức (theo flow Nhật).
  Future<void> confirmSuggestion(String mediaId, String suggestionId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$fid/albums/media/$mediaId/face-suggestions/$suggestionId/confirm',
      {},
    );
  }

  // POST .../face-suggestions/{suggestionId}/reject
  Future<void> rejectSuggestion(String mediaId, String suggestionId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$fid/albums/media/$mediaId/face-suggestions/$suggestionId/reject',
      {},
    );
  }
}
