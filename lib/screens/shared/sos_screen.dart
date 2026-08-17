import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../services/sos_location.dart';
import '../../services/sos_realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../utils/sos_alert_location.dart';
import '../../widgets/json_report_view.dart';
import 'sos_settings_screen.dart';

/// Path home theo role — cùng bảng ánh xạ với `computeRedirect`
/// (`app_router.dart`). Tách hàm thuần để unit test được.
String homePathForRole(UserRole? role) => switch (role) {
  UserRole.manager => '/manager/home',
  UserRole.deputy => '/deputy/home',
  _ => '/member/home',
};

/// Quay lại màn trước; nếu stack rỗng (mở thẳng từ lối tắt `/sos-quick` nên
/// đây là route duy nhất) thì về home theo role, vì `context.pop()` lúc đó
/// ném "There is nothing to pop".
void backOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(homePathForRole(context.read<AuthProvider>().user?.role));
}

class SOSScreen extends StatefulWidget {
  /// [autoTrigger] = mở từ **lối tắt ngoài màn hình chính** (route phẳng
  /// `/sos-quick`, xem `android/app/src/main/res/xml/shortcuts.xml`): tự chạy
  /// đếm ngược rồi gửi SOS, người dùng không phải giữ nút. Mặc định `false`
  /// cho nhánh shell `/{role}/sos` — giữ nguyên hành vi giữ-3-giây cũ.
  ///
  /// [immediate] = mở từ `EmergencySosWatcherService` (route phẳng
  /// `/sos-immediate`) khi hệ thống phát hiện màn Emergency SOS của máy đang
  /// chiếm màn hình — gửi SOS NGAY, bỏ qua đếm ngược 3 giây/nút hủy, vì lúc
  /// đó không hiện được UI đó cho người dùng thao tác. Không dùng chung với
  /// [autoTrigger].
  const SOSScreen({
    super.key,
    this.autoTrigger = false,
    this.immediate = false,
  });

  final bool autoTrigger;
  final bool immediate;

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

/// Đang đếm ngược tự động mà app bị đẩy xuống nền (tắt màn hình, bấm Home,
/// màn khóa bật lên) thì **phải gửi SOS ngay**, không chờ đếm hết.
///
/// Đo thực tế 11/08 trên OPPO CPH2159: tắt màn hình lúc đếm ngược còn ~2 giây
/// thì **người thân không nhận được gì** — Android bóp nghẹt tiến trình nền nên
/// `Timer` không bao giờ chạy tới 0. Cùng thao tác đó với màn hình sáng thì
/// người thân nhận ngay. Đây là kiểu hỏng tệ nhất cho tính năng khẩn cấp: im
/// lặng, không lỗi, người dùng tưởng đã báo được cho gia đình.
///
/// Người vừa bấm SOS rồi bỏ máy vào túi thì rõ ràng **không định bấm HỦY** —
/// nên gửi sớm vài giây là hành vi đúng, không phải đánh đổi.
///
/// Tách hàm thuần để unit test được (xem `test/sos_quick_shortcut_test.dart`).
bool shouldSendSosOnPause({
  required AppLifecycleState state,
  required bool autoCountdown,
  required int? countdown,
}) => state == AppLifecycleState.paused && autoCountdown && countdown != null;

bool shouldLockSosRouteExit({
  required bool autoTrigger,
  required bool immediate,
}) => autoTrigger || immediate;

bool shouldShowSenderSosFlow({
  required bool autoTrigger,
  required bool immediate,
  required bool autoCountdown,
  required int? countdown,
}) => autoTrigger || immediate || autoCountdown || countdown != null;

class _SOSScreenState extends State<SOSScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _sent = false;
  bool _sending = false;

  /// Đang đếm ngược **tự động** (vào từ lối tắt) chứ không phải do giữ nút.
  /// Khác biệt duy nhất: nhấc tay/chạm màn không hủy được, chỉ nút HỦY mới
  /// dừng — vì người dùng có bấm giữ gì đâu mà "thả ra".
  bool _autoCountdown = false;
  bool _apiOk = false; // true nếu BE nhận được SOS
  int? _countdown;
  Timer? _countTimer;
  double? _localLat, _localLng; // GPS lưu local khi API chưa có
  String? _sentAlertId; // id alert vừa tạo, để Đóng/confirm-safety đúng alert
  Timer? _locationStreamTimer; // gửi vị trí định kỳ trong lúc alert đang active
  bool _waitingTrackStart = false;
  // Điểm gửi lỗi (mất mạng tạm thời) được giữ lại để flush bằng
  // pushLocationBatch ở lần gửi thành công kế tiếp — tránh mất hẳn vị trí SOS
  // chỉ vì rớt mạng vài chục giây. Cap để không phình vô hạn nếu mất mạng dài.
  static const _maxPendingLocationPoints = 50;
  final List<({double lat, double lng, double? accuracy, DateTime? recordedAt})>
  _pendingLocationPoints = [];

