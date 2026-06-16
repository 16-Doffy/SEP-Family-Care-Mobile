import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get hasFamily  => _user?.familyId != null;

  // POST /auth/login
  Future<void> signIn(String email, String password) async {
    final data = await ApiClient.instance.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _applySession(data);
  }

  // POST /auth/register — schema: { email, password, fullName, phone? }
  // Không tự tạo gia đình — user sẽ chọn tạo mới hoặc join ở FamilySetupScreen
  Future<void> register(
    String email,
    String password,
    String fullName, {
    String? phone,
  }) async {
    final data = await ApiClient.instance.post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
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
      accessToken:  _user!.accessToken,
      refreshToken: _user!.refreshToken,
      familyId:     fid,
      familyName:   name.trim(),
      familyRole:   'MANAGER',
    );
    notifyListeners();
  }

  // Sau login/register: set token → gọi /families/my để lấy familyId + role trong gia đình
  Future<void> _applySession(Map<String, dynamic> data) async {
    // ApiClient đã unwrap { success, data } → data trực tiếp
    final token        = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String? ?? '';
    ApiClient.instance.setToken(token);

    final userJson = data['user'] as Map<String, dynamic>? ?? data;

    // Lấy family context
    String? familyId;
    String? familyName;
    String? familyRole;
    try {
      final families = await ApiClient.instance.get('/families/my');
      final list = families is List ? families : <dynamic>[];
      if (list.isNotEmpty) {
        final f = list.first as Map<String, dynamic>;
        familyId   = f['id']?.toString();
        familyName = f['name']?.toString();
        final members = f['members'] as List? ?? [];
        final myId    = userJson['id']?.toString();
        final me = members.whereType<Map>().firstWhere(
          (m) => m['userId']?.toString() == myId || m['user']?['id']?.toString() == myId,
          orElse: () => {},
        );
        familyRole = me['familyRole']?.toString() ?? me['role']?.toString();
      }
    } catch (_) {
      // User chưa có gia đình — vẫn để đăng nhập bình thường
    }

    if (familyId != null) ApiClient.instance.setFamilyId(familyId);

    _user = AppUser.fromJson(
      userJson,
      accessToken:  token,
      refreshToken: refreshToken,
      familyId:     familyId,
      familyName:   familyName ?? '',
      familyRole:   familyRole,
    );
    notifyListeners();
  }

  // POST /auth/logout
  Future<void> logout() async {
    try {
      if (_user?.refreshToken != null) {
        await ApiClient.instance.post('/auth/logout', {
          'refreshToken': _user!.refreshToken!,
        });
      }
    } catch (_) {}
    _user = null;
    ApiClient.instance.setToken(null);
    ApiClient.instance.setFamilyId(null);
    notifyListeners();
  }

  // Cập nhật familyId sau khi user tạo/join gia đình thành công
  Future<void> refreshFamilyContext() async {
    if (!isLoggedIn) return;
    try {
      final families = await ApiClient.instance.get('/families/my');
      final list = families is List ? families : <dynamic>[];
      if (list.isNotEmpty) {
        final f        = list.first as Map<String, dynamic>;
        final familyId = f['id']?.toString();
        final familyName = f['name']?.toString() ?? '';
        final members  = f['members'] as List? ?? [];
        final me = members.whereType<Map>().firstWhere(
          (m) => m['userId']?.toString() == _user!.id || m['user']?['id']?.toString() == _user!.id,
          orElse: () => {},
        );
        final familyRole = me['familyRole']?.toString() ?? me['role']?.toString();
        if (familyId != null) ApiClient.instance.setFamilyId(familyId);
        _user = AppUser.fromJson(
          {'id': _user!.id, 'fullName': _user!.name, 'email': _user!.email},
          accessToken:  _user!.accessToken,
          refreshToken: _user!.refreshToken,
          familyId:     familyId,
          familyName:   familyName,
          familyRole:   familyRole,
        );
        notifyListeners();
      }
    } catch (_) {}
  }
}
