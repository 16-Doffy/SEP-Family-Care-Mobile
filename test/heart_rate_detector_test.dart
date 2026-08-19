import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/services/heart_rate_detector.dart';

void main() {
  group('HeartRateDetector — nhịp tim cao', () {
    test('vượt 130 bpm đủ lâu thì kết luận bất thường', () {
      final detector = HeartRateDetector(
        minAbnormalDuration: const Duration(seconds: 15),
      );
      final samples = [
        (78, 0),
        (92, 5),
        (118, 10),
        (136, 15),
        (142, 20),
        (145, 25),
        (143, 30),
      ];

      HeartRateDetectionReading? detected;
      for (final (bpm, second) in samples) {
        final reading = detector.addSample(bpm, Duration(seconds: second));
        if (reading.detected) detected = reading;
      }

      expect(detected, isNotNull);
      expect(detected!.phase, HeartRateAnalysisPhase.highThreshold);
      expect(detector.lastResult?.high, isTrue);
      expect(detector.lastResult?.heartRate, 143);
      expect(detector.lastResult?.abnormalSeconds, 15);
    });
  });

  group('HeartRateDetector — nhịp tim thấp', () {
    test('dưới 50 bpm đủ lâu thì kết luận bất thường', () {
      final detector = HeartRateDetector();
      final samples = [
        (76, 0),
        (68, 5),
        (59, 10),
        (51, 15),
        (45, 20),
        (39, 25),
        (38, 30),
      ];

      HeartRateDetectionReading? detected;
      for (final (bpm, second) in samples) {
        final reading = detector.addSample(bpm, Duration(seconds: second));
        if (reading.detected) detected = reading;
      }

      expect(detected, isNotNull);
      expect(detected!.phase, HeartRateAnalysisPhase.lowThreshold);
      expect(detector.lastResult?.high, isFalse);
      expect(detector.lastResult?.heartRate, 38);
      expect(detector.lastResult?.abnormalSeconds, 10);
    });

    test('chỉ vượt ngưỡng thoáng qua thì không kết luận', () {
      final detector = HeartRateDetector();
      final samples = [(76, 0), (45, 5), (72, 10), (46, 15), (74, 20)];

      final hits = samples
          .map((s) => detector.addSample(s.$1, Duration(seconds: s.$2)))
          .where((reading) => reading.detected)
          .length;

      expect(hits, 0);
      expect(detector.lastResult, isNull);
    });
  });
}
