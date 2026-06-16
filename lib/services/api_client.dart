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
  String? _familyId;

  void setToken(String? token) => _token = token;
  void setFamilyId(String? id) => _familyId = id;

  String? get token => _token;
  String? get familyId => _familyId;

  // Tạo path có familyId prefix: /families/{id}/finance/...
  String familyPath(String subPath) {
    assert(_familyId != null, 'familyId chưa được set — gọi setFamilyId() sau login');
    return '/families/$_familyId$subPath';
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      await _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async =>
      await _send(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      await _send(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body)))
          as Map<String, dynamic>;

  Future<dynamic> get(String path) => _send(() => http.get(_uri(path), headers: _headers()));

  Future<dynamic> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers()));

  Uri _uri(String path) => Uri.parse('$_kBase$path');

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    final response = await fn();
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final msg = body is Map
          ? (body['message'] is List
              ? (body['message'] as List).join(', ')
              : body['message'] ?? body['error'])
          : 'Request failed (${response.statusCode})';
      throw Exception(msg);
    }
    // BE luôn bọc response trong { success, message, data }
    // Trả thẳng data để caller không cần unwrap
    if (body is Map && body.containsKey('success') && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}
