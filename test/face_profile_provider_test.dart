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
}
