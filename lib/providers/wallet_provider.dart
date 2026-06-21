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
        id:                json['id']?.toString() ?? '',
        name:              json['name']?.toString() ?? '',
        jarCode:           json['jarCode']?.toString() ?? '',
        allocationPercent: _d(json['allocationPercentage']),
        balance:           _d(json['balance'] ?? json['currentBalance']),
      );

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// Đại diện cho 1 ledger entry (thu/chi)
class LedgerEntry {
  final String id;
  final String entryType; // INCOME | EXPENSE | TRANSFER_IN | TRANSFER_OUT
  final double amount;
  final String description;
  final String? note;
  final String entryDate;
  final String? categoryName;
  final String? sourceType;

  const LedgerEntry({
    required this.id,
    required this.entryType,
    required this.amount,
    required this.description,
    this.note,
    required this.entryDate,
    this.categoryName,
    this.sourceType,
  });

  // amount dương = thu, âm = chi (tính theo entryType)
  double get signedAmount {
    if (entryType == 'EXPENSE' || entryType == 'TRANSFER_OUT') return -amount.abs();
    return amount.abs();
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] is Map ? json['category'] as Map : null;
    return LedgerEntry(
      id:           json['id']?.toString() ?? '',
      entryType:    json['entryType']?.toString() ?? 'EXPENSE',
      amount:       JarData._d(json['amount']),
      description:  json['description']?.toString() ?? '',
      note:         json['note']?.toString(),
      entryDate:    json['entryDate']?.toString() ?? json['createdAt']?.toString() ?? '',
      categoryName: cat?['name']?.toString(),
      sourceType:   json['sourceType']?.toString(),
    );
  }

  // Compat: screens cũ dùng TransactionData
  double get legacyAmount => signedAmount;
  String get legacyDescription => description;
  String get legacyCreatedAt => entryDate;
}

// Alias để không cần sửa các screen cũ ngay
typedef WalletData        = OverviewData;
typedef TransactionData   = LedgerEntry;

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
  double _monthlyIncome  = 0;
  double _monthlyExpense = 0;

  // Report data from /finance/reports/overview
  Map<String, dynamic>? _report;

  List<OverviewData> get wallets =>
      _familyOverview != null ? [_familyOverview!] : [];
  List<LedgerEntry> get transactions => _entries;
  List<JarData> get jars => _jars;
  bool get isLoading => _loading;
  String? get error => _error;

  double get totalBalance   => _familyOverview?.balance ?? 0;
  double get monthlyIncome  => _monthlyIncome  > 0 ? _monthlyIncome  : _calcIncome;
  double get monthlyExpense => _monthlyExpense > 0 ? _monthlyExpense : _calcExpense;
  Map<String, dynamic>? get report => _report;

  // Fallback: calc from ledger entries using signedAmount (correct sign)
  double get _calcIncome  => _entries.where((t) => t.signedAmount > 0).fold(0.0, (s, t) => s + t.signedAmount);
  double get _calcExpense => _entries.where((t) => t.signedAmount < 0).fold(0.0, (s, t) => s + t.signedAmount.abs());

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
        _fetchEntries(),
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
    final data = await ApiClient.instance.get(
      '${ApiClient.instance.familyPath('/finance/overview')}?month=${now.month}&year=${now.year}',
    );
    if (data is Map) {
      _familyOverview = OverviewData(
        id:        data['familyId']?.toString() ?? '',
        name:      'Quỹ gia đình',
        type:      'JOINT',
        balance:   JarData._d(data['totalBalance'] ?? data['balance'] ?? 0),
        ownerName: data['familyName']?.toString() ?? '',
      );
      // Extract monthly aggregates if API provides them
      _monthlyIncome  = JarData._d(data['totalIncome']  ?? data['monthlyIncome']  ?? data['income']  ?? 0);
      _monthlyExpense = JarData._d(data['totalExpense'] ?? data['monthlyExpense'] ?? data['expense'] ?? 0);
    }
  }

  Future<void> _fetchReport() async {
    try {
      final now   = DateTime.now();
      final start = '${now.year}-${now.month.toString().padLeft(2,'0')}-01';
      final end   = '${now.year}-${now.month.toString().padLeft(2,'0')}-${_lastDay(now)}';
      final data  = await ApiClient.instance.get(
        '${ApiClient.instance.familyPath('/finance/reports/overview')}?periodStart=$start&periodEnd=$end&includeBreakdown=true&includeAlerts=true&includeGoals=false',
      );
      if (data is Map) {
        _report = Map<String, dynamic>.from(data);
        // Override monthly totals with report data if more accurate
        final ri = JarData._d(data['totalIncome']  ?? data['income']  ?? 0);
        final re = JarData._d(data['totalExpense'] ?? data['expense'] ?? 0);
        if (ri > 0) _monthlyIncome  = ri;
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

  Future<void> _fetchEntries() async {
    try {
      final data = await ApiClient.instance.get(
        ApiClient.instance.familyPath('/finance/ledger/entries'),
      );
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : <dynamic>[];
      _entries = list
          .whereType<Map>()
          .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('WalletProvider: fetchEntries failed: $e');
      _entries = [];
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
    await ApiClient.instance.post(
      ApiClient.instance.familyPath('/finance/ledger/entries'),
      {
        'entryType':   isIncome ? 'INCOME' : 'EXPENSE',
        'amount':      amount.abs(),
        'description': description,
        'entryDate':   DateTime.now().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        'categoryId': ?categoryId,
        'sourceType': ?sourceType,
        'sourceId':   ?sourceId,
      },
    );
    await fetchWallets();
  }

  // Compat alias cho HomeDashboard (dùng deposit flow)
  Future<void> deposit(double amount, {String description = 'Nạp tiền'}) =>
      recordEntry(amount: amount, description: description, isIncome: true);
}
