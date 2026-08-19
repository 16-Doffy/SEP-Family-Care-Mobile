import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/sos_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../services/fall_detector_service.dart';
import '../../services/heart_rate_detector.dart';
import '../../services/sos_location.dart';
import '../../services/wear_heart_rate_bridge.dart';
import '../wear_fall_alert_view.dart';
import '../wear_sos_location_stream_guard.dart';
import '../wear_widgets.dart';

/// SOS tự động từ cảm biến trên đồng hồ — theo spec "Wear OS Flow" (Discord
/// #chuc-nang-moi → "Flow của Wearable Device SOS mới", 04/08/2026).
///
/// **Điểm cốt lõi của spec, khác hẳn SOS thủ công:**
/// > Wear OS **không gọi trực tiếp `/sos/alerts`** cho 2 case auto-detection.
/// > Gọi `POST /families/{familyId}/wearables/{deviceId}/events`.
/// > BE tự quyết định tạo SOS và **chống trùng** nếu user đang có SOS active.
///
/// Đi đường `/sos/alerts` là mất chống trùng của BE, và mất luôn luật
/// "FALL_DETECTED chỉ auto tạo cảnh báo khi `autoCreateAlertFromFall = true`"
/// — vì gọi thẳng alert là tạo vô điều kiện.
///
/// Màn này có **cả hai** nguồn kích hoạt, cố ý:
/// - **Cảm biến thật** (gia tốc kế) — giá trị thật của tính năng.
/// - **Nút giả lập** — máy ảo không có cảm biến thật để thử, và khi demo thì
///   cần bấm ra kết quả ngay chứ không thể quăng đồng hồ xuống đất.
class WearSensorSosScreen extends StatefulWidget {
  const WearSensorSosScreen({super.key});

  @override
  State<WearSensorSosScreen> createState() => _WearSensorSosScreenState();
}

/// Ba tình huống cảm biến mà spec yêu cầu giả lập được.
enum _Trigger { fall, heartHigh, heartLow }

extension _TriggerSpec on _Trigger {
  String get eventType => switch (this) {
    _Trigger.fall => 'FALL_DETECTED',
    _Trigger.heartHigh || _Trigger.heartLow => 'HEART_RATE_ABNORMAL',
  };

  /// Spec chỉ ghi `severity` cho case té ngã; case nhịp tim để BE tự quyết.
  String? get severity => this == _Trigger.fall ? 'HIGH' : null;

  String get title => switch (this) {
    _Trigger.fall => 'Phát hiện té ngã',
    _Trigger.heartHigh || _Trigger.heartLow => 'Nhịp tim bất thường',
  };

  /// Dòng số liệu hiện dưới tiêu đề — spec ví dụ "142 bpm".
  String get reading => switch (this) {
    _Trigger.fall => '',
    _Trigger.heartHigh => '142 bpm',
    _Trigger.heartLow => '38 bpm',
  };

  String get question => switch (this) {
    _Trigger.fall => 'Bạn có ổn không?',
    _Trigger.heartHigh || _Trigger.heartLow => 'Bạn có cần trợ giúp không?',
  };

  /// Nhãn nút huỷ — spec dùng "Con ổn" cho té ngã, "Đã ổn" cho nhịp tim.
  String get dismissLabel => this == _Trigger.fall ? 'Con ổn' : 'Đã ổn';

  IconData get icon => switch (this) {
    _Trigger.fall => Icons.accessibility_new_rounded,
    _Trigger.heartHigh => Icons.monitor_heart_rounded,
    _Trigger.heartLow => Icons.heart_broken_rounded,
  };

  /// `rawValue` bám đúng ví dụ trong spec. BE đã xác nhận `thresholdLow` hợp lệ
  /// cho case nhịp tim thấp và `HEART_RATE_ABNORMAL` tự tạo SOS.
  Map<String, dynamic> get rawValue => switch (this) {
    _Trigger.fall => {
      'gForce': 3.2,
      'stillSeconds': 8,
      'source': 'wear_os_emulator',
    },
    _Trigger.heartHigh => {
      'heartRate': 142,
      'thresholdHigh': 130,
      'durationSeconds': 30,
      'source': 'wear_os_emulator',
    },
    _Trigger.heartLow => {
      'heartRate': 38,
      'thresholdLow': 50,
      'durationSeconds': 30,
      'source': 'wear_os_emulator',
    },
  };

