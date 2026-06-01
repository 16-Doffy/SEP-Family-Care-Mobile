import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with SingleTickerProviderStateMixin {
  bool _sent = false;
  int? _countdown;
  Timer? _countTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _ring1, _ring2, _ring3;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _ring1 = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _ring2 = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _ring3 = Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  void _onPressStart() {
    _pulseCtrl.stop();
    setState(() { _countdown = 3; });
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown = (_countdown ?? 3) - 1;
        if ((_countdown ?? 0) <= 0) { t.cancel(); _triggerSOS(); }
      });
    });
  }

  void _onPressEnd() {
    _countTimer?.cancel();
    setState(() => _countdown = null);
    _pulseCtrl.repeat(reverse: true);
  }

  void _triggerSOS() {
    _countTimer?.cancel();
    setState(() { _sent = true; _countdown = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _sentScreen(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // Radial glow
            Positioned.fill(child: Center(child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.sos.withOpacity(0.12))))),

            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)), alignment: Alignment.center, child: const Text('←', style: TextStyle(fontSize: 20, color: Colors.white)))),
                      Expanded(child: Center(child: Text('Khẩn cấp', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white54)))),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // SOS button area
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(scale: _ring3.value, child: Container(width: 290, height: 290, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.sos.withOpacity(0.3), width: 1)))),
                        Transform.scale(scale: _ring2.value, child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.sos.withOpacity(0.3), width: 1)))),
                        Transform.scale(scale: _ring1.value, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.sos.withOpacity(0.3), width: 1)))),

                        GestureDetector(
                          onTapDown: (_) => _onPressStart(),
                          onTapUp: (_) => _onPressEnd(),
                          onTapCancel: _onPressEnd,
                          child: Container(
                            width: 130, height: 130,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.sos),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Text('🚨', style: TextStyle(fontSize: 40)),
                              Text('SOS', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Instructions
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _countdown != null
                      ? Text('$_countdown', style: GoogleFonts.inter(fontSize: 56, fontWeight: FontWeight.w700, color: AppColors.danger))
                      : Column(children: [
                          Text('KHẨN CẤP', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger, letterSpacing: 3)),
                          Text('Giữ 3 giây để gửi SOS', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
                        ]),
                ),

                // Emergency numbers
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Liên hệ khẩn: ', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
                      ...['113', '115', '114'].map((n) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
                        child: Text(n, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚨', style: TextStyle(fontSize: 80)),
              Text('SOS đã gửi!', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Đang liên hệ thành viên gia đình…', style: GoogleFonts.inter(fontSize: 14, color: Colors.white60)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _contactCard('BA', AppColors.avatarBlue, 'Ba'),
                  const SizedBox(width: 20),
                  _contactCard('ME', AppColors.avatarPurple, 'Mẹ'),
                ],
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => setState(() => _sent = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.danger, width: 2)),
                  child: Text('Hủy SOS', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactCard(String init, Color color, String name) {
    return Column(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: color), alignment: Alignment.center, child: Text(init, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
      const SizedBox(height: 8),
      Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('Đang gọi…', style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
    ]);
  }
}
