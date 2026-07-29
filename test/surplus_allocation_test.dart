import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/finance_provider.dart';

void main() {
  group('SurplusAvailability — số dư quỹ tháng còn phân bổ được', () {
    test('parse đúng theo contract BE', () {
      final s = SurplusAvailability.fromJson({
        'periodMonth': 6,
        'periodYear': 2026,
        'totalSurplus': 2000000,
        'allocatedSurplus': 500000,
        'availableSurplus': 1500000,
      });

      expect(s.periodMonth, 6);
      expect(s.periodYear, 2026);
      expect(s.totalSurplus, 2000000);
      expect(s.allocatedSurplus, 500000);
      expect(
        s.availableSurplus,
        1500000,
        reason: 'đây là mức chặn trên của số tiền được phân bổ',
      );
    });

    test('đã phân bổ hết thì availableSurplus = 0, không âm', () {
      final s = SurplusAvailability.fromJson({
        'periodMonth': 7,
        'periodYear': 2026,
        'totalSurplus': 1000000,
        'allocatedSurplus': 1000000,
        'availableSurplus': 0,
      });

      expect(s.availableSurplus, 0);
    });

    test('BE thiếu field thì về 0 chứ không crash', () {
      final s = SurplusAvailability.fromJson({});

      expect(s.periodMonth, 0);
      expect(s.totalSurplus, 0);
      expect(s.availableSurplus, 0);
    });

    test('số dạng chuỗi vẫn đọc được (BE từng trả string cho tiền)', () {
      final s = SurplusAvailability.fromJson({
        'periodMonth': 6,
        'periodYear': 2026,
        'availableSurplus': '1500000',
      });

      expect(s.availableSurplus, 1500000);
    });
  });
}
