import 'package:flutter_test/flutter_test.dart';
import 'package:family_care/providers/finance_provider.dart';

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
}
