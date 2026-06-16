import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _famCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _famCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name   = _nameCtrl.text.trim();
    final family = _famCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final phone  = _phoneCtrl.text.trim();
    final pass   = _passCtrl.text;

    if (name.isEmpty || family.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Vui lòng điền đầy đủ thông tin bắt buộc');
      return;
    }
    if (!email.contains('@')) {
      _showError('Email không hợp lệ');
      return;
    }
    if (pass.length < 6) {
      _showError('Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        email,
        pass,
        name,
        phone: phone.isNotEmpty ? phone : null,
        familyName: family,
      );
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(children: [
            // Header
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              ),
              Text('Tạo tài khoản',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 24),

            // Form card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    ctrl: _nameCtrl,
                    label: 'Họ và tên',
                    hint: 'Nguyễn Văn A',
                    icon: Icons.person_outline_rounded,
                  ),
                  _field(
                    ctrl: _famCtrl,
                    label: 'Tên gia đình',
                    hint: 'Gia đình Nguyễn',
                    icon: Icons.home_outlined,
                  ),
                  _field(
                    ctrl: _emailCtrl,
                    label: 'Email',
                    hint: 'email@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _field(
                    ctrl: _phoneCtrl,
                    label: 'Số điện thoại',
                    hint: '0901 234 567  (không bắt buộc)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    required: false,
                  ),
                  _passwordField(),
                  const SizedBox(height: 4),

                  // Ghi chú vai trò
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.link.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Text('👑', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Người đăng ký đầu tiên sẽ là Trưởng nhóm gia đình. Các thành viên khác tham gia qua link / QR / mã mời.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.link,
                              height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.link,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Đăng ký',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Đã có tài khoản
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textMuted),
                          children: [
                            const TextSpan(text: 'Đã có tài khoản? '),
                            TextSpan(
                              text: 'Đăng nhập',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.link,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            if (!required)
              Text(' (tuỳ chọn)',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Mật khẩu',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                    hintText: 'Ít nhất 6 ký tự',
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
