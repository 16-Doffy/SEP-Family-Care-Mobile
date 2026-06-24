import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';

// Manager xem & duyệt các yêu cầu tham gia gia đình (status CLAIMED).
class InvitationRequestsScreen extends StatefulWidget {
  const InvitationRequestsScreen({super.key});
  @override
  State<InvitationRequestsScreen> createState() => _InvitationRequestsScreenState();
}

class _InvitationRequestsScreenState extends State<InvitationRequestsScreen> {
  String? _busyId; // invitation đang xử lý (approve/reject)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvitationProvider>().fetchInvitations();
    });
  }

  Future<void> _approve(Invitation inv) async {
    final provider = context.read<InvitationProvider>();
    setState(() => _busyId = inv.id);
    try {
      await provider.approve(inv.id, familyRole: inv.familyRole, relationship: inv.relationship);
      if (mounted) {
        context.read<FamilyProvider>().fetchMembers(); // refresh danh sách thành viên
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã duyệt — thành viên đã vào gia đình ✅'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Invitation inv) async {
    final provider = context.read<InvitationProvider>();
    setState(() => _busyId = inv.id);
    try {
      await provider.reject(inv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã từ chối yêu cầu'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    // Sắp xếp: CLAIMED (chờ duyệt) lên đầu, rồi PENDING, rồi đã xong
    final sorted = [...provider.invitations]..sort((a, b) {
        int rank(Invitation i) => i.isAwaitingApproval ? 0 : i.isPending ? 1 : 2;
        return rank(a).compareTo(rank(b));
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(child: Center(child: Text('Yêu cầu tham gia', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              GestureDetector(
                onTap: () => provider.fetchInvitations(),
                child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              ),
            ]),
          ),

          if (provider.awaitingCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(children: [
                const Text('⏳', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${provider.awaitingCount} người đang chờ bạn duyệt',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                ),
              ]),
            ),
          const SizedBox(height: 8),

          if (provider.loading && provider.invitations.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error != null && provider.invitations.isEmpty)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Lỗi tải dữ liệu', style: GoogleFonts.inter(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => provider.fetchInvitations(), child: const Text('Thử lại')),
            ])))
          else if (sorted.isEmpty)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('📭', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Chưa có lời mời nào', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
            ])))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchInvitations(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _inviteCard(sorted[i]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _inviteCard(Invitation inv) {
    final (chipColor, chipLabel) = inv.statusChip;
    final busy = _busyId == inv.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: inv.isAwaitingApproval ? Border.all(color: const Color(0xFFFED7AA), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.claimerName ?? inv.email,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(inv.claimerEmail ?? inv.email,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(chipLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: chipColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          _miniChip('👤 ${inv.roleLabel}'),
          _miniChip('🔗 ${inv.relationLabel}'),
        ]),

        // Nút duyệt/từ chối — chỉ cho CLAIMED (đang chờ duyệt)
        if (inv.isAwaitingApproval) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: busy ? null : () => _approve(inv),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('✓ Duyệt', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: busy ? null : () => _reject(inv),
                  child: Text('✕ Từ chối', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _miniChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
