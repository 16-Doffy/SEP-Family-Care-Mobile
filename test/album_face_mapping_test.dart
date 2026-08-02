import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/album_media.dart';
import 'package:family_care/providers/album_face_provider.dart';

void main() {
  test('FaceSuggestion reads member name from nested backend payload', () {
    final suggestion = FaceSuggestion.fromJson({
      'id': 's1',
      'familyMemberId': 'member-1',
      'confidence': 0.93,
      'suggestedMember': {
        'id': 'member-1',
        'user': {'fullName': 'Zap MEM 2'},
      },
    });

    expect(suggestion.id, 's1');
    expect(suggestion.memberId, 'member-1');
    expect(suggestion.memberName, 'Zap MEM 2');
  });

  test(
    'FaceSuggestion marks resolved statuses so they stop showing as todo',
    () {
      FaceSuggestion withStatus(String status) =>
          FaceSuggestion.fromJson({'id': 's1', 'status': status});

      // Đã xử lý → không được hiện lại kèm nút Xác nhận.
      expect(withStatus('CONFIRMED').isResolved, isTrue);
      expect(withStatus('REJECTED').isResolved, isTrue);
      expect(withStatus('ACCEPTED').isResolved, isTrue);

      // Chờ xử lý, hoặc status lạ/thiếu → vẫn hiện (fail-open).
      expect(withStatus('PENDING').isResolved, isFalse);
      expect(withStatus('').isResolved, isFalse);
      expect(withStatus('SOME_NEW_BE_STATUS').isResolved, isFalse);
    },
  );

  test('confidence chỉ dùng để hiển thị, không tự xác nhận suggestion', () {
    expect(
      FaceSuggestion.fromJson({
        'id': 's1',
        'confidence': 93,
      }).normalizedConfidence,
      0.93,
    );
    // Flow nghiệp vụ bắt buộc người dùng gọi confirm thủ công; model không còn
    // cung cấp cờ auto-tag dựa trên confidence.
  });

  test('mỗi khuôn mặt chỉ giữ ứng viên có confidence cao nhất', () {
    final suggestions = parseFaceSuggestions({
      'faces': [
        {
          'faceId': 'face-1',
          'faceIndex': 0,
          'candidates': [
            {'id': 'low', 'memberId': 'm1', 'score': 0.5},
            {'id': 'high', 'memberId': 'm2', 'score': 0.88},
          ],
        },
        {
          'faceId': 'face-2',
          'faceIndex': 1,
          'matches': [
            {'id': 'second-face', 'memberId': 'm3', 'confidence': 0.75},
          ],
        },
      ],
    });

    expect(suggestions, hasLength(2));
    expect(suggestions.first.id, 'high');
    expect(suggestions.first.faceKey, 'face-1');
    expect(suggestions.last.id, 'second-face');
  });

  test('FaceScanStatusInfo đọc retry metadata từ response root', () {
    final info = FaceScanStatusInfo.fromJson({
      'status': 'PROCESSING',
      'retryAllowed': true,
      'maxProcessingSeconds': 90,
    });

    expect(info.state, FaceScanState.processing);
    expect(info.retryAllowed, isTrue);
    expect(info.maxProcessingSeconds, 90);
  });

  test('FaceScanStatusInfo đọc status lồng trong job', () {
    final info = FaceScanStatusInfo.fromJson({
      'job': {
        'scanStatus': 'FAILED',
        'retryAllowed': 'true',
        'maxProcessingSeconds': '120',
      },
    });

    expect(info.state, FaceScanState.failed);
    expect(info.retryAllowed, isTrue);
    expect(info.maxProcessingSeconds, 120);
  });

  group('quyền gỡ tag', () {
    test('BE không trả quyền thì vẫn cho gỡ (fail-open, để BE trả 403)', () {
      final tag = AlbumTag.fromJson({'id': 'tag-1'});
      expect(tag.canRemoveFlag, isNull);
      expect(tag.canRemove, isTrue);
    });

    test('BE nói rõ false thì tôn trọng', () {
      final tag = AlbumTag.fromJson({
        'id': 'tag-1',
        'permissions': {'canRemove': false},
      });
      expect(tag.canRemove, isFalse);
    });

    test('BE nói rõ true thì cho gỡ', () {
      expect(
        AlbumTag.fromJson({'id': 'tag-1', 'canRemove': true}).canRemove,
        isTrue,
      );
    });
  });

  test('AlbumTag reads tagged member name from nested backend payload', () {
    final tag = AlbumTag.fromJson({
      'id': 'tag-1',
      'taggedMember': {
        'id': 'member-1',
        'userAccount': {'fullName': 'Zap MEM 2'},
      },
    });

    expect(tag.id, 'tag-1');
    expect(tag.taggedMemberId, 'member-1');
    expect(tag.taggedMemberName, 'Zap MEM 2');
  });
}
