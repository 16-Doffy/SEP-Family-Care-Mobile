import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/sos_provider.dart';

// UC57 — Trigger SOS từ Wearable (hold 2 giây)

class WearSosScreen extends StatefulWidget {
  const WearSosScreen({super.key});
  @override
  State<WearSosScreen> createState() => _WearSosScreenState();
}

class _WearSosScreenState extends State<WearSosScreen>
    with SingleTickerProviderStateMixin {
  bool _holding   = false;
  bool _sent      = false;
  bool _sending   = false;
  int  _countdown = 2;
  Timer? _holdTimer;

  late AnimationController _pulse;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsProvider>().fetchFamilyLocations();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart() {
    HapticFeedback.mediumImpact();
    _pulse.stop();
    setState(() { _holding = true; _countdown = 2; });
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      HapticFeedback.heavyImpact();
      if (_countdown <= 0) {
        t.cancel();
        _triggerSOS();
      }
    });
  }

  void _onHoldEnd() {
    if (_sent || _sending) return;
    _holdTimer?.cancel();
    _pulse.repeat(reverse: true);
    setState(() { _holding = false; _countdown = 2; });
  }

  Future<void> _triggerSOS() async {
    setState(() { _sending = true; _holding = false; });
    HapticFeedback.heavyImpact();
    try {
      final myId = context.read<AuthProvider>().user?.id ?? '';
      final gps  = context.read<GpsProvider>();
      final loc  = gps.shares
          .where((s) => s.userId == myId && s.latitude != null)
          .firstOrNull;
      await context.read<SosProvider>().sendSos(
        message:  'SOS khẩn cấp từ đồng hồ FamilyCare',
        address:  loc != null
            ? 'GPS: ${loc.latitude?.toStringAsFixed(5)}, ${loc.longitude?.toStringAsFixed(5)}'
            : 'Vị trí đang cập nhật...',
        latitude:  loc?.latitude,
        longitude: loc?.longitude,
      );
      if (mounted) setState(() { _sent = true; _sending = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _sending = false; _holding = false; _countdown = 2; });
        _pulse.repeat(reverse: true);
      }
    }
  }

  void _cancelSOS() async {
    final sos = context.read<SosProvider>();
    if (sos.alerts.isNotEmpty) {
      await sos.updateAlert(sos.alerts.first.id, 'CANCELLED');
    }
    setState(() { _sent = false; _countdown = 2; });
    _pulse.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sending) return _loadingView();
    if (_sent)    return _sentView();

    final size    = MediaQuery.of(context).size;
    final btnSize = min(size.width, size.height) * 0.50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _holding ? 'Thả để huỷ...' : 'Giữ để gửi SOS',
              style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTapDown: (_) => _onHoldStart(),
              onTapUp:   (_) => _onHoldEnd(),
              onTapCancel: _onHoldEnd,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Transform.scale(
                  scale: _holding ? 1.06 : _scale.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: btnSize + 18, height: btnSize + 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDC2626)
                              .withValues(alpha: _holding ? 0.25 : 0.1),
                        ),
                      ),
                      Container(
                        width: btnSize, height: btnSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _holding
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFFDC2626),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.5),
                              blurRadius: _holding ? 18 : 8,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🚨', style: TextStyle(fontSize: 24)),
                            Text(
                              _holding ? '$_countdown' : 'SOS',
                              style: GoogleFonts.inter(
                                  fontSize: _holding ? 20 : 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text('← Vuốt xem cảnh báo →',
                style: GoogleFonts.inter(fontSize: 8, color: Colors.white24)),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 36, height: 36,
          child: CircularProgressIndicator(
              color: Color(0xFFDC2626), strokeWidth: 3)),
        const SizedBox(height: 12),
        Text('Đang gửi...', style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
      ]),
    ),
  );

  Widget _sentView() => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🚨', style: TextStyle(fontSize: 38)),
        const SizedBox(height: 6),
        Text('SOS Đã Gửi!',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Gia đình đã được thông báo',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _cancelSOS,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Huỷ SOS',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626))),
          ),
        ),
      ]),
    ),
  );
}
