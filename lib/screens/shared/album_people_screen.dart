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
  final Map<String, Future<List<AlbumMedia>>> _photoFutures = {};
  Future<List<_AlbumMemberPreview>>? _previewFuture;
  String? _previewKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FamilyProvider>().fetchMembers();
    });
  }

  Future<List<AlbumMedia>> _photosFor(String memberId) {
    return _photoFutures.putIfAbsent(
      memberId,
      () => context.read<AlbumProvider>().fetchTaggedMedia(memberId),
    );
  }

  Future<void> _refreshPeople() async {
    setState(() {
      _photoFutures.clear();
      _previewFuture = null;
      _previewKey = null;
    });
    await context.read<FamilyProvider>().fetchMembers();
  }

  Future<List<_AlbumMemberPreview>> _previewsFor(List<FamilyMember> members) {
    final key = members.map((m) => m.id).join('|');
    if (_previewFuture != null && _previewKey == key) return _previewFuture!;
    _previewKey = key;
    _previewFuture =
        Future.wait(
          members.map((member) async {
            try {
              return _AlbumMemberPreview(
                member: member,
                photos: await _photosFor(member.id),
              );
            } catch (_) {
              return _AlbumMemberPreview(member: member, photos: const []);
            }
          }),
        ).then((previews) {
          previews.sort((a, b) {
            final byCount = b.photos.length.compareTo(a.photos.length);
            if (byCount != 0) return byCount;
            return a.name.compareTo(b.name);
          });
          return previews;
        });
    return _previewFuture!;
  }

  String _countLabel(int count) => count >= 100 ? '99+ ảnh' : '$count ảnh';

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
      body: RefreshIndicator(
        onRefresh: _refreshPeople,
        child: members.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 220),
                  Center(
                    child: Text(
                      'Chưa có thành viên nào.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              )
            : FutureBuilder<List<_AlbumMemberPreview>>(
                future: _previewsFor(members),
                builder: (_, snap) {
                  final previews = snap.data ?? const <_AlbumMemberPreview>[];
                  if (snap.connectionState != ConnectionState.done &&
                      previews.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 220),
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: previews.length,
                    itemBuilder: (_, i) => _memberTile(previews[i]),
                  );
                },
              ),
      ),
    );
  }

  Widget _memberTile(_AlbumMemberPreview preview) {
    final member = preview.member;
    final photos = preview.photos;
    final cover = photos.isEmpty ? null : photos.first;
    final name = preview.name;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlbumMemberPhotosScreen(
            memberId: member.id,
            memberName: member.name,
          ),
        ),
      ),
      child: Column(
        children: [
          _memberCover(member, cover, ConnectionState.done),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _countLabel(photos.length),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCover(
    FamilyMember member,
    AlbumMedia? cover,
    ConnectionState state,
  ) {
    return SizedBox.square(
      dimension: 78,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: cover == null
                ? AvatarWidget(
                    initial: member.avatarInitials,
                    color: Color(member.avatarColor),
                    size: 78,
                  )
                : AlbumMediaThumb(media: cover),
          ),
          if (state != ConnectionState.done)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 18,
                height: 18,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumMemberPreview {
  const _AlbumMemberPreview({required this.member, required this.photos});

  final FamilyMember member;
  final List<AlbumMedia> photos;

  String get name => member.name.isEmpty ? 'Thành viên' : member.name;
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

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await context.read<AlbumProvider>().fetchTaggedMedia(
        widget.memberId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
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

  Future<void> _refresh() => _load(showSpinner: false);

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
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 220),
                        Center(
                          child: Text(
                            'Không tải được ảnh.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 220),
                        Center(
                          child: Text(
                            'Chưa có ảnh nào gắn thẻ ${widget.memberName}.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
            ),
    );
  }
}
