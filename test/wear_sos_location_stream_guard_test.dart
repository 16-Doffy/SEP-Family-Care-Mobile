import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/wear/wear_sos_location_stream_guard.dart';

void main() {
  group('WearSosLocationStreamGuard', () {
    test('dừng sau 3 lỗi liên tiếp', () {
      final guard = WearSosLocationStreamGuard();

      expect(guard.recordFailure(), isFalse);
      expect(guard.recordFailure(), isFalse);
      expect(guard.recordFailure(), isTrue);
      expect(guard.consecutiveFailures, 3);
    });

    test('gửi thành công reset bộ đếm lỗi', () {
      final guard = WearSosLocationStreamGuard();

      guard.recordFailure();
      guard.recordFailure();
      guard.recordSuccess();

      expect(guard.consecutiveFailures, 0);
      expect(guard.recordFailure(), isFalse);
    });
  });
}
