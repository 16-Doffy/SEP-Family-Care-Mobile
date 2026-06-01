import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> signIn(String email, String password) async {
    final data = await ApiClient.instance.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    _applySession(data);
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
    String familyName,
  ) async {
    final data = await ApiClient.instance.post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'familyName': familyName.trim(),
    });
    _applySession(data);
  }

  void _applySession(Map<String, dynamic> data) {
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String? ?? '';
    ApiClient.instance.setToken(token);
    _user = AppUser.fromJson(
      data['user'] as Map<String, dynamic>,
      accessToken: token,
      refreshToken: refreshToken,
    );
    notifyListeners();
  }

  // Demo login — no API call, for offline testing
  void login(UserRole role, String name, {String? familyName}) {
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

  void logout() {
    _user = null;
    ApiClient.instance.setToken(null);
    notifyListeners();
  }
}
