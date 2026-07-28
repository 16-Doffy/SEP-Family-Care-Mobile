import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

class AppRadius {
  AppRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get nav => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];
}

class AppStatusColors {
  AppStatusColors._();

  static Color foreground(String status) => switch (status.toUpperCase()) {
    'ACTIVE' ||
    'READY' ||
    'APPROVED' ||
    'COMPLETED' ||
    'SETTLED' => AppColors.success,
    'PENDING' ||
    'PROCESSING' ||
    'SUBMITTED' ||
    'WAITING_CONFIRMATION' => AppColors.accent500,
    'REJECTED' ||
    'FAILED' ||
    'CANCELED' ||
    'CANCELLED' ||
    'VOIDED' => AppColors.danger,
    'DISABLED' || 'INACTIVE' => AppColors.textMuted,
    _ => AppColors.link,
  };

  static Color background(String status) =>
      foreground(status).withValues(alpha: 0.10);
}
