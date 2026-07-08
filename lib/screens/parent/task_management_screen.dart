import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/money_input.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});
  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<TaskProvider>();
      tp.fetchTasks();
      tp.fetchCategories();
      tp.fetchSettlements();
      tp.fetchDisputes();
      tp.fetchUnavailabilities();
    });
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: AppColors.link,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.link,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Công việc'),
                Tab(text: 'Danh mục'),
                Tab(text: 'Phân công'),
                Tab(text: 'Thưởng'),
                Tab(text: 'Không thể làm'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  _TasksTab(),
                  _CategoriesTab(),
                  _AssignmentsTab(),
                  _RewardsTab(),
                  _UnavailabilityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('Quản lý Tasks',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );
}

// ─── Tab: Công việc ───────────────────────────────────────────────────────────

class _TasksTab extends StatefulWidget {
  const _TasksTab();
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String? _filter;
  TaskItem? _approveTask;
  String? _submissionId;
  String? _submittedAssignmentId;
  String? _submissionNote;
  List<Map<String, dynamic>> _submissionProofs = [];
  bool _loadingSubmission = false;
  bool _showCreate = false;
  bool _showRecurring = false;
  bool _submitting = false;
  final _titleCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selCategoryId;
  String _selPriority = 'MEDIUM';
  String _dueDate = '';
  final _recurTitleCtrl = TextEditingController();
  final _recurDescCtrl = TextEditingController();
  String _repeatType = 'WEEKLY';
  int _repeatInterval = 1;
  String _startDate = '';
  String _endDate = '';

