import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../wear_utils.dart';

// UC51 — Xem và phản hồi SOS Alert trên đồng hồ

class WearAlertsScreen extends StatefulWidget {
  const WearAlertsScreen({super.key});
  @override
  State<WearAlertsScreen> createState() => _WearAlertsScreenState();
}

class _WearAlertsScreenState extends State<WearAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final alerts = sos.activeAlerts;
    final hPad = WearUtils.safePadding(context).left;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: alerts.isEmpty
            ? _emptyView(sos)
            : _listView(context, alerts, hPad, sos),
      ),
    );
  }

  Widget _emptyView(SosProvider sos) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('✅', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          'Không có cảnh báo',
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await sos.fetchAlerts();
            HapticFeedback.lightImpact();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Làm mới',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _listView(
    BuildContext ctx,
    List<SosAlert> alerts,
    double hPad,
    SosProvider sos,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      itemCount: alerts.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🚨 ${alerts.length} cảnh báo',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await sos.fetchAlerts();
                    HapticFeedback.lightImpact();
                  },
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          );
        }
        final alert = alerts[i - 1];
        return _alertCard(ctx, alert, sos);
      },
    );
  }

  Widget _alertCard(BuildContext ctx, SosAlert alert, SosProvider sos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  alert.senderName,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            alert.message,
            style: GoogleFonts.inter(fontSize: 8, color: Colors.white54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (alert.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '📍 ${alert.address}',
              style: GoogleFonts.inter(fontSize: 7, color: Colors.white30),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (sos.sending) return;
                    HapticFeedback.mediumImpact();
                    try {
                      await sos.respond(alert.id, 'VIEWED', message: 'Tôi đang đến');
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(e.toString().replaceFirst('Exception: ', ''),
                              style: const TextStyle(fontSize: 10)),
                          backgroundColor: const Color(0xFFDC2626),
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    }
                  },
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Đến ngay',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Chỉ Manager/Deputy được phép resolve (Swagger: PATCH
              // .../resolve chỉ FAMILY_MANAGER/DEPUTY_MEMBER).
              if (ctx.watch<AuthProvider>().user?.canResolveSos == true) ...[
                const SizedBox(width: 5),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (sos.sending) return;
                      HapticFeedback.lightImpact();
                      try {
                        await sos.resolveAlert(alert.id);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', ''),
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 2),
                          ));
                        }
                      }
                    },
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Xong',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
