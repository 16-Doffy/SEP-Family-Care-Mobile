import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  void login(UserRole role, String name, {String? familyName}) {
    _user = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      familyName: familyName ?? 'Nguyễn',
      role: role,
      avatarInitials: name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
      avatarColor: _getAvatarColor(role),
    );
    notifyListeners();
  }

  int _getAvatarColor(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return AppColors.avatarBlue.toARGB32();
      case UserRole.deputy:
        return AppColors.avatarBlue.toARGB32(); // Phó nhóm dùng chung màu với Trưởng nhóm hoặc màu riêng tùy chọn
      case UserRole.member:
        return AppColors.avatarOrange.toARGB32();
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
