import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/task_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

/// Khối "Bài nộp của bạn" cho người được giao việc.
///
/// Trước đây chỉ màn quản lý mới gọi `fetchLatestSubmission` nên người nộp
/// không xem lại được minh chứng mình đã gửi, và quan trọng hơn: **không đọc
/// được `reviewNote`** — lý do quản lý từ chối. Bị từ chối mà không biết vì sao
/// thì nộp lại lần nữa cũng trượt tiếp.
class TaskSubmissionRecap extends StatefulWidget {
  const TaskSubmissionRecap({
    super.key,
    required this.assignmentId,
    required this.assignmentStatus,
  });

  final String assignmentId;

  /// Trạng thái phân công: SUBMITTED | APPROVED | REJECTED.
  final String assignmentStatus;

  /// Bị từ chối thì nhận xét là thứ cần đọc ngay, không bắt bấm mới hiện.
  /// Các trạng thái khác nạp khi người dùng mở, để một danh sách nhiều thẻ
  /// không bắn kèm ngần ấy request lúc mở màn hình.
  bool get autoLoad => assignmentStatus == 'REJECTED';

  @override
  State<TaskSubmissionRecap> createState() => _TaskSubmissionRecapState();
}

class _TaskSubmissionRecapState extends State<TaskSubmissionRecap> {
  TaskSubmission? _submission;
  bool _loading = false;
  bool _expanded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _expanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_loading || _submission != null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await context.read<TaskProvider>().fetchLatestSubmission(
      widget.assignmentId,
    );
    if (!mounted) return;
    setState(() {
      _submission = result;
      _failed = result == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rejected = widget.assignmentStatus == 'REJECTED';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rejected ? const Color(0xFFFEF2F2) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _load();
            },
            child: Row(
              children: [
                Icon(
                  rejected
                      ? Icons.error_outline_rounded
                      : Icons.assignment_turned_in_outlined,
                  size: 16,
                  color: rejected ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _headerLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: rejected
                          ? const Color(0xFF991B1B)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          if (_expanded) ...[const SizedBox(height: 8), ..._body()],
        ],
      ),
    );
  }

  String get _headerLabel => switch (widget.assignmentStatus) {
    'REJECTED' => 'Vì sao bị từ chối',
    'APPROVED' => 'Bài nộp đã được duyệt',
    _ => 'Bài nộp của bạn',
  };

  List<Widget> _body() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }
    final submission = _submission;
    if (submission == null) {
      return [
        _muted(
          _failed
              ? 'Chưa tải được bài nộp. Kéo xuống để tải lại danh sách rồi thử '
                    'lại.'
              : 'Không tìm thấy bài nộp nào.',
        ),
      ];
    }

    final reviewNote = submission.reviewNote?.trim() ?? '';
    final submissionNote = submission.submissionNote?.trim() ?? '';
    return [
      // Nhận xét của người duyệt lên trước — đây là thứ người nộp cần nhất.
      if (reviewNote.isNotEmpty) ...[
        _label('Nhận xét của người quản lý'),
        Text(
          reviewNote,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
      ] else if (widget.assignmentStatus == 'REJECTED')
        _muted('Người quản lý không để lại lý do cụ thể.'),

      if (submissionNote.isNotEmpty) ...[
        _label('Ghi chú bạn đã gửi'),
        Text(
          submissionNote,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
      ],

      if (submission.proofs.isEmpty)
        _muted('Bài nộp này không kèm minh chứng nào.')
      else ...[
        _label('Minh chứng đã gửi (${submission.proofs.length})'),
        ...submission.proofs.map(_proofTile),
      ],
    ];
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _muted(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textMuted,
    ),
  );

  Widget _proofTile(TaskProof proof) {
    if (proof.proofType == 'IMAGE' && (proof.fileUrl ?? '').isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            ApiClient.absoluteUrl(proof.fileUrl!),
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    height: 150,
                    color: AppColors.neutralBg,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (_, _, _) => Container(
              height: 80,
              color: AppColors.neutralBg,
              alignment: Alignment.center,
              child: _muted('Không tải được ảnh'),
            ),
          ),
        ),
      );
    }
    final icon = switch (proof.proofType) {
      'VIDEO' => Icons.videocam_outlined,
      'FILE' => Icons.attach_file_rounded,
      _ => Icons.notes_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              proof.note?.trim().isNotEmpty == true
                  ? proof.note!.trim()
                  : (proof.fileUrl ?? proof.proofType),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
