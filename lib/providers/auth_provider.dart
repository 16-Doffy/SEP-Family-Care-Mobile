import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_client.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kFamilyRole  = 'family_role';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _initializing = true;
  String? _pendingInviteToken;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get initializing => _initializing;
  String? get familyId => _user?.familyId;
  String? get pendingInviteToken => _pendingInviteToken;

  void setPendingInvite(String token) => _pendingInviteToken = token;

  void clearPendingInvite() {
    _pendingInviteToken = null;
    notifyListeners();
  }

  /// Gọi sau khi tạo gia đình hoặc accept invite — persist để survive refresh
  Future<void> setFamilyRole(UserRole role) async {
    if (_user == null) return;
    _user = _user!.copyWith(role: role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFamilyRole, role.name);
    notifyListeners();
  }

  AuthProvider() { _restoreSession(); }

  // ─── Session ───────────────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final access = prefs.getString(_kAccessToken);
      final refresh = prefs.getString(_kRefreshToken);
      if (access == null) return;

      ApiClient.instance.setToken(access);
      ApiClient.instance.setRefreshToken(refresh);

      final data = await ApiClient.instance.get('/auth/me');
      if (data is Map<String, dynamic>) {
        _user = AppUser.fromJson(data, accessToken: access, refreshToken: refresh);
        if (_user!.familyId == null) {
          await _fetchAndSetFamily();
        } else {
          // familyId có rồi — đồng bộ role từ members list
          await _syncRoleFromMembers(_user!.familyId!);
        }
      }
    } catch (_) {
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

  Future<void> register(String email, String password, String fullName, String familyName) async {
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

    if (_user!.familyId == null) {
      await _fetchAndSetFamily();
    } else {
      await _syncRoleFromMembers(_user!.familyId!);
    }

    notifyListeners();
  }

  // Lấy familyId từ /families/my khi auth/me không embed familyMember
  Future<void> _fetchAndSetFamily() async {
    try {
      final list = await ApiClient.instance.get('/families/my');
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final id   = first['id']?.toString();
        final name = first['name']?.toString() ?? '';
        if (id != null) {
          _user = _user!.copyWith(familyId: id, familyName: name);
          await _syncRoleFromMembers(id);
        }
      }
    } catch (_) {}
  }

  /// Fetch GET /families/{id} → tìm current user trong members → set role đúng
  Future<void> _syncRoleFromMembers(String fid) async {
    try {
      final data = await ApiClient.instance.get('/families/$fid');
      if (data is! Map<String, dynamic>) return;

      // Cập nhật familyName nếu chưa có
      final name = data['name'] as String?;
      if (name != null && (_user!.familyName.isEmpty)) {
        _user = _user!.copyWith(familyName: name);
      }

      final rawMembers = data['members'] as List<dynamic>? ?? [];
      final currentId  = _user?.id;

      for (final raw in rawMembers) {
        final m = raw as Map<String, dynamic>? ?? {};
        // userId có thể ở m['userId'] hoặc m['user']['id']
        final uid = m['userId']?.toString() ??
            (m['user'] as Map?)?['id']?.toString() ?? '';
        if (uid != currentId) continue;

        final roleStr = (m['familyRole'] as String? ?? '').toUpperCase();
        final role = roleStr.contains('MANAGER')
            ? UserRole.manager
            : roleStr.contains('DEPUTY')
                ? UserRole.deputy
                : UserRole.member;

        _user = _user!.copyWith(role: role);
        // Persist để survive browser refresh
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFamilyRole, role.name);
        return;
      }

      // Nếu không tìm thấy trong members (chưa join) → thử restore từ prefs
      final prefs     = await SharedPreferences.getInstance();
      final savedRole = prefs.getString(_kFamilyRole);
      if (savedRole != null && _user!.role == UserRole.member) {
        final r = UserRole.values.firstWhere(
          (r) => r.name == savedRole,
          orElse: () => UserRole.member,
        );
        _user = _user!.copyWith(role: r);
      }
    } catch (_) {
      // Fallback: restore role từ prefs
      try {
        final prefs     = await SharedPreferences.getInstance();
        final savedRole = prefs.getString(_kFamilyRole);
        if (savedRole != null && _user!.role == UserRole.member) {
          final r = UserRole.values.firstWhere(
            (r) => r.name == savedRole,
            orElse: () => UserRole.member,
          );
          _user = _user!.copyWith(role: r);
        }
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    try {
      final refresh = _user?.refreshToken;
      await ApiClient.instance.post(
        '/auth/logout',
        refresh != null ? {'refreshToken': refresh} : null,
      );
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
    await prefs.remove(_kFamilyRole);
  }
}
