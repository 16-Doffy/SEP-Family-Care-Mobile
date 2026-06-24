import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/sos_provider.dart';
import '../theme/app_colors.dart';

class ActiveSosBanner extends StatelessWidget {
  const ActiveSosBanner({super.key});

  String? _firstNonEmptyId(Iterable<String> ids) {
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final active = sos.activeAlerts;
    if (active.isEmpty) return const SizedBox.shrink();

    final alert = active.first;
    final extra = active.length - 1;

    return GestureDetector(
      onTap: () async {
        final alertId = alert.id.trim();
        if (alertId.isNotEmpty) {
          context.push('/sos/alert/$alertId');
          return;
        }

        await context.read<SosProvider>().fetchAlerts();
        final refreshedId = _firstNonEmptyId(
          context.read<SosProvider>().activeAlerts.map((a) => a.id),
        );
        if (!context.mounted) return;

        if (refreshedId != null) {
          context.push('/sos/alert/$refreshedId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa tìm thấy mã cảnh báo SOS'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.sos,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.sos.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.emergency_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cảnh báo SOS đang hoạt động',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    extra > 0
                        ? '${alert.senderName} và $extra cảnh báo khác - Bấm để xem'
                        : '${alert.senderName} - Bấm để xem chi tiết',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
