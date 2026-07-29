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
