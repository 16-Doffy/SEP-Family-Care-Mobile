import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/finance_provider.dart';

/// BE đổi cách tính gợi ý đóng góp 2026-08-18:
///   availableAmount = incomeAmount - personalExpenseAmount - sharedContributionAmount
///   suggestedContribution = target * availableAmount / totalAvailableAmount
///
/// Điểm mấu chốt: khoản ĐÃ GÓP QUỸ CHUNG chỉ TRỪ BỚT khả năng còn lại, không
/// được biến thành "số phải góp tiếp cho mục tiêu".
void main() {
  _shortfallTests();
  group('ContributionSuggestion', () {
    test('đọc được suggestedContribution của BE mới', () {
      final s = ContributionSuggestion.fromJson({
        'memberId': 'm1',
        'displayName': 'Giáp',
        'suggestedContribution': 2500000,
      });
      expect(s.memberId, 'm1');
      expect(s.memberName, 'Giáp');
      expect(s.suggestedAmount, 2500000);
    });

    test('vẫn đọc được tên field cũ khi BE chưa deploy', () {
      expect(
        ContributionSuggestion.fromJson({
          'suggestedAmount': 100,
        }).suggestedAmount,
        100,
      );
      expect(
        ContributionSuggestion.fromJson({'amount': 200}).suggestedAmount,
        200,
      );
      expect(
        ContributionSuggestion.fromJson({'plannedAmount': 300}).suggestedAmount,
        300,
      );
    });

    test('displayName ở gốc được ưu tiên hơn object member lồng bên trong', () {
      final s = ContributionSuggestion.fromJson({
        'displayName': 'Tên gốc',
        'member': {'fullName': 'Tên lồng'},
      });
      expect(s.memberName, 'Tên gốc');
    });

    test('đã góp quỹ chung LÀM GIẢM khả dụng, không thành khoản phải góp', () {
      // Thu 30tr, chi cá nhân 8tr, đã góp quỹ chung 10tr -> khả dụng 12tr.
      final s = ContributionSuggestion.fromJson({
        'memberId': 'm1',
        'incomeAmount': 30000000,
        'personalExpenseAmount': 8000000,
        'sharedContributionAmount': 10000000,
        'availableAmount': 12000000,
        'suggestedContribution': 3000000,
      });
      expect(s.sharedContributionAmount, 10000000);
      expect(s.availableAmount, 12000000);
      expect(
        s.availableAmount,
        s.incomeAmount! -
            s.personalExpenseAmount! -
            s.sharedContributionAmount!,
      );
      // Khoản góp quỹ chung KHÔNG được trở thành số đề xuất.
      expect(s.suggestedAmount, isNot(s.sharedContributionAmount));
      expect(s.hasBreakdown, isTrue);
    });

    test(
      'thiếu hết số liệu thì hasBreakdown = false, không dựng khung rỗng',
      () {
        final s = ContributionSuggestion.fromJson({
          'memberId': 'm1',
          'suggestedContribution': 500,
        });
        expect(s.hasBreakdown, isFalse);
        expect(s.incomeAmount, isNull);
      },
    );

    test('giữ nguyên raw để còn tra khi BE thêm field lạ', () {
      final s = ContributionSuggestion.fromJson({'fieldLa': 1});
      expect(s.raw['fieldLa'], 1);
    });
  });

  group('ContributionSuggestionResult', () {
    test('parse response object mới đủ metadata', () {
      final r = ContributionSuggestionResult.fromJson({
        'basis': 'AVAILABLE_AMOUNT',
        'monthlyContributionTarget': 9000000,
        'explicitMonthlyContributionTarget': 8000000,
        'recommendedMonthlyContribution': 7000000,
        'remainingAmount': 45000000,
        'totalAvailableAmount': 24000000,
        'warnings': ['Một thành viên chưa khai báo thu nhập'],
        'skippedMembers': [
          {
            'memberId': 'm9',
            'displayName': 'Bà',
            'reason': 'MISSING_MONTHLY_FINANCE',
          },
        ],
        'suggestions': [
          {'memberId': 'm1', 'suggestedContribution': 3000000},
          {'memberId': 'm2', 'suggestedContribution': 4000000},
        ],
      });
      expect(r.suggestions, hasLength(2));
      expect(r.basis, 'AVAILABLE_AMOUNT');
      expect(r.totalAvailableAmount, 24000000);
      expect(r.recommendedMonthlyContribution, 7000000);
      expect(r.remainingAmount, 45000000);
      expect(r.explicitMonthlyContributionTarget, 8000000);
      expect(r.warnings, hasLength(1));
      expect(r.skippedMembers.first.displayName, 'Bà');
      expect(r.hasMeta, isTrue);
    });

    test(
      'vẫn parse được response MẢNG cũ, app không vỡ khi BE chưa deploy',
      () {
        final r = ContributionSuggestionResult.fromJson([
          {'memberId': 'm1', 'suggestedAmount': 1000},
        ]);
        expect(r.suggestions, hasLength(1));
        expect(r.suggestions.first.suggestedAmount, 1000);
        expect(r.warnings, isEmpty);
        expect(r.skippedMembers, isEmpty);
        expect(r.hasMeta, isFalse);
      },
    );

    test('response rỗng hoặc sai kiểu thì trả về rỗng, không ném lỗi', () {
      expect(ContributionSuggestionResult.fromJson(null).suggestions, isEmpty);
      expect(ContributionSuggestionResult.fromJson('rác').suggestions, isEmpty);
      expect(ContributionSuggestionResult.fromJson({}).suggestions, isEmpty);
    });

    test('thiếu metadata mới thì các field là null, không phải 0', () {
      final r = ContributionSuggestionResult.fromJson({
        'suggestions': [
          {'memberId': 'm1', 'suggestedContribution': 1},
        ],
      });
      expect(r.totalAvailableAmount, isNull);
      expect(r.remainingAmount, isNull);
      expect(r.basis, isNull);
    });
  });

  group('SkippedContributionMember.reasonLabel', () {
    test('dịch đủ 4 mã BE đã chốt', () {
      String label(String reason) =>
          SkippedContributionMember.fromJson({'reason': reason}).reasonLabel;

      expect(
        label('MISSING_MONTHLY_FINANCE'),
        'Chưa có dữ liệu thu chi tháng này',
      );
      expect(label('INCOME_NOT_VISIBLE'), 'Thu nhập đang ẩn');
      expect(label('EXPENSE_NOT_VISIBLE'), 'Chi tiêu đang ẩn');
      expect(
        label('NO_AVAILABLE_AMOUNT'),
        'Không còn khả dụng sau chi phí và quỹ chung',
      );
    });

    test('mã lạ thì trả nguyên văn, không nuốt mất', () {
      expect(
        SkippedContributionMember.fromJson({
          'reason': 'MA_MOI_CUA_BE',
        }).reasonLabel,
        'MA_MOI_CUA_BE',
      );
    });

    test('không có reason thì vẫn có câu đọc được', () {
      expect(
        SkippedContributionMember.fromJson({}).reasonLabel,
        'Chưa đủ dữ liệu để ước tính',
      );
    });
  });
}

