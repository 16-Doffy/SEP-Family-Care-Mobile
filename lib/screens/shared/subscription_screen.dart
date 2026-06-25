import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final familyId = context.read<AuthProvider>().familyId;
      final sub = context.read<SubscriptionProvider>();
      sub.fetchPlans();
      if (familyId != null) sub.fetchFamilySubscription(familyId);
    });
  }

  int _daysRemaining(String? isoDate) {
    if (isoDate == null) return 0;
    final end = DateTime.tryParse(isoDate);
    if (end == null) return 0;
    return end.difference(DateTime.now()).inDays;
  }

  bool _isExpired(FamilySubscription sub) {
    if (sub.status == 'EXPIRED') return true;
    if (sub.currentPeriodEnd != null) {
      final end = DateTime.tryParse(sub.currentPeriodEnd!);
      if (end != null && end.isBefore(DateTime.now())) return true;
    }
    return false;
  }

  Future<void> _upgrade(SubscriptionPlan plan) async {
    final familyId = context.read<AuthProvider>().familyId;
    if (familyId == null) return;
    // Store messenger before async gaps to avoid use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await context.read<SubscriptionProvider>().checkout(
            familyId,
            planCode: plan.planCode,
          );
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          try {
            if (kIsWeb) {
              await launchUrl(uri, webOnlyWindowName: '_blank');
            } else {
              final canLaunch = await canLaunchUrl(uri);
              if (canLaunch) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                throw Exception('Không thể mở trang thanh toán');
              }
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Không thể mở trang thanh toán: ${e.toString()}'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text('URL không hợp lệ: $url'), backgroundColor: AppColors.danger),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không nhận được URL thanh toán từ server'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final current = sub.familySubscription;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Gói đăng ký gia đình',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────
            Expanded(
              child: sub.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        final familyId = context.read<AuthProvider>().familyId;
                        await sub.fetchPlans();
                        if (familyId != null) await sub.fetchFamilySubscription(familyId);
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                        children: [
                          // Banner hết hạn
                          if (current != null && _isExpired(current)) _expiredBanner(),

                          // Card gói hiện tại
                          if (current != null) ...[
                            _currentPlanCard(current),
                            const SizedBox(height: 24),
                          ],

                          // Danh sách các gói
                          if (sub.plans.isNotEmpty) ...[
                            Text(
                              'Các gói đăng ký',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            ...sub.plans.map((plan) => _planCard(plan, current)),
                          ],

                          if (sub.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(sub.error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiredBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gói đăng ký đã hết hạn. Tính năng nâng cao đang bị khoá. Dữ liệu cũ vẫn xem được.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );

  Widget _currentPlanCard(FamilySubscription current) {
    final days = _daysRemaining(current.currentPeriodEnd);
    final expired = _isExpired(current);
    final activeFeatures = current.featureAccess.entries.where((e) => e.value).map((e) => e.key).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Gói hiện tại',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            current.planName,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _statusChip(current.status, expired),
              if (current.currentPeriodEnd != null) ...[
                const SizedBox(width: 8),
                Text(
                  expired
                      ? 'Đã hết hạn'
                      : days > 0
                          ? 'Còn $days ngày'
                          : 'Hết hạn hôm nay',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
            ],
          ),
          if (activeFeatures.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Text(
              'Tính năng đang mở khoá',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: activeFeatures
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(f, style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status, bool expired) {
    final label = switch (status.toUpperCase()) {
      'ACTIVE' => expired ? 'Hết hạn' : 'Đang hoạt động',
      'EXPIRED' => 'Hết hạn',
      'CANCELED' || 'CANCELLED' => 'Đã huỷ',
      'TRIAL' => 'Dùng thử',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: expired ? Colors.red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _planCard(SubscriptionPlan plan, FamilySubscription? current) {
    final isCurrent = current != null && plan.planCode == current.planCode;
    final priceLabel = plan.price == 0
        ? 'Miễn phí'
        : '${_formatPrice(plan.price)} ${plan.currency}/${_cycleLabel(plan.billingCycle)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: isCurrent ? Border.all(color: AppColors.link, width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.link.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Hiện tại', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.link)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(priceLabel, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!isCurrent)
                ElevatedButton(
                  onPressed: () => _upgrade(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Nâng cấp', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(plan.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }

  String _cycleLabel(String cycle) => switch (cycle.toUpperCase()) {
        'MONTHLY' => 'tháng',
        'YEARLY' || 'ANNUAL' => 'năm',
        'WEEKLY' => 'tuần',
        _ => cycle.toLowerCase(),
      };
}
