import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/finance_provider.dart';
import 'package:family_care/providers/wallet_provider.dart';

void main() {
  _savingJarHeuristicTests();
  _budgetPlanPeriodTests();
  _contributableGoalsTests();
  test('parses category to jar mapping with nested payload', () {
    final mapping = FinanceCategoryJarMapping.fromJson({
      'id': 'mapping-1',
      'financeModel': {'id': 'model-1'},
      'category': {'id': 'category-1', 'name': 'Ăn uống'},
      'jar': {'id': 'jar-1', 'name': 'Thiết yếu'},
    });

    expect(mapping.financeModelId, 'model-1');
    expect(mapping.categoryId, 'category-1');
    expect(mapping.jarId, 'jar-1');
    expect(mapping.categoryName, 'Ăn uống');
  });

  test('parses jar target actual report aliases', () {
    final report = JarTargetActualReport.fromJson({
      'byJar': [
        {
          'jar': {'id': 'jar-1', 'name': 'Thiết yếu'},
          'allocationPercentage': 50,
          'actualPercent': 55,
          'plannedAmount': 5000000,
          'spentAmount': 5500000,
          'status': 'OVER_TARGET',
        },
      ],
      'unmapped': {'amount': 100000},
    });

    expect(report.items.single.jarName, 'Thiết yếu');
    expect(report.items.single.targetPercentage, 50);
    expect(report.items.single.actualPercentage, 55);
    expect(report.items.single.status, 'OVER_TARGET');
    expect(report.unmappedAmount, 100000);
  });

  test('parses exact jar target actual Swagger response', () {
    final report = JarTargetActualReport.fromJson({
      'period': {'periodStart': '2026-07-01', 'periodEnd': '2026-07-31'},
      'currency': 'VND',
      'financeModel': {'id': 'model-1', 'name': '80/20'},
      'totals': {
        'trackedAmount': 10000000,
        'mappedAmount': 8000000,
        'unmappedAmount': 2000000,
      },
      'items': [
        {
          'jar': {'id': 'jar-1', 'name': 'Spending'},
          'targetPercentage': 80,
          'actualPercentage': 75,
          'targetAmount': 8000000,
          'actualAmount': 7500000,
          'varianceAmount': -500000,
          'status': 'UNDER_TARGET',
          'categories': const [],
        },
      ],
      'unmapped': {
        'amount': 2000000,
        'percentage': 20,
        'entryCount': 2,
        'legacyJarAmount': 1500000,
        'legacyJarEntryCount': 1,
      },
    });

    expect(report.items.single.jarId, 'jar-1');
    expect(report.items.single.jarName, 'Spending');
    expect(report.items.single.targetAmount, 8000000);
    expect(report.items.single.actualAmount, 7500000);
    expect(report.items.single.status, 'UNDER_TARGET');
    expect(report.unmappedAmount, 2000000);
  });

  test('parses fund allocation response items from BE contract', () {
    final result = FundAllocationResult.fromJson({
      'model': {
        'id': 'model-id',
        'name': 'Five Jars',
        'modelType': 'FIVE_JARS',
      },
      'period': {'month': 7, 'year': 2026},
      'totalAmount': 10000000,
      'sourceType': 'MODEL_FUND_ALLOCATION',
      'sourceId': 'model-id:2026-07',
      'createdAt': '2026-07-28T10:15:30.000Z',
      'createdByMemberId': 'member-id',
      'note': 'Chia quỹ tháng 7',
      'items': [
        {
          'jarId': 'jar-id',
          'jarName': 'Necessities',
          'jarCode': 'NECESSITIES',
          'allocationPercentage': 50,
          'amount': 5000000,
          'ledgerEntryId': 'entry-id',
        },
      ],
      'entries': [
        {'createdAt': '2026-07-28T09:15:30.000Z'},
      ],
    });

    expect(result.modelId, 'model-id');
    expect(result.periodMonth, 7);
    expect(result.periodYear, 2026);
    expect(result.totalAmount, 10000000);
    expect(result.items, hasLength(1));
    expect(result.items.single.jarCode, 'NECESSITIES');
    expect(result.items.single.allocationPercentage, 50);
    expect(result.items.single.amount, 5000000);
    expect(result.createdAt, DateTime.parse('2026-07-28T10:15:30.000Z'));
    expect(result.createdByMemberId, 'member-id');
    expect(result.note, 'Chia quỹ tháng 7');
  });

  test('parses paginated fund allocation history snapshots', () {
    final page = FundAllocationPage.fromJson({
      'items': [
        {
          'model': {
            'id': 'old-model',
            'name': 'Five Jars snapshot',
            'modelType': 'FIVE_JARS',
          },
          'period': {'month': 7, 'year': 2026},
          'totalAmount': 10000000,
          'sourceType': 'MODEL_FUND_ALLOCATION',
          'sourceId': 'old-model:2026-07',
          'items': [
            {
              'jarId': 'old-jar',
              'jarName': 'Necessities snapshot',
              'jarCode': 'NECESSITIES',
              'allocationPercentage': 50,
              'amount': 5000000,
              'ledgerEntryId': 'entry-id',
            },
          ],
          'entries': [
            {'createdAt': '2026-07-29T02:05:06.000Z'},
          ],
        },
      ],
      'total': 21,
      'page': 2,
      'limit': 20,
      'totalPages': 2,
    });

    expect(page.page, 2);
    expect(page.total, 21);
    expect(page.totalPages, 2);
    expect(page.items.single.modelName, 'Five Jars snapshot');
    expect(page.items.single.items.single.jarName, 'Necessities snapshot');
    expect(
      page.items.single.createdAt,
      DateTime.parse('2026-07-29T02:05:06.000Z'),
    );
  });

  group('createdAt cấp allocation (BE bổ sung 2026-07-28)', () {
    test('đọc createdAt/createdByMemberId/note ở cấp allocation', () {
      final result = FundAllocationResult.fromJson({
        'model': {'id': 'm1', 'name': 'Five Jars', 'modelType': 'FIVE_JARS'},
        'period': {'month': 7, 'year': 2026},
        'totalAmount': 10000000,
        'createdAt': '2026-07-28T03:15:00.000Z',
        'createdByMemberId': 'member-1',
        'note': 'Chia quỹ tháng 7',
        'items': const [],
      });

      expect(result.createdAt, isNotNull);
      expect(result.createdAt!.toUtc().hour, 3);
      expect(result.createdByMemberId, 'member-1');
      expect(result.note, 'Chia quỹ tháng 7');
    });

    test('thiếu createdAt cấp trên thì lấy từ entries[] (BE bản cũ)', () {
      final result = FundAllocationResult.fromJson({
        'model': {'id': 'm1'},
        'period': {'month': 7, 'year': 2026},
        'totalAmount': 1000,
        'items': const [],
        'entries': [
          {'id': 'e1', 'createdAt': '2026-07-20T01:00:00.000Z'},
        ],
      });

      expect(result.createdAt!.toUtc().day, 20);
    });

    test('dữ liệu legacy thiếu hết thì null, không crash', () {
      final result = FundAllocationResult.fromJson({
        'model': {'id': 'm1', 'name': null, 'modelType': null},
        'period': {'month': 10, 'year': 2026},
        'items': const [],
      });

      expect(result.createdAt, isNull);
      // createdByMemberId là nullable (bản trên main giữ null cho dữ liệu
      // legacy) — không quy về chuỗi rỗng để phân biệt "BE không trả".
      expect(result.createdByMemberId, isNull);
      expect(result.note, isNull);
      expect(result.periodMonth, 10, reason: 'item vẫn dùng được');
    });
  });

  test('fund allocation ledger adjustment is neutral to family balance', () {
    final entry = LedgerEntry.fromJson({
      'id': 'entry-id',
      'entryType': 'ADJUSTMENT',
      'amount': 5000000,
      'description': 'Chia quỹ vào hũ Necessities',
      'entryDate': '2026-07-31T00:00:00.000Z',
      'sourceType': 'MODEL_FUND_ALLOCATION',
      'status': 'ACTIVE',
    });

    expect(entry.signedAmount, 0);
  });

  test('keeps legacy allocation with nullable snapshot fields', () {
    final page = FundAllocationPage.fromJson({
      'items': [
        {
          'model': null,
          'period': null,
          'totalAmount': null,
          'items': null,
          'createdAt': '2026-07-01T00:00:00.000Z',
        },
      ],
      'total': 1,
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.modelId, isNull);
    expect(page.items.single.periodMonth, isNull);
    expect(page.items.single.totalAmount, isNull);
    expect(page.items.single.items, isEmpty);
  });

  test('sorts history newest first and puts unknown timestamps last', () {
    final page = FundAllocationPage.fromJson({
      'items': [
        {'sourceId': 'old', 'createdAt': '2026-07-01T00:00:00.000Z'},
        {'sourceId': 'unknown'},
        {'sourceId': 'new', 'createdAt': '2026-07-29T00:00:00.000Z'},
      ],
    });

    expect(page.items.map((item) => item.sourceId), ['new', 'old', 'unknown']);
  });
}

/// Bug máy thật 19/08: card "Kết chuyển tháng trước" báo "chưa có mục tiêu nào
/// đang chạy" trong khi mục tiêu "mua xe yaz" đang thiếu tiền — vì bộ lọc dùng
/// `status == 'ACTIVE'` nên loại luôn mục tiêu AT_RISK. Đúng cái mục tiêu cần
/// tiền nhất lại bị giấu khỏi danh sách nhận số dư.
void _contributableGoalsTests() {
  FinancialGoal goal(String status) => FinancialGoal.fromJson({
    'id': 'g-$status',
    'goalName': 'mua xe yaz',
    'targetAmount': 500000000,
    'status': status,
  });

  group('canContribute — mục tiêu nào còn nhận góp', () {
    test(
      'AT_RISK vẫn nhận góp (cảnh báo tiến độ, không phải đóng mục tiêu)',
      () {
        expect(goal('AT_RISK').canContribute, isTrue);
      },
    );

    test('ACTIVE nhận góp', () {
      expect(goal('ACTIVE').canContribute, isTrue);
    });

    test('ACHIEVED và CANCELED thì không', () {
      expect(goal('ACHIEVED').canContribute, isFalse);
      expect(goal('CANCELED').canContribute, isFalse);
    });
  });
}

/// Gặp thật 19/08: người dùng tạo kế hoạch ngân sách cho **tháng 9**, dòng
/// ngân sách 5 triệu, rồi ghi khoản chi 8 triệu vào **tháng 8** và chờ cảnh báo
/// vượt ngân sách. Không có cảnh báo — đúng, vì khoản chi nằm ngoài kỳ. Nhưng
/// thẻ chỉ ghi "Đang áp dụng" nên trông như kế hoạch có hiệu lực ngay bây giờ.
void _budgetPlanPeriodTests() {
  BudgetPlan plan(String start, String end, {String status = 'ACTIVE'}) =>
      BudgetPlan.fromJson({
        'id': 'p1',
        'planName': 'Kế hoạch ngân sách tháng 9',
        'periodStart': start,
        'periodEnd': end,
        'status': status,
      });

  final today = DateTime.now();
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  group('BudgetPlan — kỳ có bao gồm hôm nay không', () {
    test('kỳ nằm hoàn toàn ở tương lai → cảnh báo chưa tới kỳ', () {
      final p = plan(
        iso(today.add(const Duration(days: 10))),
        iso(today.add(const Duration(days: 40))),
      );
      expect(p.isFuturePeriod, isTrue);
      expect(p.isExpiredPeriod, isFalse);
      expect(p.periodWarning, contains('chưa bắt đầu'));
      expect(p.coversDate(today), isFalse);
    });

    test('kỳ đã qua → cảnh báo hết kỳ', () {
      final p = plan(
        iso(today.subtract(const Duration(days: 40))),
        iso(today.subtract(const Duration(days: 10))),
      );
      expect(p.isExpiredPeriod, isTrue);
      expect(p.periodWarning, contains('đã kết thúc'));
      expect(p.coversDate(today), isFalse);
    });

    test('kỳ đang bao hôm nay → không cảnh báo gì', () {
      final p = plan(
        iso(today.subtract(const Duration(days: 5))),
        iso(today.add(const Duration(days: 5))),
      );
      expect(p.isFuturePeriod, isFalse);
      expect(p.isExpiredPeriod, isFalse);
      expect(p.periodWarning, isNull);
      expect(p.coversDate(today), isTrue);
    });

    test('kế hoạch chưa kích hoạt thì không cảnh báo kỳ', () {
      final p = plan(
        iso(today.add(const Duration(days: 10))),
        iso(today.add(const Duration(days: 40))),
        status: 'DRAFT',
      );
      expect(p.isFuturePeriod, isFalse);
      expect(p.periodWarning, isNull);
    });

    test('BE không trả mốc thời gian thì coi như có, không đoán bừa', () {
      final p = plan('', '');
      expect(p.coversDate(today), isTrue);
      expect(p.periodWarning, isNull);
    });
  });
}

/// Hũ tích luỹ vượt tỷ lệ mô hình là chuyện TỐT, không được tô đỏ như tiêu quá
/// tay. BE chưa có field phân loại hũ nên FE đoán theo jarCode/tên — đoán trượt
/// chỉ sai màu, không sai số liệu.
void _savingJarHeuristicTests() {
  group('JarTargetActualItem.looksLikeSaving', () {
    test('nhận ra hũ tiết kiệm qua mã', () {
      for (final code in ['SAVING', 'SAVINGS', 'sav', 'LTSS', 'FFA', 'EDU']) {
        expect(
          JarTargetActualItem.looksLikeSaving(code, 'Hũ'),
          isTrue,
          reason: code,
        );
      }
    });

    test('nhận ra qua tên tiếng Việt có dấu lẫn không dấu', () {
      for (final name in [
        'Tiết kiệm',
        'Tích luỹ',
        'Tích lũy',
        'Đầu tư',
        'Dau tu',
        'Giáo dục',
        'Cho đi',
        'Từ thiện',
      ]) {
        expect(
          JarTargetActualItem.looksLikeSaving('', name),
          isTrue,
          reason: name,
        );
      }
    });

    test('hũ chi tiêu KHÔNG bị nhận nhầm', () {
      for (final name in ['Spending', 'Chi tiêu', 'Thiết yếu', 'Hưởng thụ']) {
        expect(
          JarTargetActualItem.looksLikeSaving('NEC', name),
          isFalse,
          reason: name,
        );
      }
    });

    test('đọc jarCode từ nhiều biến thể BE có thể trả', () {
      final a = JarTargetActualItem.fromJson({
        'jarId': 'j1',
        'jarCode': 'SAVING',
        'jarName': 'Hũ A',
      });
      final b = JarTargetActualItem.fromJson({
        'jar': {'id': 'j2', 'jarCode': 'SAVING', 'name': 'Hũ B'},
      });
      expect(a.isSavingLike, isTrue);
      expect(b.isSavingLike, isTrue);
    });
  });
}
