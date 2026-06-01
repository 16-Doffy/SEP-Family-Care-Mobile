import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

enum TaskStatus { todo, doing, submitted, done, rejected }

class _Task {
  final String id, title, assignee, category;
  final Color assigneeColor, categoryColor;
  final int xp, reward;
  TaskStatus status;
  _Task({required this.id, required this.title, required this.assignee, required this.assigneeColor, required this.xp, required this.reward, required this.status, required this.category, required this.categoryColor});
}

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});
  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _tasks = [
    _Task(id:'1', title:'Dọn phòng ngủ', assignee:'AN', assigneeColor:AppColors.avatarOrange, xp:50, reward:20000, status:TaskStatus.submitted, category:'Nhà cửa', categoryColor:AppColors.planned),
    _Task(id:'2', title:'Rửa bát sau bữa tối', assignee:'BI', assigneeColor:AppColors.avatarPurple, xp:30, reward:10000, status:TaskStatus.doing, category:'Nhà cửa', categoryColor:AppColors.planned),
    _Task(id:'3', title:'Tưới cây', assignee:'AN', assigneeColor:AppColors.avatarOrange, xp:20, reward:5000, status:TaskStatus.todo, category:'Vườn', categoryColor:AppColors.safe),
    _Task(id:'4', title:'Học bài 1 tiếng', assignee:'BI', assigneeColor:AppColors.avatarPurple, xp:80, reward:30000, status:TaskStatus.done, category:'Học tập', categoryColor:const Color(0xFFF59E0B)),
    _Task(id:'5', title:'Gấp quần áo', assignee:'AN', assigneeColor:AppColors.avatarOrange, xp:25, reward:8000, status:TaskStatus.todo, category:'Nhà cửa', categoryColor:AppColors.planned),
  ];

  TaskStatus? _filter;
  _Task? _approveTask;
  bool _showCreate = false;
  final _titleCtrl = TextEditingController();
  String _newAssignee = 'AN';

  List<_Task> get _filtered => _filter == null ? _tasks : _tasks.where((t) => t.status == _filter).toList();
  int get _submitted => _tasks.where((t) => t.status == TaskStatus.submitted).length;

  static const _statusCfg = {
    TaskStatus.todo:      (label: 'Chờ làm',   bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
    TaskStatus.doing:     (label: 'Đang làm',  bg: Color(0xFFFEF3C7), color: Color(0xFFD97706)),
    TaskStatus.submitted: (label: 'Chờ duyệt', bg: Color(0xFFEFF6FF), color: AppColors.planned),
    TaskStatus.done:      (label: 'Hoàn thành',bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
    TaskStatus.rejected:  (label: 'Từ chối',   bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)]), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary))),
                  const Expanded(child: Center(child: Text('Quản lý Tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
                  GestureDetector(onTap: () => setState(() => _showCreate = true), child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.link), child: const Icon(Icons.add, color: Colors.white))),
                ],
              ),
            ),

            // Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _summaryCard(_tasks.length, 'Tổng', AppColors.textPrimary),
                  const SizedBox(width: 12),
                  _summaryCard(_submitted, 'Chờ duyệt', AppColors.link),
                  const SizedBox(width: 12),
                  _summaryCard(_tasks.where((t) => t.status == TaskStatus.done).length, 'Xong', AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _filterChip(null, 'Tất cả'),
                  _filterChip(TaskStatus.submitted, 'Chờ duyệt', badge: _submitted),
                  _filterChip(TaskStatus.doing, 'Đang làm'),
                  _filterChip(TaskStatus.done, 'Hoàn thành'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ..._filtered.map((task) {
                    final st = _statusCfg[task.status]!;
                    return GestureDetector(
                      onTap: () => task.status == TaskStatus.submitted ? setState(() => _approveTask = task) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                        child: Row(
                          children: [
                            Container(width: 4, height: 60, decoration: BoxDecoration(color: task.categoryColor, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                    if (task.status == TaskStatus.submitted) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)), child: Text('DUYỆT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.planned))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, children: [
                                    _chip(st.label, st.bg, st.color),
                                    _chip('⚡ ${task.xp} XP', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                                    _chip('💰 ${(task.reward / 1000).toStringAsFixed(0)}K', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AvatarWidget(initial: task.assignee, color: task.assigneeColor, size: 36),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),

      // Approve modal
      bottomSheet: _approveTask != null ? _approveSheet() : (_showCreate ? _createSheet() : null),
    );
  }

  Widget _approveSheet() {
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
            Text('👤 ${t.assignee == "AN" ? "An" : "Bi"}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Text('⚡ ${t.xp} XP', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Text('💰 ${(t.reward / 1000).toStringAsFixed(0)}K ₫', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () { setState(() { t.status = TaskStatus.done; _approveTask = null; }); }, child: Text('✓  Duyệt', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () { setState(() { t.status = TaskStatus.rejected; _approveTask = null; }); }, child: Text('✕  Từ chối', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
          ]),
          TextButton(onPressed: () => setState(() => _approveTask = null), child: Center(child: Text('Xem lại sau', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted)))),
        ],
      ),
    );
  }

  Widget _createSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📋  Tạo task mới', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text('Tên task', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5), borderRadius: BorderRadius.circular(14)),
            child: TextField(controller: _titleCtrl, decoration: InputDecoration(hintText: 'VD: Dọn phòng khách', border: InputBorder.none, hintStyle: GoogleFonts.inter(color: AppColors.textMuted)), style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 16),
          Text('Giao cho', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: ['AN', 'BI'].map((n) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _newAssignee = n),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _newAssignee == n ? AppColors.link : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(n == 'AN' ? 'An' : 'Bi', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _newAssignee == n ? Colors.white : AppColors.textPrimary)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () {
              if (_titleCtrl.text.isEmpty) return;
              setState(() {
                _tasks.insert(0, _Task(id: DateTime.now().millisecondsSinceEpoch.toString(), title: _titleCtrl.text, assignee: _newAssignee, assigneeColor: _newAssignee == 'AN' ? AppColors.avatarOrange : AppColors.avatarPurple, xp: 50, reward: 20000, status: TaskStatus.todo, category: 'Nhà cửa', categoryColor: AppColors.planned));
                _titleCtrl.clear();
                _showCreate = false;
              });
            },
            child: Text('Tạo task', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          TextButton(onPressed: () => setState(() => _showCreate = false), child: Center(child: Text('Hủy', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted)))),
        ],
      ),
    );
  }

  Widget _summaryCard(int val, String label, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]), child: Column(children: [
      Text('$val', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
    ])));
  }

  Widget _filterChip(TaskStatus? status, String label, {int badge = 0}) {
    final active = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.fromLTRB(14, 0, badge > 0 ? 4 : 14, 0),
        height: 40,
        decoration: BoxDecoration(color: active ? AppColors.link : AppColors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))]),
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

  Widget _chip(String label, Color bg, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
  }
}
