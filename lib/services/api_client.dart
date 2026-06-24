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
  const ApiException(this.statusCode, this.message);
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
  bool              _refreshing       = false;
  Completer<bool>?  _refreshCompleter;

  void Function(String newAccess, String newRefresh)? onTokenRotated;
  void Function()? onSessionExpired;

  void setToken(String? token)        => _token        = token;
  void setRefreshToken(String? token) => _refreshToken = token;
  void setFamilyId(String? id)        => _familyId     = id;

  String? get token    => _token;
  String? get familyId => _familyId;

  /// Xóa toàn bộ session data — gọi khi logout hoặc session expired
  void clearSession() {
    _token        = null;
    _refreshToken = null;
    _familyId     = null;
    onTokenRotated   = null;
    onSessionExpired = null;
  }

  String familyPath(String subPath) {
    assert(_familyId != null, 'familyId chưa được set');
    return '/families/$_familyId$subPath';
  }

  // ── HTTP methods ─────────────────────────────────────────────────────────

  /// POST — trả Map (body thực), hoặc {} nếu 204 No Content
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await _send(
        () => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)));
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  /// PATCH — trả Map hoặc {}
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final r = await _send(
        () => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)));
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  /// PUT — trả Map hoặc {}
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final r = await _send(
        () => http.put(_uri(path), headers: _headers(), body: jsonEncode(body)));
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  Future<dynamic> get(String path) =>
      _send(() => http.get(_uri(path), headers: _headers()));

  Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers()));

  /// Upload file dạng multipart/form-data — dùng cho task proofs, avatar, v.v.
  /// [queryParams] gắn vào URL (ví dụ ?proofType=IMAGE)
  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required String filePath,
    String fieldName = 'file',
    Map<String, String>? queryParams,
    String? mimeType, // ví dụ 'image/jpeg'
  }) async {
    Future<http.Response> doUpload() async {
      final uri = _uri(path).replace(queryParameters: queryParams);
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }
    final r = await _send(doUpload);
    return r is Map<String, dynamic> ? r : <String, dynamic>{};
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<http.Response> _withTimeout(Future<http.Response> Function() fn) async {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      throw Exception('Kết nối đến server quá lâu, vui lòng kiểm tra mạng và thử lại.');
    } on http.ClientException {
      throw Exception('Không thể kết nối đến server, vui lòng kiểm tra mạng.');
    }
  }

  Uri _uri(String path) => Uri.parse('$_kBase$path');

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    var response = await _withTimeout(fn);

    // ── Auto-refresh on 401 (với lock tránh race condition) ───────────────
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _lockedRefresh();
      if (refreshed) {
        response = await _withTimeout(fn); // retry với token mới
      } else {
        onSessionExpired?.call();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
    }

    // ── 204 No Content ────────────────────────────────────────────────────
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException(response.statusCode, 'Request failed (${response.statusCode})');
      }
      return <String, dynamic>{};
    }

    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      final msg = body is Map
          ? (body['message'] is List
              ? (body['message'] as List).join(', ')
              : body['message']?.toString() ?? body['error']?.toString())
          : null;
      throw ApiException(response.statusCode, msg ?? 'Request failed (${response.statusCode})');
    }

    // Unwrap { success, data }
    if (body is Map && body.containsKey('success') && body.containsKey('data')) {
      return body['data'];
    }
    return body;
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
    _refreshing       = true;
    _refreshCompleter = Completer<bool>();
    final result = await _tryRefresh();
    _refreshCompleter!.complete(result);
    _refreshing       = false;
    _refreshCompleter = null;
    return result;
  }

  Future<bool> _tryRefresh() async {
    try {
      final res = await http.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(_kRequestTimeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      final data = (body is Map && body.containsKey('data')) ? body['data'] : body;
      final newAccess  = data['accessToken']?.toString();
      final newRefresh = data['refreshToken']?.toString();
      if (newAccess == null) return false;
      _token        = newAccess;
      _refreshToken = newRefresh ?? _refreshToken;
      onTokenRotated?.call(newAccess, newRefresh ?? _refreshToken!);
      return true;
    } catch (e) {
      debugPrint('ApiClient: refresh token failed: $e');
      return false;
    }
  }
}
