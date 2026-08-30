import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../shared/task_submission_recap.dart';

class ChildTasksScreen extends StatefulWidget {
  const ChildTasksScreen({super.key});
  @override
  State<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends State<ChildTasksScreen> {
  /// "Quá hạn" tính từ DateTime.now() lúc build. Mở màn hình rồi để đó thì
  /// không có gì bắt build lại, nhãn quá hạn không bao giờ bật lên dù đã trễ.
  /// Nhịp 1 phút đủ mịn cho hạn tính theo phút mà không tốn gì.
  Timer? _overdueTicker;

  String _filter = 'Tất cả';
  final _filters = ['Tất cả', 'Chờ làm', 'Quá hạn', 'Đã nộp', 'Hoàn thành'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchMyAssignments();
      // Cho banner thưởng: settlement WAITING_CONFIRMATION cần member xác nhận.
      context.read<TaskProvider>().fetchRewardSettlements();
      // Cần để đổi id người giao thành tên khi BE chỉ trả id.
      final family = context.read<FamilyProvider>();
      if (family.members.isEmpty) family.fetchMembers();
    });
    // Xem giải thích ở [_overdueTicker].
    _overdueTicker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _overdueTicker?.cancel();
    super.dispose();
  }

  List<TaskAssignment> _filtered(List<TaskAssignment> list) {
    bool overdue(TaskAssignment a) => isAssignmentOverdue(a);
    switch (_filter) {
      case 'Chờ làm':
        // ASSIGNED là assignment mới giao; IN_PROGRESS vẫn nằm trong nhóm việc
        // cần người dùng xử lý. Việc quá hạn được tách riêng để không che
        // nhiệm vụ còn có thể hoàn tất.
        return list
            .where(
              (a) =>
                  !overdue(a) &&
                  (a.status == 'ASSIGNED' || a.status == 'IN_PROGRESS'),
            )
            .toList();
      case 'Quá hạn':
        return list.where(overdue).toList();
      case 'Đã nộp':
        return list.where((a) => a.status == 'SUBMITTED').toList();
      case 'Hoàn thành':
        return list.where((a) => a.status == 'APPROVED').toList();
      default:
        // Việc còn xử lý được phải đứng trước. Quá hạn được gom về cuối để
        // không che khuất nhiệm vụ mới; tab "Quá hạn" là nơi xử lý riêng.
        return [...list]..sort((a, b) {
          final aOverdue = overdue(a);
          final bOverdue = overdue(b);
          if (aOverdue != bOverdue) return aOverdue ? 1 : -1;
          return 0; // giữ thứ tự BE trong từng nhóm
        });
    }
  }

  IconData _catIcon(String? cat) =>
      cat == 'Học tập' ? Icons.school_outlined : Icons.home_outlined;

  static String _fmtAmount(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()} ₫';
  }

  // ── Banner thưởng chờ xác nhận (WAITING_CONFIRMATION) + tranh chấp ─────
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
                        const Icon(
                          Icons.card_giftcard_rounded,
                          size: 16,
                          color: Color(0xFF92400E),
                        ),
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
                                  'Đã nhận',
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

  Future<void> _showRewardDisputeDialog(String settlementId) async {
    final reasonCtrl = TextEditingController();
    final focusNode = FocusNode();
    final reason = await showDialog<String>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Báo chưa nhận thưởng'),
          content: TextField(
            controller: reasonCtrl,
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (value) {
              final reason = value.trim();
              if (reason.isNotEmpty) Navigator.pop(dCtx, reason);
            },
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
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dCtx, reasonCtrl.text.trim()),
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    focusNode.dispose();
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    try {
      await context.read<TaskProvider>().createDispute(settlementId, reason);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể gửi báo cáo. Vui lòng thử lại.'),
          ),
        );
      }
    }
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
                      'Nhiệm vụ',
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

              // Thưởng chờ xác nhận — hiển thị ĐỘC LẬP với card assignment
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
    final effectiveDueAt = a.dueAt ?? a.task?.dueAt;
    final isOverdue = _isOverdue(a, effectiveDueAt);
    final isNotStarted = isAssignmentNotStarted(a);
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
                  child: Icon(_catIcon(cat), size: 24, color: AppColors.link),
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
                                'Định kỳ',
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
                      if (cat != null || effectiveDueAt != null || isOverdue)
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
                            if (cat != null && effectiveDueAt != null)
                              const Text(
                                ' · ',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            if (effectiveDueAt != null)
                              Text(
                                // Có giờ phút mới nói được "đã trễ hay chưa":
                                // hạn 13:35 mà chỉ hiện "Hạn: 19/8" thì người
                                // làm không hiểu vì sao đang bị tính quá hạn.
                                'Hạn: ${_fmtDateTime(effectiveDueAt)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isOverdue
                                      ? AppColors.danger
                                      : AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      if (isOverdue)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Quá hạn',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      if (a.task?.isRecurring == true &&
                          a.task?.schedule != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            a.task!.schedule!.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ?_assignerLine(context, a),
                      if (a.startAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Bắt đầu: ${_fmtDate(a.startAt!)}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
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
                                (a.rewardSetting ?? a.task!.rewardSetting!)
                                    .label,
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

          // Ba nút hành động bên dưới đều dẫn tới nộp bài, mà BE chặn nộp khi
          // quá hạn → ẩn hết, thay bằng một câu nói rõ phải làm gì.
          if (isOverdue &&
              (a.status == 'ASSIGNED' ||
                  a.status == 'IN_PROGRESS' ||
                  a.status == 'REJECTED'))
            _overdueBlockedNote(a),

          if (isNotStarted &&
              (a.status == 'ASSIGNED' ||
                  a.status == 'IN_PROGRESS' ||
                  a.status == 'REJECTED'))
            _notStartedNote(a),

          if (a.status == 'ASSIGNED' && !isOverdue && !isNotStarted)
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
                        onPressed: () async {
                          try {
                            await context.read<TaskProvider>().startAssignment(
                              a.id,
                            );
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
                          'Bắt đầu làm',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Báo bận ngay lúc mới nhận việc — không cần bắt đầu làm
                  // trước, cũng không giới hạn chỉ nhiệm vụ lặp. BE (POST
                  // .../unavailability) không đặt giới hạn này, đây là do
                  // FE tự gate khi wire màn hình trước đó.
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
                          'Bận',
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
              ),
            ),

          if (a.status == 'IN_PROGRESS' && !isOverdue && !isNotStarted)
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
                          'Nộp nhiệm vụ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bỏ giới hạn "chỉ task lặp" — BE không yêu cầu, và task
                  // thường cũng cần đường báo không làm được.
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
                          'Bận',
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
              ),
            ),

          // Người nộp phải xem lại được minh chứng đã gửi và nhận xét của
          // người duyệt. Trước đây chỉ màn quản lý gọi fetchLatestSubmission
          // nên member chỉ thấy mỗi chip trạng thái.
          if (a.status == 'SUBMITTED' ||
              a.status == 'APPROVED' ||
              a.status == 'REJECTED')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TaskSubmissionRecap(
                assignmentId: a.id,
                assignmentStatus: a.status,
              ),
            ),

          if (a.status == 'REJECTED' && !isOverdue)
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
                        // Lý do thật nằm trong reviewNote, do khối bên trên
                        // hiển thị. Câu này chỉ còn nhiệm vụ chỉ bước tiếp
                        // theo, không giả vờ là đã giải thích xong.
                        'Bị từ chối. Đọc nhận xét ở trên rồi làm lại và nộp mới.',
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

  static String _fmtDateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day}/${d.month} ${two(d.hour)}:${two(d.minute)}';
  }

  bool _isOverdue(TaskAssignment a, DateTime? dueAt) =>
      // [dueAt] giữ lại ở chữ ký để các call site đang dùng task.dueAt không
      // phải tự suy luận; nguồn quyết định ưu tiên là isOverdue do BE trả về.
      isAssignmentOverdue(a);

  /// Quá hạn thì BE chặn nộp bài (400 `SUBMISSION_OVERDUE`). Người quản lý có
  /// thể gia hạn đúng assignment bằng PATCH thời hạn, hoặc giao lại kèm hạn mới.
  ///
  /// Để nút "Nộp nhiệm vụ" bấm được rồi mới ăn lỗi là dồn người làm vào ngõ cụt
  /// mà không nói phải làm gì. Khoá nút và nói thẳng.
  Widget _overdueBlockedNote(TaskAssignment a) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            size: 16,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã quá hạn nên không nộp bài được nữa. Nhắn người quản lý bấm '
              '"Gia hạn" để dời hạn cho bạn nhé.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _notStartedNote(TaskAssignment a) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nhiệm vụ này bắt đầu từ ${_fmtDateTime(a.startAt!)}. Bạn chưa thể bắt đầu hoặc nộp bài sớm.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                color: const Color(0xFF1E3A8A),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Dòng "Người giao" cho thành viên biết ai giao việc này.
  ///
  /// Tên có thể nằm ở assignment hoặc ở task tùy BE trả; nếu chỉ có id thì tra
  /// tiếp trong danh sách thành viên. Không ra được tên nào thì trả null để ẩn
  /// hẳn dòng — hiện "Người giao: Không rõ" chỉ làm nhiễu.
  Widget? _assignerLine(BuildContext context, TaskAssignment a) {
    final name = _assignerName(context, a);
    if (name == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Người giao: $name',
        style: GoogleFonts.inter(
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String? _assignerName(BuildContext context, TaskAssignment a) {
    final direct = (a.assignedByName ?? a.task?.createdByName)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final id = (a.assignedByMemberId ?? a.task?.createdByMemberId)?.trim();
    if (id == null || id.isEmpty) return null;
    for (final m in context.read<FamilyProvider>().members) {
      if (m.id == id || m.userId == id) {
        return m.name.trim().isEmpty ? null : m.name.trim();
      }
    }
    return null;
  }

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

                // Chỉ là lớp phòng thủ: card quá hạn không mở được sheet này.
                // BE là nguồn quyết định và trả SUBMISSION_OVERDUE khi chặn.
                if (_isOverdue(a, a.dueAt ?? a.task?.dueAt)) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Color(0xFF92400E),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nhiệm vụ đã quá hạn. Hãy nhờ người quản lý gia hạn '
                            'hoặc giao lại trước khi nộp bài.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.35,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  // Nút Nộp bật/tắt theo việc đã có gì để nộp chưa → phải dựng
                  // lại sheet mỗi lần gõ.
                  onChanged: (_) => setSheet(() {}),
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
                Text(
                  'Thêm ghi chú hoặc chọn một ảnh minh chứng để nộp bài.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),

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
                                ? 'Đã chọn ảnh minh chứng'
                                : 'Chọn ảnh minh chứng (nếu không ghi chú)',
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
                    // `proofs` là field BẮT BUỘC của CreateTaskSubmissionDto —
                    // không ảnh, không ghi chú thì gửi đi chắc chắn hỏng. Khoá
                    // nút thay vì để bấm rồi ăn lỗi BE khó hiểu.
                    onPressed:
                        submitting ||
                            (pickedImagePath == null &&
                                noteCtrl.text.trim().isEmpty)
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
                                // Upload hỏng mà im lặng bỏ qua thì người dùng
                                // tưởng đã đính kèm ảnh, còn bài nộp thì không
                                // có gì. Dừng hẳn để họ thử lại.
                                if (proof == null) {
                                  throw Exception(
                                    'Không tải được ảnh lên. Kiểm tra mạng rồi '
                                    'chọn lại ảnh giúp mình nhé.',
                                  );
                                }
                                proofs.add(proof);
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
                                  content: Text('Đã nộp! Chờ Ba/Mẹ duyệt nhé'),
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
                                  content: Text(submitProofErrorMessage(e)),
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
                                        'Đã báo. Ba/Mẹ sẽ phân công lại.',
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
    // `assignment.latestSubmissionId` gần như luôn rỗng ở đây: widget này
    // dùng thẳng assignment lấy từ `fetchMyAssignments()` (danh sách), mà
    // GET .../my-assignments không embed submission (xác nhận response thật
    // 24/08 — object chỉ có status, không có submission/latestSubmission).
    // So `s.submissionId == null` với mọi settlement thật luôn trượt, nên
    // banner phần thưởng phía member (kể cả khi đã bị huỷ/tranh chấp) im
    // lặng vĩnh viễn dù task đã APPROVED — gọi thêm endpoint theo assignment
    // để lấy đúng submissionId thật.
    await provider.fetchRewardSettlements();
    final submission = await provider.fetchLatestSubmission(
      widget.assignment.id,
    );
    final submissionId =
        submission?.id ?? widget.assignment.latestSubmissionId ?? '';
    if (!mounted) return;
    setState(() {
      _settlement = submissionId.isEmpty
          ? null
          : provider.rewardSettlements
                .where((s) => s.submissionId == submissionId)
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
                const Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: Color(0xFF92400E),
                ),
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
                          'Đã nhận',
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
                        onPressed: () => _showDisputeDialog(s.id),
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

  Future<void> _showDisputeDialog(String settlementId) async {
    final reasonCtrl = TextEditingController();
    final focusNode = FocusNode();
    final reason = await showDialog<String>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Báo chưa nhận thưởng'),
          content: TextField(
            controller: reasonCtrl,
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (value) {
              final reason = value.trim();
              if (reason.isNotEmpty) Navigator.pop(dCtx, reason);
            },
            decoration: const InputDecoration(hintText: 'Lý do...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dCtx, reasonCtrl.text.trim()),
              child: const Text('Gửi báo cáo'),
            ),
          ],
        ),
      ),
    );
    focusNode.dispose();
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    try {
      await context.read<TaskProvider>().createDispute(settlementId, reason);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể gửi báo cáo. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }
}
