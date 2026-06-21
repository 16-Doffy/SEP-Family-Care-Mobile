import 'package:flutter/material.dart';
import '../services/api_client.dart';

// ─── Helpers ───────────────────────────────────────────────────────────────

double _money(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

double? _moneyNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

// ─── Models ────────────────────────────────────────────────────────────────

class FinanceJar {
  final String id;
  final String name;
  final String jarCode;
  final double allocationPercentage;
  final bool isActive;

  const FinanceJar({required this.id, required this.name, required this.jarCode,
      required this.allocationPercentage, required this.isActive});

  factory FinanceJar.fromJson(Map<String, dynamic> j) => FinanceJar(
        id: j['id']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        jarCode: j['jarCode'] as String? ?? '',
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

  const FinanceModel({required this.id, required this.name,
      required this.modelType, required this.status, this.jars = const []});

  factory FinanceModel.fromJson(Map<String, dynamic> j) => FinanceModel(
        id: j['id']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        modelType: j['modelType'] as String? ?? '',
        status: j['status'] as String? ?? '',
        jars: (j['jars'] as List<dynamic>? ?? [])
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

  const FinanceCategory({required this.id, required this.name,
      required this.categoryType, this.essentialType});

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
        id: j['id']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        categoryType: j['categoryType'] as String? ?? 'EXPENSE',
        essentialType: j['essentialType'] as String?,
      );
}

class BudgetPlan {
  final String id;
  final String planName;
  final String periodType;
  final String periodStart;
  final String periodEnd;
  final double? expectedSharedIncome;
  final double? expectedSharedExpense;
  final String status;

  const BudgetPlan({required this.id, required this.planName,
      required this.periodType, required this.periodStart,
      required this.periodEnd, this.expectedSharedIncome,
      this.expectedSharedExpense, required this.status});

  factory BudgetPlan.fromJson(Map<String, dynamic> j) => BudgetPlan(
        id: j['id']?.toString() ?? '',
        planName: j['planName'] as String? ?? '',
        periodType: j['periodType'] as String? ?? 'MONTHLY',
        periodStart: j['periodStart'] as String? ?? '',
        periodEnd: j['periodEnd'] as String? ?? '',
        expectedSharedIncome: _moneyNull(j['expectedSharedIncome']),
        expectedSharedExpense: _moneyNull(j['expectedSharedExpense']),
        status: j['status'] as String? ?? 'DRAFT',
      );
}

class FinancialGoal {
  final String id;
  final String goalName;
  final double targetAmount;
  final String? deadline;
  final String status;
  final double? progressPercent;

  const FinancialGoal({required this.id, required this.goalName,
      required this.targetAmount, this.deadline, required this.status,
      this.progressPercent});

  factory FinancialGoal.fromJson(Map<String, dynamic> j) => FinancialGoal(
        id: j['id']?.toString() ?? '',
        goalName: j['goalName'] as String? ?? '',
        targetAmount: _money(j['targetAmount']),
        deadline: j['deadline'] as String?,
        status: j['status'] as String? ?? 'ACTIVE',
        progressPercent: _moneyNull(j['progressPercent']),
      );
}

class BudgetAlert {
  final String id;
  final String alertType;
  final String severity;
  final String message;
  final String status;
  final String createdAt;

  const BudgetAlert({required this.id, required this.alertType,
      required this.severity, required this.message,
      required this.status, required this.createdAt});

  factory BudgetAlert.fromJson(Map<String, dynamic> j) => BudgetAlert(
        id: j['id']?.toString() ?? '',
        alertType: j['alertType'] as String? ?? '',
        severity: j['severity'] as String? ?? 'LOW',
        message: j['message'] as String? ?? '',
        status: j['status'] as String? ?? 'NEW',
        createdAt: j['createdAt'] as String? ?? '',
      );
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

  const MonthlyFinance({required this.id, required this.periodMonth,
      required this.periodYear, this.expectedIncome, this.actualIncome,
      this.expectedPersonalExpense, this.actualPersonalExpense,
      required this.incomeVisibility, required this.expenseVisibility});

  factory MonthlyFinance.fromJson(Map<String, dynamic> j) => MonthlyFinance(
        id: j['id']?.toString() ?? '',
        periodMonth: j['periodMonth'] as int? ?? 0,
        periodYear: j['periodYear'] as int? ?? 0,
        expectedIncome: _moneyNull(j['expectedIncome']),
        actualIncome: _moneyNull(j['actualIncome']),
        expectedPersonalExpense: _moneyNull(j['expectedPersonalExpense']),
        actualPersonalExpense: _moneyNull(j['actualPersonalExpense']),
        incomeVisibility: j['incomeVisibility'] as String? ?? 'PRIVATE',
        expenseVisibility: j['expenseVisibility'] as String? ?? 'PRIVATE',
      );
}

// ─── Provider ──────────────────────────────────────────────────────────────

class FinanceProvider extends ChangeNotifier {
  String? _familyId;

  List<FinanceModel> _models = [];
  List<FinanceJar> _jars = [];
  List<FinanceCategory> _categories = [];
  List<BudgetPlan> _budgetPlans = [];
  List<FinancialGoal> _goals = [];
  List<BudgetAlert> _alerts = [];
  MonthlyFinance? _monthlyFinance;
  bool _loading = false;
  String? _error;

  List<FinanceModel>   get models      => _models;
  List<FinanceJar>     get jars        => _jars;
  List<FinanceCategory> get categories => _categories;
  List<BudgetPlan>     get budgetPlans => _budgetPlans;
  List<FinancialGoal>  get goals       => _goals;
  List<BudgetAlert>    get alerts      => _alerts;
  MonthlyFinance?      get monthlyFinance => _monthlyFinance;
  bool   get isLoading => _loading;
  String? get error   => _error;

  FinanceModel? get activeModel =>
      _models.where((m) => m.status == 'ACTIVE').firstOrNull ?? _models.firstOrNull;

  List<BudgetAlert> get newAlerts =>
      _alerts.where((a) => a.status == 'NEW').toList();

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchAll();
    }
  }

  Future<void> fetchAll() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([
        _fetchModels(),
        _fetchJars(),
        _fetchCategories(),
        _fetchBudgetPlans(),
        _fetchGoals(),
        _fetchAlerts(),
        _fetchMonthlyFinance(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchModels() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/models');
    _models = _parseList(data, FinanceModel.fromJson);
  }

  Future<void> _fetchJars() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/jars');
    _jars = _parseList(data, FinanceJar.fromJson);
  }

  Future<void> _fetchCategories() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/categories');
    _categories = _parseList(data, FinanceCategory.fromJson);
  }

  Future<void> _fetchBudgetPlans() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/budget-plans',
        params: {'limit': '20'});
    _budgetPlans = _parseList(data, BudgetPlan.fromJson);
  }

  Future<void> _fetchGoals() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/financial-goals',
        params: {'status': 'ACTIVE', 'includeProgress': 'true'});
    _goals = _parseList(data, FinancialGoal.fromJson);
  }

  Future<void> _fetchAlerts() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/alerts',
        params: {'status': 'NEW', 'limit': '20'});
    _alerts = _parseList(data, BudgetAlert.fromJson);
  }

  Future<void> _fetchMonthlyFinance() async {
    final now = DateTime.now();
    try {
      final data = await ApiClient.instance.get(
        '/families/$_familyId/finance/monthly-finances/me',
        params: {'month': now.month.toString(), 'year': now.year.toString()},
      );
      if (data is Map<String, dynamic>) {
        _monthlyFinance = MonthlyFinance.fromJson(data);
      }
    } catch (_) {
      _monthlyFinance = null;
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> createCategory({required String name, required String categoryType,
      String? essentialType}) async {
    await ApiClient.instance.post('/families/$_familyId/finance/categories', {
      'name': name,
      'categoryType': categoryType,
      if (essentialType != null) 'essentialType': essentialType,
    });
    await _fetchCategories();
    notifyListeners();
  }

  Future<void> createModel({required String modelType, required String name}) async {
    await ApiClient.instance.post('/families/$_familyId/finance/models',
        {'modelType': modelType, 'name': name});
    await _fetchModels();
    notifyListeners();
  }

  Future<void> activateModel(String modelId) async {
    await ApiClient.instance.patch('/families/$_familyId/finance/models/$modelId/activate');
    await _fetchModels();
    notifyListeners();
  }

  Future<void> updateJar(String jarId, {double? allocationPercentage, bool? isActive}) async {
    await ApiClient.instance.patch('/families/$_familyId/finance/jars/$jarId', {
      if (allocationPercentage != null) 'allocationPercentage': allocationPercentage,
      if (isActive != null) 'isActive': isActive,
    });
    await _fetchJars();
    notifyListeners();
  }

  Future<void> createBudgetPlan({required String planName, required String periodType,
      required String periodStart, required String periodEnd,
      double? expectedSharedIncome, double? expectedSharedExpense}) async {
    await ApiClient.instance.post('/families/$_familyId/finance/budget-plans', {
      'planName': planName,
      'periodType': periodType,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      if (expectedSharedIncome != null) 'expectedSharedIncome': expectedSharedIncome,
      if (expectedSharedExpense != null) 'expectedSharedExpense': expectedSharedExpense,
    });
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> budgetPlanAction(String planId, String action) async {
    // action: activate | close | cancel
    await ApiClient.instance.patch('/families/$_familyId/finance/budget-plans/$planId/$action');
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> createGoal({required String goalName, required double targetAmount,
      String? deadline, double? monthlyContributionTarget}) async {
    await ApiClient.instance.post('/families/$_familyId/finance/financial-goals', {
      'goalName': goalName,
      'targetAmount': targetAmount,
      if (deadline != null) 'deadline': deadline,
      if (monthlyContributionTarget != null)
        'monthlyContributionTarget': monthlyContributionTarget,
    });
    await _fetchGoals();
    notifyListeners();
  }

  Future<void> cancelGoal(String goalId) async {
    await ApiClient.instance.patch('/families/$_familyId/finance/financial-goals/$goalId/cancel');
    await _fetchGoals();
    notifyListeners();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await ApiClient.instance.patch('/families/$_familyId/finance/alerts/$alertId/acknowledge');
    await _fetchAlerts();
    notifyListeners();
  }

  Future<void> upsertMonthlyFinance({
    double? expectedIncome, double? actualIncome,
    double? expectedPersonalExpense, double? actualPersonalExpense,
    String incomeVisibility = 'FAMILY', String expenseVisibility = 'PRIVATE',
  }) async {
    final now = DateTime.now();
    final body = {
      'periodMonth': now.month,
      'periodYear': now.year,
      if (expectedIncome != null) 'expectedIncome': expectedIncome,
      if (actualIncome != null) 'actualIncome': actualIncome,
      if (expectedPersonalExpense != null) 'expectedPersonalExpense': expectedPersonalExpense,
      if (actualPersonalExpense != null) 'actualPersonalExpense': actualPersonalExpense,
      'incomeVisibility': incomeVisibility,
      'expenseVisibility': expenseVisibility,
    };
    if (_monthlyFinance != null) {
      await ApiClient.instance.put('/families/$_familyId/finance/monthly-finances/me', body);
    } else {
      await ApiClient.instance.post('/families/$_familyId/finance/monthly-finances/me', body);
    }
    await _fetchMonthlyFinance();
    notifyListeners();
  }

  // ── Finance Reports ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchOverviewReport({int? month, int? year}) async {
    final now = DateTime.now();
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/reports/overview',
      params: {
        'month': (month ?? now.month).toString(),
        'year': (year ?? now.year).toString(),
      },
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> fetchBudgetGoalReport({int? month, int? year}) async {
    final now = DateTime.now();
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/reports/budget-goal',
      params: {
        'month': (month ?? now.month).toString(),
        'year': (year ?? now.year).toString(),
      },
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> fetchNonEssentialReport({int? month, int? year}) async {
    final now = DateTime.now();
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/reports/non-essential-spending',
      params: {
        'month': (month ?? now.month).toString(),
        'year': (year ?? now.year).toString(),
      },
    );
    return data is Map<String, dynamic> ? data : {};
  }

  // ── Budget Plan Lines ──────────────────────────────────────────────────────

  Future<void> createBudgetLine(String planId, {
    required String categoryId,
    required double expectedAmount,
    String? note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_familyId/finance/budget-plans/$planId/lines',
      {
        'categoryId': categoryId,
        'expectedAmount': expectedAmount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> updateBudgetLine(String budgetLineId, {double? expectedAmount, String? note}) async {
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/budget-lines/$budgetLineId',
      {
        if (expectedAmount != null) 'expectedAmount': expectedAmount,
        if (note != null) 'note': note,
      },
    );
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<void> deleteBudgetLine(String budgetLineId) async {
    await ApiClient.instance.delete('/families/$_familyId/finance/budget-lines/$budgetLineId');
    await _fetchBudgetPlans();
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchBudgetPlanReport(String planId) async {
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/budget-plans/$planId/report',
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> updateBudgetPlan(String planId, {
    String? planName,
    double? expectedSharedIncome,
    double? expectedSharedExpense,
  }) async {
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/budget-plans/$planId',
      {
        if (planName != null) 'planName': planName,
        if (expectedSharedIncome != null) 'expectedSharedIncome': expectedSharedIncome,
        if (expectedSharedExpense != null) 'expectedSharedExpense': expectedSharedExpense,
      },
    );
    await _fetchBudgetPlans();
    notifyListeners();
  }

  // ── Financial Goal Allocations ─────────────────────────────────────────────

  Future<void> updateGoal(String goalId, {
    String? goalName,
    double? targetAmount,
    String? deadline,
  }) async {
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/financial-goals/$goalId',
      {
        if (goalName != null) 'goalName': goalName,
        if (targetAmount != null) 'targetAmount': targetAmount,
        if (deadline != null) 'deadline': deadline,
      },
    );
    await _fetchGoals();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchGoalAllocations(String goalId) async {
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/financial-goals/$goalId/allocations',
    );
    return _parseList(data, (e) => e).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchGoalProgress(String goalId) async {
    final data = await ApiClient.instance.get(
      '/families/$_familyId/finance/financial-goals/$goalId/progress',
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> createGoalAllocation(String goalId, {
    required double amount,
    String? note,
  }) async {
    await ApiClient.instance.post(
      '/families/$_familyId/finance/financial-goals/$goalId/allocations',
      {
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await _fetchGoals();
    notifyListeners();
  }

  Future<void> updateGoalAllocation(String allocationId, {double? amount, String? note}) async {
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/goal-allocations/$allocationId',
      {
        if (amount != null) 'amount': amount,
        if (note != null) 'note': note,
      },
    );
    notifyListeners();
  }

  Future<void> deleteGoalAllocation(String allocationId) async {
    await ApiClient.instance.delete('/families/$_familyId/finance/goal-allocations/$allocationId');
    notifyListeners();
  }

  // ── Alert actions ──────────────────────────────────────────────────────────

  Future<void> resolveAlert(String alertId, {String? note}) async {
    await ApiClient.instance.patch(
      '/families/$_familyId/finance/alerts/$alertId/resolve',
      {if (note != null && note.isNotEmpty) 'note': note},
    );
    await _fetchAlerts();
    notifyListeners();
  }

  Future<void> recomputeAlerts() async {
    await ApiClient.instance.post('/families/$_familyId/finance/alerts/recompute', {});
    await _fetchAlerts();
    notifyListeners();
  }

  // ── Jar creation ───────────────────────────────────────────────────────────

  Future<void> createJar({
    required String name,
    required String jarCode,
    double allocationPercentage = 0,
  }) async {
    await ApiClient.instance.post('/families/$_familyId/finance/jars', {
      'name': name,
      'jarCode': jarCode,
      'allocationPercentage': allocationPercentage,
    });
    await _fetchJars();
    notifyListeners();
  }

  // ── Model templates ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchModelTemplates() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/model-templates');
    return _parseList(data, (e) => e).cast<Map<String, dynamic>>();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final list = data is List
        ? data
        : data is Map && data['items'] is List
            ? data['items'] as List
            : <dynamic>[];
    return list.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }

}
