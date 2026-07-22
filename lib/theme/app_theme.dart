import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_surface_colors.dart';

/// ThemeData chung — input/button/dialog/sheet tự đồng bộ style toàn app,
/// màn hình mới chỉ cần dùng widget mặc định là đẹp sẵn.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    surfaces: AppSurfaceColors.light,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    surfaces: AppSurfaceColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppSurfaceColors surfaces,
  }) {
    final base = GoogleFonts.interTextTheme();
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        brightness: brightness,
        primary: AppColors.primary500,
        secondary: AppColors.secondary500,
        error: AppColors.danger,
        surface: surfaces.surface,
      ),
      extensions: [surfaces],
      scaffoldBackgroundColor: surfaces.background,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaces.background,
        foregroundColor: surfaces.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: surfaces.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: surfaces.textPrimary,
        ),
      ),
      iconTheme: IconThemeData(color: surfaces.textSecondary),
      primaryIconTheme: IconThemeData(color: surfaces.textPrimary),
      dividerTheme: DividerThemeData(
        color: surfaces.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surfaces.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: surfaces.textSecondary,
        textColor: surfaces.textPrimary,
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: surfaces.textMuted,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaces.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          color: surfaces.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return surfaces.textMuted;
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary500;
          }
          return surfaces.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return surfaces.divider.withValues(alpha: 0.45);
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary500.withValues(alpha: 0.35);
          }
          return surfaces.divider;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textTheme: base.copyWith(
        bodyLarge:  base.bodyLarge?.copyWith(color: surfaces.textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: surfaces.textPrimary),
        bodySmall:  base.bodySmall?.copyWith(color: surfaces.textSecondary),
        titleLarge: base.titleLarge?.copyWith(
          color: surfaces.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaces.inputFill,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: surfaces.textMuted),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.danger),
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: surfaces.divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: surfaces.divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary500,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaces.surface : AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaces.surface,
        headerBackgroundColor: AppColors.primary500,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaces.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