  /// Một controller chạy 0→1 **không đảo chiều**: ba vòng sóng lấy cùng giá trị
  /// này nhưng lệch pha 1/3 nên lan ra nối tiếp nhau như radar, thay vì cùng
  /// phình ra thu vào. Lấy theo hiệu ứng nút SOS trên đồng hồ.
  late AnimationController _pulseCtrl;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _sosBg => context.colors.background;
  Color get _sosSurface => context.colors.surface;
  Color get _sosText => context.colors.textPrimary;
  Color get _sosSecondary => context.colors.textSecondary;
  Color get _sosMuted => context.colors.textMuted;
  Color get _sosControl => _dark
      ? Colors.white.withValues(alpha: 0.10)
      : AppColors.white.withValues(alpha: 0.96);
  Color get _sosControlBorder =>
      _dark ? Colors.white24 : AppColors.progressTrack.withValues(alpha: 0.9);
  bool get _lockRouteExit => shouldLockSosRouteExit(
    autoTrigger: widget.autoTrigger,
    immediate: widget.immediate,
  );
  bool get _showSenderSosFlow => shouldShowSenderSosFlow(
    autoTrigger: widget.autoTrigger,
    immediate: widget.immediate,
    autoCountdown: _autoCountdown,
    countdown: _countdown,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // Refresh alerts when manager opens screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosProvider>().fetchAlerts();
      // Danh bạ khẩn cấp của gia đình cho hàng nút gọi nhanh.
      context.read<SosProvider>().fetchEmergencyContacts();
      _attachSosRealtimeTrackingCallbacks();
      // Hệ thống phát hiện Emergency SOS đang chiếm màn hình → gửi thẳng,
      // không đếm ngược (không có UI nào hiện được lúc đó để người dùng hủy).
      if (widget.immediate && mounted) {
        _triggerSOS();
        return;
      }
      // Vào từ lối tắt → đếm ngược ngay, không chờ thao tác nào. Chạy sau
      // frame đầu để _pulseCtrl đã sẵn sàng cho _onPressStart().
      if (widget.autoTrigger && mounted) _startAutoCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final realtime = SosRealtimeService.instance;
    realtime.onTrackStart = null;
    realtime.onTrackStop = null;
    _pulseCtrl.dispose();
    _countTimer?.cancel();
    _locationStreamTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!shouldSendSosOnPause(
      state: state,
      autoCountdown: _autoCountdown,
      countdown: _countdown,
    )) {
      return;
    }
    // Chờ nốt đếm ngược là mất luôn cảnh báo — xem [shouldSendSosOnPause].
    _countTimer?.cancel();
    // Rút ngắn hạn chờ GPS: tiến trình sắp bị bóp nghẹt, chờ 15 giây như luồng
    // thường thì có khi không kịp gửi. Không có toạ độ vẫn phải gửi được.
    _triggerSOS(locationTimeout: const Duration(seconds: 3));
  }

  // BE realtime /sos sẽ bắn sos:track:start sau khi tạo alert. Khi đó FE gửi
  // vị trí qua sos:location:push theo intervalSec của server. REST 20s bên dưới
  // chỉ còn là fallback nếu socket không trả track:start hoặc socket rớt.
  // "2026-07-10T15:18:52.190Z" → "10/07 22:18" (giờ máy) cho dễ đọc
  static String _fmtAlertTime(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _attachSosRealtimeTrackingCallbacks() {
    final realtime = SosRealtimeService.instance;
    realtime.onTrackStart = _onSosTrackStart;
    realtime.onTrackStop = _onSosTrackStop;
    realtime.connect();
  }

  void _onSosTrackStart(SosTrackStartEvent event) {
    if (!mounted || event.alertId.isEmpty) return;
    final currentAlertId = _sentAlertId;
    if (currentAlertId != null && currentAlertId != event.alertId) return;
    _waitingTrackStart = false;
    _startLocationStreaming(
      event.alertId,
      interval: Duration(seconds: event.intervalSec.clamp(3, 60).toInt()),
      preferSocket: true,
    );
  }

  void _onSosTrackStop(String alertId) {
    if (_sentAlertId == null || _sentAlertId == alertId) {
      _stopLocationStreaming();
    }
  }

  void _startLocationStreaming(
    String alertId, {
    Duration interval = const Duration(seconds: 20),
    bool preferSocket = false,
  }) {
    _locationStreamTimer?.cancel();
    _pendingLocationPoints.clear();
    Future<void> pushOnce() async {
      final pos = await _getLocation();
      if (pos == null || !mounted) return;
      final sosProvider = context.read<SosProvider>();
      var ok = false;
      if (preferSocket) {
        ok = sosProvider.pushLocationRealtime(
          alertId,
          pos.latitude,
          pos.longitude,
          accuracy: pos.accuracy,
          sourceType: 'MOBILE_GPS',
          recordedAt: DateTime.now(),
        );
      }
      ok =
          ok ||
          await sosProvider.pushLocation(
            alertId,
            pos.latitude,
            pos.longitude,
            accuracy: pos.accuracy,
          );
      if (!mounted) return;
      if (!ok) {
        _pendingLocationPoints.add((
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
          recordedAt: DateTime.now(),
        ));
        if (_pendingLocationPoints.length > _maxPendingLocationPoints) {
          _pendingLocationPoints.removeAt(0);
        }
        return;
      }
      // Gửi điểm hiện tại thành công → thử flush luôn các điểm còn tồn đọng
      // từ lúc mất mạng trước đó.
      if (_pendingLocationPoints.isNotEmpty) {
        final flushed = await sosProvider.pushLocationBatch(
          alertId,
          List.of(_pendingLocationPoints),
        );
        if (mounted && flushed) _pendingLocationPoints.clear();
      }
    }

    pushOnce();
    _locationStreamTimer = Timer.periodic(interval, (_) => pushOnce());
  }

  void _stopLocationStreaming() {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = null;
    _waitingTrackStart = false;
    _pendingLocationPoints.clear();
  }

  // ── Hold-to-send countdown ───────────────────────────────────────────────

  // Đếm ngược tự động cho lối tắt: dùng lại y hệt bộ đếm 3 giây của nút giữ,
  // chỉ khác cách hủy (nút HỦY thay vì nhấc tay).
  void _startAutoCountdown() {
    setState(() => _autoCountdown = true);
    _onPressStart();
  }

  void _cancelAutoCountdown() {
    _countTimer?.cancel();
    setState(() {
      _autoCountdown = false;
      _countdown = null;
    });
    _pulseCtrl.repeat();
  }

  void _onPressStart() {
    // Đang đếm ngược tự động thì chạm vào nút không được khởi động lại bộ đếm.
    if (_autoCountdown && _countdown != null) return;
    // Hủy bộ đếm cũ trước khi tạo cái mới: chạm nhanh hai lần trước đây tạo
    // hai Timer song song mà không hủy cái đầu → _triggerSOS() chạy 2 lần →
    // gửi 2 cảnh báo cho cùng một sự việc.
    _countTimer?.cancel();
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
    // Chế độ tự động: không có "nhấc tay" nào để hủy — chỉ nút HỦY mới dừng.
    if (_autoCountdown) return;
    _countTimer?.cancel();
    setState(() => _countdown = null);
    _pulseCtrl.repeat();
  }

  // ── Get GPS → send SOS ───────────────────────────────────────────────────

  // Logic lấy GPS (timeout cứng + fallback getLastKnownPosition) đã chuyển sang
  // services/sos_location.dart để phát hiện té ngã dùng chung, không nhân bản.
  Future<Position?> _getLocation() => resolveSosPosition();

  /// [locationTimeout] rút ngắn khi gửi từ nền — xem [didChangeAppLifecycleState].
  Future<void> _triggerSOS({
    Duration locationTimeout = const Duration(seconds: 15),
  }) async {
    if (_sending) return; // chặn gọi chồng (đếm ngược xong đúng lúc app pause)
    _countTimer?.cancel();
    setState(() {
      _sending = true;
      _countdown = null;
      _autoCountdown = false;
    });
    final sosProvider = context.read<SosProvider>();
    // Chốt chặn cuối: dù _getLocation có kẹt ở tầng platform channel thì SOS
    // vẫn phải được gửi đi sau [locationTimeout] (không có tọa độ cũng gửi).
    final pos = await _getLocation().timeout(
      locationTimeout,
      onTimeout: () => null,
    );
    // Lưu GPS local trước để hiển thị dù API có lỗi
    if (mounted) {
      setState(() {
        _localLat = pos?.latitude;
        _localLng = pos?.longitude;
      });
    }
    try {
      final alertId = await sosProvider.sendSos(
        message: widget.immediate
            ? 'SOS khẩn cấp — phát hiện qua màn hình Cấp cứu khẩn cấp của máy'
            : (widget.autoTrigger
                  ? 'Phát hiện té ngã/lắc mạnh từ điện thoại'
                  : 'SOS khẩn cấp từ ứng dụng Family Care'),
        address: sosAddressOf(pos),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      // Chỉ chuyển sang "đã gửi" khi API xác nhận thành công
      if (mounted) {
        setState(() {
          _sent = true;
          _sending = false;
          _apiOk = true;
          _sentAlertId = alertId;
        });
        _waitingTrackStart = true;
        Future.delayed(const Duration(seconds: 6), () {
          if (!mounted ||
              !_waitingTrackStart ||
              _sentAlertId != alertId ||
              _locationStreamTimer != null) {
            return;
          }
          _startLocationStreaming(alertId);
        });
      }
    } catch (e) {
      // API thất bại → KHÔNG báo thành công, show lỗi để user biết
      // (kèm tọa độ GPS để user có thể chia sẻ thủ công)
      if (mounted) {
        setState(() {
          _sending = false;
        });
        _pulseCtrl.repeat();
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
        backgroundColor: _sosSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Text(
              'Không gửi được SOS',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _sosText,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gia đình chưa nhận được cảnh báo. Hãy liên hệ trực tiếp.',
              style: GoogleFonts.inter(fontSize: 13, color: _sosSecondary),
            ),
            if (hasGps) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vị trí của bạn:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sosMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_localLat!.toStringAsFixed(5)}, ${_localLng!.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _sosSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Lỗi: $reason',
              style: GoogleFonts.inter(fontSize: 11, color: _sosMuted),
            ),
          ],
        ),
        actions: [
          if (hasGps)
            if (!_lockRouteExit)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openMaps(_localLat!, _localLng!, 'Vị trí của tôi');
                },
                child: Text(
                  'Mở Maps',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A73E8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Đóng',
              style: GoogleFonts.inter(
                color: AppColors.sos,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không xác định được cảnh báo, vui lòng thử lại.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }
    final canResolve = context.read<AuthProvider>().user?.canResolveSos == true;
    try {
      await sosState.confirmSafety(id);
      // confirm-safety chỉ ghi nhận phản hồi (201) — cảnh báo vẫn ACTIVE.
      // Có quyền thì đóng luôn; không thì nói rõ để user khỏi tưởng đã xong.
      if (canResolve) {
        await sosState.resolveAlert(
          id,
          resolutionNote: 'Người phát đã xác nhận an toàn',
        );
      }
      _stopLocationStreaming();
      if (mounted) {
        setState(() => _sent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              canResolve
                  ? 'Đã xác nhận an toàn và đóng cảnh báo'
                  : 'Đã báo an toàn — cảnh báo vẫn mở tới khi Trưởng/Phó nhóm đóng',
            ),
            duration: Duration(seconds: canResolve ? 2 : 4),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('SOSScreen: confirmSafety failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Xác nhận an toàn thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget screen;
    if (_sending) {
      screen = _loadingScreen();
    } else if (_sent) {
      screen = _sentScreen(context);
    } else if (_showSenderSosFlow) {
      screen = _sosButton(context);
    } else {
      final activeAlerts = context.watch<SosProvider>().activeAlerts;
      screen = activeAlerts.isNotEmpty
          ? _incomingAlertsScreen(context, activeAlerts)
          : _sosButton(context);
    }
    // Vào từ lắc/té ngã/Emergency SOS hệ thống (autoTrigger/immediate) — khác
    // hẳn lúc mở tay từ tab SOS trong shell, ở đây người dùng không chủ động
    // chọn xem màn này, có thể đang mở đè lên màn khoá (setShowWhenLocked ở
    // MainActivity.onCreate()). Nút Back/vuốt-về hệ thống trước đây KHÔNG bị
    // chặn, nên thoát được khỏi màn SOS mà không qua đúng luồng Hủy/Đóng
    // (_cancelSOS gọi confirm-safety phía server) — chặn lại, giống hệt
    // PopScope(canPop: false) đã dùng cho IncomingCallScreen. Vào bình thường
    // từ tab SOS thì vẫn cho back như cũ.
    if (!_lockRouteExit) return screen;
    return PopScope(canPop: false, child: screen);
  }

  // ── SOS button screen (member / sender) ──────────────────────────────────

  Widget _sosButton(BuildContext context) {
    return Scaffold(
      backgroundColor: _sosBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sos.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _appBar(context),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, _) {
                      final holding = _countdown != null;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Sóng chỉ chạy khi đang chờ. Lúc giữ nút thì dừng
                          // hẳn để không có gì kéo mắt khỏi con số đếm ngược.
                          if (!holding) ...[
                            _sonarRing(0),
                            _sonarRing(1 / 3),
                            _sonarRing(2 / 3),
                          ],
                          GestureDetector(
                            onTapDown: (_) => _onPressStart(),
                            onTapUp: (_) => _onPressEnd(),
                            onTapCancel: _onPressEnd,
                            child: Transform.scale(
                              scale: holding ? 1.04 : _breathScale,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: holding
                                      ? AppColors.sosPressed
                                      : AppColors.sos,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (holding
                                                  ? AppColors.sosPressed
                                                  : AppColors.sos)
                                              .withValues(alpha: 0.45),
                                      blurRadius: holding ? 48 : 28,
                                      spreadRadius: holding ? 6 : 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.emergency_share_rounded,
                                      size: holding ? 34 : 44,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      holding ? '$_countdown' : 'SOS',
                                      style: GoogleFonts.inter(
                                        fontSize: holding ? 34 : 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: holding ? 0 : 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  // Số đếm ngược nay nằm TRONG nút (giống đồng hồ), nên chỗ này
                  // chỉ còn nhãn — lúc đang giữ thì đổi thành cách thoát.
                  child: Column(
                    children: [
                      Text(
                        'KHẨN CẤP',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        _autoCountdown
                            ? 'Đang gửi SOS...'
                            : _countdown != null
                            ? 'Thả ra để hủy'
                            : 'Giữ 3 giây để gửi SOS',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _sosMuted,
                        ),
                      ),
                      // Vào từ lối tắt thì không có thao tác "thả tay" để hủy —
                      // phải có nút thật, đủ to để bấm trúng lúc hoảng.
                      if (_autoCountdown) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 200,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _cancelAutoCountdown,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.sos,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Text(
                              'HỦY',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.sos,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Liên hệ khẩn: ưu tiên danh bạ gia đình (BE), fallback hotline
                // quốc gia khi gia đình chưa khai báo liên hệ nào.
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Builder(
                    builder: (context) {
                      final contacts = context
                          .watch<SosProvider>()
                          .emergencyContacts;
                      final useFamily = contacts.isNotEmpty;
                      final entries = useFamily
                          ? contacts
                                .take(3)
                                .map(
                                  (c) => (
                                    label: c.contactName,
                                    phone: c.phoneNumber,
                                  ),
                                )
                                .toList()
                          : SosProvider.kDefaultHotlines
                                .map((n) => (label: n, phone: n))
                                .toList();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            useFamily ? 'Gọi nhanh: ' : 'Liên hệ khẩn: ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _sosMuted,
                            ),
                          ),
                          ...entries.map(
                            (e) => GestureDetector(
                              onTap: () =>
                                  launchUrl(Uri.parse('tel:${e.phone}')),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _sosControlBorder),
                                ),
                                child: Text(
                                  e.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _sosText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Manager: incoming alert list ─────────────────────────────────────────

  Widget _incomingAlertsScreen(BuildContext context, List<SosAlert> alerts) {
    return Scaffold(
      backgroundColor: _sosBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _backBtn(context),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Cảnh báo khẩn cấp',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sos,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<SosProvider>().fetchAlerts(),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _sosMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: alerts.length,
                itemBuilder: (_, i) => _alertCard(context, alerts[i]),
              ),
            ),
          ],
        ),
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
          color: AppColors.sos.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sos,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.sos_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.senderName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _sosText,
                      ),
                    ),
                    Text(
                      _fmtAlertTime(alert.createdAt),
                      style: GoogleFonts.inter(fontSize: 12, color: _sosMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sos,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showAlertDetail(context, alert.id),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _sosMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            alert.message,
            style: GoogleFonts.inter(fontSize: 14, color: _sosSecondary),
          ),

          // Alert đã đóng: hiện ai xử lý + ghi chú
          if (!alert.isActive &&
              (alert.resolvedByName != null ||
                  alert.resolutionNote != null)) ...[
            const SizedBox(height: 8),
            Text(
              '${alert.resolvedByName ?? 'Đã xử lý'}${(alert.resolutionNote ?? '').isNotEmpty ? ': ${alert.resolutionNote}' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _sosMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Location row
          if (alert.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: _sosMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alert.address,
                    style: GoogleFonts.inter(fontSize: 12, color: _sosMuted),
                  ),
                ),
              ],
            ),
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
                        initialCenter: LatLng(
                          alert.latitude!,
                          alert.longitude!,
                        ),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag
                              .none, // Không cho scroll/zoom để không chiếm gesture
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.sos_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bản đồ lớn',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A73E8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action buttons — cảnh báo CỦA MÌNH thì không thể "đang đến" chỗ
          // chính mình; thay bằng tự xác nhận an toàn (confirm-safety).
          Builder(
            builder: (context) {
              final mine = alert.isMine(context.watch<AuthProvider>().user?.id);
              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final sos = context.read<SosProvider>();
                        if (sos.sending) return;
                        final canResolve =
                            context.read<AuthProvider>().user?.canResolveSos ==
                            true;
                        try {
                          if (mine) {
                            // BE: confirm-safety chỉ GHI NHẬN phản hồi CONFIRM_SAFE
                            // (201), KHÔNG đổi status cảnh báo. Chỉ resolve/cancel
                            // (Manager/Deputy) mới đóng được.
                            await sos.confirmSafety(alert.id);
                            if (canResolve) {
                              // Người phát có quyền quản lý → đóng luôn cho gọn.
                              await sos.resolveAlert(
                                alert.id,
                                resolutionNote:
                                    'Người phát đã xác nhận an toàn',
                              );
                            }
                          } else {
                            // BE ship enum ON_THE_WAY (19/07) → gửi đúng loại phản hồi,
                            // không còn mượn VIEWED + đoán chữ trong message.
                            await sos.respond(
                              alert.id,
                              'ON_THE_WAY',
                              message: 'Tôi đang đến',
                            );
                          }
                          if (context.mounted) {
                            final msg = !mine
                                ? 'Đã phản hồi SOS'
                                : (canResolve
                                      ? 'Đã xác nhận an toàn và đóng cảnh báo'
                                      : 'Đã báo an toàn — cảnh báo vẫn mở tới khi Trưởng/Phó nhóm đóng');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                duration: Duration(
                                  seconds: mine && !canResolve ? 4 : 2,
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Phản hồi thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          mine ? 'Tôi đã an toàn' : 'Tôi đang đến',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chỉ Manager/Deputy được phép resolve (theo Swagger: PATCH
                  // .../resolve chỉ FAMILY_MANAGER/DEPUTY_MEMBER).
                  if (context.watch<AuthProvider>().user?.canResolveSos ==
                      true) ...[
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Xử lý thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _sosControlBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Đã xử lý',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _sosSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // Người phát KHÔNG có quyền đóng → giải thích vì sao cảnh báo vẫn
          // ACTIVE sau khi bấm "Tôi đã an toàn" (BE: confirm-safety chỉ ghi
          // nhận phản hồi, resolve/cancel mới đóng và chỉ Manager/Deputy).
          if (alert.isMine(context.watch<AuthProvider>().user?.id) &&
              context.watch<AuthProvider>().user?.canResolveSos != true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _sosMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Báo an toàn xong, cảnh báo vẫn mở tới khi Trưởng/Phó nhóm đóng.',
                    style: GoogleFonts.inter(fontSize: 11, color: _sosMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Open Google Maps ─────────────────────────────────────────────────────

  Future<void> _openMaps(double lat, double lng, String label) async {
    // geo: URI opens Google Maps on Android; fallback to https URL
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _SosAlertDetailSheet(alertId: alertId),
    );
  }

  // ── Loading / Sent screens ───────────────────────────────────────────────

  Widget _loadingScreen() => Scaffold(
    backgroundColor: _sosBg,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.sos, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Đang gửi SOS...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _sosText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang lấy vị trí GPS…',
            style: GoogleFonts.inter(fontSize: 13, color: _sosMuted),
          ),
        ],
      ),
    ),
  );

  Widget _sentScreen(BuildContext context) {
    final hasGps = _localLat != null && _localLng != null;
    return Scaffold(
      backgroundColor: _sosBg,
      // Nội dung màn này cao cố định (icon 84 + tiêu đề + toạ độ + mini map
      // 180 + nút xem bản đồ + nút Đóng). Trên máy màn thấp, hoặc khi đang có
      // banner "Bạn đang phát cảnh báo SOS" chiếm thêm chỗ ở trên, tổng chiều
      // cao vượt khung và Flutter báo "BOTTOM OVERFLOWED BY 106 PIXELS".
      //
      // Center + Column không co lại được nên phải cho cuộn. ConstrainedBox
      // với minHeight = chiều cao khung giữ nguyên dáng CĂN GIỮA khi màn đủ
      // cao (đa số máy), chỉ khi nội dung dài hơn khung mới sinh ra cuộn.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sos_rounded,
                      size: 84,
                      color: AppColors.sos,
                    ),
                    Text(
                      'SOS đã gửi!',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: _sosText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _apiOk
                          ? 'Thông báo đã gửi đến gia đình'
                          : 'Đã ghi nhận — thành viên đang được thông báo',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _sosSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // GPS coordinates
                    if (hasGps) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: _sosMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_localLat!.toStringAsFixed(5)}, ${_localLng!.toStringAsFixed(5)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _sosSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Inline Mini Map
                      Container(
                        height: 180,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _sosControlBorder),
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
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.sos_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
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
                      // Mở Bản đồ lớn in-app. Ẩn trong flow lắc/té ngã trên màn
                      // khóa để người dùng không rời khỏi giao diện SOS khi chưa
                      // mở khóa máy.
                      if (!_lockRouteExit)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              context.push(
                                '/map?lat=$_localLat&lng=$_localLng',
                              );
                            },
                            icon: const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              'Xem bản đồ lớn trong ứng dụng',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        'Không lấy được GPS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _sosMuted,
                        ),
                      ),
                    ],

                    if (!_apiOk) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Chức năng SOS đang chờ BE triển khai',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.amber.shade200,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _cancelSOS,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.danger, width: 2),
                        ),
                        child: Text(
                          'Đóng',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _appBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: [
        _lockRouteExit
            ? const SizedBox(width: 40, height: 40)
            : _backBtn(context),
        Expanded(
          child: Center(
            child: Text(
              'Khẩn cấp',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _sosMuted,
              ),
            ),
          ),
        ),
        // Cài đặt SOS (bật/tắt, báo cả nhà, té ngã, vị trí) — thay chỗ trống
        // cân bằng nút back trước đây.
        _lockRouteExit
            ? const SizedBox(width: 40, height: 40)
            : GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SosSettingsScreen()),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sosControl,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.settings_rounded,
                    size: 20,
                    color: _sosText,
                  ),
                ),
              ),
      ],
    ),
  );

  Widget _backBtn(BuildContext context) => GestureDetector(
    // Vào từ lối tắt (`/sos-quick`) thì đây là route DUY NHẤT trong stack —
    // context.pop() sẽ ném "There is nothing to pop". Rơi về home theo role.
    onTap: () => backOrHome(context),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _sosControl),
      alignment: Alignment.center,
      child: Icon(Icons.arrow_back_rounded, size: 20, color: _sosText),
    ),
  );

  /// Nhịp thở của chính nút SOS: 1.0 → 1.05 → 1.0 trong một vòng controller.
  double get _breathScale => 1 + 0.05 * (1 - (2 * _pulseCtrl.value - 1).abs());

  /// Một vòng sóng lan ra rồi mờ hẳn, bắt đầu từ đúng mép nút.
  ///
  /// [phase] lệch nhau 1/3 để ba vòng nối đuôi nhau thay vì cùng phình một lúc
  /// — đó là khác biệt giữa "radar đang phát" và "ba đường viền rung nhẹ".
  Widget _sonarRing(double phase) {
    final t = (_pulseCtrl.value + phase) % 1.0;
    return Transform.scale(
      scale: 1 + t * 1.25,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.sos.withValues(alpha: 0.55 * (1 - t)),
          ),
        ),
      ),
    );
  }
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
  int _locationRetryCount = 0;
  static const int _maxLocationRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await context.read<SosProvider>().fetchAlertDetail(
        widget.alertId,
      );
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
        _scheduleLocationRetryIfNeeded(d);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _scheduleLocationRetryIfNeeded(Map<String, dynamic> detail) {
    final status = (detail['status']?.toString() ?? 'ACTIVE').toUpperCase();
    if (status != 'ACTIVE' || parseSosAlertLocation(detail) != null) return;
    if (_locationRetryCount >= _maxLocationRetries) return;
    _locationRetryCount++;

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      final loc = await context.read<SosProvider>().fetchCurrentLocation(
        widget.alertId,
      );
      if (!mounted) return;
      if (loc == null) {
        _scheduleLocationRetryIfNeeded(_detail ?? detail);
        return;
      }
      final existing = _detail?['locationPoints'];
      setState(() {
        _detail = {
          ...?_detail,
          'locationPoints': [
            if (existing is List) ...existing,
            {
              'latitude': loc.lat,
              'longitude': loc.lng,
              if (loc.sourceType != null) 'sourceType': loc.sourceType,
              'recordedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        };
      });
    });
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

  SosAlertLocation? _location(Map<String, dynamic> d) {
    return parseSosAlertLocation(d);
  }

  ({IconData icon, String label})? _locationSource(String? sourceType) {
    final type = sourceType?.toUpperCase().trim();
    if (type == null || type.isEmpty) return null;
    return switch (type) {
      'WEARABLE_GPS' ||
      'WEARABLE' => (icon: Icons.watch_rounded, label: 'Vị trí từ đồng hồ'),
      'MOBILE_GPS' || 'MOBILE_APP' => (
        icon: Icons.phone_android_rounded,
        label: 'Vị trí từ điện thoại',
      ),
      'SIMULATED_GPS' ||
      'SIMULATED_DEVICE' => (icon: Icons.tune_rounded, label: 'Vị trí giả lập'),
      _ => null,
    };
  }

  // Ánh xạ loại phản hồi → (icon, màu nền node, nhãn hiển thị).
  // BE ship enum ON_THE_WAY (19/07) → phân biệt "Đang đến" bằng ĐÚNG enum.
  // Vẫn giữ fallback đoán theo message cho các phản hồi CŨ đã lưu dạng
  // VIEWED + "Tôi đang đến" trước khi BE bổ sung enum.
  ({IconData icon, Color color, String label}) _nodeStyle(
    String type,
    String message,
  ) {
    final t = type.toUpperCase();
    final legacyOnWay = message.toLowerCase().contains('đang đến');
    switch (t) {
      case 'ON_THE_WAY':
        return (
          icon: Icons.directions_run_rounded,
          color: AppColors.safe,
          label: 'Đang đến',
        );
      case 'VIEWED':
        return legacyOnWay
            ? (
                icon: Icons.directions_run_rounded,
                color: AppColors.safe,
                label: 'Đang đến',
              )
            : (
                icon: Icons.visibility_outlined,
                color: AppColors.avatarBlue,
                label: 'Đã xem',
              );
      case 'NEED_HELP':
        return (
          icon: Icons.sos_rounded,
          color: AppColors.sos,
          label: 'Cần trợ giúp',
        );
      case 'CONFIRM_SAFE':
        return (
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.safe,
          label: 'Đã an toàn',
        );
      case 'RESOLVED':
        return (
          icon: Icons.done_rounded,
          color: AppColors.safe,
          label: 'Đã xử lý',
        );
      case 'CANCELED':
        return (
          icon: Icons.close_rounded,
          color: AppColors.textMuted,
          label: 'Đã hủy',
        );
      default:
        return (
          icon: Icons.circle,
          color: AppColors.textSecondary,
          label: type.isEmpty ? 'Phản hồi' : type,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.progressTrack,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(child: _content(_detail ?? {})),
            ),
        ],
      ),
    );
  }

  Widget _content(Map<String, dynamic> d) {
    final sender =
        _memberName(d['triggeredByMember']) ??
        _memberName(d['sender']) ??
        _memberName(d['triggeredBy']) ??
        d['senderName']?.toString() ??
        'Thành viên';
    final status = (d['status']?.toString() ?? 'ACTIVE').toUpperCase();
    final createdAt =
        d['triggeredAt']?.toString() ?? d['createdAt']?.toString() ?? '';
    final message = d['message']?.toString() ?? '';
    final address = d['address']?.toString() ?? '';
    final loc = _location(d);
    final locationPoints = parseSosAlertLocationPoints(d);
    final routePoints = [for (final p in locationPoints) LatLng(p.lat, p.lng)];
    final source = _locationSource(loc?.sourceType);
    final responses = _responses(d);
    final resolvedBy = _memberName(d['resolvedByMember']);
    final resolutionNote = d['resolutionNote']?.toString();

    final isActive = status == 'ACTIVE';
    final statusColor = isActive
        ? AppColors.sos
        : (status == 'RESOLVED' ? AppColors.safe : AppColors.textMuted);
    final statusLabel = switch (status) {
      'ACTIVE' => 'ĐANG KHẨN CẤP',
      'RESOLVED' => 'ĐÃ XỬ LÝ',
      'CANCELED' => 'ĐÃ HỦY',
      'FALSE_ALARM' => 'BÁO ĐỘNG GIẢ',
      _ => status,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header đỏ gradient (v0 style) ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.sos_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS từ $sender',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            'Lúc ${_fmtTime(createdAt)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isNotEmpty) ...[
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Vị trí ────────────────────────────────────────────────────
              if (address.isNotEmpty || loc != null) ...[
                Text(
                  'Vị trí',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.progressTrack),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: AppColors.avatarBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (loc != null) ...[
                        if (address.isNotEmpty) const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tọa độ: ${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.colors.textMuted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            if (source != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                source.icon,
                                size: 13,
                                color: context.colors.textMuted,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  source.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: context.colors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 140,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(loc.lat, loc.lng),
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.familycare.app',
                                ),
                                if (routePoints.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: routePoints,
                                        color: AppColors.sos.withValues(
                                          alpha: 0.72,
                                        ),
                                        strokeWidth: 4,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(loc.lat, loc.lng),
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.sos,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.sos_rounded,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Response Timeline (điểm chính lấy từ v0) ───────────────────
              Text(
                'Diễn biến phản hồi',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _timelineNode(
                icon: Icons.sos_rounded,
                color: AppColors.sos,
                title: 'SOS được gửi',
                subtitle: sender,
                time: createdAt.isNotEmpty ? _fmtTime(createdAt) : null,
                isLast: responses.isEmpty && status == 'ACTIVE',
              ),
              for (int i = 0; i < responses.length; i++)
                _responseNode(
                  responses[i],
                  isLast: i == responses.length - 1 && status == 'ACTIVE',
                ),
              if (status == 'RESOLVED' ||
                  status == 'CANCELED' ||
                  status == 'FALSE_ALARM')
                _timelineNode(
                  icon: switch (status) {
                    'RESOLVED' => Icons.done_rounded,
                    'FALSE_ALARM' => Icons.notifications_off_outlined,
                    _ => Icons.close_rounded,
                  },
                  color: status == 'RESOLVED'
                      ? AppColors.safe
                      : AppColors.textMuted,
                  title: switch (status) {
                    'RESOLVED' => 'Đã xử lý',
                    'FALSE_ALARM' => 'Báo động giả',
                    _ => 'Đã hủy',
                  },
                  subtitle: [
                    resolvedBy,
                    resolutionNote,
                  ].where((e) => (e ?? '').isNotEmpty).join(' · '),
                  time: null,
                  isLast: true,
                ),
              if (responses.isEmpty && status == 'ACTIVE') ...[
                const SizedBox(height: 4),
                Text(
                  'Chưa có phản hồi nào',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // Status badge chip
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trạng thái: $statusLabel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),

              // ── Dữ liệu kỹ thuật (giữ JsonReportView làm fallback [VERIFY]) ──
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
                  title: Text(
                    'Dữ liệu kỹ thuật (cấu trúc cần kiểm chứng)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                  children: [JsonReportView(data: d)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responseNode(Map r, {required bool isLast}) {
    final type = (r['responseType'] ?? r['type'] ?? '').toString();
    final msg = (r['message'] ?? '').toString();
    final time = (r['respondedAt'] ?? r['createdAt'] ?? r['timestamp'] ?? '')
        .toString();
    // Field chuẩn theo Swagger (SosResponseResponseDto, verify 2026-07-16):
    // responderMember {displayName, user.fullName} — đặt ĐẦU chuỗi fallback.
    final who =
        _memberName(r['responderMember']) ??
        _memberName(r['respondedByMember']) ??
        _memberName(r['member']) ??
        _memberName(r['respondedBy']) ??
        _memberName(r['user']) ??
        r['memberName']?.toString() ??
        'Thành viên';
    final s = _nodeStyle(type, msg);
    final subtitle = msg.isNotEmpty ? '$who · $msg' : who;
    return _timelineNode(
      icon: s.icon,
      color: s.color,
      title: s.label,
      subtitle: subtitle,
      time: time.isNotEmpty ? _fmtTime(time) : null,
      isLast: isLast,
    );
  }

  Widget _timelineNode({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? time,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.progressTrack),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
