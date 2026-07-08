import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});
  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Đăng xuất thật (xóa token) rồi mới điều hướng — nếu chỉ go('/login')
  /// thì router redirect sẽ đá ngược về màn hình này vì vẫn còn đăng nhập
  Future<void> _logoutTo(String location) async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go(location);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    setState(() => _loading = true);
    try {
      final familyId = await context.read<FamilyProvider>().createFamily(
            name: name,
            description: _descCtrl.text.trim(),
          );
      if (familyId.isNotEmpty) {
        context.read<FamilyProvider>().familyId = familyId;
      }
      // Người tạo gia đình LUÔN là FAMILY_MANAGER — set và persist role
      final auth = context.read<AuthProvider>();
      await auth.setFamilyRole(UserRole.manager);
      // Cập nhật familyId vào AuthProvider — Wallet/Task/Finance/SOS provider
      // đều nhận familyId từ đây (ProxyProvider trong main.dart), thiếu bước
      // này sẽ lỗi "Chưa có gia đình" cho tới khi restart app
      if (familyId.isNotEmpty) {
        await auth.setActiveFamily(familyId, familyName: name, syncRole: false);
      }
      if (mounted) {
        context.go('/manager/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Tạo gia đình 🏠', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Bạn sẽ là trưởng nhóm và có thể mời thành viên sau.', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Tên gia đình',
                      hint: 'VD: Gia đình Nguyễn',
                      prefixIcon: Icons.home_outlined,
                      validator: (v) => Validators.minLength(v, 2, 'Tên gia đình'),
                    ),
                    AppTextField(
                      controller: _descCtrl,
                      label: 'Mô tả (tùy chọn)',
                      hint: 'Một vài điều về gia đình bạn...',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Tạo gia đình',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _logoutTo('/login'),
                      child: Text('Đăng xuất', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                    ),
                    Text('·', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                    TextButton(
                      onPressed: () => _logoutTo('/register'),
                      child: Text('Đăng ký tài khoản khác', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
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
