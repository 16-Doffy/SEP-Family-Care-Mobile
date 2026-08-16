import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

/// Explicit local workspace picker for accounts that belong to multiple
/// families. The selected id is persisted by [AuthProvider].
class SelectFamilyScreen extends StatefulWidget {
  const SelectFamilyScreen({super.key});

  @override
  State<SelectFamilyScreen> createState() => _SelectFamilyScreenState();
}

class _SelectFamilyScreenState extends State<SelectFamilyScreen> {
  String? _selectingId;

  Future<void> _select(FamilyWorkspace workspace) async {
    setState(() => _selectingId = workspace.id);
    try {
      final auth = context.read<AuthProvider>();
      await auth.selectFamily(workspace.id);
      if (!mounted) return;
      final destination = switch (auth.user?.role) {
        UserRole.manager => '/manager/home',
        UserRole.deputy => '/deputy/home',
        _ => '/member/home',
      };
      context.go(destination);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _selectingId = null);
    }
  }

  String _roleLabel(String? role) => switch (role?.toUpperCase()) {
    'FAMILY_MANAGER' || 'MANAGER' => 'Trưởng nhóm',
    'DEPUTY_MEMBER' || 'DEPUTY' => 'Phó nhóm',
    _ => 'Thành viên',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasCurrentFamily = auth.hasFamily;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: hasCurrentFamily
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(
          'Chọn gia đình',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Bạn thuộc nhiều gia đình',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn gia đình muốn làm việc. Bạn có thể đổi lại trong mục Hồ sơ.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            ...auth.workspaces.map(
              (workspace) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary100,
                      child: Icon(Icons.family_restroom_rounded, color: AppColors.primary500),
                    ),
                    title: Text(
                      workspace.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_roleLabel(workspace.role)),
                    trailing: _selectingId == workspace.id
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _selectingId == null ? () => _select(workspace) : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
