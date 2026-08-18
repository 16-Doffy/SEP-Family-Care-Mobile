import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const _kBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.familycare-digital.com/api/v1',
);

const _kRequestTimeout = Duration(seconds: 15);

/// Lỗi từ API kèm HTTP status code. `toString()` trả về đúng message của BE
/// nên code cũ dùng `e.toString().replaceFirst('Exception: ', '')` vẫn chạy.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final int? retryAfterSeconds;
  final int? cooldownSeconds;
  /// Dữ liệu lỗi có cấu trúc BE trả thêm (ví dụ quỹ khả dụng theo kỳ).
  ///
  /// Trước đây client chỉ giữ `code`/`message`, làm FE không thể dùng các field
  /// nghiệp vụ như `requestedAmount`, `availableAmount`, `periodMonth`,
  /// `periodYear` dù server đã gửi chúng.
  final Map<String, dynamic> details;

  const ApiException(
    this.statusCode,
    this.message, {
    this.code,
    this.retryAfterSeconds,
    this.cooldownSeconds,
    this.details = const {},
  });
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? _refreshToken;
  String? _familyId;

  // Refresh lock — tránh race condition khi nhiều request 401 cùng lúc
  bool _refreshing = false;
  Completer<bool>? _refreshCompleter;

  void Function(String newAccess, String newRefresh)? onTokenRotated;
  void Function()? onSessionExpired;
  void Function(String message)? onVerificationRequired;
  /// BE trả 403 kèm `code: "FEATURE_LOCKED"` khi gói hiện tại không có quyền
  /// dùng tính năng vừa gọi (xem đề xuất `DE_XUAT_BE_FEATUREACCESS_
  /// ENFORCEMENT_2026-08-18.md`). `featureKey` có thể null nếu BE chưa kịp
  /// trả field này — nơi lắng nghe (`family_shell`) vẫn hiện được dialog,
  /// chỉ là không biết chính xác quyền nào bị khoá để log/điều hướng riêng.
  void Function(String message, String? featureKey)? onFeatureLocked;

  void setToken(String? token) => _token = token;
  void setRefreshToken(String? token) => _refreshToken = token;
  void setFamilyId(String? id) => _familyId = id;

  String? get token => _token;
  String? get familyId => _familyId;

  /// Rotates the access token after a mutation changes its family claims.
  ///
  /// A new family changes `familyId` and `familyMemberId` on the server. They
  /// are embedded in the access token, therefore protected APIs must not keep
  /// authorizing the pre-creation token while the UI shows the new family.
  Future<bool> refreshSessionClaims() => _lockedRefresh();

  /// Origin của backend (bỏ `/api/v1`) — dùng cho namespace Socket.IO
  /// (`<origin>/notifications`, `<origin>/sos`). Vd
  /// `https://api.familycare-digital.com`.
  static String get origin => _kBase.replaceFirst(RegExp(r'/api/v\d+$'), '');

  /// Provider đăng ký để được dọn dữ liệu khi phiên kết thúc.
  ///
  /// Xóa token thôi là CHƯA đủ: các provider ở app scope (`main.dart`) sống
  /// suốt vòng đời app, nên dữ liệu của tài khoản trước vẫn nằm trong RAM và
  /// hiện ra cho tài khoản đăng nhập sau. Quan sát runtime 2026-08-07: đăng
  /// xuất Trưởng nhóm, đăng nhập Thành viên, màn Trợ lý AI vẫn hiện nguyên
  /// hội thoại của Trưởng nhóm — dù backend trả danh sách hội thoại RỖNG cho
  /// Thành viên (backend đúng, rò rỉ nằm ở phía app).
  ///
  /// Danh sách này ở cấp static và KHÔNG bị [clearSession] xóa: provider đăng
  /// ký một lần lúc khởi tạo và phải còn hiệu lực cho mọi lần đăng xuất sau.
  static final List<void Function()> _sessionResetListeners = [];

  static void addSessionResetListener(void Function() onReset) {
    _sessionResetListeners.add(onReset);
  }

  /// Clears cached provider data after switching family workspaces while
  /// keeping the authenticated token intact.
  void resetWorkspaceData() {
    for (final onReset in _sessionResetListeners) {
      try {
        onReset();
      } catch (e) {
        debugPrint('ApiClient: workspace reset listener failed: $e');
      }
    }
  }

  /// Xóa toàn bộ session data — gọi khi logout hoặc session expired
  void clearSession() {
    _token = null;
    _refreshToken = null;
    _familyId = null;
    onTokenRotated = null;
    onSessionExpired = null;
    onVerificationRequired = null;
    onFeatureLocked = null;
    for (final onReset in _sessionResetListeners) {
      // Một provider dọn lỗi không được chặn các provider còn lại — sót một
      // cái là rò dữ liệu tài khoản cũ sang tài khoản mới.
      try {
        onReset();
      } catch (e) {
        debugPrint('ApiClient: session reset listener lỗi: $e');
      }
    }
  }

  String familyPath(String subPath) {
    assert(_familyId != null, 'familyId chưa được set');
    return '/families/$_familyId$subPath';
  }

  /// BE trả `fileUrl`/`thumbnailUrl` (proof ảnh task, avatar...) dạng path
  /// tương đối (`/uploads/xxx.jpg`) — ghép với origin của `_kBase` (bỏ
  /// `/api/v1`) để ra URL tải được. Nếu đã là URL tuyệt đối thì giữ nguyên.
  static String absoluteUrl(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final origin = _kBase.replaceFirst(RegExp(r'/api/v\d+$'), '');
    return value.startsWith('/') ? '$origin$value' : '$origin/$value';
  }

  /// ISO 8601 UTC có mili-giây và timezone `Z`. Chỉ dùng khi contract BE đã
  /// xác nhận nhận UTC thật cho field tương ứng.
  static String utcIsoMs([DateTime? at]) {
    final d = (at ?? DateTime.now()).toUtc();
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}'
        'T${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${p(d.millisecond, 3)}Z';
  }

  /// ISO 8601 mili-giây + 'Z' theo GIỜ ĐỊA PHƯƠNG (compat flow cũ).
  /// Không đổi semantic này nếu BE chưa xác nhận migration sang UTC thật.
  static String localIsoMs([DateTime? at]) {
    final d = at ?? DateTime.now();
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}'
        'T${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${p(d.millisecond, 3)}Z';
  }

  // ── HTTP methods ─────────────────────────────────────────────────────────

  /// POST — trả Map (body thực), hoặc {} nếu 204 No Content
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await _send(
      () => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postWithTimeout(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    final r = await _send(
      () => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)),
      timeout: timeout,
    );
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  /// PATCH — trả Map hoặc {}
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await _send(
      () => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  /// PUT — trả Map hoặc {}
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await _send(
      () => http.put(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  Future<dynamic> get(String path) =>
      _send(() => http.get(_uri(path), headers: _headers()));

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) => _send(
    () => http.delete(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  /// Upload file dạng multipart/form-data — dùng cho task proofs, avatar, v.v.
  /// [queryParams] gắn vào URL (ví dụ ?proofType=IMAGE)
  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required String filePath,
    String fieldName = 'file',
    Map<String, String>? queryParams,
    Map<String, String>? fields,
    String? mimeType, // ví dụ 'image/jpeg'
  }) async {
    Future<http.Response> doUpload() async {
      final uri = _uri(path).replace(queryParameters: queryParams);
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      if (fields != null && fields.isNotEmpty) request.fields.addAll(fields);
      // Không truyền contentType thì http gửi application/octet-stream và BE
      // trả "Định dạng file minh chứng không được hỗ trợ" — phải đoán từ đuôi
      // file (verified live: octet-stream bị 400, image/png pass).
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          contentType: MediaType.parse(mimeType ?? _guessMimeType(filePath)),
        ),
      );
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    final r = await _send(doUpload);
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  /// Upload nhiều file trong cùng một multipart request. Dùng cho các contract
  /// yêu cầu mảng binary, ví dụ Face Profile `files[]` (3–5 ảnh). Không dùng
  /// vòng lặp upload đơn lẻ vì BE chỉ bắt đầu enroll khi nhận đủ mảng files.
  Future<Map<String, dynamic>> uploadFiles({
    required String path,
    required List<String> filePaths,
    String fieldName = 'files',
    Map<String, String>? fields,
    List<String?>? mimeTypes,
    Duration timeout = _kRequestTimeout,
  }) async {
    if (filePaths.isEmpty) {
      throw ArgumentError.value(
        filePaths,
        'filePaths',
        'Phải có ít nhất một file',
      );
    }
    Future<http.Response> doUpload() async {
      final request = http.MultipartRequest('POST', _uri(path));
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      if (fields != null && fields.isNotEmpty) request.fields.addAll(fields);
      for (var i = 0; i < filePaths.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            filePaths[i],
            contentType: MediaType.parse(
              mimeTypes != null && i < mimeTypes.length && mimeTypes[i] != null
                  ? mimeTypes[i]!
                  : _guessMimeType(filePaths[i]),
            ),
          ),
        );
      }
      return http.Response.fromStream(await request.send());
    }

    final result = await _send(doUpload, timeout: timeout);
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  static String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'bmp' => 'image/bmp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<http.Response> _withTimeout(
    Future<http.Response> Function() fn,
    Duration timeout,
  ) async {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      throw Exception(
        'Kết nối đến server quá lâu, vui lòng kiểm tra mạng và thử lại.',
      );
    } on http.ClientException {
      throw Exception('Không thể kết nối đến server, vui lòng kiểm tra mạng.');
    }
  }

  Uri _uri(String path) => Uri.parse('$_kBase$path');

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(
    Future<http.Response> Function() fn, {
    Duration timeout = _kRequestTimeout,
  }) async {
    var response = await _withTimeout(fn, timeout);

    // ── Auto-refresh on 401 (với lock tránh race condition) ───────────────
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _lockedRefresh();
      if (refreshed) {
        response = await _withTimeout(fn, timeout); // retry với token mới
      } else {
        onSessionExpired?.call();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
    }

    // ── 204 No Content ────────────────────────────────────────────────────
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          'Request failed (${response.statusCode})',
        );
      }
      return <String, dynamic>{};
    }

    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      final bodyMap = body is Map ? Map<String, dynamic>.from(body) : null;
      final details = _errorDetails(bodyMap);
      final msg = body is Map
          ? (body['message'] is List
                ? (body['message'] as List).join(', ')
                : body['message']?.toString() ?? body['error']?.toString())
          : null;
      final message = msg ?? 'Request failed (${response.statusCode})';
      if (response.statusCode == 403 && _isVerificationRequired(message)) {
        onVerificationRequired?.call(message);
      }
      final code =
          (bodyMap?['code'] ??
                  bodyMap?['errorCode'] ??
                  details?['code'] ??
                  details?['errorCode'])
              ?.toString();
      if (response.statusCode == 403 && code == 'FEATURE_LOCKED') {
        final featureKey =
            (bodyMap?['featureKey'] ?? details?['featureKey'])?.toString();
        onFeatureLocked?.call(message, featureKey);
      }
      final retryAfterSeconds = _intValue(
        bodyMap?['retryAfterSeconds'] ??
            details?['retryAfterSeconds'] ??
            response.headers['retry-after'],
      );
      final cooldownSeconds = _intValue(
        bodyMap?['cooldownSeconds'] ?? details?['cooldownSeconds'],
      );
      // Giữ cả cấp envelope và khối details/data. Khối lồng ưu tiên vì đó là
      // nơi BE đặt thông tin nghiệp vụ cụ thể cho từng error code.
      final errorFields = <String, dynamic>{
        if (bodyMap != null) ...bodyMap,
        if (details != null) ...details,
      };
      throw ApiException(
        response.statusCode,
        message,
        code: code,
        retryAfterSeconds: retryAfterSeconds,
        cooldownSeconds: cooldownSeconds,
        details: errorFields,
      );
    }

    // Unwrap { success, data }
    if (body is Map &&
        body.containsKey('success') &&
        body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  Map<String, dynamic>? _errorDetails(Map<String, dynamic>? body) {
    if (body == null) return null;
    for (final key in const ['data', 'details', 'error']) {
      final value = body[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isVerificationRequired(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('verify') ||
        normalized.contains('verified') ||
        normalized.contains('verification') ||
        normalized.contains('xác thực') ||
        normalized.contains('xac thuc');
  }

  // Bọc jsonDecode để tránh FormatException thô lọt ra UI khi server/proxy
  // trả về non-JSON (trang lỗi HTML khi gateway timeout, redirect, maintenance...)
  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      final preview = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      debugPrint(
        'ApiClient: invalid JSON response '
        '(${response.statusCode}) from ${response.request?.url}: '
        '${preview.length > 200 ? '${preview.substring(0, 200)}...' : preview}',
      );
      throw Exception(
        'Server trả dữ liệu không đúng định dạng JSON '
        '(${response.statusCode}). Vui lòng kiểm tra kết nối hoặc thử lại sau.',
      );
    }
  }

  /// Refresh lock: nếu refresh đang chạy, các caller khác đợi kết quả đó
  Future<bool> _lockedRefresh() async {
    if (_refreshing) {
      // Đợi refresh đang chạy hoàn tất
      return _refreshCompleter!.future;
    }
    _refreshing = true;
    _refreshCompleter = Completer<bool>();
    final result = await _tryRefresh();
    _refreshCompleter!.complete(result);
    _refreshing = false;
    _refreshCompleter = null;
    return result;
  }

  Future<bool> _tryRefresh() async {
    try {
      final res = await http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      final data = (body is Map && body.containsKey('data'))
          ? body['data']
          : body;
      final newAccess = data['accessToken']?.toString();
      final newRefresh = data['refreshToken']?.toString();
      if (newAccess == null) return false;
      _token = newAccess;
      _refreshToken = newRefresh ?? _refreshToken;
      onTokenRotated?.call(newAccess, newRefresh ?? _refreshToken!);
      return true;
    } catch (e) {
      debugPrint('ApiClient: refresh token failed: $e');
      return false;
    }
  }
}
