import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_client.dart';

class _FamilyContext {
  final String? id;
  final String? name;
  final String? role;
  const _FamilyContext({this.id, this.name, this.role});
}

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kPendingInviteTokenKey = 'pending_invite_token';

  AppUser? _user;

  // true trong lúc đang khôi phục session đã lưu khi mở app — router dùng để
  // giữ màn splash, tránh nháy về /login rồi mới vào lại home.
  bool _restoring = true;

  // Token lời mời gia đình (deeplink /join?token=...) đang chờ — lưu lại khi
  // người dùng mở link mà chưa đăng nhập, để không mất token sau khi
  // login/register xong (sống sót qua cả cold-start nhờ secure storage).
  String? _pendingInviteToken;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get hasFamily => _user?.familyId != null;
  bool get restoring => _restoring;
  String? get pendingInviteToken => _pendingInviteToken;

  Future<void> savePendingInviteToken(String token) async {
    _pendingInviteToken = token;
    try {
      await _storage.write(key: _kPendingInviteTokenKey, value: token);
    } catch (e) {
      debugPrint('AuthProvider: save pending invite token failed: $e');
    }
  }

  Future<void> clearPendingInviteToken() async {
    _pendingInviteToken = null;
    try {
      await _storage.delete(key: _kPendingInviteTokenKey);
    } catch (e) {
      debugPrint('AuthProvider: clear pending invite token failed: $e');
    }
  }

  // Chỉ dùng trong test — set state trực tiếp, không gọi API.
  @visibleForTesting
  void debugSetState({AppUser? user, bool restoring = false}) {
    _user = user;
    _restoring = restoring;
    notifyListeners();
  }

  // POST /auth/login
  Future<void> signIn(String email, String password) async {
    final data = await ApiClient.instance.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _applySession(data);
  }

  // POST /auth/register — app yêu cầu đủ { email, password, fullName, phone }
  // Không tự tạo gia đình — user sẽ chọn tạo mới hoặc join ở FamilySetupScreen
  Future<void> register(
    String email,
    String password,
    String fullName, {
    required String phone,
  }) async {
    final data = await ApiClient.instance.post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
    });
    await _applySession(data);
  }

  // POST /families — tạo gia đình mới, creator thành MANAGER
  Future<void> createFamily(String name) async {
    final family = await ApiClient.instance.post('/families', {
      'name': name.trim(),
    });
    final fid = family['id']?.toString() ?? family['family']?['id']?.toString();
    if (fid == null) throw Exception('Không lấy được ID gia đình');
    ApiClient.instance.setFamilyId(fid);
    _user = AppUser.fromJson(
      {'id': _user!.id, 'fullName': _user!.name, 'email': _user!.email},
      accessToken: _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId: fid,
      familyName: name.trim(),
      familyRole: 'MANAGER',
    );
    notifyListeners();
  }

  // Đăng ký callbacks vào ApiClient: token rotation + force logout
  void _registerApiClientCallbacks() {
    ApiClient.instance.onTokenRotated = (newAccess, newRefresh) {
      _persistTokens(newAccess, newRefresh);
      if (_user == null) return;
      _user = AppUser.fromJson(
        {'id': _user!.id, 'fullName': _user!.name, 'email': _user!.email},
        accessToken: newAccess,
        refreshToken: newRefresh,
        familyId: _user!.familyId,
        familyName: _user!.familyName,
        familyRole: _user!.role.name.toUpperCase(),
        phone: _user!.phone,
      );
      notifyListeners();
    };
    ApiClient.instance.onSessionExpired = () {
      _user = null;
      ApiClient.instance.clearSession();
      _clearStoredTokens();
      notifyListeners();
    };
  }

  // Khôi phục session đã lưu khi mở lại app (token không còn nằm trong RAM
  // sau khi OS kill app) — gọi 1 lần ở khởi động app.
  Future<void> tryRestoreSession() async {
    try {
      _pendingInviteToken = await _storage.read(key: _kPendingInviteTokenKey);
    } catch (e) {
      debugPrint('AuthProvider: load pending invite token failed: $e');
    }
    try {
      final access = await _storage.read(key: _kAccessTokenKey);
      final refresh = await _storage.read(key: _kRefreshTokenKey);
      if (access == null || access.isEmpty) {
        _restoring = false;
        notifyListeners();
        return;
      }

      ApiClient.instance.setToken(access);
      ApiClient.instance.setRefreshToken(refresh);
      _registerApiClientCallbacks();

      final me = await ApiClient.instance.get('/auth/me');
      final userJson = me is Map
          ? me as Map<String, dynamic>
          : <String, dynamic>{};
      final myId = userJson['id']?.toString();

      final ctx = await _fetchFamilyContext(myId);
      if (ctx.id != null) ApiClient.instance.setFamilyId(ctx.id);

      _user = AppUser.fromJson(
        userJson,
        accessToken: access,
        refreshToken: refresh ?? '',
        familyId: ctx.id,
        familyName: ctx.name ?? '',
        familyRole: ctx.role,
        phone:
            userJson['phone']?.toString() ??
            userJson['phoneNumber']?.toString(),
      );
    } catch (e) {
      // Token hết hạn/không hợp lệ — xóa session, bắt đăng nhập lại
      debugPrint('AuthProvider: restore session failed: $e');
      ApiClient.instance.clearSession();
      await _clearStoredTokens();
      _user = null;
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> _persistTokens(String access, String refresh) async {
    try {
      await _storage.write(key: _kAccessTokenKey, value: access);
      await _storage.write(key: _kRefreshTokenKey, value: refresh);
    } catch (e) {
      debugPrint('AuthProvider: persist tokens failed: $e');
    }
  }

  Future<void> _clearStoredTokens() async {
    try {
      await _storage.delete(key: _kAccessTokenKey);
      await _storage.delete(key: _kRefreshTokenKey);
    } catch (e) {
      debugPrint('AuthProvider: clear tokens failed: $e');
    }
  }

  // Lấy familyId/familyName/familyRole của user hiện tại — dùng chung cho
  // login, restore session và refreshFamilyContext.
  Future<_FamilyContext> _fetchFamilyContext(String? myId) async {
    try {
      final families = await ApiClient.instance.get('/families/my');
      final list = families is List ? families : <dynamic>[];
      if (list.isEmpty) return const _FamilyContext();

      final f = list.first as Map<String, dynamic>;
      final familyId = f['id']?.toString();
      final familyName = f['name']?.toString();

      String? familyRole =
          f['currentMemberRole']?.toString() ??
          f['myRole']?.toString() ??
          f['userRole']?.toString() ??
          f['role']?.toString();

      if (familyRole == null) {
        final members = f['members'] as List? ?? [];
        final me = members.whereType<Map>().firstWhere(
          (m) =>
              m['userId']?.toString() == myId ||
              m['user']?['id']?.toString() == myId,
          orElse: () => {},
        );
        familyRole = me['familyRole']?.toString() ?? me['role']?.toString();
      }

      if ((familyRole == null || familyRole.isEmpty) && familyId != null) {
        try {
          final detail = await ApiClient.instance.get('/families/$familyId');
          final dMems = (detail['members'] as List? ?? []);
          final me = dMems.whereType<Map>().firstWhere(
            (m) =>
                m['userId']?.toString() == myId ||
                m['user']?['id']?.toString() == myId,
            orElse: () => {},
          );
          familyRole = me['familyRole']?.toString() ?? me['role']?.toString();
        } catch (e) {
          debugPrint('AuthProvider: fetch family detail failed: $e');
        }
      }

      return _FamilyContext(id: familyId, name: familyName, role: familyRole);
    } catch (e) {
      // User chưa có gia đình — vẫn để đăng nhập bình thường
      debugPrint('AuthProvider: fetch family context failed: $e');
      return const _FamilyContext();
    }
  }

  // Sau login/register: set token → gọi /families/my để lấy familyId + role trong gia đình
  Future<void> _applySession(Map<String, dynamic> data) async {
    // ApiClient đã unwrap { success, data } → data trực tiếp
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String? ?? '';
    ApiClient.instance.setToken(token);
    ApiClient.instance.setRefreshToken(refreshToken);
    _registerApiClientCallbacks();
    await _persistTokens(token, refreshToken);

    final userJson = data['user'] as Map<String, dynamic>? ?? data;
    final myId = userJson['id']?.toString();

    final ctx = await _fetchFamilyContext(myId);
    if (ctx.id != null) ApiClient.instance.setFamilyId(ctx.id);

    _user = AppUser.fromJson(
      userJson,
      accessToken: token,
      refreshToken: refreshToken,
      familyId: ctx.id,
      familyName: ctx.name ?? '',
      familyRole: ctx.role,
    );
    notifyListeners();
  }

  // GET /auth/me — refresh user profile (phone, name, etc.)
  Future<void> refreshMe() async {
    if (!isLoggedIn) return;
    try {
      final data = await ApiClient.instance.get('/auth/me');
      final userJson = data is Map
          ? data as Map<String, dynamic>
          : <String, dynamic>{};
      _user = AppUser.fromJson(
        userJson,
        accessToken: _user!.accessToken,
        refreshToken: _user!.refreshToken,
        familyId: _user!.familyId,
        familyName: _user!.familyName,
        familyRole: _user!.role.name.toUpperCase(),
        phone:
            userJson['phone']?.toString() ??
            userJson['phoneNumber']?.toString(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: refreshMe failed: $e');
    }
  }

  // POST or PUT /families/{id}/finance/monthly-finances/me
  Future<void> saveMonthlyFinance({
    required double expectedIncome,
    required double expectedExpense,
    String incomeVisibility = 'PRIVATE',
    String expenseVisibility = 'PRIVATE',
    String? note,
  }) async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    final now = DateTime.now();
    final body = {
      'periodMonth': now.month,
      'periodYear': now.year,
      'expectedIncome': expectedIncome,
      'expectedPersonalExpense': expectedExpense,
      'incomeVisibility': incomeVisibility,
      'expenseVisibility': expenseVisibility,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    // Try PUT first (update existing), fall back to POST (create)
    try {
      await ApiClient.instance.put(
        ApiClient.instance.familyPath('/finance/monthly-finances/me'),
        body,
      );
    } catch (e) {
      debugPrint(
        'AuthProvider: PUT monthly-finance failed, fallback to POST: $e',
      );
      await ApiClient.instance.post(
        ApiClient.instance.familyPath('/finance/monthly-finances/me'),
        body,
      );
    }
  }

  // POST /auth/logout
  Future<void> logout() async {
    final refreshToken = _user?.refreshToken;
    // Xóa session ngay lập tức — không đợi server response
    _user = null;
    ApiClient.instance.clearSession();
    await _clearStoredTokens();
    notifyListeners();
    // Thông báo server invalidate refresh token (best-effort)
    if (refreshToken != null) {
      try {
        await ApiClient.instance.post('/auth/logout', {
          'refreshToken': refreshToken,
        });
      } catch (e) {
        debugPrint('AuthProvider: server logout call failed: $e');
      }
    }
  }

  // Cập nhật familyId sau khi user tạo/join gia đình thành công
  Future<void> refreshFamilyContext() async {
    if (!isLoggedIn) return;
    final ctx = await _fetchFamilyContext(_user!.id);
    if (ctx.id == null) return;
    ApiClient.instance.setFamilyId(ctx.id);
    _user = AppUser.fromJson(
      {'id': _user!.id, 'fullName': _user!.name, 'email': _user!.email},
      accessToken: _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId: ctx.id,
      familyName: ctx.name ?? '',
      familyRole: ctx.role,
    );
    notifyListeners();
  }
}
