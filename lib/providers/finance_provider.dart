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

  const FinanceJar({
    required this.id,
    required this.name,
    required this.jarCode,
    required this.allocationPercentage,
    required this.isActive,
  });

  factory FinanceJar.fromJson(Map<String, dynamic> j) => FinanceJar(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        jarCode: j['jarCode']?.toString() ?? '',
        allocationPercentage: _money(j['allocationPercentage']),
        isActive: j['isActive'] as bool? ?? true,
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

  const FinanceCategory({
    required this.id,
    required this.name,
    required this.categoryType,
    this.essentialType,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        categoryType: j['categoryType']?.toString() ?? 'EXPENSE',
        essentialType: j['essentialType']?.toString(),
      );
}

class BudgetPlan {
  final String id;
  final String planName;
  final String periodType; // MONTHLY | WEEKLY | ...
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
        'ACTIVE'   => const Color(0xFF16A34A),
        'CLOSED'   => const Color(0xFF6B7280),
        'CANCELED' => const Color(0xFFDC2626),
        _          => const Color(0xFFD97706),
      };

  String get statusLabel => switch (status) {
        'ACTIVE'   => 'Đang áp dụng',
        'CLOSED'   => 'Đã đóng',
        'CANCELED' => 'Đã hủy',
        _          => 'Bản nháp',
      };
}

class FinancialGoal {
  final String id;
  final String goalName;
  final double targetAmount;
  final String? deadline;
  final String status; // ACTIVE | COMPLETED | CANCELED
  final double? progressPercent;

  const FinancialGoal({
    required this.id,
    required this.goalName,
    required this.targetAmount,
    this.deadline,
    required this.status,
    this.progressPercent,
  });

  factory FinancialGoal.fromJson(Map<String, dynamic> j) => FinancialGoal(
        id: j['id']?.toString() ?? '',
        goalName: j['goalName']?.toString() ?? '',
        targetAmount: _money(j['targetAmount']),
        deadline: j['deadline']?.toString(),
        status: j['status']?.toString() ?? 'ACTIVE',
        progressPercent: _moneyNull(j['progressPercent']),
      );

  Color get statusColor => switch (status) {
        'COMPLETED' => const Color(0xFF16A34A),
        'CANCELED'  => const Color(0xFFDC2626),
        _           => const Color(0xFF2563EB),
      };

  String get statusLabel => switch (status) {
        'COMPLETED' => 'Đã đạt mục tiêu',
        'CANCELED'  => 'Đã hủy',
        _           => 'Đang tiết kiệm',
      };
}

class MonthlyFinance {
  final String id;
  final int periodMonth;
  final int periodYear;
  final double? expectedIncome;
  final double? actualIncome;
  final double? expectedPersonalExpense;
  final double? actualPersonalExpense;
  final String incomeVisibility;
  final String expenseVisibility;

  const MonthlyFinance({
    required this.id,
    required this.periodMonth,
    required this.periodYear,
    this.expectedIncome,
    this.actualIncome,
    this.expectedPersonalExpense,
    this.actualPersonalExpense,
    required this.incomeVisibility,
    required this.expenseVisibility,
  });

