import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/json_report_view.dart';

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
  Timer? _locationStreamTimer; // gửi vị trí định kỳ trong lúc alert đang active
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
    _locationStreamTimer?.cancel();
    super.dispose();
  }

  // Gửi vị trí mỗi 20s cho tới khi alert được đóng (confirm-safety) hoặc màn
  // hình bị huỷ — POST .../sos/alerts/{alertId}/locations (xem SosProvider).
  // "2026-07-10T15:18:52.190Z" → "10/07 22:18" (giờ máy) cho dễ đọc
  static String _fmtAlertTime(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _startLocationStreaming(String alertId) {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final pos = await _getLocation();
      if (pos == null || !mounted) return;
      await context.read<SosProvider>().pushLocation(
            alertId, pos.latitude, pos.longitude,
            accuracy: pos.accuracy,
          );
    });
  }

  void _stopLocationStreaming() {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = null;
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

  // Nguyên tắc: GPS KHÔNG ĐƯỢC chặn việc gửi SOS — CreateSosAlertDto không
  // bắt buộc tọa độ. getCurrentPosition trên emulator/fused provider có thể
  // treo vô hạn chờ fix mới (timeLimit của geolocator không phải lúc nào cũng
  // nhả) → bọc timeout cứng + fallback getLastKnownPosition.
  Future<Position?> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) { return null; }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        // Không lấy được fix mới trong 10s → dùng vị trí gần nhất đã biết
        // (trả về ngay, không chờ) — vẫn hơn là không có gì.
        return await Geolocator.getLastKnownPosition()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      }
    } catch (e) {
      debugPrint('SOSScreen: get GPS location failed: $e');
      return null;
    }
  }

  Future<void> _triggerSOS() async {
    _countTimer?.cancel();
    setState(() { _sending = true; _countdown = null; });
    final sosProvider = context.read<SosProvider>();
    // Chốt chặn cuối: dù _getLocation có kẹt ở tầng platform channel thì SOS
    // vẫn phải được gửi đi sau tối đa 15s (không có tọa độ cũng gửi).
    final pos = await _getLocation()
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
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
        _startLocationStreaming(alertId);
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
      _stopLocationStreaming();
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
                  Text(_fmtAlertTime(alert.createdAt),
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
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showAlertDetail(context, alert.id),
            child: const Icon(Icons.info_outline_rounded,
                size: 18, color: Colors.white54),
          ),
        ]),
        const SizedBox(height: 12),

        Text(alert.message,
            style:
                GoogleFonts.inter(fontSize: 14, color: Colors.white70)),

        // Alert đã đóng: hiện ai xử lý + ghi chú
        if (!alert.isActive && (alert.resolvedByName != null || alert.resolutionNote != null)) ...[
          const SizedBox(height: 8),
          Text(
            '✔ ${alert.resolvedByName ?? 'Đã xử lý'}${(alert.resolutionNote ?? '').isNotEmpty ? ': ${alert.resolutionNote}' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic),
          ),
        ],

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

        // ── Mini-map inline (flutter_map + OSM) ─────────────────────
        if (alert.hasLocation) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(alert.latitude!, alert.longitude!),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none, // Không cho scroll/zoom để không chiếm gesture
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.familycare.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(alert.latitude!, alert.longitude!),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.sos,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                              ),
                              child: const Center(
                                child: Text('🚨', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Overlay nút mở bản đồ lớn trong app (thay thế Google Maps ngoài)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        final current = await context
                            .read<SosProvider>()
                            .fetchCurrentLocation(alert.id);
                        final lat = current?.lat ?? alert.latitude!;
                        final lng = current?.lng ?? alert.longitude!;
                        if (context.mounted) {
                          context.push('/map?lat=$lat&lng=$lng');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🗺️', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text('Bản đồ lớn',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A73E8))),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
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

  void _showAlertDetail(BuildContext context, String alertId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _SosAlertDetailSheet(alertId: alertId),
    );
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
                    // Inline Mini Map
                    Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_localLat!, _localLng!),
                            initialZoom: 15.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.familycare.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_localLat!, _localLng!),
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.sos,
                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                                    ),
                                    child: const Center(
                                      child: Text('🚨', style: TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Mở Bản đồ lớn in-app
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
                        onPressed: () {
                          context.push('/map?lat=$_localLat&lng=$_localLng');
                        },
                        icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                        label: Text('Xem bản đồ lớn in-app',
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

// GET /families/{familyId}/sos/alerts/{alertId} — chi tiết đầy đủ (phản hồi
// + vị trí lịch sử) — list chỉ trả tóm tắt.
class _SosAlertDetailSheet extends StatefulWidget {
  final String alertId;
  const _SosAlertDetailSheet({required this.alertId});
  @override
  State<_SosAlertDetailSheet> createState() => _SosAlertDetailSheetState();
}

class _SosAlertDetailSheetState extends State<_SosAlertDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await context.read<SosProvider>().fetchAlertDetail(widget.alertId);
      if (mounted) setState(() { _detail = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  // ── Parse phòng thủ (response schema chi tiết KHÔNG được Swagger document —
  //    [VERIFY] với Nghĩa; đọc nhiều key fallback để không vỡ khi field đổi tên).

  static String? _memberName(dynamic m) {
    if (m is! Map) return null;
    final d = m['displayName']?.toString();
    if (d != null && d.isNotEmpty) return d;
    final u = m['user'];
    if (u is Map) {
      final f = u['fullName']?.toString();
      if (f != null && f.isNotEmpty) return f;
    }
    final flat = m['fullName']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _fmtTime(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  List<Map> _responses(Map<String, dynamic> d) {
    for (final key in ['responses', 'sosResponses', 'alertResponses']) {
      final v = d[key];
      if (v is List) return v.whereType<Map>().toList();
    }
    return const [];
  }

  ({double lat, double lng})? _location(Map<String, dynamic> d) {
    // Ưu tiên điểm vị trí mới nhất trong mảng locations, fallback toạ độ alert.
    for (final key in ['locations', 'sosLocations']) {
      final v = d[key];
      if (v is List && v.isNotEmpty) {
        final last = v.whereType<Map>().toList();
        if (last.isNotEmpty) {
          final lat = _d(last.last['latitude']);
          final lng = _d(last.last['longitude']);
          if (lat != null && lng != null) return (lat: lat, lng: lng);
        }
      }
    }
    final lat = _d(d['latitude'] ?? d['initialLatitude']);
    final lng = _d(d['longitude'] ?? d['initialLongitude']);
    if (lat != null && lng != null) return (lat: lat, lng: lng);
    return null;
  }

  // Ánh xạ loại phản hồi → (emoji, màu nền node, nhãn hiển thị). Phân biệt
  // "Đang đến" (VIEWED + message chứa "đang đến") với "Đã xem" như bản v0.
  ({String emoji, Color color, String label}) _nodeStyle(String type, String message) {
    final t = type.toUpperCase();
    final onWay = message.toLowerCase().contains('đang đến');
    switch (t) {
      case 'VIEWED':
        return onWay
            ? (emoji: '🚗', color: AppColors.safe, label: 'Đang đến')
            : (emoji: '👀', color: AppColors.avatarBlue, label: 'Đã xem');
      case 'NEED_HELP':
        return (emoji: '🆘', color: AppColors.sos, label: 'Cần trợ giúp');
      case 'CONFIRM_SAFE':
        return (emoji: '✅', color: AppColors.safe, label: 'Đã an toàn');
      case 'RESOLVED':
        return (emoji: '✔', color: AppColors.safe, label: 'Đã xử lý');
      case 'CANCELED':
        return (emoji: '✖', color: AppColors.textMuted, label: 'Đã hủy');
      default:
        return (emoji: '•', color: AppColors.textSecondary, label: type.isEmpty ? 'Phản hồi' : type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Grabber
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: AppColors.progressTrack,
              borderRadius: BorderRadius.circular(999)),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
          )
        else
          Flexible(child: SingleChildScrollView(child: _content(_detail ?? {}))),
      ]),
    );
  }

  Widget _content(Map<String, dynamic> d) {
    final sender = _memberName(d['triggeredByMember']) ??
        _memberName(d['sender']) ??
        _memberName(d['triggeredBy']) ??
        d['senderName']?.toString() ??
        'Thành viên';
    final status = (d['status']?.toString() ?? 'ACTIVE').toUpperCase();
    final createdAt = d['triggeredAt']?.toString() ?? d['createdAt']?.toString() ?? '';
    final message = d['message']?.toString() ?? '';
    final address = d['address']?.toString() ?? '';
    final loc = _location(d);
    final responses = _responses(d);
    final resolvedBy = _memberName(d['resolvedByMember']);
    final resolutionNote = d['resolutionNote']?.toString();

    final isActive = status == 'ACTIVE';
    final statusColor = isActive
        ? AppColors.sos
        : (status == 'RESOLVED' ? AppColors.safe : AppColors.textMuted);
    final statusLabel = isActive
        ? 'ĐANG KHẨN CẤP'
        : (status == 'RESOLVED' ? 'ĐÃ XỬ LÝ' : (status == 'CANCELED' ? 'ĐÃ HỦY' : status));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header đỏ gradient (v0 style) ──────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('🚨', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SOS từ $sender',
                    style: GoogleFonts.inter(
                        fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                if (createdAt.isNotEmpty)
                  Text('Lúc ${_fmtTime(createdAt)}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
          ]),
        ]),
      ),

      Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.isNotEmpty) ...[
            Text(message, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
          ],

          // ── Vị trí ────────────────────────────────────────────────────
          if (address.isNotEmpty || loc != null) ...[
            Text('Vị trí',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.progressTrack)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (address.isNotEmpty)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on_rounded, size: 18, color: AppColors.avatarBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(address,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
                  ]),
                if (loc != null) ...[
                  if (address.isNotEmpty) const SizedBox(height: 8),
                  Text('Tọa độ: ${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(loc.lat, loc.lng),
                          initialZoom: 15,
                          interactionOptions:
                              const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.familycare.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(loc.lat, loc.lng),
                              width: 40, height: 40,
                              child: Container(
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: AppColors.sos,
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]),
                                child: const Center(child: Text('🚨', style: TextStyle(fontSize: 18))),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // ── Response Timeline (điểm chính lấy từ v0) ───────────────────
          Text('Diễn biến phản hồi',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _timelineNode(
            emoji: '🚨', color: AppColors.sos,
            title: 'SOS được gửi', subtitle: sender,
            time: createdAt.isNotEmpty ? _fmtTime(createdAt) : null,
            isLast: responses.isEmpty && status == 'ACTIVE',
          ),
          for (int i = 0; i < responses.length; i++)
            _responseNode(responses[i], isLast: i == responses.length - 1 && status == 'ACTIVE'),
          if (status == 'RESOLVED' || status == 'CANCELED')
            _timelineNode(
              emoji: status == 'RESOLVED' ? '✔' : '✖',
              color: status == 'RESOLVED' ? AppColors.safe : AppColors.textMuted,
              title: status == 'RESOLVED' ? 'Đã xử lý' : 'Đã hủy',
              subtitle: [resolvedBy, resolutionNote].where((e) => (e ?? '').isNotEmpty).join(' · '),
              time: null, isLast: true,
            ),
          if (responses.isEmpty && status == 'ACTIVE') ...[
            const SizedBox(height: 4),
            Text('Chưa có phản hồi nào',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ],

          const SizedBox(height: 20),
          // Status badge chip
          Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Trạng thái: $statusLabel',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
          ]),

          // ── Dữ liệu kỹ thuật (giữ JsonReportView làm fallback [VERIFY]) ──
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              title: Text('Dữ liệu kỹ thuật (schema [VERIFY])',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              children: [JsonReportView(data: d)],
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _responseNode(Map r, {required bool isLast}) {
    final type = (r['responseType'] ?? r['type'] ?? '').toString();
    final msg = (r['message'] ?? '').toString();
    final time = (r['respondedAt'] ?? r['createdAt'] ?? r['timestamp'] ?? '').toString();
    // Field chuẩn theo Swagger (SosResponseResponseDto, verify 2026-07-16):
    // responderMember {displayName, user.fullName} — đặt ĐẦU chuỗi fallback.
    final who = _memberName(r['responderMember']) ??
        _memberName(r['respondedByMember']) ??
        _memberName(r['member']) ??
        _memberName(r['respondedBy']) ??
        _memberName(r['user']) ??
        r['memberName']?.toString() ??
        'Thành viên';
    final s = _nodeStyle(type, msg);
    final subtitle = msg.isNotEmpty ? '$who · $msg' : who;
    return _timelineNode(
      emoji: s.emoji, color: s.color,
      title: s.label, subtitle: subtitle,
      time: time.isNotEmpty ? _fmtTime(time) : null,
      isLast: isLast,
    );
  }

  Widget _timelineNode({
    required String emoji,
    required Color color,
    required String title,
    String? subtitle,
    String? time,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2, color: AppColors.progressTrack)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(time,
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
