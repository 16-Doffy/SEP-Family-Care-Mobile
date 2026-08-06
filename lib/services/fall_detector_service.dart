import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Phát hiện té ngã bằng gia tốc kế của điện thoại.
///
/// Đây là phần hiện thực cho cài đặt **`autoCreateAlertFromFall`** mà BE đã có
/// sẵn trong `UpdateSosSettingsDto` ("Tự tạo cảnh báo SOS khi thiết bị phát hiện
/// té ngã"). Trước đây toggle này chỉ được lưu lên server, còn điện thoại không
/// làm gì cả — chỉ màn `lib/wear/screens/wear_status_screen.dart` có code nhận
/// biết, mà màn đó lại không còn nơi nào điều hướng tới.
///
/// **Không dùng ngưỡng rung đơn thuần.** Đo một cú "rung mạnh" thì đi xe máy
/// đường xóc hay để điện thoại trong túi lúc chạy cũng vượt ngưỡng. Thay vào đó
/// bắt đúng hình dạng của một cú ngã: **rơi tự do rồi va đập**.
///
/// ```
///  |m|
///   ~9.8 ┤───────╮                      ╭──── (nằm yên sau khi ngã)
///        │       │      va đập ──▶ ╱╲   │
///   ~25  ┤       │               ╱   ╲  │
///        │       ╰──────╮       ╱     ╲╱
///   ~0   ┤   rơi tự do  ╰──────╯
///        └──────────────────────────────────▶ t
/// ```
///
/// Khi rơi, gia tốc kế đo được gần 0 (mọi phần của thiết bị rơi cùng nhau nên
/// mất "trọng lực biểu kiến"). Khi đập xuống thì vọt lên rất cao. Phải có **cả
/// hai pha, đúng thứ tự, trong một cửa sổ thời gian** mới tính là ngã.
///
/// Hạn chế phải nói rõ với người dùng (xem `sos_settings_screen`):
/// - Chỉ chạy khi app đang mở (foreground). Muốn chạy nền phải có foreground
///   service + quyền `FOREGROUND_SERVICE_SPECIAL_USE`, chi phí lớn hơn nhiều.
/// - **Rơi điện thoại** cũng cho ra đúng dạng tín hiệu này. Vì vậy luôn phải có
///   bước đếm ngược để người dùng bấm huỷ, không được gửi SOS ngay.
class FallDetectionTuning {
  /// Dưới ngưỡng này (m/s²) coi như đang rơi tự do. Nằm yên ≈ 9.81.
  final double freeFallThreshold;

  /// Phải rơi đủ lâu mới tính, để loại cú xóc ngắn.
  final Duration minFreeFall;

  /// Trên ngưỡng này (m/s²) coi như va đập.
  final double impactThreshold;

  /// Va đập phải đến trong khoảng này sau khi hết rơi tự do.
  final Duration impactWindow;

  /// Sau một lần phát hiện thì nghỉ, tránh bắn liên tiếp cùng một cú ngã.
  final Duration cooldown;

  const FallDetectionTuning({
    this.freeFallThreshold = 3.0,
    this.minFreeFall = const Duration(milliseconds: 100),
    this.impactThreshold = 25.0,
    this.impactWindow = const Duration(milliseconds: 900),
    this.cooldown = const Duration(seconds: 30),
  });
}

enum _Phase { idle, freeFall, awaitingImpact }

/// Máy trạng thái thuần — không phụ thuộc sensor, `DateTime.now()` hay Flutter,
/// nên test được bằng cách nạp thẳng chuỗi mẫu (xem `test/fall_detection_test.dart`).
class FallDetector {
  final FallDetectionTuning tuning;

  _Phase _phase = _Phase.idle;
  Duration? _freeFallStart;
  Duration? _freeFallEnd;
  Duration? _lastTrigger;

  FallDetector({this.tuning = const FallDetectionTuning()});

  @visibleForTesting
  String get phase => _phase.name;

  void reset() {
    _phase = _Phase.idle;
    _freeFallStart = null;
    _freeFallEnd = null;
  }

  /// Nạp một mẫu độ lớn gia tốc tại thời điểm [at]. Trả `true` **đúng một lần**
  /// cho mỗi cú ngã nhận được.
  bool addSample(double magnitude, Duration at) {
    final last = _lastTrigger;
    if (last != null && at - last < tuning.cooldown) {
      reset();
      return false;
    }

    if (magnitude <= tuning.freeFallThreshold) {
      if (_phase == _Phase.idle) {
        _phase = _Phase.freeFall;
        _freeFallStart = at;
      }
      // Đang trong pha rơi (hoặc rơi tiếp) → chưa kết luận gì.
      return false;
    }

    // Đã ra khỏi vùng rơi tự do.
    if (_phase == _Phase.freeFall) {
      final fell = at - (_freeFallStart ?? at);
      if (fell >= tuning.minFreeFall) {
        _phase = _Phase.awaitingImpact;
        _freeFallEnd = at;
      } else {
        // Rơi quá ngắn → chỉ là xóc, không phải ngã.
        reset();
        return false;
      }
    }

    if (_phase != _Phase.awaitingImpact) return false;

    if (at - (_freeFallEnd ?? at) > tuning.impactWindow) {
      // Rơi xong mà không có va đập → hạ cánh nhẹ, bỏ qua.
      reset();
      return false;
    }
    if (magnitude >= tuning.impactThreshold) {
      _lastTrigger = at;
      reset();
      return true;
    }
    return false;
  }
}

/// Bọc [FallDetector] quanh stream gia tốc kế thật.
///
/// Dùng `accelerometerEventStream()` (CÓ trọng lực) chứ không phải
/// `userAccelerometerEventStream()` — pha rơi tự do chỉ nhìn thấy được khi
/// trọng lực còn trong số đo: nằm yên ≈ 9.8, rơi ≈ 0.
class FallDetectorService {
  static final FallDetectorService instance = FallDetectorService._();
  FallDetectorService._();

  static const _samplingPeriod = Duration(milliseconds: 50);

  StreamSubscription<AccelerometerEvent>? _sub;
  final Stopwatch _clock = Stopwatch();
  FallDetector _detector = FallDetector();
  VoidCallback? _onFall;

  bool get isRunning => _sub != null;

  void start({
    required VoidCallback onFall,
    FallDetectionTuning tuning = const FallDetectionTuning(),
  }) {
    _onFall = onFall;
    if (_sub != null) return;
    _detector = FallDetector(tuning: tuning);
    _clock
      ..reset()
      ..start();
    _sub = accelerometerEventStream(samplingPeriod: _samplingPeriod).listen(
      _onEvent,
      onError: (_) {
        // Thiết bị không có gia tốc kế (máy ảo, một số tablet) → tắt hẳn,
        // không để stream lỗi lặp lại.
        stop();
      },
      cancelOnError: true,
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _clock.stop();
    _detector.reset();
    _onFall = null;
  }

  void _onEvent(AccelerometerEvent e) {
    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (_detector.addSample(magnitude, _clock.elapsed)) {
      _onFall?.call();
    }
  }
}
