import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifs = [
      ('🏆', 'Task hoàn thành', 'An đã hoàn thành "Dọn phòng ngủ" · +50 XP', '09:41', const Color(0xFFDCFCE7)),
      ('💰', 'Yêu cầu tiền', 'An xin 50,000 ₫ để mua sách tham khảo', '09:00', const Color(0xFFFEF3C7)),
      ('🚨', 'SOS', 'An đã gửi tín hiệu khẩn cấp!', 'Hôm qua', const Color(0xFFFEE2E2)),
      ('📅', 'Nhắc lịch', 'Dã ngoại cuối tuần còn 3 ngày', 'Hôm qua', const Color(0xFFEFF6FF)),
      ('💵', 'Giao dịch', 'Lương tháng 5 đã cộng +50,000,000 ₫', '19/05', const Color(0xFFF0FDF4)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)]), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary))),
                  const Expanded(child: Center(child: Text('Thông báo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: notifs.length,
                itemBuilder: (_, i) {
                  final n = notifs[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: n.$5, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
                    child: Row(
                      children: [
                        Text(n.$1, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.$2, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(n.$3, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ])),
                        Text(n.$4, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
