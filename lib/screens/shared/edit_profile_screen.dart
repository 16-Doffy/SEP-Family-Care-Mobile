import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

// UC14 — Quản lý hồ sơ gia đình (Edit Profile)
// Theo FAMILY_CARE_SYSTEM.md Section 7: các trường thông tin tài chính thành viên

// Nghề nghiệp (Occupation) enum — Section 7
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

// Quan hệ trong gia đình — Section 7
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
  final _incomeCtrl  = TextEditingController();
  final _expenseCtrl = TextEditingController();

  Occupation     _occupation = Occupation.employed;
  FamilyRelation _relation   = FamilyRelation.spouse;
  int            _avatarColorIdx = 0;
  bool           _saving = false;

  // 4 màu avatar theo design system
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
      _nameCtrl.text = user.name;
      // Khôi phục avatarColor index
      final colorVal = user.avatarColor;
      _avatarColorIdx = _avatarColors.indexWhere(
          (c) => c.color.value == colorVal);
      if (_avatarColorIdx < 0) _avatarColorIdx = 0;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên không được để trống'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.instance.patch('/users/me', {
        'displayName': _nameCtrl.text.trim(),
        'occupation':  _occupation.name.toUpperCase(),
        'relation':    _relation.name.toUpperCase(),
        if (_incomeCtrl.text.isNotEmpty)
          'avgMonthlyIncome': double.tryParse(_incomeCtrl.text) ?? 0,
        if (_expenseCtrl.text.isNotEmpty)
          'personalExpense': double.tryParse(_expenseCtrl.text) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã cập nhật hồ sơ ✅'),
              backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // Graceful: nếu API chưa sẵn sàng, vẫn cho phép quay lại
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lưu thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Bỏ qua',
              textColor: Colors.white,
              onPressed: () => context.pop(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatarColor = _avatarColors[_avatarColorIdx].color;
    final initials    = _nameCtrl.text.trim().isEmpty
        ? (user?.avatarInitials ?? '?')
        : _initials(_nameCtrl.text.trim());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
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
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              // Nút lưu
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _saving ? AppColors.progressTrack : AppColors.link,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Lưu',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 8),

                // ── Avatar preview + color picker ────────────────
                Center(
                  child: Column(children: [
                    AvatarWidget(
                        initial: initials,
                        color: avatarColor,
                        size: 84),
                    const SizedBox(height: 16),
                    Text('Màu avatar',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _avatarColors.length,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _avatarColorIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _avatarColors[i].color,
                              shape: BoxShape.circle,
                              border: _avatarColorIdx == i
                                  ? Border.all(
                                      color: AppColors.textPrimary, width: 3)
                                  : null,
                              boxShadow: _avatarColorIdx == i
                                  ? [BoxShadow(
                                      color: _avatarColors[i].color
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10)]
                                  : null,
                            ),
                            child: _avatarColorIdx == i
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Thông tin cơ bản ─────────────────────────────
                _sectionLabel('Thông tin cá nhân'),
                _fieldCard(children: [
                  _inputField(
                    ctrl: _nameCtrl,
                    label: 'Họ và tên hiển thị',
                    hint: 'VD: Nguyễn Văn An',
                    icon: Icons.person_outline_rounded,
                    onChanged: (_) => setState(() {}), // rebuild avatar
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Nghề nghiệp ──────────────────────────────────
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
                          Text(o.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(o.label,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: sel
                                        ? AppColors.link
                                        : AppColors.textPrimary)),
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

                // ── Quan hệ trong gia đình ───────────────────────
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
                          Text(r.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r.label,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: sel
                                        ? AppColors.link
                                        : AppColors.textPrimary)),
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

                // ── Tài chính cá nhân ────────────────────────────
                _sectionLabel('Tài chính cá nhân'),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      const Text('ℹ️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Thông tin này dùng để tính ngân sách gia đình. Chỉ Trưởng/Phó nhóm mới xem được.',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF92400E))),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                _fieldCard(children: [
                  _inputField(
                    ctrl: _incomeCtrl,
                    label: 'Thu nhập bình quân / tháng (₫)',
                    hint: 'VD: 10000000',
                    icon: Icons.trending_up_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _inputField(
                    ctrl: _expenseCtrl,
                    label: 'Chi tiêu cá nhân dự kiến / tháng (₫)',
                    hint: 'VD: 3000000',
                    icon: Icons.trending_down_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ]),

                const SizedBox(height: 32),

                // ── Save button ──────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : Text('Lưu hồ sơ',
                            style: GoogleFonts.inter(
                                fontSize: 16,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
      );

  Widget _fieldCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle:
                      GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
          ]),
        ]),
      );
}
