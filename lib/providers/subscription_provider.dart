import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String billingCycle;
  final List<String> features;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.currency = 'VND',
    this.billingCycle = 'MONTHLY',
    this.features = const [],
    this.isActive = true,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) {
    final rawFeatures = j['features'];
    final features = rawFeatures is List
        ? rawFeatures.whereType<String>().toList()
        : <String>[];
    return SubscriptionPlan(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      price: _parseDouble(j['price'] ?? j['amount']),
      currency: j['currency']?.toString() ?? 'VND',
      billingCycle: j['billingCycle']?.toString() ?? 'MONTHLY',
      features: features,
      isActive: j['isActive'] as bool? ?? true,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class SubscriptionProvider extends ChangeNotifier {
  List<SubscriptionPlan> _plans = [];
  bool _loading = false;
  String? _error;

  List<SubscriptionPlan> get plans => _plans;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> fetchPlans() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/subscription-plans');
      final list = data is List
          ? data
          : data is Map && data['items'] is List
              ? data['items'] as List
              : data is Map && data['data'] is List
                  ? data['data'] as List
                  : <dynamic>[];
      _plans = list
          .whereType<Map>()
          .map((e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
