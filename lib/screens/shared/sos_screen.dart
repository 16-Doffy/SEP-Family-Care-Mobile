import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with SingleTickerProviderStateMixin {
  bool   _sent      = false;
  bool   _sending   = false;
  bool   _apiOk     = false; // true nếu BE nhận được SOS
  int?   _countdown;
  Timer? _countTimer;
  double? _localLat, _localLng; // GPS lưu local khi API chưa có
  String? _sentAlertId; // id alert vừa tạo, để Đóng/confirm-safety đúng alert
  late AnimationController _pulseCtrl;
  late Animation<double>   _ring1, _ring2, _ring3;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _ring1 = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _ring2 = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _ring3 = Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Refresh alerts when manager opens screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  // ── Hold-to-send countdown ───────────────────────────────────────────────

  void _onPressStart() {
    _pulseCtrl.stop();
    setState(() => _countdown = 3);
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown = (_countdown ?? 3) - 1;
        if ((_countdown ?? 0) <= 0) {
          t.cancel();
          _triggerSOS();
        }
      });
    });
  }

  void _onPressEnd() {
    _countTimer?.cancel();
    setState(() => _countdown = null);
    _pulseCtrl.repeat(reverse: true);
  }

  // ── Get GPS → send SOS ───────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) { return null; }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('SOSScreen: get GPS location failed: $e');
      return null;
    }
  }

  Future<void> _triggerSOS() async {
    _countTimer?.cancel();
    setState(() { _sending = true; _countdown = null; });
    final sosProvider = context.read<SosProvider>();
    final pos = await _getLocation();
    // Lưu GPS local trước để hiển thị dù API có lỗi
    if (mounted) {
      setState(() {
        _localLat = pos?.latitude;
        _localLng = pos?.longitude;
      });
    }
    try {
      final alertId = await sosProvider.sendSos(
        message:   'SOS khẩn cấp từ ứng dụng Family Care',
        address:   pos != null
            ? 'GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
            : '',
        latitude:  pos?.latitude,
        longitude: pos?.longitude,
      );
      // Chỉ chuyển sang "đã gửi" khi API xác nhận thành công
      if (mounted) {
        setState(() { _sent = true; _sending = false; _apiOk = true; _sentAlertId = alertId; });
      }
    } catch (e) {
      // API thất bại → KHÔNG báo thành công, show lỗi để user biết
      // (kèm tọa độ GPS để user có thể chia sẻ thủ công)
      if (mounted) {
        setState(() { _sending = false; });
        _pulseCtrl.repeat(reverse: true);
        _showSosFailDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSosFailDialog(String reason) {
    final hasGps = _localLat != null && _localLng != null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('Không gửi được SOS',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gia đình chưa nhận được cảnh báo. Hãy liên hệ trực tiếp.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          if (hasGps) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📍 Vị trí của bạn:',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  '${_localLat!.toStringAsFixed(5)}, ${_localLng!.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Text('Lỗi: $reason',
              style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white38)),
        ]),
        actions: [
          if (hasGps)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openMaps(_localLat!, _localLng!, 'Vị trí của tôi');
              },
              child: Text('Mở Maps',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF1A73E8),
                      fontWeight: FontWeight.w700)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Đóng',
                style: GoogleFonts.inter(
                    color: AppColors.sos,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Đóng màn hình "đã gửi": người gửi tự xác nhận an toàn (confirm-safety),
  // không phải hủy SOS — mọi thành viên đều được phép tự xác nhận, khác với
  // /cancel và /resolve vốn chỉ Manager/Deputy mới có quyền.
  Future<void> _cancelSOS() async {
    final sosState = context.read<SosProvider>();
    if (sosState.sending) return;
    final id = _sentAlertId;
    if (id == null) {
      // Không có alertId hợp lệ → không thể xác nhận an toàn, giữ màn hình.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không xác định được cảnh báo, vui lòng thử lại.'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }
    try {
      await sosState.confirmSafety(id);
      if (mounted) setState(() => _sent = false);
    } catch (e) {
      debugPrint('SOSScreen: confirmSafety failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Xác nhận an toàn thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_sending) return _loadingScreen();
    if (_sent)    return _sentScreen(context);

    final activeAlerts = context.watch<SosProvider>().activeAlerts;
    if (activeAlerts.isNotEmpty) {
      return _incomingAlertsScreen(context, activeAlerts);
    }
    return _sosButton(context);
  }

  // ── SOS button screen (member / sender) ──────────────────────────────────

  Widget _sosButton(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sos.withValues(alpha: 0.12)),
              ),
            ),
          ),
          Column(children: [
            _appBar(context),
            Expanded(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                        scale: _ring3.value,
                        child: _ring(290,
                            AppColors.sos.withValues(alpha: 0.3))),
                    Transform.scale(
                        scale: _ring2.value,
                        child: _ring(240,
                            AppColors.sos.withValues(alpha: 0.3))),
                    Transform.scale(
                        scale: _ring1.value,
                        child: _ring(190,
                            AppColors.sos.withValues(alpha: 0.3))),
                    GestureDetector(
                      onTapDown:   (_) => _onPressStart(),
                      onTapUp:     (_) => _onPressEnd(),
                      onTapCancel: _onPressEnd,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.sos),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🚨',
                                  style: TextStyle(fontSize: 40)),
                              Text('SOS',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 2)),
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: _countdown != null
                  ? Text('$_countdown',
                      style: GoogleFonts.inter(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger))
                  : Column(children: [
                      Text('KHẨN CẤP',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                              letterSpacing: 3)),
                      Text('Giữ 3 giây để gửi SOS',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.white38)),
                    ]),
            ),
            // Emergency call buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Liên hệ khẩn: ',
                      style:
                          GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
                  ...['113', '115', '114'].map((n) => GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:$n')),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: Colors.white24)),
                          child: Text(n,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      )),
                ],
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Manager: incoming alert list ─────────────────────────────────────────

  Widget _incomingAlertsScreen(
      BuildContext context, List<SosAlert> alerts) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              _backBtn(context),
              Expanded(
                child: Center(
                  child: Text('Cảnh báo khẩn cấp 🚨',
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sos)),
                ),
              ),
              GestureDetector(
                onTap: () => context.read<SosProvider>().fetchAlerts(),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white54, size: 20),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: alerts.length,
              itemBuilder: (_, i) => _alertCard(context, alerts[i]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _alertCard(BuildContext context, SosAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sos.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.sos.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.sos),
            alignment: Alignment.center,
            child: const Text('🚨', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.senderName,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(alert.createdAt,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white38)),
                ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.sos,
                borderRadius: BorderRadius.circular(8)),
            child: Text(alert.status,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 12),

        Text(alert.message,
            style:
                GoogleFonts.inter(fontSize: 14, color: Colors.white70)),

        // Location row
        if (alert.address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_rounded,
                size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            Expanded(
              child: Text(alert.address,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white38)),
            ),
          ]),
        ],

        // ── Google Maps button ────────────────────────────────────────
        if (alert.hasLocation) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8), // Google blue
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => _openMaps(
                  alert.latitude!, alert.longitude!, alert.senderName),
              icon: const Text('🗺️', style: TextStyle(fontSize: 16)),
              label: Text('Mở vị trí trên Google Maps',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Action buttons
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final sos = context.read<SosProvider>();
                if (sos.sending) return;
                try {
                  await sos.respond(alert.id, 'VIEWED', message: 'Tôi đang đến');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Đã phản hồi SOS ✅'),
                          backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Phản hồi thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: AppColors.danger,
                    ));
                  }
                }
              },
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('✅ Tôi đang đến',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
          // Chỉ Manager/Deputy được phép resolve (theo Swagger: PATCH
          // .../resolve chỉ FAMILY_MANAGER/DEPUTY_MEMBER).
          if (context.watch<AuthProvider>().user?.canResolveSos == true) ...[
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final sos = context.read<SosProvider>();
                  if (sos.sending) return;
                  try {
                    await sos.resolveAlert(alert.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Xử lý thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  }
                },
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24)),
                  alignment: Alignment.center,
                  child: Text('Đã xử lý',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60)),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  // ── Open Google Maps ─────────────────────────────────────────────────────

  Future<void> _openMaps(
      double lat, double lng, String label) async {
    // geo: URI opens Google Maps on Android; fallback to https URL
    final geoUri  = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webUri  = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Loading / Sent screens ───────────────────────────────────────────────

  Widget _loadingScreen() => Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                    color: AppColors.sos, strokeWidth: 3),
                const SizedBox(height: 24),
                Text('Đang gửi SOS...',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text('Đang lấy vị trí GPS…',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white38)),
              ]),
        ),
      );

  Widget _sentScreen(BuildContext context) {
    final hasGps = _localLat != null && _localLng != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚨', style: TextStyle(fontSize: 80)),
                  Text('SOS đã gửi!',
                      style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    _apiOk
                        ? 'Thông báo đã gửi đến gia đình'
                        : 'Đã ghi nhận — thành viên đang được thông báo',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),

                  // GPS coordinates
                  if (hasGps) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              '${_localLat!.toStringAsFixed(5)}, ${_localLng!.toStringAsFixed(5)}',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.white70),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    // Mở Maps từ máy gửi
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => _openMaps(
                            _localLat!, _localLng!, 'Vị trí của tôi'),
                        icon: const Text('🗺️',
                            style: TextStyle(fontSize: 16)),
                        label: Text('Chia sẻ vị trí qua Google Maps',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text('Không lấy được GPS',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white38)),
                  ],

                  if (!_apiOk) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4))),
                      child: Text('⚠️ Chức năng SOS đang chờ BE triển khai',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.amber.shade200),
                          textAlign: TextAlign.center),
                    ),
                  ],

                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _cancelSOS,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.danger, width: 2)),
                      child: Text('Đóng',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _appBar(BuildContext context) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          _backBtn(context),
          Expanded(
            child: Center(
              child: Text('Khẩn cấp',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54)),
            ),
          ),
          const SizedBox(width: 40),
        ]),
      );

  Widget _backBtn(BuildContext context) => GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1)),
          alignment: Alignment.center,
          child: const Text('←',
              style: TextStyle(fontSize: 20, color: Colors.white)),
        ),
      );

  static Widget _ring(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1)),
      );
}
