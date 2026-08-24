import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/album_media.dart';
import 'package:family_care/providers/album_face_provider.dart';
import 'package:family_care/screens/shared/album_face_section.dart';

void main() {
  _tagContract19082026Tests();
  _emptySuggestionsMessageTests();
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

  group('schema chính thức face-suggestions (Swagger)', () {
    test('EXPIRED là trạng thái đã xử lý, không hiện kèm nút Xác nhận', () {
      final expired = FaceSuggestion.fromJson({
        'suggestionId': 's1',
        'memberId': 'm1',
        'score': 0.9,
        'status': 'EXPIRED',
      });

      expect(
        expired.isResolved,
        isTrue,
        reason: 'gợi ý hết hạn mà cho bấm thì chỉ nhận lỗi',
      );
    });

    test('đọc permissions.canConfirm/canReject của BE', () {
      final s = FaceSuggestion.fromJson({
        'suggestionId': 's1',
        'memberId': 'm1',
        'score': 0.88,
        'permissions': {'canConfirm': false, 'canReject': true},
      });

      expect(s.canConfirm, isFalse);
      expect(s.canReject, isTrue);
    });

    test('BE không trả permissions thì fail-open, để BE trả 403', () {
      final s = FaceSuggestion.fromJson({
        'suggestionId': 's1',
        'memberId': 'm1',
        'score': 0.88,
      });

      expect(s.canConfirm, isTrue);
      expect(s.canReject, isTrue);
    });

    test('khuôn mặt SUPERSEDED bị loại dù candidate còn PENDING', () {
      final suggestions = parseFaceSuggestions({
        'faces': [
          {
            'faceId': 'face-cu',
            'faceIndex': 0,
            'status': 'SUPERSEDED',
            'candidates': [
              {'suggestionId': 'cu', 'memberId': 'm1', 'score': 0.9},
            ],
          },
          {
            'faceId': 'face-moi',
            'faceIndex': 0,
            'status': 'MATCHED',
            'candidates': [
              {'suggestionId': 'moi', 'memberId': 'm1', 'score': 0.91},
            ],
          },
        ],
      });

      expect(
        suggestions.map((s) => s.id),
        ['moi'],
        reason:
            'khuôn mặt đã bị lần quét mới thay thế thì không còn là việc '
            'chờ làm; status của candidate không được đè status của khuôn mặt',
      );
    });

    test('status của candidate vẫn đọc đúng khi khuôn mặt MATCHED', () {
      final suggestions = parseFaceSuggestions({
        'faces': [
          {
            'faceId': 'face-1',
            'status': 'MATCHED',
            'candidates': [
              {
                'suggestionId': 's1',
                'memberId': 'm1',
                'score': 0.88,
                'status': 'PENDING',
              },
            ],
          },
        ],
      });

      expect(suggestions, hasLength(1));
      expect(suggestions.single.status, 'PENDING');
      expect(suggestions.single.detectionStatus, 'MATCHED');
      expect(suggestions.single.isSupersededDetection, isFalse);
    });
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

  test(
    'parseFaceSuggestions giữ boundingBox từ response thật của BE '
    '(verify 2026-08-24: curl trực tiếp, media a3378891, item PENDING)',
    () {
      final raw = {
        "faces": [
          {
            "faceId": "49332b4f-8a2a-43a2-8336-aeece8d968ae",
            "detectionId": "49332b4f-8a2a-43a2-8336-aeece8d968ae",
            "faceIndex": 5,
            "boundingBox": {
              "x": 0.4994769467105815,
              "y": 0.3454243695294416,
              "width": 0.09405317127544822,
              "height": 0.1359692891438802,
            },
            "detectionScore": 0.7036,
            "qualityScore": 0.7036,
            "status": "MATCHED",
            "candidates": [
              {
                "suggestionId": "2d1ae46e-fcfd-489e-abe0-0ee53bc52773",
                "memberId": "7b1ba8e5-dc73-48bb-9b82-f57da17d8909",
                "displayName": "lê anh sĩ",
                "avatarUrl": null,
                "score": 0.7338,
                "secondBestScore": -0.0393,
                "scoreMargin": 0.7731,
                "status": "PENDING",
                "permissions": {"canConfirm": true, "canReject": true},
              },
            ],
          },
        ],
        "items": [
          {
            "suggestionId": "2d1ae46e-fcfd-489e-abe0-0ee53bc52773",
            "detectionId": "49332b4f-8a2a-43a2-8336-aeece8d968ae",
            "faceId": "49332b4f-8a2a-43a2-8336-aeece8d968ae",
            "faceIndex": 5,
            "boundingBox": {
              "x": 0.4994769467105815,
              "y": 0.3454243695294416,
              "width": 0.09405317127544822,
              "height": 0.1359692891438802,
            },
            "similarityScore": 0.7338,
            "secondBestScore": -0.0393,
            "scoreMargin": 0.7731,
            "status": "PENDING",
            "suggestedMember": {
              "memberId": "7b1ba8e5-dc73-48bb-9b82-f57da17d8909",
              "displayName": "lê anh sĩ",
              "avatarUrl": null,
              "familyRole": "DEPUTY_MEMBER",
              "memberStatus": "ACTIVE",
            },
            "permissions": {"canConfirm": true, "canReject": true},
          },
        ],
        "total": 1,
      };

      final suggestions = parseFaceSuggestions(raw);

      expect(suggestions, hasLength(1));
      expect(
        suggestions.single.boundingBox,
        isNotNull,
        reason:
            'response thật của BE có boundingBox cả ở "faces" lẫn "items" — '
            'nếu null ở đây thì lỗi nằm ở parseFaceSuggestions/FaceSuggestion.fromJson',
      );
      expect(suggestions.single.boundingBox!.x, closeTo(0.4994, 0.001));
      expect(suggestions.single.memberName, 'lê anh sĩ');
    },
  );

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

/// Ba nguyên nhân "danh sách gợi ý rỗng" phải ra ba câu khác nhau. Trước đây
/// gộp chung nên xác nhận gợi ý thành công xong vẫn bị in lý do thất bại ngay
/// cạnh cái thẻ vừa tạo (gặp trên máy thật 19/08).
void _emptySuggestionsMessageTests() {
  group('emptySuggestionsMessage', () {
    test('vừa xác nhận gợi ý xong thì báo đã xử lý xong, không đổ lỗi', () {
      final msg = emptySuggestionsMessage(
        resolvedSomeSuggestion: true,
        hasAnyTag: true,
      );
      expect(msg, contains('Đã xử lý xong'));
      expect(msg, isNot(contains('quá nhỏ')));
      expect(msg, isNot(contains('gỡ thẻ')));
    });

    test('vừa xử lý xong được ưu tiên hơn cả khi ảnh chưa kịp có thẻ', () {
      // Bỏ qua gợi ý (reject) không tạo thẻ nào, nhưng vẫn không phải lỗi quét.
      final msg = emptySuggestionsMessage(
        resolvedSomeSuggestion: true,
        hasAnyTag: false,
      );
      expect(msg, contains('Đã xử lý xong'));
      expect(msg, isNot(contains('chưa ai đăng ký')));
    });

    test('ảnh đã có thẻ thì giải thích vì sao không gợi ý lại', () {
      final msg = emptySuggestionsMessage(
        resolvedSomeSuggestion: false,
        hasAnyTag: true,
      );
      expect(msg, contains('gỡ thẻ'));
      expect(msg, isNot(contains('quá nhỏ')));
    });

    test(
      'chưa có thẻ và chưa xử lý gì thì mới liệt kê nguyên nhân quét hụt',
      () {
        final msg = emptySuggestionsMessage(
          resolvedSomeSuggestion: false,
          hasAnyTag: false,
        );
        expect(msg, contains('quá nhỏ'));
        expect(msg, contains('Hồ sơ khuôn mặt'));
      },
    );
  });
}

/// Contract BE 19/08: tag trong media detail/list và endpoint /tags trả trực
/// tiếp `taggedMemberId` + `taggedByMemberId`. Trước đó response đo trên máy
/// thật chỉ có tên, không có id nào — nên vẫn giữ test cho nhánh lưới đỡ.
void _tagContract19082026Tests() {
  group('contract BE 19/08 — tag có id trực tiếp', () {
    test('đọc taggedMemberId và taggedByMemberId trực tiếp', () {
      final tag = AlbumTag.fromJson({
        'id': 'tag-1',
        'taggedMemberId': 'mem-1',
        'taggedByMemberId': 'mem-2',
        'taggedMemberName': 'Vu Quan',
      });
      expect(tag.taggedMemberId, 'mem-1');
      expect(tag.taggedByMemberId, 'mem-2');
      expect(tag.taggedMemberName, 'Vu Quan');
    });

    test('field trực tiếp thắng id lồng trong taggedMember', () {
      final tag = AlbumTag.fromJson({
        'id': 'tag-1',
        'taggedMemberId': 'mem-dung',
        'taggedMember': {'id': 'mem-sai', 'displayName': 'Vu Quan'},
      });
      expect(tag.taggedMemberId, 'mem-dung');
    });

    test('BE chưa push thì taggedByMemberId rỗng, không nổ', () {
      final tag = AlbumTag.fromJson({
        'id': 'tag-1',
        'taggedMemberName': 'Vu Quan',
      });
      expect(tag.taggedByMemberId, isEmpty);
      expect(tag.taggedMemberId, isEmpty);
    });
  });
}
