import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/finance_period.dart';
import '../providers/finance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_surface_colors.dart';
import '../theme/app_ui_tokens.dart';

/// Một dòng việc trong checklist đầu tháng.
class _ChecklistItem {
  const _ChecklistItem({
    required this.title,
    required this.hint,
    required this.done,
    this.onTap,
  });

  final String title;
  final String hint;
  final bool done;
  final VoidCallback? onTap;
}

/// Checklist "Bắt đầu {tháng}" — gom 5 việc đầu kỳ đang nằm rải ở 5 màn khác
/// nhau, mỗi dòng tự đọc trạng thái thật nên không bao giờ bảo người dùng làm
/// lại việc đã xong.
///
/// Chỉ hiện cho **kỳ hiện tại**: checklist của một tháng đã trôi qua không còn
/// hành động nào hợp lệ (chia quỹ kỳ cũ vẫn được nhưng không phải việc "đầu
/// tháng" nữa).
class MonthStartChecklist extends StatefulWidget {
  const MonthStartChecklist({
    super.key,
    required this.period,
    required this.canManageFinance,
    this.carrySurplus,
    this.onAllocateSurplus,
  });

  final FinancePeriod period;

  /// Manager/Deputy thấy đủ 5 việc; thành viên thường chỉ thấy việc khai báo
  /// của chính mình — các endpoint còn lại BE trả 403.
  final bool canManageFinance;

  /// Số dư kỳ trước, nếu màn cha đã tải sẵn thì truyền vào để khỏi gọi lại.
  final SurplusAvailability? carrySurplus;

  /// Mở luồng phân bổ số dư. Null = ẩn hành động, chỉ hiện trạng thái.
  final VoidCallback? onAllocateSurplus;

  @override
  State<MonthStartChecklist> createState() => _MonthStartChecklistState();
}

class _MonthStartChecklistState extends State<MonthStartChecklist> {
  bool _loading = true;
  bool _declared = false;
  bool _fundAllocated = false;
  SurplusAvailability? _surplus;

  @override
  void initState() {
    super.initState();
    _surplus = widget.carrySurplus;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MonthStartChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.carrySurplus != widget.carrySurplus) {
      _surplus = widget.carrySurplus;
    }
    if (oldWidget.period != widget.period ||
        oldWidget.canManageFinance != widget.canManageFinance) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final finance = context.read<FinanceProvider>();
    final period = widget.period;

    // Mỗi mục tự chịu lỗi riêng: một endpoint hỏng không được làm cả checklist
    // biến mất, vì lúc đó người dùng lại không biết phải làm gì.
    final declared = await _safe(
      () async => await finance.fetchMonthlyFinanceFor(period) != null,
      fallback: _declared,
    );

    var fundAllocated = _fundAllocated;
    var surplus = _surplus;
    if (widget.canManageFinance) {
      fundAllocated = await _safe(
        () async {
          final page = await finance.fetchFundAllocations(
            periodMonth: period.month,
            periodYear: period.year,
            limit: 1,
          );
          return page.items.isNotEmpty;
        },
        fallback: _fundAllocated,
      );
      if (widget.carrySurplus == null) {
        surplus = await _safe(
          () => finance.fetchSurplusAvailability(
            period.previous.month,
            period.previous.year,
          ),
          fallback: _surplus,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _declared = declared;
      _fundAllocated = fundAllocated;
      _surplus = surplus;
      _loading = false;
    });
  }

  Future<T> _safe<T>(
    Future<T> Function() run, {
    required T fallback,
  }) async {
    try {
      return await run();
    } catch (e) {
      debugPrint('MonthStartChecklist: $e');
      return fallback;
    }
  }

  /// Kế hoạch ngân sách ACTIVE phủ kỳ đang xét. So sánh bằng chuỗi ISO ngày:
  /// `periodStart`/`periodEnd` BE trả dạng `2026-08-01`, parse ra DateTime rồi
  /// đối chiếu hai đầu mốc.
  bool _hasActivePlanFor(List<BudgetPlan> plans, FinancePeriod period) {
    for (final plan in plans) {
      if (plan.status != 'ACTIVE') continue;
      final start = DateTime.tryParse(plan.periodStart);
      final end = DateTime.tryParse(plan.periodEnd);
      if (start == null || end == null) continue;
      // Plan quý/năm cũng tính là đã phủ kỳ này.
      if (!start.isAfter(period.end) && !end.isBefore(period.start)) {
        return true;
      }
    }
    return false;
  }

