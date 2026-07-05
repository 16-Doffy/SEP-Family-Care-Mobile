import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_client.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kFamilyRole  = 'family_role';
const _kActiveFamilyId = 'active_family_id';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _initializing = true;
  String? _pendingInviteToken;
  bool _verificationSkipped = false;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get initializing => _initializing;
  String? get familyId => _user?.familyId;
  String? get pendingInviteToken => _pendingInviteToken;

  /// UC10 — true khi tài khoản chưa verify email và user chưa chọn "bỏ qua"
  bool get needsVerification =>
      _user != null && !_user!.isEmailVerified && !_verificationSkipped;

  void skipVerification() {
    _verificationSkipped = true;
    notifyListeners();
  }

  void setPendingInvite(String token) => _pendingInviteToken = token;

  void clearPendingInvite() {
    _pendingInviteToken = null;
    notifyListeners();
  }

  Future<void> setActiveFamily(
    String familyId, {
    String? familyName,
    bool syncRole = true,
  }) async {
    if (_user == null || familyId.isEmpty) return;
    _user = _user!.copyWith(familyId: familyId, familyName: familyName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveFamilyId, familyId);
    if (syncRole) {
      await _syncRoleFromMembers(familyId);
    }
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
        await _fetchAndSetFamily();
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
    if ((_user?.familyId == null || _user!.familyId!.isEmpty) &&
        familyName.trim().isNotEmpty) {
      try {
        final family = await ApiClient.instance.post('/families', {
          'name': familyName.trim(),
        });
        if (family is Map) {
          final id = family['id']?.toString() ?? '';
          final name = family['name']?.toString() ?? familyName.trim();
          if (id.isNotEmpty && _user != null) {
            _user = _user!.copyWith(
              familyId: id,
              familyName: name,
              role: UserRole.manager,
            );
            await setFamilyRole(UserRole.manager);
          }
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    _verificationSkipped = false;
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

    await _fetchAndSetFamily();

    notifyListeners();
  }

  // Lấy familyId từ /families/my khi auth/me không embed familyMember
  Future<void> _fetchAndSetFamily() async {
    try {
      final list = await ApiClient.instance.get('/families/my');
      if (list is List && list.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final activeFamilyId = prefs.getString(_kActiveFamilyId);
        final currentFamilyId = _user?.familyId;
        Map<String, dynamic>? selected;
        final families = list
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();

        for (final family in families) {
          final id = family['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final role = await _familyRoleForCurrentUser(id);
          if (role == UserRole.member || role == UserRole.deputy) {
            selected = family;
            break;
          }
        }
        if (selected == null) {
          selected = families.firstWhere(
            (family) => family['id']?.toString() == activeFamilyId,
            orElse: () => families.firstWhere(
              (family) => family['id']?.toString() == currentFamilyId,
              orElse: () => families.first,
            ),
          );
        }

        final id   = selected['id']?.toString();
        final name = selected['name']?.toString() ?? '';
        if (id != null) {
          _user = _user!.copyWith(familyId: id, familyName: name);
          await prefs.setString(_kActiveFamilyId, id);
          await _syncRoleFromMembers(id);
        }
      } else if (_user?.familyId != null) {
        await _syncRoleFromMembers(_user!.familyId!);
      }
    } catch (_) {}
  }

  Future<UserRole?> _familyRoleForCurrentUser(String familyId) async {
    try {
      final data = await ApiClient.instance.get('/families/$familyId');
      if (data is! Map<String, dynamic>) return null;
      final rawMembers = data['members'] as List<dynamic>? ?? [];
      final currentId = _user?.id;
      for (final raw in rawMembers) {
        final m = raw as Map<String, dynamic>? ?? {};
        final uid = m['userId']?.toString() ??
            (m['user'] as Map?)?['id']?.toString() ??
            '';
        if (uid != currentId) continue;

        final roleStr = (m['familyRole'] as String? ?? '').toUpperCase();
        if (roleStr.contains('MANAGER')) return UserRole.manager;
        if (roleStr.contains('DEPUTY')) return UserRole.deputy;
        return UserRole.member;
      }
    } catch (_) {}
    return null;
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

      _user = _user!.copyWith(role: UserRole.member);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFamilyRole);
    } catch (_) {
      _user = _user?.copyWith(role: UserRole.member);
    }
  }

  // ─── Email verification (UC10) ─────────────────────────────────────────────

  /// POST /auth/verify-email với OTP 6 số; refresh lại /auth/me để cập nhật trạng thái
  Future<void> verifyEmail(String code) async {
    await ApiClient.instance.post('/auth/verify-email', {'code': code.trim()});
    _user = _user?.copyWith(verificationStatus: 'VERIFIED');
    try {
      final data = await ApiClient.instance.get('/auth/me');
      if (data is Map<String, dynamic> && _user != null) {
        _user = _user!.copyWith(
          verificationStatus:
              data['verificationStatus']?.toString().toUpperCase() ?? 'VERIFIED',
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  /// POST /auth/resend-verification — BE rate-limit, lỗi 400 khi cooldown
  Future<void> resendVerification() async {
    await ApiClient.instance.post('/auth/resend-verification', null);
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
    _verificationSkipped = false;
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
    await prefs.remove(_kActiveFamilyId);
  }
}
