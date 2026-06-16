import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

// UC-FIN-01 — Chọn mô hình tài chính gia đình (5 Jars / 80-20 / Custom)
// UC-FIN-02 — Cấu hình các khoản (Jars / Funds)
// Theo yêu cầu họp 02/06

enum FinanceModel { fiveJars, eightTwenty, custom }

class FinanceJar {
  final String name;
  final String emoji;
  final Color color;
  double percent;

  FinanceJar({required this.name, required this.emoji, required this.color, required this.percent});
}

class FinanceModelScreen extends StatefulWidget {
  const FinanceModelScreen({super.key});
  @override
  State<FinanceModelScreen> createState() => _FinanceModelScreenState();
}

class _FinanceModelScreenState extends State<FinanceModelScreen> {
  FinanceModel _model = FinanceModel.fiveJars;
  bool _saving = false;

  // 5 Jars defaults (% của thu nhập)
  final List<FinanceJar> _fiveJars = [
    FinanceJar(name: 'Nhu cầu thiết yếu', emoji: '🏠', color: const Color(0xFF2563EB), percent: 55),
    FinanceJar(name: 'Tiết kiệm dài hạn', emoji: '🐖', color: const Color(0xFF16A34A), percent: 10),
    FinanceJar(name: 'Giáo dục',          emoji: '📚', color: const Color(0xFFF59E0B), percent: 10),
    FinanceJar(name: 'Vui chơi',          emoji: '🎉', color: const Color(0xFFEC4899), percent: 10),
    FinanceJar(name: 'Quỹ dự phòng',      emoji: '🛡️', color: const Color(0xFF7C3AED), percent: 15),
  ];

  // 80-20 defaults
  final List<FinanceJar> _twoFunds = [
    FinanceJar(name: 'Chi tiêu (80%)',  emoji: '💳', color: const Color(0xFFF97316), percent: 80),
    FinanceJar(name: 'Tiết kiệm (20%)', emoji: '💰', color: const Color(0xFF16A34A), percent: 20),
  ];

  // Custom — user tự thêm
  final List<FinanceJar> _customJars = [];
  final _customNameCtrl   = TextEditingController();
  final _customPercentCtrl = TextEditingController();

  List<FinanceJar> get _activeJars {
    switch (_model) {
      case FinanceModel.fiveJars:     return _fiveJars;
      case FinanceModel.eightTwenty:  return _twoFunds;
      case FinanceModel.custom:       return _customJars;
    }
  }

  double get _totalPercent => _activeJars.fold(0, (s, j) => s + j.percent);

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customPercentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
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
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Text('Chọn mô hình phân bổ thu nhập',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 12),

                // Model selector
                _modelCard(
                  model: FinanceModel.fiveJars,
                  emoji: '🫙',
                  title: 'Quy tắc 5 Lọ (5 Jars)',
                  subtitle: '55% nhu cầu · 10% tiết kiệm · 10% giáo dục · 10% vui chơi · 15% dự phòng',
                ),
                const SizedBox(height: 10),
                _modelCard(
                  model: FinanceModel.eightTwenty,
                  emoji: '✂️',
                  title: 'Quy tắc 80/20',
                  subtitle: '80% chi tiêu tự do · 20% tiết kiệm',
                ),
                const SizedBox(height: 10),
                _modelCard(
                  model: FinanceModel.custom,
                  emoji: '⚙️',
                  title: 'Tuỳ chỉnh',
                  subtitle: 'Tự thiết lập các khoản & tỷ lệ phân bổ',
                ),
                const SizedBox(height: 20),

                // Jar configuration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cấu hình khoản',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                if (_model == FinanceModel.custom) ...[
                  ..._customJars.asMap().entries.map((e) => _jarSlider(e.value, e.key, isCustom: true)),
                  _addCustomJarTile(),
                ] else
                  ..._activeJars.asMap().entries.map((e) => _jarSlider(e.value, e.key)),

                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_saving || (_totalPercent - 100).abs() >= 0.5) ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    required FinanceModel model,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    final sel = _model == model;
    return GestureDetector(
      onTap: () => setState(() => _model = model),
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
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                  color: sel ? AppColors.link : AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.link, size: 22),
        ]),
      ),
    );
  }

  Widget _jarSlider(FinanceJar jar, int idx, {bool isCustom = false}) {
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
          Text(jar.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(jar.name,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Text('${jar.percent.round()}%',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: jar.color)),
          if (isCustom) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _customJars.removeAt(idx)),
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            ),
          ],
        ]),
        Slider(
          value: jar.percent,
          min: 1, max: 100,
          activeColor: jar.color,
          inactiveColor: jar.color.withValues(alpha: 0.15),
          onChanged: (v) => setState(() => jar.percent = v.roundToDouble()),
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
        Text('Thêm khoản mới',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                decoration: InputDecoration(
                  hintText: 'Tên khoản...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
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
                decoration: InputDecoration(
                  hintText: '%',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
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
              final colors = [const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFF59E0B),
                              const Color(0xFFEC4899), const Color(0xFF7C3AED)];
              setState(() {
                _customJars.add(FinanceJar(
                  name: name, emoji: '💼',
                  color: colors[_customJars.length % colors.length],
                  percent: pct,
                ));
                _customNameCtrl.clear();
                _customPercentCtrl.clear();
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final modelStr = switch (_model) {
        FinanceModel.fiveJars    => 'FIVE_JARS',
        FinanceModel.eightTwenty => 'EIGHTY_TWENTY',
        FinanceModel.custom      => 'CUSTOM',
      };
      // WalletProvider.saveFinanceModel API call
      await ApiClient.instance.post(
        ApiClient.instance.familyPath('/finance/models'),
        {'modelType': modelStr, 'name': modelStr},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu mô hình tài chính ✅'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
