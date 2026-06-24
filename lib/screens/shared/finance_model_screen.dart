import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';

const _modelMeta = {
  'FIVE_JARS': (icon: '🏺', name: '5 Hũ chi tiêu', desc: 'Thiết yếu · Không thiết yếu · Tiết kiệm · Giáo dục · Dự phòng'),
  'EIGHTY_TWENTY': (icon: '✨', name: 'Quy tắc 80/20', desc: '80% chi tiêu · 20% tiết kiệm'),
  'CUSTOM': (icon: '🎨', name: 'Tự tạo', desc: 'Tự định nghĩa số hũ và % cho từng hũ'),
};

const _jarColors = [
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
  Color(0xFF10B981), // green
  Color(0xFFF59E0B), // amber
  Color(0xFF06B6D4), // cyan
  Color(0xFFEC4899), // pink
];

class FinanceModelScreen extends StatefulWidget {
  const FinanceModelScreen({super.key});
  @override
  State<FinanceModelScreen> createState() => _FinanceModelScreenState();
}

class _FinanceModelScreenState extends State<FinanceModelScreen> {
  bool _activating = false;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final activeModel = finance.activeModel;
    final jars = finance.activeJars;
    final otherModels = <FinanceModel>[];
    final seenModelKeys = <String>{};
    for (final model in finance.models) {
      if (model.id == activeModel?.id) continue;
      final key = '${model.modelType}|${model.name}';
      if (seenModelKeys.add(key)) otherModels.add(model);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                ),
              ),
              Expanded(child: Center(child: Text('Mô hình tài chính',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              const SizedBox(width: 40),
            ]),
          ),

          Expanded(
            child: finance.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => finance.fetchAll(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      children: [
                        // Current active model banner
                        if (activeModel != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.heroOrange, AppColors.heroPurple]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(children: [
                              Text(_modelMeta[activeModel.modelType]?.icon ?? '💡', style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Đang dùng', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                                Text(activeModel.name.isNotEmpty ? activeModel.name : (_modelMeta[activeModel.modelType]?.name ?? activeModel.modelType),
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 20),
                        ],

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            'Ứng dụng chỉ tính tiền theo mô hình đang dùng. Các mô hình cũ được giữ như lịch sử nên có thể trùng tên, nhưng không tạo thêm hũ trên màn này.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Model list
                        Text('Chọn mô hình', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        ...otherModels.map((m) {
                          final meta = _modelMeta[m.modelType];
                          final isActive = m.status == 'ACTIVE';
                          return _ModelCard(
                            icon: meta?.icon ?? '💡',
                            name: meta?.name ?? m.name,
                            desc: meta?.desc ?? '',
                            isActive: isActive,
                            isActivating: _activating,
                            onActivate: isActive ? null : () => _activateModel(m.id),
                          );
                        }),

                        // Create new model — chọn từ mẫu chuẩn (FIVE_JARS/EIGHTY_TWENTY)
                        // hoặc tự tạo (CUSTOM). BE tự sinh sẵn các hũ mặc định cho
                        // 2 mẫu chuẩn, nên sau khi tạo chỉ cần chỉnh % ở phần dưới.
                        if (!finance.models.any((m) => m.modelType == 'FIVE_JARS')) ...[
                          const SizedBox(height: 8),
                          _TemplateModelCard(
                            modelType: 'FIVE_JARS',
                            icon: '🏺',
                            name: '5 Hũ chi tiêu',
                            desc: 'Thiết yếu · Không thiết yếu · Tiết kiệm · Giáo dục · Dự phòng',
                            onCreated: () => finance.fetchAll(),
                          ),
                        ],
                        if (!finance.models.any((m) => m.modelType == 'EIGHTY_TWENTY')) ...[
                          const SizedBox(height: 8),
                          _TemplateModelCard(
                            modelType: 'EIGHTY_TWENTY',
                            icon: '✨',
                            name: 'Quy tắc 80/20',
                            desc: '80% chi tiêu · 20% tiết kiệm',
                            onCreated: () => finance.fetchAll(),
                          ),
                        ],

                        // Create new model if no custom exists
                        if (!finance.models.any((m) => m.modelType == 'CUSTOM')) ...[
                          const SizedBox(height: 8),
                          _CreateModelCard(onCreated: () => finance.fetchAll()),
                        ],

                        // Jar configuration
                        if (jars.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Cấu hình hũ', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Tổng phải đạt 100%', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 12),
                          _JarConfigCard(jars: jars, onSaved: () => finance.fetchAll()),
                        ],

                        // Categories
                        const SizedBox(height: 24),
                        Text('Danh mục tài chính', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Dùng để gắn vào dòng ngân sách và giao dịch', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        _CategoriesCard(categories: finance.categories, onCreated: () => finance.fetchAll()),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Future<void> _activateModel(String modelId) async {
    setState(() => _activating = true);
    try {
      await context.read<FinanceProvider>().activateModel(modelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã kích hoạt mô hình ✅'), backgroundColor: AppColors.success),
        );
        context.read<FinanceProvider>().fetchAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }
}

class _ModelCard extends StatelessWidget {
  final String icon, name, desc;
  final bool isActive, isActivating;
  final VoidCallback? onActivate;

  const _ModelCard({required this.icon, required this.name, required this.desc,
      required this.isActive, required this.isActivating, this.onActivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0FDF4) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: AppColors.success, width: 1.5) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                child: Text('Đang dùng', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
            ],
          ]),
          Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        if (!isActive)
          GestureDetector(
            onTap: isActivating ? null : onActivate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(10)),
              child: isActivating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Dùng', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}

class _TemplateModelCard extends StatefulWidget {
  final String modelType, icon, name, desc;
  final VoidCallback onCreated;
  const _TemplateModelCard({
    required this.modelType, required this.icon, required this.name,
    required this.desc, required this.onCreated,
  });
  @override
  State<_TemplateModelCard> createState() => _TemplateModelCardState();
}

class _TemplateModelCardState extends State<_TemplateModelCard> {
  bool _creating = false;

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await context.read<FinanceProvider>().createModel(modelType: widget.modelType, name: widget.name);
      widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo mô hình "${widget.name}" ✅'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: Row(children: [
        Text(widget.icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(widget.desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        GestureDetector(
          onTap: _creating ? null : _create,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(10)),
            child: _creating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Tạo', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _CreateModelCard extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateModelCard({required this.onCreated});
  @override
  State<_CreateModelCard> createState() => _CreateModelCardState();
}

class _CreateModelCardState extends State<_CreateModelCard> {
  bool _show = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return GestureDetector(
        onTap: () => setState(() => _show = true),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.link, style: BorderStyle.solid),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_circle_outline, color: AppColors.link, size: 20),
            const SizedBox(width: 8),
            Text('Tạo mô hình tùy chỉnh', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.link)),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.link),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tên mô hình', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            hintText: 'VD: Mô hình của tôi',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _saving ? null : () async {
                if (_nameCtrl.text.trim().isEmpty) return;
                setState(() => _saving = true);
                try {
                  await context.read<FinanceProvider>().createModel(modelType: 'CUSTOM', name: _nameCtrl.text.trim());
                  widget.onCreated();
                  if (mounted) setState(() { _show = false; _saving = false; });
                } catch (e) {
                  if (mounted) {
                    setState(() => _saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                }
              },
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Tạo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => setState(() => _show = false), child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textMuted))),
        ]),
      ]),
    );
  }
}

