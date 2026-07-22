import 'package:flutter/material.dart';
import '../services/api_client.dart';

// Đại diện cho 1 jar trong finance model (5 Jars, 80-20, v.v.)
class JarData {
  final String id;
  final String name;
  final String jarCode;
  final double allocationPercent;
  final double balance;

  const JarData({
    required this.id,
    required this.name,
    required this.jarCode,
    required this.allocationPercent,
    required this.balance,
  });

  factory JarData.fromJson(Map<String, dynamic> json) => JarData(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    jarCode: json['jarCode']?.toString() ?? '',
    allocationPercent: _d(json['allocationPercentage']),
    balance: _d(json['balance'] ?? json['currentBalance']),
  );

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// Đại diện cho 1 ledger entry (thu/chi)
class LedgerEntry {
  final String id;
  // entryType thật theo CreateLedgerEntryDto (verify qua Swagger 2026-06-26):
  // INCOME | EXPENSE | CONTRIBUTION | ALLOWANCE | REWARD | SUPPORT | ADJUSTMENT
  // (KHÔNG có TRANSFER_IN/TRANSFER_OUT như comment cũ ghi nhầm)
  final String entryType;
  final double amount;
  final String description;
  final String? note;
  final String entryDate;
  final String? categoryName;
  final String? categoryId;
  final String? sourceType;
  final String status;

  const LedgerEntry({
    required this.id,
    required this.entryType,
    required this.amount,
    required this.description,
    this.note,
    required this.entryDate,
    this.categoryName,
    this.categoryId,
    this.sourceType,
    this.status = 'POSTED',
  });

  // amount từ BE LUÔN dương (đã verify) — dấu +/- phải tự tính theo entryType.
  // EXPENSE/SUPPORT: verify bằng kịch bản thật (duyệt support-request →
  // BE tự tạo ledger entry entryType=SUPPORT, đây chính là tiền Hoh/Dup chi
  // ra cho Mem, phải hiện dấu "-"). CONTRIBUTION/ALLOWANCE/ADJUSTMENT suy
  // luận theo nghiệp vụ (chưa verify được bằng cách tự tạo entry thật —
  // REWARD không tự sinh ledger entry qua flow settlement chuẩn nên cũng
  // chưa verify), cần xác nhận lại với BE nếu sai.
  double get signedAmount {
    const expenseTypes = {'EXPENSE', 'ALLOWANCE', 'REWARD', 'SUPPORT'};
    if (expenseTypes.contains(entryType)) return -amount.abs();
    return amount
        .abs(); // INCOME, CONTRIBUTION, ADJUSTMENT (mặc định coi là thu)
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] is Map ? json['category'] as Map : null;
    return LedgerEntry(
      id: json['id']?.toString() ?? '',
      entryType: json['entryType']?.toString() ?? 'EXPENSE',
      amount: JarData._d(json['amount']),
      description: json['description']?.toString() ?? '',
      note: json['note']?.toString(),
      entryDate:
          json['entryDate']?.toString() ?? json['createdAt']?.toString() ?? '',
      categoryName: cat?['name']?.toString(),
      categoryId: json['categoryId']?.toString() ?? cat?['id']?.toString(),
      sourceType: json['sourceType']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'POSTED',
    );
  }

  // Compat: screens cũ dùng TransactionData
  double get legacyAmount => signedAmount;
  String get legacyDescription => description;
  String get legacyCreatedAt => entryDate;

  /// BE currently appends `Z` while preserving the local wall-clock value
  /// submitted by the app. Treat that value as local for display; converting
  /// it with `toLocal()` would incorrectly add seven hours in Vietnam.
  String get displayEntryDate {
    final localValue = entryDate.endsWith('Z')
        ? entryDate.substring(0, entryDate.length - 1)
        : entryDate;
    final parsed = DateTime.tryParse(localValue);
    if (parsed == null) return entryDate;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }
}

// Alias để không cần sửa các screen cũ ngay
typedef WalletData = OverviewData;
typedef TransactionData = LedgerEntry;

