import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/family_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';

/// Manager inbox for pending requests sent by the reusable family invite code.
class InvitationRequestsScreen extends StatefulWidget {
  const InvitationRequestsScreen({super.key});

  @override
  State<InvitationRequestsScreen> createState() => _InvitationRequestsScreenState();
}

class _InvitationRequestsScreenState extends State<InvitationRequestsScreen> {
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<InvitationProvider>().fetchJoinRequests(),
    );
  }

  Future<void> _approve(JoinRequest request) async {
    var role = 'FAMILY_MEMBER';
    var relationship = 'OTHER';
    final approved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Duyệt ${request.requesterName ?? 'thành viên'}',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: const [
                DropdownMenuItem(value: 'FAMILY_MEMBER', child: Text('Thành viên')),
                DropdownMenuItem(value: 'DEPUTY_MEMBER', child: Text('Phó nhóm')),
              ],
              onChanged: (value) => setSheet(() => role = value ?? role),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: relationship,
              decoration: const InputDecoration(labelText: 'Mối quan hệ'),
              items: const [
                DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                DropdownMenuItem(value: 'CHILD', child: Text('Con')),
                DropdownMenuItem(value: 'FATHER', child: Text('Bố')),
                DropdownMenuItem(value: 'MOTHER', child: Text('Mẹ')),
                DropdownMenuItem(value: 'SPOUSE', child: Text('Vợ/Chồng')),
                DropdownMenuItem(value: 'SISTER', child: Text('Chị/Em gái')),
                DropdownMenuItem(value: 'BROTHER', child: Text('Anh/Em trai')),
                DropdownMenuItem(value: 'GRANDPARENT', child: Text('Ông/Bà')),
              ],
              onChanged: (value) => setSheet(() => relationship = value ?? relationship),
            ),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Duyệt yêu cầu'),
            )),
          ]),
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busyId = request.id);
    try {
      await context.read<InvitationProvider>().approveJoinRequest(
        request.id,
        familyRole: role,
        relationship: relationship,
      );
      if (mounted) context.read<FamilyProvider>().fetchMembers();
    } catch (e) {
      if (mounted) _snack(e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(JoinRequest request) async {
    setState(() => _busyId = request.id);
    try {
      await context.read<InvitationProvider>().rejectJoinRequest(request.id);
    } catch (e) {
      if (mounted) _snack(e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _snack(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text('Yêu cầu tham gia', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        actions: [IconButton(onPressed: provider.loading ? null : () => provider.fetchJoinRequests(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: provider.loading && provider.joinRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchJoinRequests(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: provider.joinRequests.isEmpty
                    ? const [Padding(padding: EdgeInsets.only(top: 120), child: Center(child: Text('Không có yêu cầu đang chờ')))]
                    : provider.joinRequests.map(_card).toList(),
              ),
            ),
    );
  }

  Widget _card(JoinRequest request) {
    final busy = _busyId == request.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request.requesterName ?? 'Người dùng mới', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          if (request.requesterEmail != null) Text(request.requesterEmail!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          if (request.message?.isNotEmpty == true) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('“${request.message}”', style: GoogleFonts.inter(fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: busy ? null : () => _approve(request), child: const Text('Duyệt'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: busy ? null : () => _reject(request), child: const Text('Từ chối'))),
          ]),
        ]),
      ),
    );
  }
}
