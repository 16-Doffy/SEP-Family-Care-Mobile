import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

class ChildTasksScreen extends StatefulWidget {
  const ChildTasksScreen({super.key});
  @override
  State<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends State<ChildTasksScreen> {
  String _filter = 'Tất cả';
  final _filters = ['Tất cả', 'Chờ làm', 'Đã nộp', 'Hoàn thành'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchMyAssignments();
      // Cho banner 🎁: settlement WAITING_CONFIRMATION cần member xác nhận.
      context.read<TaskProvider>().fetchRewardSettlements();
    });
  }

  List<TaskAssignment> _filtered(List<TaskAssignment> list) {
    switch (_filter) {
      case 'Chờ làm':
        // BE dùng ASSIGNED cho assignment mới giao (enum: ASSIGNED|IN_PROGRESS|...)
        return list
            .where(
              (a) =>
                  a.status == 'ASSIGNED' ||
                  a.status == 'PENDING' ||
                  a.status == 'IN_PROGRESS',
            )
            .toList();
      case 'Đã nộp':
        return list.where((a) => a.status == 'SUBMITTED').toList();
      case 'Hoàn thành':
        return list.where((a) => a.status == 'APPROVED').toList();
      default:
        return list;
    }
  }

  String _catIcon(String? cat) => cat == 'Học tập' ? '📚' : '🏠';

  static String _fmtAmount(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  // ── 🎁 Banner thưởng chờ xác nhận (WAITING_CONFIRMATION) + tranh chấp ─────
  // Đọc thẳng danh sách reward-settlements để member KHÔNG bị "mù" thưởng khi
  // BE không embed submission/rewardSetting vào my-assignments.
  Widget _rewardBanner(TaskProvider taskState) {
    final pending = taskState.rewardSettlements
        .where(
          (s) => s.status == 'WAITING_CONFIRMATION' || s.status == 'DISPUTED',
        )
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: pending
            .map(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phần thưởng ${_fmtAmount(s.amount)} — ${s.statusLabel}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s.status == 'WAITING_CONFIRMATION') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => context
                                    .read<TaskProvider>()
                                    .confirmRewardReceived(s.id),
                                child: Text(
                                  '✅ Đã nhận',
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
                              height: 34,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.danger,
                                  ),
                                ),
                                onPressed: () => _showRewardDisputeDialog(s.id),
                                child: Text(
                                  'Chưa nhận',
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
            )
            .toList(),
      ),
    );
  }

  void _showRewardDisputeDialog(String settlementId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Báo chưa nhận thưởng'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Lý do (ví dụ: chưa nhận được tiền)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dCtx);
              await context.read<TaskProvider>().createDispute(
                settlementId,
                reason,
              );
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final all = taskState.myAssignments;
    final done = all.where((a) => a.status == 'APPROVED').length;
    final total = all.length;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            taskState.fetchMyAssignments(),
            taskState.fetchRewardSettlements(),
          ]),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Text(
                      '📋 Nhiệm vụ',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.safe.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$done/$total hoàn thành',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.safe,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.safe,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tiến độ: ${total > 0 ? (done / total * 100).round() : 0}% · ${total - done} việc còn lại',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _filters
                      .map(
                        (f) => GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _filter == f
                                  ? AppColors.link
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              f,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _filter == f
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 🎁 Thưởng chờ xác nhận — hiển thị ĐỘC LẬP với card assignment
              // (my-assignments không embed latestSubmissionId → match theo
              // submission không bao giờ khớp, xem task_provider).
              _rewardBanner(taskState),

              if (taskState.loading && all.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (taskState.error != null && all.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lỗi tải dữ liệu',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => taskState.fetchMyAssignments(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: _filtered(all).isEmpty
                      ? Center(
                          child: Text(
                            'Không có nhiệm vụ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textMuted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filtered(all).length,
                          itemBuilder: (_, i) =>
                              _assignmentCard(context, _filtered(all)[i]),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, TaskAssignment a) {
    final cat = a.task?.taskCategoryName;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _catIcon(cat),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.taskTitle ?? a.task?.title ?? 'Nhiệm vụ',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (a.task?.isRecurring == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🔁 Định kỳ',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (cat != null || a.dueAt != null)
                        Row(
                          children: [
                            if (cat != null)
                              Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            if (cat != null && a.dueAt != null)
                              const Text(
                                ' · ',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            if (a.dueAt != null)
                              Text(
                                'Hạn: ${_fmtDate(a.dueAt!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      if (a.task?.isRecurring == true &&
                          a.task?.schedule != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '⏰ ${a.task!.schedule!.label}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (a.rewardSetting != null ||
                          a.task?.rewardSetting != null)
                        Wrap(
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.income.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '💰 ${(a.rewardSetting ?? a.task!.rewardSetting!).label}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.income,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: a.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    a.statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: a.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (a.status == 'ASSIGNED' || a.status == 'PENDING')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await context.read<TaskProvider>().startAssignment(a.id);
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
                  child: Text(
                    'Bắt đầu làm ▶️',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          if (a.status == 'IN_PROGRESS')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.link,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _submitTask(context, a),
                        child: Text(
                          'Nộp nhiệm vụ ✅',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (a.task?.isRecurring == true) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFEA580C),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _reportUnavailable(context, a),
                          child: Text(
                            '🚫 Bận',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          if (a.status == 'REJECTED')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_rounded,
                      size: 16,
                      color: AppColors.sos,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ba/Mẹ đã từ chối. Hãy thực hiện lại và nộp mới.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _submitTask(context, a),
                      child: Text(
                        'Nộp lại →',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (a.status == 'APPROVED' &&
              (a.rewardSetting ?? a.task?.rewardSetting) != null)
            _RewardConfirmBar(assignment: a),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}';

  // ── Nộp nhiệm vụ kèm proof (ảnh / note) ───────────────────────────────────

  void _submitTask(BuildContext context, TaskAssignment a) {
    final noteCtrl = TextEditingController();
    String? pickedImagePath;
    bool uploading = false;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nộp nhiệm vụ',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.taskTitle ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Thêm ghi chú cho Ba/Mẹ...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: uploading
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (img != null) {
                            setSheet(() => pickedImagePath = img.path);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: pickedImagePath != null
                          ? const Color(0xFFDCFCE7)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pickedImagePath != null
                            ? AppColors.success
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pickedImagePath != null
                              ? Icons.check_circle_rounded
                              : Icons.camera_alt_rounded,
                          color: pickedImagePath != null
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedImagePath != null
                                ? '📷 Đã chọn ảnh minh chứng'
                                : 'Đính kèm ảnh bằng chứng (tùy chọn)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: pickedImagePath != null
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (pickedImagePath != null)
                          GestureDetector(
                            onTap: () => setSheet(() => pickedImagePath = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.safe,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheet(() => submitting = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final provider = context.read<TaskProvider>();
                            try {
                              final proofs = <TaskProof>[];
                              if (pickedImagePath != null) {
                                setSheet(() => uploading = true);
                                final proof = await provider.uploadProof(
                                  pickedImagePath!,
                                  'IMAGE',
                                );
                                setSheet(() => uploading = false);
                                if (proof != null) proofs.add(proof);
                              }
                              if (noteCtrl.text.trim().isNotEmpty &&
                                  proofs.isEmpty) {
                                proofs.add(
                                  TaskProof(
                                    proofType: 'NOTE',
                                    note: noteCtrl.text.trim(),
                                  ),
                                );
                              }
                              await provider.submitProof(
                                a.id,
                                submissionNote: noteCtrl.text.trim(),
                                proofs: proofs,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã nộp! Chờ Ba/Mẹ duyệt nhé 🎉',
                                  ),
                                  backgroundColor: AppColors.safe,
                                ),
                              );
                            } catch (e) {
                              setSheet(() {
                                submitting = false;
                                uploading = false;
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
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
                            'Xác nhận nộp',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Báo cáo không thể thực hiện ───────────────────────────────────────────

  void _reportUnavailable(BuildContext context, TaskAssignment a) {
    final reasonCtrl = TextEditingController();
    bool submitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.do_not_disturb_on_rounded,
                    size: 28,
                    color: AppColors.accent500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Báo cáo không thể thực hiện',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.taskTitle ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('ℹ️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ba/Mẹ sẽ phân công lại nếu không ai nhận.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Lý do (VD: Con bị ốm, đang có việc khác...)',
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: submitting || reasonCtrl.text.trim().isEmpty
                            ? null
                            : () async {
                                setSheet(() => submitting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await context
                                      .read<TaskProvider>()
                                      .reportUnavailability(
                                        a.id,
                                        reasonCtrl.text.trim(),
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Đã báo. Ba/Mẹ sẽ phân công lại.',
                                      ),
                                      backgroundColor: Color(0xFFEA580C),
                                    ),
                                  );
                                } catch (e) {
                                  setSheet(() => submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Xác nhận báo bận',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reward confirm/dispute bar — hiện khi task APPROVED và có reward ──────────

class _RewardConfirmBar extends StatefulWidget {
  final TaskAssignment assignment;
  const _RewardConfirmBar({required this.assignment});
  @override
  State<_RewardConfirmBar> createState() => _RewardConfirmBarState();
}

class _RewardConfirmBarState extends State<_RewardConfirmBar> {
  RewardSettlement? _settlement;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<TaskProvider>();
    await provider.fetchRewardSettlements();
    if (!mounted) return;
    setState(() {
      _settlement = provider.rewardSettlements
          .where((s) => s.submissionId == widget.assignment.latestSubmissionId)
          .firstOrNull;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reward =
        (widget.assignment.rewardSetting ??
        widget.assignment.task?.rewardSetting)!;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_settlement == null) return const SizedBox.shrink();

    final s = _settlement!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Phần thưởng: ${reward.label} — ${s.statusLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            // Enum thật: WAITING_CONFIRMATION (verify Swagger 2026-07-08) —
            // trước đó check 'PAID' sai, nút xác nhận không bao giờ hiện ra.
            if (s.status == 'WAITING_CONFIRMATION') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () async {
                          await context
                              .read<TaskProvider>()
                              .confirmRewardReceived(s.id);
                          _load();
                        },
                        child: Text(
                          '✅ Đã nhận',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
                      height: 32,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        onPressed: () => _showDisputeDialog(context, s.id),
                        child: Text(
                          'Chưa nhận',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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

  void _showDisputeDialog(BuildContext context, String settlementId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Báo chưa nhận thưởng'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Lý do...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              await context.read<TaskProvider>().createDispute(
                settlementId,
                reasonCtrl.text.trim(),
              );
              if (dCtx.mounted) Navigator.pop(dCtx);
              _load();
            },
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}
