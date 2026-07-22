import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart' as fp;
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/app_feature_icon.dart';
import '../../widgets/json_report_view.dart';

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

  // Giá trị mặc định KHỚP với BE thật (verify qua API, không phải số bịa).
  final List<FinanceJarUi> _fiveJars = [
    FinanceJarUi(name: 'Nhu cầu thiết yếu', icon: Icons.home_work_outlined, color: const Color(0xFF2563EB), percent: 50, jarCode: 'NECESSITIES'),
    FinanceJarUi(name: 'Tiết kiệm dài hạn', icon: Icons.savings_outlined, color: const Color(0xFF16A34A), percent: 20, jarCode: 'SAVINGS'),
    FinanceJarUi(name: 'Giáo dục',          icon: Icons.school_outlined, color: const Color(0xFFF59E0B), percent: 10, jarCode: 'EDUCATION'),
    FinanceJarUi(name: 'Vui chơi',          icon: Icons.celebration_outlined, color: const Color(0xFFEC4899), percent: 10, jarCode: 'ENJOYMENT'),
    FinanceJarUi(name: 'Cho đi / Biếu tặng', icon: Icons.volunteer_activism_outlined, color: const Color(0xFF7C3AED), percent: 10, jarCode: 'GIVING'),
  ];

  final List<FinanceJarUi> _twoFunds = [
    FinanceJarUi(name: 'Chi tiêu',  icon: Icons.credit_card_rounded, color: const Color(0xFFF97316), percent: 80, jarCode: 'SPENDING'),
    FinanceJarUi(name: 'Tiết kiệm', icon: Icons.savings_outlined, color: const Color(0xFF16A34A), percent: 20, jarCode: 'SAVINGS'),
  ];

  final List<FinanceJarUi> _customJars = [];
  final _customNameCtrl   = TextEditingController();
  final _customPercentCtrl = TextEditingController();

  List<FinanceJarUi> get _activeJars => switch (_model) {
        FinanceModelType.fiveJars    => _fiveJars,
        FinanceModelType.eightTwenty => _twoFunds,
        FinanceModelType.custom      => _customJars,
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
    await provider.fetchAll();
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
    final realJars = provider.jars.where((j) => j.financeModelId == active.id).toList();
    setState(() {
      _currentModelTypeLabel = switch (active.modelType) {
        'FIVE_JARS'     => 'Quy tắc 5 Lọ',
        'EIGHTY_TWENTY' => 'Quy tắc 80/20',
        _               => active.name,
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
          final colors = [const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF7C3AED)];
          for (var i = 0; i < realJars.length; i++) {
            final j = realJars[i];
            _customJars.add(FinanceJarUi(name: j.name, icon: Icons.account_balance_wallet_outlined, color: colors[i % colors.length], percent: j.allocationPercentage, jarCode: j.jarCode));
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
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Mô hình tài chính',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (_loadingCurrent)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                GestureDetector(
                  onTap: () => _showTemplatesInfo(context),
                  child: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textMuted),
                ),
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (_currentModelTypeLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Đang áp dụng: $_currentModelTypeLabel',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF166534))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                Text('Chọn mô hình phân bổ thu nhập',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 12),

                _modelCard(
                  model: FinanceModelType.fiveJars,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Quy tắc 5 lọ',
                  subtitle: '50% nhu cầu · 20% tiết kiệm · 10% giáo dục · 10% vui chơi · 10% cho đi',
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
                    Text('Cấu hình khoản',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_totalPercent - 100).abs() < 0.5 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tổng: ${_totalPercent.round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (_totalPercent - 100).abs() < 0.5 ? const Color(0xFF166534) : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_model == FinanceModelType.custom) ...[
                  ..._customJars.asMap().entries.map((e) => _jarSlider(e.value, e.key, isCustom: true)),
                  _addCustomJarTile(),
                ] else
                  ..._activeJars.asMap().entries.map((e) => _jarSlider(e.value, e.key)),

                const SizedBox(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_saving || _activeJars.isEmpty || (_totalPercent - 100).abs() >= 0.5) ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Lưu mô hình', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ]),
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
          border: Border.all(color: sel ? AppColors.link : const Color(0xFFE5E7EB), width: sel ? 2 : 1),
        ),
        child: Row(children: [
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? AppColors.link : AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.link, size: 22),
        ]),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
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
            child: Text(jar.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Text('${jar.percent.round()}%', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: jar.color)),
          if (isCustom) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() {
                _customJars.removeAt(idx);
                _hasLocalEdits = true;
              }),
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            ),
          ],
        ]),
        Slider(
          value: jar.percent.clamp(1, 100),
          min: 1, max: 100,
          activeColor: jar.color,
          inactiveColor: jar.color.withValues(alpha: 0.15),
          onChanged: (v) => setState(() {
            jar.percent = v.roundToDouble();
            _hasLocalEdits = true;
          }),
        ),
      ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Thêm khoản mới', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 3,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: _customNameCtrl,
                decoration: InputDecoration(hintText: 'Tên khoản...', hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: _customPercentCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: '%', hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final name = _customNameCtrl.text.trim();
              final pct  = double.tryParse(_customPercentCtrl.text) ?? 0;
              if (name.isEmpty || pct <= 0) return;
              final colors = [const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF7C3AED)];
              setState(() {
                _customJars.add(FinanceJarUi(name: name, icon: Icons.account_balance_wallet_outlined, color: colors[_customJars.length % colors.length], percent: pct));
                _customNameCtrl.clear();
                _customPercentCtrl.clear();
                _hasLocalEdits = true;
              });
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ]),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _TemplatesInfoSheet(),
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
        FinanceModelType.fiveJars    => 'FIVE_JARS',
        FinanceModelType.eightTwenty => 'EIGHTY_TWENTY',
        FinanceModelType.custom      => 'CUSTOM',
      };
      final modelName = switch (_model) {
        FinanceModelType.fiveJars    => 'Quy tắc 5 Lọ',
        FinanceModelType.eightTwenty => 'Quy tắc 80/20',
        FinanceModelType.custom      => 'Tuỳ chỉnh',
      };

      final created = await provider.createModel(modelType: modelType, name: modelName);

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
        final uiJars = _model == FinanceModelType.fiveJars ? _fiveJars : _twoFunds;

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
          _currentModelTypeLabel = modelName;
          _hasLocalEdits = false;
          _loadingCurrent = false;
        });
        messenger.showSnackBar(const SnackBar(
          content: Text('Đã lưu và áp dụng mô hình tài chính'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      if (mounted) setState(() { _templates = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ℹ️ Mẫu mô hình tài chính (BE)', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_error != null)
          Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))
        else
          JsonReportView(data: _templates),
      ]),
    );
  }
}
