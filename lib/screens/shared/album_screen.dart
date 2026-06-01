import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  int _tab = 0;

  final _albums = [
    (name: 'Dã ngoại tháng 5 🏕️', count: 24, color: AppColors.income, emoji: '🏕️'),
    (name: 'Sinh nhật Mẹ 🎂', count: 18, color: AppColors.shared, emoji: '🎂'),
    (name: 'Ngày gia đình 👨‍👩‍👧', count: 32, color: AppColors.planned, emoji: '👨‍👩‍👧'),
    (name: 'Tết Nguyên Đán', count: 45, color: AppColors.avatarOrange, emoji: '🧧'),
    (name: 'Đi học 📚', count: 12, color: AppColors.safe, emoji: '📚'),
    (name: 'Ảnh ngẫu nhiên', count: 88, color: AppColors.avatarTeal, emoji: '📷'),
  ];

  final _colors = [
    const Color(0xFFFFE4E1), const Color(0xFFE0F2FE), const Color(0xFFF0FDF4),
    const Color(0xFFFEF9C3), const Color(0xFFEDE9FE), const Color(0xFFFFEDD5),
    const Color(0xFFFCE7F3), const Color(0xFFDCFCE7), const Color(0xFFEFF6FF),
    const Color(0xFFF3F4F6), const Color(0xFFFEF3C7), const Color(0xFFE0E7FF),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Text('📸 Album', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]), alignment: Alignment.center, child: const Icon(Icons.add_rounded, color: AppColors.link, size: 20)),
              ),
            ]),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _tabBtn(0, 'Album'),
              const SizedBox(width: 8),
              _tabBtn(1, 'Ảnh gần đây'),
            ]),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _tab == 0 ? _albumsGrid() : _photosGrid(),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.link,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
      ),
    );
  }

  Widget _tabBtn(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.link : AppColors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _albumsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.0, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final a = _albums[i];
        return GestureDetector(
          onTap: () => setState(() => _tab = 1),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: a.color.withOpacity(0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  alignment: Alignment.center,
                  child: Text(a.emoji, style: const TextStyle(fontSize: 48)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${a.count} ảnh', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _photosGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.0, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: _colors.length,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(color: _colors[i], borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(['🏕️', '🎂', '👨‍👩‍👧', '🧧', '📚', '📷', '🌸', '🎉', '🏖️', '🌳', '🎊', '🤸'][i], style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}
