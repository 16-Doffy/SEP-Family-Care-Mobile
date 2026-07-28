import 'package:flutter_test/flutter_test.dart';

import 'package:family_care/providers/finance_provider.dart' show FinanceJar;
import 'package:family_care/providers/wallet_provider.dart' show LedgerEntry;
import 'package:family_care/utils/jar_allocation.dart';

FinanceJar _jar(String id, String name, double pct) => FinanceJar(
  id: id,
  name: name,
  jarCode: name.toUpperCase(),
  allocationPercentage: pct,
  isActive: true,
  financeModelId: 'model-1',
);

LedgerEntry _entry({
  required String type,
  required double amount,
  String? jarId,
}) => LedgerEntry(
  id: 'e-$type-$amount-$jarId',
  entryType: type,
  amount: amount,
  description: '',
  entryDate: '2026-07-01',
  jarId: jarId,
);

void main() {
  group('computeJarAllocation', () {
    test('kế hoạch = thu nhập × % của hũ', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 55), _jar('j2', 'Tiết kiệm', 20)],
        entries: const [],
        income: 10000000,
      );

      expect(result.rows.first.name, 'Thiết yếu');
      expect(result.rows.first.target, 5500000);
      expect(result.rows[1].target, 2000000);
      expect(result.rows.every((r) => r.actual == 0), isTrue);
    });

    test('cộng thực chi theo jarId, gộp nhiều giao dịch cùng hũ', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [
          _entry(type: 'EXPENSE', amount: 300000, jarId: 'j1'),
          _entry(type: 'EXPENSE', amount: 200000, jarId: 'j1'),
        ],
        income: 1000000,
      );

      expect(result.rows.single.actual, 500000);
      expect(result.unassigned, 0);
    });

    test('giao dịch thu KHÔNG bị tính là chi của hũ', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [
          _entry(type: 'INCOME', amount: 900000, jarId: 'j1'),
          _entry(type: 'CONTRIBUTION', amount: 100000, jarId: 'j1'),
          _entry(type: 'EXPENSE', amount: 50000, jarId: 'j1'),
        ],
        income: 1000000,
      );

      expect(result.rows.single.actual, 50000);
    });

    test('SUPPORT (BE tự tạo khi duyệt xin tiền) tính là chi', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [_entry(type: 'SUPPORT', amount: 456789, jarId: 'j1')],
        income: 1000000,
      );

      expect(result.rows.single.actual, 456789);
    });

    test('chi không gán hũ dồn vào unassigned, không bị bỏ qua', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [
          _entry(type: 'EXPENSE', amount: 70000),
          _entry(type: 'EXPENSE', amount: 30000, jarId: ''),
          _entry(type: 'EXPENSE', amount: 10000, jarId: 'j1'),
        ],
        income: 1000000,
      );

      expect(result.unassigned, 100000, reason: 'null và rỗng đều là chưa gán');
      expect(result.rows.single.actual, 10000);
    });

    test('chi của hũ thuộc mô hình khác không dính vào hũ đang xét', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [_entry(type: 'EXPENSE', amount: 999000, jarId: 'j-khac')],
        income: 1000000,
      );

      expect(result.rows.single.actual, 0);
      expect(
        result.unassigned,
        0,
        reason: 'có jarId nên không phải chưa gán, chỉ là không thuộc mô hình',
      );
    });

    test('isOverBudget chỉ đúng khi vượt kế hoạch thật', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50), _jar('j2', 'Tiết kiệm', 10)],
        entries: [
          _entry(type: 'EXPENSE', amount: 600000, jarId: 'j1'),
          _entry(type: 'EXPENSE', amount: 50000, jarId: 'j2'),
        ],
        income: 1000000,
      );

      final essential = result.rows.firstWhere((r) => r.jarId == 'j1');
      final saving = result.rows.firstWhere((r) => r.jarId == 'j2');
      expect(essential.isOverBudget, isTrue, reason: '600k > 500k');
      expect(saving.isOverBudget, isFalse, reason: '50k < 100k');
    });

    test('thu nhập 0 thì kế hoạch 0 và không báo vượt (tránh chia cho 0)', () {
      final result = computeJarAllocation(
        jars: [_jar('j1', 'Thiết yếu', 50)],
        entries: [_entry(type: 'EXPENSE', amount: 100000, jarId: 'j1')],
        income: 0,
      );

      expect(result.rows.single.target, 0);
      expect(result.rows.single.actual, 100000);
      expect(result.rows.single.isOverBudget, isFalse);
    });

    test('sắp xếp hũ theo % giảm dần cho dễ đọc', () {
      final result = computeJarAllocation(
        jars: [
          _jar('j1', 'Nhỏ', 10),
          _jar('j2', 'Lớn', 55),
          _jar('j3', 'Vừa', 20),
        ],
        entries: const [],
        income: 1000000,
      );

      expect(result.rows.map((r) => r.name).toList(), ['Lớn', 'Vừa', 'Nhỏ']);
    });

    test('không có hũ thì isEmpty, màn hình sẽ fallback về cách chia cũ', () {
      final result = computeJarAllocation(
        jars: const [],
        entries: [_entry(type: 'EXPENSE', amount: 1000, jarId: 'j1')],
        income: 1000000,
      );

      expect(result.isEmpty, isTrue);
    });
  });
}
