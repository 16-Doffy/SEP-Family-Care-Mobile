import 'dart:convert';
import 'package:http/http.dart' as http;

const _kBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://103.110.84.66/api/v1',
);

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? _refreshToken;

  void setToken(String? token) => _token = token;
  void setRefreshToken(String? token) => _refreshToken = token;
  String? get token => _token;

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) {
    final uri = _uri(path, params);
    return _sendWithRetry(() => http.get(uri, headers: _headers()));
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _sendWithRetry(() => http.post(_uri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _sendWithRetry(() => http.patch(_uri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _sendWithRetry(() => http.put(_uri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null));

  Future<dynamic> delete(String path) =>
      _sendWithRetry(() => http.delete(_uri(path), headers: _headers()));

  Future<dynamic> postMultipart(
    String path,
    List<int> bytes,
    String filename, {
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    if (fields != null) request.fields.addAll(fields);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? (body['message'] ?? body['error'] ?? 'Upload failed') : 'Upload failed';
      throw ApiException(message.toString(), response.statusCode);
    }
    return _unwrap(body);
  }

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$_kBase$path');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Unwrap BE envelope { success, message, data }
  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    final response = await fn();
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map
          ? (body['message'] ?? body['error'] ?? 'Request failed')
          : 'Request failed';
      throw ApiException(message.toString(), response.statusCode);
    }
    return _unwrap(body);
  }

  // Auto-retry once on 401 using refreshToken
  Future<dynamic> _sendWithRetry(Future<http.Response> Function() fn) async {
    try {
      return await _send(fn);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && _refreshToken != null) {
        await _doRefresh();
        return await _send(fn);
      }
      rethrow;
    }
  }

  Future<void> _doRefresh() async {
    final response = await http.post(
      _uri('/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );
    if (response.statusCode >= 400) {
      _token = null;
      _refreshToken = null;
      throw ApiException('Session expired', 401);
    }
    final body = _unwrap(jsonDecode(response.body));
    if (body is Map) {
      _token = body['accessToken'] as String?;
      if (body['refreshToken'] != null) {
        _refreshToken = body['refreshToken'] as String;
      }
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
