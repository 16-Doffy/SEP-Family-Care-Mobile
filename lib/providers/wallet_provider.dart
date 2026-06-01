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

class WalletProvider extends ChangeNotifier {
  List<WalletData> _wallets = [];
  bool _loading = false;
  String? _error;

  List<WalletData> get wallets => _wallets;
  bool get loading => _loading;
  String? get error => _error;
  double get totalBalance => _wallets.fold(0, (sum, w) => sum + w.balance);

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
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deposit(
      String walletId, double amount, String description) async {
    await ApiClient.instance.post('/wallets/deposit', {
      'walletId': walletId,
      'amount': amount,
      'description': description,
    });
    await fetchWallets();
  }

  Future<void> transfer(
    String fromWalletId,
    String toWalletId,
    double amount,
    String description,
  ) async {
    await ApiClient.instance.post('/wallets/transfer', {
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'amount': amount,
      'description': description,
    });
    await fetchWallets();
  }
}
