import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final family = context.watch<FamilyProvider>();
    final user   = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  AvatarWidget(initial: user?.avatarInitials ?? 'BA', color: Color(user?.avatarColor ?? AppColors.avatarBlue.value), size: 80),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'Thành viên', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Gia đình ${family.family?.name ?? user?.familyName ?? ""}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.link.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text(_getRoleName(user?.role), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.link)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _section('Tài khoản', [
              _tile(context, '👤', 'Hồ sơ cá nhân', onTap: () => _showProfileInfo(context, auth)),
              _tile(context, '🔒', 'Bảo mật', onTap: () {}),
              _tile(context, '🔔', 'Thông báo', onTap: () => context.push('/notifications')),
            ]),
            const SizedBox(height: 16),

            _section('Gia đình', [
              // Tất cả role đều xem được danh sách thành viên
              _tile(context, '👨‍👩‍👧', 'Xem thành viên',
                  onTap: () => _showMembers(context, family)),
              // Chỉ manager/deputy mới mời và cài đặt
              if (user?.isAdministrative == true) ...[
                _tile(context, '✉️', 'Mời thành viên',
                    onTap: () => _showInvite(context, family)),
                _tile(context, '⚙️', 'Cài đặt gia đình',
                    onTap: () => _showEditFamily(context, family)),
              ],
            ]),
            const SizedBox(height: 16),

            _section('Khác', [
              _tile(context, '❓', 'Trợ giúp & FAQ', onTap: () {}),
              _tile(context, '📋', 'Điều khoản sử dụng', onTap: () {}),
            ]),
            const SizedBox(height: 16),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: auth.logout,
                child: Text('Đăng xuất', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Profile info dialog (read-only — PATCH /auth/me not available) ────────

  void _showProfileInfo(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hồ sơ cá nhân'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Họ tên', user?.name ?? '—'),
          const SizedBox(height: 8),
          _infoRow('Vai trò', _getRoleName(user?.role)),
          const SizedBox(height: 8),
          _infoRow('Gia đình', user?.familyName.isNotEmpty == true ? user!.familyName : '—'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
            child: const Text('Chỉnh sửa hồ sơ chưa được hỗ trợ trong phiên bản này.', style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
    ],
  );

  // ── Members list dialog ──────────────────────────────────────────────────

  void _showMembers(BuildContext context, FamilyProvider family) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thành viên (${family.members.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: family.isLoading
              ? const Center(child: CircularProgressIndicator())
              : family.members.isEmpty
                  ? const Text('Chưa có thành viên')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: family.members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = family.members[i];
                        return ListTile(
                          leading: AvatarWidget(initial: m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?', color: AppColors.avatarBlue, size: 36),
                          title: Text(m.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          subtitle: Text(m.roleLabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          trailing: m.isManager
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await family.removeMember(m.userId);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa ${m.displayName}')));
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                                    }
                                  },
                                ),
                        );
                      },
                    ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  // ── Invite member dialog ─────────────────────────────────────────────────

  void _showInvite(BuildContext context, FamilyProvider family) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _InviteDialog(emailCtrl: emailCtrl, family: family),
    );
  }

  // ── Edit family dialog ───────────────────────────────────────────────────

  void _showEditFamily(BuildContext context, FamilyProvider family) {
    final nameCtrl = TextEditingController(text: family.family?.name ?? '');
    final descCtrl = TextEditingController(text: family.family?.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cài đặt gia đình'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên gia đình')),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await family.updateFamily(
                  name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                );
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật gia đình')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getRoleName(UserRole? role) => switch (role) {
        UserRole.manager => 'TRƯỞNG NHÓM',
        UserRole.deputy  => 'PHÓ NHÓM',
        UserRole.member  => 'THÀNH VIÊN',
        null             => 'KHÁCH',
      };

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
        Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, String icon, String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Invite dialog (StatefulWidget để handle loading + hiện link) ────────────

class _InviteDialog extends StatefulWidget {
  final TextEditingController emailCtrl;
  final FamilyProvider family;
  const _InviteDialog({required this.emailCtrl, required this.family});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  bool _loading = false;
  String? _inviteLink;

  String get _baseUrl {
    // Lấy origin của web app (ví dụ: http://localhost:8080)
    // Nếu không phải web, dùng deeplink scheme
    try {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
    } catch (_) {
      return 'http://localhost:8080';
    }
  }

  Future<void> _send() async {
    final email = widget.emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    try {
      final token = await widget.family.inviteMember(email);
      if (mounted) {
        final link = token.isNotEmpty ? '$_baseUrl/#/invite/$token' : '';
        setState(() { _loading = false; _inviteLink = link; });
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
    if (_inviteLink != null) {
      // Hiện link sau khi tạo thành công
      return AlertDialog(
        title: const Text('Lời mời đã tạo'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gửi link này cho ${widget.emailCtrl.text.trim()}:', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(
                child: Text(
                  _inviteLink!.isNotEmpty ? _inviteLink! : '(Token không có trong response — kiểm tra API)',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              if (_inviteLink!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.link),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _inviteLink!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã copy link'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Link chỉ dùng được 1 lần và có thời hạn.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Xong', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    // Form nhập email
    return AlertDialog(
      title: const Text('Mời thành viên'),
      content: TextField(
        controller: widget.emailCtrl,
        decoration: const InputDecoration(labelText: 'Email', hintText: 'example@email.com'),
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        onSubmitted: (_) => _send(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _loading ? null : _send,
          child: _loading
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Gửi lời mời'),
        ),
      ],
    );
  }
}
