import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_client.dart';

const _kAccessToken  = 'access_token';
const _kRefreshToken = 'refresh_token';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _initializing = true;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get initializing => _initializing;
  String? get familyId => _user?.familyId;

  AuthProvider() {
    _restoreSession();
  }

  // Try to restore session from persisted tokens
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access  = prefs.getString(_kAccessToken);
      final refresh = prefs.getString(_kRefreshToken);
      if (access != null) {
        ApiClient.instance.setToken(access);
        ApiClient.instance.setRefreshToken(refresh);
        final data = await ApiClient.instance.get('/auth/me');
        if (data is Map<String, dynamic>) {
          _user = AppUser.fromJson(data, accessToken: access, refreshToken: refresh);
          // Fetch familyId if not embedded in auth/me response
          if (_user!.familyId == null) await _fetchAndSetFamily();
        }
      }
    } catch (_) {
      // Tokens expired or invalid — clear and start fresh
      await _clearPersistedTokens();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    final data = await ApiClient.instance.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _applySession(data as Map<String, dynamic>);
  }

  Future<void> register(
    String email,
    String password,
    String fullName,
    String familyName, // kept for UI compat — BE doesn't use it at register time
  ) async {
    final data = await ApiClient.instance.post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
    });
    await _applySession(data as Map<String, dynamic>);
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final access  = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String? ?? '';
    ApiClient.instance.setToken(access);
    ApiClient.instance.setRefreshToken(refresh);

    _user = AppUser.fromJson(
      data['user'] as Map<String, dynamic>? ?? data,
      accessToken: access,
      refreshToken: refresh,
    );

    await _persistTokens(access, refresh);

    // Fetch familyId if not embedded in response
    if (_user!.familyId == null) await _fetchAndSetFamily();

    notifyListeners();
  }

  Future<void> _fetchAndSetFamily() async {
    try {
      final list = await ApiClient.instance.get('/families/my');
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final id   = first['id']?.toString();
        final name = first['name']?.toString() ?? '';
        if (id != null) {
          _user = _user!.copyWith(familyId: id, familyName: name);
        }
      }
    } catch (_) {
      // No family yet — user may need to create or join one
    }
  }

  Future<void> logout() async {
    try {
      final refresh = _user?.refreshToken;
      await ApiClient.instance.post('/auth/logout',
          refresh != null ? {'refreshToken': refresh} : null);
    } catch (_) {}
    _user = null;
    ApiClient.instance.setToken(null);
    ApiClient.instance.setRefreshToken(null);
    await _clearPersistedTokens();
    notifyListeners();
  }

  Future<void> _persistTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, access);
    if (refresh.isNotEmpty) await prefs.setString(_kRefreshToken, refresh);
  }

  Future<void> _clearPersistedTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  // Demo login — no API call, for offline/UI testing
  void loginDemo(UserRole role, String name, {String? familyName}) {
    _user = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      familyName: familyName ?? 'Nguyễn',
      role: role,
      avatarInitials:
          name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
      avatarColor: AppUser.colorForRole(role),
    );
    notifyListeners();
  }
}
