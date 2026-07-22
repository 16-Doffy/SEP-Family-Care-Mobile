import 'package:flutter/foundation.dart';

import '../models/feature_access.dart';
import '../services/api_client.dart';

String _str(dynamic v) => v?.toString() ?? '';
double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
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
  final double? confidence; // 0..1 hoặc 0..100 tùy BE — UI tự chuẩn hóa
  final String status; // PENDING | CONFIRMED | REJECTED

  const FaceSuggestion({
    required this.id,
    required this.memberId,
    this.confidence,
    this.status = 'PENDING',
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory FaceSuggestion.fromJson(Map<String, dynamic> j) {
    final member = j['suggestedMember'] is Map
        ? Map<String, dynamic>.from(j['suggestedMember'] as Map)
        : (j['member'] is Map
              ? Map<String, dynamic>.from(j['member'] as Map)
              : const <String, dynamic>{});
    return FaceSuggestion(
      id: _str(j['suggestionId'] ?? j['faceSuggestionId'] ?? j['id']),
      memberId: _str(
        j['suggestedMemberId'] ??
            j['matchedMemberId'] ??
            j['memberId'] ??
            member['id'],
      ),
      confidence: _num(
        j['confidence'] ?? j['score'] ?? j['similarity'] ?? j['matchScore'],
      ),
      status: _str(j['status'] ?? j['state']).isEmpty
          ? 'PENDING'
          : _str(j['status'] ?? j['state']),
    );
  }
}

class FaceProfileStatus {
  final String memberId;
  final String status;
  final bool exists;
  final bool enabled;
  final DateTime? enrolledAt;

  const FaceProfileStatus({
    required this.memberId,
    required this.status,
    required this.exists,
    required this.enabled,
    this.enrolledAt,
  });

  factory FaceProfileStatus.none(String memberId) => FaceProfileStatus(
    memberId: memberId,
    status: 'NOT_ENROLLED',
    exists: false,
    enabled: false,
  );

  factory FaceProfileStatus.fromJson(
    Map<String, dynamic> j, {
    required String memberId,
  }) {
    final raw = _str(j['status'] ?? j['state'] ?? j['profileStatus']);
    final disabled =
        j['isDisabled'] == true ||
        j['enabled'] == false ||
        raw.toUpperCase() == 'DISABLED';
    final hasId = _str(
      j['id'] ?? j['profileId'] ?? j['faceProfileId'],
    ).isNotEmpty;
    final exists =
        hasId ||
        j['exists'] == true ||
        j['enrolled'] == true ||
        raw.isNotEmpty && raw.toUpperCase() != 'NOT_ENROLLED';
    return FaceProfileStatus(
      memberId: memberId,
      status: raw.isEmpty ? (exists ? 'ENROLLED' : 'NOT_ENROLLED') : raw,
      exists: exists,
      enabled: exists && !disabled,
      enrolledAt: DateTime.tryParse(_str(j['enrolledAt'] ?? j['createdAt'])),
    );
  }

  bool get isEnrolled => exists;
  bool get isDisabled => exists && !enabled;
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
                    : const <dynamic>[]));
    return raw
        .whereType<Map>()
        .map((e) => FaceSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
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

  Future<FaceProfileStatus> fetchFaceProfile(String memberId) async {
    final fid = _fid;
    if (fid == null) return FaceProfileStatus.none(memberId);
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/face-profiles/$memberId',
      );
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      return FaceProfileStatus.fromJson(map, memberId: memberId);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return FaceProfileStatus.none(memberId);
      rethrow;
    }
  }

  Future<FaceProfileStatus> enrollFaceProfile({
    required String memberId,
    required List<String> imagePaths,
    required bool consentConfirmed,
  }) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    if (imagePaths.length < 3 || imagePaths.length > 5) {
      throw Exception('Vui lòng chọn từ 3 đến 5 ảnh khuôn mặt.');
    }
    if (!consentConfirmed) {
      throw Exception('Cần xác nhận đồng ý trước khi đăng ký khuôn mặt.');
    }
    final data = await ApiClient.instance.uploadFiles(
      path: '/families/$fid/face-profiles/$memberId/enroll',
      filePaths: imagePaths,
      fieldName: 'files',
      fields: const {'consentConfirmed': 'true'},
    );
    notifyListeners();
    return data.isEmpty
        ? FaceProfileStatus(
            memberId: memberId,
            status: 'ENROLLED',
            exists: true,
            enabled: true,
            enrolledAt: DateTime.now(),
          )
        : FaceProfileStatus.fromJson(data, memberId: memberId);
  }

  Future<void> enableFaceProfile(String memberId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$fid/face-profiles/$memberId/enable',
      {},
    );
    notifyListeners();
  }

  Future<void> disableFaceProfile(String memberId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.patch(
      '/families/$fid/face-profiles/$memberId/disable',
      {},
    );
    notifyListeners();
  }

  Future<void> deleteFaceProfile(String memberId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.delete(
      '/families/$fid/face-profiles/$memberId',
      body: const {'confirmation': 'DELETE_FACE_PROFILE'},
    );
    notifyListeners();
  }
}
