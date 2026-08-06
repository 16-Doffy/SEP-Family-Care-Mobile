import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/services/fall_detector_service.dart';

/// Nạp chuỗi mẫu `(độ lớn gia tốc, mốc thời gian ms)` vào detector và trả về số
/// lần nó kết luận "có té ngã".
int runSamples(FallDetector d, List<(double, int)> samples) {
  var hits = 0;
  for (final (mag, ms) in samples) {
    if (d.addSample(mag, Duration(milliseconds: ms))) hits++;
  }
  return hits;
}

/// Chuỗi mẫu của một cú ngã thật: nằm yên (≈9.8) → rơi tự do (≈1) đủ lâu →
/// va đập (≈30) → nằm yên.
List<(double, int)> fallPattern({int start = 0}) => [
  (9.8, start),
  (9.7, start + 50),
  (1.0, start + 100),
  (0.8, start + 150),
  (1.2, start + 200),
  (0.9, start + 250),
  (30.0, start + 300),
  (9.9, start + 350),
];

void main() {
  group('FallDetector — nhận đúng cú ngã', () {
    test('rơi tự do đủ lâu rồi va đập mạnh → phát hiện té ngã', () {
      final d = FallDetector();
      expect(runSamples(d, fallPattern()), 1);
    });

    test('phát hiện đúng MỘT lần cho mỗi cú ngã, không bắn lặp', () {
      final d = FallDetector();
      final samples = [
        ...fallPattern(),
        // Va đập tiếp sau đó (nảy lên) không được tính thành cú ngã thứ hai.
        (28.0, 400),
        (26.0, 450),
        (9.8, 500),
      ];
      expect(runSamples(d, samples), 1);
    });
  });

  group('FallDetector — loại báo nhầm', () {
    test('rung mạnh mà KHÔNG có pha rơi tự do → không phát hiện', () {
      final d = FallDetector();
      // Lắc điện thoại: vượt xa ngưỡng va đập nhưng chưa bao giờ về gần 0.
      final samples = [
        (9.8, 0),
        (28.0, 50),
        (8.0, 100),
        (31.0, 150),
        (7.5, 200),
        (29.0, 250),
      ];
      expect(
        runSamples(d, samples),
        0,
        reason: 'đi xe máy đường xóc / lắc tay không phải té ngã',
      );
    });

    test('rơi tự do quá ngắn (cú xóc) → không phát hiện', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (1.0, 50), // chỉ 1 mẫu dưới ngưỡng
        (30.0, 90), // 40ms < minFreeFall 100ms
        (9.8, 140),
      ];
      expect(runSamples(d, samples), 0);
    });

    test('rơi tự do nhưng hạ cánh nhẹ (không va đập) → không phát hiện', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (1.0, 100),
        (0.9, 200),
        (1.1, 300),
        (10.5, 400), // đặt xuống nhẹ nhàng
        (9.8, 500),
      ];
      expect(runSamples(d, samples), 0);
    });

    test('va đập đến quá muộn sau khi hết rơi → không phát hiện', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (1.0, 100),
        (0.9, 200),
        (9.8, 300), // hết pha rơi
        (30.0, 1400), // 1100ms > impactWindow 900ms
      ];
      expect(runSamples(d, samples), 0);
    });
  });

  group('FallDetector — cooldown', () {
    test('trong thời gian nghỉ thì cú ngã thứ hai bị bỏ qua', () {
      final d = FallDetector();
      expect(runSamples(d, fallPattern()), 1);
      // Cú ngã thứ hai chỉ 5 giây sau, còn trong cooldown 30 giây.
      expect(runSamples(d, fallPattern(start: 5000)), 0);
    });

    test('hết thời gian nghỉ thì phát hiện lại bình thường', () {
      final d = FallDetector();
      expect(runSamples(d, fallPattern()), 1);
      expect(runSamples(d, fallPattern(start: 40000)), 1);
    });
  });

  group('FallDetector — cấu hình', () {
    test('ngưỡng chặt hơn thì cú va đập yếu không còn tính là ngã', () {
      final d = FallDetector(
        tuning: const FallDetectionTuning(impactThreshold: 40.0),
      );
      expect(runSamples(d, fallPattern()), 0);
    });

    test('reset() đưa máy trạng thái về idle', () {
      final d = FallDetector();
      d.addSample(1.0, const Duration(milliseconds: 100));
      expect(d.phase, 'freeFall');
      d.reset();
      expect(d.phase, 'idle');
    });
  });
}
