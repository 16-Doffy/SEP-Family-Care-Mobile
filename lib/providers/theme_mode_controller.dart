import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemePreference { system, light, dark }

extension AppThemePreferenceX on AppThemePreference {
  String get label => switch (this) {
    AppThemePreference.system => 'Theo hệ thống',
    AppThemePreference.light => 'Sáng',
    AppThemePreference.dark => 'Tối',
  };

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

class ThemeModeController extends ChangeNotifier {
  ThemeModeController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'theme_mode_preference';

  final FlutterSecureStorage _storage;
  AppThemePreference _preference = AppThemePreference.system;
  bool _loaded = false;

  AppThemePreference get preference => _preference;
  ThemeMode get themeMode => _preference.themeMode;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      _preference = AppThemePreference.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => AppThemePreference.system,
      );
    } catch (e) {
      debugPrint('ThemeModeController: đọc giao diện thất bại: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: preference.name);
    } catch (e) {
      debugPrint('ThemeModeController: lưu giao diện thất bại: $e');
    }
  }
}
