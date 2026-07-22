import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

class FamilyMapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const FamilyMapScreen({super.key, this.initialLat, this.initialLng});
  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  final _mapCtrl = MapController();

  LatLng? _myPos;
  double? _myAccuracy;
  bool    _locating = false;
  String? _locError;

  // Đẩy vị trí định kỳ khi đang bật chia sẻ + màn bản đồ đang mở. Chỉ chạy
  // trong lúc mở màn này (chưa có background service) — đủ cho luồng "cả nhà
  // cùng mở bản đồ xem nhau".
  static const _kPushInterval = Duration(seconds: 30);
  Timer? _pushTimer;

  // ── Chỉ đường A→B (A = vị trí của tôi, B = thành viên/điểm SOS) ──────────
  // Thuần FE, KHÔNG cần BE: vẽ ngay đường thẳng (tính offline bằng latlong2)
  // rồi nâng cấp lên tuyến đường bộ thật lấy từ OSRM public (không cần API
  // key). OSRM lỗi/không mạng → giữ nguyên đường thẳng, không vỡ tính năng.
  List<LatLng> _routePoints = const [];
  LatLng? _routeTarget;
  String? _routeLabel;
  double? _routeDistanceM;
  double? _routeDurationS;
  bool _routing = false;
  bool _routeIsRoad = false;

  String? get _myUserId => context.read<AuthProvider>().user?.id;

  static String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  static String _fmtDuration(double s) {
    final mins = (s / 60).round();
    if (mins < 1) return 'dưới 1 phút';
    if (mins < 60) return '$mins phút';
    return '${mins ~/ 60} giờ ${mins % 60} phút';
  }

  Future<void> _routeTo(LatLng target, {String? label}) async {
    if (_myPos == null) await _locateMe(center: false);
    final from = _myPos;
    if (from == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cần vị trí của bạn để chỉ đường — bật GPS rồi thử lại'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    // Điểm đến trùng vị trí của mình (vd mở bản đồ từ cảnh báo do CHÍNH MÌNH
    // phát) → chỉ đường vô nghĩa ("0 m"). Bỏ qua, báo nhẹ.
    final selfDistance =
        const Distance().as(LengthUnit.Meter, from, target).toDouble();
    if (selfDistance < 50) {
      if (!mounted) return;
      _clearRoute();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bạn đang ở ngay tại điểm này'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    if (!mounted) return;
    setState(() {
      _routing = true;
      _routeTarget = target;
      _routeLabel = label;
      // Đường thẳng hiển thị tức thì (không chờ mạng).
      _routePoints = [from, target];
      _routeIsRoad = false;
      _routeDistanceM =
          const Distance().as(LengthUnit.Meter, from, target).toDouble();
      _routeDurationS = null;
    });
    _fitRoute();

    // Nâng cấp lên tuyến đường bộ thật. Gọi trực tiếp bằng http (KHÔNG dùng
    // ApiClient) để không gửi Bearer token của mình sang dịch vụ bên thứ ba.
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${target.longitude},${target.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final routes = body is Map ? body['routes'] : null;
        if (routes is List && routes.isNotEmpty && routes.first is Map) {
          final r = routes.first as Map;
          final coords = (r['geometry'] as Map?)?['coordinates'];
          if (coords is List && coords.length >= 2) {
            final pts = coords
                .whereType<List>()
                .where((c) => c.length >= 2 && c[0] is num && c[1] is num)
                .map((c) => LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    ))
                .toList();
            if (pts.length >= 2 && mounted) {
              setState(() {
                _routePoints = pts;
                _routeIsRoad = true;
                _routeDistanceM =
                    (r['distance'] as num?)?.toDouble() ?? _routeDistanceM;
                _routeDurationS = (r['duration'] as num?)?.toDouble();
              });
              _fitRoute();
            }
          }
        }
      }
    } catch (e) {
      // Giữ đường thẳng — vẫn dùng được để định hướng.
      debugPrint('Route: OSRM thất bại, dùng đường thẳng: $e');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _fitRoute() {
    if (_routePoints.length < 2) return;
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints),
        padding: const EdgeInsets.fromLTRB(50, 90, 50, 220),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = const [];
      _routeTarget = null;
      _routeLabel = null;
      _routeDistanceM = null;
      _routeDurationS = null;
      _routeIsRoad = false;
    });
  }

  // Mở app điều hướng ngoài (turn-by-turn thật) tới điểm đến hiện tại.
  Future<void> _openExternalNav() async {
    final t = _routeTarget;
    if (t == null) return;
    final geo = Uri.parse('google.navigation:q=${t.latitude},${t.longitude}');
    final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFamilyLocations();
      if (widget.initialLat != null && widget.initialLng != null) {
        // Vào từ cảnh báo SOS → tự vẽ đường từ vị trí của tôi tới điểm SOS.
        final target = LatLng(widget.initialLat!, widget.initialLng!);
        _mapCtrl.move(target, 16);
        _locateMe(center: false).then((_) {
          if (mounted) _routeTo(target, label: 'Điểm SOS');
        });
      } else {
        _locateMe(center: true);
      }
      _syncPushTimer();
    });
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    super.dispose();
  }

  // Bật timer khi đang chia sẻ, tắt khi không.
  void _syncPushTimer() {
    if (!mounted) return;
    final sharing = context.read<GpsProvider>().mySharing;
    _pushTimer?.cancel();
    if (!sharing) return;
    _pushMyLocationNow();
    _pushTimer = Timer.periodic(_kPushInterval, (_) => _pushMyLocationNow());
  }

  Future<void> _pushMyLocationNow() async {
    if (!mounted) return;
    final gps = context.read<GpsProvider>();
    if (!gps.mySharing) return;
    final pos = _myPos;
    if (pos == null) return;
    await gps.updateLocation(
      pos.latitude,
      pos.longitude,
      accuracy: _myAccuracy ?? 18,
      silent: true, // timer nền — không nhấp nháy UI
    );
  }

  Future<void> _toggleSharing(bool value) async {
    final gps = context.read<GpsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await gps.toggleSharing(value, myUserId: _myUserId);
      if (!mounted) return;
      _syncPushTimer();
      messenger.showSnackBar(SnackBar(
        content: Text(value
            ? 'Đã bật chia sẻ vị trí với gia đình'
            : 'Đã tắt chia sẻ vị trí'),
        backgroundColor: value ? AppColors.safe : AppColors.textMuted,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Không đổi được chia sẻ vị trí: '
            '${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _refreshFamilyLocations() async {
    await Future.wait([
      context.read<GpsProvider>().fetchFamilyLocations(myUserId: _myUserId),
      context.read<SosProvider>().fetchAlerts(),
    ]);
  }

  Future<void> _refreshMap() async {
    setState(() => _locError = null);
    await Future.wait([
      _refreshFamilyLocations(),
      _locateMe(center: false),
    ]);
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
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myPos = latlng;
        _myAccuracy = pos.accuracy;
        // _buildPins() tự tạo lại pin "Tôi" từ _myPos/_myAccuracy mỗi lần
        // rebuild — không còn giữ danh sách pin trong state (kiến trúc cũ _pins).
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
    final auth = context.watch<AuthProvider>();
    final gps = context.watch<GpsProvider>();
    final alerts = context.watch<SosProvider>().activeAlerts;
    final pins = _buildPins(auth.user?.id, gps.shares, alerts);

    final defaultCenter = _myPos ?? const LatLng(10.7769, 106.7009); // HCM
    final hasAnySos = pins.any((p) => p.isSos);

    return Scaffold(
      backgroundColor: context.colors.background,
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
            // Đường chỉ dẫn A→B vẽ DƯỚI marker để không che pin.
            if (_routePoints.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: _routePoints,
                  color: AppColors.link,
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: pins.map(_buildMarker).toList()),
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
                    if (_locating || gps.loading)
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
                    pins.where((p) => p.isSos).length == 1
                        ? '${pins.firstWhere((p) => p.isSos).name} đang cần trợ giúp!'
                        : '${pins.where((p) => p.isSos).length} người đang cần trợ giúp!',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final sosPin =
                        pins.firstWhere((p) => p.isSos);
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

        // ── Banner tuyến đường + Legend / member list ────────────────────
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_routePoints.length >= 2) ...[
              _routeBanner(),
              const SizedBox(height: 8),
            ],
            _MemberLegend(
              pins: pins,
              loading: gps.loading,
              error: gps.error,
              sharingUnavailable: gps.sharingUnavailable,
              sharing: gps.mySharing,
              busy: gps.busy,
              onToggleSharing: _toggleSharing,
              onTap: (pin) {
                _mapCtrl.move(pin.latlng, 16);
                _showPinDetail(pin);
              },
            ),
          ]),
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
                  icon:  Icons.refresh_rounded,
                  onTap: _refreshMap,
                  size:  48,
                ),
                const SizedBox(height: 10),
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

  // Banner tuyến đường: khoảng cách + thời gian + mở điều hướng ngoài.
  Widget _routeBanner() {
    final d = _routeDistanceM;
    final t = _routeDurationS;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.link.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Icon(_routeIsRoad ? Icons.directions_rounded : Icons.timeline_rounded,
            size: 20, color: AppColors.link),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đường tới ${_routeLabel ?? 'điểm đã chọn'}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (d != null) _fmtDistance(d),
                    if (t != null) '~${_fmtDuration(t)}',
                    if (_routing)
                      'đang tìm đường…'
                    else if (!_routeIsRoad)
                      'đường chim bay',
                  ].join(' · '),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
        ),
        IconButton(
          tooltip: 'Mở điều hướng ngoài',
          onPressed: _openExternalNav,
          icon: const Icon(Icons.navigation_rounded,
              size: 20, color: AppColors.link),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: 'Bỏ chỉ đường',
          onPressed: _clearRoute,
          icon: const Icon(Icons.close_rounded,
              size: 18, color: AppColors.textMuted),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  // ── Marker builder ───────────────────────────────────────────────────────

  List<_MemberPin> _buildPins(
    String? currentUserId,
    List<LocationShare> shares,
    List<SosAlert> alerts,
  ) {
    final pins = <_MemberPin>[];
    if (_myPos != null) {
      pins.add(_MemberPin(
        latlng: _myPos!,
        name: context.read<AuthProvider>().user?.name ?? 'Tôi',
        isMe: true,
        isSos: false,
        accuracy: _myAccuracy,
      ));
    }

    for (final share in shares) {
      if (share.latitude == null || share.longitude == null) continue;
      if (share.userId.isNotEmpty && share.userId == currentUserId) continue;
      pins.add(_MemberPin(
        latlng: LatLng(share.latitude!, share.longitude!),
        name: share.displayName,
        isMe: false,
        isSos: false,
        userId: share.userId,
        updatedAt: share.updatedAt,
      ));
    }

    for (final alert in alerts) {
      if (!alert.hasLocation) continue;
      // Cảnh báo do CHÍNH MÌNH phát: pin "Tôi" (GPS trực tiếp, chính xác hơn)
      // đã đại diện vị trí này rồi → không thêm pin SOS nữa, tránh cùng một
      // người hiện 2 lần trong danh sách.
      if (alert.isMine(currentUserId)) continue;
      pins.add(_MemberPin(
        latlng: LatLng(alert.latitude!, alert.longitude!),
        name: alert.senderName,
        isMe: false,
        isSos: true,
        alertId: alert.id,
      ));
    }
    return pins;
  }

  Marker _buildMarker(_MemberPin pin) {
    return Marker(
      point:  pin.latlng,
      width:  pin.isSos ? 70 : 60,
      height: pin.isSos ? 80 : 70,
      child:  GestureDetector(
        onTap: () => _showPinDetail(pin),
        child: _PinWidget(pin: pin),
      ),
    );
  }

  void _showPinDetail(_MemberPin pin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pin.color,
                ),
                alignment: Alignment.center,
                child: Icon(
                  pin.isSos
                      ? Icons.sos_rounded
                      : pin.isMe
                          ? Icons.my_location_rounded
                          : Icons.person_pin_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pin.title,
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text(pin.subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            _detailRow(Icons.location_on_rounded, 'Tọa độ',
                '${pin.latlng.latitude.toStringAsFixed(5)}, ${pin.latlng.longitude.toStringAsFixed(5)}'),
            if (pin.accuracy != null)
              _detailRow(Icons.gps_fixed_rounded, 'Độ chính xác',
                  '±${pin.accuracy!.round()}m'),
            if (pin.updatedAt != null && pin.updatedAt!.isNotEmpty)
              _detailRow(Icons.schedule_rounded, 'Cập nhật',
                  _fmtDateTime(pin.updatedAt!)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pin.color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _mapCtrl.move(pin.latlng, pin.isSos ? 16 : 15);
                },
                icon: const Icon(Icons.center_focus_strong_rounded,
                    color: Colors.white, size: 18),
                label: Text('Đưa vào giữa bản đồ',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            // Chỉ đường tới thành viên khác / điểm SOS (không cần với pin của
            // chính mình).
            if (!pin.isMe) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.link),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _routeTo(pin.latlng, label: pin.name);
                  },
                  icon: const Icon(Icons.directions_rounded,
                      color: AppColors.link, size: 18),
                  label: Text('Chỉ đường tới đây',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.link)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }

  static String _fmtDateTime(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
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
    final Color bg = pin.color;

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
            pin.isMe ? '📍 Tôi' : pin.isSos ? '🚨 ${pin.name}' : pin.name,
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
  final bool loading;
  final String? error;
  final bool sharingUnavailable;
  final bool sharing;
  final bool busy;
  final void Function(bool) onToggleSharing;
  final void Function(_MemberPin) onTap;
  const _MemberLegend({
    required this.pins,
    required this.loading,
    required this.error,
    required this.sharingUnavailable,
    required this.sharing,
    required this.busy,
    required this.onToggleSharing,
    required this.onTap,
  });

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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
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
          // Vẫn phải cho bật chia sẻ ở trạng thái rỗng — nếu không user không
          // có cách nào bật để xuất hiện trên bản đồ nhà mình.
          Row(children: [
            Icon(
              sharing
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              size: 16,
              color: sharing ? AppColors.safe : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                sharing
                    ? 'Đang chia sẻ vị trí của bạn'
                    : 'Chia sẻ vị trí của bạn',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        sharing ? AppColors.safe : AppColors.textSecondary),
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: sharing,
                onChanged: busy ? null : onToggleSharing,
                activeThumbColor: AppColors.safe,
              ),
            ),
          ]),
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
              if (loading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
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
            const Row(children: [
              _LegendDot(color: AppColors.primary500, label: 'Tôi'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.avatarBlue, label: 'Gia đình'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.sos, label: 'SOS'),
            ]),
            // Bật/tắt chia sẻ vị trí của mình — khi bật, màn này đẩy vị trí
            // định kỳ 30s để các thành viên khác thấy mình trên bản đồ.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(
                  sharing
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 16,
                  color: sharing ? AppColors.safe : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sharing
                        ? 'Đang chia sẻ vị trí của bạn'
                        : 'Chia sẻ vị trí của bạn',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sharing
                            ? AppColors.safe
                            : AppColors.textSecondary),
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: sharing,
                    onChanged: busy ? null : onToggleSharing,
                    activeThumbColor: AppColors.safe,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
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
                      if (pin.updatedAt != null && !pin.isSos) ...[
                        Text(
                          _FamilyMapScreenState._fmtDateTime(pin.updatedAt!),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted),
                        ),
                      ],
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
            if (sharingUnavailable)
              Row(children: [
                const Text('🚧', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Chia sẻ vị trí gia đình đang được phát triển',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              ])
            else if (error != null)
              Text(
                error!.replaceFirst('Exception: ', ''),
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.danger),
              ),
          ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]);
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
  final String? userId;
  final String? updatedAt;

  const _MemberPin({
    required this.latlng,
    required this.name,
    required this.isMe,
    required this.isSos,
    this.accuracy,
    this.alertId,
    this.userId,
    this.updatedAt,
  });

  Color get color => isSos
      ? AppColors.sos
      : isMe
          ? AppColors.primary500
          : AppColors.avatarBlue;

  String get title => isMe ? 'Vị trí của tôi' : isSos ? 'SOS: $name' : name;

  String get subtitle => isSos
      ? 'Cảnh báo khẩn cấp'
      : isMe
          ? 'Thiết bị hiện tại'
          : 'Thành viên gia đình';
}
