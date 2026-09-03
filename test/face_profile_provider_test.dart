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

  group('Face profile GET contract', () {
    test('old enrolled member without preview falls back safely', () {
      final profile = FaceProfile.fromJson('member-old', {
        'isEnrolled': true,
        'registeredImageCount': 3,
        'previewImage': null,
      });

      expect(profile.isEnrolled, isTrue);
      expect(profile.status, FaceProfileStatus.ready);
      expect(profile.registeredImageCount, 3);
      expect(profile.previewImageUrl, isNull);
    });

    test('re-enrolled member exposes preview image URL', () {
      final profile = FaceProfile.fromJson('member-new', {
        'isEnrolled': true,
        'registeredImageCount': 5,
        'previewImage': {'url': 'https://cdn.example.test/face-preview.jpg'},
      });

      expect(profile.isEnrolled, isTrue);
      expect(profile.registeredImageCount, 5);
      expect(
        profile.previewImageUrl,
        'https://cdn.example.test/face-preview.jpg',
      );
    });

    test('not-enrolled or deleted response resets profile values', () {
      final profile = FaceProfile.fromJson('member-none', {
        'isEnrolled': false,
        'registeredImageCount': 0,
        'previewImage': null,
      });

      expect(profile.isEnrolled, isFalse);
      expect(profile.status, FaceProfileStatus.notEnrolled);
      expect(profile.registeredImageCount, 0);
      expect(profile.previewImageUrl, isNull);
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

    test('normalizes one-based BE result indexes for image thumbnails', () {
      final response = FaceValidationResponse.fromJson({
        'canEnroll': false,
        'results': [
          {'index': 1, 'passed': true},
          {'index': 2, 'passed': false, 'reasonCode': 'MIME_MISMATCH'},
          {'index': 3, 'passed': false, 'reasonCode': 'IMAGE_TOO_LARGE'},
        ],
      });

      expect(response.results.map((result) => result.index), [0, 1, 2]);
      expect(
        response.results[1].displayMessage,
        'File sai định dạng/nội dung.',
      );
      expect(response.results[2].displayMessage, 'Ảnh quá 5MB.');
      expect(response.displayMessage, contains('Ảnh 2'));
      expect(response.displayMessage, contains('Ảnh 3'));
    });

    test('unavailable validate blocks enroll until images can be checked', () {
      final response = FaceValidationResponse.unavailable(
        'Không thể kiểm tra chất lượng ảnh lúc này. Vui lòng thử lại sau.',
      );

      expect(response.canEnroll, isFalse);
      expect(response.validationUnavailable, isTrue);
      expect(response.results, isEmpty);
      expect(response.displayMessage, contains('Không thể kiểm tra'));
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
