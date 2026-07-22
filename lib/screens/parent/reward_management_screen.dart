import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/json_report_view.dart';

// Quản lý phần thưởng phía Manager/Deputy — trước đây hoàn toàn vắng mặt
// dù BE có đủ endpoint và phía Member đã tạo dispute/báo bận từ lâu
// (child_tasks_screen.dart). Gộp 3 luồng còn thiếu UI Manager:
//   1. Thanh toán (Reward Settlements) — đánh dấu đã trả, hủy.
//   2. Tranh chấp (Reward Disputes) — giải quyết.
//   3. Báo bận (Unavailabilities) — xử lý / hủy phân công.
class RewardManagementScreen extends StatefulWidget {
  const RewardManagementScreen({super.key});
  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<TaskProvider>();
      tp.fetchRewardSettlements();
      tp.fetchRewardDisputes();
      tp.fetchUnavailabilities();
      context.read<FamilyProvider>().fetchMembers();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
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
              const Expanded(child: Center(child: Text('Quản lý phần thưởng', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              const SizedBox(width: 40),
            ]),
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.link,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.link,
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Thanh toán'),
              Tab(text: 'Tranh chấp'),
              Tab(text: 'Báo bận'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _SettlementsTab(fmt: _fmt),
                const _DisputesTab(),
                const _UnavailabilityTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

Widget _emptyView(String text) => Center(
      child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
    );

Widget _card({required Widget child}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ]),
      child: child,
    );

// ── Tab 1: Thanh toán ────────────────────────────────────────────────────

class _SettlementsTab extends StatelessWidget {
  final String Function(double) fmt;
  const _SettlementsTab({required this.fmt});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TaskProvider>();
    final list = tp.rewardSettlements;
    if (list.isEmpty) return _emptyView('Chưa có khoản thưởng nào');
    return RefreshIndicator(
      onRefresh: () => context.read<TaskProvider>().fetchRewardSettlements(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: list.length,
        itemBuilder: (_, i) => _settlementCard(context, list[i]),
      ),
    );
  }

  Widget _settlementCard(BuildContext context, RewardSettlement s) {
    return GestureDetector(
      onTap: () => _showDetail(context, s),
      child: _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.memberName ?? 'Thành viên', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: s.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(s.statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: s.statusColor)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(fmt(s.amount), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.income)),
          if (s.note != null && s.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.note!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
          if (s.needsMarkPaid) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
                    onPressed: () => _markPaid(context, s),
                    child: Text('Đánh dấu đã trả', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                    onPressed: () => context.read<TaskProvider>().cancelSettlement(s.id),
                    child: Text('Hủy', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  // MarkRewardPaidDto: { externalMethod (bắt buộc), externalNote? }.
  Future<void> _markPaid(BuildContext context, RewardSettlement s) async {
    String method = 'CASH';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Đánh dấu đã trả thưởng', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Phương thức trả', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in ['CASH', 'BANK_TRANSFER', 'THIRD_PARTY_WALLET', 'OTHER'])
                ChoiceChip(
                  label: Text(switch (m) { 'CASH' => 'Tiền mặt', 'BANK_TRANSFER' => 'Chuyển khoản', 'THIRD_PARTY_WALLET' => 'Ví điện tử', _ => 'Khác' }),
                  selected: method == m,
                  onSelected: (_) => setD(() => method = m),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(hintText: 'Ghi chú (tùy chọn)'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<TaskProvider>().markRewardPaid(s.id, externalMethod: method, externalNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
      }
    }
  }

  void _showDetail(BuildContext context, RewardSettlement s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _SettlementDetailSheet(settlementId: s.id),
    );
  }
}

class _SettlementDetailSheet extends StatefulWidget {
  final String settlementId;
  const _SettlementDetailSheet({required this.settlementId});
  @override
  State<_SettlementDetailSheet> createState() => _SettlementDetailSheetState();
}

class _SettlementDetailSheetState extends State<_SettlementDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _allocations = [];
  TaskSubmission? _submission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tp = context.read<TaskProvider>();
    try {
      final results = await Future.wait([
        tp.fetchSettlementDetail(widget.settlementId),
        tp.fetchSettlementAllocations(widget.settlementId),
      ]);
      final detail = results[0] as Map<String, dynamic>;
      // GET .../tasks/submissions/{id} — bài nộp gốc gắn với settlement, nếu
      // BE trả kèm submissionId.
      final submissionId = detail['submissionId']?.toString() ?? detail['taskSubmissionId']?.toString();
      final submission = submissionId != null ? await tp.fetchSubmissionDetail(submissionId) : null;
      if (mounted) {
        setState(() {
          _detail = detail;
          _allocations = results[1] as List<Map<String, dynamic>>;
          _submission = submission;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔍 Chi tiết khoản thưởng', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))
          else ...[
            JsonReportView(data: _detail ?? {}),
            if (_allocations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Phân bổ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              JsonReportView(data: _allocations),
            ],
            if (_submission != null) ...[
              const SizedBox(height: 16),
              Text('Bài nộp gốc', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              if (_submission!.submissionNote != null && _submission!.submissionNote!.isNotEmpty)
                Text(_submission!.submissionNote!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              if (_submission!.proofs.isNotEmpty)
                Text('${_submission!.proofs.length} minh chứng đính kèm', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
          ],
        ]),
      ),
    );
  }
}

// ── Tab 2: Tranh chấp ────────────────────────────────────────────────────

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    final list = context.watch<TaskProvider>().rewardDisputes;
    if (list.isEmpty) return _emptyView('Chưa có tranh chấp nào');
    return RefreshIndicator(
      onRefresh: () => context.read<TaskProvider>().fetchRewardDisputes(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: list.length,
        itemBuilder: (_, i) => _disputeCard(context, list[i]),
      ),
    );
  }

  Widget _disputeCard(BuildContext context, RewardDispute d) {
    final isOpen = d.status == 'OPEN';
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('⚠️ Tranh chấp', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isOpen ? AppColors.danger : AppColors.success).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(isOpen ? 'Đang mở' : 'Đã giải quyết',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isOpen ? AppColors.danger : AppColors.success)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(d.reason, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        if (d.resolutionNote != null && d.resolutionNote!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Giải quyết: ${d.resolutionNote}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
        if (isOpen) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, padding: EdgeInsets.zero),
              onPressed: () => _resolveDialog(context, d),
              child: Text('Giải quyết', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ]),
    );
  }

  // ResolveRewardDisputeDto: { action: ACCEPT_DISPUTE | REJECT_DISPUTE } — không
  // có trường ghi chú tự do trên BE thật.
  Future<void> _resolveDialog(BuildContext context, RewardDispute d) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Giải quyết tranh chấp', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(d.reason, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
            onPressed: () => Navigator.pop(ctx, 'REJECT_DISPUTE'),
            child: const Text('Từ chối', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'ACCEPT_DISPUTE'),
            child: const Text('Chấp nhận'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    try {
      await context.read<TaskProvider>().resolveDispute(d.id, action);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
      }
    }
  }
}

// ── Tab 3: Báo bận ────────────────────────────────────────────────────────

class _UnavailabilityTab extends StatelessWidget {
  const _UnavailabilityTab();