  /// Chuỗi mẫu (chuỗi hiển thị, giá trị số) chạy trên UI trước khi mở cảnh
  /// báo — mỗi mẫu được so với [isAbnormal] theo thời gian thực, **hệ thống
  /// chỉ mở đếm ngược khi có mẫu thật sự vượt ngưỡng**, không phải cứ chạy
  /// hết chuỗi là tự động mở. Đây là so ngưỡng đơn giản (1 lần so sánh),
  /// **không phải thuật toán phân tích đầy đủ** kiểu rơi-tự-do/thời-gian-duy-
  /// trì của bản detector thật (đã hoãn sau mùa bảo vệ) — nhưng vẫn là một
  /// bước "phát hiện" thật sự, không phải luôn luôn báo động vô điều kiện.
  /// Mẫu cuối luôn khớp đúng [rawValue]/[reading] đã gửi BE.
  List<(String, double)> get signalSamples => switch (this) {
    _Trigger.fall => const [
      ('1.0 g', 1.0),
      ('0.9 g', 0.9),
      ('0.3 g', 0.3),
      ('0.1 g', 0.1),
      ('0.2 g', 0.2),
      ('1.8 g', 1.8),
      ('3.2 g', 3.2),
    ],
    _Trigger.heartHigh => const [
      ('78 bpm', 78),
      ('92 bpm', 92),
      ('110 bpm', 110),
      ('126 bpm', 126),
      ('136 bpm', 136),
      ('142 bpm', 142),
    ],
    _Trigger.heartLow => const [
      ('76 bpm', 76),
      ('65 bpm', 65),
      ('58 bpm', 58),
      ('50 bpm', 50),
      ('44 bpm', 44),
      ('38 bpm', 38),
    ],
  };

  /// Ngưỡng "phát hiện bất thường" — trùng đúng số đã gửi BE trong [rawValue]
  /// (`thresholdHigh: 130`, `thresholdLow: 50`) để nhất quán; té ngã dùng
  /// mốc va đập 2.5g (dưới mức 3.2g của mẫu cuối, dư khoảng cách để chuỗi
  /// luôn kết ở đúng mẫu phát hiện được, không rơi vào trường hợp chạy hết
  /// chuỗi mà chưa phát hiện gì).
  bool isAbnormal(double value) => switch (this) {
    _Trigger.fall => value >= 2.5,
    _Trigger.heartHigh => value > 130,
    _Trigger.heartLow => value < 50,
  };
}

class _WearSensorSosScreenState extends State<WearSensorSosScreen> {
  /// Spec: "Tự gửi SOS sau 20s".
  static const _countdownSeconds = 20;
  static const _locationStreamPeriod = Duration(seconds: 30);

  bool _sensorOn = false;
  bool _heartSensorOn = false;
  final _heartRateDetector = HeartRateDetector();
  Stopwatch? _heartRateStopwatch;
  _Trigger? _pending;
  Map<String, dynamic>? _pendingRawValue;
  String? _pendingReadingText;
  int _countdown = 0;
  Timer? _timer;

  bool _sending = false;
  bool _sent = false;
  bool _signalRunning = false;
  _Trigger? _signalTrigger;
  String? _signalReading;
  Timer? _signalTimer;
  String? _alertId;
  bool _alertCreated = false;
  String? _error;
  String? _locationNotice;
  Timer? _locationStreamTimer;
  final _locationStreamGuard = WearSosLocationStreamGuard();

