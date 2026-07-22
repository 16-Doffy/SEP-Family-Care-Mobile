import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ring_chart.dart';
import '../../widgets/waffle_chart.dart';
import '../../widgets/money_input.dart';

String _fmt(int n) =>
    '${n.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ₫';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWallets();
      context.read<SupportRequestProvider>().fetchRequests();
      context.read<FinanceProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = context.watch<WalletProvider>();
    final pendingRequests = context
        .watch<SupportRequestProvider>()
        .pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _backBtn(context),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sổ thu chi gia đình',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: walletState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : walletState.error != null
                  ? _errorView(
                      walletState.error!,
                      () => walletState.fetchWallets(),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildHeroCard(context, walletState),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _tabItem(0, 'Tổng quan'),
                              _tabItem(1, 'Lịch sử'),
                              _tabItem(2, 'Yêu cầu', badge: pendingRequests),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_tab == 0) ..._buildOverview(context, walletState),
                        if (_tab == 1) ..._buildHistory(walletState),
                        if (_tab == 2) ..._buildRequests(context),

                        const SizedBox(height: 110),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, WalletProvider state) {
    final family = state.familyWallet;
    final totalIn = state.monthlyIncome;
    final totalOut = state.monthlyExpense;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.heroOrange, AppColors.heroPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quỹ gia đình',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(family?.balance.round() ?? 0),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Tháng này +${_fmt(totalIn.round())} / -${_fmt(totalOut.round())}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRecordSheet(context, isIncome: true),
                  child: _heroBtn('📥', 'Thu'),
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white30),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRecordSheet(context, isIncome: false),
                  child: _heroBtn('📤', 'Chi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverview(BuildContext context, WalletProvider state) {
    final income = state.monthlyIncome;
    final expense = state.monthlyExpense;
    final remaining = income - expense;
    final spentRatio = income > 0 ? expense / income : 0.0;
    final bufferPct = income > 0 ? ((remaining / income) * 100).round() : 0;
    final badgeBg = bufferPct < 10
        ? const Color(0xFFFEE2E2)
        : bufferPct < 30
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFDCFCE7);
    final badgeTxt = bufferPct < 10
        ? const Color(0xFF991B1B)
        : bufferPct < 30
        ? const Color(0xFF92400E)
        : const Color(0xFF166534);

    return [
      _sectionCard(
        title: 'Ngân sách tháng này',
        child: Column(
          children: [
            Row(
              children: [
                RingChart(
                  progress: spentRatio.clamp(0.0, 1.0),
                  size: 110,
                  strokeWidth: 14,
                  color: AppColors.shared,
                  trackColor: const Color(0xFFDCFCE7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(spentRatio * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'đã chi',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmt(expense.round()),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'đã chi / ${_fmt(income.round())} thu nhập',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Dư ${_fmt(remaining.round())} · $bufferPct%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeTxt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Flexible(
                    flex: expense.round(),
                    fit: FlexFit.tight,
                    child: Container(height: 12, color: AppColors.shared),
                  ),
                  Flexible(
                    flex: remaining.round().clamp(0, 999999999),
                    fit: FlexFit.tight,
                    child: Container(height: 12, color: AppColors.safe),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _barLegend('Chi tiêu', AppColors.shared, _fmt(expense.round())),
                _barLegend('Dư', AppColors.safe, _fmt(remaining.round())),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      _sectionCard(
        title: 'Phân bổ thu nhập',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaffleChart(
              segments: [
                WaffleSegment(
                  color: AppColors.income,
                  pct: income > 0 ? 50 : 0,
                  label: 'Thu nhập',
                  amount: income.round(),
                ),
                WaffleSegment(
                  color: AppColors.shared,
                  pct: income > 0 ? (expense / income * 100).round() : 0,
                  label: 'Chi tiêu',
                  amount: expense.round(),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _waffleLegend(
                    'Thu nhập',
                    AppColors.income,
                    _fmt(income.round()),
                    '100%',
                  ),
                  const SizedBox(height: 10),
                  _waffleLegend(
                    'Chi tiêu',
                    AppColors.shared,
                    _fmt(expense.round()),
                    income > 0 ? '${(expense / income * 100).round()}%' : '0%',
                  ),
                  const SizedBox(height: 10),
                  _waffleLegend(
                    'Dư',
                    const Color(0xFFE5E7EB),
                    _fmt(remaining.round()),
                    '$bufferPct%',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      _alertBar(remaining.round(), bufferPct),
    ];
  }

  List<Widget> _buildHistory(WalletProvider state) {
    if (state.transactions.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Chưa có giao dịch nào',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }
    return [
      _sectionCard(
        title: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...state.transactions.map((tx) {
              final signed = tx.signedAmount;
              final isPos = signed >= 0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openLedgerEntry(context, tx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF3F4F6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isPos ? '💵' : '💸',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              tx.displayEntryDate,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isPos ? '+' : ''}${_fmt(signed.abs().round())}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPos ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (state.hasMoreEntries) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: state.isLoadingMoreEntries
                      ? null
                      : () => context.read<WalletProvider>().fetchMoreEntries(),
                  child: state.isLoadingMoreEntries
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tải thêm'),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _openLedgerEntry(BuildContext context, LedgerEntry entry) async {
    try {
      final detail = await context.read<WalletProvider>().fetchEntryDetail(
        entry.id,
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          final editable =
              detail.entryType == 'INCOME' || detail.entryType == 'EXPENSE';
          final signed = detail.signedAmount;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi tiết giao dịch',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ledgerDetailRow(
                    'Loại',
                    signed >= 0 ? 'Khoản thu' : 'Khoản chi',
                  ),
                  _ledgerDetailRow(
                    'Số tiền',
                    '${_fmt(detail.amount.round())} đ',
                  ),
                  _ledgerDetailRow(
                    'Danh mục',
                    detail.categoryName ?? 'Chưa phân loại',
                  ),
                  _ledgerDetailRow('Thời gian', detail.displayEntryDate),
                  _ledgerDetailRow(
                    'Mô tả',
                    detail.description.isEmpty ? '—' : detail.description,
                  ),
                  if ((detail.note ?? '').isNotEmpty)
                    _ledgerDetailRow('Ghi chú', detail.note!),
                  if (editable) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showEditLedgerSheet(context, detail);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            onPressed: () async {
                              final approved = await _confirmVoidEntry(context);
                              if (!approved || !context.mounted) return;
                              try {
                                await context.read<WalletProvider>().voidEntry(
                                  detail.id,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showFinanceError(context, e);
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hủy giao dịch'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Giao dịch được tạo từ flow hệ thống nên không sửa trực tiếp ở sổ thu chi.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        _showFinanceError(context, e);
      }
    }
  }

  Widget _ledgerDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<bool> _confirmVoidEntry(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hủy giao dịch?'),
            content: const Text(
              'Giao dịch sẽ bị hủy và không còn được tính vào số liệu tài chính.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Không'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hủy giao dịch'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditLedgerSheet(BuildContext context, LedgerEntry entry) {
    final amountCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.formatThousands(
        entry.amount.round().toString(),
      ),
    );
    final descriptionCtrl = TextEditingController(text: entry.description);
    final noteCtrl = TextEditingController(text: entry.note ?? '');
    final categories = context
        .read<FinanceProvider>()
        .categories
        .where((category) =>
            category.categoryType == entry.entryType && category.isActive)
        .toList();
    String? categoryId = entry.categoryId;
    if (categoryId == null ||
        !categories.any((category) => category.id == categoryId)) {
      categoryId = categories.isNotEmpty ? categories.first.id : null;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chỉnh sửa giao dịch',
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Số tiền (đ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => categoryId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = parseMoneyInput(amountCtrl.text);
                    final description = descriptionCtrl.text.trim();
                    if (amount <= 0 || description.isEmpty) {
                      _showFinanceError(
                        sheetContext,
                        'Nhập số tiền lớn hơn 0 và mô tả giao dịch.',
                      );
                      return;
                    }
                    try {
                      await context.read<WalletProvider>().updateEntry(
                        entry.id,
                        amount: amount,
                        description: description,
                        categoryId: categoryId,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    } catch (e) {
                      if (sheetContext.mounted) {
                        _showFinanceError(sheetContext, e);
                      }
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFinanceError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showCategoryManagerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final categories = sheetContext.watch<FinanceProvider>().categories;
        final orderedCategories = [...categories]
          ..sort((a, b) {
            if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Danh mục thu chi',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tạo danh mục',
                        onPressed: () =>
                            _showCreateCategoryDialog(sheetContext),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngưng dùng chỉ ẩn danh mục khỏi các form mới; lịch sử giao dịch và ngân sách vẫn được giữ.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: orderedCategories.isEmpty
                        ? const Center(child: Text('Chưa có danh mục nào'))
                        : ListView.separated(
                            itemCount: orderedCategories.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final category = orderedCategories[index];
                              final isIncome =
                                  category.categoryType == 'INCOME';
                              final essentialLabel =
                                  category.essentialType == 'ESSENTIAL'
                                  ? 'Thiết yếu'
                                  : 'Không thiết yếu';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isIncome
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isIncome
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                                title: Text(category.name),
                                subtitle: Text(
                                  isIncome
                                  ? 'Khoản thu · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}'
                                  : category.essentialType == null
                                  ? 'Khoản chi · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}'
                                  : 'Khoản chi · $essentialLabel · ${category.isActive ? 'Đang hoạt động' : 'Đã ngưng dùng'}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      _showEditCategoryDialog(
                                        sheetContext,
                                        category,
                                      );
                                      return;
                                    }
                                    final approved =
                                        await _confirmDeactivateCategory(
                                          sheetContext,
                                          category.name,
                                        );
                                    if (!approved || !sheetContext.mounted) {
                                      return;
                                    }
                                    try {
                                      await sheetContext
                                          .read<FinanceProvider>()
                                          .deactivateCategory(category.id);
                                    } catch (e) {
                                      if (sheetContext.mounted) {
                                        _showFinanceError(sheetContext, e);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Đổi tên'),
                                    ),
                                    PopupMenuItem(
                                      value: 'deactivate',
                                      child: Text('Ngưng dùng'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeactivateCategory(
    BuildContext context,
    String name,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ngưng dùng danh mục?'),
            content: Text(
              'Danh mục “$name” sẽ không thể chọn cho giao dịch hoặc kế hoạch mới.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Không'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Ngưng dùng'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditCategoryDialog(BuildContext context, FinanceCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await context.read<FinanceProvider>().updateCategory(
                  category.id,
                  name: name,
                  essentialType: category.essentialType,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) _showFinanceError(dialogContext, e);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    var categoryType = 'EXPENSE';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Tạo danh mục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryType,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: const [
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Khoản chi')),
                  DropdownMenuItem(value: 'INCOME', child: Text('Khoản thu')),
                ],
                onChanged: (value) =>
                    setDialogState(() => categoryType = value ?? 'EXPENSE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await context.read<FinanceProvider>().createCategory(
                    name: name,
                    categoryType: categoryType,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    _showFinanceError(dialogContext, e);
                  }
                }
              },
              child: const Text('Tạo danh mục'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRequests(BuildContext context) {
    final provider = context.watch<SupportRequestProvider>();
    final pending = provider.requests
        .where((request) => request.isPending)
        .toList();
    if (pending.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            '🎉 Không có yêu cầu chờ duyệt',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }
    return pending
        .map(
          (req) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.link.withValues(alpha: .14),
                  child: Text(
                    req.requesterName.isEmpty
                        ? '?'
                        : req.requesterName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppColors.link,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${req.requesterName} · ${_fmt(req.amount.round())}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        req.purpose,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          await provider.review(
                            requestId: req.id,
                            decision: 'APPROVE',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã duyệt ${_fmt(req.amount.round())} cho ${req.requesterName} ✅',
                              ),
                              backgroundColor: AppColors.safe,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          _showFinanceError(context, e);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await provider.review(
                            requestId: req.id,
                            decision: 'REJECT',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã từ chối yêu cầu của ${req.requesterName} ❌',
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          _showFinanceError(context, e);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  void _showRecordSheet(BuildContext context, {required bool isIncome}) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categories = context
        .read<FinanceProvider>()
        .categories
        .where(
          (category) =>
              category.categoryType == (isIncome ? 'INCOME' : 'EXPENSE') &&
                  category.isActive,
        )
        .toList();
    String? categoryId = categories.isNotEmpty ? categories.first.id : null;
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
            28,
            28,
            28,
            MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isIncome ? '📥' : '📤',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isIncome ? 'Ghi nhận Thu' : 'Ghi nhận Chi',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Số tiền (₫)',
                  hintText: 'VD: 500.000',
                  suffixText: '₫',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheet(() => categoryId = value),
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showCategoryManagerSheet(context),
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Quản lý danh mục'),
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  hintText: isIncome ? 'VD: Lương tháng 6' : 'VD: Tiền chợ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncome
                        ? AppColors.success
                        : AppColors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final amount = parseMoneyInput(amountCtrl.text);
                    if (amount <= 0) return;
                    final desc = descCtrl.text.trim().isNotEmpty
                        ? descCtrl.text.trim()
                        : (isIncome ? 'Thu nhập' : 'Chi tiêu');
                    try {
                      await context.read<WalletProvider>().recordEntry(
                        amount: amount,
                        description: desc,
                        isIncome: isIncome,
                        categoryId: categoryId,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    isIncome ? 'Lưu khoản Thu' : 'Lưu khoản Chi',
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

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _errorView(String msg, VoidCallback onRetry) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Lỗi tải dữ liệu',
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.danger),
        ),
        const SizedBox(height: 8),
        Text(
          msg,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            child,
          ],
        ),
      );

  Widget _barLegend(String label, Color color, String val) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(left: 12, top: 2),
        child: Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );

  Widget _waffleLegend(String label, Color color, String amount, String pct) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                pct,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _alertBar(int remaining, int bufferPct) {
    final String icon;
    final Color bg, tc, sc;
    final String title, sub;
    if (bufferPct < 10) {
      icon = '🚨';
      bg = const Color(0xFFFEE2E2);
      tc = const Color(0xFF991B1B);
      sc = const Color(0xFFB91C1C);
      title = 'Cảnh báo ngân sách';
      sub = 'Chỉ còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else if (bufferPct < 30) {
      icon = '⚠️';
      bg = const Color(0xFFFFFBEB);
      tc = const Color(0xFF92400E);
      sc = const Color(0xFFB45309);
      title = 'Thu gần Chi';
      sub = 'Còn ${_fmt(remaining)} ($bufferPct% dự phòng)';
    } else {
      icon = '✅';
      bg = const Color(0xFFF0FDF4);
      tc = const Color(0xFF166634);
      sc = const Color(0xFF15803D);
      title = 'Dư ${_fmt(remaining)} — Tháng tốt!';
      sub = 'Còn $bufferPct% dự phòng 🎉';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tc,
                  ),
                ),
                Text(sub, style: GoogleFonts.inter(fontSize: 11, color: sc)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBtn(String icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18, color: Colors.white)),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _tabItem(int index, String label, {int badge = 0}) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.link : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.pop(),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: AppColors.textPrimary,
      ),
    ),
  );
}
