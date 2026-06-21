import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';

class InvitationScreen extends StatefulWidget {
  final String token;
  const InvitationScreen({super.key, required this.token});
  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  Map<String, dynamic>? _invite;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<FamilyProvider>().lookupInvitation(widget.token);
      if (mounted) setState(() { _invite = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _accept() async {
    setState(() => _acting = true);
    try {
      await context.read<FamilyProvider>().acceptInvitation(widget.token);
      if (mounted) {
        final role = context.read<AuthProvider>().currentUser?['role']?.toString() ?? 'FAMILY_MEMBER';
        context.go(role == 'FAMILY_MANAGER' ? '/manager/home' : '/member/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _acting = true);
    try {
      await context.read<FamilyProvider>().rejectInvitation(widget.token);
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : _inviteView(),
      ),
    );
  }

  Widget _inviteView() {
    final familyName = _invite?['family'] is Map ? (_invite!['family'] as Map)['name']?.toString() : null;
    final inviterName = _invite?['inviter'] is Map ? (_invite!['inviter'] as Map)['displayName']?.toString() : null;
    final role = _invite?['familyRole']?.toString() ?? 'FAMILY_MEMBER';
    final roleLabel = role == 'FAMILY_MANAGER' ? 'Trưởng nhóm' : role == 'DEPUTY_MEMBER' ? 'Phó nhóm' : 'Thành viên';

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text('Lời mời tham gia gia đình', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (inviterName != null)
            Text('$inviterName mời bạn vào', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          if (familyName != null)
            Text(familyName, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.link)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.link.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
            child: Text('Vai trò: $roleLabel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.link)),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              onPressed: _acting ? null : _accept,
              child: _acting
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text('Chấp nhận lời mời', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _acting ? null : _reject,
              child: Text('Từ chối', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('❌', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Lời mời không hợp lệ hoặc đã hết hạn', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => context.go('/login'),
              child: Text('Về trang đăng nhập', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ),
      );
}
