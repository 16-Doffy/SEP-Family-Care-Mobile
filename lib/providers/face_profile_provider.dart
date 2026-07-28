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

  // Compat cho lưới Thành viên (Ảnh): suy ra enroll/enabled từ status.
  bool get isEnrolled =>
      status != FaceProfileStatus.notEnrolled &&
      status != FaceProfileStatus.unknown;
  bool get enabled => status == FaceProfileStatus.ready;
  bool get isDisabled => status == FaceProfileStatus.disabled;
}

class FaceValidationResult {
  final int index;
  final String fileName;
  final bool passed;
  final String? reasonCode;
  final String? message;
  final Map<String, dynamic> raw;

  const FaceValidationResult({
    required this.index,
    required this.fileName,
    required this.passed,
    this.reasonCode,
    this.message,
    this.raw = const {},
  });

  factory FaceValidationResult.fromJson(
    Map<String, dynamic> json, {
    required int fallbackIndex,
  }) {
    final rawPassed =
        json['passed'] ?? json['pass'] ?? json['isValid'] ?? json['valid'];
    final reason = json['reasonCode'] ?? json['code'] ?? json['reason'];
    final passed = rawPassed == null
        ? reason == null
        : rawPassed == true ||
              rawPassed.toString().toUpperCase() == 'TRUE' ||
              rawPassed.toString().toUpperCase() == 'PASS';
    return FaceValidationResult(
      index: (json['index'] as num?)?.toInt() ?? fallbackIndex,
      fileName: (json['fileName'] ?? json['filename'] ?? json['name'] ?? '')
          .toString(),
      passed: passed,
      reasonCode: reason?.toString(),
      message: (json['message'] ?? json['errorMessage'])?.toString(),
      raw: json,
    );
  }

  String get displayMessage {
    if (passed) return 'Đạt yêu cầu.';
    final mapped = switch (reasonCode?.toUpperCase()) {
      'NO_FACE_DETECTED' => 'Không phát hiện khuôn mặt.',
      'MULTIPLE_FACES_DETECTED' => 'Ảnh có nhiều hơn 1 khuôn mặt.',
      'MIME_MISMATCH' => 'File sai định dạng/nội dung.',
      'IMAGE_TOO_LARGE' => 'Ảnh quá 5MB.',
      _ => message ?? 'Ảnh chưa đạt yêu cầu đăng ký.',
    };
    return mapped;
  }
}

class FaceValidationResponse {
  final bool canEnroll;
  final List<FaceValidationResult> results;
  final String? message;
  final bool validationUnavailable;
  final Map<String, dynamic> raw;

  const FaceValidationResponse({
    required this.canEnroll,
    required this.results,
    this.message,
    this.validationUnavailable = false,
    this.raw = const {},
  });

  factory FaceValidationResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] ?? json['files'] ?? json['items'];
    final results = rawResults is List
        ? rawResults
              .asMap()
              .entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => FaceValidationResult.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                  fallbackIndex: entry.key,
                ),
              )
              .toList()
        : <FaceValidationResult>[];
    final rawCanEnroll = json['canEnroll'] ?? json['isEnrollable'];
    final inferredCanEnroll =
        results.isNotEmpty && results.every((result) => result.passed);
    return FaceValidationResponse(
      canEnroll: rawCanEnroll is bool ? rawCanEnroll : inferredCanEnroll,
      results: results,
      message: (json['message'] ?? json['summary'])?.toString(),
      raw: json,
    );
  }

  String get displayMessage {
    if (canEnroll) {
      return message ??
          (validationUnavailable
              ? 'Chưa kiểm tra được ảnh. Vẫn có thể đăng ký bằng API enroll hiện tại.'
              : 'Ảnh đạt yêu cầu. Có thể đăng ký Face Profile.');
    }
    final failed = results.where((result) => !result.passed).toList();
    if (failed.isEmpty) {
      return message ?? 'Ảnh chưa đạt yêu cầu đăng ký.';
    }
    return failed
        .map((result) => 'Ảnh ${result.index + 1}: ${result.displayMessage}')
        .join('\n');
  }

  factory FaceValidationResponse.unavailable([String? message]) =>
      FaceValidationResponse(
        canEnroll: true,
        results: const [],
        message: message,
        validationUnavailable: true,
      );
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

  /// Tải trạng thái hồ sơ khuôn mặt của 1 thành viên mà KHÔNG đụng state chung
  /// (`profile`). Dùng cho lưới Thành viên cần nhiều hồ sơ song song.
  Future<FaceProfile> load(String memberId) async {
    try {
      final data = await ApiClient.instance.get(
        '/families/$_fid/face-profiles/$memberId',
      );
      return FaceProfile.fromJson(
        memberId,
        data is Map ? Map<String, dynamic>.from(data) : const {},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return FaceProfile(
          memberId: memberId,
          status: FaceProfileStatus.notEnrolled,
        );
      }
      rethrow;
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

  Future<FaceValidationResponse> validate(
    String memberId,
    List<String> imagePaths,
  ) async {
    if (imagePaths.length < 3 || imagePaths.length > 5) {
      throw ArgumentError('Chọn từ 3 đến 5 ảnh rõ mặt.');
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.uploadFiles(
        path: '/families/$_fid/face-profiles/$memberId/validate',
        filePaths: imagePaths,
      );
      return FaceValidationResponse.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 501) {
        return FaceValidationResponse.unavailable(
          'BE chưa bật API kiểm tra ảnh. FE sẽ dùng luồng đăng ký hiện tại.',
        );
      }
      rethrow;
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
