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

/// Cú ngã "mềm" mà bộ ngưỡng cũ (6.0 / 25.0) bỏ sót: máy trong túi nên biên độ
/// chỉ tụt xuống 6.4–6.9 m/s², và tiếp đất trên bề mặt mềm nên va đập chỉ ~20.5
/// m/s² chứ không tới 25. Đây chính là ca "lúc detect được lúc không" mà test
/// thực tế ngày 2026-09-03 báo về.
List<(double, int)> softFallPattern({int start = 0}) => [
  (9.8, start),
  (6.6, start + 100),
  (6.9, start + 150),
  (6.4, start + 200),
  (20.5, start + 260),
  (9.7, start + 320),
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

    test('rơi tự do 6–7 m/s² rồi va đập ~20 m/s² → phát hiện té ngã', () {
      final d = FallDetector();
      expect(
        runSamples(d, softFallPattern()),
        1,
        reason: 'ngưỡng cũ 6.0/25.0 bỏ sót hoàn toàn ca này',
      );
    });

    test('va đập đúng bằng ngưỡng 19.0 → vẫn tính là ngã', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (6.8, 100),
        (6.5, 180),
        (19.0, 240), // đúng bằng impactThreshold, so sánh là >=
        (9.8, 300),
      ];
      expect(runSamples(d, samples), 1);
    });

    test('va đập đến ở mép cuối cửa sổ 1200ms → vẫn tính là ngã', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (1.0, 100),
        (0.9, 200),
        (9.8, 300), // hết pha rơi tại đây
        (21.0, 1450), // 1150ms sau, còn trong cửa sổ 1200ms
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

    test('biên độ chạm 7.5 m/s² (chưa dưới ngưỡng 7.0) → không phát hiện', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (7.6, 100),
        (8.2, 150),
        (21.0, 200), // va đập đủ mạnh nhưng trước đó không có pha rơi hợp lệ
        (9.8, 260),
      ];
      expect(runSamples(d, samples), 0);
    });

    test('rơi tự do quá ngắn (cú xóc) → không phát hiện', () {
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (1.0, 50), // chỉ 1 mẫu dưới ngưỡng
        (30.0, 90), // 40ms < minFreeFall 60ms
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

    test('ngồi phịch xuống ghế (va đập ~15 m/s²) → không phát hiện', () {
      // Chốt chặn của ngưỡng 19.0: hạ tiếp xuống 15 là ca này bắt đầu báo giả.
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (5.0, 100),
        (4.8, 180),
        (15.0, 240),
        (9.8, 300),
      ];
      expect(runSamples(d, samples), 0);
    });

    test('đi lại bình thường → không phát hiện', () {
      // Đáy mỗi bước chân có thể chạm 6.8 m/s², tức là LỌT vào pha rơi tự do
      // của ngưỡng 7.0 — thứ chặn lại là không có cú va đập ≥19 ngay sau đó.
      final d = FallDetector();
      final samples = [
        (9.8, 0),
        (7.2, 100),
        (12.5, 200),
        (6.8, 300),
        (13.1, 400),
        (8.4, 500),
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
        (30.0, 1700), // 1400ms > impactWindow 1200ms
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

    test('cooldown chặn cả cú ngã mềm đi theo ngay sau đó', () {
      final d = FallDetector();
      expect(runSamples(d, softFallPattern()), 1);
      expect(runSamples(d, softFallPattern(start: 8000)), 0);
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

    test('giá trị mặc định khớp với FallDetector.kt phía Android', () {
      // Bộ số này được sửa đồng thời ở hai nơi; test khoá lại phía Dart để lần
      // sau ai đổi một bên mà quên bên kia thì thấy ngay.
      const t = FallDetectionTuning();
      expect(t.freeFallThreshold, 7.0);
      expect(t.minFreeFall, const Duration(milliseconds: 60));
      expect(t.impactThreshold, 19.0);
      expect(t.impactWindow, const Duration(milliseconds: 1200));
      expect(t.cooldown, const Duration(seconds: 30));
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