class _CategoriesCard extends StatefulWidget {
  final List<FinanceCategory> categories;
  final VoidCallback onCreated;
  const _CategoriesCard({required this.categories, required this.onCreated});
  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
  bool _show = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  String _categoryType = 'EXPENSE';
  String _essentialType = 'NEUTRAL';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<FinanceProvider>().createCategory(
        name: _nameCtrl.text.trim(),
        categoryType: _categoryType,
        essentialType: _essentialType,
      );
      widget.onCreated();
      if (mounted) {
        _nameCtrl.clear();
        setState(() => _show = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.categories.isEmpty)
          Text('Chưa có danh mục nào.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.categories.map((c) {
              final isIncome = c.categoryType == 'INCOME';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(c.name,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                        color: isIncome ? AppColors.success : AppColors.textSecondary)),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        if (!_show)
          GestureDetector(
            onTap: () => setState(() => _show = true),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_circle_outline, color: AppColors.link, size: 18),
              const SizedBox(width: 6),
              Text('Thêm danh mục', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.link)),
            ]),
          )
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'VD: Tiền điện, Học phí...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                filled: true, fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _segButton('EXPENSE', 'Chi tiêu', _categoryType, (v) => setState(() => _categoryType = v))),
              const SizedBox(width: 8),
              Expanded(child: _segButton('INCOME', 'Thu nhập', _categoryType, (v) => setState(() => _categoryType = v))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _segButton('ESSENTIAL', 'Thiết yếu', _essentialType, (v) => setState(() => _essentialType = v))),
              const SizedBox(width: 8),
              Expanded(child: _segButton('NON_ESSENTIAL', 'Không thiết yếu', _essentialType, (v) => setState(() => _essentialType = v))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _saving ? null : _create,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Tạo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => _show = false), child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textMuted))),
            ]),
          ]),
      ]),
    );
  }

  Widget _segButton(String value, String label, String current, ValueChanged<String> onTap) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.link : AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _JarConfigCard extends StatefulWidget {
  final List<FinanceJar> jars;
  final VoidCallback onSaved;
  const _JarConfigCard({required this.jars, required this.onSaved});
  @override
  State<_JarConfigCard> createState() => _JarConfigCardState();
}

class _JarConfigCardState extends State<_JarConfigCard> {
  late List<TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrls = widget.jars.map((j) => TextEditingController(text: j.allocationPercentage.round().toString())).toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  double get _total => _ctrls.fold(0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    final ok = (_total - 100).abs() < 0.5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...List.generate(widget.jars.length, (i) {
          final jar = widget.jars[i];
          final color = _jarColors[i % _jarColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(jar.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _ctrls[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    suffixText: '%',
                    filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          );
        }),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: List.generate(widget.jars.length, (i) {
              final pct = (double.tryParse(_ctrls[i].text) ?? 0)
                  .clamp(0.0, 100.0)
                  .toDouble();
              return Flexible(
                flex: pct <= 0 ? 1 : pct.round(),
                child: Container(height: 8, color: _jarColors[i % _jarColors.length]),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tổng: ${_total.round()}%',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                  color: ok ? AppColors.success : AppColors.danger)),
          if (!ok) Text('Cần đủ 100%', style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
        ]),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ok ? AppColors.link : AppColors.textMuted,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_saving || !ok) ? null : () => _save(context),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Lưu cấu hình', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _saving = true);
    try {
      final provider = context.read<FinanceProvider>();
      for (int i = 0; i < widget.jars.length; i++) {
        final pct = double.tryParse(_ctrls[i].text) ?? widget.jars[i].allocationPercentage;
        await provider.updateJar(widget.jars[i].id, allocationPercentage: pct);
      }
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình hũ ✅'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