  @override
  Widget build(BuildContext context) {
    final list = context.watch<TaskProvider>().unavailabilities;
    if (list.isEmpty) return _emptyView('Chưa có báo bận nào');
    return RefreshIndicator(
      onRefresh: () => context.read<TaskProvider>().fetchUnavailabilities(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: list.length,
        itemBuilder: (_, i) => _unavailCard(context, list[i]),
      ),
    );
  }

  Widget _unavailCard(BuildContext context, TaskUnavailability u) {
    final isOpen = u.isOpen;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('🙅 Báo bận', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isOpen ? const Color(0xFFD97706) : AppColors.textMuted).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(isOpen ? 'Chờ xử lý' : u.status,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFFD97706) : AppColors.textMuted)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(u.reason, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        if (isOpen) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, padding: EdgeInsets.zero),
                  onPressed: () => _handleSheet(context, u),
                  child: Text('Xử lý', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                  onPressed: () => context.read<TaskProvider>().cancelUnavailability(u.id),
                  child: Text('Hủy báo bận', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  void _handleSheet(BuildContext context, TaskUnavailability u) {
    final members = context.read<FamilyProvider>().members.where((m) => m.isActive).toList();
    String action = 'MARK_HANDLED';
    String? newMemberId;
    final noteCtrl = TextEditingController();
    bool submitting = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Xử lý báo bận', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(u.reason, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: const Text('Đánh dấu đã xử lý'), selected: action == 'MARK_HANDLED', onSelected: (_) => setSheet(() => action = 'MARK_HANDLED')),
              ChoiceChip(label: const Text('Hủy phân công'), selected: action == 'CANCEL_ASSIGNMENT', onSelected: (_) => setSheet(() => action = 'CANCEL_ASSIGNMENT')),
              ChoiceChip(label: const Text('Giao lại người khác'), selected: action == 'REASSIGN', onSelected: (_) => setSheet(() => action = 'REASSIGN')),
            ]),
            if (action == 'REASSIGN') ...[
              const SizedBox(height: 12),
              Text('Giao cho', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: newMemberId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                onChanged: (v) => setSheet(() => newMemberId = v),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: noteCtrl,
                decoration: InputDecoration(hintText: 'Ghi chú (tùy chọn)', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            if (sheetError != null) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: submitting ? null : () async {
                  if (action == 'REASSIGN' && newMemberId == null) {
                    setSheet(() => sheetError = 'Chọn người được giao');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<TaskProvider>().handleUnavailability(
                      u.id, action: action,
                      newAssignedToMemberId: action == 'REASSIGN' ? newMemberId : null,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Xác nhận', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
