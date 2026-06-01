import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String initial;
  final Color color;
  final double size;
  final bool showPresence;

  const AvatarWidget({
    super.key,
    required this.initial,
    required this.color,
    this.size = 44,
    this.showPresence = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          alignment: Alignment.center,
          child: Text(
            initial.length > 2 ? initial.substring(0, 2) : initial,
            style: GoogleFonts.inter(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (showPresence)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.safe,
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
