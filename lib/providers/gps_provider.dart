import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/location_realtime_service.dart';

// Shape response đã được BE document (Swagger 19/07):
// { userId, memberId, displayName, avatarUrl, latitude, longitude, accuracy,
//   updatedAt, isSharing } — vẫn giữ fallback key cũ cho chắc.
class LocationShare {
  final String userId;
  final String? memberId;
  final String displayName;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? updatedAt;
  final bool isSharing;

  const LocationShare({
    required this.userId,
    this.memberId,
    required this.displayName,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.updatedAt,
    this.isSharing = true,
  });

  factory LocationShare.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final displayName =
        json['displayName']?.toString() ??
        json['fullName']?.toString() ??
        user['displayName']?.toString() ??
        user['fullName']?.toString() ??
        'Thành viên';
    return LocationShare(
      userId: json['userId']?.toString() ?? user['id']?.toString() ?? '',
      memberId: json['memberId']?.toString(),
      displayName: displayName,
      avatarUrl: json['avatarUrl']?.toString() ?? user['avatarUrl']?.toString(),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      accuracy: _parseDouble(json['accuracy']),
      updatedAt:
          json['updatedAt']?.toString() ?? json['recordedAt']?.toString(),
      // Endpoint chỉ trả thành viên đang bật chia sẻ → mặc định true.
      isSharing: json['isSharing'] as bool? ?? true,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

class GpsProvider extends ChangeNotifier {
  GpsProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    stopRealtime();
    _shares = [];
    _loading = false;
    _busy = false;
    _error = null;
    _sharingUnavailable = false;
    _mySharing = false;
    _lastPushError = null;
    notifyListeners();
  }

  List<LocationShare> _shares = [];
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _sharingUnavailable = false;
  bool _realtimeOn = false;
  String? _realtimeMyUserId;

  // Trạng thái chia sẻ vị trí của CHÍNH MÌNH. BE không có endpoint đọc riêng →
  // suy từ việc mình có mặt trong members/locations (endpoint chỉ trả người
  // đang bật), và cập nhật lạc quan khi bấm toggle.
  bool _mySharing = false;

  /// Lỗi lần đẩy vị trí gần nhất qua [updateLocation] — kể cả lượt `silent`
  /// (timer nền mỗi 5 giây). Trước đây lỗi này chỉ `debugPrint` rồi biến mất,
  /// không có cách nào biết "đang chia sẻ vị trí" thật ra có tới server hay
  /// không — quan sát runtime 2026-08-19: BE từ chối liên tục
  /// ("Vĩ độ phải là số"/"Độ chính xác phải là số") mỗi chu kỳ mà UI vẫn hiện
  /// công tắc "đang bật" bình thường, không ai biết vị trí không hề cập nhật.
  String? _lastPushError;

  List<LocationShare> get shares => _shares;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  bool get mySharing => _mySharing;
  String? get lastPushError => _lastPushError;
  bool get realtimeConnected => LocationRealtimeService.instance.connected;
  // Giữ làm lưới an toàn: nếu endpoint location 404 (BE rollback/đổi path),
  // UI hiện "đang phát triển" thay vì phơi raw "Cannot GET ...".
  bool get sharingUnavailable => _sharingUnavailable;

  // BE ship 3 EP location 19/07 (đúng contract BAO_CAO_BE_SOS_2026-07-16 §7
  // phương án B — family-scoped). Path cũ `/location/*` đã chết, không dùng.
  String? get _fid => ApiClient.instance.familyId;

  void startRealtime({String? myUserId}) {
    if (_realtimeOn) return;
    _realtimeOn = true;
    _realtimeMyUserId = myUserId;
    final svc = LocationRealtimeService.instance;
    svc.onLocationUpdated = _applyRealtimeLocationUpdated;
    svc.onSharingChanged = _applyRealtimeSharingChanged;
    svc.connect();
  }

  void stopRealtime() {
    if (!_realtimeOn) return;
    _realtimeOn = false;
    _realtimeMyUserId = null;
    final svc = LocationRealtimeService.instance;
    svc.onLocationUpdated = null;
    svc.onSharingChanged = null;
    svc.disconnect();
  }

  void _applyRealtimeLocationUpdated(Map<String, dynamic> payload) {
    final workspaceId = payload['workspaceId']?.toString();
    final fid = _fid;
    if (fid != null &&
        workspaceId != null &&
        workspaceId.isNotEmpty &&
        workspaceId != fid) {
      return;
    }

    final share = LocationShare.fromJson(payload);
    if (share.userId.isEmpty &&
        (share.memberId == null || share.memberId!.isEmpty)) {
      return;
    }
    if (!share.isSharing || share.latitude == null || share.longitude == null) {
      _removeShare(memberId: share.memberId, userId: share.userId);
      notifyListeners();
      return;
    }

    _upsertShare(share);
    if (_realtimeMyUserId != null && share.userId == _realtimeMyUserId) {
      _mySharing = share.isSharing;
    }
    notifyListeners();
  }

  void _applyRealtimeSharingChanged(Map<String, dynamic> payload) {
    final workspaceId = payload['workspaceId']?.toString();
    final fid = _fid;
    if (fid != null &&
        workspaceId != null &&
        workspaceId.isNotEmpty &&
        workspaceId != fid) {
      return;
    }

    final memberId = payload['memberId']?.toString();
    final isSharing = payload['isSharing'] as bool? ?? false;
    if (memberId == null || memberId.isEmpty) return;

    final existing = _shareByMemberId(memberId);
    if (_realtimeMyUserId != null && existing?.userId == _realtimeMyUserId) {
      _mySharing = isSharing;
    }
    if (!isSharing) {
      _removeShare(memberId: memberId);
    }
    notifyListeners();
  }

  void _upsertShare(LocationShare share) {
    final index = _shares.indexWhere(
      (s) =>
          (share.memberId != null &&
              share.memberId!.isNotEmpty &&
              s.memberId == share.memberId) ||
          (share.userId.isNotEmpty && s.userId == share.userId),
    );
    if (index == -1) {
      _shares = [share, ..._shares];
      return;
    }
    _shares = [
      for (var i = 0; i < _shares.length; i++) i == index ? share : _shares[i],
    ];
  }

  LocationShare? _shareByMemberId(String memberId) {
    for (final share in _shares) {
      if (share.memberId == memberId) return share;
    }
    return null;
  }

  void _removeShare({String? memberId, String? userId}) {
    _shares = [
      for (final share in _shares)
        if (!((memberId != null &&
                memberId.isNotEmpty &&
                share.memberId == memberId) ||
            (userId != null && userId.isNotEmpty && share.userId == userId)))
          share,
    ];
  }

  Future<void> fetchFamilyLocations({
    String? myUserId,
    bool silent = false,
  }) async {
    final fid = _fid;
    if (fid == null) return;
    if (!silent) _loading = true;
    _error = null;
    _sharingUnavailable = false;
    if (!silent) notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$fid/members/locations',
      );
      final list = data is List
          ? data
          : data is Map && data['shares'] is List
          ? data['shares'] as List
          : data is Map && data['items'] is List
          ? data['items'] as List
          : data is Map && data['locations'] is List
          ? data['locations'] as List
          : <dynamic>[];
      _shares = list
          .whereType<Map>()
          .map((e) => LocationShare.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Có mặt trong danh sách = mình đang bật chia sẻ.
      if (myUserId != null && myUserId.isNotEmpty) {
        _mySharing = _shares.any((s) => s.userId == myUserId && s.isSharing);
      }
    } catch (e) {
      // Nếu endpoint location trả 404 (rollback/đổi path) → coi như chưa. Đây
      // KHÔNG phải lỗi thật, chỉ là tính năng chia sẻ vị trí chưa sẵn sàng —
      // đặt cờ để UI hiện "đang phát triển", không phơi thông báo kỹ thuật.
      final msg = e.toString();
      if (msg.contains('Cannot GET') ||
          msg.contains('404') ||
          msg.toLowerCase().contains('not found')) {
        _sharingUnavailable = true;
        _error = null;
      } else {
        _error = 'Không tải được vị trí gia đình';
      }
    } finally {
      if (!silent) _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSharing(bool value, {String? myUserId}) async {
    final fid = _fid;
    if (fid == null) return;
    _busy = true;
    _mySharing = value; // lạc quan để UI phản hồi ngay
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$fid/members/me/location-sharing',
        {'isSharing': value},
      );
      await fetchFamilyLocations(myUserId: myUserId);
      // Endpoint danh sách có thể chưa trả chính mình ngay sau PATCH nếu chưa
      // có bản ghi tọa độ mới. Giữ trạng thái theo kết quả PATCH để switch
      // không bật xong lại nhảy về tắt trước khi FE kịp POST /locations.
      _mySharing = value;
    } catch (e) {
      _mySharing = !value; // rollback nếu BE từ chối
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Đẩy vị trí của mình. [silent] = true khi gọi từ timer định kỳ: không bật
  /// cờ busy và không refetch, tránh nhấp nháy UI mỗi chu kỳ.
  Future<void> updateLocation(
    double latitude,
    double longitude, {
    double accuracy = 18,
    bool silent = false,
    String? myUserId,
  }) async {
    final fid = _fid;
    if (fid == null) return;
    // Chặn trước khi gửi: một số thiết bị (quan sát runtime 2026-08-19 trên
    // Oppo/ColorOS) có thể trả toạ độ/độ chính xác bất thường lúc GPS vừa
    // khởi động hoặc tín hiệu yếu (NaN/Infinity, hoặc lệch khoảng hợp lệ
    // -90..90 / -180..180) — BE validate chặt và từ chối bằng thông báo dạng
    // "Vĩ độ phải là số"/"Độ chính xác phải là số". Trước đây không có bước
    // này, mỗi lượt bất thường vẫn cứ gửi rồi bị BE từ chối lặp lại đều đặn.
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !accuracy.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      final msg =
          'Toạ độ GPS không hợp lệ (lat=$latitude, lng=$longitude, '
          'accuracy=$accuracy) — bỏ qua lượt gửi này';
      debugPrint('GpsProvider: updateLocation $msg');
      if (_lastPushError != msg) {
        _lastPushError = msg;
        notifyListeners();
      }
      return;
    }
    if (!silent) {
      _busy = true;
      notifyListeners();
    }
    try {
      await ApiClient.instance.post('/families/$fid/locations', {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      });
      // Không còn nuốt lỗi âm thầm: trước đây lượt `silent` (timer nền) chỉ
      // debugPrint rồi không ai biết — giờ lưu lại để UI đọc được qua
      // [lastPushError], chỉ notifyListeners khi TRẠNG THÁI THAY ĐỔI (tránh
      // rebuild mỗi 5 giây dù không có gì mới, đúng tinh thần "silent" ban đầu).
      if (_lastPushError != null) {
        _lastPushError = null;
        notifyListeners();
      }
      if (!silent) await fetchFamilyLocations(myUserId: myUserId);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('GpsProvider: updateLocation failed: $e');
      if (_lastPushError != msg) {
        _lastPushError = msg;
        notifyListeners();
      }
    } finally {
      if (!silent) {
        _busy = false;
        notifyListeners();
      }
    }
  }
}
