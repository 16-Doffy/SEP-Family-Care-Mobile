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

/// `null` khi BE không trả field (khác hẳn với `false`) để nơi gọi tự quyết định
/// fail-open hay fail-closed.
bool? _boolOrNull(dynamic v) {
  if (v is bool) return v;
  if (v == 'true') return true;
  if (v == 'false') return false;
  return null;
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

/// Metadata của GET face-scan. Swagger chưa khai báo response schema đầy đủ,
/// nên parser chấp nhận cả field ở root lẫn object `job`/`scan`.
class FaceScanStatusInfo {
  final FaceScanState state;
  final bool retryAllowed;
  final int? maxProcessingSeconds;

  const FaceScanStatusInfo({
    required this.state,
    this.retryAllowed = false,
    this.maxProcessingSeconds,
  });

  factory FaceScanStatusInfo.fromJson(dynamic value) {
    final root = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final nested = _map(root['job']) ?? _map(root['scan']) ?? root;
    final raw = _str(
      nested['scanStatus'] ??
          nested['faceScanStatus'] ??
          nested['status'] ??
          nested['state'] ??
          root['scanStatus'] ??
          root['faceScanStatus'] ??
          root['status'] ??
          root['state'],
    );
    final retryValue = nested['retryAllowed'] ?? root['retryAllowed'];
    final maxSeconds = _num(
      nested['maxProcessingSeconds'] ?? root['maxProcessingSeconds'],
    );
    return FaceScanStatusInfo(
      state: _scanStateFrom(raw),
      retryAllowed:
          retryValue == true || retryValue?.toString().toLowerCase() == 'true',
      maxProcessingSeconds: maxSeconds?.round(),
    );
  }
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
  /// Trạng thái của **candidate** (`FaceSuggestionCandidateResponseDto.status`):
  /// `PENDING | CONFIRMED | REJECTED | EXPIRED`.
  final String status;

  /// Trạng thái của **khuôn mặt được phát hiện**
  /// (`DetectedFaceSuggestionResponseDto.status`:
  /// `MATCHED | UNMATCHED | SUPERSEDED`) — trùng tên `status` với candidate nên
  /// phải giữ riêng, xem [parseFaceSuggestions].
  final String detectionStatus;
  final String faceKey;
  final int? faceIndex;

  /// `permissions` của BE. `null` = BE không trả field → cho phép (fail-open,
  /// để BE trả 403 quyết định), giống quyền gỡ tag ở `AlbumTag`.
  final bool? canConfirmFlag;
  final bool? canRejectFlag;

  const FaceSuggestion({
    required this.id,
    required this.memberId,
    this.memberName = '',
    this.confidence,
    this.status = 'PENDING',
    this.detectionStatus = '',
    this.faceKey = '',
    this.faceIndex,
    this.canConfirmFlag,
    this.canRejectFlag,
  });

  bool get canConfirm => canConfirmFlag ?? true;
  bool get canReject => canRejectFlag ?? true;

  /// Confidence chuẩn hóa về thang 0..1 (BE có thể trả 0..1 hoặc 0..100).
  double? get normalizedConfidence {
    final c = confidence;
    if (c == null) return null;
    final v = c > 1 ? c / 100 : c;
    return v.clamp(0, 1).toDouble();
  }

  /// Gợi ý đã được xử lý (xác nhận / từ chối / **hết hạn**) thì không còn là việc
  /// chờ làm. `EXPIRED` là trạng thái chính thức trong Swagger — thiếu nó thì gợi
  /// ý hết hạn vẫn hiện nút Xác nhận, bấm vào chỉ nhận lỗi. Các biến thể tên khác
  /// vẫn bắt theo chuỗi con để status lạ/thiếu còn hiện ra (fail-open) như phần
  /// còn lại của file.
  bool get isResolved {
    final s = status.toUpperCase();
    return s.contains('CONFIRM') ||
        s.contains('ACCEPT') ||
        s.contains('APPROV') ||
        s.contains('TAGGED') ||
        s.contains('REJECT') ||
        s.contains('DECLIN') ||
        s.contains('DISMISS') ||
        s.contains('EXPIRE');
  }

  /// Khuôn mặt đã bị lần quét mới thay thế (`SUPERSEDED`). Candidate bên trong
  /// vẫn có thể là `PENDING`, nên phải lọc theo trạng thái khuôn mặt chứ không
  /// chỉ theo [isResolved] của candidate.
  bool get isSupersededDetection =>
      detectionStatus.toUpperCase().contains('SUPERSED');

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
      detectionStatus: _str(j['detectionStatus']),
      canConfirmFlag: _boolOrNull(_map(j['permissions'])?['canConfirm']),
      canRejectFlag: _boolOrNull(_map(j['permissions'])?['canReject']),
      faceKey: _str(
        j['faceId'] ??
            j['detectedFaceId'] ??
            j['faceDetectionId'] ??
            j['detectionId'],
      ),
      faceIndex:
          (j['faceIndex'] as num?)?.toInt() ?? (j['index'] as num?)?.toInt(),
    );
  }
}

