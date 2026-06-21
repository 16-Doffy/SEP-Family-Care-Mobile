import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Polyline;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});
  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  final _mapCtrl = MapController();

  LatLng? _myPos;
  bool    _locating = false;
  String? _locError;

  // Thành viên với vị trí đã biết (từ SOS alert hoặc location API)
  final List<_MemberPin> _pins = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateMe(center: true);
    });
  }

  // ── Lấy GPS thiết bị ────────────────────────────────────────────────────

  Future<void> _locateMe({bool center = false}) async {
    setState(() { _locating = true; _locError = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() => _locError = 'Chưa cấp quyền GPS');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final me = context.read<AuthProvider>().user;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myPos = latlng;
        // Cập nhật hoặc thêm pin của bản thân
        _pins.removeWhere((p) => p.isMe);
        _pins.add(_MemberPin(
          latlng:  latlng,
          name:    me?.name ?? 'Tôi',
          isMe:    true,
          isSos:   false,
          accuracy: pos.accuracy,
        ));
      });
      if (center) {
        _mapCtrl.move(latlng, 15);
      }
    } catch (e) {
      if (mounted) setState(() => _locError = 'Không lấy được GPS: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Reload SOS pins khi provider thay đổi (không setState — chỉ sync list)
    final alerts = context.watch<SosProvider>().activeAlerts;
    for (final a in alerts) {
      if (a.hasLocation && !_pins.any((p) => p.alertId == a.id)) {
        _pins.add(_MemberPin(
          latlng:  LatLng(a.latitude!, a.longitude!),
          name:    '🚨 ${a.senderName}',
          isMe:    false,
          isSos:   true,
          alertId: a.id,
        ));
      }
    }

    final defaultCenter = _myPos ?? const LatLng(10.7769, 106.7009); // HCM
    final hasAnySos = _pins.any((p) => p.isSos);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: defaultCenter,
            initialZoom:   14,
            minZoom:       4,
            maxZoom:       18,
          ),
          children: [
            // OpenStreetMap tile — miễn phí
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.familycare.app',
              maxZoom: 18,
            ),
            // Markers
            MarkerLayer(markers: _pins.map(_buildMarker).toList()),
          ],
        ),

        // ── App bar overlay ─────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _roundBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(children: [
                    const Text('🗺️',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bản đồ gia đình',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    if (_locating)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary500)),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // ── SOS active banner ────────────────────────────────────────────
        if (hasAnySos)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.sos,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.sos.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(children: [
                const Text('🚨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pins.where((p) => p.isSos).length == 1
                        ? '${_pins.firstWhere((p) => p.isSos).name} đang cần trợ giúp!'
                        : '${_pins.where((p) => p.isSos).length} người đang cần trợ giúp!',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final sosPin =
                        _pins.firstWhere((p) => p.isSos);
                    _mapCtrl.move(sosPin.latlng, 16);
                  },
                  child: Text('Xem →',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                ),
              ]),
            ),
          ),

        // ── Legend / member list ─────────────────────────────────────────
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: _MemberLegend(
            pins: _pins,
            onTap: (pin) => _mapCtrl.move(pin.latlng, 16),
          ),
        ),

        // ── FAB: locate me ───────────────────────────────────────────────
        Positioned(
          bottom: 32,
          right: 16,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _roundBtn(
                  icon:  Icons.my_location_rounded,
                  color: AppColors.primary500,
                  onTap: () => _locateMe(center: true),
                  size:  52,
                ),
              ]),
        ),

        // ── GPS error snack ──────────────────────────────────────────────
        if (_locError != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_locError!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  // ── Marker builder ───────────────────────────────────────────────────────

  Marker _buildMarker(_MemberPin pin) {
    return Marker(
      point:  pin.latlng,
      width:  pin.isSos ? 70 : 60,
      height: pin.isSos ? 80 : 70,
      child:  _PinWidget(pin: pin),
    );
  }

  // ── Round button helper ──────────────────────────────────────────────────

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    double size = 44,
    Color iconColor = AppColors.textPrimary,
  }) {
    final isColored = color != Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size:  22,
            color: isColored ? Colors.white : iconColor),
      ),
    );
  }
}

// ── Pin widget on map ────────────────────────────────────────────────────────

class _PinWidget extends StatelessWidget {
  final _MemberPin pin;
  const _PinWidget({required this.pin});

  @override
  Widget build(BuildContext context) {
    final Color bg = pin.isSos
        ? AppColors.sos
        : pin.isMe
            ? AppColors.primary500
            : AppColors.avatarBlue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bubble
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: bg.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(
            pin.isMe ? '📍 Tôi' : pin.name,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Pointer
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(bg),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Member legend (bottom card) ──────────────────────────────────────────────

class _MemberLegend extends StatelessWidget {
  final List<_MemberPin> pins;
  final void Function(_MemberPin) onTap;
  const _MemberLegend({required this.pins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ]),
        child: Row(children: [
          const Text('📍', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nhấn 📍 bên dưới để hiển thị vị trí của bạn',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ]),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Thành viên trên bản đồ',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('OSM · Miễn phí',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            ...pins.map((pin) => GestureDetector(
                  onTap: () => onTap(pin),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pin.isSos
                              ? AppColors.sos
                              : pin.isMe
                                  ? AppColors.primary500
                                  : AppColors.avatarBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(pin.name,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                      ),
                      if (pin.accuracy != null)
                        Text(
                          '±${pin.accuracy!.round()}m',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted),
                        ),
                      if (pin.isSos) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.sos,
                              borderRadius:
                                  BorderRadius.circular(4)),
                          child: Text('SOS',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.textMuted),
                    ]),
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              '⚠️ Vị trí thành viên khác cần BE thêm API',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textMuted),
            ),
          ]),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _MemberPin {
  final LatLng  latlng;
  final String  name;
  final bool    isMe;
  final bool    isSos;
  final double? accuracy;
  final String? alertId;

  const _MemberPin({
    required this.latlng,
    required this.name,
    required this.isMe,
    required this.isSos,
    this.accuracy,
    this.alertId,
  });
}
