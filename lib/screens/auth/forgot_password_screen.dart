import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

/// UC Quên mật khẩu (BE bổ sung 2026-07-10):
///   Bước 1: POST /auth/forgot-password {email}   → BE gửi OTP 6 số qua email
///   Bước 2: POST /auth/reset-password {email, code, newPassword}
/// Mật khẩu mới theo chuẩn BE: ≥8 ký tự, có hoa, thường, số, ký tự đặc biệt.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Vui lòng nhập email hợp lệ');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/forgot-password', {'email': email});
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _passwordIssue(String p) {
    if (p.length < 8) return 'Mật khẩu phải từ 8 ký tự';
    if (!p.contains(RegExp(r'[A-Z]'))) return 'Cần ít nhất 1 chữ hoa';
    if (!p.contains(RegExp(r'[a-z]'))) return 'Cần ít nhất 1 chữ thường';
    if (!p.contains(RegExp(r'[0-9]'))) return 'Cần ít nhất 1 chữ số';
    if (!p.contains(RegExp(r'[^A-Za-z0-9]'))) return 'Cần ít nhất 1 ký tự đặc biệt (@, #, !...)';
    return null;
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Mã OTP gồm 6 chữ số');
      return;
    }
    final issue = _passwordIssue(_passCtrl.text);
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/reset-password', {
        'email': _emailCtrl.text.trim(),
        'code': code,
        'newPassword': _passCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đặt lại mật khẩu thành công! Hãy đăng nhập lại.'),
        backgroundColor: AppColors.safe,
      ));
      context.go('/login');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
              ),
              Text('Quên mật khẩu',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _codeSent
                      ? 'Mã OTP 6 số đã gửi tới ${_emailCtrl.text.trim()}. Nhập mã và mật khẩu mới bên dưới.'
                      : 'Nhập email tài khoản — chúng tôi sẽ gửi mã OTP để đặt lại mật khẩu.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 18),

                if (!_codeSent)
                  _input(_emailCtrl, 'Email', 'email@example.com',
                      icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress)
                else ...[
                  _input(_codeCtrl, 'Mã OTP', '123456',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
                  _input(_passCtrl, 'Mật khẩu mới', 'Ít nhất 8 ký tự, có hoa, số, ký tự đặc biệt',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20, color: AppColors.textMuted),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.danger)),
                ],
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loading ? null : (_codeSent ? _resetPassword : _sendCode),
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_codeSent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                if (_codeSent)
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _sendCode,
                      child: Text('Gửi lại mã', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, String hint,
      {IconData? icon, bool obscure = false, TextInputType? keyboardType,
      List<TextInputFormatter>? formatters, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.textMuted) : null,
            suffixIcon: suffix,
          ),
        ),
      ]),
    );
  }
}