  @override
  void initState() {
    super.initState();
    // Cần deviceId để gửi sự kiện cảm biến → phải biết tài khoản đã ghép
    // wearable nào chưa. Cần SosSettings để biết gia đình có bật SOS/tự tạo
    // cảnh báo té ngã hay không trước khi cho bấm nút giả lập.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WearableProvider>().fetchCurrentDevice();
      context.read<SosProvider>().fetchSettings();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _signalTimer?.cancel();
    _stopLocationStreaming();
    FallDetectorService.instance.stop();
    WearHeartRateBridge.stop();
    super.dispose();
  }

  void _toggleSensor(bool on) {
    HapticFeedback.mediumImpact();
    setState(() => _sensorOn = on);
    if (on) {
      FallDetectorService.instance.start(onFall: () => _raise(_Trigger.fall));
    } else {
      FallDetectorService.instance.stop();
    }
  }

  /// Bật/tắt đọc nhịp tim thật qua Wear Health Services — chỉ có dữ liệu
  /// thật trên đồng hồ Wear OS thật có cảm biến PPG (xem
  /// `wear_heart_rate_bridge.dart`). Mỗi mẫu bpm đi qua [HeartRateDetector]
  /// (đã có sẵn, dùng ngưỡng đúng số đã gửi BE: `thresholdHigh: 130`,
  /// `thresholdLow: 50`, phải duy trì bất thường ≥10s) — chỉ khi detector tự
  /// kết luận mới mở cảnh báo, không phải mỗi mẫu lệch ngưỡng là báo ngay.
  Future<void> _toggleHeartSensor(bool on) async {
    HapticFeedback.mediumImpact();
    if (!on) {
      await WearHeartRateBridge.stop();
      if (mounted) setState(() => _heartSensorOn = false);
      return;
    }
    final granted =
        await WearHeartRateBridge.hasPermission() ||
        await WearHeartRateBridge.requestPermission();
    if (!granted) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa cấp quyền đọc cảm biến nhịp tim — vào Cài đặt > Ứng dụng '
              '> Family Care > Quyền để cấp.',
        );
      }
      return;
    }
    _heartRateDetector.reset();
    _heartRateStopwatch = Stopwatch()..start();
    try {
      await WearHeartRateBridge.start(onReading: _onHeartRateSample);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (mounted) setState(() => _heartSensorOn = true);
  }

  void _onHeartRateSample(int bpm) {
    if (!mounted || _heartRateStopwatch == null) return;
    final reading = _heartRateDetector.addSample(
      bpm,
      _heartRateStopwatch!.elapsed,
    );
    if (!reading.detected) return;
    final result = _heartRateDetector.lastResult;
    if (result == null) return;
    _raise(
      result.high ? _Trigger.heartHigh : _Trigger.heartLow,
      realRawValue: {
        'heartRate': result.heartRate,
        if (result.high) 'thresholdHigh': 130 else 'thresholdLow': 50,
        'durationSeconds': result.abnormalSeconds,
        'source': 'wear_health_services',
      },
      realReadingText: '${result.heartRate} bpm',
    );
  }

  void _raise(
    _Trigger trigger, {
    Map<String, dynamic>? realRawValue,
    String? realReadingText,
  }) {
    if (!mounted || _pending != null || _sending || _sent) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _pending = trigger;
      _pendingRawValue = realRawValue;
      _pendingReadingText = realReadingText;
      _countdown = _countdownSeconds;
      _error = null;
      _locationNotice = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 5 && _countdown > 0) HapticFeedback.mediumImpact();
      if (_countdown <= 0) {
        _timer?.cancel();
        _send(trigger);
      }
    });
  }

  /// Spec: bấm "Con ổn" → đóng cảnh báo, **không gọi API tạo SOS**.
  void _dismiss() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _pending = null;
      _pendingRawValue = null;
      _pendingReadingText = null;
      _countdown = 0;
    });
  }

  /// Chặn bấm nút giả lập khi gia đình/thiết bị chưa đủ điều kiện để BE thật
  /// sự tạo cảnh báo — tránh bấm, đợi 20 giây rồi chỉ nhận về "đã gửi sự
  /// kiện" mà không có cảnh báo nào, dễ gây hiểu nhầm lúc demo.
  bool _canStartSignal(_Trigger trigger) {
    final device = context.read<WearableProvider>().currentDevice;
    final settings = context.read<SosProvider>().settings;
    if (device == null || !device.isPaired || !device.sosEnabled) return false;
    if (settings == null || !settings.isEnabled) return false;
    if (trigger == _Trigger.fall && !settings.autoCreateAlertFromFall) {
      return false;
    }
    return true;
  }

  String _blockedReason(_Trigger trigger) {
    final device = context.read<WearableProvider>().currentDevice;
    final settings = context.read<SosProvider>().settings;
    if (device == null || !device.isPaired) return 'Chưa ghép thiết bị đeo';
    if (!device.sosEnabled) return 'SOS của wearable đang tắt';
    if (settings == null) return 'Chưa tải cài đặt SOS gia đình';
    if (!settings.isEnabled) return 'SOS gia đình đang tắt';
    if (trigger == _Trigger.fall && !settings.autoCreateAlertFromFall) {
      return 'Chưa bật tự tạo SOS khi té ngã';
    }
    return 'Chưa đủ điều kiện tạo SOS';
  }

  void _showSignalBlocked(_Trigger trigger) {
    HapticFeedback.lightImpact();
    setState(() => _error = _blockedReason(trigger));
  }

  /// Chạy chuỗi mẫu giả lập trên UI — **KHÔNG gọi API/mở đếm ngược ngay khi
  /// bấm**. Mỗi mẫu hiện lên rồi được so với [_Trigger.isAbnormal]; chỉ khi
  /// một mẫu thật sự vượt ngưỡng thì mới coi là "hệ thống đã phát hiện" và
  /// gọi [_raise] để mở màn đếm ngược. Nếu chạy hết chuỗi mà không mẫu nào
  /// vượt ngưỡng (không xảy ra với chuỗi demo cố định hiện tại, nhưng vẫn xử
  /// lý đúng nếu có), quay lại trạng thái bình thường, không mở cảnh báo.
  ///
  /// Đây là so ngưỡng đơn giản (1 phép so sánh/mẫu), khác thuật toán phân
  /// tích đầy đủ (rơi tự do + thời gian duy trì) của bản detector thật đã
  /// hoãn sau mùa bảo vệ — nhưng vẫn là một bước phát hiện có thật, không
  /// phải mở cảnh báo vô điều kiện sau khi chuỗi chạy xong.
  void _runSignal(_Trigger trigger) {
    if (!_canStartSignal(trigger)) {
      _showSignalBlocked(trigger);
      return;
    }
    if (_signalRunning || _pending != null || _sending || _sent) return;
    HapticFeedback.selectionClick();
    final samples = trigger.signalSamples;
    var index = 0;
    _signalTimer?.cancel();
    setState(() {
      _signalRunning = true;
      _signalTrigger = trigger;
      _error = null;
    });
    // Dùng `timer.cancel()` (tham số của chính callback) để tự huỷ — không
    // dựa vào `_signalTimer` bên ngoài, vì `Timer.periodic()` chỉ gán xong
    // biến đó SAU khi lệnh này chạy hết, nên gọi `_signalTimer?.cancel()`
    // ngay trong lượt tick đầu tiên có thể huỷ nhầm timer cũ thay vì timer
    // hiện tại.
    _signalTimer = Timer.periodic(const Duration(milliseconds: 260), (timer) {
      if (!mounted || index >= samples.length) {
        // Hết chuỗi mà chưa mẫu nào vượt ngưỡng — không phát hiện gì, không
        // mở cảnh báo.
        timer.cancel();
        if (mounted) {
          setState(() {
            _signalRunning = false;
            _signalTrigger = null;
          });
        }
        return;
      }
      final (display, value) = samples[index];
      index++;
      setState(() => _signalReading = display);
      if (trigger.isAbnormal(value)) {
        timer.cancel();
        setState(() {
          _signalRunning = false;
          _signalTrigger = null;
        });
        _raise(trigger);
      }
    });
  }

  /// Nút làm mới ở header — phòng trường hợp `GET /sos/settings` hoặc
  /// `device.sosEnabled` không phản ánh ngay thay đổi vừa thực hiện trên điện
  /// thoại (BE chưa xác nhận độ trễ cache, xem
  /// BAO_CAO_BE_KE_HOACH_WEARABLE_SENSOR_UI_PREFLIGHT_2026-08-19.md).
  Future<void> _refreshGateState() async {
    HapticFeedback.selectionClick();
    await Future.wait([
      context.read<WearableProvider>().fetchCurrentDevice(),
      context.read<SosProvider>().fetchSettings(),
    ]);
  }

  Future<void> _send(_Trigger trigger) async {
    final device = context.read<WearableProvider>().currentDevice;
    if (device == null) {
      setState(() {
        _pending = null;
        _error = 'Chưa ghép thiết bị đeo, không gửi được sự kiện.';
      });
      return;
    }
    setState(() {
      _pending = null;
      _sending = true;
      _error = null;
      _locationNotice = null;
    });
    try {
      final result = await context.read<WearableProvider>().createEvent(
        device.id,
        eventType: trigger.eventType,
        severity: trigger.severity,
        // Nếu cảm biến thật vừa kích hoạt (nhịp tim qua Health Services) thì
        // gửi đúng số đo được, không phải hằng số demo — xem _onHeartRateSample.
        rawValue: _pendingRawValue ?? trigger.rawValue,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _alertCreated = result.alertCreated;
        _alertId = result.alertId;
      });
      // `CreateSensorEventDto` KHÔNG có trường vị trí và BE là bên tạo alert,
      // nên cảnh báo sinh ra từ cảm biến không có toạ độ nào. Người nhận vì thế
      // không thấy bản đồ, khác hẳn cảnh báo phát từ điện thoại. Đẩy một điểm
      // vị trí ngay sau khi alert tồn tại để bù chỗ đó.
      final alertId = result.alertId;
      if (alertId != null) {
        await _pushPosition(alertId, device.id);
        if (mounted) _startLocationStreaming(alertId, device.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Gửi vị trí kèm cho cảnh báo vừa tạo. Chỉ dùng GPS của chính đồng hồ; hỏng
  /// bước này thì cảnh báo vẫn còn nguyên, chỉ là thiếu bản đồ.
  Future<bool> _pushPosition(
    String alertId,
    String deviceId, {
    bool showLocating = true,
  }) async {
    if (showLocating) setState(() => _locationNotice = 'Đang lấy vị trí…');
    final pos = await resolveWearableSosPosition();
    if (!mounted) return false;
    if (pos == null) {
      setState(() => _locationNotice = 'Không lấy được GPS đồng hồ');
      return false;
    }
    final pushed = await context.read<SosProvider>().pushLocation(
      alertId,
      pos.lat,
      pos.lng,
      accuracy: pos.accuracy,
      sourceType: 'WEARABLE_GPS',
      deviceId: deviceId,
    );
    if (!mounted) return false;
    setState(
      () => _locationNotice = pushed
          ? 'Đã có vị trí'
          : 'Chưa gửi được vị trí đồng hồ',
    );
    return pushed;
  }

  void _startLocationStreaming(String alertId, String deviceId) {
    _locationStreamTimer?.cancel();
    _locationStreamGuard.reset();
    _locationStreamTimer = Timer.periodic(
      _locationStreamPeriod,
      (_) => _streamLocation(alertId, deviceId),
    );
  }

  void _stopLocationStreaming({String? notice}) {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = null;
    _locationStreamGuard.reset();
    if (notice != null && mounted) {
      setState(() => _locationNotice = notice);
    }
  }

  Future<void> _streamLocation(String alertId, String deviceId) async {
    if (!mounted) return;
    try {
      final detail = await context.read<SosProvider>().fetchAlertDetail(
        alertId,
      );
      if (!mounted) return;
      final status = (detail['status']?.toString() ?? 'ACTIVE').toUpperCase();
      if (status != 'ACTIVE') {
        _stopLocationStreaming();
        return;
      }
    } catch (_) {
      if (_locationStreamGuard.recordFailure()) {
        _stopLocationStreaming(notice: 'Đã dừng gửi vị trí do lỗi liên tiếp');
      }
      return;
    }

    final pushed = await _pushPosition(alertId, deviceId, showLocating: false);
    if (!mounted) return;
    if (pushed) {
      _locationStreamGuard.recordSuccess();
    } else if (_locationStreamGuard.recordFailure()) {
      _stopLocationStreaming(notice: 'Đã dừng gửi vị trí do lỗi liên tiếp');
    }
  }

  /// "Hủy báo động" = người đeo tự xác nhận an toàn. Dùng `confirm-safety` chứ
  /// không dùng `cancel` — Swagger giới hạn cancel cho Trưởng/Phó nhóm, còn
  /// người đeo thường chỉ là thành viên.
  Future<void> _cancelAlert() async {
    final id = _alertId;
    if (id == null) {
      setState(() => _sent = false);
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<SosProvider>().confirmSafety(id);
      if (mounted) {
        _stopLocationStreaming();
        setState(() {
          _sent = false;
          _alertId = null;
          _alertCreated = false;
          _locationNotice = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending != null) return _alertView(_pending!);
    if (_sent) return _sentView();
    return _homeView();
  }

  // ── Màn chính: trạng thái + cảm biến thật + 3 nút giả lập ────────────────
  Widget _homeView() {
    final device = context.watch<WearableProvider>().currentDevice;
    final paired = device != null && device.isPaired;

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.sensors_rounded,
            label: 'Cảm biến SOS',
            color: WearPalette.green,
            trailing: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.sos,
                    ),
                  )
                : GestureDetector(
                    onTap: _refreshGateState,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: WearPalette.faint,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: WearPalette.sosSoft),
            ),
            const SizedBox(height: 6),
          ],
          // Spec: màn chính hiển thị trạng thái "An toàn".
          WearTile(
            icon: paired
                ? Icons.verified_user_rounded
                : Icons.watch_off_rounded,
            title: paired ? 'An toàn' : 'Chưa ghép thiết bị',
            subtitle: paired
                ? device.deviceName
                : 'Ghép thiết bị đeo trên điện thoại trước',
            color: paired ? WearPalette.green : WearPalette.faint,
            filled: paired,
          ),
          const SizedBox(height: 10),
          const WearSectionLabel('Cảm biến thật'),
          WearTile(
            icon: _sensorOn ? Icons.shield_rounded : Icons.shield_outlined,
            title: 'Phát hiện té ngã',
            subtitle: _sensorOn
                ? 'Đang bật · huỷ trong 20 giây'
                : 'Chạm để bật',
            color: _sensorOn ? WearPalette.green : WearPalette.faint,
            filled: _sensorOn,
            onTap: paired ? () => _toggleSensor(!_sensorOn) : null,
            trailing: Icon(
              _sensorOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 24,
              color: _sensorOn ? WearPalette.green : WearPalette.faint,
            ),
          ),
          const SizedBox(height: 6),
          // Chỉ có dữ liệu thật trên đồng hồ Wear OS thật có cảm biến PPG —
          // xem WearHeartRateBridge. Bật lên trên emulator/điện thoại thường
          // sẽ không nhận được mẫu nào (Health Services không có gì để đọc).
          WearTile(
            icon: _heartSensorOn
                ? Icons.monitor_heart_rounded
                : Icons.monitor_heart_outlined,
            title: 'Nhịp tim',
            subtitle: _heartSensorOn
                ? 'Đang đọc cảm biến thật'
                : 'Chạm để bật (cần đồng hồ Wear OS thật)',
            color: _heartSensorOn ? WearPalette.green : WearPalette.faint,
            filled: _heartSensorOn,
            onTap: paired ? () => _toggleHeartSensor(!_heartSensorOn) : null,
            trailing: Icon(
              _heartSensorOn
                  ? Icons.toggle_on_rounded
                  : Icons.toggle_off_rounded,
              size: 24,
              color: _heartSensorOn ? WearPalette.green : WearPalette.faint,
            ),
          ),
          const SizedBox(height: 10),
          // Máy ảo không có gia tốc kế thật để thử, nên phải có nút giả lập.
          const WearSectionLabel('Giả lập (demo)'),
          const SizedBox(height: 2),
          const Text(
            'Gửi một sự kiện cảm biến lên máy chủ — máy chủ tự quyết định có '
            'tạo cảnh báo hay không, khác với nút SOS thủ công.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: WearPalette.faint),
          ),
          const SizedBox(height: 6),
          ..._Trigger.values.map((t) {
            final canStart = _canStartSignal(t);
            final running = _signalRunning && _signalTrigger == t;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WearTile(
                icon: t.icon,
                title: switch (t) {
                  _Trigger.fall => 'Giả lập té ngã',
                  _Trigger.heartHigh => 'Giả lập nhịp tim cao',
                  _Trigger.heartLow => 'Giả lập nhịp tim thấp',
                },
                subtitle: running
                    ? (_signalReading ?? '')
                    : (canStart
                          ? (t.reading.isEmpty ? t.eventType : t.reading)
                          : _blockedReason(t)),
                color: running
                    ? WearPalette.green
                    : (canStart ? WearPalette.amber : WearPalette.faint),
                filled: running,
                onTap: (paired && !_signalRunning)
                    ? () => _runSignal(t)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Màn cảnh báo: đếm ngược 20s ──────────────────────────────────────────
  Widget _alertView(_Trigger t) {
    // KHÔNG cho cuộn: đây là màn đếm ngược, cả "Con ổn" lẫn "Gửi SOS" phải nằm
    // sẵn trong tầm mắt. Đổi lại nội dung phải tự vừa — từng khoảng cách dưới
    // đây đã bị cắt để có dư chỗ (trước đây tràn 4px trên đồng hồ tròn).
    return WearPage(
      child: WearFallAlertView(
        icon: t.icon,
        title: t.title,
        reading: _pendingReadingText ?? t.reading,
        question: t.question,
        countdown: _countdown,
        dismissLabel: t.dismissLabel,
        onDismiss: _dismiss,
        onSendNow: () {
          _timer?.cancel();
          _send(t);
        },
      ),
    );
  }

  // ── Màn đã gửi ───────────────────────────────────────────────────────────
  Widget _sentView() {
    final hasAlert = _alertCreated || _alertId != null;
    final reusedActiveAlert = !_alertCreated && _alertId != null;
    return WearPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasAlert ? Icons.campaign_rounded : Icons.done_all_rounded,
            size: 26,
            color: hasAlert ? WearPalette.sos : WearPalette.green,
          ),
          const SizedBox(height: 6),
          Text(
            hasAlert
                ? (reusedActiveAlert ? 'SOS đang hoạt động' : 'Đã gửi SOS')
                : 'Đã gửi sự kiện',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasAlert
                ? (reusedActiveAlert
                      ? 'BE ghi nhận SOS active hiện có'
                      : 'Đang thông báo cho người thân')
                // alertCreated=false là hợp lệ: BE chỉ tạo cảnh báo với một số
                // loại/cài đặt. Nếu chống duplicate, BE vẫn trả alertId active.
                : 'Máy chủ không tạo cảnh báo cho sự kiện này',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: WearPalette.faint),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: WearPalette.sosSoft),
            ),
          ],
          if (_locationNotice != null) ...[
            const SizedBox(height: 4),
            Text(
              _locationNotice!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: WearPalette.faint),
            ),
          ],
          const SizedBox(height: 10),
          WearPillButton(
            label: hasAlert ? 'Hủy báo động' : 'Xong',
            icon: hasAlert ? Icons.close_rounded : Icons.check_rounded,
            color: hasAlert ? WearPalette.faint : WearPalette.green,
            outlined: hasAlert,
            loading: _sending,
            onTap: _sending ? null : _cancelAlert,
          ),
        ],
      ),
    );
  }
}
