import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/finance_provider.dart';
import 'package:family_care/providers/wallet_provider.dart';

void main() {
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
      'entries': [],
    });

    expect(result.modelId, 'model-id');
    expect(result.periodMonth, 7);
    expect(result.periodYear, 2026);
    expect(result.totalAmount, 10000000);
    expect(result.items, hasLength(1));
    expect(result.items.single.jarCode, 'NECESSITIES');
    expect(result.items.single.allocationPercentage, 50);
    expect(result.items.single.amount, 5000000);
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
          'entries': [],
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
      expect(result.createdByMemberId, '');
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
}