  factory MonthlyFinance.fromJson(Map<String, dynamic> j) => MonthlyFinance(
        id: j['id']?.toString() ?? '',
        periodMonth: (j['periodMonth'] as num?)?.toInt() ?? 0,
        periodYear: (j['periodYear'] as num?)?.toInt() ?? 0,
        expectedIncome: _moneyNull(j['expectedIncome']),
        actualIncome: _moneyNull(j['actualIncome']),
        expectedPersonalExpense: _moneyNull(j['expectedPersonalExpense']),
        actualPersonalExpense: _moneyNull(j['actualPersonalExpense']),
        incomeVisibility: j['incomeVisibility']?.toString() ?? 'PRIVATE',
        expenseVisibility: j['expenseVisibility']?.toString() ?? 'PRIVATE',
      );
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
    final entries = params.entries.where((e) => e.value != null && e.value.toString().isNotEmpty);
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
    final data = await ApiClient.instance.get('/families/$_fid/finance/categories');
    categories = _list(data).map(FinanceCategory.fromJson).toList();
  }

  Future<void> _fetchBudgetPlans() async {
    final data = await ApiClient.instance.get('/families/$_fid/finance/budget-plans${_qs({'limit': 20})}');
    budgetPlans = _list(data).map(BudgetPlan.fromJson).toList();
  }

  Future<void> _fetchGoals() async {
    final data = await ApiClient.instance.get(
        '/families/$_fid/finance/financial-goals${_qs({'includeProgress': 'true'})}');
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
    } catch (_) {
      monthlyFinance = null;
    }
  }

  // ── Mutations: Model / Jar ───────────────────────────────────────────────

  Future<void> createModel({required String modelType, required String name}) async {
    await ApiClient.instance.post('/families/$_fid/finance/models', {
      'modelType': modelType,
      'name': name,
    });
    await _fetchModels();
    notifyListeners();
  }

  Future<void> activateModel(String modelId) async {
    await ApiClient.instance.patch('/families/$_fid/finance/models/$modelId/activate', {});
    await _fetchModels();
    notifyListeners();
  }

  Future<void> updateJar(String jarId, {double? allocationPercentage, bool? isActive}) async {
    await ApiClient.instance.patch('/families/$_fid/finance/jars/$jarId', {
      'allocationPercentage': ?allocationPercentage,
      'isActive': ?isActive,
    });
    await _fetchJars();
    notifyListeners();
  }

  Future<void> createCategory({
    required String name,
    required String categoryType,
    String? essentialType,
  }) async {
    await ApiClient.instance.post('/families/$_fid/finance/categories', {
      'name': name,
      'categoryType': categoryType,
      'essentialType': ?essentialType,
    });
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
  }) async {
    final res = await ApiClient.instance.post('/families/$_fid/finance/budget-plans', {
      'planName': planName,
      'periodType': periodType,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'expectedSharedIncome': ?expectedSharedIncome,
      'expectedSharedExpense': ?expectedSharedExpense,
    });
    await _fetchBudgetPlans();
    notifyListeners();
    return res.isNotEmpty ? BudgetPlan.fromJson(res) : null;
  }

  /// action: activate | close | cancel
  Future<void> budgetPlanAction(String planId, String action) async {
    await ApiClient.instance.patch('/families/$_fid/finance/budget-plans/$planId/$action', {});
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> addBudgetLine(String planId, {
    required String categoryId,
    required double plannedAmount,
  }) async {
    await ApiClient.instance.post('/families/$_fid/finance/budget-plans/$planId/lines', {
      'categoryId': categoryId,
      'plannedAmount': plannedAmount,
    });
    notifyListeners();
  }

  // ── Mutations: Financial Goal ────────────────────────────────────────────

  Future<FinancialGoal?> createGoal({
    required String goalName,
    required double targetAmount,
    DateTime? deadline,
    double? monthlyContributionTarget,
  }) async {
    final res = await ApiClient.instance.post('/families/$_fid/finance/financial-goals', {
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
    await ApiClient.instance.patch('/families/$_fid/finance/financial-goals/$goalId/cancel', {});
    await _fetchGoals();
    notifyListeners();
  }

  Future<void> contributeToGoal(String goalId, double amount, {String? note}) async {
    await ApiClient.instance.post('/families/$_fid/finance/financial-goals/$goalId/allocations', {
      'amount': amount,
      'note': ?note,
    });
    await _fetchGoals();
    notifyListeners();
  }

  // ── Mutations: Monthly finance ───────────────────────────────────────────

  Future<void> upsertMonthlyFinance({
    double? expectedIncome,
    double? actualIncome,
    double? expectedPersonalExpense,
    double? actualPersonalExpense,
    String incomeVisibility = 'FAMILY',
    String expenseVisibility = 'PRIVATE',
  }) async {
    final now = DateTime.now();
    final body = {
      'periodMonth': now.month,
      'periodYear': now.year,
      'expectedIncome': ?expectedIncome,
      'actualIncome': ?actualIncome,
      'expectedPersonalExpense': ?expectedPersonalExpense,
      'actualPersonalExpense': ?actualPersonalExpense,
      'incomeVisibility': incomeVisibility,
      'expenseVisibility': expenseVisibility,
    };
    if (monthlyFinance != null) {
      await ApiClient.instance.put('/families/$_fid/finance/monthly-finances/me', body);
    } else {
      await ApiClient.instance.post('/families/$_fid/finance/monthly-finances/me', body);
    }
    await _fetchMonthlyFinance();
    notifyListeners();
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
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
