import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});
  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  String? _filter;

  static const _statusCfg = {
    'DRAFT':     (label: 'Bản nháp',  bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    'ACTIVE':    (label: 'Đang chạy', bg: Color(0xFFEFF6FF), color: AppColors.planned),
    'COMPLETED': (label: 'Hoàn thành',bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    'CANCELED':  (label: 'Đã hủy',    bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
      context.read<TaskProvider>().fetchCategories();
      context.read<FamilyProvider>().fetchMembers();
      // Cho badge 💳: đếm settlement chờ trả/tranh chấp trên icon AppBar.
      context.read<TaskProvider>().fetchRewardSettlements();
    });
  }

  List<FamilyTask> _filtered(List<FamilyTask> tasks) =>
      _filter == null ? tasks : tasks.where((t) => t.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final tasks      = taskState.tasks;
    final active      = tasks.where((t) => t.status == 'ACTIVE').length;
    final completed   = tasks.where((t) => t.status == 'COMPLETED').length;
    // Settlement cần Manager xử lý: chờ trả (PENDING_SETTLEMENT) + tranh chấp.
    final pendingRewards = taskState.rewardSettlements
        .where((s) => s.status == 'PENDING_SETTLEMENT' || s.status == 'DISPUTED')
        .length;

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
              const Expanded(child: Center(child: Text('Quản lý Tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
              GestureDetector(
                onTap: () => context.push('/manager/reward-management'),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40, height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                    child: const Icon(Icons.payments_outlined, size: 18, color: AppColors.textPrimary),
                  ),
                  // Badge số settlement chờ trả/tranh chấp — entry Quản lý
                  // thưởng vốn chỉ là icon, không badge thì Manager không biết.
                  if (pendingRewards > 0)
                    Positioned(
                      top: -2, right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.5)),
                        alignment: Alignment.center,
                        child: Text('$pendingRewards',
                            style: GoogleFonts.inter(fontSize: 9, height: 1, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                ]),
              ),
              GestureDetector(
                onTap: () => _showCreateTaskSheet(context),
                child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), child: const Icon(Icons.add, color: Colors.white)),
              ),
            ]),
          ),

          if (taskState.loading && tasks.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (taskState.error != null && tasks.isEmpty)
            Expanded(child: _errorView(taskState.error!, () => taskState.fetchTasks()))
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _summaryCard(tasks.length, 'Tổng', AppColors.textPrimary),
                const SizedBox(width: 12),
                _summaryCard(active, 'Đang chạy', AppColors.link),
                const SizedBox(width: 12),
                _summaryCard(completed, 'Xong', AppColors.success),
              ]),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _filterChip(null,        'Tất cả'),
                  _filterChip('ACTIVE',    'Đang chạy'),
                  _filterChip('DRAFT',     'Bản nháp'),
                  _filterChip('COMPLETED', 'Hoàn thành'),
                  _filterChip('CANCELED',  'Đã hủy'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => taskState.fetchTasks(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ..._filtered(tasks).map((task) => _taskCard(context, task)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _taskCard(BuildContext context, FamilyTask task) {
    final st = _statusCfg[task.status] ?? _statusCfg['ACTIVE']!;
    return GestureDetector(
      onTap: () => _showTaskDetailSheet(context, task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 4, height: 56, decoration: BoxDecoration(color: AppColors.planned, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip(st.label, st.bg, st.color),
                if (task.isRecurring) _chip('🔁 ${task.schedule?.label ?? "Định kỳ"}', const Color(0xFFF0F9FF), const Color(0xFF0369A1)),
                if (task.taskCategoryName != null) _chip('🏷️ ${task.taskCategoryName}', const Color(0xFFF3F4F6), AppColors.textSecondary),
                if (task.rewardSetting != null)
                  _chip('💰 ${task.rewardSetting!.label}', const Color(0xFFDCFCE7), const Color(0xFF16A34A))
                else
                  _chip('🎁 Chưa đặt thưởng', const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  // ── Task detail bottom sheet: assignments + actions ──────────────────────

  void _showTaskDetailSheet(BuildContext context, FamilyTask task) {
    context.read<TaskProvider>().fetchTaskAssignments(task.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Consumer<TaskProvider>(
          builder: (_, taskState, _) {
            final assignments = taskState.assignmentsFor(task.id);
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(task.title, style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(task.description!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ]),
                  ),
                  if (task.status != 'CANCELED' && task.status != 'COMPLETED')
                    GestureDetector(
                      onTap: () => _showEditTaskSheet(context, task),
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 18, color: AppColors.link)),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // Task LẶP không dùng được POST .../assignments (BE trả
                      // "Vui lòng sinh phân công ... bằng API lịch lặp") →
                      // phân nhánh sang _ScheduleSheet (generate-assignments).
                      onPressed: () => task.isRecurring
                          ? _showScheduleSheet(context, task)
                          : _showAssignSheet(context, task),
                      icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                      label: Text('Giao việc', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRewardSettingSheet(context, task),
                      icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                      label: Text('Đặt thưởng', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                ]),
                if (task.isRecurring) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showScheduleSheet(context, task),
                    icon: const Icon(Icons.event_repeat_rounded, size: 16),
                    label: Text('Lịch lặp & tạo phân công', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  ),
                ],
                const SizedBox(height: 8),
                if (task.status != 'CANCELED' && task.status != 'COMPLETED')
                  TextButton(
                    onPressed: () async {
                      await context.read<TaskProvider>().cancelTask(task.id);
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    },
                    child: Text('Hủy task', style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger)),
                  ),
                const SizedBox(height: 12),
                Text('Phân công (${assignments.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                if (assignments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Chưa giao cho ai', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                  )
                else
                  ...assignments.map((a) => _assignmentCard(context, a)),
              ],
            );
          },
        ),
      ),
    );
  }

  // PATCH /tasks/{taskId} — sửa tên/mô tả/mức ưu tiên task đã tạo.
  void _showEditTaskSheet(BuildContext context, FamilyTask task) {
    final titleCtrl = TextEditingController(text: task.title);
    final descCtrl = TextEditingController(text: task.description ?? '');
    String priority = task.priority;
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✏️ Sửa task', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text('Tên task', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(titleCtrl, 'Tên task'),
              const SizedBox(height: 12),
              Text('Mô tả', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(descCtrl, 'Chi tiết công việc (tùy chọn)'),
              const SizedBox(height: 12),
              Text('Mức ưu tiên', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final p in ['LOW', 'MEDIUM', 'HIGH'])
                  ChoiceChip(
                    label: Text(switch (p) { 'LOW' => 'Thấp', 'HIGH' => 'Cao', _ => 'Trung bình' }),
                    selected: priority == p,
                    onSelected: (_) => setSheet(() => priority = p),
                  ),
              ]),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: submitting ? null : () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    setSheet(() => sheetError = 'Nhập tên task');
                    return;
                  }
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<TaskProvider>().updateTask(task.id, {
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'priority': priority,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Lưu thay đổi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, TaskAssignment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarWidget(
            initial: (a.assignedToName ?? '?').isNotEmpty ? (a.assignedToName ?? '?').substring(0, 1).toUpperCase() : '?',
            color: AppColors.avatarOrange,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.assignedToName ?? 'Thành viên', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(a.statusLabel, style: GoogleFonts.inter(fontSize: 12, color: a.statusColor, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (a.status == 'SUBMITTED')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => _showReviewSheet(context, a),
              child: Text('Duyệt', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          // Duyệt/từ chối xong vẫn xem lại được bài nộp (chế độ chỉ xem)
          if (a.status == 'APPROVED' || a.status == 'REJECTED')
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              onPressed: () => _showReviewSheet(context, a, readOnly: true),
              child: Text('Xem bài nộp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          if (a.status == 'UNAVAILABLE')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => _showReassignSheet(context, a),
              child: Text('Phân công lại', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          if (a.status == 'PENDING' || a.status == 'IN_PROGRESS')
            GestureDetector(
              onTap: () async {
                final tp = context.read<TaskProvider>();
                await tp.cancelAssignment(a.id);
                // cancelAssignment() chỉ refresh myAssignments (view member) —
                // sheet Manager đang xem theo _assignmentsByTask[taskId], phải
                // refetch riêng để badge trạng thái cập nhật ngay.
                await tp.fetchTaskAssignments(a.taskId);
              },
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Review submission ─────────────────────────────────────────────────────

  Future<void> _showReviewSheet(BuildContext context, TaskAssignment a, {bool readOnly = false}) async {
    // BE không embed submission trong response danh sách assignment (chỉ có
    // status), nên KHÔNG có proofs sẵn trên TaskAssignment dù
    // latestSubmissionId có giá trị — luôn phải gọi riêng endpoint
    // submissions để lấy submission đầy đủ (kèm proofs) trước khi duyệt.
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final submission = await context.read<TaskProvider>().fetchLatestSubmission(a.id);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // đóng loading

    if (submission == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(readOnly ? 'Không tìm thấy bài nộp nào' : 'Không tìm thấy bài nộp để duyệt — thử tải lại'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    if (!context.mounted) return;

    final noteCtrl = TextEditingController();
    bool submitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(readOnly ? 'Bài nộp của ${a.assignedToName ?? 'thành viên'}' : 'Duyệt công việc',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(a.taskTitle ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              if (readOnly) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: a.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(a.statusLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: a.statusColor)),
                ),
              ],
              if (submission.submissionNote != null && submission.submissionNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Text(submission.submissionNote!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],
              if (submission.proofs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Minh chứng (${submission.proofs.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...submission.proofs.map(_proofPreview),
              ],
              // Ghi chú đánh giá cũ (nếu có) — hiện ở chế độ xem lại
              if (readOnly && (submission.reviewNote ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Ghi chú đánh giá', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Text(submission.reviewNote!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],
              if (!readOnly) ...[
              const SizedBox(height: 16),
              _inputBox(noteCtrl, 'Ghi chú (tùy chọn)'),
              ],
              const SizedBox(height: 16),
              if (!readOnly) Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: submitting ? null : () async {
                      setSheet(() => submitting = true);
                      final sheetMessenger = ScaffoldMessenger.of(context);
                      try {
                        await context.read<TaskProvider>().reviewSubmission(submission.id, approved: true, reviewNote: noteCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        // Task có thưởng → BE vừa tạo settlement chờ trả;
                        // nhắc Manager sang màn Quản lý thưởng (icon 💳).
                        if ((a.rewardSetting ?? a.task?.rewardSetting) != null) {
                          sheetMessenger.showSnackBar(SnackBar(
                            content: const Text('Đã duyệt ✅ — vào 💳 Quản lý thưởng (góc phải màn Tasks) để trả thưởng'),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 4),
                          ));
                        }
                      } catch (e) {
                        setSheet(() => submitting = false);
                        sheetMessenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                      }
                    },
                    child: Text('✓ Duyệt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: submitting ? null : () async {
                      setSheet(() => submitting = true);
                      final sheetMessenger = ScaffoldMessenger.of(context);
                      try {
                        await context.read<TaskProvider>().reviewSubmission(submission.id, approved: false, reviewNote: noteCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setSheet(() => submitting = false);
                        sheetMessenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                      }
                    },
                    child: Text('✕ Từ chối', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // Preview 1 proof minh chứng: ảnh hiển thị trực tiếp, video/file/note hiện
  // dạng card có icon (không có player video trong scope này).
  Widget _proofPreview(TaskProof proof) {
    if (proof.proofType == 'IMAGE' && (proof.fileUrl ?? '').isNotEmpty) {
      final url = ApiClient.absoluteUrl(proof.fileUrl!);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    height: 180,
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (_, _, _) => Container(
              height: 100,
              color: AppColors.background,
              alignment: Alignment.center,
              child: Text('Không tải được ảnh', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ),
          ),
        ),
      );
    }
    // NOTE / FILE / VIDEO không có ảnh preview — hiện card thông tin
    final icon = switch (proof.proofType) { 'VIDEO' => '🎥', 'FILE' => '📎', _ => '📝' };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            proof.note?.isNotEmpty == true ? proof.note! : (proof.fileUrl ?? proof.proofType),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ]),
    );
  }

  // ── Assign to member ──────────────────────────────────────────────────────

  void _showAssignSheet(BuildContext context, FamilyTask task) {
    // Chỉ member ACTIVE — tránh gán nhầm thành viên đã REMOVED (BE /families/my
    // từng lẫn REMOVED) → khỏi bị "thành viên không hợp lệ". Nhất quán với
    // picker định kỳ (_GenerateAssignments) vốn đã lọc isActive.
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
    String? selectedId;
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
            Text('Giao việc cho', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(task.title, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // Dùng m.id (bản ghi thành viên trong gia đình) — KHÔNG dùng m.userId
            ...members.map((m) => RadioListTile<String>(
                  value: m.id,
                  groupValue: selectedId,
                  onChanged: (v) => setSheet(() { selectedId = v; sheetError = null; }),
                  title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                  subtitle: Text(m.roleLabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  contentPadding: EdgeInsets.zero,
                )),
            if (sheetError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: (submitting || selectedId == null) ? null : () async {
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    await context.read<TaskProvider>().assignTask(task.id, assignedToMemberId: selectedId!);
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

  // ── Reassign (member báo bận) ─────────────────────────────────────────────

  void _showReassignSheet(BuildContext context, TaskAssignment a) {
    // a.assignedToMemberId là familyMember.id — lọc đúng theo m.id, và chỉ
    // member ACTIVE (khỏi reassign nhầm sang thành viên đã REMOVED).
    final members = context.read<FamilyProvider>().members
        .where((m) => m.isActive && m.id != a.assignedToMemberId).toList();
    String? selectedId;
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
            Text('🔄 Phân công lại', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('${a.assignedToName} đã báo không thể thực hiện.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ...members.map((m) => RadioListTile<String>(
                  value: m.id,
                  groupValue: selectedId,
                  onChanged: (v) => setSheet(() { selectedId = v; sheetError = null; }),
                  title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                )),
            if (sheetError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: (submitting || selectedId == null) ? null : () async {
                  setSheet(() { submitting = true; sheetError = null; });
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await context.read<TaskProvider>().reassignAssignment(a.id, assignedToMemberId: selectedId!);
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(const SnackBar(content: Text('Đã phân công lại ✅'), backgroundColor: AppColors.success));
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

  // ── Schedule (recurring task) ────────────────────────────────────────────
  // GET .../schedule (refresh), PATCH .../schedule (sửa), POST
  // .../schedule/generate-assignments (tạo phân công hàng loạt).
  void _showScheduleSheet(BuildContext context, FamilyTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ScheduleSheet(task: task),
    );
  }

  // ── Reward setting ────────────────────────────────────────────────────────

  void _showRewardSettingSheet(BuildContext context, FamilyTask task) {
    String rewardType = task.rewardSetting?.rewardType ?? 'MONEY_RECORD';
    final amountCtrl = TextEditingController(text: task.rewardSetting?.rewardAmount.toStringAsFixed(0) ?? '');
    final descCtrl   = TextEditingController(text: task.rewardSetting?.rewardDescription ?? '');
    bool autoSettle  = task.rewardSetting?.autoCreateSettlement ?? true;
    bool submitting  = false;
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
            Text('🎁 Đặt phần thưởng', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              for (final t in ['MONEY_RECORD', 'POINT', 'OTHER'])
                ChoiceChip(
                  label: Text(switch (t) { 'MONEY_RECORD' => '💰 Tiền', 'POINT' => '⭐ Điểm', _ => '🎁 Khác' }),
                  selected: rewardType == t,
                  onSelected: (_) => setSheet(() => rewardType = t),
                ),
            ]),
            const SizedBox(height: 12),
            if (rewardType != 'OTHER') ...[
              Text(rewardType == 'POINT' ? 'Số điểm' : 'Số tiền (₫)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(amountCtrl, 'VD: 20000', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
            ],
            Text('Ghi chú', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _inputBox(descCtrl, 'Mô tả phần thưởng (tùy chọn)'),
            const SizedBox(height: 8),
            SwitchListTile(
              value: autoSettle,
              onChanged: (v) => setSheet(() => autoSettle = v),
              title: Text('Tự tạo thanh toán khi duyệt task', style: GoogleFonts.inter(fontSize: 13)),
              contentPadding: EdgeInsets.zero,
            ),
            if (sheetError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                child: Text(sheetError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: submitting ? null : () async {
                  setSheet(() { submitting = true; sheetError = null; });
                  try {
                    final tp = context.read<TaskProvider>();
                    // PATCH nếu task đã có reward-setting (sửa), POST nếu chưa (tạo mới).
                    if (task.rewardSetting != null) {
                      await tp.updateRewardSetting(
                        task.id,
                        rewardType: rewardType,
                        rewardAmount: double.tryParse(amountCtrl.text.trim()),
                        rewardDescription: descCtrl.text.trim(),
                        autoCreateSettlement: autoSettle,
                      );
                    } else {
                      await tp.setRewardSetting(
                        task.id,
                        rewardType: rewardType,
                        rewardAmount: double.tryParse(amountCtrl.text.trim()),
                        rewardDescription: descCtrl.text.trim(),
                        autoCreateSettlement: autoSettle,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                  }
                },
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(task.rewardSetting != null ? 'Lưu thay đổi' : 'Lưu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            if (task.rewardSetting != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: submitting ? null : () async {
                    setSheet(() { submitting = true; sheetError = null; });
                    try {
                      await context.read<TaskProvider>().deleteRewardSetting(task.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setSheet(() { submitting = false; sheetError = e.toString().replaceFirst('Exception: ', ''); });
                    }
                  },
                  child: Text('Xóa phần thưởng', style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Create task sheet (AD_HOC / RECURRING) ───────────────────────────────

  void _showCreateTaskSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String taskType = 'AD_HOC';
    String priority = 'MEDIUM';
    String? categoryId;
    String repeatType = 'DAILY';
    final intervalCtrl = TextEditingController(text: '1');
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final categories = context.watch<TaskProvider>().categories;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📋 Tạo task mới', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Row(children: [
                  _typeToggle(label: '⚡ Tự phát', selected: taskType == 'AD_HOC', onTap: () => setSheet(() => taskType = 'AD_HOC')),
                  const SizedBox(width: 8),
                  _typeToggle(label: '🔁 Định kỳ', selected: taskType == 'RECURRING', onTap: () => setSheet(() => taskType = 'RECURRING')),
                ]),
                const SizedBox(height: 14),
                Text('Tên task', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _inputBox(titleCtrl, 'VD: Dọn phòng khách, Đưa con đi học...'),
                const SizedBox(height: 12),
                Text('Mô tả', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                _inputBox(descCtrl, 'Chi tiết công việc (tùy chọn)'),
                const SizedBox(height: 12),

                Text('Danh mục', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...categories.map((c) => GestureDetector(
                        onLongPress: () => _showRenameCategoryDialog(context, c),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: categoryId == c.id,
                          onSelected: (_) => setSheet(() => categoryId = c.id),
                        ),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('Mới'),
                    onPressed: () => _showCreateCategoryDialog(context, (newId) => setSheet(() => categoryId = newId)),
                  ),
                ]),
                Text('Giữ để đổi tên danh mục', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 12),

                Text('Mức ưu tiên', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final p in ['LOW', 'MEDIUM', 'HIGH'])
                    ChoiceChip(
                      label: Text(switch (p) { 'LOW' => 'Thấp', 'HIGH' => 'Cao', _ => 'Trung bình' }),
                      selected: priority == p,
                      onSelected: (_) => setSheet(() => priority = p),
                    ),
                ]),
                const SizedBox(height: 12),

                if (taskType == 'RECURRING') ...[
                  Text('Lặp lại', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    for (final r in ['DAILY', 'WEEKLY', 'MONTHLY'])
                      ChoiceChip(
                        label: Text(switch (r) { 'DAILY' => 'Hàng ngày', 'WEEKLY' => 'Hàng tuần', _ => 'Hàng tháng' }),
                        selected: repeatType == r,
                        onSelected: (_) => setSheet(() => repeatType = r),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Text('Khoảng lặp (mỗi N ${repeatType == "DAILY" ? "ngày" : repeatType == "WEEKLY" ? "tuần" : "tháng"})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  _inputBox(intervalCtrl, '1', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: submitting ? null : () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    setSheet(() => submitting = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final taskProvider = context.read<TaskProvider>();
                      if (taskType == 'RECURRING') {
                        await taskProvider.createRecurringTask(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          taskCategoryId: categoryId,
                          priority: priority,
                          repeatType: repeatType,
                          repeatInterval: int.tryParse(intervalCtrl.text.trim()) ?? 1,
                          startDate: DateTime.now(),
                        );
                      } else {
                        await taskProvider.createTask(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          taskCategoryId: categoryId,
                          taskType: taskType,
                          priority: priority,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setSheet(() => submitting = false);
                      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                    }
                  },
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Tạo task', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context, void Function(String id) onCreated) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Danh mục mới'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'VD: Nhà cửa, Học tập...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final cat = await context.read<TaskProvider>().createCategory(name: nameCtrl.text.trim());
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (cat != null) onCreated(cat.id);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  // PATCH /tasks/categories/{categoryId} — đổi tên danh mục.
  void _showRenameCategoryDialog(BuildContext context, TaskCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Tên danh mục')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await context.read<TaskProvider>().updateCategory(category.id, name: nameCtrl.text.trim());
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ── Small widgets ──────────────────────────────────────────────────────────

  Widget _typeToggle({required String label, required bool selected, required VoidCallback onTap}) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: selected ? AppColors.link : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );

  Widget _inputBox(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      );

  Widget _errorView(String msg, VoidCallback onRetry) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Lỗi tải dữ liệu', style: GoogleFonts.inter(fontSize: 15, color: AppColors.danger)),
      const SizedBox(height: 8),
      Text(msg, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );

  Widget _summaryCard(int val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        Text('$val', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        Text(label,  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      ]),
    ),
  );

  Widget _filterChip(String? status, String label) {
    final active = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 40,
        decoration: BoxDecoration(
          color: active ? AppColors.link : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

// GET .../schedule (refresh mới nhất), PATCH .../schedule (sửa lịch lặp),
// POST .../schedule/generate-assignments (tạo hàng loạt phân công theo
// khoảng ngày cho 1 thành viên).
class _ScheduleSheet extends StatefulWidget {
  final FamilyTask task;
  const _ScheduleSheet({required this.task});
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  TaskSchedule? _schedule;
  bool _loadingSchedule = true;
  late String _repeatType;
  late final TextEditingController _intervalCtrl;
  bool _savingSchedule = false;
  String? _scheduleError;

  String? _genMemberId;
  DateTime _genFrom = DateTime.now();
  DateTime _genTo = DateTime.now().add(const Duration(days: 30));
  bool _generating = false;
  String? _genError;

  @override
  void initState() {
    super.initState();
    _repeatType = widget.task.schedule?.repeatType ?? 'DAILY';
    _intervalCtrl = TextEditingController(text: '${widget.task.schedule?.repeatInterval ?? 1}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedule());
  }

  @override
  void dispose() {
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    final s = await context.read<TaskProvider>().fetchSchedule(widget.task.id);
    if (mounted) {
      setState(() {
        _schedule = s ?? widget.task.schedule;
        _repeatType = _schedule?.repeatType ?? _repeatType;
        _intervalCtrl.text = '${_schedule?.repeatInterval ?? 1}';
        _loadingSchedule = false;
      });
    }
  }

  Future<void> _saveSchedule() async {
    setState(() { _savingSchedule = true; _scheduleError = null; });
    try {
      await context.read<TaskProvider>().updateSchedule(widget.task.id, {
        'repeatType': _repeatType,
        'repeatInterval': int.tryParse(_intervalCtrl.text.trim()) ?? 1,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu lịch lặp ✅'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) setState(() => _scheduleError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _savingSchedule = false);
    }
  }

  Future<void> _generate() async {
    if (_genMemberId == null) {
      setState(() => _genError = 'Chọn thành viên');
      return;
    }
    setState(() { _generating = true; _genError = null; });
    try {
      await context.read<TaskProvider>().generateAssignments(
        widget.task.id,
        assignedToMemberId: _genMemberId!,
        fromDate: _genFrom, toDate: _genTo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo phân công hàng loạt ✅'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) setState(() => _genError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<FamilyProvider>().members.where((m) => m.isActive).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔁 Lịch lặp', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (_loadingSchedule)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            Wrap(spacing: 8, children: [
              for (final r in ['DAILY', 'WEEKLY', 'MONTHLY'])
                ChoiceChip(
                  label: Text(switch (r) { 'DAILY' => 'Hàng ngày', 'WEEKLY' => 'Hàng tuần', _ => 'Hàng tháng' }),
                  selected: _repeatType == r,
                  onSelected: (_) => setState(() => _repeatType = r),
                ),
            ]),
            const SizedBox(height: 12),
            Text('Khoảng lặp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            if (_scheduleError != null) ...[
              const SizedBox(height: 8),
              Text(_scheduleError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _savingSchedule ? null : _saveSchedule,
                child: _savingSchedule
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Lưu lịch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text('Tạo phân công hàng loạt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text('Thành viên', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _genMemberId,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: members.map((m) => DropdownMenuItem(value: m.userId, child: Text(m.name))).toList(),
              onChanged: (v) => setState(() => _genMemberId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _genFrom, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (picked != null) setState(() => _genFrom = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                    child: Text('Từ ${_genFrom.day}/${_genFrom.month}/${_genFrom.year}', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _genTo, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (picked != null) setState(() => _genTo = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                    child: Text('Đến ${_genTo.day}/${_genTo.month}/${_genTo.year}', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ),
              ),
            ]),
            if (_genError != null) ...[
              const SizedBox(height: 8),
              Text(_genError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Tạo phân công', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
