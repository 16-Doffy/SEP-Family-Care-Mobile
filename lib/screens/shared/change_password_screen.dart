import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _email => context.read<AuthProvider>().user?.email ?? '';

  Future<void> _sendCode() async {
    if (_email.isEmpty) {
      setState(() => _error = 'Không tìm thấy email tài khoản hiện tại');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/auth/forgot-password', {'email': _email});
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _passwordIssue(String value) {
    if (value.length < 8) return 'Mật khẩu phải từ 8 ký tự';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Cần ít nhất 1 chữ hoa';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Cần ít nhất 1 chữ thường';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Cần ít nhất 1 chữ số';
    if (!value.contains(RegExp(r'[^A-Za-z0-9]'))) {
      return 'Cần ít nhất 1 ký tự đặc biệt';
    }
    if (value != _confirmCtrl.text) return 'Mật khẩu xác nhận chưa khớp';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.post('/auth/reset-password', {
        'email': _email,
        'code': code,
        'newPassword': _passCtrl.text,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await context.read<AuthProvider>().logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Text(
                    'Đổi mật khẩu',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'Tạm thời dùng OTP qua email vì backend chưa có API đổi mật khẩu bằng mật khẩu cũ. Sau khi đổi thành công, bạn cần đăng nhập lại.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
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
                  children: [
                    _readOnlyEmail(email),
                    const SizedBox(height: 14),
                    if (!_codeSent)
                      Text(
                        'Mã OTP 6 số sẽ được gửi tới email tài khoản hiện tại.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      )
                    else ...[
                      _input(
                        _codeCtrl,
                        'Mã OTP',
                        '123456',
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                      _input(
                        _passCtrl,
                        'Mật khẩu mới',
                        'Ít nhất 8 ký tự, có hoa, số, ký tự đặc biệt',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      _input(
                        _confirmCtrl,
                        'Xác nhận mật khẩu mới',
                        'Nhập lại mật khẩu mới',
                        icon: Icons.lock_reset_rounded,
                        obscure: _obscureConfirm,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.link,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : (_codeSent ? _resetPassword : _sendCode),
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _codeSent ? 'Đổi mật khẩu' : 'Gửi mã OTP',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    if (_codeSent)
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _sendCode,
                          child: Text(
                            'Gửi lại mã',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyEmail(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            email.isEmpty ? '-' : email,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    String hint, {
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null
                  ? Icon(icon, size: 20, color: AppColors.textMuted)
                  : null,
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}
