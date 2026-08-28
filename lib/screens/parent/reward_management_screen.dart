import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Quản lý phần thưởng',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.link,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.link,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
          ],
        ),
      ),
    );
  }
}

Widget _emptyView(BuildContext context, String text) => Center(
  child: Text(
    text,
    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
  ),
);

Widget _card(BuildContext context, {required Widget child}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
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
    if (list.isEmpty) return _emptyView(context, 'Chưa có khoản thưởng nào');
    return RefreshIndicator(
      onRefresh: () => context.read<TaskProvider>().fetchRewardSettlements(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: list.length + 1,
        itemBuilder: (_, i) => i == 0
            ? _paymentFlowGuide()
            : _settlementCard(context, list[i - 1]),
      ),
    );
  }

  Widget _paymentFlowGuide() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 19,
          color: Color(0xFF2563EB),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Người quản lý ghi nhận đã trả hoặc hủy khoản thưởng. Sau khi đã trả, người nhận xác nhận “Đã nhận” hoặc chọn “Chưa nhận” để tạo tranh chấp.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFF1E3A8A),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _settlementCard(BuildContext context, RewardSettlement s) {
    final currentUser = context.watch<AuthProvider>().user;
    final currentMember = context
        .watch<FamilyProvider>()
        .members
        .where((m) => m.userId == currentUser?.id)
        .firstOrNull;
    // Người nhận không được tự ghi nhận đã trả hoặc hủy khoản của mình. Nhưng
    // sau khi người quản lý mark-paid, chính người nhận (kể cả Deputy) PHẢI có
    // quyền xác nhận đã nhận hoặc báo chưa nhận. Bản cũ gộp hai quyền này và
    // khiến Deputy bị kẹt ở nhãn "Đã trả, chờ xác nhận" không có nút bấm.
    final isOwnSettlement =
        s.receiverUserId == currentUser?.id ||
        (currentMember != null && s.receiverMemberId == currentMember.id);
    return GestureDetector(
      onTap: () => _showDetail(context, s),
      child: _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Người nhận: ${s.memberName ?? 'Thành viên'}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (s.taskTitle != null && s.taskTitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Nhiệm vụ: ${s.taskTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: s.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      s.statusLabel,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: s.statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fmt(s.amount),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.income,
              ),
            ),
            if (s.note != null && s.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                s.note!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (s.needsMarkPaid && isOwnSettlement) ...[
              const SizedBox(height: 10),
              Text(
                'Bạn là người nhận khoản thưởng này. Trưởng nhóm sẽ thực hiện thanh toán hoặc hủy.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (s.needsMarkPaid && !isOwnSettlement) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      // Android có thể cắt nét dấu tiếng Việt khi nút 36px,
                      // nhất là với Inter đậm trên máy font scale lớn.
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _markPaid(context, s),
                        child: Text(
                          'Đánh dấu đã trả',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        onPressed: () => _cancelSettlement(context, s),
                        child: Text(
                          'Hủy thưởng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (s.status == 'WAITING_CONFIRMATION' && isOwnSettlement) ...[
              const SizedBox(height: 12),
              Text(
                'Người quản lý đã ghi nhận đã trả. Hãy xác nhận để hoàn tất, hoặc báo chưa nhận nếu thông tin không đúng.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _confirmReceived(context, s),
                        child: Text(
                          'Đã nhận',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        onPressed: () => _showDisputeDialog(context, s.id),
                        child: Text(
                          'Chưa nhận',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReceived(
    BuildContext context,
    RewardSettlement settlement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đã nhận thưởng?'),
        content: const Text(
          'Xác nhận này sẽ hoàn tất khoản thưởng và không thể báo chưa nhận sau đó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đã nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<TaskProvider>().confirmRewardReceived(settlement.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showDisputeDialog(
    BuildContext context,
    String settlementId,
  ) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Báo chưa nhận thưởng'),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(hintText: 'Lý do...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, reasonCtrl.text.trim()),
              child: const Text('Gửi báo cáo'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !context.mounted) return;
    try {
      await context.read<TaskProvider>().createDispute(settlementId, reason);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _cancelSettlement(
    BuildContext context,
    RewardSettlement settlement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy khoản thưởng?'),
        content: const Text(
          'Thao tác này kết thúc khoản thưởng ngay và người nhận sẽ không thể báo “Chưa nhận”. Đây không phải thao tác tạo tranh chấp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy khoản thưởng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<TaskProvider>().cancelSettlement(settlement.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // MarkRewardPaidDto: { externalMethod (bắt buộc), externalNote? }.
  Future<void> _markPaid(BuildContext context, RewardSettlement s) async {
    String method = 'CASH';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Đánh dấu đã trả thưởng',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phương thức trả',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in [
                    'CASH',
                    'BANK_TRANSFER',
                    'THIRD_PARTY_WALLET',
                    'OTHER',
                  ])
                    ChoiceChip(
                      label: Text(switch (m) {
                        'CASH' => 'Tiền mặt',
                        'BANK_TRANSFER' => 'Chuyển khoản',
                        'THIRD_PARTY_WALLET' => 'Ví điện tử',
                        _ => 'Khác',
                      }),
                      selected: method == m,
                      onSelected: (_) => setD(() => method = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ghi chú (tùy chọn)',
                ),
              ),
              const SizedBox(height: 12),
              // BE đã chốt Phase 1 (26/08): confirm-received -> tự sinh
              // LedgerEntry entryType=REWARD, sourceType=TASK_REWARD_SETTLEMENT
              // trong SỔ QUỸ GIA ĐÌNH, có idempotency. Nhưng Phase 1 **không**
              // cộng vào MemberMonthlyFinance.actualIncome (đó là số kê khai
              // cá nhân, không phải sổ giao dịch) — nên câu này vẫn đúng cả
              // sau khi BE deploy. Đo 26/08: BE chưa deploy (0 entry REWARD).
              // Xem DE_XUAT_BE_THUONG_KHONG_VAO_SO_2026-08-26.md.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ứng dụng không tự chuyển tiền. Chỉ xác nhận sau khi bạn đã '
                  'trả tiền thật bằng phương thức đã chọn; hệ thống chỉ lưu '
                  'thông tin đối soát. Sau đó người nhận sẽ chọn “Đã nhận” '
                  'hoặc “Chưa nhận”.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<TaskProvider>().markRewardPaid(
        s.id,
        externalMethod: method,
        externalNote: noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showDetail(BuildContext context, RewardSettlement s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
      final submissionId =
          detail['submissionId']?.toString() ??
          detail['taskSubmissionId']?.toString();
      final submission = submissionId != null
          ? await tp.fetchSubmissionDetail(submissionId)
          : null;
      if (mounted) {
        setState(() {
          _detail = detail;
          _allocations = results[1] as List<Map<String, dynamic>>;
          _submission = submission;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chi tiết khoản thưởng',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger),
              )
            else ...[
              JsonReportView(data: _detail ?? {}),
              if (_allocations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Phân bổ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                JsonReportView(data: _allocations),
              ],
              if (_submission != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Bài nộp gốc',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (_submission!.submissionNote != null &&
                    _submission!.submissionNote!.isNotEmpty)
                  Text(
                    _submission!.submissionNote!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (_submission!.proofs.isNotEmpty)
                  Text(
                    '${_submission!.proofs.length} minh chứng đính kèm',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ],
          ],
        ),
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
    if (list.isEmpty) return _emptyView(context, 'Chưa có tranh chấp nào');
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
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tranh chấp',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.danger : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOpen ? 'Đang mở' : 'Đã giải quyết',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? AppColors.danger : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            d.reason,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (d.resolutionNote != null && d.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Giải quyết: ${d.resolutionNote}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isOpen) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _resolveDialog(context, d),
                child: Text(
                  'Giải quyết',
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
    );
  }

  // ResolveRewardDisputeDto: { action: ACCEPT_DISPUTE | REJECT_DISPUTE } — không
  // có trường ghi chú tự do trên BE thật.
  Future<void> _resolveDialog(BuildContext context, RewardDispute d) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Giải quyết tranh chấp',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          d.reason,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => Navigator.pop(ctx, 'REJECT_DISPUTE'),
            child: const Text(
              'Từ chối',
              style: TextStyle(color: AppColors.danger),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
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
    if (list.isEmpty) return _emptyView(context, 'Chưa có báo bận nào');
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
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Báo bận',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (isOpen ? const Color(0xFFD97706) : AppColors.textMuted)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOpen ? 'Chờ xử lý' : u.status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOpen
                        ? const Color(0xFFD97706)
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            u.reason,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.link,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _handleSheet(context, u),
                      child: Text(
                        'Xử lý',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => context
                          .read<TaskProvider>()
                          .cancelUnavailability(u.id),
                      child: Text(
                        'Hủy báo bận',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleSheet(BuildContext context, TaskUnavailability u) {
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
    String action = 'MARK_HANDLED';
    String? newMemberId;
    final noteCtrl = TextEditingController();
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
                'Xử lý báo bận',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                u.reason,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Đánh dấu đã xử lý'),
                    selected: action == 'MARK_HANDLED',
                    onSelected: (_) => setSheet(() => action = 'MARK_HANDLED'),
                  ),
                  ChoiceChip(
                    label: const Text('Hủy phân công'),
                    selected: action == 'CANCEL_ASSIGNMENT',
                    onSelected: (_) =>
                        setSheet(() => action = 'CANCEL_ASSIGNMENT'),
                  ),
                  ChoiceChip(
                    label: const Text('Giao lại người khác'),
                    selected: action == 'REASSIGN',
                    onSelected: (_) => setSheet(() => action = 'REASSIGN'),
                  ),
                ],
              ),
              if (action == 'REASSIGN') ...[
                const SizedBox(height: 12),
                Text(
                  'Giao cho',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: newMemberId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: members
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.name)),
                      )
                      .toList(),
                  onChanged: (v) => setSheet(() => newMemberId = v),
                ),
              ],
              const SizedBox(height: 12),
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
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ghi chú (tùy chọn)',
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
                          if (action == 'REASSIGN' && newMemberId == null) {
                            setSheet(() => sheetError = 'Chọn người được giao');
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context
                                .read<TaskProvider>()
                                .handleUnavailability(
                                  u.id,
                                  action: action,
                                  newAssignedToMemberId: action == 'REASSIGN'
                                      ? newMemberId
                                      : null,
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                );
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
                          'Xác nhận',
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
}
