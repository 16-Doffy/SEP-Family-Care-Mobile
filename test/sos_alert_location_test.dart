import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/utils/sos_alert_location.dart';

void main() {
  group('parseSosAlertLocation', () {
    test('đọc locationPoints theo contract SosAlertResponseDto', () {
      final loc = parseSosAlertLocation({
        'locationPoints': [
          {
            'latitude': '10.762622',
            'longitude': '106.660172',
            'sourceType': 'WEARABLE_GPS',
            'recordedAt': '2026-08-09T10:00:00.000Z',
          },
        ],
      });

      expect(loc, isNotNull);
      expect(loc!.lat, 10.762622);
      expect(loc.lng, 106.660172);
      expect(loc.sourceType, 'WEARABLE_GPS');
    });

    test('lấy điểm mới nhất theo recordedAt, kèm sourceType của điểm đó', () {
      final loc = parseSosAlertLocation({
        'locationPoints': [
          {
            'latitude': 10.0,
            'longitude': 106.0,
            'sourceType': 'WEARABLE_GPS',
            'recordedAt': '2026-08-09T10:05:00.000Z',
          },
          {
            'latitude': 11.0,
            'longitude': 107.0,
            'sourceType': 'MOBILE_GPS',
            'recordedAt': '2026-08-09T10:01:00.000Z',
          },
        ],
      });

      expect(loc?.lat, 10.0);
      expect(loc?.lng, 106.0);
      expect(loc?.sourceType, 'WEARABLE_GPS');
    });

    test('ưu tiên locationPoints mới nhất thay vì initialLatitude', () {
      final loc = parseSosAlertLocation({
        'initialLatitude': 1,
        'initialLongitude': 2,
        'locationPoints': [
          {
            'latitude': 10.5,
            'longitude': 106.5,
            'createdAt': '2026-08-09T10:00:00.000Z',
          },
        ],
      });

      expect(loc?.lat, 10.5);
      expect(loc?.lng, 106.5);
    });

    test('fallback sang initialLatitude khi chưa có điểm lịch sử', () {
      final loc = parseSosAlertLocation({
        'initialLatitude': '10.762622',
        'initialLongitude': '106.660172',
      });

      expect(loc?.lat, 10.762622);
      expect(loc?.lng, 106.660172);
    });

    test('trả danh sách điểm đã sort để vẽ đường đi', () {
      final points = parseSosAlertLocationPoints({
        'locationPoints': [
          {
            'latitude': 10.2,
            'longitude': 106.2,
            'sourceType': 'WEARABLE_GPS',
            'recordedAt': '2026-08-09T10:02:00.000Z',
          },
          {
            'latitude': 10.1,
            'longitude': 106.1,
            'sourceType': 'WEARABLE_GPS',
            'recordedAt': '2026-08-09T10:01:00.000Z',
          },
        ],
      });

      expect(points.map((p) => p.lat).toList(), [10.1, 10.2]);
      expect(points.last.sourceType, 'WEARABLE_GPS');
    });

    test('không có tọa độ hợp lệ thì trả null', () {
      expect(parseSosAlertLocation({'locationPoints': []}), isNull);
      expect(
        parseSosAlertLocation({
          'locationPoints': [
            {'latitude': 'bad', 'longitude': 106.0},
          ],
        }),
        isNull,
      );
    });
  });
}
