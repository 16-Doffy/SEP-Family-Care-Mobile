import 'package:flutter/material.dart';
import '../models/finance_period.dart';
import '../services/api_client.dart';

// ════════════════════════════════════════════════════════════════════════
// FinanceProvider — quản lý Mô hình tài chính (Jars), Ngân sách (Budget
// Plan) và Mục tiêu tiết kiệm (Financial Goal). Cảnh báo ngân sách dùng
// riêng FinanceAlertProvider, không gộp vào đây để tránh trùng state.
// ════════════════════════════════════════════════════════════════════════

double _money(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

double? _moneyNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

// ── Models ──────────────────────────────────────────────────────────────

class FinanceJar {
  final String id;
  final String name;
  final String jarCode;
  final double allocationPercentage;
  final bool isActive;
  final String? financeModelId;

  const FinanceJar({
    required this.id,
    required this.name,
    required this.jarCode,
    required this.allocationPercentage,
    required this.isActive,
    this.financeModelId,
  });

  factory FinanceJar.fromJson(Map<String, dynamic> j) => FinanceJar(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    jarCode: j['jarCode']?.toString() ?? '',
    allocationPercentage: _money(j['allocationPercentage']),
    isActive: j['isActive'] as bool? ?? true,
    financeModelId: j['financeModelId']?.toString(),
  );
}

class FinanceModel {
  final String id;
  final String name;
  final String modelType;
  final String status;
  final List<FinanceJar> jars;

  const FinanceModel({
    required this.id,
    required this.name,
    required this.modelType,
    required this.status,
    this.jars = const [],
  });

  bool get isActive => status == 'ACTIVE';

  factory FinanceModel.fromJson(Map<String, dynamic> j) => FinanceModel(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    modelType: j['modelType']?.toString() ?? '',
    status: j['status']?.toString() ?? '',
    jars: (j['jars'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FinanceJar.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class FundAllocationItem {
  final String jarId;
  final String jarName;
  final String jarCode;
  final double allocationPercentage;
  final double amount;
  final String? ledgerEntryId;

  const FundAllocationItem({
    required this.jarId,
    required this.jarName,
    required this.jarCode,
    required this.allocationPercentage,
    required this.amount,
    this.ledgerEntryId,
  });

  factory FundAllocationItem.fromJson(Map<String, dynamic> j) =>
      FundAllocationItem(
        jarId: j['jarId']?.toString() ?? '',
        jarName: j['jarName']?.toString() ?? '',
        jarCode: j['jarCode']?.toString() ?? '',
        allocationPercentage: _money(j['allocationPercentage']),
        amount: _money(j['amount']),
        ledgerEntryId: j['ledgerEntryId']?.toString(),
      );
}

class FundAllocationResult {
  final String? modelId;
  final String? modelName;
  final String? modelType;
  final int? periodMonth;
  final int? periodYear;
  final double? totalAmount;
  final String sourceType;
  final String sourceId;

  /// Thời điểm chia quỹ, BE bổ sung ở **cấp allocation** (2026-07-28) sau khi FE
  /// báo `entries[].createdAt` trả null/rỗng lúc runtime. Null với dữ liệu legacy
  /// không khôi phục được.
  final DateTime? createdAt;
  final String? createdByMemberId;
  final String? note;
  final List<FundAllocationItem> items;

  const FundAllocationResult({
    required this.modelId,
    required this.modelName,
    required this.modelType,
    required this.periodMonth,
    required this.periodYear,
    required this.totalAmount,
    required this.sourceType,
    required this.sourceId,
    this.createdAt,
    this.createdByMemberId,
    this.note,
    required this.items,
  });

  factory FundAllocationResult.fromJson(Map<String, dynamic> j) {
    final model = j['model'] is Map ? j['model'] as Map : const {};
    final period = j['period'] is Map ? j['period'] as Map : const {};
    final entryDates =
        (j['entries'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (entry) =>
                  DateTime.tryParse(entry['createdAt']?.toString() ?? ''),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();
    final topLevelCreatedAt = DateTime.tryParse(
      j['createdAt']?.toString() ?? '',
    );
    return FundAllocationResult(
      modelId: model['id']?.toString(),
      modelName: model['name']?.toString(),
      modelType: model['modelType']?.toString(),
      periodMonth: (period['month'] as num?)?.toInt(),
      periodYear: (period['year'] as num?)?.toInt(),
      totalAmount: _moneyNull(j['totalAmount']),
      sourceType: j['sourceType']?.toString() ?? '',
      sourceId: j['sourceId']?.toString() ?? '',
      items: (j['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => FundAllocationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      // Contract mới trả createdAt ở cấp allocation. Fallback entries chỉ để
      // đọc dữ liệu cũ được tạo trước khi BE bổ sung metadata này.
      createdAt:
          topLevelCreatedAt ?? (entryDates.isEmpty ? null : entryDates.first),
      createdByMemberId: j['createdByMemberId']?.toString(),
      note: j['note']?.toString(),
    );
  }
}

class FundAllocationPage {
  final List<FundAllocationResult> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const FundAllocationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory FundAllocationPage.fromJson(Map<String, dynamic> j) {
    final items =
        (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  FundAllocationResult.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
          ..sort((a, b) {
            final aTime = a.createdAt;
            final bTime = b.createdAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
    return FundAllocationPage(
      items: items,
      total: (j['total'] as num?)?.toInt() ?? 0,
      page: (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? 20,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class FinanceCategory {
  final String id;
  final String name;
  final String categoryType; // INCOME | EXPENSE
  final String? essentialType;
  final String status;
  final bool isActive;

  const FinanceCategory({
    required this.id,
    required this.name,
    required this.categoryType,
    this.essentialType,
    required this.status,
    required this.isActive,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    categoryType: j['categoryType']?.toString() ?? 'EXPENSE',
    essentialType: j['essentialType']?.toString(),
    status:
        j['status']?.toString().toUpperCase() ??
        ((j['isActive'] == false) ? 'INACTIVE' : 'ACTIVE'),
    isActive: j['isActive'] is bool
        ? j['isActive'] as bool
        : !const {
            'INACTIVE',
            'DISABLED',
            'DELETED',
            'VOIDED',
          }.contains(j['status']?.toString().toUpperCase()),
  );
}

class FinanceCategoryJarMapping {
  final String id;
  final String financeModelId;
  final String categoryId;
  final String jarId;
  final String? categoryName;
  final String? jarName;

  const FinanceCategoryJarMapping({
    required this.id,
    required this.financeModelId,
    required this.categoryId,
    required this.jarId,
    this.categoryName,
    this.jarName,
  });

  factory FinanceCategoryJarMapping.fromJson(Map<String, dynamic> j) {
    final category = j['category'] is Map
        ? Map<String, dynamic>.from(j['category'] as Map)
        : const <String, dynamic>{};
    final jar = j['jar'] is Map
        ? Map<String, dynamic>.from(j['jar'] as Map)
        : const <String, dynamic>{};
    final model = j['financeModel'] is Map
        ? Map<String, dynamic>.from(j['financeModel'] as Map)
        : const <String, dynamic>{};
    return FinanceCategoryJarMapping(
      id: j['id']?.toString() ?? j['mappingId']?.toString() ?? '',
      financeModelId:
          j['financeModelId']?.toString() ?? model['id']?.toString() ?? '',
      categoryId:
          j['categoryId']?.toString() ?? category['id']?.toString() ?? '',
      jarId: j['jarId']?.toString() ?? jar['id']?.toString() ?? '',
      categoryName:
          j['categoryName']?.toString() ?? category['name']?.toString(),
      jarName: j['jarName']?.toString() ?? jar['name']?.toString(),
    );
  }
}

class JarTargetActualItem {
  final String jarId;
  final String jarName;

  /// Mã hũ (`SAVING`, `NEC`, `EDU`…). Dùng để đoán hũ nào là hũ **tích luỹ** —
  /// xem [isSavingLike]. BE chưa có field phân loại hũ chính thức.
  final String jarCode;

  final double targetPercentage;
  final double actualPercentage;
  final double? targetAmount;
  final double? actualAmount;
  final String status;

  const JarTargetActualItem({
    required this.jarId,
    required this.jarName,
    this.jarCode = '',
    required this.targetPercentage,
    required this.actualPercentage,
    this.targetAmount,
    this.actualAmount,
    required this.status,
  });

  /// Hũ mà **vượt tỷ lệ là chuyện tốt** — tiết kiệm / đầu tư / cho đi nhiều
  /// hơn dự định thì không có gì phải báo động.
  ///
  /// ⚠️ Đây là **đoán theo tên**, không phải dữ liệu thật: BE chưa có field
  /// phân loại hũ (`FinanceJar` chỉ có id/name/jarCode/allocationPercentage).
  /// Gia đình đặt tên hũ kiểu khác là đoán trượt — đã đề xuất BE thêm
  /// `jarType`. Đoán trượt chỉ làm sai màu sắc, không sai số liệu.
  static bool looksLikeSaving(String code, String name) {
    final text = '$code $name'.toLowerCase();
    const keys = [
      'sav', // SAVING, savings, tiết kiệm (mã)
      'tiết kiệm',
      'tich luy',
      'tích luỹ',
      'tích lũy',
      'invest',
      'đầu tư',
      'dau tu',
      'ltss', // Long Term Saving for Spending (mô hình 6 hũ)
      'ffa', // Financial Freedom Account
      'give',
      'cho đi',
      'từ thiện',
      'edu', // học tập cũng là đầu tư dài hạn
      'giáo dục',
    ];
    return keys.any(text.contains);
  }

  bool get isSavingLike => looksLikeSaving(jarCode, jarName);

  factory JarTargetActualItem.fromJson(Map<String, dynamic> j) {
    final jar = j['jar'] is Map
        ? Map<String, dynamic>.from(j['jar'] as Map)
        : const <String, dynamic>{};
    return JarTargetActualItem(
      jarId: j['jarId']?.toString() ?? jar['id']?.toString() ?? '',
      jarCode:
          j['jarCode']?.toString() ??
          jar['jarCode']?.toString() ??
          jar['code']?.toString() ??
          '',
      jarName:
          j['jarName']?.toString() ??
          j['name']?.toString() ??
          jar['name']?.toString() ??
          'Hũ tài chính',
      targetPercentage: _money(
        j['targetPercentage'] ??
            j['targetPercent'] ??
            j['allocationPercentage'],
      ),
      actualPercentage: _money(
        j['actualPercentage'] ?? j['actualPercent'] ?? j['percentage'],
      ),
      targetAmount: _moneyNull(j['targetAmount'] ?? j['plannedAmount']),
      actualAmount: _moneyNull(j['actualAmount'] ?? j['spentAmount']),
      status: j['status']?.toString().toUpperCase() ?? '',
    );
  }
}

class JarTargetActualReport {
  final List<JarTargetActualItem> items;
  final double? unmappedAmount;

  /// Mẫu số của cả báo cáo — **tổng chi đã theo dõi trong kỳ**, không phải thu
  /// nhập. Swagger nói rõ: `targetAmount = trackedAmount * targetPercentage /
  /// 100` và `actualPercentage = actualAmount / trackedAmount * 100`. Phải nêu
  /// rõ con số này ra UI, nếu không người dùng thấy "hạn mức" tự tăng mỗi lần
  /// chi thêm và tưởng app tính sai.
  final double? trackedAmount;

  final Map<String, dynamic> raw;

  const JarTargetActualReport({
    required this.items,
    required this.unmappedAmount,
    this.trackedAmount,
    required this.raw,
  });

  factory JarTargetActualReport.fromJson(Map<String, dynamic> j) {
    List<dynamic> rawItems = const [];
    for (final key in const [
      'items',
      'jars',
      'byJar',
      'results',
      'breakdown',
    ]) {
      if (j[key] is List) {
        rawItems = j[key] as List;
        break;
      }
    }
    return JarTargetActualReport(
      items: rawItems
          .whereType<Map>()
          .map(
            (e) => JarTargetActualItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      unmappedAmount: _moneyNull(
        j['unmappedAmount'] ??
            (j['unmapped'] is Map ? (j['unmapped'] as Map)['amount'] : null),
      ),
      trackedAmount: _moneyNull(
        j['trackedAmount'] ?? j['totalTracked'] ?? j['totalAmount'],
      ),
      raw: j,
    );
  }
}

class BudgetPlan {
  final String id;
  final String planName;
  final String periodType; // MONTHLY | QUARTERLY | YEARLY
  final String periodStart;
  final String periodEnd;
  final double? expectedSharedIncome;
  final double? expectedSharedExpense;
  final String status; // DRAFT | ACTIVE | CLOSED | CANCELED

  const BudgetPlan({
    required this.id,
    required this.planName,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    this.expectedSharedIncome,
    this.expectedSharedExpense,
    required this.status,
  });

  factory BudgetPlan.fromJson(Map<String, dynamic> j) => BudgetPlan(
    id: j['id']?.toString() ?? '',
    planName: j['planName']?.toString() ?? '',
    periodType: j['periodType']?.toString() ?? 'MONTHLY',
    periodStart: j['periodStart']?.toString() ?? '',
    periodEnd: j['periodEnd']?.toString() ?? '',
    expectedSharedIncome: _moneyNull(j['expectedSharedIncome']),
    expectedSharedExpense: _moneyNull(j['expectedSharedExpense']),
    status: j['status']?.toString() ?? 'DRAFT',
  );

  Color get statusColor => switch (status) {
    'ACTIVE' => const Color(0xFF16A34A),
    'CLOSED' => const Color(0xFF6B7280),
    'CANCELED' => const Color(0xFFDC2626),
    _ => const Color(0xFFD97706),
  };

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Đang áp dụng',
    'CLOSED' => 'Đã đóng',
    'CANCELED' => 'Đã hủy',
    _ => 'Bản nháp',
  };

  DateTime? get periodStartDate => DateTime.tryParse(periodStart);
  DateTime? get periodEndDate => DateTime.tryParse(periodEnd);

  /// Kỳ của kế hoạch có bao gồm ngày [d] không.
  ///
  /// `null` = không đọc được mốc thời gian → coi như có, để không tự dựng cảnh
  /// báo dựa trên dữ liệu mình không chắc.
  bool coversDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final start = periodStartDate;
    final end = periodEndDate;
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  /// Trạng thái ACTIVE nhưng kỳ **chưa tới** hoặc **đã qua**.
  ///
  /// Gặp thật 19/08: người dùng tạo kế hoạch cho tháng 9, dòng ngân sách 5 triệu,
  /// rồi ghi khoản chi 8 triệu vào **tháng 8** và chờ cảnh báo vượt ngân sách.
  /// Không có cảnh báo nào — đúng, vì khoản chi nằm ngoài kỳ của kế hoạch.
  /// Nhưng thẻ chỉ ghi "Đang áp dụng" nên trông như kế hoạch đang có hiệu lực
  /// ngay bây giờ.
  bool get isFuturePeriod {
    final start = periodStartDate;
    if (status != 'ACTIVE' || start == null) return false;
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).isBefore(DateTime(start.year, start.month, start.day));
  }

  bool get isExpiredPeriod {
    final end = periodEndDate;
    if (status != 'ACTIVE' || end == null) return false;
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).isAfter(DateTime(end.year, end.month, end.day));
  }

  /// Câu giải thích khi kế hoạch ACTIVE nhưng chưa/không còn hiệu lực hôm nay.
  String? get periodWarning {
    if (isFuturePeriod) {
      return 'Kỳ của kế hoạch này chưa bắt đầu — các khoản chi hôm nay KHÔNG '
          'được tính vào đây và sẽ không sinh cảnh báo vượt ngân sách.';
    }
    if (isExpiredPeriod) {
      return 'Kỳ của kế hoạch này đã kết thúc — các khoản chi hôm nay không '
          'còn được tính vào đây.';
    }
    return null;
  }
}

// 1 dòng ngân sách thuộc BudgetPlan — chỉ có khi lấy chi tiết 1 plan
// (GET .../budget-plans/{id}), list endpoint không trả kèm lines.
class BudgetLine {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final String? jarId;
  final double plannedAmount;
  final double? actualAmount;
  final double? thresholdAmount;
  final double? thresholdPercent;
  final String? essentialType;
  final String? note;

  const BudgetLine({
    required this.id,
    this.categoryId,
    this.categoryName,
    this.jarId,
    required this.plannedAmount,
    this.actualAmount,
    this.thresholdAmount,
    this.thresholdPercent,
    this.essentialType,
    this.note,
  });

  factory BudgetLine.fromJson(Map<String, dynamic> j) {
    final categoryMap = j['category'] is Map
        ? Map<String, dynamic>.from(j['category'] as Map)
        : null;
    return BudgetLine(
      id: j['id']?.toString() ?? '',
      categoryId: j['categoryId']?.toString() ?? categoryMap?['id']?.toString(),
      categoryName:
          categoryMap?['name']?.toString() ?? j['categoryName']?.toString(),
      jarId: j['jarId']?.toString(),
      plannedAmount: _money(j['plannedAmount']),
      actualAmount: _moneyNull(j['actualAmount']),
      thresholdAmount: _moneyNull(j['thresholdAmount']),
      thresholdPercent: _moneyNull(j['thresholdPercent']),
      essentialType: j['essentialType']?.toString(),
      note: j['note']?.toString(),
    );
  }
}

class FinancialGoal {
  final String id;
  final String goalName;
  final double targetAmount;
  final String? deadline;
  final String status; // ACTIVE | ACHIEVED | CANCELED | AT_RISK
  final double? progressPercent;
  final double? currentAmount;
  final double? remainingAmount;

  const FinancialGoal({
    required this.id,
    required this.goalName,
    required this.targetAmount,
    this.deadline,
    required this.status,
    this.progressPercent,
    this.currentAmount,
    this.remainingAmount,
  });

  // Với includeProgress=true BE bọc item thành {goal: {...}, progress: {...}}
  // — phải bóc lớp, đọc phẳng sẽ ra tên rỗng/0đ (bug đã xác minh trên API live)
  factory FinancialGoal.fromJson(Map<String, dynamic> j) {
    final goal = j['goal'] is Map
        ? Map<String, dynamic>.from(j['goal'] as Map)
        : j;
    final progress = j['progress'] is Map
        ? Map<String, dynamic>.from(j['progress'] as Map)
        : null;
    return FinancialGoal(
      id: goal['id']?.toString() ?? '',
      goalName: goal['goalName']?.toString() ?? '',
      targetAmount: _money(goal['targetAmount']),
      deadline: goal['deadline']?.toString(),
      status: goal['status']?.toString() ?? 'ACTIVE',
      progressPercent: _moneyNull(
        progress?['progressPercent'] ??
            goal['progressPercent'] ??
            j['progressPercent'],
      ),
      currentAmount: _moneyNull(
        progress?['currentAmount'] ??
            goal['currentAmount'] ??
            j['currentAmount'],
      ),
      remainingAmount: _moneyNull(
        progress?['remainingAmount'] ??
            goal['remainingAmount'] ??
            j['remainingAmount'],
      ),
    );
  }

  /// BE dùng `ACHIEVED`; một số response cũ trả `COMPLETED`. Ở list có thể
  /// status chưa cập nhật kịp, nhưng progress đã là 100%, nên dùng cả hai để
  /// tránh hiển thị sai "Đang tiết kiệm" và tránh cho góp dư.
  bool get isAchieved =>
      status == 'ACHIEVED' ||
      status == 'COMPLETED' ||
      (progressPercent ?? 0) >= 100;

  /// List endpoint đôi khi chỉ trả `progressPercent`, còn endpoint chi tiết mới
  /// có `currentAmount`. Dùng số suy ra để UI không hiển thị sai 0 ₫ / mục tiêu.
  double? get displayCurrentAmount =>
      currentAmount ??
      (progressPercent == null
          ? null
          : targetAmount * (progressPercent!.clamp(0, 100) / 100));

  Color get statusColor {
    if (isAchieved) return const Color(0xFF16A34A);
    return switch (status) {
      'CANCELED' => const Color(0xFFDC2626),
      'AT_RISK' => const Color(0xFFDC2626),
      _ => const Color(0xFF2563EB),
    };
  }

  String get statusLabel {
    if (isAchieved) return 'Đã hoàn thành';
    return switch (status) {
      'CANCELED' => 'Đã hủy',
      'AT_RISK' => 'Có nguy cơ không đạt',
      _ => 'Đang tiết kiệm',
    };
  }

  /// AT_RISK là cảnh báo tiến độ, không phải trạng thái đóng mục tiêu.
  /// Chỉ mục tiêu đã hoàn thành hoặc đã hủy mới không được góp thêm.
  bool get canContribute => !isAchieved && status != 'CANCELED';
}

// GET .../financial-goals/{goalId}/allocations — 1 lần góp tiền (ad-hoc, khác
// với Goal Contribution Plans theo tháng) đã ghi vào mục tiêu.
class GoalAllocation {
  final String id;
  final double amount;
  final String? note;
  final String? createdAt;

  const GoalAllocation({
    required this.id,
    required this.amount,
    this.note,
    this.createdAt,
  });

  factory GoalAllocation.fromJson(Map<String, dynamic> j) => GoalAllocation(
    id: j['id']?.toString() ?? '',
    amount: _money(j['amount']),
    note: j['note']?.toString(),
    createdAt: j['createdAt']?.toString(),
  );
}

// GET .../financial-goals/{goalId}/contribution-suggestions — chỉ đọc, gợi ý
// mức đóng góp/tháng theo từng thành viên. BE không document response schema
// → parse phòng thủ nhiều tên field khả dĩ, giữ `raw` để debug/hiển thị
// fallback nếu tên field đoán sai.
/// Một dòng gợi ý đóng góp do AI tính, kèm căn cứ tính.
///
/// **Đây là ĐỀ XUẤT, không phải nghĩa vụ.** BE đổi cách tính 2026-08-18: khoản
/// đã góp quỹ chung KHÔNG còn bị lấy làm "số phải góp tiếp cho mục tiêu", nó
/// chỉ bị **trừ khỏi khả năng còn lại**:
///
/// ```
/// availableAmount = incomeAmount - personalExpenseAmount - sharedContributionAmount
/// suggestedContribution = contributionTargetAmount * availableAmount / totalAvailableAmount
/// ```
///
/// Nhờ vậy người đã góp quỹ chung 10 triệu thấy khoản đó ở "Đã góp quỹ chung"
/// và **khả dụng còn lại giảm đi**, chứ không bị hiểu thành phải góp thêm 10
/// triệu nữa cho mục tiêu.
class ContributionSuggestion {
  final String memberId;
  final String memberName;

  /// Số tiền AI đề xuất. BE mới gửi `suggestedContribution`; các tên cũ
  /// (`suggestedAmount`/`amount`/`plannedAmount`) vẫn nhận để không vỡ khi BE
  /// chưa deploy.
  final double suggestedAmount;

  final double? incomeAmount;
  final double? personalExpenseAmount;
  final double? sharedContributionAmount;
  final double? availableAmount;

  /// Nguồn số liệu BE dùng (vd khai báo tay vs tính từ sổ) — hiển thị nguyên
  /// văn nếu có, không dịch vì chưa biết hết tập giá trị.
  final String? incomeSource;
  final String? expenseSource;
  final String? sharedContributionSource;

  final Map<String, dynamic> raw;

  const ContributionSuggestion({
    required this.memberId,
    required this.memberName,
    required this.suggestedAmount,
    required this.raw,
    this.incomeAmount,
    this.personalExpenseAmount,
    this.sharedContributionAmount,
    this.availableAmount,
    this.incomeSource,
    this.expenseSource,
    this.sharedContributionSource,
  });

  /// Có đủ số liệu để bày phần "căn cứ tính" hay không. Thiếu sạch thì chỉ
  /// hiện mỗi số tiền, không dựng khung rỗng.
  bool get hasBreakdown =>
      incomeAmount != null ||
      personalExpenseAmount != null ||
      sharedContributionAmount != null ||
      availableAmount != null;

  factory ContributionSuggestion.fromJson(Map<String, dynamic> j) {
    final memberMap = j['member'] is Map
        ? Map<String, dynamic>.from(j['member'] as Map)
        : j['user'] is Map
        ? Map<String, dynamic>.from(j['user'] as Map)
        : null;
    double? moneyOrNull(dynamic v) => v == null ? null : _money(v);
    String? strOrNull(dynamic v) {
      final s = v?.toString();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ContributionSuggestion(
      memberId:
          j['memberId']?.toString() ??
          memberMap?['id']?.toString() ??
          memberMap?['userId']?.toString() ??
          '',
      memberName:
          // `displayName` ở gốc dòng gợi ý là tên BE mới gửi kèm; ưu tiên nó
          // trước khi phải lần vào object member/user lồng bên trong.
          strOrNull(j['displayName']) ??
          strOrNull(memberMap?['fullName']) ??
          strOrNull(memberMap?['displayName']) ??
          strOrNull(j['memberName']) ??
          'Thành viên',
      suggestedAmount: _money(
        j['suggestedContribution'] ??
            j['suggestedAmount'] ??
            j['amount'] ??
            j['plannedAmount'],
      ),
      incomeAmount: moneyOrNull(j['incomeAmount']),
      personalExpenseAmount: moneyOrNull(j['personalExpenseAmount']),
      sharedContributionAmount: moneyOrNull(j['sharedContributionAmount']),
      availableAmount: moneyOrNull(j['availableAmount']),
      incomeSource: strOrNull(j['incomeSource']),
      expenseSource: strOrNull(j['expenseSource']),
      sharedContributionSource: strOrNull(j['sharedContributionSource']),
      raw: j,
    );
  }
}

/// Thành viên BE bỏ qua khi tính gợi ý, kèm lý do máy đọc được.
class SkippedContributionMember {
  final String memberId;
  final String displayName;

  /// Mã lý do của BE (`MISSING_MONTHLY_FINANCE`, `INCOME_NOT_VISIBLE`…).
  final String reason;

  const SkippedContributionMember({
    required this.memberId,
    required this.displayName,
    required this.reason,
  });

  factory SkippedContributionMember.fromJson(Map<String, dynamic> j) {
    return SkippedContributionMember(
      memberId: j['memberId']?.toString() ?? '',
      displayName: j['displayName']?.toString() ?? 'Thành viên',
      reason: j['reason']?.toString() ?? '',
    );
  }

  /// Câu tiếng Việt cho người dùng đọc. Mã lạ thì trả nguyên văn thay vì nuốt
  /// mất — BE có thể thêm mã mới bất cứ lúc nào.
  String get reasonLabel => switch (reason.toUpperCase()) {
    'MISSING_MONTHLY_FINANCE' => 'Chưa có dữ liệu thu chi tháng này',
    'INCOME_NOT_VISIBLE' => 'Thu nhập đang ẩn',
    'EXPENSE_NOT_VISIBLE' => 'Chi tiêu đang ẩn',
    'NO_AVAILABLE_AMOUNT' => 'Không còn khả dụng sau chi phí và quỹ chung',
    _ => reason.isEmpty ? 'Chưa đủ dữ liệu để ước tính' : reason,
  };
}

/// Kết quả đối chiếu "mức đang định góp" với "mức cần góp để kịp hạn".
///
/// Sinh ra để cảnh báo sớm: AI chia đúng số tiền người dùng đưa ra, nhưng
/// **không tự đối chiếu** với `recommendedMonthlyContribution` mà BE đã tính.
/// Ca thật gặp 2026-08-18: mục tiêu 500 triệu, hạn 17/09/2029, người dùng đặt
/// 5 triệu/tháng → chỉ đạt 185 triệu, thiếu 315 triệu, mà không có cảnh báo nào.
class ContributionShortfall {
  /// Tổng số tiền dự định góp mỗi tháng (tổng các dòng gợi ý, hoặc số người
  /// dùng tự nhập).
  final double planned;

  /// Mức cần góp mỗi tháng để đạt mục tiêu đúng hạn — BE tính, FE không đoán.
  final double recommended;

  /// Số tiền còn thiếu để đạt mục tiêu.
  final double? remaining;

  const ContributionShortfall({
    required this.planned,
    required this.recommended,
    this.remaining,
  });

  /// Tỷ lệ đạt được nếu giữ mức hiện tại, 0..1.
  double get coverage => recommended <= 0 ? 1 : planned / recommended;

  /// Phần trăm làm tròn để hiện cho người dùng.
  int get coveragePercent => (coverage * 100).round();

  /// Số tháng cần nếu giữ nguyên mức hiện tại. `null` khi không tính được
  /// (chưa biết số còn thiếu, hoặc mức góp bằng 0 → không bao giờ tới đích).
  int? get monthsNeeded {
    final left = remaining;
    if (left == null || left <= 0 || planned <= 0) return null;
    return (left / planned).ceil();
  }
}

/// Trả về cảnh báo khi mức góp **không đủ** đạt mục tiêu đúng hạn.
///
/// `null` nghĩa là không cần cảnh báo: hoặc BE chưa gửi
/// `recommendedMonthlyContribution` (không đoán thay BE), hoặc mức đang góp đã
/// đủ. Dùng ngưỡng 1% để bỏ qua chênh lệch do làm tròn — tổng các dòng gợi ý
/// thường lệch vài đồng so với mục tiêu.
ContributionShortfall? evaluateContributionShortfall({
  required double planned,
  double? recommended,
  double? remaining,
}) {
  if (recommended == null || recommended <= 0) return null;
  if (planned >= recommended * 0.99) return null;
  return ContributionShortfall(
    planned: planned,
    recommended: recommended,
    remaining: remaining,
  );
}

/// Toàn bộ response của `contribution-suggestions`, gồm cả phần metadata BE
/// mới bổ sung.
///
/// BE có thể trả **mảng thuần** (bản cũ) hoặc **object** có `suggestions` +
/// metadata (bản mới) — [fromJson] nhận cả hai để app không vỡ dù BE deploy
/// trước hay sau.
class ContributionSuggestionResult {
  final List<ContributionSuggestion> suggestions;
  final List<SkippedContributionMember> skippedMembers;
  final List<String> warnings;

  /// Căn cứ BE dùng để chia (vd theo khả dụng còn lại). Chuỗi tự do.
  final String? basis;

  final double? monthlyContributionTarget;
  final double? explicitMonthlyContributionTarget;
  final double? recommendedMonthlyContribution;
  final double? remainingAmount;
  final double? totalAvailableAmount;

  const ContributionSuggestionResult({
    this.suggestions = const [],
    this.skippedMembers = const [],
    this.warnings = const [],
    this.basis,
    this.monthlyContributionTarget,
    this.explicitMonthlyContributionTarget,
    this.recommendedMonthlyContribution,
    this.remainingAmount,
    this.totalAvailableAmount,
  });

  bool get hasMeta =>
      warnings.isNotEmpty ||
      skippedMembers.isNotEmpty ||
      totalAvailableAmount != null ||
      monthlyContributionTarget != null ||
      recommendedMonthlyContribution != null;

  factory ContributionSuggestionResult.fromJson(dynamic data) {
    double? moneyOrNull(dynamic v) => v == null ? null : _money(v);

    // Bản cũ: BE trả thẳng mảng, không có metadata nào.
    if (data is List) {
      return ContributionSuggestionResult(
        suggestions: data
            .whereType<Map>()
            .map(
              (e) =>
                  ContributionSuggestion.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
    }
    if (data is! Map) return const ContributionSuggestionResult();
    final map = Map<String, dynamic>.from(data);

    // Envelope `{ data: {...} }` đã được ApiClient bóc, nhưng vẫn có thể gặp
    // dạng lồng thêm một lớp — dò `suggestions` ở cả hai chỗ.
    final rawList = map['suggestions'] ?? map['items'] ?? map['data'];
    final suggestions = rawList is List
        ? rawList
              .whereType<Map>()
              .map(
                (e) => ContributionSuggestion.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <ContributionSuggestion>[];

    final rawSkipped = map['skippedMembers'];
    final rawWarnings = map['warnings'];

    return ContributionSuggestionResult(
      suggestions: suggestions,
      skippedMembers: rawSkipped is List
          ? rawSkipped
                .whereType<Map>()
                .map(
                  (e) => SkippedContributionMember.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      warnings: rawWarnings is List
          ? rawWarnings
                .map((e) => e?.toString() ?? '')
                .where((e) => e.isNotEmpty)
                .toList()
          : const [],
      basis: map['basis']?.toString(),
      monthlyContributionTarget: moneyOrNull(map['monthlyContributionTarget']),
      explicitMonthlyContributionTarget: moneyOrNull(
        map['explicitMonthlyContributionTarget'],
      ),
      recommendedMonthlyContribution: moneyOrNull(
        map['recommendedMonthlyContribution'],
      ),
      remainingAmount: moneyOrNull(map['remainingAmount']),
      totalAvailableAmount: moneyOrNull(map['totalAvailableAmount']),
    );
  }
}

// GET .../financial-goals/{goalId}/contribution-plans — kế hoạch đóng góp
// tháng theo từng thành viên (planned vs actual). `status` là TÊN ĐOÁN theo
// quy ước enum ALL_CAPS của project — CHƯA verify trực tiếp với BE thật, cần
// chạy live để xác nhận (PENDING/SUBMITTED/APPROVED/REJECTED là suy luận từ
// luồng submit→approve/reject mô tả trong Swagger, không phải giá trị đã thấy).
class GoalContributionPlan {
  final String id;
  final String memberId;
  final String memberName;
  final double plannedAmount;
  final double? actualAmount;
  final String status;
  final String? note;
  final String? dueDate;
  final Map<String, dynamic> raw;

  const GoalContributionPlan({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.plannedAmount,
    this.actualAmount,
    required this.status,
    this.note,
    this.dueDate,
    required this.raw,
  });

  // Live BE response uses PLANNED for a plan waiting for its member to submit
  // (the older FE assumption was PENDING).
  bool get isPending {
    final value = status.toUpperCase();
    return value == 'PENDING' || value == 'PLANNED';
  }

  bool get isSubmitted => status.toUpperCase() == 'SUBMITTED';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  String get statusLabel => switch (status.toUpperCase()) {
    'SUBMITTED' => 'Chờ duyệt',
    'APPROVED' => 'Đã duyệt',
    'PAID' => 'Đã hoàn thành',
    'REJECTED' => 'Bị từ chối',
    _ => 'Chưa nộp',
  };

  Color get statusColor => switch (status.toUpperCase()) {
    'SUBMITTED' => const Color(0xFFD97706),
    'APPROVED' => const Color(0xFF16A34A),
    'PAID' => const Color(0xFF16A34A),
    'REJECTED' => const Color(0xFFDC2626),
    _ => const Color(0xFF6B7280),
  };

  factory GoalContributionPlan.fromJson(Map<String, dynamic> j) {
    final memberMap = j['member'] is Map
        ? Map<String, dynamic>.from(j['member'] as Map)
        : j['user'] is Map
        ? Map<String, dynamic>.from(j['user'] as Map)
        : null;
    return GoalContributionPlan(
      id:
          j['id']?.toString() ??
          j['planId']?.toString() ??
          j['contributionPlanId']?.toString() ??
          '',
      memberId:
          j['memberId']?.toString() ??
          memberMap?['id']?.toString() ??
          memberMap?['userId']?.toString() ??
          '',
      memberName:
          memberMap?['fullName']?.toString() ??
          memberMap?['displayName']?.toString() ??
          j['displayName']?.toString() ??
          j['memberName']?.toString() ??
          'Thành viên',
      plannedAmount: _money(j['plannedAmount']),
      actualAmount: _moneyNull(
        j['actualAmount'] ?? j['submittedAmount'] ?? j['amount'],
      ),
      status: j['status']?.toString() ?? 'PENDING',
      note: j['note']?.toString(),
      dueDate: j['dueDate']?.toString(),
      raw: j,
    );
  }
}

class MonthlyFinance {
  final String id;
  final int periodMonth;
  final int periodYear;
  final double? expectedIncome;
  final double? actualIncome;
  final double? expectedPersonalExpense;
  final double? actualPersonalExpense;
  final double? expectedSharedContribution;
  final double? actualSharedContribution;
  final String incomeVisibility;
  final String expenseVisibility;
  final String? note;

  const MonthlyFinance({
    required this.id,
    required this.periodMonth,
    required this.periodYear,
    this.expectedIncome,
    this.actualIncome,
    this.expectedPersonalExpense,
    this.actualPersonalExpense,
    this.expectedSharedContribution,
    this.actualSharedContribution,
    required this.incomeVisibility,
    required this.expenseVisibility,
    this.note,
  });

  factory MonthlyFinance.fromJson(Map<String, dynamic> j) => MonthlyFinance(
    id: j['id']?.toString() ?? '',
    periodMonth: (j['periodMonth'] as num?)?.toInt() ?? 0,
    periodYear: (j['periodYear'] as num?)?.toInt() ?? 0,
    expectedIncome: _moneyNull(j['expectedIncome']),
    actualIncome: _moneyNull(j['actualIncome']),
    expectedPersonalExpense: _moneyNull(j['expectedPersonalExpense']),
    actualPersonalExpense: _moneyNull(j['actualPersonalExpense']),
    expectedSharedContribution: _moneyNull(j['expectedSharedContribution']),
    actualSharedContribution: _moneyNull(j['actualSharedContribution']),
    incomeVisibility: j['incomeVisibility']?.toString() ?? 'PRIVATE',
    expenseVisibility: j['expenseVisibility']?.toString() ?? 'PRIVATE',
    note: j['note']?.toString(),
  );
}

// Tổng quan tài chính tháng của 1 thành viên — response của
// GET .../finance/monthly-summary/me | .../monthly-summary/members/{memberId}
// (BE 2026-07-13). Field private của member khác được BE trả null sẵn.
class MonthlySummary {
  final int month;
  final int year;
  final String memberName;
  final MonthlyFinance? monthlyFinance; // null = chưa khai báo tháng này
  // Đóng góp quỹ gia đình
  final double? fundPlanned;
  final double? fundDeclared;
  final double fundLedgerActual;
  final double fundActual;
  // Đóng góp mục tiêu tài chính
  final double goalPlanned;
  final double goalActual;
  final double goalShortage;
  final List<Map<String, dynamic>> goalItems;

  const MonthlySummary({
    required this.month,
    required this.year,
    required this.memberName,
    this.monthlyFinance,
    this.fundPlanned,
    this.fundDeclared,
    required this.fundLedgerActual,
    required this.fundActual,
    required this.goalPlanned,
    required this.goalActual,
    required this.goalShortage,
    required this.goalItems,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> j) {
    final period = j['period'] is Map ? j['period'] as Map : const {};
    final member = j['member'] is Map ? j['member'] as Map : const {};
    final fund = j['familyFundContribution'] is Map
        ? j['familyFundContribution'] as Map
        : const {};
    final goal = j['goalContributions'] is Map
        ? j['goalContributions'] as Map
        : const {};
    return MonthlySummary(
      month: (period['month'] as num?)?.toInt() ?? 0,
      year: (period['year'] as num?)?.toInt() ?? 0,
      memberName: member['displayName']?.toString() ?? '',
      monthlyFinance: j['monthlyFinance'] is Map
          ? MonthlyFinance.fromJson(
              Map<String, dynamic>.from(j['monthlyFinance'] as Map),
            )
          : null,
      fundPlanned: _moneyNull(fund['plannedAmount']),
      fundDeclared: _moneyNull(fund['declaredActualAmount']),
      fundLedgerActual: _moneyNull(fund['ledgerActualAmount']) ?? 0,
      fundActual: _moneyNull(fund['actualAmount']) ?? 0,
      goalPlanned: _moneyNull(goal['totalPlannedAmount']) ?? 0,
      goalActual: _moneyNull(goal['totalActualAmount']) ?? 0,
      goalShortage: _moneyNull(goal['totalShortageAmount']) ?? 0,
      goalItems: goal['items'] is List
          ? (goal['items'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
    );
  }
}

// API: Lấy số dư khả dụng từ tháng
class SurplusAvailability {
  final int periodMonth;
  final int periodYear;
  final double totalSurplus;
  final double allocatedSurplus;
  final double availableSurplus;

  const SurplusAvailability({
    required this.periodMonth,
    required this.periodYear,
    required this.totalSurplus,
    required this.allocatedSurplus,
    required this.availableSurplus,
  });

  factory SurplusAvailability.fromJson(Map<String, dynamic> j) {
    return SurplusAvailability(
      periodMonth: (j['periodMonth'] as num?)?.toInt() ?? 0,
      periodYear: (j['periodYear'] as num?)?.toInt() ?? 0,
      totalSurplus: _money(j['totalSurplus']),
      allocatedSurplus: _money(j['allocatedSurplus']),
      availableSurplus: _money(j['availableSurplus']),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Provider
// ════════════════════════════════════════════════════════════════════════

class FinanceProvider extends ChangeNotifier {
  FinanceProvider() {
    ApiClient.addSessionResetListener(resetForNewSession);
  }

  /// Xóa dữ liệu của tài khoản vừa đăng xuất.
  ///
  /// Provider này nằm ở app scope (`main.dart`) nên sống suốt vòng đời ứng
  /// dụng, không bị hủy khi đổi tài khoản. Không dọn thì người đăng nhập sau
  /// nhìn thấy dữ liệu của người trước. Đăng ký tự động qua
  /// [ApiClient.addSessionResetListener].
  void resetForNewSession() {
    models = [];
    jars = [];
    categories = [];
    budgetPlans = [];
    goals = [];
    monthlyFinance = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  List<FinanceModel> models = [];
  List<FinanceJar> jars = [];
  List<FinanceCategory> categories = [];
  List<BudgetPlan> budgetPlans = [];
  List<FinancialGoal> goals = [];
  MonthlyFinance? monthlyFinance;

  bool loading = false;
  String? error;

  FinanceModel? get activeModel =>
      models.where((m) => m.isActive).firstOrNull ?? models.firstOrNull;

  List<BudgetPlan> get activeBudgetPlans =>
      budgetPlans.where((p) => p.status == 'ACTIVE').toList();

  /// Mục tiêu còn nhận được tiền góp.
  ///
  /// **Không** lọc `status == 'ACTIVE'`: `AT_RISK` là cảnh báo tiến độ, không
  /// phải trạng thái đóng mục tiêu (xem [FinancialGoal.canContribute]). Lọc
  /// theo ACTIVE làm mục tiêu đang có nguy cơ trượt bị loại khỏi danh sách nhận
  /// số dư kết chuyển — đúng cái mục tiêu cần tiền nhất lại bị giấu đi, và card
  /// kết chuyển báo "chưa có mục tiêu nào đang chạy" dù rõ ràng đang có.
  List<FinancialGoal> get contributableGoals =>
      goals.where((g) => g.canContribute).toList();

  String get _fid {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    return fid;
  }

  /// `2026-08-01` — định dạng ngày BE dùng cho mọi field `period*` của Finance.
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _qs(Map<String, dynamic> params) {
    final entries = params.entries.where(
      (e) => e.value != null && e.value.toString().isNotEmpty,
    );
    if (entries.isEmpty) return '';
    return '?${entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}').join('&')}';
  }

  Future<void> fetchAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([
        _fetchModels(),
        _fetchJars(),
        _fetchCategories(),
        _fetchBudgetPlans(),
        _fetchGoals(),
        _fetchMonthlyFinance(),
      ]);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchModels() async {
    final data = await ApiClient.instance.get('/families/$_fid/finance/models');
    models = _list(data).map(FinanceModel.fromJson).toList();
  }

  Future<void> _fetchJars() async {
    final data = await ApiClient.instance.get('/families/$_fid/finance/jars');
    jars = _list(data).map(FinanceJar.fromJson).toList();
  }

  Future<void> _fetchCategories() async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/categories',
    );
    categories = _list(data).map(FinanceCategory.fromJson).toList();
  }

  Future<void> _fetchBudgetPlans() async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/budget-plans${_qs({'limit': 20})}',
    );
    budgetPlans = _list(data).map(BudgetPlan.fromJson).toList();
  }

  Future<void> _fetchGoals() async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals${_qs({'includeProgress': 'true'})}',
    );
    goals = _list(data).map(FinancialGoal.fromJson).toList();
  }

  /// Bản khai của **tháng hiện tại**. Cố ý không đi theo kỳ người dùng đang
  /// xem: `upsertMonthlyFinance` dùng field này để chọn POST hay PUT, và màn
  /// khai báo (`edit_profile_screen`) luôn khai cho tháng này. Muốn đọc kỳ khác
  /// thì dùng [fetchMonthlyFinanceFor] — nó không đụng vào state chung.
  Future<void> _fetchMonthlyFinance() async {
    try {
      monthlyFinance = await fetchMonthlyFinanceFor(FinancePeriod.current());
    } catch (e) {
      debugPrint('FinanceProvider: fetchMonthlyFinance failed: $e');
      monthlyFinance = null;
    }
  }

  /// Đọc bản khai tài chính của chính mình ở một kỳ bất kỳ (không cache).
  Future<MonthlyFinance?> fetchMonthlyFinanceFor(FinancePeriod period) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/monthly-finances/me'
      '${_qs({'month': period.month, 'year': period.year})}',
    );
    return data is Map<String, dynamic> && data.isNotEmpty
        ? MonthlyFinance.fromJson(data)
        : null;
  }

  // ── Mutations: Model / Jar ───────────────────────────────────────────────

  // Trả về FinanceModel vừa tạo (kèm jars BE tự sinh cho FIVE_JARS/EIGHTY_TWENTY,
  // rỗng cho CUSTOM) — caller cần model.id để activate/tạo thêm jar ngay,
  // không đợi round-trip fetchModels().
  Future<FinanceModel> createModel({
    required String modelType,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/families/$_fid/finance/models',
      {'modelType': modelType, 'name': name},
    );
    await _fetchModels();
    notifyListeners();
    return FinanceModel.fromJson(res);
  }

  Future<void> activateModel(String modelId) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/models/$modelId/activate',
      {},
    );
    await _fetchModels();
    notifyListeners();
  }

  /// Chia một khoản quỹ theo tỷ lệ các hũ của mô hình đang hoạt động.
  ///
  /// BE trả 409 nếu cùng mô hình/kỳ đã được chia trước đó. Không tự retry vì
  /// thao tác này tạo ledger entry cho từng hũ và phải tránh ghi nhận hai lần.
  Future<FundAllocationResult> allocateFundByModel({
    required double amount,
    required int periodMonth,
    required int periodYear,
    String? modelId,
    String? note,
  }) async {
    final response = await ApiClient.instance
        .post('/families/$_fid/finance/fund-allocations', {
          'amount': amount,
          'periodMonth': periodMonth,
          'periodYear': periodYear,
          if (modelId != null && modelId.isNotEmpty) 'modelId': modelId,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
    final result = FundAllocationResult.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (result.items.isEmpty) {
      throw const ApiException(502, 'Kết quả chia quỹ không có danh sách hũ.');
    }
    await fetchAll();
    return result;
  }

  /// Xem lại snapshot các lần chia quỹ. BE giữ nguyên tên/tỷ lệ hũ tại thời
  /// điểm chia nên không ghép lại từ cấu hình model hiện tại.
  Future<FundAllocationPage> fetchFundAllocations({
    String? modelId,
    int? periodMonth,
    int? periodYear,
    int page = 1,
    int limit = 20,
  }) async {
    if ((periodMonth == null) != (periodYear == null)) {
      throw ArgumentError(
        'periodMonth và periodYear phải được truyền cùng nhau',
      );
    }
    final response = await ApiClient.instance.get(
      '/families/$_fid/finance/fund-allocations${_qs({'modelId': modelId, 'periodMonth': periodMonth, 'periodYear': periodYear, 'page': page, 'limit': limit})}',
    );
    return FundAllocationPage.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> updateJar(
    String jarId, {
    double? allocationPercentage,
    bool? isActive,
  }) async {
    await ApiClient.instance.patch('/families/$_fid/finance/jars/$jarId', {
      'allocationPercentage': ?allocationPercentage,
      'isActive': ?isActive,
    });
    await _fetchJars();
    notifyListeners();
  }

  // Tạo jar mới thuộc 1 model (chỉ cần cho CUSTOM — FIVE_JARS/EIGHTY_TWENTY
  // đã có jar mặc định do BE tự sinh kèm theo lúc createModel()).
  Future<FinanceJar> createJar({
    required String financeModelId,
    required String name,
    required String jarCode,
    required double allocationPercentage,
  }) async {
    final res = await ApiClient.instance.post('/families/$_fid/finance/jars', {
      'financeModelId': financeModelId,
      'name': name,
      'jarCode': jarCode,
      'allocationPercentage': allocationPercentage,
    });
    await _fetchJars();
    notifyListeners();
    return FinanceJar.fromJson(res);
  }

  Future<FinanceCategory?> createCategory({
    required String name,
    required String categoryType,
    String? essentialType,
  }) async {
    final res = await ApiClient.instance
        .post('/families/$_fid/finance/categories', {
          'name': name,
          'categoryType': categoryType,
          if (categoryType == 'EXPENSE')
            'essentialType': essentialType ?? 'ESSENTIAL',
        });
    await _fetchCategories();
    notifyListeners();
    return res.isEmpty ? null : FinanceCategory.fromJson(res);
  }

  /// PATCH /families/{familyId}/finance/categories/{categoryId}
  Future<void> updateCategory(
    String categoryId, {
    required String name,
    String? essentialType,
  }) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/categories/$categoryId',
      {'name': name, 'essentialType': ?essentialType},
    );
    await _fetchCategories();
    notifyListeners();
  }

  /// DELETE /families/{familyId}/finance/categories/{categoryId}.
  /// BE ngưng dùng danh mục nhưng giữ dữ liệu ledger/budget đã có.
  Future<void> deactivateCategory(String categoryId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/finance/categories/$categoryId',
    );
    await _fetchCategories();
    notifyListeners();
  }

  /// Mapping thuộc từng model, không dùng chung giữa model cũ và model active.
  Future<List<FinanceCategoryJarMapping>> fetchCategoryJarMappings({
    required String financeModelId,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/category-jar-mappings${_qs({'financeModelId': financeModelId})}',
    );
    return _list(data)
        .map(FinanceCategoryJarMapping.fromJson)
        .where((mapping) => mapping.categoryId.isNotEmpty)
        .toList();
  }

  Future<void> upsertCategoryJarMapping({
    required String financeModelId,
    required String categoryId,
    required String jarId,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/category-jar-mappings',
      {
        'financeModelId': financeModelId,
        'categoryId': categoryId,
        'jarId': jarId,
      },
    );
  }

  Future<void> deleteCategoryJarMapping(String mappingId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/finance/category-jar-mappings/$mappingId',
    );
  }

  Future<JarTargetActualReport> fetchJarTargetActualReport({
    DateTime? periodStart,
    DateTime? periodEnd,
    String? financeModelId,
  }) async {
    String? date(DateTime? value) => value == null
        ? null
        : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/reports/jar-target-actual${_qs({'periodStart': date(periodStart), 'periodEnd': date(periodEnd), 'financeModelId': financeModelId})}',
    );
    return JarTargetActualReport.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ── Mutations: Budget Plan ────────────────────────────────────────────────

  Future<BudgetPlan?> createBudgetPlan({
    required String planName,
    required String periodType,
    required DateTime periodStart,
    required DateTime periodEnd,
    double? expectedSharedIncome,
    double? expectedSharedExpense,
    List<Map<String, dynamic>> lines = const [],
  }) async {
    final res = await ApiClient.instance.post(
      '/families/$_fid/finance/budget-plans',
      {
        'planName': planName,
        'periodType': periodType,
        // `CreateBudgetPlanDto` khai `periodStart`/`periodEnd` dạng chuỗi ngày
        // (`2026-06-01`). `toIso8601String()` gửi kèm giờ local không timezone
        // (`2026-08-02T11:11:23.456`) — lệch contract, và là một trong hai
        // nghi phạm của lỗi "Lỗi hệ thống" khi tạo kế hoạch (2026-08-02).
        'periodStart': _dateOnly(periodStart),
        'periodEnd': _dateOnly(periodEnd),
        'expectedSharedIncome': ?expectedSharedIncome,
        'expectedSharedExpense': ?expectedSharedExpense,
        'lines': lines,
      },
    );

    // `lines` is part of CreateBudgetPlanDto.  Some deployed BE versions
    // created the plan but silently omitted those nested lines.  Verify the
    // result once and add any missing line through the documented endpoint so
    // a newly-created plan can be activated immediately.
    final plan = res.isNotEmpty ? BudgetPlan.fromJson(res) : null;
    if (plan != null && lines.isNotEmpty) {
      final detail = await fetchBudgetPlanDetail(plan.id);
      if (detail.$2.isEmpty) {
        for (final line in lines) {
          await ApiClient.instance.post(
            '/families/$_fid/finance/budget-plans/${plan.id}/lines',
            line,
          );
        }
      }
    }
    await _fetchBudgetPlans();
    notifyListeners();
    return plan;
  }

  /// action: activate | close | cancel
  Future<void> budgetPlanAction(String planId, String action) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/budget-plans/$planId/$action',
      {},
    );
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> addBudgetLine(
    String planId, {
    required String categoryId,
    required double plannedAmount,
    double? thresholdAmount,
    double? thresholdPercent,
    String? essentialType,
  }) async {
    await ApiClient.instance
        .post('/families/$_fid/finance/budget-plans/$planId/lines', {
          'categoryId': categoryId,
          'plannedAmount': plannedAmount,
          'thresholdAmount': ?thresholdAmount,
          'thresholdPercent': ?thresholdPercent,
          'essentialType': ?essentialType,
        });
    notifyListeners();
  }

  // GET /families/{familyId}/finance/budget-plans/{budgetPlanId} — chi tiết 1
  // plan kèm `lines` (list endpoint không trả lines).
  Future<(BudgetPlan, List<BudgetLine>)> fetchBudgetPlanDetail(
    String planId,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/budget-plans/$planId',
    );
    final plan = BudgetPlan.fromJson(data);
    final lines = _list(data['lines']).map(BudgetLine.fromJson).toList();
    return (plan, lines);
  }

  // PATCH /families/{familyId}/finance/budget-plans/{budgetPlanId} — chỉ sửa
  // được khi plan còn DRAFT.
  Future<void> updateBudgetPlan(
    String planId, {
    String? planName,
    String? periodType,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? expectedSharedIncome,
    double? expectedSharedExpense,
  }) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/budget-plans/$planId',
      {
        'planName': ?planName,
        'periodType': ?periodType,
        // Cùng định dạng ngày với create — xem ghi chú ở `createBudgetPlan`.
        'periodStart': ?(periodStart == null ? null : _dateOnly(periodStart)),
        'periodEnd': ?(periodEnd == null ? null : _dateOnly(periodEnd)),
        'expectedSharedIncome': ?expectedSharedIncome,
        'expectedSharedExpense': ?expectedSharedExpense,
      },
    );
    await _fetchBudgetPlans();
    notifyListeners();
  }

  // PATCH /families/{familyId}/finance/budget-lines/{budgetLineId}
  Future<void> updateBudgetLine(
    String lineId, {
    String? categoryId,
    String? jarId,
    double? plannedAmount,
    double? thresholdAmount,
    double? thresholdPercent,
    String? essentialType,
    String? note,
  }) async {
    await ApiClient.instance
        .patch('/families/$_fid/finance/budget-lines/$lineId', {
          'categoryId': ?categoryId,
          'jarId': ?jarId,
          'plannedAmount': ?plannedAmount,
          'thresholdAmount': ?thresholdAmount,
          'thresholdPercent': ?thresholdPercent,
          'essentialType': ?essentialType,
          'note': ?note,
        });
    notifyListeners();
  }

  // DELETE /families/{familyId}/finance/budget-lines/{budgetLineId}
  Future<void> deleteBudgetLine(String lineId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/finance/budget-lines/$lineId',
    );
    notifyListeners();
  }

  // ── Mutations: Financial Goal ────────────────────────────────────────────

  Future<FinancialGoal?> createGoal({
    required String goalName,
    required double targetAmount,
    DateTime? deadline,
    double? monthlyContributionTarget,
  }) async {
    final res = await ApiClient.instance
        .post('/families/$_fid/finance/financial-goals', {
          'goalName': goalName,
          'targetAmount': targetAmount,
          'deadline': ?deadline?.toIso8601String(),
          'monthlyContributionTarget': ?monthlyContributionTarget,
        });
    await _fetchGoals();
    notifyListeners();
    return res.isNotEmpty ? FinancialGoal.fromJson(res) : null;
  }

  Future<void> cancelGoal(String goalId) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/financial-goals/$goalId/cancel',
      {},
    );
    await _fetchGoals();
    notifyListeners();
  }

  Future<void> contributeToGoal(
    String goalId,
    double amount, {
    String? note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/financial-goals/$goalId/allocations',
      {'amount': amount, 'note': ?note},
    );
    await _fetchGoals();
    notifyListeners();
  }

  // GET /families/{familyId}/finance/financial-goals/{goalId} — chi tiết 1
  // goal riêng (list `_fetchGoals` dùng `includeProgress=true` nên đã đủ cho
  // hầu hết UI; gọi thêm để có field không xuất hiện ở list, nếu có).
  Future<(FinancialGoal goal, Map<String, dynamic> progress)>
  fetchGoalDetailWithProgress(String goalId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId',
    );
    final root = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    final progress = root['progress'] is Map
        ? Map<String, dynamic>.from(root['progress'] as Map)
        : <String, dynamic>{};
    return (FinancialGoal.fromJson(root), progress);
  }

  // PATCH /families/{familyId}/finance/financial-goals/{goalId}
  Future<void> updateGoal(
    String goalId, {
    String? goalName,
    double? targetAmount,
    DateTime? deadline,
    double? monthlyContributionTarget,
    String? relatedJarId,
  }) async {
    await ApiClient.instance
        .patch('/families/$_fid/finance/financial-goals/$goalId', {
          'goalName': ?goalName,
          'targetAmount': ?targetAmount,
          'deadline': ?deadline?.toIso8601String(),
          'monthlyContributionTarget': ?monthlyContributionTarget,
          'relatedJarId': ?relatedJarId,
        });
    await _fetchGoals();
    notifyListeners();
  }

  // GET /families/{familyId}/finance/financial-goals/{goalId}/allocations —
  // lịch sử từng lần góp tiền ad-hoc vào mục tiêu (khác Contribution Plans).
  Future<List<GoalAllocation>> fetchGoalAllocations(String goalId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId/allocations',
    );
    return _list(data).map(GoalAllocation.fromJson).toList();
  }

  // PATCH /families/{familyId}/finance/goal-allocations/{allocationId} — sửa
  // số tiền 1 lần góp đã ghi.
  Future<void> updateGoalAllocation(String allocationId, double amount) async {
    await ApiClient.instance.patch(
      '/families/$_fid/finance/goal-allocations/$allocationId',
      {'amount': amount},
    );
    await _fetchGoals();
    notifyListeners();
  }

  // DELETE /families/{familyId}/finance/goal-allocations/{allocationId} —
  // hủy 1 lần góp đã ghi nhầm.
  Future<void> deleteGoalAllocation(String allocationId) async {
    await ApiClient.instance.delete(
      '/families/$_fid/finance/goal-allocations/$allocationId',
    );
    await _fetchGoals();
    notifyListeners();
  }

  // GET /families/{familyId}/finance/financial-goals/surplus-availability
  Future<SurplusAvailability?> fetchSurplusAvailability(
    int month,
    int year,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/surplus-availability${_qs({'month': month, 'year': year})}',
    );
    return data is Map<String, dynamic> && data.isNotEmpty
        ? SurplusAvailability.fromJson(data)
        : null;
  }

  // POST /families/{familyId}/finance/financial-goals/{goalId}/surplus-allocations
  Future<void> allocateSurplusToGoal(
    String goalId, {
    required int periodMonth,
    required int periodYear,
    required double amount,
    required String note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/financial-goals/$goalId/surplus-allocations',
      {
        'periodMonth': periodMonth,
        'periodYear': periodYear,
        'amount': amount,
        'note': note,
      },
    );
    await _fetchGoals();
    notifyListeners();
  }

  // GET /families/{familyId}/finance/model-templates — mẫu mô hình tài chính
  // có sẵn (FIVE_JARS/EIGHTY_TWENTY/CUSTOM), khai báo constant phía BE.
  Future<List<Map<String, dynamic>>> fetchModelTemplates() async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/model-templates',
    );
    return _list(data);
  }

  // ── Mutations: Monthly finance ───────────────────────────────────────────

  Future<void> upsertMonthlyFinance({
    double? expectedIncome,
    double? actualIncome,
    double? expectedPersonalExpense,
    double? actualPersonalExpense,
    double? expectedSharedContribution,
    double? actualSharedContribution,
    String incomeVisibility = 'FAMILY',
    String expenseVisibility = 'PRIVATE',
    String? note,
  }) async {
    final now = DateTime.now();
    final body = {
      'periodMonth': now.month,
      'periodYear': now.year,
      'expectedIncome': ?expectedIncome,
      'actualIncome': ?actualIncome,
      'expectedPersonalExpense': ?expectedPersonalExpense,
      'actualPersonalExpense': ?actualPersonalExpense,
      'expectedSharedContribution': ?expectedSharedContribution,
      'actualSharedContribution': ?actualSharedContribution,
      'incomeVisibility': incomeVisibility,
      'expenseVisibility': expenseVisibility,
      'note': ?note,
    };
    if (monthlyFinance != null) {
      try {
        await ApiClient.instance.put(
          '/families/$_fid/finance/monthly-finances/me',
          body,
        );
      } catch (_) {
        await ApiClient.instance.post(
          '/families/$_fid/finance/monthly-finances/me',
          body,
        );
      }
    } else {
      try {
        await ApiClient.instance.post(
          '/families/$_fid/finance/monthly-finances/me',
          body,
        );
      } catch (_) {
        await ApiClient.instance.put(
          '/families/$_fid/finance/monthly-finances/me',
          body,
        );
      }
    }
    await _fetchMonthlyFinance();
    notifyListeners();
  }

  // ── Monthly summary & xem tài chính member (BE ship 2026-07-13) ─────────

  // GET .../finance/monthly-summary/me?month&year — tổng quan tháng của chính
  // mình: khai báo thu chi + đóng góp quỹ gia đình + đóng góp mục tiêu
  Future<MonthlySummary?> fetchMonthlySummaryMe({
    required int month,
    required int year,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/monthly-summary/me${_qs({'month': month, 'year': year})}',
    );
    return data is Map && data.isNotEmpty
        ? MonthlySummary.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  // GET .../finance/monthly-summary/members/{memberId}?month&year — Manager/
  // Deputy xem tổng quan tháng của member; field private BE trả null sẵn
  Future<MonthlySummary?> fetchMemberMonthlySummary(
    String memberId, {
    required int month,
    required int year,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/monthly-summary/members/$memberId${_qs({'month': month, 'year': year})}',
    );
    return data is Map && data.isNotEmpty
        ? MonthlySummary.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  // GET .../finance/monthly-finances/members/{memberId}?month&year — bản khai
  // báo thô của member (monthly-summary đã bao trùm; giữ cho màn chi tiết riêng).
  // data null = member chưa khai báo tháng đó.
  Future<MonthlyFinance?> fetchMemberMonthlyFinance(
    String memberId, {
    required int month,
    required int year,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/monthly-finances/members/$memberId${_qs({'month': month, 'year': year})}',
    );
    return data is Map && data.isNotEmpty
        ? MonthlyFinance.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  // ── Goal Contribution Plans (workflow Manager confirm → Member submit →
  // Manager approve/reject) ────────────────────────────────────────────────

  // GET .../financial-goals/{goalId}/contribution-suggestions?month&year
  /// Gợi ý đóng góp kèm **căn cứ tính** (bản BE 2026-08-18).
  ///
  /// Nhận được cả response mảng cũ lẫn object mới có metadata — xem
  /// [ContributionSuggestionResult.fromJson].
  Future<ContributionSuggestionResult> fetchContributionSuggestionResult(
    String goalId,
    int month,
    int year,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-suggestions${_qs({'month': month, 'year': year})}',
    );
    return ContributionSuggestionResult.fromJson(data);
  }

  /// Giữ lại cho nơi gọi cũ chỉ cần danh sách. Nơi nào cần cảnh báo hoặc danh
  /// sách bị bỏ qua thì dùng [fetchContributionSuggestionResult].
  Future<List<ContributionSuggestion>> fetchContributionSuggestions(
    String goalId,
    int month,
    int year,
  ) async {
    final result = await fetchContributionSuggestionResult(goalId, month, year);
    return result.suggestions;
  }

  // POST .../financial-goals/{goalId}/contribution-plans/confirm
  Future<void> confirmContributionPlan(
    String goalId, {
    required int periodMonth,
    required int periodYear,
    required DateTime dueDate,
    required List<({String memberId, double plannedAmount})> members,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-plans/confirm',
      {
        'periodMonth': periodMonth,
        'periodYear': periodYear,
        'dueDate': dueDate.toIso8601String().split('T').first,
        'members': members
            .map(
              (m) => {'memberId': m.memberId, 'plannedAmount': m.plannedAmount},
            )
            .toList(),
      },
    );
    notifyListeners();
  }

  // GET .../financial-goals/{goalId}/contribution-plans?month&year
  Future<List<GoalContributionPlan>> fetchContributionPlans(
    String goalId,
    int month,
    int year,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-plans${_qs({'month': month, 'year': year})}',
    );
    return _contributionPlanList(
      data,
    ).map(GoalContributionPlan.fromJson).toList();
  }

  // POST .../financial-goals/{goalId}/contribution-plans/{planId}/submit — thành viên xác nhận đã đóng góp
  Future<void> submitContributionPlan(
    String goalId,
    String planId,
    double amount, {
    String? note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-plans/$planId/submit',
      {'amount': amount, 'note': ?note},
    );
    notifyListeners();
  }

  /// action: approve | reject
  Future<void> reviewContributionPlan(
    String goalId,
    String planId,
    String action, {
    String? note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-plans/$planId/$action',
      {'note': ?note},
    );
    notifyListeners();
  }

  // GET .../financial-goals/{goalId}/contribution-shortage?month&year
  Future<Map<String, dynamic>> fetchContributionShortage(
    String goalId,
    int month,
    int year,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-shortage${_qs({'month': month, 'year': year})}',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Reports (planned-vs-actual) ──────────────────────────────────────────
  // BE không document response schema cho 3 endpoint report này (chỉ có mô
  // tả "planned-vs-actual" trong Swagger) — trả raw Map, màn hình dùng
  // JsonReportView để hiển thị mọi field BE trả về mà không đoán sai tên.

  // GET /families/{familyId}/finance/budget-plans/{budgetPlanId}/report
  Future<Map<String, dynamic>> fetchBudgetPlanReport(String planId) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/budget-plans/$planId/report',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // GET /families/{familyId}/finance/reports/non-essential-spending
  Future<Map<String, dynamic>> fetchNonEssentialSpendingReport({
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/reports/non-essential-spending${_qs({'periodStart': periodStart?.toIso8601String().split('T').first, 'periodEnd': periodEnd?.toIso8601String().split('T').first})}',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // GET /families/{familyId}/finance/reports/budget-goal
  Future<Map<String, dynamic>> fetchBudgetGoalReport({
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/reports/budget-goal${_qs({'periodStart': periodStart?.toIso8601String().split('T').first, 'periodEnd': periodEnd?.toIso8601String().split('T').first})}',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _list(dynamic data) {
    final raw = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : data is Map && data['data'] is List
        ? data['data'] as List
        : <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Contribution-plan list responses have arrived from BE as both a bare
  /// list and nested objects (for example `{ data: { plans: [...] } }`).
  /// Keep this endpoint-specific unwrapping narrow instead of weakening the
  /// generic parser used by unrelated Finance APIs.
  static List<Map<String, dynamic>> _contributionPlanList(dynamic data) {
    final direct = _list(data);
    if (direct.isNotEmpty) return direct;
    if (data is! Map) return const [];

    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('contributionPlanId') ||
        map.containsKey('planId') ||
        (map.containsKey('id') && map.containsKey('plannedAmount'))) {
      return [map];
    }

    for (final key in const [
      'plans',
      'contributionPlans',
      'memberPlans',
      'members',
      'results',
      'data',
    ]) {
      final nested = _contributionPlanList(map[key]);
      if (nested.isNotEmpty) return nested;
    }
    return const [];
  }
}
