import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

class _FamilyContext {
  final String? id;
  final String? name;
  final String? role;
  const _FamilyContext({this.id, this.name, this.role});
}

/// A workspace that the signed-in account currently belongs to.
///
/// The backend intentionally permits one account to belong to several family
/// workspaces.  This is therefore a local selection, not an inference from
/// response order or a claim embedded in the JWT.
class FamilyWorkspace {
  final String id;
  final String name;
  final String? role;

  const FamilyWorkspace({required this.id, required this.name, this.role});
}

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kPendingInviteTokenKey = 'pending_invite_token';
  static const _kCurrentFamilyIdKey = 'current_family_id';

  AppUser? _user;
  List<FamilyWorkspace> _workspaces = const [];
  bool _needsFamilySelection = false;

  // true trong lúc đang khôi phục session đã lưu khi mở app — router dùng để
  // giữ màn splash, tránh nháy về /login rồi mới vào lại home.
  bool _restoring = true;

  // Token lời mời gia đình (deeplink /join?token=...) đang chờ — lưu lại khi
  // người dùng mở link mà chưa đăng nhập, để không mất token sau khi
  // login/register xong (sống sót qua cả cold-start nhờ secure storage).
  String? _pendingInviteToken;

  // Người dùng đã chủ động bấm "Đăng nhập để gửi yêu cầu" ở `/join` TRƯỚC
  // khi bị bắt qua `/login` — nhớ lại ý định này để sau khi đăng nhập xong,
  // `JoinFamilyScreen` tự gửi yêu cầu tiếp luôn thay vì bắt bấm lại lần 2
  // cho cùng một hành động (verify UX 2026-08-19: nhập mã → bấm gửi → login
  // → phải bấm "Gửi yêu cầu tham gia" thêm lần nữa). Chỉ sống trong bộ nhớ —
  // không cần qua secure storage vì chỉ cần sống sót qua đúng 1 lượt điều
  // hướng /join → /login → /join trong cùng phiên app đang chạy, không cần
  // qua cold-start như `_pendingInviteToken`.
  bool _pendingInviteAutoSubmit = false;

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
  List<FamilyWorkspace> get workspaces => List.unmodifiable(_workspaces);

  /// True when the account has memberships but there is no valid local choice.
  /// The router sends the user to the picker instead of silently selecting the
  /// first family returned by GET /families/my.
  bool get needsFamilySelection => _needsFamilySelection;

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

  /// Đánh dấu ý định "đã bấm gửi yêu cầu tham gia" trước khi bị bắt đăng
  /// nhập. Gọi ĐÚNG một chỗ: `JoinFamilyScreen._submit()` khi chưa đăng
  /// nhập, ngay trước khi điều hướng sang `/login`.
  void markInviteAutoSubmitAfterLogin() {
    _pendingInviteAutoSubmit = true;
  }

  /// Đọc kèm xoá cờ ngay (one-shot) — chỉ tự gửi đúng một lần cho đúng lượt
  /// đăng nhập vừa rồi; mở lại `/join` sau đó (vd bấm nhầm rồi quay lại) sẽ
  /// KHÔNG tự gửi nữa, người dùng phải tự bấm như bình thường.
  bool consumePendingInviteAutoSubmit() {
    final value = _pendingInviteAutoSubmit;
    _pendingInviteAutoSubmit = false;
    return value;
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

  /// Wear OS claim token sau khi mobile đã pair mã FCW qua
  /// `POST /families/{familyId}/wearables`.
  Future<void> claimWearableActivation(String sessionId) async {
    final clean = sessionId.trim();
    if (clean.isEmpty) throw Exception('Thiếu phiên ghép đồng hồ.');
    final data = await ApiClient.instance.post(
      '/wearable-activations/$clean/claim',
      {},
    );
    await _applySession(data);
  }

  // POST /auth/firebase — đăng nhập bằng Google qua Firebase ID token.
  // Trả về `true` nếu đăng nhập thành công, `false` nếu user tự hủy chọn tài
  // khoản (để UI không hiện lỗi). Ném lỗi cho các trường hợp thật (401/403/503).
  Future<bool> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return false; // user hủy hộp chọn tài khoản
    final gAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.accessToken,
    );
    final userCred = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final firebaseIdToken = await userCred.user?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw Exception('Không lấy được token Google, vui lòng thử lại.');
    }
    final data = await ApiClient.instance.post('/auth/firebase', {
      'idToken': firebaseIdToken,
    });
    await _applySession(data);
    return true;
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
    // Authorization is evaluated from :familyId on each request. Select the
    // newly created workspace locally; do not rely on JWT family claims.
    await _activateFamilyContext(
      _FamilyContext(id: fid, name: name.trim(), role: 'FAMILY_MANAGER'),
      persist: true,
    );
    notifyListeners();
    return;
  }

  /*
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
    if (!claimsRefreshed) {
      // The create operation already succeeded; report a recovery step rather
      // than leaving the user with a misleading permission error later.
      throw Exception(
        'Gia đình đã được tạo nhưng phiên đăng nhập chưa được làm mới. '
        'Vui lòng đăng xuất và đăng nhập lại trước khi tạo dữ liệu.',
      );
    }
  }

  // Đăng ký callbacks vào ApiClient: token rotation + force logout
  */
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
      _workspaces = const [];
      _needsFamilySelection = false;
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
      if (ctx.id != null) {
        ApiClient.instance.setFamilyId(ctx.id);
        await _storage.write(key: _kCurrentFamilyIdKey, value: ctx.id);
      }

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
      await _storage.delete(key: _kCurrentFamilyIdKey);
    } catch (e) {
      debugPrint('AuthProvider: clear tokens failed: $e');
    }
  }

  // Lấy familyId/familyName/familyRole của user hiện tại — dùng chung cho
  // login, restore session và refreshFamilyContext.
  Future<_FamilyContext> _fetchFamilyContext(
    String? myId, {
    String? preferredFamilyId,
  }) async {
    try {
      final response = await ApiClient.instance.get('/families/my');
      final families = response is List
          ? response.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      _workspaces = families
          .map(_workspaceFromJson)
          .whereType<FamilyWorkspace>()
          .toList(growable: false);

      if (_workspaces.isEmpty) {
        _needsFamilySelection = false;
        return const _FamilyContext();
      }

      final storedId =
          preferredFamilyId ?? await _storage.read(key: _kCurrentFamilyIdKey);
      FamilyWorkspace? selected;
      for (final workspace in _workspaces) {
        if (workspace.id == storedId) {
          selected = workspace;
          break;
        }
      }

      if (selected == null && storedId != null) {
        await _storage.delete(key: _kCurrentFamilyIdKey);
        _needsFamilySelection = true;
        return const _FamilyContext();
      }
      if (selected == null && _workspaces.length > 1) {
        _needsFamilySelection = true;
        return const _FamilyContext();
      }

      final workspace = selected ?? _workspaces.single;
      _needsFamilySelection = false;
      return _resolveFamilyContext(workspace, myId);
    } catch (e) {
      debugPrint('AuthProvider: fetch family context failed: $e');
      return const _FamilyContext();
    }
  }

  FamilyWorkspace? _workspaceFromJson(Map<String, dynamic> family) {
    final id = family['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return FamilyWorkspace(
      id: id,
      name: family['name']?.toString() ?? 'Gia đình',
      role: _roleFromFamily(family),
    );
  }

  String? _roleFromFamily(Map<String, dynamic> family) {
    final direct =
        family['currentMemberRole']?.toString() ??
        family['myRole']?.toString() ??
        family['userRole']?.toString() ??
        family['role']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final members = family['members'] as List? ?? const [];
    Map? firstMember;
    for (final member in members.whereType<Map>()) {
      firstMember = member;
      break;
    }
    return firstMember?['familyRole']?.toString() ??
        firstMember?['role']?.toString();
  }

  Future<_FamilyContext> _resolveFamilyContext(
    FamilyWorkspace workspace,
    String? myId,
  ) async {
    String? role = workspace.role;
    try {
      final result = await ApiClient.instance.get('/families/${workspace.id}');
      if (result is Map) {
        final members = (result['members'] as List? ?? const [])
            .whereType<Map>();
        final me = members.firstWhere(
          (member) =>
              member['userId']?.toString() == myId ||
              member['user']?['id']?.toString() == myId,
          orElse: () => const <String, dynamic>{},
        );
        final status = me['status']?.toString().toUpperCase();
        if (status != null && status.isNotEmpty && status != 'ACTIVE') {
          return const _FamilyContext();
        }
        role = me['familyRole']?.toString() ?? me['role']?.toString() ?? role;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        await _storage.delete(key: _kCurrentFamilyIdKey);
        _needsFamilySelection = true;
        return const _FamilyContext();
      }
      debugPrint('AuthProvider: family detail check failed: $e');
    }
    return _FamilyContext(id: workspace.id, name: workspace.name, role: role);
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
    if (ctx.id != null) {
      ApiClient.instance.setFamilyId(ctx.id);
      await _storage.write(key: _kCurrentFamilyIdKey, value: ctx.id);
    }

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

  /// PATCH /auth/me — cập nhật hồ sơ của tài khoản đang đăng nhập.
  Future<void> updateMyProfile({
    required String fullName,
    String? phone,
  }) async {
    if (!isLoggedIn) throw Exception('Bạn chưa đăng nhập');
    await ApiClient.instance.patch('/auth/me', {
      'fullName': fullName.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
    });
    await refreshMe();
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
    // Đăng xuất Google + Firebase (best-effort) để lần sau hiện lại hộp chọn
    // tài khoản; lỗi ở đây KHÔNG được chặn logout.
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('AuthProvider: Google/Firebase signOut failed: $e');
    }
    // Báo server revoke refresh token TRƯỚC khi xoá session khỏi ApiClient.
    // Swagger xác nhận `/auth/logout` yêu cầu `security: [{bearer: []}]`
    // (401 "Missing or invalid access token") — gọi SAU `clearSession()`
    // như bản cũ thì request đi không có Authorization, BE luôn trả 401 và
    // refresh token KHÔNG BAO GIỜ được revoke phía server (lỗi thật, xác
    // nhận qua Swagger 2026-08-19). Không `await`: `_headers()` đọc token
    // ngay khi gọi `post()` (đồng bộ, trước await đầu tiên), nên fire-and-
    // forget vẫn gửi đúng token — giữ đúng ý định cũ "không đợi server
    // response" để đăng xuất cục bộ vẫn tức thời.
    unawaited(
      ApiClient.instance
          .post('/auth/logout', {
            if (refreshToken != null) 'refreshToken': refreshToken,
          })
          .catchError((Object e) {
            debugPrint('AuthProvider: server logout call failed: $e');
            return <String, dynamic>{};
          }),
    );
    // Xóa session ngay lập tức — không đợi server response
    _user = null;
    _workspaces = const [];
    _needsFamilySelection = false;
    _pendingEmailVerification = false;
    // Token mời đang treo là của phiên cũ — bỏ luôn, nếu giữ thì tài khoản
    // đăng nhập sau bị đẩy nhầm về màn Tham gia gia đình.
    await clearPendingInviteToken();
    ApiClient.instance.clearSession();
    await _clearStoredTokens();
    notifyListeners();
  }

  // Cập nhật familyId sau khi user tạo/join gia đình thành công
  Future<void> _activateFamilyContext(
    _FamilyContext context, {
    required bool persist,
  }) async {
    final familyId = context.id;
    if (familyId == null || _user == null) return;
    if (persist) {
      await _storage.write(key: _kCurrentFamilyIdKey, value: familyId);
    }
    if (!_workspaces.any((item) => item.id == familyId)) {
      _workspaces = [
        ..._workspaces,
        FamilyWorkspace(
          id: familyId,
          name: context.name ?? 'Gia đình',
          role: context.role,
        ),
      ];
    }
    _needsFamilySelection = false;
    ApiClient.instance.setFamilyId(familyId);
    _user = AppUser.fromJson(
      {
        'id': _user!.id,
        'fullName': _user!.name,
        'email': _user!.email,
        'userType': _user!.userType,
      },
      accessToken: _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId: familyId,
      familyName: context.name ?? '',
      familyRole: context.role,
      phone: _user!.phone,
    );
  }

  Future<void> selectFamily(String familyId) async {
    if (!isLoggedIn) return;
    FamilyWorkspace? workspace;
    for (final item in _workspaces) {
      if (item.id == familyId) {
        workspace = item;
        break;
      }
    }
    if (workspace == null) {
      throw Exception('Gia đình đã chọn không còn hoạt động.');
    }
    final context = await _resolveFamilyContext(workspace, _user!.id);
    if (context.id == null) {
      throw Exception('Bạn không còn là thành viên của gia đình này.');
    }
    await _activateFamilyContext(context, persist: true);
    ApiClient.instance.resetWorkspaceData();
    notifyListeners();
  }

  Future<void> refreshFamilyContext({String? preferredFamilyId}) async {
    if (!isLoggedIn) return;
    final ctx = await _fetchFamilyContext(
      _user!.id,
      preferredFamilyId: preferredFamilyId,
    );
    if (ctx.id == null) {
      ApiClient.instance.setFamilyId(null);
      _user = AppUser.fromJson(
        {
          'id': _user!.id,
          'fullName': _user!.name,
          'email': _user!.email,
          'userType': _user!.userType,
        },
        accessToken: _user!.accessToken,
        refreshToken: _user!.refreshToken,
        familyRole: _user!.familyRoleString,
        phone: _user!.phone,
      );
      notifyListeners();
      return;
    }
    await _storage.write(key: _kCurrentFamilyIdKey, value: ctx.id);
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
