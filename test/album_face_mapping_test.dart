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
