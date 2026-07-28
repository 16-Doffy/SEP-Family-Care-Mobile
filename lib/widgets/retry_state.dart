import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'empty_state.dart';

class RetryState extends StatelessWidget {
  const RetryState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.danger,
      title: 'Không tải được dữ liệu',
      subtitle: message,
      actionLabel: 'Thử lại',
      onAction: onRetry,
    );
  }
}
