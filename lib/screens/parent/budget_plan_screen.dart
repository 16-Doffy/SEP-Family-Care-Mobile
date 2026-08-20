import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/money_input.dart';

class BudgetPlanScreen extends StatefulWidget {
  const BudgetPlanScreen({super.key});
  @override
  State<BudgetPlanScreen> createState() => _BudgetPlanScreenState();
}

class _BudgetPlanScreenState extends State<BudgetPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchAll();
    });
  }

  String _fmt(double? v) {
    if (v == null) return '—';
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  /// Dải cảnh báo cam khi kế hoạch ACTIVE nhưng kỳ chưa tới / đã qua.
  /// `null` khi kỳ đang bao gồm hôm nay — không thêm dòng thừa.
  Widget? _periodWarningLine(BudgetPlan plan) {
    final warning = plan.periodWarning;
    if (warning == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              size: 14,
              color: Color(0xFF92400E),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                warning,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final plans = provider.budgetPlans;

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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Kế hoạch ngân sách',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCreateSheet(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.link,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            if (provider.loading && plans.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (provider.error != null && plans.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lỗi tải dữ liệu',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => provider.fetchAll(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (plans.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.savings_rounded,
                        size: 40,
                        color: AppColors.primary500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa có kế hoạch ngân sách',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plans.length,
                    itemBuilder: (_, i) => _planCard(context, plans[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, BudgetPlan plan) {
    return GestureDetector(
      onTap: () =>
          context.push('/manager/budget-plans/detail?planId=${plan.id}'),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.planName,
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
                    color: plan.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: plan.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmtDate(plan.periodStart)} → ${_fmtDate(plan.periodEnd)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            // "Đang áp dụng" mà kỳ chưa tới / đã qua thì trông như kế hoạch có
            // hiệu lực ngay bây giờ — người dùng ghi khoản chi hôm nay rồi chờ
            // cảnh báo vượt ngân sách mãi không thấy. Nói thẳng ra.
            ?_periodWarningLine(plan),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thu nhập dự kiến',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _fmt(plan.expectedSharedIncome),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiêu dự kiến',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _fmt(plan.expectedSharedExpense),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (plan.status != 'CANCELED') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  onPressed: () => context.push('/manager/finance-reports'),
                  icon: const Icon(
                    Icons.bar_chart_rounded,
                    size: 15,
                    color: AppColors.link,
                  ),
                  label: Text(
                    'Xem báo cáo kế hoạch vs thực tế',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.link,
                    ),
                  ),
                ),
              ),
            ],
            if (plan.status == 'DRAFT' || plan.status == 'ACTIVE') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (plan.status == 'DRAFT')
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () =>
                              _runPlanAction(context, plan, 'activate'),
                          child: Text(
                            'Kích hoạt',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (plan.status == 'ACTIVE')
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () =>
                              _runPlanAction(context, plan, 'close'),
                          child: Text(
                            'Đóng',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        onPressed: () =>
                            _runPlanAction(context, plan, 'cancel'),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    // Lấy trước — `ctx` (context của sheet) mất theo sheet ngay sau
    // Navigator.pop, không dùng lại được để báo hint sau khi tạo xong.
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final incomeCtrl = TextEditingController();
    final expenseCtrl = TextEditingController();
    final firstLineCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController();
    final newCategoryCtrl = TextEditingController();
    String? firstLineCategoryId;
    // null = chưa quyết định, để build đầu tiên tự suy ra theo danh sách thật.
    // Trước đây cờ này được chốt một lần từ bản chụp danh mục lúc mở sheet, nên
    // sau khi tạo danh mục thành công mà bước sau lỗi, sheet vẫn khăng khăng
    // "chưa có danh mục" và ép tạo lại đúng tên đó → BE trả 409, bế tắc hẳn.
    bool? isCreatingCategory;
    var newCategoryEssentialType = 'NEUTRAL';
    String periodType = 'MONTHLY';
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
        builder: (ctx, setSheet) {
          // Đọc lại danh mục ở MỖI lần build: `createCategory` gọi
          // `notifyListeners()` sau khi refetch, nên vừa tạo xong là dropdown có
          // ngay — không còn cảnh sheet bảo "chưa có danh mục" trong khi BE đã có.
          final expenseCategories = ctx
              .watch<FinanceProvider>()
              .categories
              .where(
                (category) =>
                    category.categoryType == 'EXPENSE' && category.isActive,
              )
              .toList();
          final creatingCategory =
              isCreatingCategory ?? expenseCategories.isEmpty;
          if (firstLineCategoryId != null &&
              !expenseCategories.any((c) => c.id == firstLineCategoryId)) {
            // Danh mục đang chọn vừa bị ngưng dùng ở màn khác → bỏ chọn thay vì
            // để DropdownButtonFormField ném vì value không có trong items.
            firstLineCategoryId = null;
          }
          if (!creatingCategory &&
              firstLineCategoryId == null &&
              expenseCategories.isNotEmpty) {
            firstLineCategoryId = expenseCategories.first.id;
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tạo kế hoạch ngân sách',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tên kế hoạch',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputBox(nameCtrl, 'VD: Ngân sách tháng 6'),
                  const SizedBox(height: 12),
                  Text(
                    'Kỳ hạn',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in ['MONTHLY', 'QUARTERLY', 'YEARLY'])
                        ChoiceChip(
                          label: Text(switch (p) {
                            'MONTHLY' => 'Hàng tháng',
                            'QUARTERLY' => 'Hàng quý',
                            _ => 'Hàng năm',
                          }),
                          selected: periodType == p,
                          onSelected: (_) => setSheet(() => periodType = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Thu nhập dự kiến (₫)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputBox(
                    incomeCtrl,
                    'VD: 20000000',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tổng số tiền gia đình dự kiến thu trong kỳ này.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chi tiêu dự kiến (₫)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputBox(
                    expenseCtrl,
                    'VD: 15000000',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tổng ngân sách dự kiến chi cho tất cả danh mục trong kỳ.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dòng ngân sách đầu tiên',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bắt buộc để có thể kích hoạt kế hoạch.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (expenseCategories.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: firstLineCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Danh mục chi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        ...expenseCategories.map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '__create_new_category__',
                          child: Text('+ Tạo danh mục Chi mới'),
                        ),
                      ],
                      onChanged: (value) {
                        final creatingNew = value == '__create_new_category__';
                        setSheet(() {
                          isCreatingCategory = creatingNew;
                          firstLineCategoryId = creatingNew ? null : value;
                          sheetError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (creatingCategory) ...[
                    Text(
                      expenseCategories.isEmpty
                          ? 'Chưa có danh mục Chi. Tạo danh mục đầu tiên ngay bên dưới.'
                          : 'Nhập thông tin danh mục Chi mới.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: expenseCategories.isEmpty
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _inputBox(newCategoryCtrl, 'Tên danh mục Chi, VD: Ăn uống'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                                ('ESSENTIAL', 'Thiết yếu'),
                                ('NON_ESSENTIAL', 'Không thiết yếu'),
                                ('NEUTRAL', 'Trung lập'),
                              ]
                              .map(
                                (item) => ChoiceChip(
                                  label: Text(item.$2),
                                  selected: newCategoryEssentialType == item.$1,
                                  onSelected: (_) => setSheet(
                                    () => newCategoryEssentialType = item.$1,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _inputBox(
                    firstLineCtrl,
                    'Ngân sách cho danh mục này (₫)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phần tiền được phân bổ cho danh mục đã chọn ở trên.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _inputBox(
                    thresholdCtrl,
                    'Cảnh báo khi đã chi đến (₫, tùy chọn)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ví dụ ngân sách 5.000.000 ₫, nhập 4.000.000 ₫ để được cảnh báo sớm.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            final firstLineAmount = parseMoneyInput(
                              firstLineCtrl.text,
                            );
                            final expectedExpense = _optionalMoney(
                              expenseCtrl.text,
                            );
                            final thresholdAmount = _optionalMoney(
                              thresholdCtrl.text,
                            );
                            if (nameCtrl.text.trim().isEmpty ||
                                firstLineAmount <= 0 ||
                                (firstLineCategoryId == null &&
                                    newCategoryCtrl.text.trim().isEmpty)) {
                              setSheet(
                                () => sheetError =
                                    'Nhập tên kế hoạch, danh mục Chi và số tiền kế hoạch lớn hơn 0.',
                              );
                              return;
                            }
                            if (expectedExpense != null &&
                                firstLineAmount > expectedExpense) {
                              setSheet(
                                () => sheetError =
                                    'Dòng ngân sách đầu tiên không được lớn hơn Chi tiêu dự kiến.',
                              );
                              return;
                            }
                            if (thresholdAmount != null &&
                                thresholdAmount <= 0) {
                              setSheet(
                                () => sheetError =
                                    'Ngưỡng cảnh báo phải là số tiền lớn hơn 0.',
                              );
                              return;
                            }
                            setSheet(() {
                              submitting = true;
                              sheetError = null;
                            });
                            try {
                              final range = _planPeriodRange(periodType);
                              final finance = context.read<FinanceProvider>();
                              final categoryId =
                                  firstLineCategoryId ??
                                  await _ensureExpenseCategory(
                                    finance,
                                    name: newCategoryCtrl.text.trim(),
                                    essentialType: newCategoryEssentialType,
                                  );
                              // Ghim danh mục đã giải quyết được: nếu bước tạo
                              // kế hoạch bên dưới lỗi, lần bấm lại sẽ dùng thẳng
                              // id này thay vì gọi lại POST categories.
                              firstLineCategoryId = categoryId;
                              isCreatingCategory = false;
                              await finance.createBudgetPlan(
                                planName: nameCtrl.text.trim(),
                                periodType: periodType,
                                periodStart: range.start,
                                periodEnd: range.end,
                                expectedSharedIncome: _optionalMoney(
                                  incomeCtrl.text,
                                ),
                                expectedSharedExpense: _optionalMoney(
                                  expenseCtrl.text,
                                ),
                                lines: [
                                  {
                                    'categoryId': categoryId,
                                    'plannedAmount': firstLineAmount,
                                    // CreateBudgetLineDto.thresholdAmount là
                                    // `number` KHÔNG nullable (khác
                                    // UpdateBudgetLineDto) — gửi null tường minh
                                    // là sai contract, phải bỏ hẳn key.
                                    'thresholdAmount': ?thresholdAmount,
                                  },
                                ],
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              // Danh mục Chi vừa tạo trong sheet này chưa
                              // được gán vào hũ nào — khoản chi sau này sẽ
                              // rơi vào "Chưa gán hũ" cho đến khi vào Mô
                              // hình tài chính gán tay (verify runtime
                              // 2026-08-19).
                              if (creatingCategory) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã tạo danh mục "${newCategoryCtrl.text.trim()}". '
                                      'Nhớ vào Mô hình tài chính → "Gán danh mục vào hũ" — '
                                      'chưa gán thì khoản chi sẽ nằm ở "Chưa gán hũ".',
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Budget plan create failed: $e');
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
                            'Tạo kế hoạch',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
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

  double? _optionalMoney(String input) =>
      input.trim().isEmpty ? null : parseMoneyInput(input);

  /// Kỳ của kế hoạch, nắn về **mốc tròn** thay vì "hôm nay → hôm nay + n tháng".
  ///
  /// Trước đây tạo ngày 02/08 ra kỳ 02/08–02/09: không phải tháng 8, không khớp
  /// bộ chọn kỳ lẫn mọi báo cáo tính theo tháng dương lịch.
  ({DateTime start, DateTime end}) _planPeriodRange(String periodType) {
    final now = DateTime.now();
    return switch (periodType) {
      // Quý dương lịch chứa hôm nay: 1–3, 4–6, 7–9, 10–12.
      'QUARTERLY' => (
        start: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1),
        end: DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 4, 0),
      ),
      'YEARLY' => (
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31),
      ),
      // `DateTime(y, m + 1, 0)` = ngày cuối tháng m, tự đúng cả tháng 12 lẫn
      // năm nhuận.
      _ => (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      ),
    };
  }

  /// Lấy id danh mục Chi theo tên — tạo mới nếu chưa có, **dùng lại nếu BE báo
  /// trùng**.
  ///
  /// `POST /finance/categories` trả `409` khi đã có danh mục ACTIVE cùng tên.
  /// Trước đây 409 được ném thẳng lên banner lỗi và người dùng kẹt vĩnh viễn:
  /// ý định của họ là "dùng danh mục tên này", không phải "tạo thêm một bản ghi".
  Future<String> _ensureExpenseCategory(
    FinanceProvider finance, {
    required String name,
    required String essentialType,
  }) async {
    String? existingId() {
      final matching = finance.categories.where(
        (category) =>
            category.categoryType == 'EXPENSE' &&
            category.isActive &&
            category.name.trim().toLowerCase() == name.toLowerCase(),
      );
      return matching.isEmpty ? null : matching.last.id;
    }

    try {
      final created = await finance.createCategory(
        name: name,
        categoryType: 'EXPENSE',
        essentialType: essentialType,
      );
      final id = created?.id;
      if (id != null && id.isNotEmpty) return id;
    } on ApiException catch (e) {
      // 409 = đã tồn tại. Mọi status khác là lỗi thật, để nguyên cho banner.
      if (e.statusCode != 409) rethrow;
      // Danh sách trong provider có thể là bản trước khi danh mục được tạo (ví
      // dụ lần bấm trước tạo xong rồi bước sau mới lỗi) → refetch trước khi tra.
      await finance.fetchAll();
    }

    final id = existingId();
    if (id == null || id.isEmpty) {
      throw Exception(
        'Không lấy được danh mục Chi "$name". Chọn lại danh mục ở danh sách trên.',
      );
    }
    return id;
  }

  Future<void> _runPlanAction(
    BuildContext context,
    BudgetPlan plan,
    String action,
  ) async {
    // "close"/"cancel" không quay lại được (đóng thì không kích hoạt lại
    // được, hủy thì mất hẳn) nhưng trước đây bấm là chạy ngay, không hỏi
    // (verify runtime 2026-08-19). "activate" vẫn chạy thẳng — không phá gì,
    // sai kỳ thì BE tự chặn bằng 409.
    if (action == 'close' || action == 'cancel') {
      final actionLabel = action == 'close' ? 'đóng' : 'hủy';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Bạn chắc chắn muốn $actionLabel kế hoạch này?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: Text(
            action == 'close'
                ? '"${plan.planName}" sẽ ngừng áp dụng. Không kích hoạt lại được — '
                      'phải tạo kế hoạch mới nếu cần dùng lại.'
                : '"${plan.planName}" sẽ bị hủy, không hoàn tác được.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action == 'close' ? 'Đóng' : 'Hủy'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().budgetPlanAction(plan.id, action);
      if (!context.mounted) return;
      final label = switch (action) {
        'activate' => 'Đã kích hoạt kế hoạch',
        'close' => 'Đã đóng kế hoạch',
        _ => 'Đã hủy kế hoạch',
      };
      messenger.showSnackBar(
        SnackBar(content: Text(label), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
