import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'package:image_picker/image_picker.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});
  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  /// "Quá hạn" tính từ DateTime.now() lúc build. Mở màn hình rồi để đó thì
  /// không có gì bắt build lại, nhãn quá hạn không bao giờ bật lên dù đã trễ.
  /// Nhịp 1 phút đủ mịn cho hạn tính theo phút mà không tốn gì.
  Timer? _overdueTicker;

  String? _filter;
  _TaskSort _sort = _TaskSort.newest;

  static const _statusCfg = {
    'DRAFT': (
      label: 'Bản nháp',
      bg: AppColors.neutralBg,
      color: AppColors.textSecondary,
    ),
    'ACTIVE': (
      label: 'Đang chạy',
      bg: Color(0xFFEFF6FF), // sky-50 — chưa có token info trong AppColors
      color: AppColors.planned,
    ),
    'COMPLETED': (
      label: 'Hoàn thành',
      bg: AppColors.safeLight,
      color: AppColors.safe,
    ),
    'CANCELED': (
      label: 'Đã hủy',
      bg: AppColors.dangerLight,
      color: AppColors.sos,
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tasks = context.read<TaskProvider>();
      tasks.fetchCategories();
      context.read<FamilyProvider>().fetchMembers();
      // Cho badge thanh toán: đếm settlement chờ trả/tranh chấp trên icon AppBar.
      tasks.fetchRewardSettlements();
      await tasks.fetchTasks(hydrateRewardSettings: true);
      if (!mounted) return;
      // GET /tasks không trả kèm assignment → nạp thêm để item hiện người làm
      // và thời gian. Chạy sau khi có danh sách để biết cần nạp task nào.
      await tasks.ensureAssignmentsFor(tasks.tasks.map((t) => t.id));
    });
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

  List<FamilyTask> _visibleTasks(List<FamilyTask> tasks) {
    final visible = _filter == null
        ? List<FamilyTask>.from(tasks)
        : tasks.where((t) => t.status == _filter).toList();

    switch (_sort) {
      case _TaskSort.newest:
        // API does not document an ordering guarantee. A user expects the task
        // just created to be immediately visible at the top of this screen.
        visible.sort(
          (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
            a.createdAt?.millisecondsSinceEpoch ?? 0,
          ),
        );
      case _TaskSort.dueSoon:
        // Tasks without a deadline are intentionally placed after dated tasks.
        visible.sort((a, b) {
          final aDue = a.dueAt?.millisecondsSinceEpoch;
          final bDue = b.dueAt?.millisecondsSinceEpoch;
          if (aDue == null && bDue == null) return 0;
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
    }
    return visible;
  }

  String get _sortLabel => switch (_sort) {
    _TaskSort.newest => 'Mới tạo',
    _TaskSort.dueSoon => 'Hạn gần nhất',
  };

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final tasks = taskState.tasks;
    final active = tasks.where((t) => t.status == 'ACTIVE').length;
    final completed = tasks.where((t) => t.status == 'COMPLETED').length;
    // Settlement cần Manager xử lý: chờ trả (PENDING_SETTLEMENT) + tranh chấp.
    final pendingRewards = taskState.rewardSettlements
        .where(
          (s) => s.status == 'PENDING_SETTLEMENT' || s.status == 'DISPUTED',
        )
        .length;

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
                        'Quản lý nhiệm vụ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/manager/reward-management'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
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
                            Icons.payments_outlined,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // Badge số settlement chờ trả/tranh chấp — entry Quản lý
                        // thưởng vốn chỉ là icon, không badge thì Manager không biết.
                        if (pendingRewards > 0)
                          Positioned(
                            top: -2,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$pendingRewards',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCreateTaskSheet(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.link,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            if (taskState.loading && tasks.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (taskState.error != null && tasks.isEmpty)
              Expanded(
                child: _errorView(
                  taskState.error!,
                  () => taskState.fetchTasks(hydrateRewardSettings: true),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _summaryCard(tasks.length, 'Tổng', AppColors.textPrimary),
                    const SizedBox(width: 12),
                    _summaryCard(active, 'Đang chạy', AppColors.link),
                    const SizedBox(width: 12),
                    _summaryCard(completed, 'Xong', AppColors.success),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _filterChip(null, 'Tất cả'),
                    _filterChip('ACTIVE', 'Đang chạy'),
                    _filterChip('DRAFT', 'Bản nháp'),
                    _filterChip('COMPLETED', 'Hoàn thành'),
                    _filterChip('CANCELED', 'Đã hủy'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Sắp xếp:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<_TaskSort>(
                      initialValue: _sort,
                      tooltip: 'Sắp xếp nhiệm vụ',
                      onSelected: (value) => setState(() => _sort = value),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _TaskSort.newest,
                          child: Text('Mới tạo'),
                        ),
                        PopupMenuItem(
                          value: _TaskSort.dueSoon,
                          child: Text('Hạn gần nhất'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.progressTrack),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sort_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      taskState.fetchTasks(hydrateRewardSettings: true),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ..._visibleTasks(
                        tasks,
                      ).map((task) => _taskCard(context, task)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskCard(BuildContext context, FamilyTask task) {
    final st = _statusCfg[task.status] ?? _statusCfg['ACTIVE']!;
    final overdue = _isTaskOverdue(context, task);
    return GestureDetector(
      onTap: () => _showTaskDetailSheet(context, task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
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
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.planned,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(st.label, st.bg, st.color),
                      if (overdue)
                        _chip(
                          'Quá hạn',
                          AppColors.dangerLight,
                          AppColors.danger,
                        ),
                      if (task.isRecurring)
                        _chip(
                          task.schedule?.label ?? "Định kỳ",
                          const Color(0xFFEFF6FF),
                          const Color(0xFF0369A1),
                        ),
                      if (task.taskCategoryName != null)
                        _chip(
                          task.taskCategoryName!,
                          AppColors.neutralBg,
                          AppColors.textSecondary,
                        ),
                      if (task.rewardSetting != null)
                        _chip(
                          task.rewardSetting!.label,
                          AppColors.safeLight,
                          AppColors.safe,
                        )
                      else
                        _chip(
                          'Chưa đặt thưởng',
                          AppColors.neutralBg,
                          AppColors.textSecondary,
                        ),
                    ],
                  ),
                  ..._taskMetaLines(context, task),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  bool _isTaskOverdue(BuildContext context, FamilyTask task) {
    if (task.status == 'COMPLETED' || task.status == 'CANCELED') return false;
    final now = DateTime.now();
    final activeAssignments = context
        .watch<TaskProvider>()
        .assignmentsFor(task.id)
        .where(
          (a) =>
              a.status != 'APPROVED' &&
              a.status != 'CANCELED' &&
              a.status != 'REJECTED',
        );
    // Khi task đã có phân công, hạn của từng người làm mới là hạn thực tế.
    // Nếu chưa giao, dùng hạn chung của task.
    final assignmentDues = activeAssignments
        .map((a) => a.dueAt)
        .whereType<DateTime>();
    return assignmentDues.any((due) => due.isBefore(now)) ||
        (task.dueAt?.isBefore(now) ?? false);
  }

  // ── Task detail bottom sheet: assignments + actions ──────────────────────

  void _showTaskDetailSheet(BuildContext context, FamilyTask task) {
    context.read<TaskProvider>().fetchTaskAssignments(task.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.progressTrack,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (task.description != null &&
                              task.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              task.description!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (task.status != 'CANCELED' && task.status != 'COMPLETED')
                      GestureDetector(
                        onTap: () => _showEditTaskSheet(context, task),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: AppColors.link,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Task LẶP không dùng được POST .../assignments (BE trả
                        // "Vui lòng sinh phân công ... bằng API lịch lặp") →
                        // phân nhánh sang _ScheduleSheet (generate-assignments).
                        onPressed: () => task.isRecurring
                            ? _showScheduleSheet(context, task)
                            : _showAssignSheet(context, task),
                        icon: const Icon(
                          Icons.person_add_alt_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Giao việc',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRewardSettingSheet(context, task),
                        icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                        label: Text(
                          'Đặt thưởng',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.isRecurring) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showScheduleSheet(context, task),
                    icon: const Icon(Icons.event_repeat_rounded, size: 16),
                    label: Text(
                      'Lịch lặp & tạo phân công',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (task.status != 'CANCELED' && task.status != 'COMPLETED')
                  TextButton(
                    onPressed: () async {
                      await context.read<TaskProvider>().cancelTask(task.id);
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    },
                    child: Text(
                      'Hủy nhiệm vụ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Phân công (${assignments.length})',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (assignments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Chưa giao cho ai',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
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
    // Task định kỳ có hạn trên từng assignment được sinh từ lịch; không dùng
    // dueAt chung của task để tránh nhầm với chu kỳ lặp.
    DateTime? dueAt = task.isRecurring ? null : task.dueAt;
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sửa nhiệm vụ',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tên nhiệm vụ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                _inputBox(titleCtrl, 'Tên nhiệm vụ'),
                const SizedBox(height: 12),
                if (!task.isRecurring) ...[
                  _deadlineField(
                    dueAt: dueAt,
                    onPick: () async {
                      final picked = await _pickDeadline(ctx, dueAt);
                      if (picked != null) setSheet(() => dueAt = picked);
                    },
                    onClear: dueAt == null
                        ? null
                        : () => setSheet(() => dueAt = null),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Mô tả',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                _inputBox(descCtrl, 'Chi tiết công việc (tùy chọn)'),
                const SizedBox(height: 12),
                Text(
                  'Mức ưu tiên',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in ['LOW', 'MEDIUM', 'HIGH'])
                      ChoiceChip(
                        label: Text(switch (p) {
                          'LOW' => 'Thấp',
                          'HIGH' => 'Cao',
                          _ => 'Trung bình',
                        }),
                        selected: priority == p,
                        onSelected: (_) => setSheet(() => priority = p),
                      ),
                  ],
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) {
                            setSheet(() => sheetError = 'Nhập tên nhiệm vụ');
                            return;
                          }
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            await context
                                .read<TaskProvider>()
                                .updateTask(task.id, {
                                  'title': titleCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'priority': priority,
                                  if (!task.isRecurring)
                                    'dueAt': dueAt?.toIso8601String(),
                                });
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
                          'Lưu thay đổi',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, TaskAssignment a) {
    // Reviewer và người thực hiện phải khác nhau. Không chỉ Deputy: Manager tự
    // giao việc cho chính mình cũng không được tự duyệt assignment đó.
    final currentUserId = context.read<AuthProvider>().user?.id;
    final currentMemberId = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.userId == currentUserId || m.id == currentUserId)
        .firstOrNull
        ?.id;
    final isOwnAssignment =
        currentMemberId != null && a.assignedToMemberId == currentMemberId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                initial: (a.assignedToName ?? '?').isNotEmpty
                    ? (a.assignedToName ?? '?').substring(0, 1).toUpperCase()
                    : '?',
                color: AppColors.avatarOrange,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.assignedToName ?? 'Thành viên',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      a.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: a.statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (a.status == 'SUBMITTED' && !isOwnAssignment)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showReviewSheet(context, a),
                  child: Text(
                    'Duyệt',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (a.status == 'SUBMITTED' && isOwnAssignment)
                Text(
                  // KHÔNG viết "Chờ Manager duyệt": API_DOCS mục
                  // PATCH .../submissions/{id}/review ghi rõ quyền duyệt là
                  // Manager **hoặc** Deputy, nên Deputy đọc câu cũ sẽ tưởng
                  // mình phải chờ Manager.
                  'Chờ người quản lý duyệt',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              // Xem lại bài nộp (chế độ chỉ xem): sau khi duyệt/từ chối, và cả
              // lúc còn chờ duyệt cho chính người đã nộp — trước đây người nộp
              // không có cách nào xem lại mình đã gửi ảnh/ghi chú gì.
              if (a.status == 'APPROVED' ||
                  a.status == 'REJECTED' ||
                  (a.status == 'SUBMITTED' && isOwnAssignment))
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: AppColors.progressTrack),
                  ),
                  onPressed: () => _showReviewSheet(context, a, readOnly: true),
                  child: Text(
                    'Xem bài nộp',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (a.status == 'UNAVAILABLE')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.urgent,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showReassignSheet(context, a),
                  child: Text(
                    'Phân công lại',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
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
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          Builder(
            builder: (ctx) {
              final user = context.read<AuthProvider>().user;
              final myMemberId = context
                  .read<FamilyProvider>()
                  .members
                  .where((m) => m.userId == user?.id || m.id == user?.id)
                  .firstOrNull
                  ?.id;
              final isMine = a.assignedToMemberId == myMemberId;
              if (!isMine) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: [
                    if (a.status == 'ASSIGNED')
                      SizedBox(
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
                              await context
                                  .read<TaskProvider>()
                                  .startAssignment(a.id);
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
                    if (a.status == 'IN_PROGRESS' || a.status == 'REJECTED')
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: a.status == 'REJECTED'
                                      ? AppColors.sos
                                      : AppColors.link,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _submitTask(context, a),
                                child: Text(
                                  a.status == 'REJECTED'
                                      ? 'Nộp lại'
                                      : 'Nộp nhiệm vụ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (a.task?.isRecurring == true &&
                              a.status == 'IN_PROGRESS') ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.urgent,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _reportUnavailable(context, a),
                                  child: Text(
                                    'Bận',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.urgent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Review submission ─────────────────────────────────────────────────────

  Future<void> _showReviewSheet(
    BuildContext context,
    TaskAssignment a, {
    bool readOnly = false,
  }) async {
    // BE không embed submission trong response danh sách assignment (chỉ có
    // status), nên KHÔNG có proofs sẵn trên TaskAssignment dù
    // latestSubmissionId có giá trị — luôn phải gọi riêng endpoint
    // submissions để lấy submission đầy đủ (kèm proofs) trước khi duyệt.
    final currentUserId = context.read<AuthProvider>().user?.id;
    final currentMemberId = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.userId == currentUserId || m.id == currentUserId)
        .firstOrNull
        ?.id;
    if (!readOnly &&
        currentMemberId != null &&
        a.assignedToMemberId == currentMemberId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể tự duyệt công việc do mình thực hiện.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final submission = await context.read<TaskProvider>().fetchLatestSubmission(
      a.id,
    );
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // đóng loading
    }

    if (submission == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            readOnly
                ? 'Không tìm thấy bài nộp nào'
                : 'Không tìm thấy bài nộp để duyệt — thử tải lại',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (!context.mounted) return;

    final noteCtrl = TextEditingController();
    bool submitting = false;
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readOnly
                      ? 'Bài nộp của ${a.assignedToName ?? 'thành viên'}'
                      : 'Duyệt công việc',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  a.taskTitle ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (readOnly) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: a.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      a.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: a.statusColor,
                      ),
                    ),
                  ),
                ],
                if (submission.submissionNote != null &&
                    submission.submissionNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      submission.submissionNote!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (submission.proofs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Minh chứng (${submission.proofs.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...submission.proofs.map(_proofPreview),
                ],
                // Ghi chú đánh giá cũ (nếu có) — hiện ở chế độ xem lại
                if (readOnly && (submission.reviewNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Ghi chú đánh giá',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      submission.reviewNote!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (!readOnly) ...[
                  const SizedBox(height: 16),
                  _inputBox(noteCtrl, 'Ghi chú (tùy chọn)'),
                ],
                const SizedBox(height: 16),
                if (!readOnly)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  setSheet(() => submitting = true);
                                  final sheetMessenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await context
                                        .read<TaskProvider>()
                                        .reviewSubmission(
                                          submission.id,
                                          approved: true,
                                          reviewNote: noteCtrl.text.trim(),
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    final setting =
                                        a.rewardSetting ??
                                        a.task?.rewardSetting;
                                    if (setting == null) {
                                      // Không có cấu hình thưởng thì BE KHÔNG
                                      // sinh settlement — nói rõ, không thì
                                      // thành viên chờ thưởng mãi không có.
                                      sheetMessenger.showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Đã duyệt. Việc này chưa đặt thưởng nên không phát sinh khoản thưởng nào.',
                                          ),
                                          backgroundColor: AppColors.textMuted,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    } else if (!setting.autoCreateSettlement) {
                                      // Tắt tự tạo → phải tạo ghi nhận thưởng
                                      // thủ công, nếu không cũng không có gì
                                      // để trả.
                                      sheetMessenger.showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Đã duyệt. Cấu hình thưởng đang TẮT tự tạo — mở Quản lý thưởng để tạo ghi nhận thưởng.',
                                          ),
                                          backgroundColor: AppColors.amberDark,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    } else {
                                      // BE vừa tạo settlement chờ trả; nhắc
                                      // Manager sang màn Quản lý thưởng.
                                      sheetMessenger.showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Đã duyệt — vào Quản lý thưởng ở góc phải màn Nhiệm vụ để trả thưởng',
                                          ),
                                          backgroundColor: AppColors.success,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheet(() => submitting = false);
                                    sheetMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            'Duyệt',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  setSheet(() => submitting = true);
                                  final sheetMessenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await context
                                        .read<TaskProvider>()
                                        .reviewSubmission(
                                          submission.id,
                                          approved: false,
                                          reviewNote: noteCtrl.text.trim(),
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    setSheet(() => submitting = false);
                                    sheetMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            'Từ chối',
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
                // Bài nộp đã duyệt, có cấu hình thưởng, nhưng KHÔNG có ghi nhận
                // thưởng nào (BE tắt tự tạo, hoặc lần tạo tự động thất bại) →
                // đây là đường khôi phục duy nhất, không có nút này thì thành
                // viên không bao giờ nhận được thưởng của bài nộp đó.
                if (readOnly &&
                    submission.status == 'APPROVED' &&
                    (a.rewardSetting ?? a.task?.rewardSetting) != null &&
                    !context.watch<TaskProvider>().rewardSettlements.any(
                      (s) => s.submissionId == submission.id,
                    ))
                  _createSettlementButton(ctx, submission.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nút tạo ghi nhận thưởng thủ công cho bài nộp đã duyệt mà chưa có settlement.
  Widget _createSettlementButton(BuildContext ctx, String submissionId) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.safe,
          side: const BorderSide(color: AppColors.safe),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
        label: Text(
          'Tạo ghi nhận thưởng',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(ctx);
          try {
            await ctx.read<TaskProvider>().createSettlement(submissionId);
            if (ctx.mounted) Navigator.pop(ctx);
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã tạo ghi nhận thưởng — mở Quản lý thưởng để trả',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceFirst('Exception: ', '')),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        },
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
              child: Text(
                'Không tải được ảnh',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // NOTE / FILE / VIDEO không có ảnh preview — hiện card thông tin
    final icon = switch (proof.proofType) {
      'VIDEO' => Icons.videocam_outlined,
      'FILE' => Icons.attach_file_rounded,
      _ => Icons.notes_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              proof.note?.isNotEmpty == true
                  ? proof.note!
                  : (proof.fileUrl ?? proof.proofType),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
    // Ai đang giữ task này rồi — để cảnh báo giao trùng. Không loại khỏi danh
    // sách: Swagger không nói BE có cấm giao 2 lần cho cùng một người hay
    // không, tự ẩn đi là FE quyết thay BE. Chỉ ghi nhãn để manager tự cân nhắc.
    final assignedStatusByMemberId = <String, String>{};
    for (final a in context.read<TaskProvider>().assignmentsFor(task.id)) {
      if (a.status == 'CANCELED' || a.assignedToMemberId.isEmpty) continue;
      assignedStatusByMemberId.putIfAbsent(
        a.assignedToMemberId,
        () => a.status,
      );
    }

    String? selectedId;
    DateTime? dueAt;
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
        // Nhà đông thành viên là danh sách radio + ô hạn + nút vượt chiều cao
        // sheet → Column trần sẽ tràn layout. Bọc scroll và chặn trần 80% màn
        // hình để sheet tự cuộn thay vì vỡ.
        builder: (ctx, setSheet) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: SingleChildScrollView(
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
                  'Giao việc cho',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Dùng m.id (bản ghi thành viên trong gia đình) — KHÔNG dùng m.userId
                ...members.map((m) {
                  final assignedStatus = assignedStatusByMemberId[m.id];
                  return RadioListTile<String>(
                    value: m.id,
                    groupValue: selectedId,
                    onChanged: (v) => setSheet(() {
                      selectedId = v;
                      sheetError = null;
                    }),
                    title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(
                      assignedStatus == null
                          ? m.roleLabel
                          : '${m.roleLabel} · đã được giao '
                                '(${TaskAssignment.labelOf(assignedStatus)})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: assignedStatus == null
                            ? AppColors.textMuted
                            : AppColors.danger,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 8),
                _deadlineField(
                  dueAt: dueAt,
                  onPick: () async {
                    final picked = await _pickDeadline(ctx, dueAt);
                    if (picked != null) setSheet(() => dueAt = picked);
                  },
                  onClear: dueAt == null
                      ? null
                      : () => setSheet(() => dueAt = null),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
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
                const SizedBox(height: 12),
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
                    onPressed: (submitting || selectedId == null)
                        ? null
                        : () async {
                            setSheet(() {
                              submitting = true;
                              sheetError = null;
                            });
                            try {
                              await context.read<TaskProvider>().assignTask(
                                task.id,
                                assignedToMemberId: selectedId!,
                                dueAt: dueAt,
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
      ),
    );
  }

  // ── Reassign (member báo bận) ─────────────────────────────────────────────

  void _showReassignSheet(BuildContext context, TaskAssignment a) {
    // a.assignedToMemberId là familyMember.id — lọc đúng theo m.id, và chỉ
    // member ACTIVE (khỏi reassign nhầm sang thành viên đã REMOVED).
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive && m.id != a.assignedToMemberId)
        .toList();
    String? selectedId;
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
                'Phân công lại',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${a.assignedToName} đã báo không thể thực hiện.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              ...members.map(
                (m) => RadioListTile<String>(
                  value: m.id,
                  groupValue: selectedId,
                  onChanged: (v) => setSheet(() {
                    selectedId = v;
                    sheetError = null;
                  }),
                  title: Text(m.name, style: GoogleFonts.inter(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
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
              const SizedBox(height: 12),
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
                  onPressed: (submitting || selectedId == null)
                      ? null
                      : () async {
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await context
                                .read<TaskProvider>()
                                .reassignAssignment(
                                  a.id,
                                  assignedToMemberId: selectedId!,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Đã phân công lại'),
                                backgroundColor: AppColors.success,
                              ),
                            );
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

  // ── Schedule (recurring task) ────────────────────────────────────────────
  // GET .../schedule (refresh), PATCH .../schedule (sửa), POST
  // .../schedule/generate-assignments (tạo phân công hàng loạt).
  void _showScheduleSheet(BuildContext context, FamilyTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ScheduleSheet(task: task),
    );
  }

  // ── Reward setting ────────────────────────────────────────────────────────

  Future<void> _showRewardSettingSheet(
    BuildContext context,
    FamilyTask task,
  ) async {
    // The task list does not guarantee embedding rewardSetting. Read the
    // dedicated endpoint before deciding POST versus PATCH.
    final existingReward =
        await context.read<TaskProvider>().fetchRewardSetting(task.id) ??
        task.rewardSetting;
    if (!context.mounted) return;
    String rewardType = existingReward?.rewardType ?? 'MONEY_RECORD';
    final amountCtrl = TextEditingController(
      text: existingReward?.rewardAmount.toStringAsFixed(0) ?? '',
    );
    final descCtrl = TextEditingController(
      text: existingReward?.rewardDescription ?? '',
    );
    bool autoSettle = existingReward?.autoCreateSettlement ?? true;
    bool submitting = false;
    String? sheetError;

    double? parseRewardAmount() {
      final raw = amountCtrl.text.trim();
      if (raw.isEmpty) return null;
      // Vietnamese currency is commonly entered as "30.000". Dart parses that
      // as the decimal number 30.0, so normalize money to digits before send.
      if (rewardType == 'MONEY_RECORD') {
        return double.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
      }
      return double.tryParse(raw.replaceAll(',', '.'));
    }

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
                'Đặt phần thưởng',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ['MONEY_RECORD', 'POINT', 'OTHER'])
                    ChoiceChip(
                      label: Text(switch (t) {
                        'MONEY_RECORD' => 'Tiền',
                        'POINT' => 'Điểm',
                        _ => 'Khác',
                      }),
                      selected: rewardType == t,
                      onSelected: (_) => setSheet(() => rewardType = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (rewardType != 'OTHER') ...[
                Text(
                  rewardType == 'POINT' ? 'Số điểm' : 'Số tiền (₫)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                _inputBox(
                  amountCtrl,
                  'VD: 20000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Ghi chú',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _inputBox(descCtrl, 'Mô tả phần thưởng (tùy chọn)'),
              const SizedBox(height: 8),
              SwitchListTile(
                value: autoSettle,
                onChanged: (v) => setSheet(() => autoSettle = v),
                title: Text(
                  'Tự tạo thanh toán khi duyệt nhiệm vụ',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
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
              const SizedBox(height: 8),
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
                          setSheet(() {
                            submitting = true;
                            sheetError = null;
                          });
                          try {
                            final tp = context.read<TaskProvider>();
                            // PATCH nếu task đã có reward-setting (sửa), POST nếu chưa (tạo mới).
                            if (existingReward != null) {
                              await tp.updateRewardSetting(
                                task.id,
                                rewardType: rewardType,
                                rewardAmount: parseRewardAmount(),
                                rewardDescription: descCtrl.text.trim(),
                                autoCreateSettlement: autoSettle,
                              );
                            } else {
                              await tp.setRewardSetting(
                                task.id,
                                rewardType: rewardType,
                                rewardAmount: parseRewardAmount(),
                                rewardDescription: descCtrl.text.trim(),
                                autoCreateSettlement: autoSettle,
                              );
                            }
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
                          existingReward != null ? 'Lưu thay đổi' : 'Lưu',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              if (existingReward != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheet(() {
                              submitting = true;
                              sheetError = null;
                            });
                            try {
                              await context
                                  .read<TaskProvider>()
                                  .deleteRewardSetting(task.id);
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
                    child: Text(
                      'Xóa phần thưởng',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Create task sheet (AD_HOC / RECURRING) ───────────────────────────────

  void _showCreateTaskSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String taskType = 'AD_HOC';
    String priority = 'MEDIUM';
    String? categoryId;
    DateTime? dueAt;
    String repeatType = 'DAILY';
    final intervalCtrl = TextEditingController(text: '1');
    DateTime recurringStartDate = DateTime.now();
    DateTime? recurringEndDate;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final categories = context.watch<TaskProvider>().categories;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tạo nhiệm vụ mới',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _typeToggle(
                        label: 'Tự phát',
                        selected: taskType == 'AD_HOC',
                        onTap: () => setSheet(() => taskType = 'AD_HOC'),
                      ),
                      const SizedBox(width: 8),
                      _typeToggle(
                        label: 'Định kỳ',
                        selected: taskType == 'RECURRING',
                        onTap: () => setSheet(() => taskType = 'RECURRING'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tên nhiệm vụ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputBox(
                    titleCtrl,
                    'VD: Dọn phòng khách, Đưa con đi học...',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mô tả',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputBox(descCtrl, 'Chi tiết công việc (tùy chọn)'),
                  const SizedBox(height: 12),

                  if (taskType == 'AD_HOC') ...[
                    _deadlineField(
                      dueAt: dueAt,
                      onPick: () async {
                        final picked = await _pickDeadline(ctx, dueAt);
                        if (picked != null) setSheet(() => dueAt = picked);
                      },
                      onClear: dueAt == null
                          ? null
                          : () => setSheet(() => dueAt = null),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Danh mục',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...categories.map(
                        (c) => GestureDetector(
                          onLongPress: () =>
                              _showRenameCategoryDialog(context, c),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: categoryId == c.id,
                            onSelected: (_) =>
                                setSheet(() => categoryId = c.id),
                          ),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('Mới'),
                        onPressed: () => _showCreateCategoryDialog(
                          context,
                          (newId) => setSheet(() => categoryId = newId),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Giữ để đổi tên danh mục',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Mức ưu tiên',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in ['LOW', 'MEDIUM', 'HIGH'])
                        ChoiceChip(
                          label: Text(switch (p) {
                            'LOW' => 'Thấp',
                            'HIGH' => 'Cao',
                            _ => 'Trung bình',
                          }),
                          selected: priority == p,
                          onSelected: (_) => setSheet(() => priority = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (taskType == 'RECURRING') ...[
                    Text(
                      'Lặp lại',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final r in ['DAILY', 'WEEKLY', 'MONTHLY'])
                          ChoiceChip(
                            label: Text(switch (r) {
                              'DAILY' => 'Hàng ngày',
                              'WEEKLY' => 'Hàng tuần',
                              _ => 'Hàng tháng',
                            }),
                            selected: repeatType == r,
                            onSelected: (_) => setSheet(() => repeatType = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Khoảng lặp (mỗi N ${repeatType == "DAILY"
                          ? "ngày"
                          : repeatType == "WEEKLY"
                          ? "tuần"
                          : "tháng"})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _inputBox(
                      intervalCtrl,
                      '1',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _datePickerField(
                            label: 'Bắt đầu',
                            value: recurringStartDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: recurringStartDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 730),
                                ),
                              );
                              if (picked != null) {
                                setSheet(() {
                                  recurringStartDate = picked;
                                  if (recurringEndDate != null &&
                                      recurringEndDate!.isBefore(picked)) {
                                    recurringEndDate = null;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _datePickerField(
                            label: 'Kết thúc (tuỳ chọn)',
                            value: recurringEndDate,
                            onPick: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    recurringEndDate ?? recurringStartDate,
                                firstDate: recurringStartDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 730),
                                ),
                              );
                              if (picked != null) {
                                setSheet(() => recurringEndDate = picked);
                              }
                            },
                            onClear: recurringEndDate == null
                                ? null
                                : () => setSheet(() => recurringEndDate = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
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
                                  repeatInterval:
                                      int.tryParse(intervalCtrl.text.trim()) ??
                                      1,
                                  startDate: recurringStartDate,
                                  endDate: recurringEndDate,
                                );
                              } else {
                                await taskProvider.createTask(
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  taskCategoryId: categoryId,
                                  taskType: taskType,
                                  priority: priority,
                                  dueAt: dueAt,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Tạo nhiệm vụ',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateCategoryDialog(
    BuildContext context,
    void Function(String id) onCreated,
  ) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Danh mục mới'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            hintText: 'VD: Nhà cửa, Học tập...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final cat = await context.read<TaskProvider>().createCategory(
                name: nameCtrl.text.trim(),
              );
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
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await context.read<TaskProvider>().updateCategory(
                category.id,
                name: nameCtrl.text.trim(),
              );
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Deadline belongs to the task/assignment data, not a client-side timer.
  /// FE only lets the manager choose and render it; BE remains the source of
  /// truth for status transitions.
  Future<DateTime?> _pickDeadline(
    BuildContext context,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return null;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!picked.isAfter(now)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hạn hoàn thành phải ở thời điểm tương lai.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return null;
    }
    return picked;
  }

  Widget _deadlineField({
    required DateTime? dueAt,
    required Future<void> Function() onPick,
    VoidCallback? onClear,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hạn hoàn thành (tuỳ chọn)',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.progressTrack, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dueAt == null ? 'Chọn ngày và giờ hạn' : _fmtDateTime(dueAt),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: dueAt == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _datePickerField({
    required String label,
    required DateTime? value,
    required Future<void> Function() onPick,
    VoidCallback? onClear,
  }) => InkWell(
    onTap: onPick,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.progressTrack),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value == null
                  ? label
                  : '$label: ${value.day}/${value.month}/${value.year}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: value == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    ),
  );

  // ── Small widgets ──────────────────────────────────────────────────────────

  Widget _typeToggle({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.link : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );

  Widget _inputBox(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.progressTrack, width: 1.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
      ),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
    ),
  );

  Widget _errorView(String msg, VoidCallback onRetry) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Lỗi tải dữ liệu',
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.danger),
        ),
        const SizedBox(height: 8),
        Text(
          msg,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _summaryCard(int val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          Text(
            '$val',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Dòng phụ của item task: người giao · người làm · thời gian.
  ///
  /// Người làm lấy từ assignment (đã nạp qua `ensureAssignmentsFor`); người giao
  /// chỉ hiện khi BE trả `createdByMember` — Swagger chưa document field này nên
  /// không có thì ẩn hẳn dòng thay vì hiện "Không rõ".
  List<Widget> _taskMetaLines(BuildContext context, FamilyTask task) {
    final assignments = context.watch<TaskProvider>().assignmentsFor(task.id);
    final active = assignments
        .where((a) => a.status != 'CANCELED')
        .toList(growable: false);

    // Một người có thể có nhiều assignment record (ví dụ task định kỳ hoặc dữ
    // liệu bị tạo lặp). Card tóm tắt phải nói số *người nhận duy nhất*, không
    // dùng active.length vì đó chỉ là số bản ghi assignment.
    final assigneesByMemberId = <String, String>{};
    for (final assignment in active) {
      final memberId = assignment.assignedToMemberId.trim();
      if (memberId.isEmpty || assigneesByMemberId.containsKey(memberId)) {
        continue;
      }
      final name = assignment.assignedToName?.trim();
      assigneesByMemberId[memberId] = name == null || name.isEmpty
          ? 'Thành viên'
          : name;
    }
    final assigneeNames = assigneesByMemberId.values.toList(growable: false);
    final assignee = switch (assigneeNames.length) {
      0 => 'Chưa giao cho ai',
      1 => assigneeNames.first,
      2 => '${assigneeNames[0]}, ${assigneeNames[1]}',
      _ =>
        '${assigneeNames[0]}, ${assigneeNames[1]} và ${assigneeNames.length - 2} người khác',
    };

    // Ưu tiên hạn của assignment (sát thực tế hơn), không có thì lấy hạn task.
    final due = active
        .map((a) => a.dueAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final start = active
        .map((a) => a.startAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

    final timeParts = <String>[
      ?(start != null ? 'Bắt đầu ${_fmtDateTime(start)}' : null),
      ?(due ?? task.dueAt) != null
          ? 'Hạn ${_fmtDateTime(due ?? task.dueAt!)}'
          : null,
      ?(task.isRecurring && start == null && due == null && task.dueAt == null
          ? task.schedule?.label
          : null),
    ];

    final assigner =
        _resolveName(context, task.createdByName, task.createdByMemberId) ??
        // Tên người giao có thể chỉ nằm ở assignment chứ không ở task.
        active
            .map(
              (a) =>
                  _resolveName(context, a.assignedByName, a.assignedByMemberId),
            )
            .whereType<String>()
            .firstOrNull;

    final rows = <String>[
      ?(assigner == null ? null : 'Người giao: $assigner'),
      'Người làm: $assignee',
      ?(timeParts.isEmpty ? null : timeParts.join(' · ')),
    ];

    return [
      const SizedBox(height: 8),
      ...rows.map(
        (line) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ];
  }

  /// Ưu tiên tên BE trả; chỉ có id thì tra trong danh sách thành viên. Không ra
  /// tên nào thì null để caller ẩn dòng, không hiện id thô.
  String? _resolveName(BuildContext context, String? name, String? memberId) {
    final direct = name?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final id = memberId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final m in context.read<FamilyProvider>().members) {
      if (m.id == id || m.userId == id) {
        return m.name.trim().isEmpty ? null : m.name.trim();
      }
    }
    return null;
  }

  static String _fmtDateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
  }

  Widget _chip(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

  // ── Nộp nhiệm vụ kèm proof (ảnh / note) cho chính user ────────────────────

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
                    hintText: 'Thêm ghi chú...',
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
                          ? AppColors.safeLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pickedImagePath != null
                            ? AppColors.success
                            : AppColors.progressTrack,
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
                                  content: Text('Đã nộp!'),
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
                Text(
                  'Báo cáo không thể thực hiện',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Lý do (VD: Đang có việc khác...)',
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.urgent,
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
                                content: Text('Đã báo.'),
                                backgroundColor: AppColors.urgent,
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
                          'Xác nhận',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
}

enum _TaskSort { newest, dueSoon }

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
  TimeOfDay _genStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _genDueTime = const TimeOfDay(hour: 18, minute: 0);
  bool _generating = false;
  String? _genError;

  @override
  void initState() {
    super.initState();
    _repeatType = widget.task.schedule?.repeatType ?? 'DAILY';
    _intervalCtrl = TextEditingController(
      text: '${widget.task.schedule?.repeatInterval ?? 1}',
    );
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
    setState(() {
      _savingSchedule = true;
      _scheduleError = null;
    });
    try {
      await context.read<TaskProvider>().updateSchedule(widget.task.id, {
        'repeatType': _repeatType,
        'repeatInterval': int.tryParse(_intervalCtrl.text.trim()) ?? 1,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu lịch lặp'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _scheduleError = e.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _savingSchedule = false);
    }
  }

  Future<void> _generate() async {
    if (_genMemberId == null) {
      setState(() => _genError = 'Chọn thành viên');
      return;
    }
    if (_genTo.isBefore(_genFrom)) {
      setState(
        () => _genError = 'Ngày kết thúc phải sau hoặc bằng ngày bắt đầu',
      );
      return;
    }
    if (_genDueTime != null &&
        (_genDueTime!.hour * 60 + _genDueTime!.minute) <=
            (_genStartTime.hour * 60 + _genStartTime.minute)) {
      setState(() => _genError = 'Giờ hạn phải muộn hơn giờ bắt đầu');
      return;
    }
    setState(() {
      _generating = true;
      _genError = null;
    });
    try {
      await context.read<TaskProvider>().generateAssignments(
        widget.task.id,
        assignedToMemberId: _genMemberId!,
        fromDate: _genFrom,
        toDate: _genTo,
        startTime: _timeText(_genStartTime),
        dueTime: _genDueTime == null ? null : _timeText(_genDueTime!),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo phân công hàng loạt'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _genError = e.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = context
        .watch<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
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
              'Lịch lặp',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingSchedule)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final r in ['DAILY', 'WEEKLY', 'MONTHLY'])
                    ChoiceChip(
                      label: Text(switch (r) {
                        'DAILY' => 'Hàng ngày',
                        'WEEKLY' => 'Hàng tuần',
                        _ => 'Hàng tháng',
                      }),
                      selected: _repeatType == r,
                      onSelected: (_) => setState(() => _repeatType = r),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Khoảng lặp',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.progressTrack,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              if (_scheduleError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _scheduleError!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _savingSchedule ? null : _saveSchedule,
                  child: _savingSchedule
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Lưu lịch',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Tạo phân công hàng loạt',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Thành viên',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _genMemberId,
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
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _genMemberId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _genFrom,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) setState(() => _genFrom = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.progressTrack),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Từ ${_genFrom.day}/${_genFrom.month}/${_genFrom.year}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _genTo,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) setState(() => _genTo = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.progressTrack),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Đến ${_genTo.day}/${_genTo.month}/${_genTo.year}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _timePickerField(
                      label: 'Bắt đầu',
                      value: _genStartTime,
                      onPick: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _genStartTime,
                        );
                        if (picked != null) {
                          setState(() => _genStartTime = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _timePickerField(
                      label: 'Hạn (tuỳ chọn)',
                      value: _genDueTime,
                      onPick: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _genDueTime ?? _genStartTime,
                        );
                        if (picked != null) {
                          setState(() => _genDueTime = picked);
                        }
                      },
                      onClear: _genDueTime == null
                          ? null
                          : () => setState(() => _genDueTime = null),
                    ),
                  ),
                ],
              ),
              if (_genError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _genError!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _generating ? null : _generate,
                  child: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Tạo phân công',
                          style: GoogleFonts.inter(
                            fontSize: 14,
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
    );
  }

  String _timeText(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _timePickerField({
    required String label,
    required TimeOfDay? value,
    required Future<void> Function() onPick,
    VoidCallback? onClear,
  }) => InkWell(
    onTap: onPick,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.progressTrack),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value == null ? label : '$label: ${_timeText(value)}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: value == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    ),
  );
}
