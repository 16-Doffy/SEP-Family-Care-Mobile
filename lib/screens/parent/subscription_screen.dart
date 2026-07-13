import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

// UC01 — Quản lý gói đăng ký (3 tiers: Free / Family / Premium)
// Theo FAMILY_CARE_SYSTEM.md Section 6

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // null = đang tải gói hiện tại — KHÔNG mặc định 'FREE' vì màn hình sẽ nháy
  // "Đang dùng" trên gói Free 2-3s rồi mới nhảy sang gói thật (user tưởng
  // subscription bị mất — báo cáo 2026-07-13)
  String? _currentPlan;
  bool _plansLoading = false;
  List<_PlanData> _plans = [];
  // planCode đang gọi checkout — khoá nút để tránh tạo nhiều Stripe session
  // cùng lúc nếu user bấm nhiều lần.
  String? _checkingOutPlan;

  static const _fallbackPlans = [
    _PlanData(
      id: 'FREE',
      name: 'Free',
      price: '0 ₫',
      period: '/tháng',
      emoji: '🏠',
      color: Color(0xFF6B7280),
      gradientColors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
      members: '4 thành viên',
      storage: '1 GB',
      db: 'Shared DB + RLS',
      features: [
        '✅ Task & Wallet cơ bản',
        '✅ Chat nhóm',
        '✅ Thông báo',
        '❌ Calendar',
        '❌ Album ảnh',
        '❌ Theo dõi vị trí',
        '❌ AI Chatbot',
        '❌ Đồng hồ thông minh',
      ],
    ),
    _PlanData(
      id: 'PLUS',
      name: 'Family',
      price: '99,000 ₫',
      priceValue: 99000,
      period: '/tháng',
      emoji: '👨‍👩‍👧‍👦',
      color: Color(0xFF2563EB),
      gradientColors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
      members: '8 thành viên',
      storage: '5 GB',
      db: 'Shared DB + RLS',
      features: [
        '✅ Task & Wallet cơ bản',
        '✅ Chat nhóm',
        '✅ Thông báo',
        '✅ Calendar + màu sự kiện',
        '✅ Album ảnh gia đình',
        '✅ Theo dõi vị trí GPS',
        '❌ AI Chatbot',
        '❌ Đồng hồ thông minh',
      ],
    ),
    _PlanData(
      id: 'PREMIUM',
      name: 'Premium',
      price: '299,000 ₫',
      priceValue: 299000,
      period: '/tháng',
      emoji: '⭐',
      color: Color(0xFF7C3AED),
      gradientColors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
      members: 'Không giới hạn',
      storage: 'Không giới hạn',
      db: 'Docker riêng / gia đình',
      features: [
        '✅ Tất cả tính năng Family',
        '✅ AI Chatbot & dự báo tài chính',
        '✅ Đồng hồ thông minh (SOS)',
        '✅ Docker container độc lập',
        '✅ Ưu tiên hỗ trợ kỹ thuật',
        '✅ Báo cáo nâng cao',
        '✅ Xuất dữ liệu',
        '✅ Sắp ra mắt: AI insights',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _plans = List.from(_fallbackPlans);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPlans();
      _fetchCurrentSubscription();
    });
  }

  // GET /families/{id}/subscription — gói thật gia đình đang dùng, thay cho
  // hardcode 'FREE'. Response: { plan: { planCode, ... }, status, ... }
  Future<void> _fetchCurrentSubscription() async {
    final fid = ApiClient.instance.familyId;
    if (fid == null) {
      setState(() => _currentPlan = 'FREE');
      return;
    }
    try {
      final data = await ApiClient.instance.get('/families/$fid/subscription');
      final plan = data is Map ? data['plan'] : null;
      final planCode = plan is Map ? plan['planCode']?.toString() : null;
      if (mounted) setState(() => _currentPlan = planCode ?? 'FREE');
    } catch (_) {
      // Gia đình chưa có subscription record nào → coi như FREE
      if (mounted) setState(() => _currentPlan = 'FREE');
    }
  }

  Future<void> _fetchPlans() async {
    setState(() => _plansLoading = true);
    try {
      final data = await ApiClient.instance.get('/subscription-plans');
      final list = data is List ? data : (data['items'] as List? ?? data['data'] as List? ?? []);
      if (list.isNotEmpty) {
        final mapped = list.map((p) {
          final code    = p['planCode']?.toString() ?? '';
          final name    = p['name']?.toString() ?? code;
          // BE trả annualPrice/storageLimit dạng string ("180000") — ép as num
          // sẽ throw và rơi về gói cứng, phải tryParse qua toString
          final annual  = double.tryParse(p['annualPrice']?.toString() ?? '') ?? 0;
          final maxM    = p['maxMembers']?.toString() ?? '∞';
          final stoMB   = double.tryParse(p['storageLimit']?.toString() ?? '') ?? 0;
          final stoStr  = stoMB >= 1024
              ? '${(stoMB / 1024).toStringAsFixed(0)} GB'
              : '${stoMB.toStringAsFixed(0)} MB';
          final feat    = p['featureAccess'] is Map ? p['featureAccess'] as Map : const {};
          // Map đúng các key featureAccess BE đang dùng
          final features = <String>[
            '✅ Task & Wallet cơ bản',
            '✅ Chat nhóm & Thông báo',
            if (feat['aiEnabled'] == true) '✅ Tính năng AI',
            if (feat['advancedFinance'] == true) '✅ Tài chính nâng cao',
            if (feat['advancedReports'] == true) '✅ Báo cáo nâng cao',
            if (feat['aiChatbot'] == true) '✅ AI Chatbot',
            if (feat['sos'] == true) '✅ SOS khẩn cấp',
            if (feat['unlimitedStorage'] == true) '✅ Lưu trữ không giới hạn',
            if (feat['maxFamilies'] != null && feat['maxFamilies'] != false)
              '✅ Nhiều gia đình',
          ];

          Color color;
          List<Color> gradient;
          String emoji;
          if (code == 'FREE') {
            color = const Color(0xFF6B7280);
            gradient = const [Color(0xFFF3F4F6), Color(0xFFE5E7EB)];
            emoji = '🏠';
          } else if (code == 'GOLD' || code == 'PREMIUM') {
            color = const Color(0xFFD97706);
            gradient = const [Color(0xFFF59E0B), Color(0xFFFBBF24)];
            emoji = '⭐';
          } else {
            color = const Color(0xFF2563EB);
            gradient = const [Color(0xFF2563EB), Color(0xFF3B82F6)];
            emoji = '👨‍👩‍👧‍👦';
          }

          return _PlanData(
            id: code,
            name: name,
            // BE định giá theo năm (annualPrice) — hiển thị đúng như web admin
            price: annual > 0 ? '${_fmtPrice(annual.round())} ₫' : '0 ₫',
            priceValue: annual,
            period: '/năm',
            emoji: emoji,
            color: color,
            gradientColors: gradient,
            members: maxM == '0' ? 'Không giới hạn' : 'tối đa $maxM thành viên',
            storage: stoStr,
            db: code == 'GOLD' || code == 'PREMIUM' ? 'Docker riêng / gia đình' : 'Shared DB + RLS',
            features: features,
          );
        }).toList();
        if (mounted) setState(() => _plans = mapped);
      }
    } catch (_) {
      // Keep fallback plans
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  // Giá gói đang dùng — 0 nếu không thấy trong danh sách (coi mọi gói là nâng cấp)
  double get _currentPriceValue {
    for (final p in _plans) {
      if (p.id == _currentPlan) return p.priceValue;
    }
    return 0;
  }

  static String _fmtPrice(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // POST /families/{id}/subscription/checkout — body { planCode } trả về
  // link Stripe Checkout, mở bằng trình duyệt ngoài để hoàn tất thanh toán.
  // BE redirect lại app qua deep link sau khi Stripe xử lý xong (ngoài scope
  // màn này — xem mục Subscription/Stripe trong BE_API_REQUESTS.md).
  //
  // ⚠️ Response checkout chưa có schema công khai trên Swagger — field chứa
  // URL được đoán theo convention phổ biến (`checkoutUrl`/`url`), thử nhiều
  // tên trước khi báo lỗi. Cần xác nhận lại field thật khi test tay 1 lần.
  Future<void> _subscribe(_PlanData plan) async {
    // _currentPlan == null: chưa biết gói hiện tại — đừng cho checkout kẻo
    // nâng/hạ nhầm chính gói đang dùng
    if (_currentPlan == null || plan.id == _currentPlan || _checkingOutPlan != null) {
      return;
    }
    final fid = ApiClient.instance.familyId;
    if (fid == null) return;

    // Hạ gói → xác nhận trước vì gia đình sẽ mất quyền lợi của gói cao hơn
    if (plan.priceValue < _currentPriceValue) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text('Hạ xuống ${plan.name}?',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
              'Gia đình sẽ mất các quyền lợi của gói hiện tại (thành viên, dung lượng, tính năng nâng cao). Bạn chắc chứ?',
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Giữ gói hiện tại')),
            TextButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Hạ gói', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _checkingOutPlan = plan.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ApiClient.instance.post(
        '/families/$fid/subscription/checkout',
        {'planCode': plan.id},
      );
      final url = data['checkoutUrl']?.toString();
      if (url == null) {
        throw Exception('Không lấy được link thanh toán từ server');
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Không mở được trang thanh toán');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _checkingOutPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20)
                      ]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Gói đăng ký',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 40),
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ── Gói hiện tại ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFBAE6FD), width: 1.5)),
                  child: Row(children: [
                    const Text('📋',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gói hiện tại của gia đình',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted)),
                            Text(
                              _currentPlan == null
                                  ? 'Đang tải...'
                                  : _plans.any((p) => p.id == _currentPlan)
                                      ? _plans.firstWhere((p) => p.id == _currentPlan).name
                                      : _currentPlan!,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _currentPlan == null
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary),
                            ),
                          ]),
                    ),
                    if (_currentPlan == null)
                      const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('Đang dùng',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB))),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),

                Text('Chọn gói phù hợp',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    'Không giới hạn thành viên · Hủy bất cứ lúc nào',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 16),

                // ── Plan cards ────────────────────────────────
                if (_plansLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                ..._plans.map((plan) => _PlanCard(
                      plan: plan,
                      isCurrent: plan.id == _currentPlan,
                      isDowngrade: plan.priceValue < _currentPriceValue,
                      isCheckingOut: _checkingOutPlan == plan.id,
                      onSubscribe: () => _subscribe(plan),
                    )),

                const SizedBox(height: 16),

                // ── Architecture note ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8F5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFDDD6FE), width: 1)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🔒  Bảo mật dữ liệu',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                            'Free & Family: Dữ liệu được bảo vệ bằng Row-Level Security (RLS) — mỗi gia đình chỉ thấy dữ liệu của mình.\n\nPremium: Docker container riêng biệt cho từng gia đình — hoàn toàn độc lập.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ]),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool isCurrent;
  // Gói rẻ hơn gói đang dùng → CTA là "Hạ xuống" thay vì "Nâng cấp"
  final bool isDowngrade;
  final bool isCheckingOut;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    this.isDowngrade = false,
    this.isCheckingOut = false,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: isCurrent
            ? Border.all(color: plan.color, width: 2)
            : Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isCurrent ? 0.08 : 0.04),
              blurRadius: 24,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Plan header gradient ─────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: plan.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(children: [
            Text(plan.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.name,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: plan.id == 'FREE'
                            ? AppColors.textPrimary
                            : Colors.white)),
                Text('${plan.members} · ${plan.storage}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: plan.id == 'FREE'
                            ? AppColors.textMuted
                            : Colors.white70)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(plan.price,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: plan.id == 'FREE'
                          ? AppColors.textPrimary
                          : Colors.white)),
              Text(plan.period,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: plan.id == 'FREE'
                          ? AppColors.textMuted
                          : Colors.white70)),
            ]),
          ]),
        ),

        // ── Features ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...plan.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(f,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: f.startsWith('✅')
                              ? AppColors.textPrimary
                              : AppColors.textMuted)),
                ),
              ),
              const SizedBox(height: 16),

              // ── CTA Button ───────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isCurrent ? const Color(0xFFF3F4F6) : plan.color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isCurrent || isCheckingOut) ? null : onSubscribe,
                  child: isCheckingOut
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: plan.id == 'FREE' ? AppColors.textPrimary : Colors.white),
                        )
                      : Text(
                          isCurrent
                              ? '✓ Đang sử dụng'
                              : '${isDowngrade ? 'Hạ xuống' : 'Nâng cấp'} ${plan.name}',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? AppColors.textMuted
                                  : plan.id == 'FREE'
                                      ? AppColors.textPrimary
                                      : Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PlanData {
  final String id;
  final String name;
  final String price;
  // Giá dạng số để so sánh nâng/hạ gói (price chỉ là chuỗi hiển thị)
  final double priceValue;
  final String period;
  final String emoji;
  final Color color;
  final List<Color> gradientColors;
  final String members;
  final String storage;
  final String db;
  final List<String> features;

  const _PlanData({
    required this.id,
    required this.name,
    required this.price,
    this.priceValue = 0,
    required this.period,
    required this.emoji,
    required this.color,
    required this.gradientColors,
    required this.members,
    required this.storage,
    required this.db,
    required this.features,
  });
}
