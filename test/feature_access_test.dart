import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/models/feature_access.dart';

void main() {
  group('FeatureAccess', () {
    test('đọc key lồng từ schema mới của BE', () {
      final access = FeatureAccess.fromJson({
        'calendar': {
          'enabled': true,
          'reminders': true,
          'recurringEvents': false,
        },
      });

      expect(access.calendarEnabled, isTrue);
      expect(access.calendarReminders, isTrue);
      expect(access.calendarRecurringEvents, isFalse);
    });

    test('đọc key dot và key phẳng cũ để tương thích dữ liệu hiện tại', () {
      final access = FeatureAccess.fromJson({
        'calendar.enabled': true,
        'calendarReminders': true,
        'aiEnabled': true,
        'advancedFinance': true,
      });

      expect(access.calendarEnabled, isTrue);
      expect(access.calendarReminders, isTrue);
      expect(access.aiEnabled, isTrue);
      expect(access.advancedFinance, isTrue);
    });
  });
}
