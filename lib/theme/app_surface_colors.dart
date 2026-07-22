import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppSurfaceColors extends ThemeExtension<AppSurfaceColors> {
  const AppSurfaceColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.inputFill,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color inputFill;

  static const light = AppSurfaceColors(
    background: AppColors.background,
    surface: AppColors.white,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    divider: AppColors.progressTrack,
    inputFill: Color(0xFFFAFAFA),
  );

  static const dark = AppSurfaceColors(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE5E7EB),
    textMuted: Color(0xFF8E8E93),
    divider: Color(0xFF38383A),
    inputFill: Color(0xFF2C2C2E),
  );

  @override
  AppSurfaceColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? inputFill,
  }) {
    return AppSurfaceColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppSurfaceColors lerp(ThemeExtension<AppSurfaceColors>? other, double t) {
    if (other is! AppSurfaceColors) return this;
    return AppSurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

extension AppSurfaceColorsX on BuildContext {
  AppSurfaceColors get colors =>
      Theme.of(this).extension<AppSurfaceColors>() ?? AppSurfaceColors.light;
}
