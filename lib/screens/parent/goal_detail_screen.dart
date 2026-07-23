import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/money_input.dart';

// GET .../financial-goals/{id} trả cả goal + progress; không gọi endpoint
// /progress vì BE đã đánh dấu deprecated. Các allocations dùng GET/PATCH/DELETE.
class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  bool _loading = true;
  String? _error;
  FinancialGoal? _goal;
  Map<String, dynamic>? _progress;
  List<GoalAllocation> _allocations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<FinanceProvider>();
    try {
      final results = await Future.wait([
        provider.fetchGoalDetailWithProgress(widget.goalId),
        provider.fetchGoalAllocations(widget.goalId),
      ]);
      if (mounted) {
        final detail = results[0] as (FinancialGoal, Map<String, dynamic>);
        setState(() {
          _goal = detail.$1;
          _progress = detail.$2;
          _allocations = results[1] as List<GoalAllocation>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
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
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        goal?.goalName ?? 'Chi tiết mục tiêu',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (goal != null)
                    GestureDetector(
                      onTap: () => _showEditGoalSheet(context, goal),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.link,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (goal == null)
              const Expanded(child: SizedBox())
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _summaryCard(goal, _progress),
                      const SizedBox(height: 16),
                      _sectionLabel('Tiến độ chi tiết'),
                      _progressCard(goal, _progress),
                      const SizedBox(height: 16),
                      _sectionLabel('Lịch sử đóng góp'),
                      if (_allocations.isEmpty)
                        _card(
                          child: Text(
                            'Chưa có lần góp nào',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      else
                        ..._allocations.map((a) => _allocationCard(context, a)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _summaryCard(FinancialGoal goal, Map<String, dynamic>? rawProgress) {
    final pct = ((goal.progressPercent ?? 0) / 100).clamp(0.0, 1.0);
    final nestedProgress = _asMap(rawProgress?['progress']);
    final currentAmount =
        goal.currentAmount ?? _number(nestedProgress['currentAmount']);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.goalName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: goal.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  goal.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: goal.statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (goal.deadline != null) ...[
            const SizedBox(height: 4),
            Text(
              'Hạn: ${_formatDate(goal.deadline!)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(goal.statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã góp ${_fmt(currentAmount)} / ${_fmt(goal.targetAmount)} · ${(pct * 100).round()}%',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          if (goal.canContribute) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showContributeSheet(context, goal),
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Góp tiền cá nhân (Tiền túi)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Nộp từ nguồn cá nhân của bạn vào quỹ & mục tiêu',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (context.read<AuthProvider>().user?.isAdministrative ==
                true) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.link,
                    side: const BorderSide(color: AppColors.link, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showSurplusAllocationSheet(context, goal),
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                  ),
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Trích từ số dư quỹ chung',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Dùng tiền dư thừa tích lũy của tháng',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Widget _progressCard(FinancialGoal goal, Map<String, dynamic>? raw) {
    final root = raw ?? const <String, dynamic>{};
    final progress = _asMap(root['progress']);
    final values = progress.isEmpty ? root : progress;
    final current = _number(values['currentAmount']);
    final remaining = _number(values['remainingAmount']);
    final percent = _number(values['progressPercent']);
    final days = values['daysRemaining'];
    final months = values['monthsRemaining'];
    final recommended = _number(values['recommendedMonthlyContribution']);

    Widget row(String label, String value, {Color? valueColor}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Đã góp', _fmt(current), valueColor: AppColors.income),
          row('Mục tiêu', _fmt(goal.targetAmount)),
          row('Còn thiếu', _fmt(remaining)),
          row('Tiến độ', '${percent.round()}%'),
          if (goal.deadline != null)
            row('Hạn hoàn thành', _formatDate(goal.deadline!)),
          if (days != null) row('Số ngày còn lại', '$days ngày'),
          if (months != null) row('Số tháng còn lại', '$months tháng'),
          if (!goal.isAchieved && recommended > 0)
            row(
              'Nên góp mỗi tháng',
              _fmt(recommended),
              valueColor: AppColors.link,
            ),
          const Divider(height: 20),
          row('Tình trạng', goal.statusLabel, valueColor: goal.statusColor),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showContributeSheet(BuildContext context, FinancialGoal goal) {
    final amountCtrl = TextEditingController();
    bool submitting = false;
    bool linkToMonthlyPlan = true;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Góp tiền cá nhân vào mục tiêu',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                goal.goalName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tiền nạp từ tài khoản cá nhân của bạn sẽ tăng Tổng quỹ gia đình và tăng số tiền tiết kiệm của mục tiêu.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _inputBox(
                amountCtrl,
                'Số tiền góp (₫)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () =>
                    setSheet(() => linkToMonthlyPlan = !linkToMonthlyPlan),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: linkToMonthlyPlan,
                        onChanged: (v) =>
                            setSheet(() => linkToMonthlyPlan = v ?? true),
                        activeColor: AppColors.link,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cập nhật vào Kế hoạch đóng góp tháng này của tôi',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(
                  sheetError!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = parseMoneyInput(amountCtrl.text);
                          if (amount <= 0) {
                            setSheet(
                              () => sheetError = 'Nhập số tiền góp lớn hơn 0.',
                            );
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            final fp = context.read<FinanceProvider>();
                            await fp.contributeToGoal(goal.id, amount);

                            // Tự động ghi nhận vào Kế hoạch tháng của tôi nếu có
                            if (linkToMonthlyPlan) {
                              try {
                                final now = DateTime.now();
                                final plans = await fp.fetchContributionPlans(
                                  goal.id,
                                  now.month,
                                  now.year,
                                );
                                final user = context.read<AuthProvider>().user;
                                final myMemberId = context
                                    .read<FamilyProvider>()
                                    .members
                                    .where(
                                      (m) =>
                                          m.userId == user?.id ||
                                          m.id == user?.id,
                                    )
                                    .firstOrNull
                                    ?.id;
                                final myUserId = user?.id;
                                final myPlan = plans
                                    .where(
                                      (p) =>
                                          (p.memberId == myMemberId ||
                                              p.memberId == myUserId) &&
                                          (p.isPending ||
                                              p.isRejected ||
                                              p.isSubmitted),
                                    )
                                    .firstOrNull;

                                if (myPlan != null) {
                                  await fp.submitContributionPlan(
                                    goal.id,
                                    myPlan.id,
                                    amount,
                                  );
                                  if (context
                                          .read<AuthProvider>()
                                          .user
                                          ?.canManageFinance ==
                                      true) {
                                    await fp.reviewContributionPlan(
                                      goal.id,
                                      myPlan.id,
                                      'approve',
                                    );
                                  }
                                }
                              } catch (_) {}
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            setSheet(() {
                              submitting = false;
                              final message = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              sheetError =
                                  message.contains(
                                    'vượt quá số tiền còn có thể phân bổ',
                                  )
                                  ? 'Khoản góp này gắn với giao dịch nguồn. Số tiền sửa không thể vượt quá số tiền còn lại của giao dịch đó; hãy tạo khoản góp mới nếu muốn góp thêm.'
                                  : message;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Xác nhận góp tiền',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSurplusAllocationSheet(BuildContext context, FinancialGoal goal) {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    SurplusAvailability? surplusData;
    bool loadingSurplus = true;
    String? surplusError;

    final amountCtrl = TextEditingController();
    bool submitting = false;
    String? sheetError;

    // Fetch surplus availability function
    Future<void> loadSurplus(void Function(void Function()) setSheet) async {
      setSheet(() {
        loadingSurplus = true;
        surplusError = null;
        surplusData = null;
      });
      try {
        final res = await context
            .read<FinanceProvider>()
            .fetchSurplusAvailability(selectedMonth, selectedYear);
        setSheet(() {
          surplusData = res;
          loadingSurplus = false;
        });
      } catch (e) {
        setSheet(() {
          surplusError = e.toString().replaceFirst('Exception: ', '');
          loadingSurplus = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Trigger initial load
          if (loadingSurplus && surplusData == null && surplusError == null) {
            loadSurplus(setSheet);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trích từ số dư quỹ chung',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  goal.goalName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Text('ℹ️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chuyển tiền dư thừa chưa sử dụng của Quỹ gia đình sang cho Mục tiêu này. Tổng quỹ chung gia đình không thay đổi.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Trạng thái load số dư
                if (loadingSurplus)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (surplusError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Text(
                            surplusError!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => loadSurplus(setSheet),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (surplusData != null) ...[
                  // Thông tin số dư
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kỳ tháng $selectedMonth/$selectedYear',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tổng số dư quỹ:',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _fmt(surplusData!.totalSurplus),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Số dư khả dụng (chưa phân bổ):',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _fmt(surplusData!.availableSurplus),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (surplusData!.availableSurplus <= 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Không còn số dư quỹ tháng $selectedMonth để phân bổ vào mục tiêu.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.danger,
                        ),
                      ),
                    )
                  else ...[
                    _inputBox(
                      amountCtrl,
                      'Số tiền phân bổ (₫)',
                      keyboardType: TextInputType.number,
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        sheetError!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.link,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: submitting
                            ? null
                            : () async {
                                final amount = parseMoneyInput(amountCtrl.text);
                                if (amount <= 0) {
                                  setSheet(
                                    () =>
                                        sheetError = 'Nhập số tiền lớn hơn 0.',
                                  );
                                  return;
                                }
                                if (amount > surplusData!.availableSurplus) {
                                  setSheet(
                                    () => sheetError =
                                        'Số tiền phân bổ không được vượt quá số dư khả dụng.',
                                  );
                                  return;
                                }
                                setSheet(() {
                                  submitting = true;
                                  sheetError = null;
                                });
                                try {
                                  await context
                                      .read<FinanceProvider>()
                                      .allocateSurplusToGoal(
                                        goal.id,
                                        periodMonth: selectedMonth,
                                        periodYear: selectedYear,
                                        amount: amount,
                                        note:
                                            'Chuyển số dư quỹ tháng $selectedMonth vào mục tiêu',
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                } catch (e) {
                                  setSheet(() {
                                    submitting = false;
                                    sheetError = e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    );
                                  });
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Xác nhận phân bổ',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _allocationCard(BuildContext context, GoalAllocation a) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt(a.amount),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.income,
                  ),
                ),
                if (a.note != null && a.note!.isNotEmpty)
                  Text(
                    a.note!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (a.createdAt != null)
                  Text(
                    a.createdAt!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditAllocationSheet(context, a),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_rounded, size: 16, color: AppColors.link),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteAllocation(context, a),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllocation(BuildContext context, GoalAllocation a) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().deleteGoalAllocation(a.id);
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showEditAllocationSheet(BuildContext context, GoalAllocation a) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        a.amount.round().toString(),
      ),
    );
    bool submitting = false;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sửa số tiền đã góp',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _inputBox(
                amountCtrl,
                'Số tiền (₫)',
                keyboardType: TextInputType.number,
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sheetError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final amt = parseMoneyInput(amountCtrl.text);
                          if (amt <= 0) {
                            setSheet(() => sheetError = 'Nhập số tiền hợp lệ');
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context
                                .read<FinanceProvider>()
                                .updateGoalAllocation(a.id, amt);
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            setSheet(() {
                              submitting = false;
                              final message = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              sheetError = message.contains('vượt quá số tiền')
                                  ? 'Khoản góp này gắn với giao dịch nguồn. Số tiền sửa không thể vượt quá số tiền còn lại của giao dịch đó; hãy tạo khoản góp mới nếu muốn góp thêm.'
                                  : message;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Lưu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGoalSheet(BuildContext context, FinancialGoal goal) {
    final nameCtrl = TextEditingController(text: goal.goalName);
    final targetCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        goal.targetAmount.round().toString(),
      ),
    );
    bool submitting = false;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sửa mục tiêu',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _inputBox(nameCtrl, 'Tên mục tiêu'),
              const SizedBox(height: 12),
              _inputBox(
                targetCtrl,
                'Số tiền mục tiêu (₫)',
                keyboardType: TextInputType.number,
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sheetError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final target = parseMoneyInput(targetCtrl.text);
                          if (nameCtrl.text.trim().isEmpty || target <= 0) {
                            setSheet(
                              () => sheetError = 'Nhập tên và số tiền hợp lệ',
                            );
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context.read<FinanceProvider>().updateGoal(
                              widget.goalId,
                              goalName: nameCtrl.text.trim(),
                              targetAmount: target,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            setSheet(() {
                              submitting = false;
                              sheetError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Lưu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBox(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? const [ThousandsSeparatorInputFormatter()]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
      ),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
    ),
  );
}
