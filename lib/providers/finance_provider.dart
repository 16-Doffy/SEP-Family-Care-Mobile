import 'package:flutter/material.dart';
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
class ContributionSuggestion {
  final String memberId;
  final String memberName;
  final double suggestedAmount;
  final Map<String, dynamic> raw;

  const ContributionSuggestion({
    required this.memberId,
    required this.memberName,
    required this.suggestedAmount,
    required this.raw,
  });

  factory ContributionSuggestion.fromJson(Map<String, dynamic> j) {
    final memberMap = j['member'] is Map
        ? Map<String, dynamic>.from(j['member'] as Map)
        : j['user'] is Map
        ? Map<String, dynamic>.from(j['user'] as Map)
        : null;
    return ContributionSuggestion(
      memberId:
          j['memberId']?.toString() ??
          memberMap?['id']?.toString() ??
          memberMap?['userId']?.toString() ??
          '',
      memberName:
          memberMap?['fullName']?.toString() ??
          memberMap?['displayName']?.toString() ??
          j['memberName']?.toString() ??
          'Thành viên',
      suggestedAmount: _money(
        j['suggestedAmount'] ?? j['amount'] ?? j['plannedAmount'],
      ),
      raw: j,
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

  List<FinancialGoal> get activeGoals =>
      goals.where((g) => g.status == 'ACTIVE').toList();

  String get _fid {
    final fid = ApiClient.instance.familyId;
    if (fid == null) throw Exception('Chưa có gia đình');
    return fid;
  }

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

  Future<void> _fetchMonthlyFinance() async {
    final now = DateTime.now();
    try {
      final data = await ApiClient.instance.get(
        '/families/$_fid/finance/monthly-finances/me${_qs({'month': now.month, 'year': now.year})}',
      );
      monthlyFinance = data is Map<String, dynamic> && data.isNotEmpty
          ? MonthlyFinance.fromJson(data)
          : null;
    } catch (e) {
      debugPrint('FinanceProvider: fetchMonthlyFinance failed: $e');
      monthlyFinance = null;
    }
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
    final res = await ApiClient.instance
        .post('/families/$_fid/finance/budget-plans', {
          'planName': planName,
          'periodType': periodType,
          'periodStart': periodStart.toIso8601String(),
          'periodEnd': periodEnd.toIso8601String(),
          'expectedSharedIncome': ?expectedSharedIncome,
          'expectedSharedExpense': ?expectedSharedExpense,
          'lines': lines,
        });

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
    await ApiClient.instance
        .patch('/families/$_fid/finance/budget-plans/$planId', {
          'planName': ?planName,
          'periodType': ?periodType,
          'periodStart': ?periodStart?.toIso8601String(),
          'periodEnd': ?periodEnd?.toIso8601String(),
          'expectedSharedIncome': ?expectedSharedIncome,
          'expectedSharedExpense': ?expectedSharedExpense,
        });
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
  Future<List<ContributionSuggestion>> fetchContributionSuggestions(
    String goalId,
    int month,
    int year,
  ) async {
    final data = await ApiClient.instance.get(
      '/families/$_fid/finance/financial-goals/$goalId/contribution-suggestions${_qs({'month': month, 'year': year})}',
    );
    return _list(data).map(ContributionSuggestion.fromJson).toList();
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
