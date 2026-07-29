import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart' as fp;
import '../../providers/wallet_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/money_input.dart';

// UC-FIN-01 — Chọn mô hình tài chính gia đình (5 Jars / 80-20 / Custom)
// UC-FIN-02 — Cấu hình các khoản (Jars / Funds)
//
// Flow thật đã verify với BE (2026-06-26):
//   1. POST /finance/models {modelType, name} → BE tự sinh jar mặc định cho
//      FIVE_JARS (Necessities 50/Savings 20/Education 10/Enjoyment 10/
//      Giving 10) và EIGHTY_TWENTY (Spending 80/Savings 20). CUSTOM thì
//      jars rỗng, phải tự POST /finance/jars cho từng lọ.
//   2. Nếu user đổi % khác mặc định → PATCH /finance/jars/{jarId} từng lọ.
//   3. Model mới tạo ở trạng thái DRAFT — phải PATCH .../activate mới thực
//      sự áp dụng cho gia đình (BE tự vô hiệu hoá model cũ).
// Trước đây _save() chỉ gửi {modelType, name}, bỏ qua toàn bộ % người dùng
// chỉnh và không activate — coi như không có gì được lưu thật.

enum FinanceModelType { fiveJars, eightTwenty, custom }

String _formatAllocationDateTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class FinanceJarUi {
  final String name;
  final IconData icon;
  final Color color;
  double percent;
  // jarCode/jarId khi map với jar thật của BE (đã tồn tại từ model active
  // hiện tại) — null nếu đây là lọ mới user tự thêm (CUSTOM).
  final String? jarCode;

  FinanceJarUi({
    required this.name,
    required this.icon,
    required this.color,
    required this.percent,
    this.jarCode,
  });
}

class FinanceModelScreen extends StatefulWidget {
  const FinanceModelScreen({super.key});
  @override
  State<FinanceModelScreen> createState() => _FinanceModelScreenState();
}

class _FinanceModelScreenState extends State<FinanceModelScreen> {
  FinanceModelType _model = FinanceModelType.fiveJars;
  bool _saving = false;
  bool _loadingCurrent = true;
  bool _hasLocalEdits = false;
  // Tên model hiện gia đình đang active (để hiện banner — null nếu chưa có)
  String? _currentModelTypeLabel;
  String? _currentModelId;

  // Giá trị mặc định KHỚP với BE thật (verify qua API, không phải số bịa).
  final List<FinanceJarUi> _fiveJars = [
    FinanceJarUi(
      name: 'Nhu cầu thiết yếu',
      icon: Icons.home_work_outlined,
      color: const Color(0xFF2563EB),
      percent: 50,
      jarCode: 'NECESSITIES',
    ),
    FinanceJarUi(
      name: 'Tiết kiệm dài hạn',
      icon: Icons.savings_outlined,
      color: const Color(0xFF16A34A),
      percent: 20,
      jarCode: 'SAVINGS',
    ),
    FinanceJarUi(
      name: 'Giáo dục',
      icon: Icons.school_outlined,
      color: const Color(0xFFF59E0B),
      percent: 10,
      jarCode: 'EDUCATION',
    ),
    FinanceJarUi(
      name: 'Vui chơi',
      icon: Icons.celebration_outlined,
      color: const Color(0xFFEC4899),
      percent: 10,
      jarCode: 'ENJOYMENT',
    ),
    FinanceJarUi(
      name: 'Cho đi / Biếu tặng',
      icon: Icons.volunteer_activism_outlined,
      color: const Color(0xFF7C3AED),
      percent: 10,
      jarCode: 'GIVING',
    ),
  ];

  final List<FinanceJarUi> _twoFunds = [
    FinanceJarUi(
      name: 'Chi tiêu',
      icon: Icons.credit_card_rounded,
      color: const Color(0xFFF97316),
      percent: 80,
      jarCode: 'SPENDING',
    ),
    FinanceJarUi(
      name: 'Tiết kiệm',
      icon: Icons.savings_outlined,
      color: const Color(0xFF16A34A),
      percent: 20,
      jarCode: 'SAVINGS',
    ),
  ];

  final List<FinanceJarUi> _customJars = [];
  final _customNameCtrl = TextEditingController();
  final _customPercentCtrl = TextEditingController();

