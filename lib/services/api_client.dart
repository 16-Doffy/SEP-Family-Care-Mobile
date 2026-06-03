import 'dart:convert';
import 'package:http/http.dart' as http;

const _kBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api',
);

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      await _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async =>
      await _send(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)))
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
      final message = body is Map ? body['message'] ?? body['error'] : 'Request failed';
      throw Exception(message);
    }
    return body;
  }
}
