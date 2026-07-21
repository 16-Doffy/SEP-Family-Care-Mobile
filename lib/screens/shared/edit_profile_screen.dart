import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/money_input.dart';

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
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _expenseCtrl = TextEditingController();
  final _sharedCtrl = TextEditingController();

  bool _savingFinance = false;
  bool _loadingFinance = true;
  bool _incomeShared = false;
  bool _expenseShared = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone ?? '';
    }
    // Load monthly finance data
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonthlyFinance());
  }

  Future<void> _loadMonthlyFinance() async {
    setState(() => _loadingFinance = true);
    try {
      final auth = context.read<AuthProvider>();
      final finance = context.read<FinanceProvider>();
      await auth.refreshMe(); // also refreshes phone
      final now = DateTime.now();
      final summary = await finance.fetchMonthlySummaryMe(
        month: now.month,
        year: now.year,
      );
      final monthly = summary?.monthlyFinance;
      if (mounted) {
        _phoneCtrl.text = auth.user?.phone ?? '';
        if (monthly != null) {
          _incomeCtrl.text = _formatInputMoney(monthly.expectedIncome);
          _expenseCtrl.text = _formatInputMoney(
            monthly.expectedPersonalExpense,
          );
          _sharedCtrl.text = _formatInputMoney(
            monthly.expectedSharedContribution,
          );
          _incomeShared = monthly.incomeVisibility == 'FAMILY';
          _expenseShared = monthly.expenseVisibility == 'FAMILY';
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFinance = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    _sharedCtrl.dispose();
    super.dispose();
  }

  // Lưu thu nhập/chi tiêu tháng → POST/PUT /finance/monthly-finances/me
  Future<void> _saveFinance() async {
    final income = _parseOptionalMoney(_incomeCtrl.text);
    final expense = _parseOptionalMoney(_expenseCtrl.text);
    final shared = _parseOptionalMoney(_sharedCtrl.text);
    if (income == null && expense == null && shared == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập ít nhất một giá trị tài chính'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _savingFinance = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().upsertMonthlyFinance(
        expectedIncome: income,
        expectedPersonalExpense: expense,
        expectedSharedContribution: shared,
        incomeVisibility: _incomeShared ? 'FAMILY' : 'PRIVATE',
        expenseVisibility: _expenseShared ? 'FAMILY' : 'PRIVATE',
      );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã lưu tài chính tháng ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFinance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                        'Chỉnh sửa hồ sơ',
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),

                  // Avatar preview (read-only until BE supports user avatar updates)
                  Center(
                    child: Column(
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _nameCtrl,
                          builder: (_, value, _) {
                            final initials = value.text.trim().isEmpty
                                ? (user?.avatarInitials ?? '?')
                                : _initials(value.text.trim());
                            return AvatarWidget(
                              initial: initials,
                              color: Color(
                                user?.avatarColor ??
                                    AppColors.avatarBlue.toARGB32(),
                              ),
                              size: 84,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Avatar đang lấy theo vai trò trong gia đình',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Thông tin cá nhân (read-only — cần PATCH /auth/me từ BE) ──
                  _sectionLabel('Thông tin cá nhân'),
                  _fieldCard(
                    children: [
                      _inputField(
                        ctrl: _nameCtrl,
                        label: 'Họ và tên hiển thị',
                        hint: 'VD: Nguyễn Văn An',
                        icon: Icons.person_outline_rounded,
                        enabled: false,
                      ),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _inputField(
                        ctrl: _phoneCtrl,
                        label: 'Số điện thoại',
                        hint: 'VD: 0901234567',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        enabled: false,
                      ),
                    ],
                  ),
                  _infoNote(
                    'Để chỉnh sửa tên và số điện thoại, vui lòng liên hệ quản trị viên hoặc chờ tính năng cập nhật.',
                  ),
                  const SizedBox(height: 16),

                  _comingSoonCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Nghề nghiệp',
                    message:
                        'Backend chưa có field lưu nghề nghiệp, nên mục này tạm thời chỉ hiển thị khi có API chính thức.',
                  ),
                  const SizedBox(height: 12),
                  _comingSoonCard(
                    icon: Icons.diversity_3_rounded,
                    title: 'Quan hệ trong gia đình',
                    message:
                        'Quan hệ thành viên hiện lấy từ danh sách gia đình. Chỉnh sửa quan hệ cần endpoint quản lý member từ backend.',
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
                    child: Row(
                      children: [
                        const Text('ℹ️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dùng để tính ngân sách gia đình. Trưởng/Phó nhóm có thể xem nếu bạn chọn "Chia sẻ".',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _fieldCard(
                    children: [
                      _inputField(
                        ctrl: _incomeCtrl,
                        label: 'Thu nhập dự kiến / tháng (₫)',
                        hint: 'VD: 10.000.000',
                        icon: Icons.trending_up_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsSeparatorInputFormatter()],
                      ),
                      _visibilitySwitch(
                        label: 'Chia sẻ thu nhập với Trưởng/Phó nhóm',
                        value: _incomeShared,
                        onChanged: (v) => setState(() => _incomeShared = v),
                      ),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _inputField(
                        ctrl: _expenseCtrl,
                        label: 'Chi tiêu cá nhân dự kiến / tháng (₫)',
                        hint: 'VD: 3.000.000',
                        icon: Icons.trending_down_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsSeparatorInputFormatter()],
                      ),
                      _visibilitySwitch(
                        label: 'Chia sẻ chi tiêu với Trưởng/Phó nhóm',
                        value: _expenseShared,
                        onChanged: (v) => setState(() => _expenseShared = v),
                      ),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _inputField(
                        ctrl: _sharedCtrl,
                        label: 'Đóng góp chung dự kiến / tháng (₫)',
                        hint: 'VD: 1.000.000',
                        icon: Icons.savings_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsSeparatorInputFormatter()],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingFinance) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đang tải dữ liệu tháng này...',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _savingFinance ? null : _saveFinance,
                      child: _savingFinance
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : Text(
                              'Lưu tài chính tháng',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _infoNote(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
    ),
  );

  Widget _fieldCard({required List<Widget> children}) => Container(
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
      children: children,
    ),
  );

  Widget _comingSoonCard({
    required IconData icon,
    required String title,
    required String message,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sắp có',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _visibilitySwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
    child: Row(
      children: [
        const Icon(
          Icons.visibility_outlined,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.success,
        ),
      ],
    ),
  );

  String _formatInputMoney(double? value) {
    if (value == null) return '';
    return ThousandsSeparatorInputFormatter.formatThousands(
      value.round().toString(),
    );
  }

  double? _parseOptionalMoney(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.textMuted : AppColors.textSecondary,
            ),
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
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (!enabled)
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ],
    ),
  );
}
