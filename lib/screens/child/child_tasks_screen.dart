import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';

// ── Local demo model (vẫn giữ khi API chưa sẵn sàng) ──────────────────────
class _Task {
  final String id;
  final String title;
  final String category;
  final String reward;
  final String due;
  final int xp;
  final bool isRecurring; // UC39 — task định kỳ
  final String? schedule; // "07:00–07:30 hàng ngày"
  String status; // pending | submitted | approved | rejected | unavailable

  _Task({
    required this.id,
    required this.title,
    required this.category,
    required this.reward,
    required this.due,
    required this.xp,
    this.isRecurring = false,
    this.schedule,
    this.status = 'pending',
  });
}

class ChildTasksScreen extends StatefulWidget {
  const ChildTasksScreen({super.key});
  @override
  State<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends State<ChildTasksScreen> {
  final _tasks = [
    _Task(
        id: '1',
        title: 'Dọn phòng ngủ',
        category: 'Nhà cửa',
        reward: '20,000 ₫',
        due: 'Hôm nay',
        xp: 50),
    _Task(
        id: '2',
        title: 'Làm bài tập toán trang 45-48',
        category: 'Học tập',
        reward: '30,000 ₫',
        due: 'Hôm nay',
        xp: 80),
    // UC39 — Task định kỳ
    _Task(
        id: '3',
        title: 'Đổ rác buổi sáng',
        category: 'Nhà cửa',
        reward: '10,000 ₫',
        due: 'Hôm nay 06:30',
        xp: 30,
        isRecurring: true,
        schedule: '06:30 – 06:45 mỗi ngày'),
    _Task(
        id: '4',
        title: 'Đọc sách 30 phút',
        category: 'Học tập',
        reward: '15,000 ₫',
        due: 'Ngày mai',
        xp: 40),
    _Task(
        id: '5',
        title: 'Rửa chén sau bữa tối',
        category: 'Nhà cửa',
        reward: '20,000 ₫',
        due: 'Tối nay',
        xp: 50,
        isRecurring: true,
        schedule: '19:00 – 19:30 mỗi tối',
        status: 'submitted'),
    _Task(
        id: '6',
        title: 'Ôn bài kiểm tra cuối tuần',
        category: 'Học tập',
        reward: '50,000 ₫',
        due: 'Thứ 7',
        xp: 120,
        status: 'approved'),
  ];

  String _filter = 'Tất cả';
  final _filters = ['Tất cả', 'Chờ làm', 'Đã nộp', 'Hoàn thành'];

  List<_Task> get _filtered {
    switch (_filter) {
      case 'Chờ làm':
        return _tasks.where((t) => t.status == 'pending').toList();
      case 'Đã nộp':
        return _tasks.where((t) => t.status == 'submitted').toList();
      case 'Hoàn thành':
        return _tasks.where((t) => t.status == 'approved').toList();
      default:
        return _tasks;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'submitted':
        return AppColors.planned;
      case 'approved':
        return AppColors.safe;
      case 'rejected':
        return AppColors.sos;
      case 'unavailable':
        return const Color(0xFFEA580C);
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'submitted':
        return '⏳ Chờ duyệt';
      case 'approved':
        return '✅ Hoàn thành';
      case 'rejected':
        return '❌ Từ chối';
      case 'unavailable':
        return '🚫 Đã báo bận';
      default:
        return '🔵 Chờ làm';
    }
  }

  String _catIcon(String cat) => cat == 'Học tập' ? '📚' : '🏠';

  @override
  Widget build(BuildContext context) {
    final done  = _tasks.where((t) => t.status == 'approved').length;
    final total = _tasks.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Text('📋 Nhiệm vụ',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
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

          // ── Progress bar ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.safe),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'Tiến độ: ${total > 0 ? (done / total * 100).round() : 0}% · ${total - done} việc còn lại',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Filter chips ───────────────────────────────────────
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

          // ── Task list ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final t = _filtered[i];
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
                      ]),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: Text(_catIcon(t.category),
                                  style: const TextStyle(fontSize: 24)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title + recurring badge
                                    Row(children: [
                                      Expanded(
                                        child: Text(t.title,
                                            style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary)),
                                      ),
                                      if (t.isRecurring)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFF0F9FF),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text('🔁 Định kỳ',
                                              style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                      0xFF0369A1))),
                                        ),
                                    ]),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Text(t.category,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textMuted)),
                                      const Text(' · ',
                                          style: TextStyle(
                                              color: AppColors.textMuted)),
                                      Text('Hạn: ${t.due}',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textMuted)),
                                    ]),
                                    // Khung giờ nếu là recurring
                                    if (t.isRecurring && t.schedule != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('⏰ ${t.schedule}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF0369A1))),
                                      ),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 6, children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: AppColors.income
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999)),
                                          child: Text(t.reward,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.income))),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: AppColors.planned
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999)),
                                          child: Text('+${t.xp} XP',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.planned))),
                                    ]),
                                  ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color:
                                      _statusColor(t.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999)),
                              child: Text(_statusLabel(t.status),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(t.status))),
                            ),
                          ]),
                    ),

                    // ── Action buttons ─────────────────────────────
                    if (t.status == 'pending') ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(children: [
                          // Nộp nhiệm vụ
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.link,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                onPressed: () => _submitTask(t),
                                child: Text('Nộp nhiệm vụ ✅',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                          // UC41 — "Không thể làm" chỉ cho recurring tasks
                          if (t.isRecurring) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFFEA580C), width: 1.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10))),
                                  onPressed: () => _reportUnavailable(t),
                                  child: Text('🚫 Bận',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFEA580C))),
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ],

                    // Từ chối → hiện thông báo để sửa
                    if (t.status == 'rejected')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Text('❌',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'Ba/Mẹ đã từ chối. Hãy thực hiện lại và nộp mới.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF991B1B))),
                            ),
                            GestureDetector(
                              onTap: () => _submitTask(t),
                              child: Text('Nộp lại →',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626))),
                            ),
                          ]),
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

  // ── Nộp nhiệm vụ ──────────────────────────────────────────────────────────
  void _submitTask(_Task t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Nộp nhiệm vụ',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(t.title,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Thêm ghi chú cho Ba/Mẹ...',
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
                  backgroundColor: AppColors.safe,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                setState(() => t.status = 'submitted');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã nộp! Chờ Ba/Mẹ duyệt nhé 🎉'),
                    backgroundColor: AppColors.safe));
              },
              child: Text('Xác nhận nộp',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── UC41 — Báo cáo không thể thực hiện task định kỳ ─────────────────────
  void _reportUnavailable(_Task t) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon cảnh báo
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(28)),
              alignment: Alignment.center,
              child:
                  const Text('🚫', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 12),
            Text('Báo cáo không thể thực hiện',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(t.title,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            if (t.schedule != null)
              Text('⏰ ${t.schedule}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF0369A1))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Text('ℹ️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Hệ thống sẽ thông báo cho các thành viên khác. Ba/Mẹ sẽ phân công lại nếu không ai nhận.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF92400E))),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Lý do (VD: Con bị ốm, Con đang có việc khác...)',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE5E7EB), width: 1.5),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    // Gọi API nếu task đến từ real provider
                    // (hiện tại vẫn dùng local state)
                    setState(() => t.status = 'unavailable');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            '✅ Đã báo. Ba/Mẹ sẽ phân công lại cho người khác.'),
                        backgroundColor: const Color(0xFFEA580C),
                        action: SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  child: Text('Xác nhận báo bận',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