  static const _statusCfg = {
    'DRAFT':     (label: 'Bản nháp',   bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    'ACTIVE':    (label: 'Đang thực hiện', bg: Color(0xFFFEF3C7), color: Color(0xFFD97706)),
    'COMPLETED': (label: 'Hoàn thành', bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    'CANCELED':  (label: 'Đã hủy',     bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _rewardCtrl.dispose();
    _descCtrl.dispose();
    _recurTitleCtrl.dispose();
    _recurDescCtrl.dispose();
    super.dispose();
  }

  String _submissionIdOf(Map<String, dynamic> submission) =>
      submission['id']?.toString() ?? submission['submissionId']?.toString() ?? '';

  String? _submissionNoteOf(Map<String, dynamic> submission) =>
      submission['submissionNote']?.toString() ??
      submission['note']?.toString() ??
      submission['comment']?.toString();

  List<Map<String, dynamic>> _proofsOf(Map<String, dynamic> submission) {
    for (final key in const [
      'proofs',
      'taskProofs',
      'proofFiles',
      'files',
      'attachments',
      'evidences',
    ]) {
      final raw = submission[key];
      if (raw is List) {
        return raw.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
      }
      if (raw is Map) {
        final nested = _proofsOf(Map<String, dynamic>.from(raw));
        if (nested.isNotEmpty) return nested;
      }
    }
    for (final key in const ['data', 'submission', 'latestSubmission']) {
      final raw = submission[key];
      if (raw is Map) {
        final nested = _proofsOf(Map<String, dynamic>.from(raw));
        if (nested.isNotEmpty) return nested;
      }
    }
    return [];
  }

  String _proofUrlOf(Map<String, dynamic> proof) {
    const keys = [
      'fileUrl',
      'url',
      'thumbnailUrl',
      'publicUrl',
      'path',
      'filePath',
      'storagePath',
      'proofUrl',
      'file_url',
      'proofValue',
      'value',
    ];
    for (final key in keys) {
      final value = proof[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    for (final key in const ['file', 'media', 'attachment', 'resource', 'data']) {
      final nested = proof[key];
      if (nested is Map) {
        final value = _proofUrlOf(Map<String, dynamic>.from(nested));
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  bool _isImageProof(Map<String, dynamic> proof) {
    final type = proof['proofType']?.toString().toUpperCase();
    final mime = (proof['mimeType'] ?? proof['contentType'] ?? proof['type'])
        ?.toString()
        .toLowerCase();
    final url = _proofUrlOf(proof).toLowerCase();
    return type == 'IMAGE' ||
        (mime != null && mime.startsWith('image/')) ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp');
  }

  List<Map<String, dynamic>> get _imageProofs =>
      _submissionProofs.where(_isImageProof).toList();

  Future<void> _openApproveSheet(TaskItem task) async {
    setState(() {
      _approveTask = task;
      _submissionId = null;
      _submittedAssignmentId = null;
      _submissionNote = null;
      _submissionProofs = [];
      _loadingSubmission = true;
    });
    try {
      final provider = context.read<TaskProvider>();
      // 1. Load all assignments for this task
      final assignments = await provider.fetchTaskAssignments(task.id);
      // 2. Find assignment with SUBMITTED status
      final submitted = assignments.where((a) => a['status'] == 'SUBMITTED').toList();
      if (submitted.isEmpty) {
        if (mounted) setState(() => _loadingSubmission = false);
        return;
      }
      final assignment = submitted.last;
      final assignmentId = assignment['id']?.toString() ?? '';
      // 3. Load submissions for this assignment
      final subs = await provider.fetchSubmissions(assignmentId);
      if (mounted) {
        if (subs.isNotEmpty) {
          var latest = subs.last;
          final submissionId = _submissionIdOf(latest);
          var proofs = _proofsOf(latest);
          if (submissionId.isNotEmpty && proofs.isEmpty) {
            try {
              final detail = await provider.fetchSubmission(submissionId);
              latest = detail;
              proofs = _proofsOf(detail);
            } catch (_) {}
          }
          setState(() {
            _submissionId = submissionId;
            _submittedAssignmentId = assignmentId;
            _submissionNote = _submissionNoteOf(latest);
            _submissionProofs = proofs;
            _loadingSubmission = false;
          });
        } else {
          setState(() {
            _submittedAssignmentId = assignmentId;
            _loadingSubmission = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubmission = false);
    }
  }

  List<TaskItem> _filtered(List<TaskItem> tasks) =>
      _filter == null ? tasks : tasks.where((t) => t.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final tasks = taskState.tasks;
    final activeCount = tasks.where((t) => t.status == 'ACTIVE').length;
    final completedCount = tasks.where((t) => t.status == 'COMPLETED').length;

    return Stack(
      children: [
        Column(
          children: [
            if (taskState.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (taskState.error != null)
              Expanded(child: _errorView(taskState.error!, () => taskState.fetchTasks()))
            else ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _summaryCard(tasks.length, 'Tổng', AppColors.textPrimary),
                  const SizedBox(width: 12),
                  _summaryCard(activeCount, 'Đang làm', AppColors.link),
                  const SizedBox(width: 12),
                  _summaryCard(completedCount, 'Xong', AppColors.success),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _filterChip(null, 'Tất cả'),
                    _filterChip('ACTIVE', 'Đang làm', badge: activeCount),
                    _filterChip('COMPLETED', 'Hoàn thành'),
                    _filterChip('DRAFT', 'Bản nháp'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => taskState.fetchTasks(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    children: [
                      ..._filtered(tasks).map((task) {
                        final st = _statusCfg[task.status] ?? _statusCfg['DRAFT']!;
                        final isActive = task.status == 'ACTIVE';
                        return GestureDetector(
                          onTap: isActive ? () => _openApproveSheet(task) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: isActive ? Border.all(color: AppColors.link.withOpacity(0.25)) : null,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                            ),
                            child: Row(children: [
                              Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(color: isActive ? AppColors.link : AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                    if (isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                        child: Text('Duyệt →', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.link)),
                                      ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, children: [
                                    _chip(st.label, st.bg, st.color),
                                    if (task.reward > 0)
                                      _chip('💰 ${(task.reward / 1000).toStringAsFixed(0)}K', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                                    if (task.categoryName != null)
                                      _chip(task.categoryName!, const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
                                  ]),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              AvatarWidget(
                                initial: task.assigneeName.isNotEmpty ? task.assigneeName.substring(0, 1).toUpperCase() : '?',
                                color: AppColors.avatarOrange,
                                size: 36,
                              ),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'recurring_fab',
              backgroundColor: const Color(0xFF7C3AED),
              onPressed: () => setState(() { _showRecurring = true; _recurTitleCtrl.clear(); _recurDescCtrl.clear(); _repeatType = 'WEEKLY'; _repeatInterval = 1; _startDate = ''; _endDate = ''; }),
              child: const Icon(Icons.repeat_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'task_fab',
              backgroundColor: AppColors.link,
              onPressed: () => setState(() => _showCreate = true),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ]),
        ),
        if (_approveTask != null)
          _BottomSheetOverlay(child: _approveSheet(context)),
        if (_showCreate)
          _BottomSheetOverlay(child: _createSheet(context)),
        if (_showRecurring)
          _BottomSheetOverlay(child: _recurringSheet(context)),
      ],
    );
  }

  Widget _approveSheet(BuildContext context) {
    final t = _approveTask!;
    final hasSubmittedAssignment = _submittedAssignmentId != null;
    final hasSubmission = _submissionId != null;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Duyệt minh chứng', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
      if (_loadingSubmission) ...[
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
      ] else if (!hasSubmittedAssignment) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
          child: Text('Chưa có thành viên nộp bài cho task này.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFD97706))),
        ),
      ] else if (!hasSubmission) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
          child: Text('Không tải được minh chứng nộp bài cho assignment này.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFD97706))),
        ),
      ] else ...[
        if (_submissionNote != null && _submissionNote!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ghi chú:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(_submissionNote!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            ]),
          ),
        ],
        // Proof images
        if (_imageProofs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Ảnh minh chứng:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _imageProofs
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(ApiClient.absoluteUrl(_proofUrlOf(p)), width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: const Color(0xFFF3F4F6), child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted))),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSubmission ? AppColors.success : AppColors.textMuted,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_submitting || _loadingSubmission || !hasSubmission) ? null : () async {
              setState(() => _submitting = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<TaskProvider>().reviewSubmission(_submissionId!, approved: true);
                try {
                  await context.read<TaskProvider>().createSettlement(_submissionId!);
                } catch (settlementErr) {
                  final msg = settlementErr.toString().toLowerCase();
                  final alreadyExists = msg.contains('exist') || msg.contains('already') || msg.contains('đã tồn tại');
                  if (!alreadyExists) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('Duyệt thành công nhưng chưa tạo được thưởng: ${settlementErr.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: AppColors.heroOrange,
                    ));
                  }
                }
                if (mounted) {
                  setState(() { _approveTask = null; _submitting = false; });
                  context.read<TaskProvider>().fetchTasks();
                  context.read<TaskProvider>().fetchSettlements();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _submitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              }
            },
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Text('Duyệt', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSubmission ? AppColors.danger : AppColors.textMuted,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_submitting || _loadingSubmission || !hasSubmission) ? null : () async {
              setState(() => _submitting = true);
              try {
                await context.read<TaskProvider>().reviewSubmission(_submissionId!, approved: false);
                if (mounted) {
                  setState(() { _approveTask = null; _submitting = false; });
                  context.read<TaskProvider>().fetchTasks();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _submitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              }
            },
            child: Text('Từ chối', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
      TextButton(
        onPressed: () => setState(() => _approveTask = null),
        child: Center(child: Text('Xem lại sau', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted))),
      ),
    ]);
  }

  Widget _createSheet(BuildContext context) {
    final categories = context.watch<TaskProvider>().categories
        .where((c) => c.status == 'ACTIVE').toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tạo task mới', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 16),
      Text('Tên task', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(hintText: 'VD: Dọn phòng khách', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      ),
      const SizedBox(height: 12),
      Text('Mô tả (tùy chọn)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      _inputBox(_descCtrl, 'VD: Lau bàn ghế, hút bụi sofa...'),
      const SizedBox(height: 12),
      if (categories.isNotEmpty) ...[
        Text('Danh mục', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: categories.map((c) {
            final sel = _selCategoryId == c.id;
            return ChoiceChip(
              selected: sel,
              label: Text(c.name),
              onSelected: (_) => setState(() => _selCategoryId = sel ? null : c.id),
              selectedColor: AppColors.primary500,
              backgroundColor: AppColors.primary50,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.primary600),
              side: BorderSide(color: sel ? AppColors.primary500 : AppColors.progressTrack),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ưu tiên', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            for (final p in const [('LOW', 'Thấp'), ('MEDIUM', 'Vừa'), ('HIGH', 'Cao')])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selPriority = p.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selPriority == p.$1 ? AppColors.primary500 : AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _selPriority == p.$1 ? AppColors.primary500 : AppColors.progressTrack),
                    ),
                    alignment: Alignment.center,
                    child: Text(p.$2, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _selPriority == p.$1 ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              ),
          ]),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hạn chót (tùy chọn)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dateBox(_dueDate, (iso) => setState(() => _dueDate = iso)),
        ])),
      ]),
      const SizedBox(height: 12),
      Text('Thuong (VND)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: _rewardCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(hintText: 'VD: 50.000', suffixText: '₫', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: _submitting ? null : () async {
          if (_titleCtrl.text.isEmpty) return;
          setState(() => _submitting = true);
          try {
            final provider = context.read<TaskProvider>();
            final task = await provider.createTask(
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              categoryId: _selCategoryId,
              priority: _selPriority,
              // BE nhận ISO datetime — lấy cuối ngày đã chọn
              dueAt: _dueDate.isNotEmpty
                  ? DateTime.parse('$_dueDate 23:59:59').toUtc().toIso8601String()
                  : null,
            );
            final rewardAmount = parseMoneyInput(_rewardCtrl.text);
            if (task.id.isNotEmpty && rewardAmount > 0) {
              await provider.createRewardSetting(
                task.id,
                rewardType: 'MONEY_RECORD',
                rewardAmount: rewardAmount,
                autoCreateSettlement: true,
              );
              await provider.fetchTasks();
            }
            if (mounted) {
              _titleCtrl.clear();
              _rewardCtrl.clear();
              _descCtrl.clear();
              setState(() {
                _showCreate = false;
                _submitting = false;
                _selCategoryId = null;
                _selPriority = 'MEDIUM';
                _dueDate = '';
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() => _submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
            }
          }
        },
        child: _submitting
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text('Tạo task', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      TextButton(
        onPressed: () => setState(() => _showCreate = false),
        child: Center(child: Text('Hủy', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted))),
      ),
    ]);
  }

  Widget _recurringSheet(BuildContext context) {
    final now = DateTime.now();
    final defaultStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_startDate.isEmpty) _startDate = defaultStart;

    return StatefulBuilder(builder: (ctx, setSheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tạo task lặp lại', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _fieldLabel('Tên task'),
        const SizedBox(height: 6),
        _inputBox(_recurTitleCtrl, 'VD: Dọn phòng hàng tuần...'),
        const SizedBox(height: 12),
        _fieldLabel('Mô tả (tùy chọn)'),
        const SizedBox(height: 6),
        _inputBox(_recurDescCtrl, 'Mô tả ngắn...'),
        const SizedBox(height: 12),
        _fieldLabel('Kiểu lặp'),
        const SizedBox(height: 6),
        Row(children: ['DAILY', 'WEEKLY', 'MONTHLY'].map((t) => Expanded(
          child: GestureDetector(
            onTap: () => setSheet(() => _repeatType = t),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _repeatType == t ? AppColors.link : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t == 'DAILY' ? 'Ngày' : t == 'WEEKLY' ? 'Tuần' : 'Tháng',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _repeatType == t ? Colors.white : AppColors.textSecondary),
              ),
            ),
          ),
        )).toList()),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Ngày bắt đầu'),
            const SizedBox(height: 6),
            _dateBox(_startDate.isNotEmpty ? _startDate : defaultStart,
                (iso) => setState(() => _startDate = iso)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Ngày kết thúc (tùy chọn)'),
            const SizedBox(height: 6),
            _dateBox(_endDate, (iso) => setState(() => _endDate = iso)),
          ])),
        ]),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _submitting
              ? null
              : () async {
                  if (_recurTitleCtrl.text.trim().isEmpty) return;
                  setState(() => _submitting = true);
                  try {
                    await context.read<TaskProvider>().createRecurringTask(
                      title: _recurTitleCtrl.text.trim(),
                      description: _recurDescCtrl.text.trim(),
                      schedule: {
                        'repeatType': _repeatType,
                        'repeatInterval': _repeatInterval,
                        'startDate': _startDate.isNotEmpty ? _startDate : defaultStart,
                        if (_endDate.isNotEmpty) 'endDate': _endDate,
                        'status': 'ACTIVE',
                      },
                    );
                    if (mounted) {
                      setState(() { _showRecurring = false; _submitting = false; });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã tạo task lặp lại!'), backgroundColor: AppColors.safe),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _submitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                    }
                  }
                },
          child: _submitting
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text('Tạo task lặp lại', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        TextButton(
          onPressed: () => setState(() => _showRecurring = false),
          child: Center(child: Text('Hủy', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted))),
        ),
      ],
    ));
  }

  // Ô chọn ngày cho task lặp lại — BE chỉ nhận YYYY-MM-DD nên dùng lịch
  Widget _dateBox(String iso, ValueChanged<String> onPicked) => GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(iso) ?? now,
            firstDate: now,
            lastDate: DateTime(now.year + 5),
          );
          if (picked != null) {
            onPicked('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
          }
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(iso.isEmpty ? 'Chọn ngày' : iso,
                style: GoogleFonts.inter(fontSize: 14, color: iso.isEmpty ? AppColors.textMuted : AppColors.textPrimary))),
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textMuted),
          ]),
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
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(children: [
            Text('$val', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
          if (badge > 0) ...[
            const SizedBox(width: 4),
            Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger), alignment: Alignment.center, child: Text('$badge', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
            const SizedBox(width: 4),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// ─── Tab: Danh mục ────────────────────────────────────────────────────────────

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  bool _showCreate = false;
  bool _submitting = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<TaskProvider>().categories;
    final active = cats.where((c) => c.status == 'ACTIVE').toList();
    final inactive = cats.where((c) => c.status != 'ACTIVE').toList();

    return Stack(children: [
      RefreshIndicator(
        onRefresh: () => context.read<TaskProvider>().fetchCategories(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            if (active.isNotEmpty) ...[
              Text('Đang dùng', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...active.map((c) => _categoryCard(c)),
            ],
            if (inactive.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Đã ẩn', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              ...inactive.map((c) => _categoryCard(c)),
            ],
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🗂️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('Chưa có danh mục nào', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      Positioned(
        right: 20,
        bottom: 20,
        child: FloatingActionButton(
          heroTag: 'cat_fab',
          backgroundColor: AppColors.link,
          onPressed: () => setState(() { _showCreate = true; _nameCtrl.clear(); _descCtrl.clear(); }),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      if (_showCreate) _BottomSheetOverlay(child: _createSheet(context)),
    ]);
  }

  Widget _categoryCard(TaskCategory c) {
    final isActive = c.status == 'ACTIVE';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: isActive ? AppColors.link.withOpacity(0.1) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(Icons.category_rounded, size: 20, color: isActive ? AppColors.link : AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (c.description.isNotEmpty)
            Text(c.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        GestureDetector(
          onTap: () async {
            try {
              await context.read<TaskProvider>().updateCategory(
                c.id,
                status: isActive ? 'INACTIVE' : 'ACTIVE',
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isActive ? 'Đang dùng' : 'Đã ẩn',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF16A34A) : AppColors.textMuted),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _createSheet(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tạo danh mục mới', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _fieldLabel('Tên danh mục'),
          const SizedBox(height: 6),
          _inputBox(_nameCtrl, 'VD: Học tập, Nhà cửa, Thể thao...'),
          const SizedBox(height: 12),
          _fieldLabel('Mô tả (tùy chọn)'),
          const SizedBox(height: 6),
          _inputBox(_descCtrl, 'Mô tả ngắn về danh mục này'),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _submitting
                ? null
                : () async {
                    if (_nameCtrl.text.trim().isEmpty) return;
                    setState(() => _submitting = true);
                    try {
                      await context.read<TaskProvider>().createCategory(
                            name: _nameCtrl.text.trim(),
                            description: _descCtrl.text.trim(),
                          );
                      if (mounted) setState(() { _showCreate = false; _submitting = false; });
                    } catch (e) {
                      if (mounted) {
                        setState(() => _submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                      }
                    }
                  },
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Text('Tạo danh mục', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          TextButton(
            onPressed: () => setState(() => _showCreate = false),
            child: Center(child: Text('Hủy', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted))),
          ),
        ],
      );
}

// ─── Tab: Phân công ───────────────────────────────────────────────────────────

class _AssignmentsTab extends StatefulWidget {
  const _AssignmentsTab();
  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  TaskItem? _selected;
  List<Map<String, dynamic>> _assignments = [];
  bool _loadingAssign = false;
  bool _submitting = false;
  final _memberCtrl = TextEditingController();

  @override
  void dispose() {
    _memberCtrl.dispose();
    super.dispose();
  }

  String _assignableMemberId(dynamic member) {
    final memberId = member.id.toString();
    return memberId.isNotEmpty ? memberId : member.userId.toString();
  }

  Future<void> _loadAssignments(TaskItem task) async {
    setState(() { _selected = task; _assignments = []; _loadingAssign = true; });
    try {
      final list = await context.read<TaskProvider>().fetchTaskAssignments(task.id);
      if (mounted) setState(() { _assignments = list; _loadingAssign = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAssign = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().tasks;

    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text('Chọn công việc để xem / quản lý phân công:', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...tasks.map((t) => GestureDetector(
                onTap: () => _loadAssignments(t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selected?.id == t.id ? AppColors.link.withOpacity(0.08) : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _selected?.id == t.id ? AppColors.link : Colors.transparent, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
                  ),
                  child: Row(children: [
                    Expanded(child: Text(t.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ]),
                ),
              )),
          if (_selected != null) ...[
            const SizedBox(height: 20),
            Text('Phân công của "${_selected!.title}"', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            if (_loadingAssign)
              const Center(child: CircularProgressIndicator())
            else if (_assignments.isEmpty)
              Text('Chưa có phân công nào', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
            else
              ..._assignments.map((a) => _assignmentCard(a)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text('Giao cho thành viên', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.link,
                side: const BorderSide(color: AppColors.link),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _selected!.isRecurring
                  ? _showGenerateAssignSheet(context)
                  : _showAssignSheet(context),
            ),
          ],
        ],
      ),
    ]);
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final member = a['member'] is Map ? a['member'] as Map : {};
    final name = member['displayName']?.toString() ?? 'Thành viên';
    final status = a['status']?.toString() ?? 'PENDING';

    const statusCfg = {
      'PENDING':   (label: 'Chờ',       color: Color(0xFF6B7280)),
      'IN_PROGRESS': (label: 'Đang làm', color: Color(0xFFD97706)),
      'SUBMITTED': (label: 'Đã nộp',    color: AppColors.link),
      'APPROVED':  (label: 'Đã duyệt',  color: AppColors.success),
      'REJECTED':  (label: 'Từ chối',   color: AppColors.danger),
      'CANCELLED': (label: 'Đã hủy',    color: AppColors.textMuted),
    };
    final st = statusCfg[status] ?? (label: status, color: AppColors.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Row(children: [
        AvatarWidget(initial: name.substring(0, 1).toUpperCase(), color: AppColors.avatarBlue, size: 36),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (a['dueAt'] != null)
            Text('Hạn: ${a['dueAt'].toString().substring(0, 10)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: st.color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
          child: Text(st.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: st.color)),
        ),
        const SizedBox(width: 8),
        if (status == 'PENDING' || status == 'IN_PROGRESS')
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
            onSelected: (v) => _handleAssignAction(v, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'cancel', child: Text('Hủy phân công')),
              const PopupMenuItem(value: 'reassign', child: Text('Giao lại')),
            ],
          ),
      ]),
    );
  }

  Future<void> _handleAssignAction(String action, Map<String, dynamic> a) async {
    final assignmentId = a['id']?.toString() ?? '';
    if (assignmentId.isEmpty) return;
    final tp = context.read<TaskProvider>();

    if (action == 'cancel') {
      setState(() => _submitting = true);
      try {
        await tp.cancelAssignment(assignmentId);
        if (_selected != null) await _loadAssignments(_selected!);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else if (action == 'reassign') {
      _showReassignSheet(context, assignmentId);
    }
  }

  void _showAssignSheet(BuildContext context) {
    if (_selected == null) return;
    final members = context.read<FamilyProvider>().members;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _sheetWrap(Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Giao việc: ${_selected!.title}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _fieldLabel('Chọn thành viên'),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Không có thành viên', style: GoogleFonts.inter(color: AppColors.textMuted)),
          )
        else
          ...members.map((m) => Material(
            color: Colors.transparent,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.link.withOpacity(0.15),
                child: Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.link)),
              ),
              title: Text(m.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: Text(_roleLabel(m.familyRole), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await context.read<TaskProvider>().assignTask(_selected!.id, _assignableMemberId(m));
                  if (mounted) { if (_selected != null) _loadAssignments(_selected!); }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
            ),
          )),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showGenerateAssignSheet(BuildContext context) {
    if (_selected == null) return;
    final members = context.read<FamilyProvider>().members;
    final now = DateTime.now();
    String fromDate = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final end = now.add(const Duration(days: 30));
    String toDate = '${end.year}-${end.month.toString().padLeft(2,'0')}-${end.day.toString().padLeft(2,'0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) => _sheetWrap(Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Giao task lặp lại: ${_selected!.title}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Từ ngày'),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: now, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365)));
                if (picked != null) setSheet(() => fromDate = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(border: Border.all(color: AppColors.progressTrack), borderRadius: BorderRadius.circular(10)), child: Text(fromDate, style: GoogleFonts.inter(fontSize: 14))),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Đến ngày'),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: end, firstDate: now, lastDate: now.add(const Duration(days: 365)));
                if (picked != null) setSheet(() => toDate = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(border: Border.all(color: AppColors.progressTrack), borderRadius: BorderRadius.circular(10)), child: Text(toDate, style: GoogleFonts.inter(fontSize: 14))),
            ),
          ])),
        ]),
        const SizedBox(height: 16),
        _fieldLabel('Chọn thành viên'),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Không có thành viên', style: GoogleFonts.inter(color: AppColors.textMuted)))
        else
          ...members.map((m) => Material(
            color: Colors.transparent,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.link.withOpacity(0.15),
                child: Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.link)),
              ),
              title: Text(m.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: Text(_roleLabel(m.familyRole), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await context.read<TaskProvider>().generateAssignments(
                    _selected!.id,
                    memberId: _assignableMemberId(m),
                    fromDate: fromDate,
                    toDate: toDate,
                  );
                  if (mounted) { if (_selected != null) _loadAssignments(_selected!); }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
            ),
          )),
        const SizedBox(height: 8),
      ]))),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'FAMILY_MANAGER': return 'Trưởng nhóm';
      case 'DEPUTY_MEMBER': return 'Phó nhóm';
      default: return 'Thành viên';
    }
  }

  void _showReassignSheet(BuildContext context, String assignmentId) {
    final members = context.read<FamilyProvider>().members;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _sheetWrap(Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Giao lại cho thành viên khác', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _fieldLabel('Chọn thành viên'),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Không có thành viên', style: GoogleFonts.inter(color: AppColors.textMuted)),
          )
        else
          ...members.map((m) => Material(
            color: Colors.transparent,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.link.withOpacity(0.15),
                child: Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.link)),
              ),
              title: Text(m.displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: Text(_roleLabel(m.familyRole), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await context.read<TaskProvider>().reassignTask(assignmentId, newMemberId: _assignableMemberId(m));
                  if (mounted) { if (_selected != null) _loadAssignments(_selected!); }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
            ),
          )),
        const SizedBox(height: 8),
      ])),
    );
  }
}