class OverviewData {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String ownerName;

  const OverviewData({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.ownerName,
  });
}

class WalletProvider extends ChangeNotifier {
  OverviewData? _familyOverview;
  List<LedgerEntry> _entries = [];
  List<JarData> _jars = [];
  bool _loading = false;
  String? _error;

  // Monthly aggregates from /finance/overview (more accurate than summing entries)
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;

  // Report data from /finance/reports/overview
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _financeSummary;
  Map<String, dynamic>? _cashFlowSummary;
  Map<String, dynamic>? _categorySpendingSummary;
  Map<String, dynamic>? _memberContributionSummary;
  int _entriesPage = 1;
  final int _entriesLimit = 20;
  int? _entriesTotalPages;
  bool _loadingMoreEntries = false;

  List<OverviewData> get wallets =>
      _familyOverview != null ? [_familyOverview!] : [];
  List<LedgerEntry> get transactions => _entries;
  List<JarData> get jars => _jars;
  bool get isLoading => _loading;
  String? get error => _error;

  double get totalBalance => _familyOverview?.balance ?? 0;
  double get monthlyIncome => _monthlyIncome > 0 ? _monthlyIncome : _calcIncome;
  double get monthlyExpense =>
      _monthlyExpense > 0 ? _monthlyExpense : _calcExpense;
  Map<String, dynamic>? get report => _report;
  Map<String, dynamic>? get financeSummary => _financeSummary;
  Map<String, dynamic>? get cashFlowSummary => _cashFlowSummary;
  Map<String, dynamic>? get categorySpendingSummary => _categorySpendingSummary;
  Map<String, dynamic>? get memberContributionSummary => _memberContributionSummary;
  bool get isLoadingMoreEntries => _loadingMoreEntries;
  bool get hasMoreEntries => _entriesTotalPages == null
      ? _entries.length >= _entriesLimit
      : _entriesPage < _entriesTotalPages!;

  // Fallback: calc from ledger entries using signedAmount (correct sign)
  double get _calcIncome => _entries
      .where((t) => t.signedAmount > 0)
      .fold(0.0, (s, t) => s + t.signedAmount);
  double get _calcExpense => _entries
      .where((t) => t.signedAmount < 0)
      .fold(0.0, (s, t) => s + t.signedAmount.abs());

  OverviewData? get familyWallet => _familyOverview;
  List<OverviewData> get memberWallets => [];

