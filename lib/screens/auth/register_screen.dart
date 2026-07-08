import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _famCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _famCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
            _emailCtrl.text.trim(),
            _passCtrl.text,
            _nameCtrl.text.trim(),
            _famCtrl.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header gradient chào mừng ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary400, AppColors.secondary500],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 28)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Tạo tài khoản',
                        style: GoogleFonts.inter(
                            fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Bắt đầu hành trình chăm sóc gia đình bạn 💕',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Form ──
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Họ tên',
                        hint: 'Nguyễn Văn A',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) => Validators.minLength(v, 2, 'Họ tên'),
                      ),
                      AppTextField(
                        controller: _famCtrl,
                        label: 'Tên gia đình',
                        hint: 'Gia đình Nguyễn',
                        prefixIcon: Icons.home_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) => Validators.minLength(v, 2, 'Tên gia đình'),
                      ),
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
                        controller: _passCtrl,
                        label: 'Mật khẩu',
                        hint: 'Ít nhất 8 ký tự, có hoa, số, ký tự đặc biệt',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscure: !_showPass,
                        textInputAction: TextInputAction.next,
                        validator: Validators.strongPassword,
                        suffix: IconButton(
                          icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.textMuted),
                          onPressed: () => setState(() => _showPass = !_showPass),
                        ),
                      ),
                      AppTextField(
                        controller: _confirmCtrl,
                        label: 'Nhập lại mật khẩu',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_reset_rounded,
                        obscure: !_showPass,
                        validator: (v) =>
                            v == _passCtrl.text ? null : 'Mật khẩu nhập lại không khớp',
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '💡 Tài khoản đăng ký trực tiếp sẽ tạo gia đình mới và là Family Manager. Deputy/member tham gia bằng link mời.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Đăng ký',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Đã có tài khoản?  ',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text('Đăng nhập',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.link,
                              fontWeight: FontWeight.w700)),
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
}
