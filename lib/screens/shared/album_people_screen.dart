import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/album_media.dart';
import '../../providers/album_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'album_screen.dart' show AlbumMediaThumb;

/// "Mọi người" — chia album theo từng thành viên (tham khảo Google Photos).
///
/// Lưới avatar thành viên; chạm một người → xem tất cả ảnh có gắn thẻ người đó
/// (BE filter `taggedMemberId`). Thẻ được tạo khi xác nhận gợi ý khuôn mặt hoặc
/// gắn thủ công.
class AlbumPeopleScreen extends StatefulWidget {
  const AlbumPeopleScreen({super.key});

  @override
  State<AlbumPeopleScreen> createState() => _AlbumPeopleScreenState();
}

class _AlbumPeopleScreenState extends State<AlbumPeopleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FamilyProvider>().fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = context
        .watch<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Mọi người',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: members.isEmpty
          ? Center(
              child: Text(
                'Chưa có thành viên nào.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 0.8,
              ),
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlbumMemberPhotosScreen(
                        memberId: m.id,
                        memberName: m.name,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      AvatarWidget(
                        initial: m.avatarInitials,
                        color: Color(m.avatarColor),
                        size: 78,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m.name.isEmpty ? 'Thành viên' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Ảnh có gắn thẻ một thành viên.
class AlbumMemberPhotosScreen extends StatefulWidget {
  const AlbumMemberPhotosScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  final String memberId;
  final String memberName;

  @override
  State<AlbumMemberPhotosScreen> createState() =>
      _AlbumMemberPhotosScreenState();
}

class _AlbumMemberPhotosScreenState extends State<AlbumMemberPhotosScreen> {
  List<AlbumMedia> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final list = await context.read<AlbumProvider>().fetchTaggedMedia(
        widget.memberId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _viewImage(AlbumMedia media) async {
    // List không ký URL → resolve signed URL (cache dùng lại của thumbnail).
    final url = media.displayUrl.isNotEmpty
        ? media.displayUrl
        : (await context.read<AlbumProvider>().resolveDisplayUrl(media) ?? '');
    if (url.isEmpty || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url))),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          widget.memberName.isEmpty ? 'Ảnh thành viên' : widget.memberName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Không tải được ảnh.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                'Chưa có ảnh nào gắn thẻ ${widget.memberName}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final media = _items[i];
                return GestureDetector(
                  onTap: () => _viewImage(media),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AlbumMediaThumb(media: media),
                  ),
                );
              },
            ),
    );
  }
}
