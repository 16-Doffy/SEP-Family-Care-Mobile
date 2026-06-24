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
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilyProvider>();
    final user = auth.user;

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
                  AvatarWidget(
                    initial: user?.avatarInitials ?? 'BA',
                    color: Color(user?.avatarColor ?? AppColors.avatarBlue.value),
                    size: 80,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Thanh vien',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Gia dinh ${family.family?.name ?? user?.familyName ?? ""}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.link.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _getRoleName(user?.role),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.link,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _section('Tai khoan', [
              _tile(
                context,
                Icons.person_outline_rounded,
                'Ho so ca nhan',
                onTap: () => _showProfileInfo(context, auth),
              ),
              _tile(
                context,
                Icons.lock_outline_rounded,
                'Bao mat',
                onTap: () {},
              ),
              _tile(
                context,
                Icons.notifications_none_rounded,
                'Thong bao',
                onTap: () => context.push('/notifications'),
              ),
            ]),
            const SizedBox(height: 16),
            _section('Gia dinh', [
              _tile(
                context,
                Icons.groups_2_outlined,
                'Xem thanh vien',
                onTap: () => _showMembers(context, family),
              ),
              if (user?.canInviteMembers == true)
                _tile(
                  context,
                  Icons.person_add_alt_1_rounded,
                  'Moi thanh vien',
                  onTap: () => _showInvite(context, family),
                ),
              if (user?.canInviteMembers == true)
                _tile(
                  context,
                  Icons.how_to_reg_rounded,
                  'Yeu cau cho duyet',
                  onTap: () => _showPendingInvitations(context, family),
                ),
              if (user?.canManageFamilySettings == true)
                _tile(
                  context,
                  Icons.settings_outlined,
                  'Cai dat gia dinh',
                  onTap: () => _showEditFamily(context, family),
                ),
            ]),
            const SizedBox(height: 16),
            _section('Khac', [
              _tile(
                context,
                Icons.help_outline_rounded,
                'Tro giup va FAQ',
                onTap: () {},
              ),
              _tile(
                context,
                Icons.description_outlined,
                'Dieu khoan su dung',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: auth.logout,
                child: Text(
                  'Dang xuat',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showProfileInfo(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ho so ca nhan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Ho ten', user?.name ?? '-'),
            const SizedBox(height: 8),
            _infoRow('Vai tro', _getRoleName(user?.role)),
            const SizedBox(height: 8),
            _infoRow(
              'Gia dinh',
              user?.familyName.isNotEmpty == true ? user!.familyName : '-',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chinh sua ho so chua duoc ho tro trong phien ban nay.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dong'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showMembers(BuildContext context, FamilyProvider family) {
    final canManageMembers =
        context.read<AuthProvider>().user?.canManageFamilyMembers ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thanh vien (${family.members.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: family.isLoading
              ? const Center(child: CircularProgressIndicator())
              : family.members.isEmpty
                  ? const Text('Chua co thanh vien')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: family.members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final member = family.members[i];
                        return ListTile(
                          leading: AvatarWidget(
                            initial: member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : '?',
                            color: AppColors.avatarBlue,
                            size: 36,
                          ),
                          title: Text(
                            member.displayName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            member.roleLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: !canManageMembers || member.isManager
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await family.removeMember(member.userId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Da xoa ${member.displayName}',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: AppColors.danger,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dong'),
          ),
        ],
      ),
    );
  }

  void _showInvite(BuildContext context, FamilyProvider family) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(emailCtrl: emailCtrl, family: family),
    );
  }

  Future<void> _showPendingInvitations(
    BuildContext context,
    FamilyProvider family,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await family.fetchInvitations(status: 'CLAIMED');
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final invitations = family.claimedInvitations;
        return AlertDialog(
          title: Text('Yeu cau cho duyet (${invitations.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: invitations.isEmpty
                ? const Text('Khong co yeu cau nao dang cho duyet')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: invitations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final invitation = invitations[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          invitation.claimedByName?.isNotEmpty == true
                              ? invitation.claimedByName!
                              : invitation.email,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${invitation.email}\nVai tro: ${invitation.roleLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Duyet',
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await family.approveInvitation(invitation);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Da duyet yeu cau'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Tu choi',
                              icon: const Icon(
                                Icons.cancel_rounded,
                                color: AppColors.danger,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await family
                                      .rejectClaimedInvitation(invitation.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Da tu choi yeu cau'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dong'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFamily(BuildContext context, FamilyProvider family) {
    final nameCtrl = TextEditingController(text: family.family?.name ?? '');
    final descCtrl =
        TextEditingController(text: family.family?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cai dat gia dinh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ten gia dinh'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Mo ta'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await family.updateFamily(
                  name: nameCtrl.text.trim().isEmpty
                      ? null
                      : nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Da cap nhat gia dinh')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Luu'),
          ),
        ],
      ),
    );
  }

  String _getRoleName(UserRole? role) {
    return switch (role) {
      UserRole.manager => 'TRUONG NHOM',
      UserRole.deputy => 'PHO NHOM',
      UserRole.member => 'THANH VIEN',
      null => 'KHACH',
    };
  }

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({
    required this.emailCtrl,
    required this.family,
  });

  final TextEditingController emailCtrl;
  final FamilyProvider family;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  bool _loading = false;
  String? _inviteLink;
  String _familyRole = 'FAMILY_MEMBER';

  String get _baseUrl {
    try {
      final uri = Uri.base;
      final port =
          uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port';
    } catch (_) {
      return 'http://localhost:8080';
    }
  }

  Future<void> _send() async {
    final email = widget.emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      final token = await widget.family.inviteMember(
        email,
        familyRole: _familyRole,
      );
      if (!mounted) return;
      final link = token.isNotEmpty ? '$_baseUrl/#/invite/$token' : '';
      setState(() {
        _loading = false;
        _inviteLink = link;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inviteLink != null) {
      return AlertDialog(
        title: const Text('Loi moi da tao'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gui link nay cho ${widget.emailCtrl.text.trim()}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _inviteLink!.isNotEmpty
                          ? _inviteLink!
                          : '(API khong tra ve invite token)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_inviteLink!.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppColors.link,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _inviteLink!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Da copy link'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link chi dung duoc 1 lan va co thoi han.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.link,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Xong', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Moi thanh vien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'example@email.com',
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _familyRole,
            decoration: const InputDecoration(labelText: 'Vai tro'),
            items: const [
              DropdownMenuItem(
                value: 'FAMILY_MEMBER',
                child: Text('Thanh vien'),
              ),
              DropdownMenuItem(
                value: 'DEPUTY_MEMBER',
                child: Text('Pho nhom'),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _familyRole = value);
                    }
                  },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huy'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _send,
          child: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gui loi moi'),
        ),
      ],
    );
  }
}
