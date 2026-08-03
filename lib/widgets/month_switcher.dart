import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/finance_period.dart';
import '../theme/app_colors.dart';
import '../theme/app_surface_colors.dart';
import '../theme/app_ui_tokens.dart';

/// Thanh chọn kỳ tài chính: `◀  Tháng 8/2026  ▶` + nút "Về tháng này".
///
/// Chặn tiến quá kỳ hiện tại (không có dữ liệu tương lai để xem) và chặn lùi
/// quá [earliest] nếu caller biết mốc bắt đầu của gia đình.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.period,
    required this.onChanged,
    this.earliest,
    this.enabled = true,
    this.trailing,
  });

  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onChanged;

  /// Kỳ cũ nhất còn xem được. Null = không giới hạn.
  final FinancePeriod? earliest;

  /// Khoá thao tác trong lúc đang tải để tránh bắn 2 request chồng nhau.
  final bool enabled;

  /// Chỗ cắm thêm (ví dụ nút xuất báo cáo) ở mép phải.
  final Widget? trailing;

  bool get _canGoBack =>
      earliest == null || period.previous.compareTo(earliest!) >= 0;

  /// Chỉ cho tiến khi đang đứng ở kỳ quá khứ — không có dữ liệu tương lai.
  bool get _canGoForward => period.isPast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _arrow(
            context,
            icon: Icons.chevron_left,
            tooltip: 'Tháng trước',
            onTap: enabled && _canGoBack
                ? () => onChanged(period.previous)
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (!period.isCurrent)
                  Text(
                    'Kỳ đã qua',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.amberText,
                    ),
                  ),
              ],
            ),
          ),
          _arrow(
            context,
            icon: Icons.chevron_right,
            tooltip: 'Tháng sau',
            onTap: enabled && _canGoForward
                ? () => onChanged(period.next)
                : null,
          ),
          if (!period.isCurrent)
            TextButton(
              onPressed: enabled
                  ? () => onChanged(FinancePeriod.current())
                  : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Tháng này',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary500,
                ),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _arrow(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final colors = context.colors;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 22,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      color: colors.textPrimary,
      disabledColor: colors.textMuted.withValues(alpha: 0.4),
    );
  }
}
