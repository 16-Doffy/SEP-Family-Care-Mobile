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

  factory WalletData.fromJson(Map<String, dynamic> json) => WalletData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ??
            json['type']?.toString() ??
            'Ví gia đình',
        type: json['type']?.toString() ?? '',
        balance: _parseDouble(json['balance']),
        ownerName: json['owner'] is Map
            ? (json['owner'] as Map)['displayName']?.toString() ?? ''
            : '',
      );

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
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

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    final raw = WalletData._parseDouble(json['amount']);
    final type = json['type']?.toString() ?? '';
    // Nếu backend dùng type field thay vì signed amount
    final signed = type == 'EXPENSE' || type == 'TRANSFER_OUT' ? -raw.abs() : raw;
    return TransactionData(
      id: json['id']?.toString() ?? '',
      amount: signed,
      description: json['description']?.toString() ??
          json['reason']?.toString() ??
          type,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class WalletProvider extends ChangeNotifier {
  List<WalletData> _wallets = [];
  List<TransactionData> _transactions = [];
  bool _loading = false;
  String? _error;

  List<WalletData> get wallets => _wallets;
  List<TransactionData> get transactions => _transactions;
  bool get isLoading => _loading;
  String? get error => _error;

  double get totalBalance => _wallets.fold(0, (s, w) => s + w.balance);

  // Ví chung gia đình (JOINT) hoặc ví đầu tiên
  WalletData? get familyWallet =>
      _wallets.where((w) => w.type == 'JOINT').firstOrNull ??
      _wallets.firstOrNull;

  // Ví thành viên cá nhân (không phải JOINT)
  List<WalletData> get memberWallets =>
      _wallets.where((w) => w.type != 'JOINT').toList();

  Future<void> fetchWallets() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/wallets');
      final list = data is List
          ? data
          : data is Map && data['wallets'] is List
              ? data['wallets'] as List
              : <dynamic>[];
      _wallets = list
          .whereType<Map>()
          .map((e) => WalletData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Fetch transactions sau khi có wallets
      await _fetchTransactions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final data = await ApiClient.instance.get('/wallets/transactions');
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : data is Map && data['transactions'] is List
                  ? data['transactions'] as List
                  : <dynamic>[];
      _transactions = list
          .whereType<Map>()
          .map((e) => TransactionData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // Graceful fallback — endpoint chưa có hoặc lỗi, giữ list rỗng
      _transactions = [];
    }
  }

  // Nạp tiền vào familyWallet
  Future<void> deposit(double amount, {String description = 'Nạp tiền'}) async {
    final wallet = familyWallet;
    if (wallet == null) throw Exception('Không có ví gia đình');
    await ApiClient.instance.post('/wallets/deposit', {
      'walletId': wallet.id,
      'amount': amount,
      'description': description,
    });
    await fetchWallets();
  }

  // Chuyển tiền từ familyWallet sang ví khác
  Future<void> transfer(
      String toWalletId, double amount, String description) async {
    final wallet = familyWallet;
    if (wallet == null) throw Exception('Không có ví nguồn');
    await ApiClient.instance.post('/wallets/transfer', {
      'fromWalletId': wallet.id,
      'toWalletId': toWalletId,
      'amount': amount,
      'description': description,
    });
    await fetchWallets();
  }

  // UC27 — Ghi nhận thu/chi cá nhân thực tế
  // UC28 — Ghi nhận chi phí chung gia đình
  Future<void> recordTransaction({
    required double amount,    // dương = thu, âm = chi
    required String description,
    String category = '',
    bool isShared = false,     // true = UC28 (chi phí chung)
  }) async {
    await ApiClient.instance.post('/wallets/transactions', {
      'amount': amount,
      'description': description,
      if (category.isNotEmpty) 'category': category,
      'type': amount >= 0 ? 'INCOME' : 'EXPENSE',
      'scope': isShared ? 'SHARED' : 'PERSONAL',
    });
    await fetchWallets();
  }

  // UC-FIN-01/02 — Lưu mô hình tài chính + cấu hình jars
  Future<void> saveFinanceModel(
      String model, List<Map<String, dynamic>> jars) async {
    await ApiClient.instance.post('/finance/model', {
      'model': model,
      'jars': jars,
    });
  }
}