  /// Plan ACTIVE đã hết hạn trước kỳ này — cần đóng để báo cáo không lẫn kỳ.
  List<BudgetPlan> _stalePlans(List<BudgetPlan> plans, FinancePeriod period) {
    return plans.where((plan) {
      if (plan.status != 'ACTIVE') return false;
      final end = DateTime.tryParse(plan.periodEnd);
      return end != null && end.isBefore(period.start);
    }).toList();
  }

  List<_ChecklistItem> _items(BuildContext context) {
    final period = widget.period;
    final items = <_ChecklistItem>[
      _ChecklistItem(
        title: 'Khai báo thu nhập & hạn mức ${period.shortLabel}',
        hint: _declared
            ? 'Đã khai báo'
            : 'Hồ sơ → Tài chính tháng. Chưa khai thì hạn mức hiện “Chưa khai báo”.',
        done: _declared,
        // `context.push` không dispose lại State này khi quay về (go_router
        // giữ nguyên widget cha) nên `_declared` không tự cập nhật — người
        // dùng khai báo xong ở màn Hồ sơ, bấm Lưu, quay lại vẫn thấy mục này
        // chưa tick dù dữ liệu đã lưu thật. `push()` trả về Future hoàn tất
        // đúng lúc pop, nên `await` rồi gọi lại `_load()` là đủ, không cần
        // RouteObserver.
        onTap: () async {
          await context.push('/profile/edit');
          if (!mounted) return;
          _load();
        },
      ),
    ];

    if (!widget.canManageFinance) return items;

    final plans = context.watch<FinanceProvider>().budgetPlans;
    final surplus = _surplus;
    final carryDone = surplus == null || surplus.availableSurplus <= 0;
    final stale = _stalePlans(plans, period);

    items.insert(
      0,
      _ChecklistItem(
        title: 'Kết chuyển số dư ${period.previous.shortLabel}',
        hint: carryDone
            ? 'Không còn số dư chờ phân bổ'
            : 'Còn ${_money(surplus.availableSurplus)} chưa có đích đến',
        done: carryDone,
        onTap: carryDone ? null : widget.onAllocateSurplus,
      ),
    );

    items.addAll([
      _ChecklistItem(
        title: 'Chia quỹ ${period.shortLabel} theo mô hình',
        hint: _fundAllocated
            ? 'Kỳ này đã chia quỹ'
            : 'Mỗi kỳ chỉ chia được một lần — chia lại sẽ bị từ chối.',
        done: _fundAllocated,
        onTap: () => context.push('/manager/finance-model'),
      ),
      _ChecklistItem(
        title: 'Kế hoạch ngân sách cho kỳ này',
        hint: _hasActivePlanFor(plans, period)
            ? 'Đã có kế hoạch đang áp dụng'
            : 'Tạo kế hoạch rồi kích hoạt, nếu không báo cáo kỳ này sẽ trống.',
        done: _hasActivePlanFor(plans, period),
        onTap: () => context.push('/manager/budget-plans'),
      ),
      _ChecklistItem(
        title: 'Đóng kế hoạch kỳ trước',
        hint: stale.isEmpty
            ? 'Không còn kế hoạch quá hạn'
            : '${stale.length} kế hoạch đã hết kỳ nhưng vẫn đang áp dụng',
        done: stale.isEmpty,
        onTap: () => context.push('/manager/budget-plans'),
      ),
    ]);

    return items;
  }

  static String _money(double v) {
    final s = v.round().toString();
    final withSep = s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$withSep ₫';
  }

  @override
  Widget build(BuildContext context) {
    // Kỳ đã qua thì không còn "đầu tháng" nào để bắt đầu.
    if (!widget.period.isCurrent) return const SizedBox.shrink();

    final items = _items(context);
    final remaining = items.where((i) => !i.done).length;

    // Xong hết và đã qua tuần đầu → thôi chiếm chỗ ở đầu màn.
    if (remaining == 0 && DateTime.now().day > 7) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: remaining == 0
              ? AppColors.safe.withValues(alpha: 0.35)
              : AppColors.primary500.withValues(alpha: 0.30),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bắt đầu ${widget.period.label.toLowerCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (_loading)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: remaining == 0
                        ? AppColors.safeLight
                        : AppColors.primary50,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    remaining == 0
                        ? 'Xong'
                        : 'Còn $remaining/${items.length} việc',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: remaining == 0
                          ? AppColors.safeDark
                          : AppColors.primary600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            remaining == 0
                ? 'Kỳ này đã được thiết lập đầy đủ.'
                : 'Những việc cần làm để số liệu kỳ này chạy đúng.',
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in items) _row(context, item),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _ChecklistItem item) {
    final colors = context.colors;
    final tappable = item.onTap != null && !item.done;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: item.done ? AppColors.safe : colors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: item.done ? colors.textMuted : colors.textPrimary,
                      decoration: item.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.hint,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.35,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (tappable)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
