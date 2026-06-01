import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class _Task {
  final String id, title, category, reward, due;
  final int xp;
  String status; // pending | submitted | approved | rejected
  _Task({required this.id, required this.title, required this.category, required this.reward, required this.due, required this.xp, this.status = 'pending'});
}

class ChildTasksScreen extends StatefulWidget {
  const ChildTasksScreen({super.key});
  @override
  State<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends State<ChildTasksScreen> {
  final _tasks = [
    _Task(id:'1', title:'Dọn phòng ngủ', category:'Nhà cửa', reward:'20,000 ₫', due:'Hôm nay', xp:50),
    _Task(id:'2', title:'Làm bài tập toán trang 45-48', category:'Học tập', reward:'30,000 ₫', due:'Hôm nay', xp:80),
    _Task(id:'3', title:'Tưới cây trong nhà', category:'Nhà cửa', reward:'10,000 ₫', due:'Ngày mai', xp:30),
    _Task(id:'4', title:'Đọc sách 30 phút', category:'Học tập', reward:'15,000 ₫', due:'Ngày mai', xp:40),
    _Task(id:'5', title:'Rửa chén sau bữa tối', category:'Nhà cửa', reward:'20,000 ₫', due:'Tối nay', xp:50, status:'submitted'),
    _Task(id:'6', title:'Ôn bài kiểm tra cuối tuần', category:'Học tập', reward:'50,000 ₫', due:'Thứ 7', xp:120, status:'approved'),
  ];

  String _filter = 'Tất cả';
  final _filters = ['Tất cả', 'Chờ làm', 'Đã nộp', 'Hoàn thành'];

  List<_Task> get _filtered {
    switch (_filter) {
      case 'Chờ làm': return _tasks.where((t) => t.status == 'pending').toList();
      case 'Đã nộp': return _tasks.where((t) => t.status == 'submitted').toList();
      case 'Hoàn thành': return _tasks.where((t) => t.status == 'approved').toList();
      default: return _tasks;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'submitted': return AppColors.planned;
      case 'approved': return AppColors.safe;
      case 'rejected': return AppColors.sos;
      default: return AppColors.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'submitted': return '⏳ Chờ duyệt';
      case 'approved': return '✅ Hoàn thành';
      case 'rejected': return '❌ Từ chối';
      default: return '🔵 Chờ làm';
    }
  }

  String _catIcon(String cat) => cat == 'Học tập' ? '📚' : '🏠';

  @override
  Widget build(BuildContext context) {
    final done = _tasks.where((t) => t.status == 'approved').length;
    final total = _tasks.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Text('📋 Nhiệm vụ', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.safe.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('$done/$total hoàn thành', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.safe)),
              ),
            ]),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.safe),
                ),
              ),
              const SizedBox(height: 6),
              Text('Tiến độ: ${(done / total * 100).round()}% · ${total - done} việc còn lại', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: 12),

          // Filter chips
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

          // Task list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final t = _filtered[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(_catIcon(t.category), style: const TextStyle(fontSize: 24))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(t.category, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                            Text('Hạn: ${t.due}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.income.withOpacity(0.1), borderRadius: BorderRadius.circular(999)), child: Text(t.reward, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.income))),
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.planned.withOpacity(0.1), borderRadius: BorderRadius.circular(999)), child: Text('+${t.xp} XP', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.planned))),
                          ]),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(t.status).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                          child: Text(_statusLabel(t.status), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(t.status))),
                        ),
                      ]),
                    ),
                    if (t.status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                        child: SizedBox(
                          width: double.infinity, height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () => _submitTask(t),
                            child: Text('Nộp nhiệm vụ ✅', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _submitTask(_Task t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Nộp nhiệm vụ', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(t.title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Thêm ghi chú cho Ba/Mẹ...',
              hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.safe, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                setState(() => t.status = 'submitted');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã nộp! Chờ Ba/Mẹ duyệt nhé 🎉'), backgroundColor: AppColors.safe));
              },
              child: Text('Xác nhận nộp', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
