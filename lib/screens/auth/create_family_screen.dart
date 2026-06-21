import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});
  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final familyId = await context.read<FamilyProvider>().createFamily(
            name: name,
            description: _descCtrl.text.trim(),
          );
      if (familyId.isNotEmpty) {
        context.read<FamilyProvider>().familyId = familyId;
      }
      final role = context.read<AuthProvider>().currentUser?['role']?.toString() ?? 'FAMILY_MANAGER';
      if (mounted) {
        context.go(role == 'FAMILY_MANAGER' ? '/manager/home' : '/member/home');
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
              _label('Tên gia đình'),
              const SizedBox(height: 8),
              _input(_nameCtrl, 'VD: Gia đình Nguyễn'),
              const SizedBox(height: 20),
              _label('Mô tả (tùy chọn)'),
              const SizedBox(height: 8),
              _input(_descCtrl, 'Một vài điều về gia đình bạn...', maxLines: 3),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Tạo gia đình', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Đăng xuất', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary));

  Widget _input(TextEditingController ctrl, String hint, {int maxLines = 1}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      );
}