  List<FinanceJarUi> get _activeJars => switch (_model) {
    FinanceModelType.fiveJars => _fiveJars,
    FinanceModelType.eightTwenty => _twoFunds,
    FinanceModelType.custom => _customJars,
  };

  double get _totalPercent => _activeJars.fold(0, (s, j) => s + j.percent);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentModel());
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customPercentCtrl.dispose();
    super.dispose();
  }

  // Tải mô hình đang ACTIVE của gia đình (nếu có) để slider khởi điểm đúng
  // với số liệu thật đã lưu, không phải số mặc định cứng.
  Future<void> _loadCurrentModel() async {
    final provider = context.read<fp.FinanceProvider>();
    await Future.wait([
      provider.fetchAll(),
      context.read<WalletProvider>().fetchWallets(),
    ]);
    if (!mounted) return;
    if (_hasLocalEdits || _saving) {
      setState(() => _loadingCurrent = false);
      return;
    }
    // FinanceProvider.activeModel fallback về model đầu tiên (kể cả DRAFT)
    // khi gia đình chưa có model nào ACTIVE — chỉ coi là "đang áp dụng" khi
    // status thật sự ACTIVE, tránh hiện banner sai cho model chưa activate.
    final active = provider.activeModel;
    if (active == null || active.status != 'ACTIVE') {
      setState(() => _loadingCurrent = false);
      return;
    }
    // GET /finance/models (list) chỉ trả _count.jars, KHÔNG có jars đầy đủ
    // — phải lấy từ provider.jars (GET /finance/jars riêng) lọc theo
    // financeModelId để có % thật của từng lọ.
    final realJars = provider.jars
        .where((j) => j.financeModelId == active.id)
        .toList();
    setState(() {
      _currentModelId = active.id;
      _currentModelTypeLabel = switch (active.modelType) {
        'FIVE_JARS' => 'Quy tắc 5 Lọ',
        'EIGHTY_TWENTY' => 'Quy tắc 80/20',
        _ => active.name,
      };
      switch (active.modelType) {
        case 'FIVE_JARS':
          _model = FinanceModelType.fiveJars;
          _applyRealJars(_fiveJars, realJars);
          break;
        case 'EIGHTY_TWENTY':
          _model = FinanceModelType.eightTwenty;
          _applyRealJars(_twoFunds, realJars);
          break;
        default:
          _model = FinanceModelType.custom;
          _customJars.clear();
          final colors = [
            const Color(0xFF2563EB),
            const Color(0xFF16A34A),
            const Color(0xFFF59E0B),
            const Color(0xFFEC4899),
            const Color(0xFF7C3AED),
          ];
          for (var i = 0; i < realJars.length; i++) {
            final j = realJars[i];
            _customJars.add(
              FinanceJarUi(
                name: j.name,
                icon: Icons.account_balance_wallet_outlined,
                color: colors[i % colors.length],
                percent: j.allocationPercentage,
                jarCode: j.jarCode,
              ),
            );
          }
      }
      _loadingCurrent = false;
    });
  }

  // Map % thật từ BE theo jarCode đã verify, tránh phụ thuộc thứ tự list BE trả về.
  void _applyRealJars(List<FinanceJarUi> uiJars, List<fp.FinanceJar> realJars) {
    for (final uiJar in uiJars) {
      final realJar = _jarByCode(realJars, uiJar.jarCode);
      if (realJar != null) uiJar.percent = realJar.allocationPercentage;
    }
  }

  fp.FinanceJar? _jarByCode(List<fp.FinanceJar> jars, String? jarCode) {
    if (jarCode == null || jarCode.isEmpty) return null;
    for (final jar in jars) {
      if (jar.jarCode == jarCode) return jar;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mô hình tài chính',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_loadingCurrent)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    GestureDetector(
                      onTap: () => _showTemplatesInfo(context),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_currentModelTypeLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đang áp dụng: $_currentModelTypeLabel',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Chọn mô hình phân bổ thu nhập',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _modelCard(
                    model: FinanceModelType.fiveJars,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Quy tắc 5 lọ',
                    subtitle:
                        '50% nhu cầu · 20% tiết kiệm · 10% giáo dục · 10% vui chơi · 10% cho đi',
                  ),
                  const SizedBox(height: 10),
                  _modelCard(
                    model: FinanceModelType.eightTwenty,
                    icon: Icons.call_split_rounded,
                    title: 'Quy tắc 80/20',
                    subtitle: '80% chi tiêu · 20% tiết kiệm',
                  ),
                  const SizedBox(height: 10),
                  _modelCard(
                    model: FinanceModelType.custom,
                    icon: Icons.tune_rounded,
                    title: 'Tuỳ chỉnh',
                    subtitle: 'Tự thiết lập các khoản & tỷ lệ phân bổ',
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cấu hình khoản',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (_totalPercent - 100).abs() < 0.5
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tổng: ${_totalPercent.round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: (_totalPercent - 100).abs() < 0.5
                                ? const Color(0xFF166534)
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_model == FinanceModelType.custom) ...[
                    ..._customJars.asMap().entries.map(
                      (e) => _jarSlider(e.value, e.key, isCustom: true),
                    ),
                    _addCustomJarTile(),
                  ] else
                    ..._activeJars.asMap().entries.map(
                      (e) => _jarSlider(e.value, e.key),
                    ),

                  const SizedBox(height: 24),

                  if (_currentModelId != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppColors.link),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _showFundAllocationDialog,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Chia quỹ theo mô hình đang áp dụng'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _saving ? null : _showFundAllocationHistory,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Lịch sử chia quỹ'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        (_saving ||
                            _activeJars.isEmpty ||
                            (_totalPercent - 100).abs() >= 0.5)
                        ? null
                        : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Lưu mô hình',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelCard({
    required FinanceModelType model,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final sel = _model == model;
    return GestureDetector(
      onTap: () => setState(() {
        _model = model;
        _hasLocalEdits = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sel ? AppColors.link.withValues(alpha: 0.06) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? AppColors.link : const Color(0xFFE5E7EB),
            width: sel ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AppFeatureIcon(
              icon: icon,
              color: sel ? AppColors.link : AppColors.textMuted,
              backgroundColor: sel
                  ? AppColors.link.withValues(alpha: 0.12)
                  : const Color(0xFFF3F4F6),
              size: 48,
              iconSize: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: sel ? AppColors.link : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (sel)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.link,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _jarSlider(FinanceJarUi jar, int idx, {bool isCustom = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppFeatureIcon(
                icon: jar.icon,
                color: jar.color,
                backgroundColor: jar.color.withValues(alpha: 0.12),
                size: 34,
                iconSize: 18,
                radius: 10,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  jar.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${jar.percent.round()}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: jar.color,
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() {
                    _customJars.removeAt(idx);
                    _hasLocalEdits = true;
                  }),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          Slider(
            value: jar.percent.clamp(1, 100),
            min: 1,
            max: 100,
            activeColor: jar.color,
            inactiveColor: jar.color.withValues(alpha: 0.15),
            onChanged: (v) => setState(() {
              jar.percent = v.roundToDouble();
              _hasLocalEdits = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _addCustomJarTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thêm khoản mới',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _customNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tên khoản...',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _customPercentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '%',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final name = _customNameCtrl.text.trim();
                  final pct = double.tryParse(_customPercentCtrl.text) ?? 0;
                  if (name.isEmpty || pct <= 0) return;
                  final colors = [
                    const Color(0xFF2563EB),
                    const Color(0xFF16A34A),
                    const Color(0xFFF59E0B),
                    const Color(0xFFEC4899),
                    const Color(0xFF7C3AED),
                  ];
                  setState(() {
                    _customJars.add(
                      FinanceJarUi(
                        name: name,
                        icon: Icons.account_balance_wallet_outlined,
                        color: colors[_customJars.length % colors.length],
                        percent: pct,
                      ),
                    );
                    _customNameCtrl.clear();
                    _customPercentCtrl.clear();
                    _hasLocalEdits = true;
                  });
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.link,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // GET /finance/model-templates — mẫu mô hình khai báo constant phía BE,
  // chỉ mang tính tham khảo (UI đã hardcode đúng theo mẫu này, verify
  // 2026-06-26). Hiện dạng info sheet, không đổi luồng chọn mô hình.
  Future<void> _showTemplatesInfo(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _TemplatesInfoSheet(),
    );
  }

  Future<void> _showFundAllocationDialog() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final now = DateTime.now();
    var selectedMonth = now.month;
    var selectedYear = now.year;
    final availableBalance = context.read<WalletProvider>().totalBalance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chia quỹ theo mô hình'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Số tiền sẽ được chia vào từng hũ theo tỷ lệ của mô hình đang áp dụng.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(labelText: 'Tháng'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('Tháng ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) => setDialogState(
                        () => selectedMonth = value ?? selectedMonth,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(labelText: 'Năm'),
                      items: List.generate(5, (index) {
                        final year = now.year - 1 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      }),
                      onChanged: (value) => setDialogState(
                        () => selectedYear = value ?? selectedYear,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Số tiền cần chia (đ)',
                  hintText: 'Ví dụ: 10.000.000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                ),
              ),
              if (availableBalance > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Tổng quỹ hiện tại: ${_formatMoney(availableBalance)} đ',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chỉ để tham khảo. Server sẽ kiểm tra quỹ khả dụng riêng của kỳ $selectedMonth/$selectedYear.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final amount = parseMoneyInput(amountController.text);
                if (amount <= 0) {
                  _showFundValidationMessage(
                    'Vui lòng nhập số tiền lớn hơn 0.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Xác nhận chia quỹ'),
            ),
          ],
        ),
      ),
    );
    final amount = parseMoneyInput(amountController.text);
    final note = noteController.text;
    if (confirmed != true || amount <= 0 || !mounted) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    // showDialog hoàn tất Future ngay khi pop được gọi, trước khi animation đóng
    // route kết thúc hẳn. Chờ route cũ deactive xong để không mở result sheet
    // chồng lên và gây assertion `_dependents.isEmpty` của Flutter framework.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    amountController.dispose();
    noteController.dispose();
    if (!mounted) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context
          .read<fp.FinanceProvider>()
          .allocateFundByModel(
            amount: amount,
            periodMonth: selectedMonth,
            periodYear: selectedYear,
            modelId: _currentModelId,
            note: note,
          );
      if (!mounted) return;
      await _showFundAllocationResult(result);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_fundAllocationError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFundValidationMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _fundAllocationError(Object error) {
    if (error is ApiException) {
      final byCode = switch (error.code) {
        // Khóa chống trùng của BE là familyId + kỳ, KHÔNG kèm modelId (chốt
        // 2026-07-28) → đổi mô hình rồi chia lại trong cùng kỳ vẫn bị 409.
        'FUND_ALLOCATION_ALREADY_EXISTS' =>
          'Gia đình đã chia quỹ cho kỳ này. Mỗi tháng chỉ được chia một lần, kể cả khi đổi mô hình.',
        'NO_ACTIVE_FINANCE_MODEL' =>
          'Gia đình chưa có mô hình tài chính đang áp dụng.',
        'INVALID_FINANCE_MODEL' =>
          'Mô hình tài chính không hợp lệ hoặc không thuộc gia đình này.',
        'INVALID_JAR_PERCENTAGE' =>
          'Tổng tỷ lệ các hũ đang hoạt động phải bằng 100%.',
        'INSUFFICIENT_AVAILABLE_FUND' =>
          'Số tiền chia vượt quá quỹ khả dụng của kỳ đã chọn. Tổng quỹ hiện tại không phải hạn mức của mọi tháng.',
        _ => null,
      };
      if (byCode != null) return byCode;
      return switch (error.statusCode) {
        400 =>
          'Không thể chia quỹ: mô hình chưa có hũ hoặc tổng tỷ lệ các hũ chưa bằng 100%.',
        404 =>
          'Không tìm thấy mô hình đang áp dụng. Vui lòng lưu và kích hoạt mô hình trước.',
        409 =>
          'Gia đình đã chia quỹ cho kỳ này. Mỗi tháng chỉ được chia một lần, kể cả khi đổi mô hình.',
        _ => error.message,
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _showFundAllocationHistory() async {
    final selected = await showModalBottomSheet<fp.FundAllocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FundAllocationHistorySheet(),
    );
    if (selected != null && mounted) {
      await _showFundAllocationResult(selected);
    }
  }

  static String _formatMoney(double amount) =>
      amount.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );

  Future<void> _showFundAllocationResult(fp.FundAllocationResult result) {
    final modelName = result.modelName?.trim();
    final period = result.periodMonth != null && result.periodYear != null
        ? 'Kỳ ${result.periodMonth}/${result.periodYear}'
        : 'Kỳ chưa xác định';
    final amount = result.totalAmount == null
        ? 'Số tiền chưa xác định'
        : '${_formatMoney(result.totalAmount!)} đ';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kết quả chia quỹ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${modelName == null || modelName.isEmpty ? 'Mô hình không còn dữ liệu' : modelName} • $period • $amount'
                '${result.createdAt == null ? '' : '\nThực hiện lúc ${_formatAllocationDateTime(result.createdAt)}'}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (result.note != null && result.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Ghi chú: ${result.note}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (result.createdByMemberId != null &&
                  result.createdByMemberId!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Mã thành viên thực hiện: ${result.createdByMemberId}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (result.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Dữ liệu lịch sử cũ không còn đủ thông tin từng hũ.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                ...result.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.jarName.isEmpty ? item.jarCode : item.jarName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${item.allocationPercentage.toStringAsFixed(item.allocationPercentage % 1 == 0 ? 0 : 1)}%',
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${_formatMoney(item.amount)} đ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Hoàn tất'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lưu — flow thật khớp BE (verify 2026-06-26) ───────────────────────────
  //   1. Tạo model mới (BE tự sinh jar mặc định cho FIVE_JARS/EIGHTY_TWENTY)
  //   2. Đồng bộ % người dùng chỉnh khác mặc định → PATCH từng jar
  //   3. CUSTOM: POST jar riêng cho từng khoản người dùng thêm
  //   4. Activate model (BE tự vô hiệu hoá model cũ của gia đình)
  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<fp.FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final modelType = switch (_model) {
        FinanceModelType.fiveJars => 'FIVE_JARS',
        FinanceModelType.eightTwenty => 'EIGHTY_TWENTY',
        FinanceModelType.custom => 'CUSTOM',
      };
      final modelName = switch (_model) {
        FinanceModelType.fiveJars => 'Quy tắc 5 Lọ',
        FinanceModelType.eightTwenty => 'Quy tắc 80/20',
        FinanceModelType.custom => 'Tuỳ chỉnh',
      };

      final created = await provider.createModel(
        modelType: modelType,
        name: modelName,
      );

      if (_model == FinanceModelType.custom) {
        // BE không tự sinh jar cho CUSTOM — tự tạo từng lọ.
        for (var i = 0; i < _customJars.length; i++) {
          final jar = _customJars[i];
          await provider.createJar(
            financeModelId: created.id,
            name: jar.name,
            jarCode: 'CUSTOM_${i + 1}',
            allocationPercentage: jar.percent,
          );
        }
      } else {
        // FIVE_JARS/EIGHTY_TWENTY: BE đã tự tạo jar mặc định kèm theo —
        // patch theo jarCode đã verify, không phụ thuộc thứ tự list.
        final uiJars = _model == FinanceModelType.fiveJars
            ? _fiveJars
            : _twoFunds;

        // BE validate tổng % <= 100 sau MỖI lần PATCH. Nếu patch theo thứ tự
        // list mà một lọ TĂNG trước khi lọ khác GIẢM, tổng trung gian vượt 100%
        // → BE trả "không được vượt quá 100%" dù đích cuối đúng 100%.
        // Cách sửa: gom các lọ cần đổi rồi patch GIẢM trước, TĂNG sau (sort theo
        // delta tăng dần) → tổng chạy luôn <= 100 tại mọi bước.
        final pending = <({String id, double pct, double delta})>[];
        for (final uiJar in uiJars) {
          final realJar = _jarByCode(created.jars, uiJar.jarCode);
          if (realJar == null) continue;
          final delta = uiJar.percent - realJar.allocationPercentage;
          if (delta.abs() >= 0.5) {
            pending.add((id: realJar.id, pct: uiJar.percent, delta: delta));
          }
        }
        pending.sort((a, b) => a.delta.compareTo(b.delta));
        for (final p in pending) {
          await provider.updateJar(p.id, allocationPercentage: p.pct);
        }
      }

      await provider.activateModel(created.id);

      if (mounted) {
        setState(() {
          _currentModelId = created.id;
          _currentModelTypeLabel = modelName;
          _hasLocalEdits = false;
          _loadingCurrent = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã lưu và áp dụng mô hình tài chính'),
            backgroundColor: AppColors.success,
          ),
        );
        // Để _save kết thúc và route hiện tại ổn định trước khi mở dialog kế
        // tiếp. Mở/await dialog ngay trong vòng đời lưu có thể làm Flutter
        // deactive InheritedWidget khi modal vẫn còn dependency.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showFundAllocationDialog();
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FundAllocationHistorySheet extends StatefulWidget {
  const _FundAllocationHistorySheet();

  @override
  State<_FundAllocationHistorySheet> createState() =>
      _FundAllocationHistorySheetState();
}

class _FundAllocationHistorySheetState
    extends State<_FundAllocationHistorySheet> {
  fp.FundAllocationPage? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(1);
      // Cần danh sách thành viên để đổi createdByMemberId thành tên người chia.
      final family = context.read<FamilyProvider>();
      if (family.members.isEmpty) family.fetchMembers();
    });
  }

  /// Tên người chia quỹ, resolve từ `createdByMemberId` qua danh sách thành viên.
  /// Không tra được (chưa nạp member, hoặc người đó đã bị xoá khỏi gia đình) thì
  /// bỏ hẳn khỏi dòng phụ — hiện id thô không giúp gì cho người đọc.
  String? _allocatorName(String? memberId) {
    final id = memberId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final m in context.read<FamilyProvider>().members) {
      if (m.id == id || m.userId == id) {
        return m.name.trim().isEmpty ? null : 'Người chia: ${m.name.trim()}';
      }
    }
    return null;
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<fp.FinanceProvider>()
          .fetchFundAllocations(page: page);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lịch sử chia quỹ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dữ liệu là snapshot tại thời điểm chia; đổi mô hình sau đó không làm thay đổi lịch sử.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _load(result?.page ?? 1),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : result == null || result.items.isEmpty
                    ? const Center(child: Text('Chưa có lần chia quỹ nào.'))
                    : ListView.separated(
                        itemCount: result.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = result.items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.modelName == null || item.modelName!.isEmpty
                                  ? 'Mô hình tài chính (dữ liệu cũ)'
                                  : item.modelName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                item.periodMonth != null &&
                                        item.periodYear != null
                                    ? 'Kỳ ${item.periodMonth}/${item.periodYear} · ${item.items.length} hũ'
                                    : 'Kỳ chưa xác định · ${item.items.length} hũ',
                                if (item.createdAt != null)
                                  'Thực hiện lúc ${_formatAllocationDateTime(item.createdAt)}',
                                // Người chia quỹ — resolve createdByMemberId
                                // sang tên; không tra được thì bỏ dòng.
                                ?_allocatorName(item.createdByMemberId),
                                if (item.note != null && item.note!.isNotEmpty)
                                  'Ghi chú: ${item.note}',
                              ].join('\n'),
                            ),
                            trailing: Text(
                              item.totalAmount == null
                                  ? '—'
                                  : '${_FinanceModelScreenState._formatMoney(item.totalAmount!)} đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
              if (!_loading && result != null && result.totalPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: result.page > 1
                          ? () => _load(result.page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('Trang ${result.page}/${result.totalPages}'),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: result.page < result.totalPages
                          ? () => _load(result.page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatesInfoSheet extends StatefulWidget {
  @override
  State<_TemplatesInfoSheet> createState() => _TemplatesInfoSheetState();
}

class _TemplatesInfoSheetState extends State<_TemplatesInfoSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final t = await context.read<fp.FinanceProvider>().fetchModelTemplates();
      if (mounted) {
        setState(() {
          _templates = t;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          18,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 22,
                  color: AppColors.link,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mẫu mô hình tài chính',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Dữ liệu lấy từ BE, hiển thị lại bằng tiếng Việt để đối chiếu trước khi áp dụng.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _templates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _templateCard(_templates[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateCard(Map<String, dynamic> template) {
    final type = template['modelType']?.toString() ?? '';
    final jars = (template['jars'] as List? ?? []).whereType<Map>().toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppFeatureIcon(
                icon: _templateIcon(type),
                color: AppColors.link,
                backgroundColor: AppColors.link.withValues(alpha: 0.1),
                size: 38,
                iconSize: 20,
                radius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modelTypeLabel(type, template['name']?.toString()),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _templateDescription(type),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (jars.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...jars.map((jar) => _jarRow(Map<String, dynamic>.from(jar))),
          ],
        ],
      ),
    );
  }

  Widget _jarRow(Map<String, dynamic> jar) {
    final code = jar['jarCode']?.toString() ?? '';
    final pct = jar['allocationPercentage']?.toString() ?? '0';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(_jarIcon(code), size: 18, color: _jarColor(code)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _jarLabel(code, jar['name']?.toString()),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _jarDescription(code),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _jarColor(code),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _templateIcon(String type) => switch (type) {
    'FIVE_JARS' => Icons.account_balance_wallet_outlined,
    'EIGHTY_TWENTY' => Icons.call_split_rounded,
    _ => Icons.tune_rounded,
  };

  static String _modelTypeLabel(String type, String? fallback) =>
      switch (type) {
        'FIVE_JARS' => 'Quy tắc 5 lọ',
        'EIGHTY_TWENTY' => 'Quy tắc 80/20',
        'CUSTOM' => 'Tuỳ chỉnh',
        _ => fallback ?? type,
      };

  static String _templateDescription(String type) => switch (type) {
    'FIVE_JARS' => 'Phân bổ thu nhập vào 5 nhóm chi tiêu và tiết kiệm.',
    'EIGHTY_TWENTY' => 'Tách nhanh 80% chi tiêu và 20% tiết kiệm.',
    'CUSTOM' => 'Gia đình tự đặt tên khoản và tỷ lệ phân bổ.',
    _ => 'Mẫu phân bổ thu nhập.',
  };

  static String _jarLabel(String code, String? fallback) => switch (code) {
    'NECESSITIES' => 'Nhu cầu thiết yếu',
    'SAVINGS' => 'Tiết kiệm',
    'EDUCATION' => 'Giáo dục',
    'ENJOYMENT' => 'Vui chơi',
    'GIVING' => 'Cho đi / Biếu tặng',
    'SPENDING' => 'Chi tiêu',
    _ => fallback ?? code,
  };

  static String _jarDescription(String code) => switch (code) {
    'NECESSITIES' => 'Chi phí sinh hoạt và nhu cầu bắt buộc.',
    'SAVINGS' => 'Dự phòng, tiết kiệm dài hạn và mục tiêu tài chính.',
    'EDUCATION' => 'Học tập và phát triển cá nhân.',
    'ENJOYMENT' => 'Giải trí, trải nghiệm và nhu cầu linh hoạt.',
    'GIVING' => 'Quà tặng, biếu tặng hoặc hỗ trợ người khác.',
    'SPENDING' => 'Khoản chi tiêu chính trong tháng.',
    _ => 'Khoản phân bổ tuỳ chỉnh.',
  };

  static IconData _jarIcon(String code) => switch (code) {
    'NECESSITIES' => Icons.home_work_outlined,
    'SAVINGS' => Icons.savings_outlined,
    'EDUCATION' => Icons.school_outlined,
    'ENJOYMENT' => Icons.celebration_outlined,
    'GIVING' => Icons.volunteer_activism_outlined,
    'SPENDING' => Icons.credit_card_rounded,
    _ => Icons.account_balance_wallet_outlined,
  };

  static Color _jarColor(String code) => switch (code) {
    'NECESSITIES' => const Color(0xFF2563EB),
    'SAVINGS' => const Color(0xFF16A34A),
    'EDUCATION' => const Color(0xFFF59E0B),
    'ENJOYMENT' => const Color(0xFFEC4899),
    'GIVING' => const Color(0xFF7C3AED),
    'SPENDING' => const Color(0xFFF97316),
    _ => AppColors.link,
  };
}
