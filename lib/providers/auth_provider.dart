import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

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

  // true ngay sau register() (tài khoản mới luôn chưa verify) hoặc khi
  // POST /families trả 403 "Account not verified" (tài khoản cũ đăng nhập
  // lại nhưng chưa từng verify) — router dùng để chặn vào /family-setup cho
  // tới khi verifyEmail() thành công. Không dựa vào field nào từ /auth/me vì
  // BE không document schema response — xử lý theo sự kiện chắc chắn hơn.
  bool _pendingEmailVerification = false;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get hasFamily => _user?.familyId != null;
  bool get restoring => _restoring;
  String? get pendingInviteToken => _pendingInviteToken;
  bool get pendingEmailVerification => _pendingEmailVerification;

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
    // Tài khoản vừa tạo luôn chưa verify — BE gửi OTP 6 số qua email ngay
    // sau register (xem AuthController_register / verify-email trong Swagger).
    _pendingEmailVerification = true;
    notifyListeners();
  }

  // POST /auth/verify-email — xác thực tài khoản bằng OTP 6 số gửi qua email
  Future<void> verifyEmail(String code) async {
    await ApiClient.instance.post('/auth/verify-email', {'code': code});
    _pendingEmailVerification = false;
    notifyListeners();
  }

  // POST /auth/resend-verification — gửi lại OTP (BE rate-limit, có thể trả
  // 400 "Already verified or resend on cooldown")
  Future<void> resendVerificationCode() async {
    await ApiClient.instance.post('/auth/resend-verification', {});
  }

  // POST /families — tạo gia đình mới, creator thành MANAGER
  Future<void> createFamily(String name) async {
    Map<String, dynamic> family;
    try {
      family = await ApiClient.instance.post('/families', {
        'name': name.trim(),
      });
    } on ApiException catch (e) {
      // 403 = "Account not verified" theo Swagger — đây là lý do 403 DUY NHẤT
      // được document cho POST /families, nên tin thẳng statusCode. Message
      // thật từ BE là tiếng Việt ("Vui lòng xác thực tài khoản để dùng chức
      // năng này"), KHÔNG chứa "verif" — check theo message tiếng Anh trước
      // đó không bao giờ khớp → pendingEmailVerification không được set →
      // router (mandatory) không redirect sang /verify-email → luồng bắt buộc
      // xác thực hỏng. Fix bằng kịch bản thật 2026-07-08.
      if (e.statusCode == 403) {
        _pendingEmailVerification = true;
        notifyListeners();
      }
      rethrow;
    }
    final fid = family['id']?.toString() ?? family['family']?['id']?.toString();
    if (fid == null) throw Exception('Không lấy được ID gia đình');
    ApiClient.instance.setFamilyId(fid);
    _user = AppUser.fromJson(
      {
        'id': _user!.id,
        'fullName': _user!.name,
        'email': _user!.email,
        'userType': _user!.userType,
      },
      accessToken: _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId: fid,
      familyName: name.trim(),
      familyRole: 'FAMILY_MANAGER',
    );
    notifyListeners();
  }

  // Đăng ký callbacks vào ApiClient: token rotation + force logout
  void _registerApiClientCallbacks() {
    ApiClient.instance.onTokenRotated = (newAccess, newRefresh) {
      _persistTokens(newAccess, newRefresh);
      if (_user == null) return;
      _user = AppUser.fromJson(
        {
          'id': _user!.id,
          'fullName': _user!.name,
          'email': _user!.email,
          'userType': _user!.userType,
        },
        accessToken: newAccess,
        refreshToken: newRefresh,
        familyId: _user!.familyId,
        familyName: _user!.familyName,
        familyRole: _user!.familyRoleString,
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
      if (familyId == null) return const _FamilyContext();

      // ⚠️ BE bug: /families/my VẪN trả gia đình mà user đã bị xoá
      // (status REMOVED) — không lọc. Xác thực tư cách thành viên còn hiệu
      // lực bằng /families/{id}: BE trả 403 "không còn hoạt động" nếu đã bị
      // xoá → coi như user CHƯA có gia đình để router đưa về /family-setup.
      Map<String, dynamic>? detail;
      try {
        final d = await ApiClient.instance.get('/families/$familyId');
        detail = d is Map ? Map<String, dynamic>.from(d) : null;
      } on ApiException catch (e) {
        if (e.statusCode == 403) {
          debugPrint('AuthProvider: membership REMOVED → no family');
          return const _FamilyContext();
        }
        // Lỗi khác (mạng/500) → giữ family từ /families/my để tránh đá nhầm
        // người dùng hợp lệ ra khỏi gia đình khi server tạm lỗi.
        debugPrint(
          'AuthProvider: family detail check failed (${e.statusCode}): $e',
        );
      }

      // Lấy role: ưu tiên từ detail (chính xác), fallback /families/my.
      String? familyRole;
      if (detail != null) {
        final dMems = (detail['members'] as List? ?? []);
        final me = dMems.whereType<Map>().firstWhere(
          (m) =>
              m['userId']?.toString() == myId ||
              m['user']?['id']?.toString() == myId,
          orElse: () => {},
        );
        // Nếu tìm thấy nhưng status không ACTIVE → cũng coi như không còn.
        final st = me['status']?.toString().toUpperCase();
        if (st != null && st.isNotEmpty && st != 'ACTIVE') {
          return const _FamilyContext();
        }
        familyRole = me['familyRole']?.toString() ?? me['role']?.toString();
      }

      familyRole ??=
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
        familyRole: _user!.familyRoleString,
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
    double? expectedSharedContribution,
    double? actualSharedContribution,
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
      'expectedSharedContribution': ?expectedSharedContribution,
      'actualSharedContribution': ?actualSharedContribution,
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
    // Hủy FCM token TRƯỚC khi xóa session (cần access token để gọi DELETE) —
    // nếu không, máy dùng chung sẽ nhận push của tài khoản cũ.
    await PushService.instance.unregister();
    // Xóa session ngay lập tức — không đợi server response
    _user = null;
    _pendingEmailVerification = false;
    // Token mời đang treo là của phiên cũ — bỏ luôn, nếu giữ thì tài khoản
    // đăng nhập sau bị đẩy nhầm về màn Tham gia gia đình.
    await clearPendingInviteToken();
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
      {
        'id': _user!.id,
        'fullName': _user!.name,
        'email': _user!.email,
        'userType': _user!.userType,
      },
      accessToken: _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId: ctx.id,
      familyName: ctx.name ?? '',
      familyRole: ctx.role,
    );
    notifyListeners();
  }
}
