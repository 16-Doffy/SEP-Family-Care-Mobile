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

class FamilySubscription {
  final String id;
  final String planCode;
  final String planName;
  final String status;
  final String? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  const FamilySubscription({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.status,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  factory FamilySubscription.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] as Map<String, dynamic>? ?? {};
    return FamilySubscription(
      id: j['id']?.toString() ?? '',
      planCode: plan['planCode']?.toString() ?? j['planCode']?.toString() ?? 'FREE',
      planName: plan['name']?.toString() ?? j['planName']?.toString() ?? 'Free',
      status: j['status']?.toString() ?? 'ACTIVE',
      currentPeriodEnd: j['currentPeriodEnd']?.toString(),
      cancelAtPeriodEnd: j['cancelAtPeriodEnd'] as bool? ?? false,
    );
  }
}

class SubscriptionProvider extends ChangeNotifier {
  List<SubscriptionPlan> _plans = [];
  FamilySubscription? _familySubscription;
  bool _loading = false;
  String? _error;

  List<SubscriptionPlan> get plans => _plans;
  FamilySubscription? get familySubscription => _familySubscription;
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

  Future<void> fetchFamilySubscription(String familyId) async {
    try {
      final data = await ApiClient.instance.get('/families/$familyId/subscription');
      if (data is Map<String, dynamic>) {
        _familySubscription = FamilySubscription.fromJson(data);
        notifyListeners();
      }
    } catch (_) {
      _familySubscription = null;
    }
  }

  // Returns the Stripe checkout URL string on success
  Future<String?> checkout(String familyId, {required String planCode}) async {
    final data = await ApiClient.instance.post(
      '/families/$familyId/subscription/checkout',
      {'planCode': planCode},
    );
    if (data is Map<String, dynamic>) {
      return data['url']?.toString() ?? data['checkoutUrl']?.toString();
    }
    return null;
  }
}
