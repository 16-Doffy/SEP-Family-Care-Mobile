import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';

class ChildTasksScreen extends StatefulWidget {
  const ChildTasksScreen({super.key});
  @override
  State<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends State<ChildTasksScreen> {
  String _filter = 'Tất cả';
  final _filters = ['Tất cả', 'Chờ làm', 'Đang làm', 'Đã nộp', 'Hoàn thành'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchMyAssignments();
    });
  }

  bool _matchFilter(String status) {
    switch (_filter) {
      case 'Chờ làm':
        return status == 'PENDING' || status == 'TODO' || status == 'ASSIGNED' || status == 'SCHEDULED';
      case 'Đang làm':
        return status == 'IN_PROGRESS';
      case 'Đã nộp':
        return status == 'SUBMITTED';
      case 'Hoàn thành':
        return status == 'APPROVED' || status == 'DONE';
      default:
        return true;
    }
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'IN_PROGRESS':
        return const Color(0xFFD97706);
      case 'SUBMITTED':
        return AppColors.planned;
      case 'APPROVED':
      case 'DONE':
        return AppColors.safe;
      case 'REJECTED':
        return AppColors.sos;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'IN_PROGRESS':
        return '🔄 Đang làm';
      case 'SUBMITTED':
        return '⏳ Chờ duyệt';
      case 'APPROVED':
      case 'DONE':
        return '✅ Hoàn thành';
      case 'REJECTED':
        return '❌ Từ chối';
      default:
        return '🔵 Chờ làm';
    }
  }

  bool _canStart(String s) {
    final u = s.toUpperCase();
    return u == 'PENDING' || u == 'TODO' || u == 'ASSIGNED' || u == 'SCHEDULED';
  }

  bool _canSubmit(String s) {
    final u = s.toUpperCase();
    return u == 'PENDING' || u == 'TODO' || u == 'IN_PROGRESS' || u == 'ASSIGNED' || u == 'SCHEDULED';
  }

  String _fmt(double n) =>
      '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

  Future<void> _startTask(TaskItem t) async {
    final id = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
    try {
      await context.read<TaskProvider>().startAssignment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bắt đầu làm! Cố lên nào 💪'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _submitTask(TaskItem t) async {
    final noteCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Nộp nhiệm vụ', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(t.title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Thêm ghi chú cho Ba/Mẹ...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          setBS(() => submitting = true);
                          try {
                            final assignmentId = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
                            await context.read<TaskProvider>().submitCompletion(assignmentId, note: noteCtrl.text);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã nộp! Chờ Ba/Mẹ duyệt nhé 🎉'), backgroundColor: AppColors.safe),
                              );
                              context.read<TaskProvider>().fetchMyAssignments();
                            }
                          } catch (e) {
                            setBS(() => submitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Xác nhận nộp', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _reportUnavailability(TaskItem t) async {
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Báo không thể làm', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(t.title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Lý do không thể làm (VD: Con bị ốm...)',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reasonCtrl.text.trim().isEmpty) return;
                          setBS(() => submitting = true);
                          try {
                            final assignmentId = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
                            await context.read<TaskProvider>().reportUnavailability(assignmentId, reason: reasonCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã báo cho Ba/Mẹ biết'), backgroundColor: AppColors.safe),
                              );
                            }
                          } catch (e) {
                            setBS(() => submitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Gửi báo cáo', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelUnavailability(String unavailabilityId) async {
    try {
      await context.read<TaskProvider>().cancelUnavailability(unavailabilityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy báo cáo'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _confirmReceived(TaskItem t) async {
    final settlementId = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
    try {
      await context.read<TaskProvider>().confirmSettlementReceived(settlementId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận nhận thưởng!'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _reportDispute(TaskItem t) async {
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Chưa nhận được thưởng?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(t.title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Nhập lý do để Ba/Mẹ xem xét lại', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'VD: Con đã hoàn thành nhưng chưa nhận thưởng...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.planned,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reasonCtrl.text.trim().isEmpty) return;
                          setBS(() => submitting = true);
                          try {
                            // settlement ID must come from the task's settlement — use assignmentId as proxy
                            final settlementId = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
                            await context.read<TaskProvider>().createDispute(settlementId, reason: reasonCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã gửi khiếu nại'), backgroundColor: AppColors.safe),
                              );
                            }
                          } catch (e) {
                            setBS(() => submitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Gửi khiếu nại', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final allTasks = provider.tasks;
    final filtered = allTasks.where((t) => _matchFilter(t.status)).toList();
    final done = allTasks.where((t) {
      final u = t.status.toUpperCase();
      return u == 'APPROVED' || u == 'DONE';
    }).length;
    final total = allTasks.length;
    final progress = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Text('📋 Nhiệm vụ', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.safe.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text('$done/$total hoàn thành', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.safe)),
                ),
            ]),
          ),

          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.safe),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tiến độ: ${(progress * 100).round()}% · ${total - done} việc còn lại',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                ),
              ]),
            ),
          const SizedBox(height: 12),

          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _filters.map((f) => GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filter == f ? AppColors.link : AppColors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                      ),
                      child: Text(f, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _filter == f ? Colors.white : AppColors.textSecondary)),
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => context.read<TaskProvider>().fetchMyAssignments(),
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('📋', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                allTasks.isEmpty ? 'Chưa có nhiệm vụ nào' : 'Không có nhiệm vụ trong mục này',
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                              ),
                            ]),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final catIcon = (t.categoryName?.toLowerCase().contains('học') ?? false) ? '📚' : '🏠';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                                ),
                                child: Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                                        alignment: Alignment.center,
                                        child: Text(catIcon, style: const TextStyle(fontSize: 24)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(t.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          if (t.categoryName != null) ...[
                                            Text(t.categoryName!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                            const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                                          ],
                                          if (t.dueDate != null)
                                            Text(
                                              'Hạn: ${t.dueDate!.length >= 10 ? t.dueDate!.substring(0, 10) : t.dueDate!}',
                                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                            ),
                                        ]),
                                        if (t.reward > 0) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: AppColors.income.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                                            child: Text(_fmt(t.reward), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.income)),
                                          ),
                                        ],
                                      ])),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: _statusColor(t.status).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                                          child: Text(_statusLabel(t.status), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(t.status))),
                                        ),
                                        if (t.status.toUpperCase() == 'DONE' || t.status.toUpperCase() == 'APPROVED') ...[
                                          const SizedBox(height: 6),
                                          Row(mainAxisSize: MainAxisSize.min, children: [
                                            GestureDetector(
                                              onTap: () => _confirmReceived(t),
                                              child: Text('Đã nhận thưởng', style: GoogleFonts.inter(fontSize: 11, color: AppColors.safe, decoration: TextDecoration.underline)),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _reportDispute(t),
                                              child: Text('Khiếu nại', style: GoogleFonts.inter(fontSize: 11, color: AppColors.danger, decoration: TextDecoration.underline)),
                                            ),
                                          ]),
                                        ],
                                      ]),
                                    ]),
                                  ),
                                  // Action buttons
                                  if (_canStart(t.status) || _canSubmit(t.status))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                                      child: Row(children: [
                                        if (_canStart(t.status))
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: SizedBox(
                                                height: 40,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                  onPressed: () => _startTask(t),
                                                  child: Text('Bắt đầu 🚀', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_canSubmit(t.status))
                                          Expanded(
                                            child: SizedBox(
                                              height: 40,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                onPressed: () => _submitTask(t),
                                                child: Text('Nộp bài ✅', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 6),
                                        if (_canSubmit(t.status))
                                          GestureDetector(
                                            onTap: () => _reportUnavailability(t),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.block_rounded, size: 18, color: AppColors.textMuted),
                                            ),
                                          ),
                                      ]),
                                    ),
                                ]),
                              );
                            },
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}
