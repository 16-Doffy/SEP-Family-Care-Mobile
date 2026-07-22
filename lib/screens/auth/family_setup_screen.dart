import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Onboarding entry point. Joining now always uses the dedicated invite-code
/// route, so this screen has no retired invitation-token API calls.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _creating = true);
    try {
      await auth.createFamily(name);
      if (!mounted) return;
      context.go('/manager/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 36),
            const Icon(Icons.family_restroom_rounded, size: 72, color: AppColors.primary500),
            const SizedBox(height: 18),
            Text('Thiết lập gia đình', textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tạo gia đình mới hoặc xin tham gia bằng mã mời 8 ký tự.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tạo gia đình mới', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Tên gia đình'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                    onPressed: _creating ? null : _create,
                    child: _creating ? const CircularProgressIndicator(color: Colors.white) : const Text('Tạo gia đình'),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/join'),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Tham gia bằng mã mời'),
            ),
            TextButton(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                await auth.logout();
                if (!mounted) return;
                context.go('/login');
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}
