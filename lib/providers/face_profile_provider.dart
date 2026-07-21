import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

enum FaceProfileStatus {
  notEnrolled,
  processing,
  ready,
  failed,
  disabled,
  unknown,
}

class FaceProfile {
  final String memberId;
  final FaceProfileStatus status;
  final String? message;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const FaceProfile({
    required this.memberId,
    required this.status,
    this.message,
    this.updatedAt,
    this.raw = const {},
  });

  factory FaceProfile.fromJson(String memberId, Map<String, dynamic> json) {
    final value = (json['status'] ?? json['profileStatus'] ?? '')
        .toString()
        .toUpperCase();
    final status = switch (value) {
      'NOT_ENROLLED' || 'NONE' || '' => FaceProfileStatus.notEnrolled,
      'PROCESSING' || 'PENDING' || 'ENROLLING' => FaceProfileStatus.processing,
      'READY' || 'ACTIVE' || 'ENROLLED' => FaceProfileStatus.ready,
      'FAILED' || 'ERROR' || 'NEEDS_UPDATE' => FaceProfileStatus.failed,
      'DISABLED' || 'INACTIVE' => FaceProfileStatus.disabled,
      _ => FaceProfileStatus.unknown,
    };
    return FaceProfile(
      memberId: memberId,
      status: status,
      message: (json['message'] ?? json['errorMessage'])?.toString(),
      updatedAt: DateTime.tryParse(
        (json['updatedAt'] ?? json['createdAt'] ?? '').toString(),
      )?.toLocal(),
      raw: json,
    );
  }

  String get label => switch (status) {
    FaceProfileStatus.notEnrolled => 'Chưa thiết lập',
    FaceProfileStatus.processing => 'Đang xử lý',
    FaceProfileStatus.ready => 'Đã thiết lập',
    FaceProfileStatus.failed => 'Lỗi / cần cập nhật',
    FaceProfileStatus.disabled => 'Đã tắt',
    FaceProfileStatus.unknown => 'Không rõ trạng thái',
  };
}

class FaceProfileProvider extends ChangeNotifier {
  FaceProfile? profile;
  bool loading = false;
  bool busy = false;
  String? error;

  String get _fid {
    final id = ApiClient.instance.familyId;
    if (id == null || id.isEmpty) throw Exception('Chưa có gia đình');
    return id;
  }

  Future<void> fetch(String memberId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/families/$_fid/face-profiles/$memberId',
      );
      profile = FaceProfile.fromJson(
        memberId,
        data is Map ? Map<String, dynamic>.from(data) : const {},
      );
    } on ApiException catch (e) {
      // Chưa enroll có thể là 404 tùy implementation BE; đó không phải lỗi UI.
      if (e.statusCode == 404) {
        profile = FaceProfile(
          memberId: memberId,
          status: FaceProfileStatus.notEnrolled,
        );
      } else {
        error = e.message;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> enroll(String memberId, List<String> imagePaths) async {
    if (imagePaths.length < 3 || imagePaths.length > 5) {
      throw ArgumentError('Chọn từ 3 đến 5 ảnh rõ mặt.');
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.uploadFiles(
        path: '/families/$_fid/face-profiles/$memberId/enroll',
        filePaths: imagePaths,
        fields: const {'consentConfirmed': 'true'},
      );
      profile = FaceProfile.fromJson(memberId, data);
      await fetch(memberId);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(String memberId, bool enabled) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await ApiClient.instance.patch(
        '/families/$_fid/face-profiles/$memberId/${enabled ? 'enable' : 'disable'}',
        {},
      );
      await fetch(memberId);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> delete(String memberId) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await ApiClient.instance.delete(
        '/families/$_fid/face-profiles/$memberId',
        body: const {'confirmation': 'DELETE_FACE_PROFILE'},
      );
      profile = FaceProfile(
        memberId: memberId,
        status: FaceProfileStatus.notEnrolled,
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
