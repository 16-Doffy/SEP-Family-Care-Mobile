import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/sos_provider.dart';
import 'package:family_care/services/api_client.dart';

void main() {
  group('SosAlert.fromJson', () {
    test('parse đủ field cơ bản', () {
      final alert = SosAlert.fromJson({
        'id': 'a1',
        'status': 'ACTIVE',
        'message': 'Tôi cần giúp đỡ khẩn cấp',
        'address': '',
        'createdAt': '2026-06-22T10:00:00Z',
        'sender': {'fullName': 'Nguyễn Văn A'},
        'initialLatitude': 10.762622,
        'initialLongitude': 106.660172,
      });

      expect(alert.id, 'a1');
      expect(alert.status, 'ACTIVE');
      expect(alert.senderName, 'Nguyễn Văn A');
      expect(alert.latitude, 10.762622);
      expect(alert.longitude, 106.660172);
      expect(alert.hasLocation, isTrue);
    });

    test(
      'isActive chỉ true khi status ACTIVE — không còn ACKNOWLEDGED giả',
      () {
        expect(SosAlert.fromJson({'status': 'ACTIVE'}).isActive, isTrue);
        expect(SosAlert.fromJson({'status': 'RESOLVED'}).isActive, isFalse);
        expect(SosAlert.fromJson({'status': 'CANCELED'}).isActive, isFalse);
        expect(SosAlert.fromJson({'status': 'FALSE_ALARM'}).isActive, isFalse);
        expect(SosAlert.fromJson({'status': 'ACKNOWLEDGED'}).isActive, isFalse);
      },
    );

    test('thiếu field thì có giá trị mặc định an toàn, không throw', () {
      final alert = SosAlert.fromJson(<String, dynamic>{});
      expect(alert.id, '');
      expect(alert.status, 'ACTIVE');
      expect(alert.senderName, 'Thành viên');
      expect(alert.hasLocation, isFalse);
    });

    test('sender qua field triggeredBy (alias) vẫn parse được tên', () {
      final alert = SosAlert.fromJson({
        'triggeredBy': {'displayName': 'Trần Thị B'},
      });
      expect(alert.senderName, 'Trần Thị B');
    });
  });

  group('SosProvider — guard khi chưa có familyId', () {
    // Các action mutating phải throw rõ ràng khi thiếu family context,
    // không được âm thầm "thành công giả" (bug đã sửa: trước đây respond/
    // resolveAlert/cancelAlert/confirmSafety chỉ `return` im lặng).
    setUp(() => ApiClient.instance.clearSession());

    test('sendSos throw khi chưa có familyId', () async {
      final sos = SosProvider();
      expect(() => sos.sendSos(message: 'test'), throwsException);
    });

    test('respond throw khi chưa có familyId', () async {
      final sos = SosProvider();
      expect(() => sos.respond('a1', 'VIEWED'), throwsException);
    });

    test('resolveAlert throw khi chưa có familyId', () async {
      final sos = SosProvider();
      expect(() => sos.resolveAlert('a1'), throwsException);
    });

    test('cancelAlert throw khi chưa có familyId', () async {
      final sos = SosProvider();
      expect(() => sos.cancelAlert('a1'), throwsException);
    });

    test('confirmSafety throw khi chưa có familyId', () async {
      final sos = SosProvider();
      expect(() => sos.confirmSafety('a1'), throwsException);
    });

    test(
      'sending reset về false sau khi action throw (finally luôn chạy)',
      () async {
        final sos = SosProvider();
        try {
          await sos.resolveAlert('a1');
        } catch (_) {}
        expect(sos.sending, isFalse);
      },
    );
  });

  group('SosProvider — responder realtime locations', () {
    test('lưu responder location theo alertId + responderMemberId', () {
      final sos = SosProvider();

      sos.debugApplyResponderLocation({
        'sosAlertId': 'a1',
        'responderMemberId': 'm1',
        'responderMember': {
          'id': 'm1',
          'displayName': 'Ngo Pham Nhut Duy',
          'avatarUrl': 'https://example.test/duy.png',
        },
        'point': {
          'latitude': '10.774998',
          'longitude': '106.691014',
          'accuracy': 17,
          'recordedAt': '2026-08-17T08:00:00Z',
        },
      });

      final responders = sos.responderLocationsFor('a1');
      expect(responders, hasLength(1));
      expect(responders.single.responderMemberId, 'm1');
      expect(responders.single.displayName, 'Ngo Pham Nhut Duy');
      expect(responders.single.avatarUrl, 'https://example.test/duy.png');
      expect(responders.single.location.lat, 10.774998);
      expect(responders.single.location.lng, 106.691014);
      expect(responders.single.location.accuracy, 17);
    });

    test('clear responder locations khi alert resolved/canceled', () {
      final sos = SosProvider();

      sos.debugApplyResponderLocation({
        'sosAlertId': 'a1',
        'responderMemberId': 'm1',
        'responderMember': {'displayName': 'Duy'},
        'point': {'latitude': 10.77, 'longitude': 106.69},
      });
      expect(sos.responderLocationsFor('a1'), hasLength(1));

      sos.debugApplyResolved('a1');

      expect(sos.responderLocationsFor('a1'), isEmpty);
    });
  });
}
