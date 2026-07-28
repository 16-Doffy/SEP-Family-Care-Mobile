import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/face_profile_provider.dart';

void main() {
  group('FaceProfile.fromJson', () {
    test('maps known backend statuses to UI states', () {
      expect(
        FaceProfile.fromJson('member-1', {'status': 'READY'}).status,
        FaceProfileStatus.ready,
      );
      expect(
        FaceProfile.fromJson('member-1', {
          'profileStatus': 'PROCESSING',
        }).status,
        FaceProfileStatus.processing,
      );
      expect(
        FaceProfile.fromJson('member-1', {'status': 'DISABLED'}).status,
        FaceProfileStatus.disabled,
      );
      expect(
        FaceProfile.fromJson('member-1', {'status': 'FAILED'}).status,
        FaceProfileStatus.failed,
      );
    });

    test('empty or 404-style payload is a safe not-enrolled state', () {
      final profile = FaceProfile.fromJson('member-1', const {});
      expect(profile.memberId, 'member-1');
      expect(profile.status, FaceProfileStatus.notEnrolled);
      expect(profile.label, 'Chưa thiết lập');
    });
  });

  group('FaceValidationResponse.fromJson', () {
    test('maps canEnroll and per-image reason codes', () {
      final response = FaceValidationResponse.fromJson({
        'canEnroll': false,
        'results': [
          {'index': 0, 'passed': true},
          {'index': 1, 'passed': false, 'reasonCode': 'NO_FACE_DETECTED'},
          {
            'index': 2,
            'passed': false,
            'reasonCode': 'MULTIPLE_FACES_DETECTED',
          },
        ],
      });

      expect(response.canEnroll, isFalse);
      expect(response.results, hasLength(3));
      expect(response.results[1].displayMessage, 'Không phát hiện khuôn mặt.');
      expect(
        response.results[2].displayMessage,
        'Ảnh có nhiều hơn 1 khuôn mặt.',
      );
      expect(response.displayMessage, contains('Ảnh 2'));
    });

    test('infers canEnroll when every result passes', () {
      final response = FaceValidationResponse.fromJson({
        'results': [
          {'passed': true},
          {'passed': true},
          {'passed': true},
        ],
      });

      expect(response.canEnroll, isTrue);
    });

    test('unavailable validate keeps enroll flow open', () {
      final response = FaceValidationResponse.unavailable(
        'BE chưa bật API kiểm tra ảnh. FE sẽ dùng luồng đăng ký hiện tại.',
      );

      expect(response.canEnroll, isTrue);
      expect(response.validationUnavailable, isTrue);
      expect(response.results, isEmpty);
      expect(response.displayMessage, contains('BE chưa bật API'));
    });

    test('respects explicit failed result even without reason code', () {
      final response = FaceValidationResponse.fromJson({
        'results': [
          {'passed': false},
          {'passed': true},
          {'passed': true},
        ],
      });

      expect(response.canEnroll, isFalse);
      expect(
        response.results.first.displayMessage,
        'Ảnh chưa đạt yêu cầu đăng ký.',
      );
    });
  });
}
