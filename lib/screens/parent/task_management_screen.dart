import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

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
  bool _showCreate = false;
  bool _submitting = false;
  final _titleCtrl = TextEditingController();

  static const _statusCfg = {
    'TODO':      (label: 'Chờ làm',    bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    'DOING':     (label: 'Đang làm',   bg: Color(0xFFFEF3C7), color: Color(0xFFD97706)),
    'SUBMITTED': (label: 'Chờ duyệt',  bg: Color(0xFFEFF6FF), color: AppColors.planned),
    'DONE':      (label: 'Hoàn thành', bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    'REJECTED':  (label: 'Từ chối',    bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  List<TaskItem> _filtered(List<TaskItem> tasks) =>
      _filter == null ? tasks : tasks.where((t) => t.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final tasks = taskState.tasks;
    final submitted = tasks.where((t) => t.status == 'SUBMITTED').length;

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
                  _summaryCard(submitted, 'Chờ duyệt', AppColors.link),
                  const SizedBox(width: 12),
                  _summaryCard(tasks.where((t) => t.status == 'DONE').length, 'Xong', AppColors.success),
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
                    _filterChip('SUBMITTED', 'Chờ duyệt', badge: submitted),
                    _filterChip('DOING', 'Đang làm'),
                    _filterChip('DONE', 'Hoàn thành'),
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
                        final st = _statusCfg[task.status] ?? _statusCfg['TODO']!;
                        return GestureDetector(
                          onTap: () => task.status == 'SUBMITTED'
                              ? setState(() => _approveTask = task)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                            ),
                            child: Row(children: [
                              Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(color: AppColors.planned, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          child: FloatingActionButton(
            backgroundColor: AppColors.link,
            onPressed: () => setState(() => _showCreate = true),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        if (_approveTask != null)
          _BottomSheetOverlay(child: _approveSheet(context)),
        if (_showCreate)
          _BottomSheetOverlay(child: _createSheet(context)),
      ],
    );
  }

  Widget _approveSheet(BuildContext context) {
    final t = _approveTask!;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Duyệt task', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
              try {
                await context.read<TaskProvider>().reviewSubmission(
                  t.assignmentId.isNotEmpty ? t.assignmentId : t.id,
                  approved: true,
                );
                if (mounted) setState(() { _approveTask = null; _submitting = false; });
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _submitting ? null : () async {
              setState(() => _submitting = true);
              try {
                await context.read<TaskProvider>().reviewSubmission(
                  t.assignmentId.isNotEmpty ? t.assignmentId : t.id,
                  approved: false,
                );
                if (mounted) setState(() { _approveTask = null; _submitting = false; });
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
      const SizedBox(height: 20),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: _submitting ? null : () async {
          if (_titleCtrl.text.isEmpty) return;
          setState(() => _submitting = true);
          try {
            await context.read<TaskProvider>().createTask(title: _titleCtrl.text.trim());
            if (mounted) {
              _titleCtrl.clear();
              setState(() { _showCreate = false; _submitting = false; });
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
              onPressed: () => _showAssignSheet(context),
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
    final memberIdCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _sheetWrap(Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Giao việc: ${_selected!.title}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _fieldLabel('ID thành viên'),
          const SizedBox(height: 6),
          _inputBox(memberIdCtrl, 'UUID của thành viên...'),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              if (memberIdCtrl.text.trim().isEmpty) return;
              try {
                await context.read<TaskProvider>().assignTask(_selected!.id, memberIdCtrl.text.trim());
                if (mounted) { Navigator.pop(context); if (_selected != null) _loadAssignments(_selected!); }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            child: Text('Giao việc', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ])),
      ),
    );
  }

  void _showReassignSheet(BuildContext context, String assignmentId) {
    final memberIdCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _sheetWrap(Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Giao lại cho thành viên khác', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _fieldLabel('ID thành viên mới'),
          const SizedBox(height: 6),
          _inputBox(memberIdCtrl, 'UUID của thành viên...'),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              if (memberIdCtrl.text.trim().isEmpty) return;
              try {
                await context.read<TaskProvider>().reassignTask(assignmentId, newMemberId: memberIdCtrl.text.trim());
                if (mounted) { Navigator.pop(context); if (_selected != null) _loadAssignments(_selected!); }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            child: Text('Giao lại', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ])),
      ),
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
    const statusCfg = {
      'PENDING':          (label: 'Chờ trả',       color: Color(0xFFD97706)),
      'PAID':             (label: 'Đã trả',         color: AppColors.success),
      'CONFIRMED':        (label: 'Đã nhận',        color: Color(0xFF16A34A)),
      'CANCELLED':        (label: 'Đã hủy',         color: AppColors.textMuted),
      'DISPUTED':         (label: 'Tranh chấp',     color: AppColors.danger),
    };
    final st = statusCfg[s.status] ?? (label: s.status, color: AppColors.textMuted);

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
        if (s.status == 'PENDING') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  try { await tp.markSettlementPaid(s.id); } catch (e) {
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
      ]),
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
                  try { await tp.resolveDispute(d.id, action: 'APPROVE'); } catch (e) {
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
                  try { await tp.resolveDispute(d.id, action: 'REJECT'); } catch (e) {
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

Widget _inputBox(TextEditingController ctrl, String hint, {int maxLines = 1}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)),
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
