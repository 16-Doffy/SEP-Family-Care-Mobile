import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Icon chức năng dùng chung cho card/menu/shortcut.
///
/// Giữ icon trong một khung bo nhẹ để thay emoji rải rác bằng một ngôn ngữ
/// hình ảnh thống nhất trên toàn app.
class AppFeatureIcon extends StatelessWidget {
  const AppFeatureIcon({
    super.key,
    required this.icon,
    this.color = AppColors.primary500,
    this.backgroundColor,
    this.size = 44,
    this.iconSize = 22,
    this.radius = 14,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
