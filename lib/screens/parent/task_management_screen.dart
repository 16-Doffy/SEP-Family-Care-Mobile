import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
// ignore: unused_import (TaskType dùng cho _createType)
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});
  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  String? _filter;
  TaskItem? _approveTask;
  bool _showCreate = false;
  bool _submitting = false;
  final _titleCtrl = TextEditingController();

  TaskType _createType = TaskType.adHoc;
  final _scheduleCtrl  = TextEditingController();
  final _assigneeCtrl  = TextEditingController(); // tên / ID người được giao
  final _rewardCtrl    = TextEditingController(); // phần thưởng (₫)

  static const _statusCfg = {
    'TODO':        (label: 'Chờ làm',       bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    'DOING':       (label: 'Đang làm',      bg: Color(0xFFFEF3C7), color: Color(0xFFD97706)),
    'SUBMITTED':   (label: 'Chờ duyệt',     bg: Color(0xFFEFF6FF), color: AppColors.planned),
    'DONE':        (label: 'Hoàn thành',    bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    'REJECTED':    (label: 'Từ chối',       bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
    'UNAVAILABLE': (label: 'Cần phân công', bg: Color(0xFFFFF7ED), color: Color(0xFFEA580C)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scheduleCtrl.dispose();
    _assigneeCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  List<TaskItem> _filtered(List<TaskItem> tasks) =>
      _filter == null ? tasks : tasks.where((t) => t.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final tasks     = taskState.tasks;
    final submitted = tasks.where((t) => t.status == 'SUBMITTED').length;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                  const Expanded(child: Center(child: Text('Quản lý Tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
                  GestureDetector(
                    onTap: () => setState(() => _showCreate = true),
                    child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), child: const Icon(Icons.add, color: Colors.white)),
                  ),
                ],
              ),
            ),

            if (taskState.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (taskState.error != null)
              Expanded(child: _errorView(taskState.error!, () => taskState.fetchTasks()))
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _summaryCard(tasks.length, 'Tổng', AppColors.textPrimary),
                    const SizedBox(width: 12),
                    _summaryCard(submitted, 'Chờ duyệt', AppColors.link),
                    const SizedBox(width: 12),
                    _summaryCard(tasks.where((t) => t.status == 'DONE').length, 'Xong', AppColors.success),
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
                    _filterChip(null,          'Tất cả'),
                    _filterChip('SUBMITTED',   'Chờ duyệt', badge: submitted),
                    _filterChip('DOING',       'Đang làm'),
                    _filterChip('DONE',        'Hoàn thành'),
                    _filterChip('UNAVAILABLE', '🚫 Chờ phân công',
                        badge: tasks.where((t) => t.status == 'UNAVAILABLE').length),
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
                      ..._filtered(tasks).map((task) {
                        final st = _statusCfg[task.status] ?? _statusCfg['TODO']!;
                        return GestureDetector(
                          onTap: () {
                            if (task.status == 'SUBMITTED') {
                              setState(() => _approveTask = task);
                            } else if (task.status == 'UNAVAILABLE') {
                              _showReassignSheet(context, task);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Container(width: 4, height: 60, decoration: BoxDecoration(color: AppColors.planned, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(child: Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                        if (task.status == 'SUBMITTED')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                            child: Text('DUYỆT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.planned)),
                                          ),
                                      ]),
                                      const SizedBox(height: 8),
                                      Wrap(spacing: 6, runSpacing: 4, children: [
                                        _chip(st.label, st.bg, st.color),
                                        if (task.isRecurring)
                                          _chip('🔁 Định kỳ', const Color(0xFFF0F9FF), const Color(0xFF0369A1)),
                                        if (task.reward > 0)
                                          _chip('💰 ${(task.reward / 1000).toStringAsFixed(0)}K', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                                        if (task.status == 'UNAVAILABLE')
                                          _chip('Tap để phân công →', const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
                                      ]),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AvatarWidget(
                                  initial: task.assigneeName.isNotEmpty
                                      ? task.assigneeName.substring(0, 1).toUpperCase()
                                      : '?',
                                  color: AppColors.avatarOrange,
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomSheet: _approveTask != null
          ? _approveSheet(context)
          : _showCreate
              ? _createSheet(context)
              : null,
    );
  }

  Widget _approveSheet(BuildContext context) {
    final t = _approveTask!;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅  Duyệt task', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text(t.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            Text('👤 ${t.assigneeName}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            if (t.reward > 0) ...[
              const SizedBox(width: 16),
              Text('💰 ${(t.reward / 1000).toStringAsFixed(0)}K ₫', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _submitting ? null : () async {
                  setState(() => _submitting = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await context.read<TaskProvider>().approveTask(t.id, approved: true);
                    if (mounted) setState(() { _approveTask = null; _submitting = false; });
                  } catch (e) {
                    if (mounted) setState(() => _submitting = false);
                    messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('✓  Duyệt', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _submitting ? null : () async {
                  setState(() => _submitting = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await context.read<TaskProvider>().approveTask(t.id, approved: false);
                    if (mounted) setState(() { _approveTask = null; _submitting = false; });
                  } catch (e) {
                    if (mounted) setState(() => _submitting = false);
                    messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('✕  Từ chối', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
          TextButton(
            onPressed: () => setState(() => _approveTask = null),
            child: Center(child: Text('Xem lại sau', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted))),
          ),
        ],
      ),
    );
  }

  Widget _createSheet(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setSheetState) => Container(
        padding: EdgeInsets.fromLTRB(
            28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋  Tạo task mới',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Loại task toggle (UC38 vs UC39) ──
            Row(
              children: [
                _typeToggle(
                    label: '⚡ Tự phát',
                    selected: _createType == TaskType.adHoc,
                    onTap: () => setState(() => _createType = TaskType.adHoc)),
                const SizedBox(width: 8),
                _typeToggle(
                    label: '🔁 Định kỳ',
                    selected: _createType == TaskType.recurring,
                    onTap: () =>
                        setState(() => _createType = TaskType.recurring)),
              ],
            ),
            const SizedBox(height: 14),

            Text('Tên task',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _inputBox(_titleCtrl, 'VD: Dọn phòng khách, Đưa con đi học...'),
            const SizedBox(height: 12),

            // Khung giờ — chỉ cho recurring
            if (_createType == TaskType.recurring) ...[
              Text('Khung giờ thực hiện',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(_scheduleCtrl, 'VD: 07:00–07:30 hàng ngày'),
              const SizedBox(height: 12),
            ],

            // ── Giao cho (assignee) ───────────────────────────
            Text('Giao cho',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _inputBox(_assigneeCtrl, 'Tên thành viên hoặc ID (để trống = chưa giao)'),
            const SizedBox(height: 12),

            // ── Phần thưởng ───────────────────────────────────
            Text('Phần thưởng (₫)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFE5E7EB), width: 1.5),
                  borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _rewardCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                  hintText: 'VD: 20000  (để trống nếu không có thưởng)',
                  border: InputBorder.none,
                  hintStyle:
                      GoogleFonts.inter(color: AppColors.textMuted),
                  suffixText: '₫',
                  suffixStyle: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600),
                ),
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.link,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting
                  ? null
                  : () async {
                      if (_titleCtrl.text.isEmpty) return;
                      setState(() => _submitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await context.read<TaskProvider>().createTask(
                              title:      _titleCtrl.text.trim(),
                              type:       _createType,
                              schedule:   _scheduleCtrl.text.trim().isEmpty
                                  ? null : _scheduleCtrl.text.trim(),
                              assigneeId: _assigneeCtrl.text.trim(),
                              reward:     double.tryParse(
                                  _rewardCtrl.text.trim()) ?? 0,
                            );
                        if (mounted) {
                          _titleCtrl.clear();
                          _scheduleCtrl.clear();
                          _assigneeCtrl.clear();
                          _rewardCtrl.clear();
                          setState(() {
                            _showCreate = false;
                            _submitting = false;
                          });
                        }
                      } catch (e) {
                        if (mounted) setState(() => _submitting = false);
                        messenger.showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.danger));
                      }
                    },
              child: _submitting
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : Text('Tạo task',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
            TextButton(
              onPressed: () => setState(() => _showCreate = false),
              child: Center(
                  child: Text('Hủy',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textMuted))),
            ),
          ],
        ),
      ),
    );
  }

  // UC42 — Reassign task định kỳ khi member báo không thể làm
  void _showReassignSheet(BuildContext context, TaskItem task) {
    final assigneeCtrl = TextEditingController();
    bool submitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              28, 28, 28, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔄  Phân công lại',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(task.title,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${task.assigneeName} đã báo không thể thực hiện.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text('ID thành viên mới',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _inputBox(assigneeCtrl, 'Nhập Member ID hoặc tên thành viên'),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.link,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: submitting
                    ? null
                    : () async {
                        if (assigneeCtrl.text.isEmpty) return;
                        setSheet(() => submitting = true);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await context
                              .read<TaskProvider>()
                              .reassignTask(task.id, assigneeCtrl.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Đã phân công lại ✅'),
                                backgroundColor: AppColors.success),
                          );
                        } catch (e) {
                          setSheet(() => submitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.danger));
                          }
                        }
                      },
                child: submitting
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Text('Xác nhận phân công',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeToggle(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
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
  }

  Widget _inputBox(TextEditingController ctrl, String hint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            border:
                Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
          ),
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

  Widget _filterChip(String? status, String label, {int badge = 0}) {
    final active = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.fromLTRB(14, 0, badge > 0 ? 4 : 14, 0),
        height: 40,
        decoration: BoxDecoration(
          color: active ? AppColors.link : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger), alignment: Alignment.center, child: Text('$badge', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}
