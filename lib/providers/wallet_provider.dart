import 'package:flutter/material.dart';
import '../services/api_client.dart';

class WalletData {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String ownerName;

  const WalletData({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.ownerName,
  });
}

class TransactionData {
  final String id;
  final double amount; // positive = income, negative = expense
  final String description;
  final String createdAt;

  const TransactionData({
    required this.id,
    required this.amount,
    required this.description,
    required this.createdAt,
  });
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

class WalletProvider extends ChangeNotifier {
  String? _familyId;

  List<WalletData> _wallets = [];
  List<TransactionData> _transactions = [];
  bool _loading = false;
  String? _error;

  List<WalletData> get wallets => _wallets;
  List<TransactionData> get transactions => _transactions;
  bool get isLoading => _loading;
  String? get error => _error;

  double get totalBalance => _wallets.fold(0, (s, w) => s + w.balance);

  WalletData? get familyWallet =>
      _firstOrNull(_wallets.where((w) => w.type == 'JOINT')) ??
      _firstOrNull(_wallets);

  List<WalletData> get memberWallets =>
      _wallets.where((w) => w.type != 'JOINT').toList();

  void clear() {
    if (_familyId == null && _wallets.isEmpty && _transactions.isEmpty && !_loading && _error == null) {
      return;
    }
    _familyId = null;
    _wallets = [];
    _transactions = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchWallets();
    }
  }

  Future<void> fetchWallets() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([_fetchOverview(), _fetchEntries()]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchOverview() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/overview');
    if (data is! Map) return;

    final totalIncome  = _parseMoney(data['totalIncome']);
    final totalExpense = _parseMoney(data['totalExpense']);
    final balance      = _parseMoney(data['balance']);

    final ledger = data['ledger'] as Map<String, dynamic>?;
    _wallets = [
      WalletData(
        id: ledger?['id']?.toString() ?? _familyId!,
        name: ledger?['ledgerName']?.toString() ?? 'Sổ chung gia đình',
        type: 'JOINT',
        balance: balance,
        ownerName: '',
      ),
    ];

    // Derive income/expense as synthetic "member wallets" for the overview ring
    if (totalIncome > 0) {
      _wallets.add(WalletData(
        id: 'income',
        name: 'Thu nhập',
        type: 'INCOME',
        balance: totalIncome,
        ownerName: '',
      ));
    }
    if (totalExpense > 0) {
      _wallets.add(WalletData(
        id: 'expense',
        name: 'Chi tiêu',
        type: 'EXPENSE',
        balance: totalExpense,
        ownerName: '',
      ));
    }
  }

  Future<void> _fetchEntries() async {
    final data = await ApiClient.instance.get('/families/$_familyId/finance/ledger/entries');
    final list = data is List
        ? data
        : data is Map && data['items'] is List
            ? data['items'] as List
            : <dynamic>[];

    _transactions = list.whereType<Map>().map((e) {
      final json    = Map<String, dynamic>.from(e);
      final raw     = _parseMoney(json['amount']);
      final type    = json['entryType']?.toString() ?? '';
      final isIncome = type == 'INCOME' || type == 'CONTRIBUTION';
      return TransactionData(
        id: json['id']?.toString() ?? '',
        amount: isIncome ? raw : -raw.abs(),
        description: json['description']?.toString() ?? type,
        createdAt: json['entryDate']?.toString() ?? json['createdAt']?.toString() ?? '',
      );
    }).toList();
  }

  // Tạo giao dịch thu nhập vào sổ chung (thay thế deposit cũ)
  Future<void> deposit(double amount, {String description = 'Nạp tiền'}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/finance/ledger/entries', {
      'entryType': 'INCOME',
      'amount': amount,
      'description': description,
      'entryDate': DateTime.now().toIso8601String().substring(0, 10),
    });
    await fetchWallets();
  }

  // Tạo giao dịch chi tiêu
  Future<void> addExpense(double amount, {required String description, String? categoryId}) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post('/families/$_familyId/finance/ledger/entries', {
      'entryType': 'EXPENSE',
      'amount': amount,
      'description': description,
      'entryDate': DateTime.now().toIso8601String().substring(0, 10),
      if (categoryId != null) 'categoryId': categoryId,
    });
    await fetchWallets();
  }

  static double _parseMoney(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