// ─── Tab: Thưởng ─────────────────────────────────────────────────────────────

class _RewardsTab extends StatefulWidget {
  const _RewardsTab();
  @override
  State<_RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<_RewardsTab> {
  bool _showSettlements = true;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TaskProvider>();
    final settlements = tp.settlements;
    final disputes = tp.disputes;
    final openDisputes = disputes.where((d) => d.status == 'OPEN').length;

    return Column(children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _segBtn('Thưởng (${settlements.length})', _showSettlements, () => setState(() => _showSettlements = true)),
          const SizedBox(width: 8),
          _segBtn('Tranh chấp${openDisputes > 0 ? ' ($openDisputes)' : ''}', !_showSettlements, () => setState(() => _showSettlements = false)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            await tp.fetchSettlements();
            await tp.fetchDisputes();
          },
          child: _showSettlements ? _settlementsList(tp, settlements) : _disputesList(tp, disputes),
        ),
      ),
    ]);
  }

  Widget _settlementsList(TaskProvider tp, List<RewardSettlement> list) {
    if (list.isEmpty) return _emptyState('Chưa có ghi nhận thưởng', '🏆');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: list.map((s) => _settlementCard(tp, s)).toList(),
    );
  }

  Widget _settlementCard(TaskProvider tp, RewardSettlement s) {
    final st = switch (s.status) {
      'PENDING_SETTLEMENT' => (label: 'Chờ trả thưởng', color: const Color(0xFFD97706)),
      'WAITING_CONFIRMATION' => (label: 'Chờ thành viên xác nhận', color: AppColors.link),
      'SETTLED' => (label: 'Đã hoàn tất', color: const Color(0xFF16A34A)),
      'CANCELED' => (label: 'Đã hủy', color: AppColors.textMuted),
      'DISPUTED' => (label: 'Đang tranh chấp', color: AppColors.danger),
      _ => (label: s.status, color: AppColors.textMuted),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.taskTitle.isNotEmpty ? s.taskTitle : 'Task #${s.id.substring(0, 6)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: st.color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
            child: Text(st.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: st.color)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('👤 ${s.memberName.isNotEmpty ? s.memberName : 'Thành viên'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text('💰 ${_fmt(s.amount)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.income)),
        ]),
        if (s.status == 'PENDING_SETTLEMENT') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  try {
                    await tp.markSettlementPaid(s.id, externalMethod: 'CASH');
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('Đã trả thưởng', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  try { await tp.cancelSettlement(s.id); } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('Hủy', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
        if (s.status == 'SETTLED') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
            label: Text('Phân bổ vào quỹ / mục tiêu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.link,
              side: const BorderSide(color: AppColors.link),
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showAllocateSheet(context, tp, s),
          ),
        ],
      ]),
    );
  }

  void _showAllocateSheet(BuildContext context, TaskProvider tp, RewardSettlement s) {
    final amountCtrl = TextEditingController();
    var targetType = 'JAR';
    String? selectedJarId;
    String? selectedGoalId;
    amountCtrl.text = ThousandsSeparatorInputFormatter.formatThousands(s.amount.round().toString());
    context.read<FinanceProvider>().fetchAll();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _sheetWrap(StatefulBuilder(builder: (ctx, set) {
          final finance = ctx.watch<FinanceProvider>();
          final jars = finance.activeJars;
          final goals = finance.goals;
          if (jars.isEmpty) {
            selectedJarId = null;
          } else if (selectedJarId == null || !jars.any((jar) => jar.id == selectedJarId)) {
            selectedJarId = jars.first.id;
          }
          if (goals.isEmpty) {
            selectedGoalId = null;
          } else if (selectedGoalId == null || !goals.any((goal) => goal.id == selectedGoalId)) {
            selectedGoalId = goals.first.id;
          }

          Widget targetButton(String value, String label) {
            final active = targetType == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => set(() => targetType = value),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.link : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AppColors.link : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phân bổ thưởng', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Tổng: ${_fmt(s.amount)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              _fieldLabel('Số tiền phân bổ'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Đây là ghi nhận nội bộ sau khi thành viên đã xác nhận nhận thưởng. App không chuyển tiền thật; chỉ gán khoản thưởng vào hũ tài chính hoặc mục tiêu để báo cáo.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E), height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              _inputBox(amountCtrl, '50.000', money: true),
              const SizedBox(height: 12),
              Row(children: [
                targetButton('JAR', 'Hũ chi tiêu'),
                const SizedBox(width: 8),
                targetButton('GOAL', 'Mục tiêu tiết kiệm'),
              ]),
              const SizedBox(height: 12),
              if (targetType == 'JAR') ...[
                _fieldLabel('Chọn hũ chi tiêu'),
                const SizedBox(height: 6),
                if (jars.isEmpty)
                  Text('Chưa có hũ nào, hãy tạo trước', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
                else
                  DropdownButtonFormField<String>(
                    value: selectedJarId,
                    items: jars
                        .map((jar) => DropdownMenuItem(
                              value: jar.id,
                              child: Text('${jar.name} (${jar.allocationPercentage.round()}%)'),
                            ))
                        .toList(),
                    onChanged: (value) => set(() => selectedJarId = value),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
              ] else ...[
                _fieldLabel('Chọn mục tiêu tiết kiệm'),
                const SizedBox(height: 6),
                if (goals.isEmpty)
                  Text('Chưa có mục tiêu nào, hãy tạo trước', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
                else
                  DropdownButtonFormField<String>(
                    value: selectedGoalId,
                    items: goals
                        .map((goal) => DropdownMenuItem(
                              value: goal.id,
                              child: Text(goal.goalName),
                            ))
                        .toList(),
                    onChanged: (value) => set(() => selectedGoalId = value),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  final amount = parseMoneyInput(amountCtrl.text);
                  if (amount <= 0) return;
                  final alloc = <String, dynamic>{'amount': amount};
                  if (targetType == 'JAR') {
                    if (selectedJarId == null) return;
                    alloc['jarId'] = selectedJarId;
                  } else {
                    if (selectedGoalId == null) return;
                    alloc['goalId'] = selectedGoalId;
                  }
                  try {
                    await tp.allocateSettlement(s.id, allocations: [alloc]);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('Phân bổ', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          );
        })),
      ),
    );
  }

  Widget _disputesList(TaskProvider tp, List<RewardDispute> list) {
    if (list.isEmpty) return _emptyState('Không có tranh chấp nào', '✅');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: list.map((d) => _disputeCard(tp, d)).toList(),
    );
  }

  Widget _disputeCard(TaskProvider tp, RewardDispute d) {
    final isOpen = d.status == 'OPEN';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Tranh chấp #${d.id.substring(0, 6)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (isOpen ? AppColors.danger : AppColors.success).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
            child: Text(isOpen ? 'Chờ xử lý' : 'Đã xử lý', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isOpen ? AppColors.danger : AppColors.success)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('👤 ${d.reporterName.isNotEmpty ? d.reporterName : 'Thành viên'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Lý do: ${d.reason}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        if (isOpen) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  try { await tp.resolveDispute(d.id, action: 'ACCEPT_DISPUTE'); } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('Xác nhận trả', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted, side: const BorderSide(color: Color(0xFFE5E7EB)), minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  try { await tp.resolveDispute(d.id, action: 'REJECT_DISPUTE'); } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                },
                child: Text('Bác bỏ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.link : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
            ),
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );

  String _fmt(double n) => '${n.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';
}

// ─── Tab: Không thể làm ───────────────────────────────────────────────────────

class _UnavailabilityTab extends StatefulWidget {
  const _UnavailabilityTab();
  @override
  State<_UnavailabilityTab> createState() => _UnavailabilityTabState();
}

class _UnavailabilityTabState extends State<_UnavailabilityTab> {
  @override
  Widget build(BuildContext context) {
    final unavails = context.watch<TaskProvider>().unavailabilities;
    final pending = unavails.where((u) => u.status == 'PENDING').toList();
    final handled = unavails.where((u) => u.status != 'PENDING').toList();

    return RefreshIndicator(
      onRefresh: () => context.read<TaskProvider>().fetchUnavailabilities(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          if (pending.isNotEmpty) ...[
            Text('Chờ xử lý (${pending.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
            const SizedBox(height: 8),
            ...pending.map((u) => _card(u)),
          ],
          if (handled.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Đã xử lý', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            ...handled.map((u) => _card(u, showActions: false)),
          ],
          if (unavails.isEmpty) _emptyState('Không có báo cáo nào', '👍'),
        ],
      ),
    );
  }

  Widget _card(TaskUnavailability u, {bool showActions = true}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(u.taskTitle.isNotEmpty ? u.taskTitle : 'Công việc', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (u.status == 'PENDING' ? AppColors.danger : AppColors.textMuted).withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(u.status == 'PENDING' ? 'Chờ xử lý' : u.status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: u.status == 'PENDING' ? AppColors.danger : AppColors.textMuted)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('👤 ${u.memberName.isNotEmpty ? u.memberName : 'Thành viên'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Lý do: ${u.reason}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          if (showActions && u.status == 'PENDING') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _handleAction(u, 'MARK_HANDLED'),
                  child: Text('Đã xử lý', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _handleAction(u, 'CANCEL_ASSIGNMENT'),
                  child: Text('Hủy phân công', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ]),
      );

  Future<void> _handleAction(TaskUnavailability u, String action) async {
    try {
      await context.read<TaskProvider>().handleUnavailability(u.id, action: action);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    }
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

Widget _emptyState(String msg, String emoji) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(msg, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
      ]),
    );

Widget _fieldLabel(String label) =>
    Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary));

Widget _inputBox(TextEditingController ctrl, String hint, {int maxLines = 1, bool money = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: money ? TextInputType.number : null,
        inputFormatters: money ? const [ThousandsSeparatorInputFormatter()] : null,
        decoration: InputDecoration(hintText: hint, suffixText: money ? '₫' : null, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      ),
    );

Widget _sheetWrap(Widget child) => Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: child,
    );

class _BottomSheetOverlay extends StatelessWidget {
  final Widget child;
  const _BottomSheetOverlay({required this.child});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: GestureDetector(
          onTap: () {},
          child: Column(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
            ),
            _sheetWrap(child),
          ]),
        ),
      );
}
