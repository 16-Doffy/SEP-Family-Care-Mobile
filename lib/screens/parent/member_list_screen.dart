import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
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
      // Lấy yêu cầu đang chờ từ flow mã mời mới (Manager-only).
      final me = context.read<AuthProvider>().user;
      if (me?.canInviteMembers ?? false) {
        context.read<InvitationProvider>().fetchJoinRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final canManage =
        (me?.canManageMemberRoles ?? false) || (me?.canRemoveMembers ?? false);
    final provider = context.watch<FamilyProvider>();

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thành viên gia đình',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (me?.canInviteMembers ?? false) ...[
                    // Nút "Yêu cầu" với badge số người đang chờ duyệt
                    GestureDetector(
                      onTap: () => context.push('/manager/invite-requests'),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.how_to_reg_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Builder(
                            builder: (_) {
                              final cnt = context
                                  .watch<InvitationProvider>()
                                  .pendingJoinRequestCount;
                              if (cnt == 0) return const SizedBox.shrink();
                              return Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$cnt',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/manager/invite'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.link,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+ Mời',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tên gia đình — PATCH /families/{id}, chỉ Manager sửa được.
            if (provider.familyName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🏠 ${provider.familyName}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                    if (me?.role == UserRole.manager)
                      GestureDetector(
                        onTap: () => _showRenameFamilySheet(
                          context,
                          provider.familyName,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 15,
                            color: AppColors.link,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: provider.members.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _memberCard(
                          context,
                          provider.members[i],
                          me,
                          canManage,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(
    BuildContext ctx,
    FamilyMember m,
    AppUser? me,
    bool canManage,
  ) {
    final isMe = m.userId == me?.id;
    return InkWell(
      onTap: () => ctx.push('/manager/member/${Uri.encodeComponent(m.id)}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            AvatarWidget(
              initial: m.avatarInitials,
              color: Color(m.avatarColor),
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name + (isMe ? ' (Bạn)' : ''),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: m.roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.roleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: m.roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.email,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (m.relation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      m.relation,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            if ((canManage && !isMe) || (me?.canManageFinance ?? false))
              GestureDetector(
                onTap: () => _showManageSheet(ctx, m, me),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameFamilySheet(BuildContext context, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    bool submitting = false;
    String? sheetError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✏️ Đổi tên gia đình',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Tên gia đình',
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sheetError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            setSheet(() => sheetError = 'Nhập tên gia đình');
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context
                                .read<FamilyProvider>()
                                .updateFamilyName(name);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setSheet(() {
                              submitting = false;
                              sheetError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Lưu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageSheet(BuildContext ctx, FamilyMember m, AppUser? me) {
    final provider = ctx.read<FamilyProvider>();
    final isMe = m.userId == me?.id;
    final canRemove = (me?.canRemoveMembers ?? false) && !isMe;
    final canViewFinance = me?.canManageFinance ?? false;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member info header
            Row(
              children: [
                AvatarWidget(
                  initial: m.avatarInitials,
                  color: Color(m.avatarColor),
                  size: 44,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      m.roleLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // UC gap #5 — Manager/Deputy xem tài chính tháng của thành viên
            // (BE ship monthly-summary 2026-07-13; field private BE trả null)
            if (canViewFinance) ...[
              _actionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: isMe ? 'Tài chính tháng của tôi' : 'Xem tài chính tháng',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.push(
                    '/manager/member-finance?memberId=${isMe ? '' : m.id}&name=${Uri.encodeQueryComponent(m.name)}',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // UC19 — Remove member (Manager-only)
            if (canRemove)
              _actionTile(
                icon: Icons.person_remove_rounded,
                label: 'Xoá thành viên khỏi gia đình',
                color: AppColors.danger,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemove(ctx, m, provider);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(
    BuildContext ctx,
    FamilyMember m,
    FamilyProvider provider,
  ) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xoá thành viên?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${m.name} sẽ bị xoá khỏi gia đình và không thể xem dữ liệu chung.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Huỷ',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.removeMember(m.userId);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Đã xoá ${m.name}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Xoá',
              style: GoogleFonts.inter(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(FamilyProvider p) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          p.error ?? 'Lỗi tải dữ liệu',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: p.fetchMembers, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _emptyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          'Chưa có thành viên',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mời thành viên bằng QR, link hoặc mã 8 ký tự',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
