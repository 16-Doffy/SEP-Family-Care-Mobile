import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/models/tab_option.dart';
import 'package:family_care/navigation/family_shell.dart';

const _chatBranch = 1;

bool _suppress({
  String? referenceType = 'CONVERSATION',
  String? referenceId = 'conv-1',
  bool appInForeground = true,
  int currentBranchIndex = _chatBranch,
  String? openConversationId = 'conv-1',
}) => shouldSuppressChatNotification(
  referenceType: referenceType,
  referenceId: referenceId,
  appInForeground: appInForeground,
  currentBranchIndex: currentBranchIndex,
  openConversationId: openConversationId,
);

void main() {
  test('chat vẫn là branch 1 — hàm suppress dựa vào hằng số này', () {
    expect(TabOption.chat.branchIndex, _chatBranch);
  });

  group('shouldSuppressChatNotification', () {
    test('đang mở đúng hội thoại đó thì nuốt thông báo', () {
      expect(_suppress(), isTrue);
    });

    test('đang ở tab khác thì vẫn báo dù hội thoại vẫn đang mở', () {
      // Chat là branch của indexedStack nên màn hình còn sống và vẫn giữ
      // conversationId kể cả khi người dùng đã sang tab khác.
      expect(_suppress(currentBranchIndex: kSosBranchIndex), isFalse);
      expect(_suppress(currentBranchIndex: kHomeBranchIndex), isFalse);
    });

    test('tin của hội thoại khác thì vẫn báo', () {
      expect(_suppress(referenceId: 'conv-2'), isFalse);
    });

    test('không kèm id hội thoại thì vẫn báo, không đoán bừa', () {
      expect(_suppress(referenceId: null), isFalse);
      expect(_suppress(referenceId: '   '), isFalse);
    });

    test('app ở nền thì luôn báo', () {
      expect(_suppress(appInForeground: false), isFalse);
    });

    test('loại thông báo khác chat thì không đụng tới', () {
      expect(_suppress(referenceType: 'SOS'), isFalse);
      expect(_suppress(referenceType: null), isFalse);
    });

    test('chưa mở hội thoại nào thì vẫn báo', () {
      expect(_suppress(openConversationId: null), isFalse);
    });
  });
}
