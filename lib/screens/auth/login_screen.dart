import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signIn(email, password);
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
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đăng nhập', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 20),

                          AppTextField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'email@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                          ),
                          AppTextField(
                            controller: _passwordCtrl,
                            label: 'Mật khẩu',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscure: !_showPass,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) => Validators.notEmpty(v, 'mật khẩu'),
                            suffix: IconButton(
                              icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20, color: AppColors.textMuted),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            ),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('Quên mật khẩu?', style: GoogleFonts.inter(fontSize: 13, color: AppColors.link, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 20),

                          PrimaryButton(
                            label: 'Đăng nhập',
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
