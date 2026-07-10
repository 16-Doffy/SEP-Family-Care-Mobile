import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Đích deep link Stripe trả về sau thanh toán (BE đặt trong env checkout):
///   thành công: familycare://app/payment-success
///   thất bại:   familycare://app/payment-failed
/// Màn subscription tự refetch khi mở lại nên ở đây chỉ hiển thị kết quả.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({super.key, required this.success});

  final bool success;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: success ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(success ? '🎉' : '😥', style: const TextStyle(fontSize: 44)),
                ),
                const SizedBox(height: 20),
                Text(
                  success ? 'Thanh toán thành công!' : 'Thanh toán chưa hoàn tất',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  success
                      ? 'Gói đăng ký của gia đình sẽ được kích hoạt trong giây lát. Nếu chưa thấy cập nhật, hãy mở lại màn Gói đăng ký.'
                      : 'Giao dịch đã bị hủy hoặc gặp lỗi. Bạn có thể thử lại bất cứ lúc nào — chưa có khoản tiền nào bị trừ.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.go('/manager/subscription'),
                    child: Text('Xem gói đăng ký',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/manager/home'),
                  child: Text('Về trang chủ', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
