import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SubscriptionPlan {
  final String id;
  final String planCode;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String billingCycle;
  final List<String> features;
  final Map<String, bool> featureAccess;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    this.planCode = 'FREE',
    required this.name,
    this.description = '',
    required this.price,
    this.currency = 'VND',
    this.billingCycle = 'YEARLY',
    this.features = const [],
    this.featureAccess = const {},
    this.isActive = true,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) {
    final rawFeatures = j['features'];
    final features = rawFeatures is List
        ? rawFeatures.whereType<String>().toList()
        : <String>[];
    final rawFeatureAccess = j['featureAccess'];
    final featureAccess = rawFeatureAccess is Map
        ? <String, bool>{
            for (final entry in rawFeatureAccess.entries)
              entry.key.toString(): entry.value == true,
          }
        : <String, bool>{};
    return SubscriptionPlan(
      id: j['id']?.toString() ?? '',
      planCode: j['planCode']?.toString() ?? 'FREE',
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      price: _parseDouble(j['annualPrice'] ?? j['price'] ?? j['amount']),
      currency: j['currency']?.toString() ?? 'VND',
      billingCycle: j['billingCycle']?.toString() ?? 'YEARLY',
      features: features,
      featureAccess: featureAccess,
      isActive: j['isActive'] as bool? ?? true,
    );
  }

  bool hasFeature(String key) => featureAccess[key] == true;

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
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final Map<String, bool> featureAccess;

  const FamilySubscription({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.featureAccess = const {},
  });

  factory FamilySubscription.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] as Map<String, dynamic>? ?? {};
    final rawFeatureAccess = plan['featureAccess'] ?? j['featureAccess'];
    final featureAccess = rawFeatureAccess is Map
        ? <String, bool>{
            for (final entry in rawFeatureAccess.entries)
              entry.key.toString(): entry.value == true,
          }
        : <String, bool>{};
    return FamilySubscription(
      id: j['id']?.toString() ?? '',
      planCode: plan['planCode']?.toString() ?? j['planCode']?.toString() ?? 'FREE',
      planName: plan['name']?.toString() ?? j['planName']?.toString() ?? 'Free',
      status: j['status']?.toString() ?? 'ACTIVE',
      currentPeriodStart: j['currentPeriodStart']?.toString(),
      currentPeriodEnd: j['currentPeriodEnd']?.toString(),
      cancelAtPeriodEnd: j['cancelAtPeriodEnd'] as bool? ?? false,
      featureAccess: featureAccess,
    );
  }

  bool hasFeature(String key) => featureAccess[key] == true;
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
