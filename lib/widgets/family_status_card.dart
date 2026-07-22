import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/sos_provider.dart';
import '../theme/app_colors.dart';
import 'app_feature_icon.dart';

/// Block "Trạng thái gia đình" ở Trang chủ — nhìn nhanh ai đang có SOS active.
///
/// Bản RÚT GỌN: chỉ dựa [SosProvider.activeAlerts] (không kèm vị trí / last-
/// update từng thành viên) vì API location độc lập (`/location/*`) hiện còn
/// 404 — xem PHAN_TICH_v0_SOS_MAP §5. Thuần UI, không đụng BE. Khi BE ship
/// location sharing thì mở rộng thêm hàng vị trí cho từng thành viên.
class FamilyStatusCard extends StatelessWidget {
  const FamilyStatusCard({super.key});

  static String _fmtTime(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<SosProvider>().activeAlerts;
    final safe = alerts.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: safe
            ? const Color(0xFFF0FDF4)
            : AppColors.sos.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: safe
              ? const Color(0xFFDCFCE7)
              : AppColors.sos.withValues(alpha: 0.4),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppFeatureIcon(
            icon: safe
                ? Icons.health_and_safety_outlined
                : Icons.sos_rounded,
            color: safe ? AppColors.safe : AppColors.sos,
            backgroundColor: safe
                ? AppColors.safe.withValues(alpha: 0.12)
                : AppColors.sos.withValues(alpha: 0.12),
            size: 34,
            iconSize: 18,
            radius: 10,
          ),
          const SizedBox(width: 8),
          Text('Trạng thái gia đình',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        if (safe)
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.safe),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Cả nhà an toàn — không có cảnh báo nào',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ])
        else
          ...alerts.map((a) {
            final t = _fmtTime(a.createdAt);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.sos, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      '${a.senderName} đang cần trợ giúp${t.isNotEmpty ? ' · $t' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sos)),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}
