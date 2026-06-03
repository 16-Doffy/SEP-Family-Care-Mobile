import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

// UC01 — Quản lý gói đăng ký (3 tiers: Free / Family / Premium)
// Theo FAMILY_CARE_SYSTEM.md Section 6

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Mock: gói hiện tại của gia đình
  String _currentPlan = 'FREE';
  bool _loading = false;

  static const _plans = [
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
      id: 'FAMILY',
      name: 'Family',
      price: '99,000 ₫',
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

  Future<void> _subscribe(_PlanData plan) async {
    if (plan.id == _currentPlan) return;
    setState(() => _loading = true);
    // TODO: gọi API /subscriptions/upgrade
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _currentPlan = plan.id;
      _loading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Đã chuyển sang gói ${plan.name} ${plan.emoji}'),
          backgroundColor: plan.color,
        ),
      );
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
                            color: Colors.black.withOpacity(0.06),
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
                              _plans
                                  .firstWhere(
                                      (p) => p.id == _currentPlan)
                                  .name,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
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
                ..._plans.map((plan) => _PlanCard(
                      plan: plan,
                      isCurrent: plan.id == _currentPlan,
                      loading: _loading,
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
  final bool loading;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.loading,
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
              color: Colors.black.withOpacity(isCurrent ? 0.08 : 0.04),
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
                  onPressed: isCurrent ? null : onSubscribe,
                  child: loading && !isCurrent
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: plan.color, strokeWidth: 2))
                      : Text(
                          isCurrent ? '✓ Đang sử dụng' : 'Chọn gói ${plan.name}',
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