/// Chuẩn hóa response face-suggestions mới của BE.
///
/// BE có thể trả danh sách phẳng (mỗi item là một suggestion), hoặc nhóm theo
/// từng khuôn mặt với `candidates`/`matches`. Với mỗi khuôn mặt FE chỉ giữ ứng
/// viên có điểm cao nhất; các khuôn mặt khác nhau vẫn được giữ độc lập để user
/// xác nhận từng người. Việc chọn điểm cao nhất KHÔNG tự tạo tag chính thức.
@visibleForTesting
List<FaceSuggestion> parseFaceSuggestions(dynamic data) {
  List<dynamic> rootItems(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return const [];
    for (final key in const [
      'items',
      'results',
      'suggestions',
      'faceSuggestions',
      'faces',
      'detections',
    ]) {
      final nested = value[key];
      if (nested is List) return nested;
    }
    return [value];
  }

  final flattened = <Map<String, dynamic>>[];
  for (final raw in rootItems(data)) {
    if (raw is! Map) continue;
    final face = Map<String, dynamic>.from(raw);
    List? candidates;
    for (final key in const [
      'candidates',
      'matches',
      'suggestions',
      'faceSuggestions',
    ]) {
      if (face[key] is List) {
        candidates = face[key] as List;
        break;
      }
    }
    if (candidates == null) {
      flattened.add(face);
      continue;
    }
    // `DetectedFaceSuggestionResponseDto.status` (MATCHED | UNMATCHED |
    // SUPERSEDED) trùng tên field với `status` của candidate (PENDING |
    // CONFIRMED | REJECTED | EXPIRED). Candidate được spread sau nên sẽ đè mất
    // trạng thái khuôn mặt → tách ra key riêng trước khi ghép, nếu không khuôn
    // mặt SUPERSEDED (đã bị lần quét mới thay thế) vẫn hiện như gợi ý còn hiệu
    // lực sau khi force rescan.
    final detectionStatus = _str(face['detectionStatus'] ?? face['status']);
    for (final candidate in candidates.whereType<Map>()) {
      final merged = <String, dynamic>{
        ...face,
        ...Map<String, dynamic>.from(candidate),
      };
      if (detectionStatus.isNotEmpty) {
        merged['detectionStatus'] = detectionStatus;
      }
      // Không để list lồng nhau bị hiểu nhầm ở bước parse tiếp theo.
      for (final key in const [
        'candidates',
        'matches',
        'suggestions',
        'faceSuggestions',
      ]) {
        merged.remove(key);
      }
      flattened.add(merged);
    }
  }

  final parsed = flattened
      .map(FaceSuggestion.fromJson)
      .where(
        (s) => s.id.isNotEmpty && !s.isResolved && !s.isSupersededDetection,
      )
      .toList();
  final bestByFace = <String, FaceSuggestion>{};
  final withoutFaceKey = <FaceSuggestion>[];
  for (final suggestion in parsed) {
    final key = suggestion.faceKey.isNotEmpty
        ? suggestion.faceKey
        : suggestion.faceIndex != null
        ? 'index:${suggestion.faceIndex}'
        : '';
    if (key.isEmpty) {
      withoutFaceKey.add(suggestion);
      continue;
    }
    final current = bestByFace[key];
    if (current == null ||
        (suggestion.normalizedConfidence ?? -1) >
            (current.normalizedConfidence ?? -1)) {
      bestByFace[key] = suggestion;
    }
  }
  return [...bestByFace.values, ...withoutFaceKey];
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
  Future<FaceScanStatusInfo> fetchScanInfo(String mediaId) async {
    final fid = _fid;
    if (fid == null) {
      return const FaceScanStatusInfo(state: FaceScanState.notScanned);
    }
    final data = await ApiClient.instance.get(
      '/families/$fid/albums/media/$mediaId/face-scan',
    );
    return FaceScanStatusInfo.fromJson(data);
  }

  Future<FaceScanState> fetchScanStatus(String mediaId) async =>
      (await fetchScanInfo(mediaId)).state;

  // POST /albums/media/{mediaId}/face-scan/retry — chỉ gọi khi GET status trả
  // retryAllowed=true (job FAILED hoặc PROCESSING/PENDING quá thời gian tối đa).
  Future<void> retryScan(String mediaId) async {
    final fid = _fid;
    if (fid == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$fid/albums/media/$mediaId/face-scan/retry',
      const {},
    );
  }

  // GET /albums/media/{mediaId}/face-suggestions
  Future<List<FaceSuggestion>> fetchSuggestions(String mediaId) async {
    final fid = _fid;
    if (fid == null) return [];
    final data = await ApiClient.instance.get(
      '/families/$fid/albums/media/$mediaId/face-suggestions',
    );
    return parseFaceSuggestions(data);
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
