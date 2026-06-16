import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

// UC20 — Xem danh sách thành viên gia đình
// UC17 — Quản lý Role & Quan hệ thành viên
// UC18 — Cấp / Thu quyền Phó nhóm
// UC19 — Xoá / Vô hiệu hoá thành viên

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});
  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FamilyProvider>().fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final me       = context.watch<AuthProvider>().user;
    final isAdmin  = me?.isAdministrative ?? false;
    final provider = context.watch<FamilyProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Thành viên gia đình',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (isAdmin)
                GestureDetector(
                  onTap: () => context.push('/manager/invite'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.link, borderRadius: BorderRadius.circular(12)),
                    child: Text('+ Mời', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ]),
          ),

          // Body
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? _errorView(provider)
                    : provider.members.isEmpty
                        ? _emptyView()
                        : RefreshIndicator(
                            onRefresh: provider.fetchMembers,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: provider.members.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _memberCard(context, provider.members[i], me?.id, isAdmin),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _memberCard(BuildContext ctx, FamilyMember m, String? myId, bool isAdmin) {
    final isMe = m.id == myId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        AvatarWidget(initial: m.avatarInitials, color: Color(m.avatarColor), size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(m.name + (isMe ? ' (Bạn)' : ''),
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: m.roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(m.roleLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: m.roleColor)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(m.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            if (m.relation.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(m.relation, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ]),
        ),
        if (isAdmin && !isMe)
          GestureDetector(
            onTap: () => _showManageSheet(ctx, m),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
      ]),
    );
  }

  void _showManageSheet(BuildContext ctx, FamilyMember m) {
    final provider = ctx.read<FamilyProvider>();
    final isDeputy = m.role.toUpperCase() == 'DEPUTY';

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Member info header
          Row(children: [
            AvatarWidget(initial: m.avatarInitials, color: Color(m.avatarColor), size: 44),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(m.roleLabel, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            ]),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // UC18 — Deputy toggle
          _actionTile(
            icon: isDeputy ? Icons.remove_moderator_rounded : Icons.admin_panel_settings_rounded,
            label: isDeputy ? 'Thu quyền Phó nhóm' : 'Cấp quyền Phó nhóm',
            color: AppColors.link,
            onTap: () async {
              Navigator.pop(ctx);
              try {
                if (isDeputy) {
                  await provider.revokeDeputy(m.id);
                } else {
                  await provider.grantDeputy(m.id);
                }
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(isDeputy ? 'Đã thu quyền Phó nhóm' : 'Đã cấp quyền Phó nhóm'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppColors.danger,
                  ));
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // UC19 — Remove member
          _actionTile(
            icon: Icons.person_remove_rounded,
            label: 'Xoá thành viên khỏi gia đình',
            color: AppColors.danger,
            onTap: () {
              Navigator.pop(ctx);
              _confirmRemove(ctx, m, provider);
            },
          ),
        ]),
      ),
    );
  }

  void _confirmRemove(BuildContext ctx, FamilyMember m, FamilyProvider provider) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xoá thành viên?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('${m.name} sẽ bị xoá khỏi gia đình và không thể xem dữ liệu chung.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Huỷ', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.removeMember(m.id);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Đã xoá ${m.name}'),
                    backgroundColor: AppColors.danger,
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppColors.danger,
                  ));
                }
              }
            },
            child: Text('Xoá', style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _errorView(FamilyProvider p) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('⚠️', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text(p.error ?? 'Lỗi tải dữ liệu', style: GoogleFonts.inter(color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      TextButton(onPressed: p.fetchMembers, child: const Text('Thử lại')),
    ]),
  );

  Widget _emptyView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('Chưa có thành viên', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Text('Mời thành viên bằng QR, link hoặc mã 6 ký tự',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
    ]),
  );
}
