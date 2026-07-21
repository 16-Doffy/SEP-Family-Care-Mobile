import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AiChatbotIcon extends StatelessWidget {
  final double size;

  const AiChatbotIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trợ lý AI FamilyCare',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _AiChatbotIconPainter()),
        ),
      ),
    );
  }
}

class _AiChatbotIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);

    final bubble = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.06, s * 0.11, s * 0.88, s * 0.74),
          Radius.circular(s * 0.24),
        ),
      )
      ..moveTo(s * 0.33, s * 0.78)
      ..quadraticBezierTo(s * 0.26, s * 0.94, s * 0.13, s * 0.98)
      ..quadraticBezierTo(s * 0.30, s * 0.99, s * 0.48, s * 0.83);

    canvas.drawShadow(
      bubble,
      Colors.black.withValues(alpha: 0.18),
      s * 0.04,
      true,
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary500, AppColors.secondary500],
        ).createShader(rect),
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025
        ..color = Colors.white.withValues(alpha: 0.70),
    );

    final antennaPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(s * 0.50, s * 0.30),
      Offset(s * 0.50, s * 0.20),
      antennaPaint,
    );
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.18),
      s * 0.055,
      Paint()..color = AppColors.accent500,
    );

    final earPaint = Paint()..color = Colors.white.withValues(alpha: 0.78);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.14, s * 0.43, s * 0.12, s * 0.25),
        Radius.circular(s * 0.06),
      ),
      earPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.74, s * 0.43, s * 0.12, s * 0.25),
        Radius.circular(s * 0.06),
      ),
      earPaint,
    );

    final headRect = Rect.fromLTWH(s * 0.22, s * 0.34, s * 0.56, s * 0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(s * 0.14)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(s * 0.14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = AppColors.primary100,
    );

    final visor = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.31, s * 0.45, s * 0.38, s * 0.18),
      Radius.circular(s * 0.09),
    );
    canvas.drawRRect(visor, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(
      Offset(s * 0.40, s * 0.53),
      s * 0.033,
      Paint()..color = AppColors.avatarTeal,
    );
    canvas.drawCircle(
      Offset(s * 0.60, s * 0.53),
      s * 0.033,
      Paint()..color = AppColors.accent500,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.45, s * 0.57)
        ..quadraticBezierTo(s * 0.50, s * 0.61, s * 0.55, s * 0.57),
      Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    _drawHeart(
      canvas,
      Offset(s * 0.67, s * 0.69),
      s * 0.055,
      Paint()..color = AppColors.primary500,
    );
    _drawSpark(canvas, Offset(s * 0.78, s * 0.25), s * 0.055);
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + r * 0.70)
      ..cubicTo(
        center.dx - r * 1.45,
        center.dy - r * 0.20,
        center.dx - r * 0.95,
        center.dy - r * 1.20,
        center.dx,
        center.dy - r * 0.45,
      )
      ..cubicTo(
        center.dx + r * 0.95,
        center.dy - r * 1.20,
        center.dx + r * 1.45,
        center.dy - r * 0.20,
        center.dx,
        center.dy + r * 0.70,
      );
    canvas.drawPath(path, paint);
  }

  void _drawSpark(Canvas canvas, Offset center, double r) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.30, center.dy - r * 0.30)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx + r * 0.30, center.dy + r * 0.30)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.30, center.dy + r * 0.30)
      ..lineTo(center.dx - r, center.dy)
      ..lineTo(center.dx - r * 0.30, center.dy - r * 0.30)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
