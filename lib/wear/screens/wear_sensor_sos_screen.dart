import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/sos_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../services/fall_detector_service.dart';
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

  /// `rawValue` bám đúng ví dụ trong spec.
  /// ⚠️ [VERIFY] Case nhịp tim **thấp** không có trong spec — `thresholdLow` là
  /// FE suy ra đối xứng với `thresholdHigh`, cần BE xác nhận tên field.
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
}

class _WearSensorSosScreenState extends State<WearSensorSosScreen> {
  /// Spec: "Tự gửi SOS sau 20s".
  static const _countdownSeconds = 20;

  bool _sensorOn = false;
  _Trigger? _pending;
  int _countdown = 0;
  Timer? _timer;

  bool _sending = false;
  bool _sent = false;
  String? _alertId;
  bool _alertCreated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Cần deviceId để gửi sự kiện cảm biến → phải biết tài khoản đã ghép
    // wearable nào chưa.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WearableProvider>().fetchCurrentDevice(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    FallDetectorService.instance.stop();
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

  void _raise(_Trigger trigger) {
    if (!mounted || _pending != null || _sending || _sent) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _pending = trigger;
      _countdown = _countdownSeconds;
      _error = null;
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
      _countdown = 0;
    });
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
    });
    try {
      final result = await context.read<WearableProvider>().createEvent(
        device.id,
        eventType: trigger.eventType,
        severity: trigger.severity,
        rawValue: trigger.rawValue,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _alertCreated = result.alertCreated;
        _alertId = result.alertId;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
        setState(() {
          _sent = false;
          _alertId = null;
          _alertCreated = false;
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
                : null,
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
          const SizedBox(height: 10),
          // Máy ảo không có gia tốc kế thật để thử, nên phải có nút giả lập.
          const WearSectionLabel('Giả lập (demo)'),
          ..._Trigger.values.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WearTile(
                icon: t.icon,
                title: switch (t) {
                  _Trigger.fall => 'Giả lập té ngã',
                  _Trigger.heartHigh => 'Giả lập nhịp tim cao',
                  _Trigger.heartLow => 'Giả lập nhịp tim thấp',
                },
                subtitle: t.reading.isEmpty ? t.eventType : t.reading,
                color: WearPalette.amber,
                onTap: paired ? () => _raise(t) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Màn cảnh báo: đếm ngược 20s ──────────────────────────────────────────
  Widget _alertView(_Trigger t) {
    return WearPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(t.icon, size: 24, color: WearPalette.sos),
          const SizedBox(height: 5),
          Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          if (t.reading.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              t.reading,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: WearPalette.sos,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            t.question,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: WearPalette.muted),
          ),
          const SizedBox(height: 2),
          Text(
            'Tự gửi SOS sau $_countdown giây',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8, color: WearPalette.faint),
          ),
          const SizedBox(height: 8),
          // Nút huỷ để trên và nổi hơn: đây là nút chống báo nhầm.
          WearPillButton(
            label: t.dismissLabel,
            icon: Icons.check_rounded,
            color: WearPalette.green,
            onTap: _dismiss,
          ),
          const SizedBox(height: 6),
          WearPillButton(
            label: 'Gửi SOS',
            icon: Icons.sos_rounded,
            color: WearPalette.sos,
            onTap: () {
              _timer?.cancel();
              _send(t);
            },
          ),
        ],
      ),
    );
  }

  // ── Màn đã gửi ───────────────────────────────────────────────────────────
  Widget _sentView() {
    return WearPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _alertCreated ? Icons.campaign_rounded : Icons.done_all_rounded,
            size: 26,
            color: _alertCreated ? WearPalette.sos : WearPalette.green,
          ),
          const SizedBox(height: 6),
          Text(
            _alertCreated ? 'Đã gửi SOS' : 'Đã gửi sự kiện',
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
            _alertCreated
                ? 'Đang thông báo cho người thân'
                // alertCreated=false là hợp lệ: BE chỉ tạo cảnh báo với một số
                // loại/cài đặt (té ngã cần autoCreateAlertFromFall = true).
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
          const SizedBox(height: 10),
          WearPillButton(
            label: _alertCreated ? 'Hủy báo động' : 'Xong',
            icon: _alertCreated ? Icons.close_rounded : Icons.check_rounded,
            color: _alertCreated ? WearPalette.faint : WearPalette.green,
            outlined: _alertCreated,
            loading: _sending,
            onTap: _sending ? null : _cancelAlert,
          ),
        ],
      ),
    );
  }
}
