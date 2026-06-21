import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Hiển thị trong lúc AuthProvider.tryRestoreSession() đang khôi phục
// session đã lưu (đọc token từ secure storage + gọi /auth/me).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.link),
      ),
    );
  }
}
