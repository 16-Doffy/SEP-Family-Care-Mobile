import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

enum Occupation {
  employed('Đi làm', '💼'),
  student('Học sinh / Sinh viên', '📚'),
  retired('Hưu trí', '🏖️'),
  homemaker('Nội trợ', '🏠'),
  other('Khác', '✨');

  final String label;
  final String emoji;
  const Occupation(this.label, this.emoji);
}

enum FamilyRelation {
  spouse('Vợ / Chồng', '💑'),
  child('Con cái', '👧'),
  parent('Cha / Mẹ', '👨‍👩‍👧'),
  grandparent('Ông / Bà', '👴'),
  sibling('Anh / Chị / Em', '👫'),
  other('Khác', '👤');

  final String label;
  final String emoji;
  const FamilyRelation(this.label, this.emoji);
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _incomeCtrl  = TextEditingController();
  final _expenseCtrl = TextEditingController();

  Occupation     _occupation     = Occupation.employed;
  FamilyRelation _relation       = FamilyRelation.spouse;
  int            _avatarColorIdx = 0;
  bool           _savingFinance  = false;

  static const _avatarColors = [
    (color: AppColors.avatarBlue,   label: 'Xanh dương'),
    (color: AppColors.avatarPurple, label: 'Tím'),
    (color: AppColors.avatarOrange, label: 'Cam'),
    (color: AppColors.avatarTeal,   label: 'Xanh ngọc'),
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text  = user.name;
      _phoneCtrl.text = user.phone ?? '';
      final colorVal  = user.avatarColor;
      _avatarColorIdx = _avatarColors
          .indexWhere((c) => c.color.toARGB32() == colorVal);
      if (_avatarColorIdx < 0) _avatarColorIdx = 0;
    }
    // Load monthly finance data
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonthlyFinance());
  }

  Future<void> _loadMonthlyFinance() async {
    // Pre-populate income/expense if already declared this month
    // (best-effort — field stays empty if not declared yet)
    try {
      final auth = context.read<AuthProvider>();
      await auth.refreshMe(); // also refreshes phone
      if (mounted) {
        _phoneCtrl.text = auth.user?.phone ?? '';
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    super.dispose();
  }

  // Lưu thu nhập/chi tiêu tháng → POST/PUT /finance/monthly-finances/me
  Future<void> _saveFinance() async {
    final income  = double.tryParse(_incomeCtrl.text.replaceAll(',', ''));
    final expense = double.tryParse(_expenseCtrl.text.replaceAll(',', ''));
    if (income == null && expense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ít nhất một trong hai giá trị'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _savingFinance = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().saveMonthlyFinance(
        expectedIncome:  income  ?? 0,
        expectedExpense: expense ?? 0,
      );
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Đã lưu tài chính tháng ✅'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _savingFinance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user        = context.watch<AuthProvider>().user;
    final avatarColor = _avatarColors[_avatarColorIdx].color;

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
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Chỉnh sửa hồ sơ',
                      style: TextStyle(fontSize: 17,
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
                const SizedBox(height: 8),

                // Avatar preview + color picker
                Center(
                  child: Column(children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _nameCtrl,
                      builder: (_, value, _) {
                        final initials = value.text.trim().isEmpty
                            ? (user?.avatarInitials ?? '?')
                            : _initials(value.text.trim());
                        return AvatarWidget(
                            initial: initials,
                            color: avatarColor,
                            size: 84);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Màu avatar',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_avatarColors.length, (i) =>
                        GestureDetector(
                          onTap: () => setState(() => _avatarColorIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _avatarColors[i].color,
                              shape: BoxShape.circle,
                              border: _avatarColorIdx == i
                                  ? Border.all(color: AppColors.textPrimary, width: 3)
                                  : null,
                              boxShadow: _avatarColorIdx == i
                                  ? [BoxShadow(
                                      color: _avatarColors[i].color.withValues(alpha: 0.4),
                                      blurRadius: 10)]
                                  : null,
                            ),
                            child: _avatarColorIdx == i
                                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Thông tin cá nhân (read-only — cần PATCH /auth/me từ BE) ──
                _sectionLabel('Thông tin cá nhân'),
                _fieldCard(children: [
                  _inputField(
                    ctrl:  _nameCtrl,
                    label: 'Họ và tên hiển thị',
                    hint:  'VD: Nguyễn Văn An',
                    icon:  Icons.person_outline_rounded,
                    enabled: false,
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _inputField(
                    ctrl:            _phoneCtrl,
                    label:           'Số điện thoại',
                    hint:            'VD: 0901234567',
                    icon:            Icons.phone_outlined,
                    keyboardType:    TextInputType.phone,
                    enabled:         false,
                  ),
                ]),
                _infoNote('Để chỉnh sửa tên và số điện thoại, vui lòng liên hệ quản trị viên hoặc chờ tính năng cập nhật.'),
                const SizedBox(height: 16),

                // ── Nghề nghiệp ──
                _sectionLabel('Nghề nghiệp'),
                _fieldCard(
                  children: Occupation.values.map((o) {
                    final sel = _occupation == o;
                    return GestureDetector(
                      onTap: () => setState(() => _occupation = o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.link.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Text(o.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(o.label,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                    color: sel ? AppColors.link : AppColors.textPrimary)),
                          ),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppColors.link),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Quan hệ trong gia đình ──
                _sectionLabel('Quan hệ trong gia đình'),
                _fieldCard(
                  children: FamilyRelation.values.map((r) {
                    final sel = _relation == r;
                    return GestureDetector(
                      onTap: () => setState(() => _relation = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.link.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Text(r.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r.label,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                    color: sel ? AppColors.link : AppColors.textPrimary)),
                          ),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppColors.link),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Tài chính tháng này (kết nối API thực) ──
                _sectionLabel('Tài chính tháng này'),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Dùng để tính ngân sách gia đình. Trưởng/Phó nhóm có thể xem nếu bạn chọn "Chia sẻ".',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF92400E))),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                _fieldCard(children: [
                  _inputField(
                    ctrl:            _incomeCtrl,
                    label:           'Thu nhập dự kiến / tháng (₫)',
                    hint:            'VD: 10,000,000',
                    icon:            Icons.trending_up_rounded,
                    keyboardType:    TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _inputField(
                    ctrl:            _expenseCtrl,
                    label:           'Chi tiêu cá nhân dự kiến / tháng (₫)',
                    hint:            'VD: 3,000,000',
                    icon:            Icons.trending_down_rounded,
                    keyboardType:    TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _savingFinance ? null : _saveFinance,
                    child: _savingFinance
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text('Lưu tài chính tháng',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
      );

  Widget _infoNote(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      );

  Widget _fieldCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(icon, size: 18,
                color: enabled ? AppColors.textMuted : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              ),
            ),
            if (!enabled)
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textMuted),
          ]),
        ]),
      );
}
