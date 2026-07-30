import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/finance_provider.dart';
import 'package:family_care/providers/wallet_provider.dart';

void main() {
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