/// Cảnh báo "góp thế này không kịp hạn".
///
/// Ca thật 2026-08-18: mục tiêu 500 triệu, hạn 17/09/2029 (38 tháng còn lại),
/// BE tính `recommendedMonthlyContribution` = 13.157.895đ. Người dùng đặt 5
/// triệu/tháng → AI vẫn chia đều mà KHÔNG cảnh báo gì, trong khi thực tế chỉ
/// đạt 37% mục tiêu đúng hạn.
void _shortfallTests() {
  group('evaluateContributionShortfall', () {
    test('ca thật: 5tr/tháng cho mục tiêu cần 13,16tr/tháng', () {
      final s = evaluateContributionShortfall(
        planned: 5000001,
        recommended: 13157895,
        remaining: 500000000,
      );
      expect(s, isNotNull);
      expect(s!.coveragePercent, 38); // 5.000.001 / 13.157.895
      // Giữ mức 5tr thì cần 100 tháng, tức hơn 8 năm.
      expect(s.monthsNeeded, 100);
    });

    test('góp đủ thì KHÔNG cảnh báo', () {
      expect(
        evaluateContributionShortfall(
          planned: 13157895,
          recommended: 13157895,
          remaining: 500000000,
        ),
        isNull,
      );
    });

    test('góp dư thì cũng không cảnh báo', () {
      expect(
        evaluateContributionShortfall(planned: 20000000, recommended: 13157895),
        isNull,
      );
    });

    test('lệch vài đồng do làm tròn thì bỏ qua, không dọa người dùng', () {
      // Tổng các dòng gợi ý hay lệch vài đồng so với mục tiêu.
      expect(
        evaluateContributionShortfall(planned: 4999999, recommended: 5000001),
        isNull,
      );
    });

    test('BE chưa gửi recommended thì im lặng, KHÔNG tự đoán', () {
      expect(
        evaluateContributionShortfall(planned: 1000, recommended: null),
        isNull,
      );
      expect(
        evaluateContributionShortfall(planned: 1000, recommended: 0),
        isNull,
      );
    });

    test('chưa biết số còn thiếu thì không tính được số tháng', () {
      final s = evaluateContributionShortfall(
        planned: 5000000,
        recommended: 13157895,
      );
      expect(s, isNotNull);
      expect(s!.monthsNeeded, isNull);
      expect(s.coveragePercent, 38);
    });

    test('góp 0đ thì không chia cho 0, trả null cho số tháng', () {
      final s = evaluateContributionShortfall(
        planned: 0,
        recommended: 13157895,
        remaining: 500000000,
      );
      expect(s, isNotNull);
      expect(s!.coveragePercent, 0);
      expect(s.monthsNeeded, isNull);
    });
  });
}
