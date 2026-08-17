import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/services/sos_realtime_service.dart';

void main() {
  group('SosRealtimeService responder events', () {
    test('parse sos:responder:track:start payload', () {
      final event = SosTrackStartEvent.fromJson({
        'alertId': 'a1',
        'workspaceId': 'fam1',
        'intervalSec': 5,
      });

      expect(event.alertId, 'a1');
      expect(event.workspaceId, 'fam1');
      expect(event.intervalSec, 5);
    });

    test('parse sos:responder:location payload', () {
      final event = SosResponderLocationEvent.fromJson({
        'sosAlertId': 'a1',
        'responderMemberId': 'm2',
        'responderMember': {
          'id': 'm2',
          'displayName': 'Ngo Pham Nhut Duy',
          'avatarUrl': 'https://example.test/avatar.png',
        },
        'point': {
          'latitude': '10.774998',
          'longitude': 106.691014,
          'accuracy': 17,
          'recordedAt': '2026-08-17T08:00:00Z',
        },
      });

      expect(event.sosAlertId, 'a1');
      expect(event.responderMemberId, 'm2');
      expect(event.responderMember['displayName'], 'Ngo Pham Nhut Duy');
      expect(event.point['latitude'], '10.774998');
      expect(event.point['longitude'], 106.691014);
    });

    test('build responder location push payload uses BE contract fields', () {
      final recordedAt = DateTime.utc(2026, 8, 17, 8, 1, 2);
      final payload = SosRealtimeService.buildLocationPayload(
        workspaceId: 'fam1',
        alertId: 'a1',
        latitude: 10.774998,
        longitude: 106.691014,
        accuracy: 12,
        sourceType: 'MOBILE_GPS',
        recordedAt: recordedAt,
      );

      expect(
        SosRealtimeService.responderLocationPushEventName,
        'sos:responder:location:push',
      );
      expect(payload, {
        'workspaceId': 'fam1',
        'alertId': 'a1',
        'latitude': 10.774998,
        'longitude': 106.691014,
        'accuracy': 12,
        'sourceType': 'MOBILE_GPS',
        'recordedAt': '2026-08-17T08:01:02.000Z',
      });
    });

    test('reject invalid coordinates before emitting', () {
      expect(SosRealtimeService.isValidCoordinate(10, 106), isTrue);
      expect(SosRealtimeService.isValidCoordinate(91, 106), isFalse);
      expect(SosRealtimeService.isValidCoordinate(10, 181), isFalse);
      expect(SosRealtimeService.isValidCoordinate(double.nan, 106), isFalse);
    });
  });
}
