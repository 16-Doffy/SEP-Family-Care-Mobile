import '../providers/finance_provider.dart' show FinanceJar;
import '../providers/wallet_provider.dart' show LedgerEntry;

/// Một dòng phân bổ theo hũ: kế hoạch (theo % của mô hình) so với thực chi.
class JarAllocationRow {
  const JarAllocationRow({
    required this.jarId,
    required this.name,
    required this.pct,
    required this.target,
    required this.actual,
  });

  final String jarId;
  final String name;

  /// Tỷ lệ phân bổ của hũ, thang 0..100.
  final double pct;

  /// Số tiền kế hoạch = thu nhập × pct / 100.
  final double target;

  /// Tổng chi thực tế của các giao dịch có `jarId` này.
  final double actual;

  /// Chi vượt kế hoạch. Hũ chưa có kế hoạch (target = 0) thì không coi là vượt.
  bool get isOverBudget => target > 0 && actual > target;
}

/// Kết quả phân bổ theo mô hình tài chính.
class JarAllocation {
  const JarAllocation({required this.rows, required this.unassigned});

  final List<JarAllocationRow> rows;

  /// Tổng chi của giao dịch KHÔNG gán hũ nào. Phải hiện ra để tổng số khớp với
  /// tổng chi tiêu, không âm thầm bỏ qua phần này.
  final double unassigned;

  bool get isEmpty => rows.isEmpty;
}

/// Tính phân bổ theo hũ hoàn toàn ở FE.
///
/// BE chưa trả `byJar` trong `finance/summary` (Swagger ghi "Reserved") nên
/// phần thực chi được cộng từ `jarId` của từng ledger entry — `CreateLedgerEntryDto`
/// có `jarId`, và `POST /finance/fund-allocations` ghi mỗi hũ thành một entry.
///
/// [jars] nên là các hũ đang hoạt động của **đúng** mô hình đang áp dụng —
/// `GET /finance/jars` trả hũ của mọi mô hình cho quản lý, nên caller phải lọc
/// theo `financeModelId` trước khi gọi hàm này.
JarAllocation computeJarAllocation({
  required List<FinanceJar> jars,
  required List<LedgerEntry> entries,
  required double income,
}) {
  final spentByJar = <String, double>{};
  double unassigned = 0;

  for (final entry in entries) {
    final signed = entry.signedAmount;
    // Chỉ tính giao dịch chi; thu (signedAmount >= 0) không thuộc hũ nào.
    if (signed >= 0) continue;
    final spent = -signed;
    final jarId = entry.jarId;
    if (jarId == null || jarId.isEmpty) {
      unassigned += spent;
    } else {
      spentByJar[jarId] = (spentByJar[jarId] ?? 0) + spent;
    }
  }

  final rows =
      jars
          .map(
            (j) => JarAllocationRow(
              jarId: j.id,
              name: j.name.isEmpty ? j.jarCode : j.name,
              pct: j.allocationPercentage,
              // Thu nhập âm/không có thì kế hoạch là 0, không để ra số âm.
              target: income > 0 ? income * j.allocationPercentage / 100 : 0,
              actual: spentByJar[j.id] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.pct.compareTo(a.pct));

  return JarAllocation(rows: rows, unassigned: unassigned);
}
