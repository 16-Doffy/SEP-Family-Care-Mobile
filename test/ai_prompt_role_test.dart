import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/screens/shared/ai_assistant_screen.dart';

/// Gợi ý câu hỏi phải khớp quyền của người đang đăng nhập.
///
/// Trước 2026-08-07 màn Trợ lý AI dùng một danh sách cứng cho mọi vai trò:
/// thiếu hẳn nhóm mô hình tài chính cho Trưởng nhóm, và mời Thành viên làm
/// những việc họ không có quyền.
void main() {
  final managerGroups = aiPromptGroupsFor(canManageFinance: true);
  final memberGroups = aiPromptGroupsFor(canManageFinance: false);

  List<String> promptsOf(List<AiPromptGroup> groups) =>
      groups.expand((g) => g.prompts).toList();

  group('Trưởng nhóm và Phó nhóm', () {
    test('có nhóm gợi ý về mô hình tài chính và ngân sách', () {
      expect(
        managerGroups.any((g) => g.title.contains('Mô hình')),
        isTrue,
        reason:
            'Thiếu nhóm mô hình tài chính thì người quản lý không biết hỏi '
            'AI về hũ, ngân sách hay chia quỹ',
      );
    });

    test('hỏi được về mô hình đang áp dụng, hũ và ngân sách', () {
      final all = promptsOf(managerGroups).join(' ').toLowerCase();
      expect(all, contains('mô hình tài chính'));
      expect(all, contains('hũ'));
      expect(all, contains('ngân sách'));
      expect(all, contains('chia quỹ'));
    });

    test('vẫn tạo được cả ba loại đề xuất backend hỗ trợ', () {
      // Ví dụ "Nhờ AI tạo" ghi sổ được random giữa chi/thu mỗi lần dựng
      // (`_randomLedgerPrompt`) để người dùng thấy cả hai khả năng — kiểm
      // tra bằng "ghi khoản" chung (khớp cả "ghi khoản chi" lẫn "ghi khoản
      // thu") thay vì cố định một trong hai, tránh test tự nhiên bị flaky.
      final all = promptsOf(managerGroups).join(' ').toLowerCase();
      expect(all, contains('ghi khoản'));
      expect(all, contains('tạo nhiệm vụ'));
      expect(all, contains('tạo lịch'));
    });
  });

  group('Thành viên', () {
    test('KHÔNG được mời làm việc mình không có quyền', () {
      final all = promptsOf(memberGroups).join(' ').toLowerCase();
      // Ba việc này đều cần canManageFinance/canManageTasks/canManageCalendar,
      // Thành viên đều false. Quan sát runtime: backend không trả pendingAction
      // nên bấm vào là ngõ cụt.
      expect(all, isNot(contains('ghi khoản chi')));
      expect(all, isNot(contains('ghi khoản thu')));
      expect(all, isNot(contains('tạo nhiệm vụ')));
      expect(all, isNot(contains('tạo lịch')));
    });

    test('không có nhóm "Nhờ AI tạo"', () {
      expect(memberGroups.any((g) => g.title.contains('Nhờ AI tạo')), isFalse);
    });

    test(
      'không hỏi về quỹ chung — Thành viên bị 403 ở sổ quỹ theo thiết kế',
      () {
        final all = promptsOf(memberGroups).join(' ').toLowerCase();
        expect(all, isNot(contains('nhà mình đã chi')));
        expect(all, isNot(contains('mục tiêu tiết kiệm của nhà mình')));
        expect(all, isNot(contains('mô hình tài chính')));
      },
    );

    test('vẫn hỏi được phần của mình: nhiệm vụ, chi tiêu cá nhân, lịch', () {
      final all = promptsOf(memberGroups).join(' ').toLowerCase();
      expect(all, contains('nhiệm vụ'));
      expect(all, contains('tôi đã tiêu'));
      expect(all, contains('lịch'));
    });

    test('danh sách không rỗng — không được khoá sạch màn của Thành viên', () {
      expect(memberGroups, isNotEmpty);
      expect(promptsOf(memberGroups).length, greaterThanOrEqualTo(4));
    });
  });

  test('mọi nhóm đều có tiêu đề và ít nhất một câu gợi ý', () {
    for (final group in [...managerGroups, ...memberGroups]) {
      expect(group.title.trim(), isNotEmpty);
      expect(group.prompts, isNotEmpty, reason: group.title);
      for (final prompt in group.prompts) {
        expect(prompt.trim(), isNotEmpty, reason: group.title);
      }
    }
  });
}
