import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/sos_provider.dart';
import '../wear_utils.dart';

// UC58 — Fall Detection từ accelerometer
// Status: GPS vị trí, fall detection toggle, thông tin user

class WearStatusScreen extends StatefulWidget {
  const WearStatusScreen({super.key});
  @override
  State<WearStatusScreen> createState() => _WearStatusScreenState();
}

class _WearStatusScreenState extends State<WearStatusScreen> {
  bool _fallEnabled  = false;
  bool _fallDetected = false;
  double _magnitude  = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Ngưỡng ngã: gia tốc > 25 m/s² (bình thường khi đứng yên ~9.8)
  static const _threshold = 25.0;

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _toggleFall(bool enabled) {
    setState(() => _fallEnabled = enabled);
    if (enabled) {
      HapticFeedback.mediumImpact();
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(_onAccel);
    } else {
      _accelSub?.cancel();
      setState(() { _fallDetected = false; _magnitude = 0; });
    }
  }

  void _onAccel(AccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (_magnitude < _threshold && mag >= _threshold && !_fallDetected) {
      setState(() => _fallDetected = true);
      HapticFeedback.heavyImpact();
      _autoSendFallSOS();
    }
    setState(() => _magnitude = mag);
  }

  Future<void> _autoSendFallSOS() async {
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final gps  = context.read<GpsProvider>();
    final loc  = gps.shares
        .where((s) => s.userId == myId && s.latitude != null)
        .firstOrNull;
    try {
      await context.read<SosProvider>().sendSos(
        message:  '⚠️ Phát hiện té ngã — Cần hỗ trợ ngay!',
        address:  loc != null
            ? 'GPS: ${loc.latitude?.toStringAsFixed(5)}, ${loc.longitude?.toStringAsFixed(5)}'
            : 'Vị trí đang cập nhật...',
        latitude:  loc?.latitude,
        longitude: loc?.longitude,
      );
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _fallDetected = false);
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user;
    final gps   = context.watch<GpsProvider>();
    final hPad  = WearUtils.safePadding(context).left;

    final myLoc = gps.shares
        .where((s) => s.userId == (user?.id ?? '') && s.latitude != null)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // User row
            Row(children: [
              Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF2563EB)),
                alignment: Alignment.center,
                child: Text(user?.avatarInitials ?? '?',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(user?.name ?? '—',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 10),

            // GPS
            _row('📍', 'GPS',
                myLoc != null
                    ? '${myLoc.latitude?.toStringAsFixed(3)}, '
                      '${myLoc.longitude?.toStringAsFixed(3)}'
                    : 'Chưa có vị trí',
                myLoc != null ? const Color(0xFF16A34A) : Colors.white38),
            const SizedBox(height: 8),

            // Fall detection toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: _fallEnabled
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(10),
                border: _fallDetected
                    ? Border.all(color: const Color(0xFFDC2626), width: 1.5)
                    : null,
              ),
              child: Row(children: [
                Text(_fallDetected ? '⚠️' : '🛡️',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Phát hiện ngã',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    if (_fallDetected)
                      Text('⚠️ Đã gửi SOS!',
                          style: GoogleFonts.inter(
                              fontSize: 7, color: const Color(0xFFDC2626))),
                  ]),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _fallEnabled,
                    onChanged: _toggleFall,
                    activeThumbColor: const Color(0xFF16A34A),
                  ),
                ),
              ]),
            ),

            if (_fallEnabled) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(children: [
                  const Text('📊', style: TextStyle(fontSize: 9)),
                  const SizedBox(width: 5),
                  Text('${_magnitude.toStringAsFixed(1)} m/s²',
                      style: GoogleFonts.inter(
                          fontSize: 8, color: Colors.white38)),
                ]),
              ),
            ],

            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<AuthProvider>().logout();
                },
                child: Text('Đăng xuất',
                    style: GoogleFonts.inter(
                        fontSize: 8, color: Colors.white24,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white24)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(String icon, String label, String value, Color color) {
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 5),
      Text('$label: ',
          style: GoogleFonts.inter(fontSize: 8, color: Colors.white38)),
      Expanded(
        child: Text(value,
            style: GoogleFonts.inter(
                fontSize: 8, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