  // GET /families/{familyId}/finance/overview + /finance/ledger/entries
  Future<void> fetchWallets() async {
    final api = ApiClient.instance;
    if (api.familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([
        _fetchOverview(),
        _fetchDashboardSummaries(),
        _fetchEntries(refresh: true),
        _fetchJars(),
        _fetchReport(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchOverview() async {
    final now = DateTime.now();
    final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final end = '${now.year}-${now.month.toString().padLeft(2, '0')}-${_lastDay(now)}';
    dynamic data;
    try {
      // New documented Finance home contract.
      data = await ApiClient.instance.get(
        '${ApiClient.instance.familyPath('/finance/summary')}?periodStart=$start&periodEnd=$end&includeAlerts=true&includeGoals=true&includeBreakdown=true',
      );
      if (data is Map && data['budget'] is Map) {
        _financeSummary = Map<String, dynamic>.from(data);
        final budget = data['budget'] as Map;
        _familyOverview = OverviewData(
          id: ApiClient.instance.familyId ?? '',
          name: 'Quỹ gia đình',
          type: 'JOINT',
          balance: JarData._d(budget['actualBalance']),
          ownerName: '',
        );
        _monthlyIncome = JarData._d(budget['actualIncome']);
        _monthlyExpense = JarData._d(budget['actualExpense']);
        return;
      }
    } catch (_) {
      // Keep compatibility with the existing overview endpoint below.
    }
    data = await ApiClient.instance.get(
      '${ApiClient.instance.familyPath('/finance/overview')}?month=${now.month}&year=${now.year}',
    );
    if (data is Map) {
      _familyOverview = OverviewData(
        id: data['familyId']?.toString() ?? '',
        name: 'Quỹ gia đình',
        type: 'JOINT',
        balance: JarData._d(data['totalBalance'] ?? data['balance'] ?? 0),
        ownerName: data['familyName']?.toString() ?? '',
      );
      // Extract monthly aggregates if API provides them
      _monthlyIncome = JarData._d(
        data['totalIncome'] ?? data['monthlyIncome'] ?? data['income'] ?? 0,
      );
      _monthlyExpense = JarData._d(
        data['totalExpense'] ?? data['monthlyExpense'] ?? data['expense'] ?? 0,
      );
    }
  }

  Future<void> _fetchDashboardSummaries() async {
    final now = DateTime.now();
    final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final end = '${now.year}-${now.month.toString().padLeft(2, '0')}-${_lastDay(now)}';
    final base = ApiClient.instance.familyPath('/finance');
    Future<Map<String, dynamic>?> read(String path) async {
      try {
        final data = await ApiClient.instance.get('$base/$path?periodStart=$start&periodEnd=$end');
        return data is Map ? Map<String, dynamic>.from(data) : null;
      } catch (_) {
        return null;
      }
    }
    final results = await Future.wait([
      read('cash-flow-summary'),
      read('category-spending-summary'),
      read('member-contribution-summary'),
    ]);
    _cashFlowSummary = results[0];
    _categorySpendingSummary = results[1];
    _memberContributionSummary = results[2];
  }

  Future<void> _fetchReport() async {
    try {
      final now = DateTime.now();
      final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final end =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${_lastDay(now)}';
      final data = await ApiClient.instance.get(
        '${ApiClient.instance.familyPath('/finance/reports/overview')}?periodStart=$start&periodEnd=$end&includeBreakdown=true&includeAlerts=true&includeGoals=false',
      );
      if (data is Map) {
        _report = Map<String, dynamic>.from(data);
        // Override monthly totals with report data if more accurate
        final ri = JarData._d(data['totalIncome'] ?? data['income'] ?? 0);
        final re = JarData._d(data['totalExpense'] ?? data['expense'] ?? 0);
        if (ri > 0) _monthlyIncome = ri;
        if (re > 0) _monthlyExpense = re;
      }
    } catch (e) {
      debugPrint('WalletProvider: fetchReport failed: $e');
      _report = null;
    }
  }

  static String _lastDay(DateTime d) {
    final last = DateTime(d.year, d.month + 1, 0);
    return last.day.toString().padLeft(2, '0');
  }

  int? _readTotalPages(dynamic data, int fetchedCount) {
    if (data is! Map) return fetchedCount < _entriesLimit ? _entriesPage : null;
    final meta = data['meta'] is Map
        ? data['meta'] as Map
        : data['pagination'] is Map
        ? data['pagination'] as Map
        : data;
    final totalPages = (meta['totalPages'] as num?)?.toInt();
    if (totalPages != null) return totalPages;
    final total = (meta['total'] as num?)?.toInt();
    if (total != null) return (total / _entriesLimit).ceil().clamp(1, 1 << 30);
    final hasNext = meta['hasNext'] == true || meta['hasNextPage'] == true;
    return hasNext ? null : _entriesPage;
  }

  Future<void> _fetchEntries({bool refresh = true}) async {
    try {
      final now = DateTime.now();
      final nextPage = refresh ? 1 : _entriesPage + 1;
      final data = await ApiClient.instance.get(
        '${ApiClient.instance.familyPath('/finance/ledger/entries')}'
        '?page=$nextPage&limit=$_entriesLimit&month=${now.month}&year=${now.year}',
      );
      final list = data is List
          ? data
          : data is Map && data['items'] is List
          ? data['items'] as List
          : <dynamic>[];
      final parsed = list
          .whereType<Map>()
          .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          // DELETE is a soft delete on BE. Never render or re-count a VOIDED
          // entry even if the list endpoint returns it for audit history.
          .where((entry) => entry.status != 'VOIDED')
          .toList();
      if (refresh) {
        _entries = parsed;
      } else {
        _entries.addAll(parsed);
      }
      _entriesPage = nextPage;
      _entriesTotalPages = _readTotalPages(data, parsed.length);
    } catch (e) {
      debugPrint('WalletProvider: fetchEntries failed: $e');
      if (refresh) _entries = [];
    }
  }

  Future<void> fetchMoreEntries() async {
    if (_loadingMoreEntries || !hasMoreEntries) return;
    _loadingMoreEntries = true;
    notifyListeners();
    try {
      await _fetchEntries(refresh: false);
    } finally {
      _loadingMoreEntries = false;
      notifyListeners();
    }
  }

  Future<void> _fetchJars() async {
    try {
      final data = await ApiClient.instance.get(
        ApiClient.instance.familyPath('/finance/jars'),
      );
      final list = data is List
          ? data
          : data is Map && data['items'] is List
          ? data['items'] as List
          : <dynamic>[];
      _jars = list
          .whereType<Map>()
          .map((e) => JarData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('WalletProvider: fetchJars failed: $e');
      _jars = [];
    }
  }

  // UC27/28 — Ghi nhận thu/chi: POST /finance/ledger/entries
  // CreateLedgerEntryDto: { entryType, amount, description, note?, entryDate, categoryId?, sourceType?, sourceId? }
  Future<void> recordEntry({
    required double amount,
    required String description,
    required bool isIncome,
    String? categoryId,
    String? note,
    String? sourceType,
    String? sourceId,
  }) async {
    await ApiClient.instance
        .post(ApiClient.instance.familyPath('/finance/ledger/entries'), {
          'entryType': isIncome ? 'INCOME' : 'EXPENSE',
          'amount': amount.abs(),
          'description': description,
          'entryDate': DateTime.now().toUtc().toIso8601String(),
          if (note != null && note.isNotEmpty) 'note': note,
          'categoryId': ?categoryId,
          'sourceType': ?sourceType,
          'sourceId': ?sourceId,
        });
    await fetchWallets();
  }

  /// GET /families/{familyId}/finance/ledger/entries/{entryId}
  ///
  /// Danh sách chỉ có dữ liệu rút gọn; lấy chi tiết trước khi mở thao tác
  /// chỉnh sửa/hủy để không làm mất note hoặc các trường BE bổ sung.
  Future<LedgerEntry> fetchEntryDetail(String entryId) async {
    final data = await ApiClient.instance.get(
      ApiClient.instance.familyPath('/finance/ledger/entries/$entryId'),
    );
    if (data is! Map) throw Exception('Không đọc được chi tiết giao dịch');
    return LedgerEntry.fromJson(Map<String, dynamic>.from(data));
  }

  /// PATCH /families/{familyId}/finance/ledger/entries/{entryId}
  Future<void> updateEntry(
    String entryId, {
    required double amount,
    required String description,
    String? categoryId,
    String? note,
  }) async {
    await ApiClient.instance.patch(
      ApiClient.instance.familyPath('/finance/ledger/entries/$entryId'),
      {
        'amount': amount.abs(),
        'description': description,
        'categoryId': ?categoryId,
        'note': ?note,
      },
    );
    await fetchWallets();
  }

  /// DELETE /families/{familyId}/finance/ledger/entries/{entryId}
  /// BE thực hiện soft-delete và chuyển trạng thái giao dịch thành VOIDED.
  Future<void> voidEntry(String entryId) async {
    await ApiClient.instance.delete(
      ApiClient.instance.familyPath('/finance/ledger/entries/$entryId'),
    );
    await fetchWallets();
  }

  // Compat alias cho HomeDashboard (dùng deposit flow)
  Future<void> deposit(double amount, {String description = 'Nạp tiền'}) =>
      recordEntry(amount: amount, description: description, isIncome: true);
}
