enum HeartRateAnalysisPhase { normal, highThreshold, lowThreshold }

class HeartRateDetectionReading {
  final int bpm;
  final Duration at;
  final HeartRateAnalysisPhase phase;
  final int abnormalSeconds;
  final int observedSeconds;
  final bool detected;

  const HeartRateDetectionReading({
    required this.bpm,
    required this.at,
    required this.phase,
    required this.abnormalSeconds,
    required this.observedSeconds,
    required this.detected,
  });
}

class HeartRateDetectionResult {
  final bool high;
  final int heartRate;
  final int abnormalSeconds;

  const HeartRateDetectionResult({
    required this.high,
    required this.heartRate,
    required this.abnormalSeconds,
  });
}

class HeartRateDetector {
  final int thresholdHigh;
  final int thresholdLow;
  final Duration minAbnormalDuration;

  Duration? _abnormalStart;
  HeartRateAnalysisPhase _phase = HeartRateAnalysisPhase.normal;
  bool _triggered = false;
  HeartRateDetectionResult? _lastResult;

  HeartRateDetector({
    this.thresholdHigh = 130,
    this.thresholdLow = 50,
    this.minAbnormalDuration = const Duration(seconds: 10),
  });

  HeartRateAnalysisPhase get phase => _phase;
  HeartRateDetectionResult? get lastResult => _lastResult;

  void reset() {
    _abnormalStart = null;
    _phase = HeartRateAnalysisPhase.normal;
    _triggered = false;
    _lastResult = null;
  }

  HeartRateDetectionReading addSample(int bpm, Duration at) {
    _lastResult = null;

    final nextPhase = bpm > thresholdHigh
        ? HeartRateAnalysisPhase.highThreshold
        : (bpm < thresholdLow
              ? HeartRateAnalysisPhase.lowThreshold
              : HeartRateAnalysisPhase.normal);

    if (nextPhase == HeartRateAnalysisPhase.normal) {
      _abnormalStart = null;
      _phase = nextPhase;
      _triggered = false;
      return HeartRateDetectionReading(
        bpm: bpm,
        at: at,
        phase: _phase,
        abnormalSeconds: 0,
        observedSeconds: at.inSeconds,
        detected: false,
      );
    }

    if (_phase != nextPhase) {
      _abnormalStart = at;
      _triggered = false;
    }
    _phase = nextPhase;

    final abnormalSeconds = (at - (_abnormalStart ?? at)).inSeconds
        .clamp(0, 1 << 31)
        .toInt();
    final detected =
        !_triggered && abnormalSeconds >= minAbnormalDuration.inSeconds;
    if (detected) {
      _triggered = true;
      _lastResult = HeartRateDetectionResult(
        high: _phase == HeartRateAnalysisPhase.highThreshold,
        heartRate: bpm,
        abnormalSeconds: abnormalSeconds,
      );
    }

    return HeartRateDetectionReading(
      bpm: bpm,
      at: at,
      phase: _phase,
      abnormalSeconds: abnormalSeconds,
      observedSeconds: at.inSeconds,
      detected: detected,
    );
  }
}
