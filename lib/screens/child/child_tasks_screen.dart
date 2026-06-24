import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
      final provider = context.read<TaskProvider>();
      provider.fetchMyAssignments();
      // API tự lọc settlements theo member hiện tại (role-based)
      provider.fetchSettlements();
    });
  }

  // ERD: assignment_status = ASSIGNED | IN_PROGRESS | SUBMITTED | APPROVED | REJECTED | CANCELED
  bool _matchFilter(String status) {
    switch (_filter) {
      case 'Chờ làm':
        return status == 'ASSIGNED' || status == 'SCHEDULED'
            || status == 'PENDING' || status == 'TODO'; // legacy compat
      case 'Đang làm':
        return status == 'IN_PROGRESS';
      case 'Đã nộp':
        return status == 'SUBMITTED';
      case 'Hoàn thành':
        return status == 'APPROVED';
      default:
        return status != 'CANCELED'; // ẩn cancelled khỏi "Tất cả"
    }
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'IN_PROGRESS':
        return const Color(0xFFD97706);
      case 'SUBMITTED':
        return AppColors.planned;
      case 'APPROVED':
        return AppColors.safe;
      case 'REJECTED':
        return AppColors.sos;
      case 'CANCELED':
        return AppColors.textMuted;
      default: // ASSIGNED, SCHEDULED
        return AppColors.link;
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'IN_PROGRESS':
        return '🔄 Đang làm';
      case 'SUBMITTED':
        return '⏳ Chờ duyệt';
      case 'APPROVED':
        return '✅ Đã duyệt';
      case 'REJECTED':
        return '❌ Từ chối';
      case 'CANCELED':
        return '🚫 Đã hủy';
      case 'SCHEDULED':
        return '📅 Lịch sắp tới';
      default: // ASSIGNED, PENDING, TODO
        return '🔵 Chờ làm';
    }
  }

  // Chỉ hiện "Bắt đầu" khi task ASSIGNED/SCHEDULED chưa IN_PROGRESS
  bool _canStart(String s) {
    final u = s.toUpperCase();
    return u == 'ASSIGNED' || u == 'SCHEDULED' || u == 'PENDING' || u == 'TODO';
  }

  // Hiện "Nộp bài" khi đang làm hoặc chưa click bắt đầu
  bool _canSubmit(String s) {
    final u = s.toUpperCase();
    return u == 'ASSIGNED' || u == 'SCHEDULED'
        || u == 'IN_PROGRESS'
        || u == 'PENDING' || u == 'TODO';
  }

  // Hiện nút báo không thể làm khi chưa submitted
  bool _canReportUnavailable(String s) {
    final u = s.toUpperCase();
    return u == 'ASSIGNED' || u == 'SCHEDULED'
        || u == 'IN_PROGRESS'
        || u == 'PENDING' || u == 'TODO';
  }

  String _fmt(double n) =>
      '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

  Future<void> _startTask(TaskItem t) async {
    final id = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
    try {
      await context.read<TaskProvider>().startAssignment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bắt đầu làm! Cố lên nào 💪'),
            backgroundColor: AppColors.safe,
          ),
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
    final picker = ImagePicker();
    final pickedImages = <XFile>[];
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
              Text('Nộp nhiệm vụ',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(t.title,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Note field
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ghi chú minh chứng cho Ba/Mẹ...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),

              // Image picker row
              GestureDetector(
                onTap: () async {
                  final imgs = await picker.pickMultiImage(imageQuality: 70);
                  if (imgs.isNotEmpty) {
                    setBS(() {
                      pickedImages.clear();
                      pickedImages.addAll(imgs.take(4));
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.progressTrack),
                  ),
                  child: Column(children: [
                    const Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text('Thêm ảnh minh chứng (tối đa 4)',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                ),
              ),

              // Preview thumbnails
              if (pickedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pickedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder(
                            future: pickedImages[i].readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.background,
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }
                              return Image.memory(
                                snapshot.data!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setBS(() => pickedImages.removeAt(i)),
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(color: AppColors.sos, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

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
                            final provider = context.read<TaskProvider>();
                            final assignmentId = t.assignmentId.isNotEmpty ? t.assignmentId : t.id;

                            // Upload images → collect proofs
                            final extraProofs = <Map<String, dynamic>>[];
                            for (final img in pickedImages) {
                              final bytes = await img.readAsBytes();
                              final filename = img.name.isNotEmpty ? img.name : 'proof.jpg';
                              try {
                                final url = await provider.uploadProofFile(bytes, filename);
                                if (url.isNotEmpty) {
                                  extraProofs.add({'proofType': 'IMAGE', 'fileUrl': url});
                                }
                              } catch (_) {
                                // Tiếp tục nếu upload 1 ảnh lỗi
                              }
                            }

                            await provider.submitCompletion(
                              assignmentId,
                              note: noteCtrl.text,
                              extraProofs: extraProofs,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã nộp! Chờ Ba/Mẹ duyệt nhé 🎉'), backgroundColor: AppColors.safe),
                              );
                              provider.fetchMyAssignments();
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
                      : Text('Xác nhận nộp bài',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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
              Text('Báo không thể làm',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(t.title,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Lý do không thể làm (VD: Con bị ốm...)',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reasonCtrl.text.trim().isEmpty) return;
                          setBS(() => submitting = true);
                          try {
                            final assignmentId =
                                t.assignmentId.isNotEmpty ? t.assignmentId : t.id;
                            await context
                                .read<TaskProvider>()
                                .reportUnavailability(assignmentId,
                                    reason: reasonCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã báo cho Ba/Mẹ biết'),
                                  backgroundColor: AppColors.safe,
                                ),
                              );
                            }
                          } catch (e) {
                            setBS(() => submitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text('Gửi báo cáo',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }

  /// Xác nhận đã nhận thưởng — chỉ gọi khi settlement.status == WAITING_CONFIRMATION
  Future<void> _confirmReceived(String settlementId) async {
    try {
      final taskProvider = context.read<TaskProvider>();
      await taskProvider.confirmSettlementReceived(settlementId);
      await taskProvider.fetchMyAssignments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận nhận thưởng! 🎉'),
            backgroundColor: AppColors.safe,
          ),
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

  /// Khiếu nại chưa nhận thưởng — settlement phải ở WAITING_CONFIRMATION
  Future<void> _reportDispute(String settlementId, String taskTitle) async {
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
              Text('Chưa nhận được thưởng?',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(taskTitle,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Nhập lý do để Ba/Mẹ xem xét lại',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'VD: Con đã hoàn thành nhưng chưa nhận thưởng...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reasonCtrl.text.trim().isEmpty) return;
                          setBS(() => submitting = true);
                          try {
                            await context
                                .read<TaskProvider>()
                                .createDispute(settlementId,
                                    reason: reasonCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã gửi khiếu nại'),
                                  backgroundColor: AppColors.safe,
                                ),
                              );
                            }
                          } catch (e) {
                            setBS(() => submitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text('Gửi khiếu nại',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textMuted)),
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
    final filtered =
        allTasks.where((t) => _matchFilter(t.status)).toList();
    final done = allTasks
        .where((t) => t.status.toUpperCase() == 'APPROVED')
        .length;
    final total = allTasks
        .where((t) => t.status.toUpperCase() != 'CANCELED')
        .length;
    final progress = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Text('📋 Nhiệm vụ',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (total > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.safe.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('$done/$total hoàn thành',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.safe)),
                ),
            ]),
          ),

          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.safe),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tiến độ: ${(progress * 100).round()}% · ${total - done} việc còn lại',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ]),
            ),
          const SizedBox(height: 12),

          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _filters
                  .map((f) => GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _filter == f
                                ? AppColors.link
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Text(f,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _filter == f
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await provider.fetchMyAssignments();
                      await provider.fetchSettlements();
                    },
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('📋',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  allTasks.isEmpty
                                      ? 'Chưa có nhiệm vụ nào'
                                      : 'Không có nhiệm vụ trong mục này',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textMuted),
                                ),
                              ]),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              // Tìm settlement theo taskId để hiển thị đúng trạng thái thưởng
                              final settlement =
                                  provider.settlementFor(t.id);
                              return _buildTaskCard(t, settlement);
                            },
                          ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTaskCard(TaskItem t, RewardSettlement? settlement) {
    final catIcon = (t.categoryName?.toLowerCase().contains('học') ?? false)
        ? '📚'
        : '🏠';

    // Settlement badges — dựa theo ERD: PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED
    final settlementStatus = settlement?.status ?? '';
    final hasPendingReward = settlementStatus == 'PENDING_SETTLEMENT';
    final needsConfirm = settlementStatus == 'WAITING_CONFIRMATION';
    final isDisputed = settlementStatus == 'DISPUTED';
    final isSettled = settlementStatus == 'SETTLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(catIcon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.title,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  if (t.categoryName != null) ...[
                    Text(t.categoryName!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                    const Text(' · ',
                        style: TextStyle(color: AppColors.textMuted)),
                  ],
                  if (t.dueDate != null)
                    Text(
                      'Hạn: ${t.dueDate!.length >= 10 ? t.dueDate!.substring(0, 10) : t.dueDate!}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                ]),
                if (t.reward > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(_fmt(t.reward),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.income)),
                  ),
                ],
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Task status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _statusColor(t.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(_statusLabel(t.status),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(t.status))),
              ),
              // Settlement status badge (khi task đã APPROVED)
              if (t.status.toUpperCase() == 'APPROVED' &&
                  settlement != null) ...[
                const SizedBox(height: 4),
                _settlementBadge(settlementStatus),
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
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () => _startTask(t),
                        child: Text('Bắt đầu 🚀',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              if (_canSubmit(t.status))
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.link,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => _submitTask(t),
                      child: Text('Nộp bài ✅',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
              if (_canReportUnavailable(t.status)) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _reportUnavailability(t),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.block_rounded,
                        size: 18, color: AppColors.textMuted),
                  ),
                ),
              ],
            ]),
          ),

        // Reward action buttons — CHỈ hiện khi settlement.status == WAITING_CONFIRMATION
        if (needsConfirm && settlement != null)
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.safe,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _confirmReceived(settlement.id),
                    child: Text('Đã nhận thưởng 🎁',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _reportDispute(settlement.id, t.title),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text('Khiếu nại',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger)),
                ),
              ),
            ]),
          ),

        // Thưởng đã SETTLED — thông báo nhẹ
        if (isSettled && !hasPendingReward && !needsConfirm && !isDisputed)
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.safe.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('🏆 Đã nhận thưởng thành công',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.safe)),
            ),
          ),
      ]),
    );
  }

  Widget _settlementBadge(String status) {
    switch (status) {
      case 'PENDING_SETTLEMENT':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('⏳ Chờ chuyển thưởng',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF59E0B))),
        );
      case 'WAITING_CONFIRMATION':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: AppColors.link.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('💰 Cần xác nhận',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.link)),
        );
      case 'DISPUTED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('⚠️ Đang khiếu nại',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger)),
        );
      case 'SETTLED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: AppColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999)),
          child: Text('✅ Đã nhận',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.safe)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
