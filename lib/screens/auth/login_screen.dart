import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập email và mật khẩu');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signIn(email, password);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loginDemo(UserRole role, String name) {
    // Demo login đã bị xoá — dùng signIn() thật
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            right: -60, bottom: 200,
            child: Container(
              width: 240, height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGlow,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/FamilyCare_logo.png',
                        height: 350,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quản lý gia đình thông minh',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đăng nhập', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 20),

                        _label('Email'),
                        _inputField(
                          ctrl: _emailCtrl,
                          hint: 'email@example.com',
                          icon: '✉',
                          keyboardType: TextInputType.emailAddress,
                        ),

                        _label('Mật khẩu'),
                        _inputField(
                          ctrl: _passwordCtrl,
                          hint: '••••••••',
                          icon: '🔒',
                          obscure: !_showPass,
                          suffix: GestureDetector(
                            onTap: () => setState(() => _showPass = !_showPass),
                            child: Text(_showPass ? '🙈' : '👁', style: const TextStyle(fontSize: 18)),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Quên mật khẩu?', style: GoogleFonts.inter(fontSize: 13, color: AppColors.link, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.link,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Đăng nhập', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('DEMO ROLE', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _demoButton(
                          emoji: '👑', label: 'Trưởng nhóm', role: 'Family Manager',
                          bg: const Color(0xFFEFF6FF), textColor: AppColors.link,
                          onTap: () => _loginDemo(UserRole.manager, 'Ba Nguyễn'),
                        ),
                        const SizedBox(height: 10),
                        _demoButton(
                          emoji: '🛡️', label: 'Phó nhóm', role: 'Deputy',
                          bg: const Color(0xFFF0FDF4), textColor: const Color(0xFF16A34A),
                          onTap: () => _loginDemo(UserRole.deputy, 'Mẹ Nguyễn'),
                        ),
                        const SizedBox(height: 10),
                        _demoButton(
                          emoji: '🧒', label: 'Thành viên', role: 'Member',
                          bg: const Color(0xFFFFF7ED), textColor: const Color(0xFFEA580C),
                          onTap: () => _loginDemo(UserRole.member, 'An Nguyễn'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Chưa có tài khoản?  ', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text('Đăng ký ngay', style: GoogleFonts.inter(fontSize: 14, color: AppColors.link, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // UC13 — Tham gia gia đình qua lời mời
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push('/join'),
                      child: Text('Có mã mời? Tham gia gia đình →',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
  );

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    required String icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              obscureText: obscure,
              keyboardType: keyboardType,
              decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _demoButton({
    required String emoji, required String label, required String role,
    required Color bg, required Color textColor, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: textColor)),
                Text(role, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
