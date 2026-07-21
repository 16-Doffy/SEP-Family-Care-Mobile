import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/album_media.dart';
import '../../models/user.dart';
import '../../providers/album_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlbumProvider>().fetchMedia();
      context.read<FamilyProvider>().fetchMembers();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final album = context.read<AlbumProvider>();
      if (album.hasPendingItems) album.fetchMedia(refresh: true);
    });
  }

  void _snack(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source, {required bool video}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    _showUploadSheet(file);
  }

  void _showUploadSheet(XFile file) {
    final captionCtrl = TextEditingController();
    var scope = AlbumVisibilityScope.family;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tải media lên album',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: captionCtrl,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Caption',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AlbumVisibilityScope>(
                initialValue: scope,
                decoration: InputDecoration(
                  labelText: 'Quyền xem',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: AlbumVisibilityScope.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(_scopeLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setS(() => scope = v ?? AlbumVisibilityScope.family),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white,
                  ),
                  label: const Text('Upload'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<AlbumProvider>().uploadMedia(
                        filePath: file.path,
                        caption: captionCtrl.text,
                        visibilityScope: scope,
                      );
                    } catch (e) {
                      _snack(e);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery, video: false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_library_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Chọn video từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery, video: true);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera, video: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final album = context.watch<AlbumProvider>();
    // Current manual moderation contract is FAMILY_MANAGER only.
    final isAdmin =
        context.watch<AuthProvider>().user?.role == UserRole.manager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Album',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Hàng đợi kiểm duyệt thủ công của Manager/Deputy.
          if (isAdmin)
            IconButton(
              tooltip: 'Hàng đợi kiểm duyệt',
              icon: const Icon(
                Icons.shield_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: _showModerationQueueSheet,
            ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => album.fetchMedia(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(album),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => album.fetchMedia(refresh: true),
              child: _body(album, isAdmin),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'album_fab',
        onPressed: album.uploading ? null : _showCreateMenu,
        backgroundColor: AppColors.link,
        child: album.uploading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_a_photo_outlined, color: Colors.white),
      ),
    );
  }

  // Sheet hàng đợi kiểm duyệt thủ công. Face AI không được gọi/hiển thị.
  void _showModerationQueueSheet() {
    final album = context.read<AlbumProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: album.fetchModerationQueue(),
              builder: (_, snap) {
                final items = snap.data ?? const [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛡️ Hàng đợi kiểm duyệt${snap.hasData ? ' (${items.length})' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Đánh dấu ảnh/video hợp lệ trước khi cho phép gắn tag.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snap.hasError)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Không tải được: ${snap.error}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Không có media nào chờ kiểm duyệt 🎉',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView(
                          shrinkWrap: true,
                          children: items.map((it) {
                            final mediaId = it['mediaId']?.toString() ?? '';
                            final status =
                                it['moderationStatus']?.toString() ?? '';
                            final needAction = status != 'SAFE';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        it['mediaType']?.toString() == 'VIDEO'
                                            ? '🎬'
                                            : '🖼️',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          status,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (needAction && mediaId.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        left: 26,
                                      ),
                                      child: Row(
                                        children: [
                                          _queueAction(
                                            label: '✓ An toàn',
                                            color: AppColors.safe,
                                            onTap: () async {
                                              try {
                                                await album.reviewModeration(
                                                  mediaId,
                                                  decision: 'MARK_SAFE',
                                                  reviewNote:
                                                      'Đã kiểm tra thủ công từ hàng đợi',
                                                );
                                                setSheet(() {});
                                              } catch (e) {
                                                _snack(e);
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _queueAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _filters(AlbumProvider album) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              label: 'Tất cả',
              selected:
                  album.mediaType == null && album.moderationStatus == null,
              onTap: () => album.fetchMedia(refresh: true),
            ),
            _chip(
              label: 'Ảnh',
              selected: album.mediaType == AlbumMediaType.photo,
              onTap: () => album.fetchMedia(
                refresh: true,
                mediaType: AlbumMediaType.photo,
              ),
            ),
            _chip(
              label: 'Video',
              selected: album.mediaType == AlbumMediaType.video,
              onTap: () => album.fetchMedia(
                refresh: true,
                mediaType: AlbumMediaType.video,
              ),
            ),
            _chip(
              label: 'Cần duyệt',
              selected:
                  album.moderationStatus == AlbumModerationStatus.needReview,
              onTap: () => album.fetchMedia(
                refresh: true,
                moderationStatus: AlbumModerationStatus.needReview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary50,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primary600 : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: selected ? AppColors.primary500 : const Color(0xFFE5E7EB),
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _body(AlbumProvider album, bool isAdmin) {
    if (album.loading && album.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (album.error != null && album.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.textMuted.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Không tải được album',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              album.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }
    if (album.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 130),
          const Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Chưa có media nào',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tải ảnh/video gia đình lên để bắt đầu.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: album.items.length + (album.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= album.items.length) {
          album.fetchMedia(refresh: false);
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final media = album.items[i];
        return _tile(media, isAdmin);
      },
    );
  }

  Widget _tile(AlbumMedia media, bool isAdmin) {
    return GestureDetector(
      onTap: () => _openDetail(media, isAdmin),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MediaThumb(media: media),
            if (media.isVideo)
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            Positioned(
              left: 6,
              top: 6,
              child: _statusBadge(media.moderationStatus),
            ),
            if (media.isPending)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Text(
                  'Đang duyệt',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPreview(AlbumMedia media) {
    final url = media.displayUrl;
    if (url.isEmpty) return _thumbPlaceholder(isVideo: media.isVideo);
    return _thumbImage(url);
  }

  Future<void> _openDetail(AlbumMedia initial, bool isAdmin) async {
    AlbumMedia media = initial;
    try {
      media =
          await context.read<AlbumProvider>().fetchDetail(initial.id) ??
          initial;
    } catch (_) {
      media = initial;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              _detailMedia(media),
              const SizedBox(height: 14),
              Text(
                media.caption?.isNotEmpty == true
                    ? media.caption!
                    : 'Chưa có caption',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${media.uploaderName} · ${_fmtDate(media.createdAt)} · ${_scopeLabel(media.visibilityScope)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusBadge(media.moderationStatus),
                  ...media.tags.map((t) => _tagChip(ctx, media, t)),
                ],
              ),
              const SizedBox(height: 18),
              _actionList(ctx, media, isAdmin),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailMedia(AlbumMedia media) {
    final url = media.fileUrl ?? media.displayUrl;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url.isEmpty
            ? _mediaPreview(media)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mediaPreview(media),
              ),
      ),
    );
  }

  Widget _actionList(
    BuildContext sheetContext,
    AlbumMedia media,
    bool isAdmin,
  ) {
    final deleted = media.deletedAt != null;
    return Column(
      children: [
        if (media.isSafe)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
            title: const Text('Sửa caption / quyền xem'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showEditSheet(media);
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.sell_outlined,
            color: AppColors.textSecondary,
          ),
          title: const Text('Tag thành viên'),
          onTap: () {
            Navigator.pop(sheetContext);
            _showTagSheet(media);
          },
        ),
        if (isAdmin && media.canManualReview)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined, color: AppColors.safe),
            title: const Text('Manual review'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showReviewSheet(media);
            },
          ),
        if (deleted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded, color: AppColors.safe),
            title: const Text('Khôi phục'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().restore(media.id);
              } catch (e) {
                _snack(e);
              }
            },
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            title: const Text('Xóa mềm'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().softDelete(media.id);
              } catch (e) {
                _snack(e);
              }
            },
          ),
        if (deleted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: AppColors.danger,
            ),
            title: const Text('Xóa vĩnh viễn'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().permanentDelete(media.id);
              } catch (e) {
                _snack(e);
              }
            },
          ),
      ],
    );
  }

  void _showEditSheet(AlbumMedia media) {
    final captionCtrl = TextEditingController(text: media.caption ?? '');
    var scope = media.visibilityScope;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Caption',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AlbumVisibilityScope>(
                initialValue: scope,
                decoration: InputDecoration(
                  labelText: 'Quyền xem',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: AlbumVisibilityScope.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(_scopeLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setS(() => scope = v ?? scope),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  child: const Text('Lưu'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<AlbumProvider>().updateMedia(
                        media.id,
                        caption: captionCtrl.text,
                        visibilityScope: scope,
                      );
                    } catch (e) {
                      _snack(e);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagSheet(AlbumMedia media) {
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tag thành viên',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Chưa có danh sách thành viên',
                    style: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                )
              else
                ...members.map(
                  (m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name),
                    subtitle: Text(m.roleLabel),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await context.read<AlbumProvider>().tagMember(
                          media.id,
                          m.id,
                        );
                      } catch (e) {
                        _snack(e);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewSheet(AlbumMedia media) {
    final noteCtrl = TextEditingController(text: 'Đã kiểm tra thủ công.');
    var decision = 'MARK_SAFE';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.verified_outlined, color: AppColors.safe),
                title: Text('Đánh dấu an toàn (SAFE)'),
              ),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ghi chú review',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  child: const Text('Lưu review'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<AlbumProvider>().reviewModeration(
                        media.id,
                        decision: decision,
                        reviewNote: noteCtrl.text.trim().isEmpty
                            ? 'Đã kiểm tra thủ công.'
                            : noteCtrl.text.trim(),
                      );
                    } catch (e) {
                      _snack(e);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(AlbumModerationStatus status) {
    final (label, color, bg) = switch (status) {
      AlbumModerationStatus.safe => (
        'SAFE',
        AppColors.safe,
        const Color(0xFFDCFCE7),
      ),
      AlbumModerationStatus.needReview => (
        'REVIEW',
        AppColors.accent500,
        const Color(0xFFFFF7ED),
      ),
      AlbumModerationStatus.flagged => (
        'FLAGGED',
        AppColors.danger,
        const Color(0xFFFEE2E2),
      ),
      AlbumModerationStatus.pending => (
        'PENDING',
        AppColors.textSecondary,
        const Color(0xFFF3F4F6),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _tagChip(BuildContext sheetContext, AlbumMedia media, AlbumTag tag) {
    return InputChip(
      label: Text('@${tag.taggedMemberName}'),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      deleteIcon: tag.canRemove
          ? const Icon(Icons.close_rounded, size: 16)
          : null,
      onDeleted: tag.canRemove
          ? () async {
              try {
                final album = context.read<AlbumProvider>();
                await album.untagMember(media.id, tag.id);
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
              } catch (e) {
                _snack(e);
              }
            }
          : null,
    );
  }

  static String _scopeLabel(AlbumVisibilityScope scope) {
    return switch (scope) {
      AlbumVisibilityScope.family => 'Gia đình',
      AlbumVisibilityScope.private => 'Riêng tư',
      AlbumVisibilityScope.managerOnly => 'Chỉ Trưởng/Phó nhóm',
    };
  }

  static String _fmtDate(DateTime? date) {
    if (date == null) return 'Không rõ ngày';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ── Thumbnail lưới album ────────────────────────────────────────────────────
// Dùng chung visual cho cả ô lưới và fallback ở màn chi tiết.
Widget _thumbBox(IconData icon) => Container(
  color: const Color(0xFFE5E7EB),
  alignment: Alignment.center,
  child: Icon(icon, color: AppColors.textMuted),
);

Widget _thumbPlaceholder({required bool isVideo}) =>
    _thumbBox(isVideo ? Icons.movie_outlined : Icons.image_outlined);

Widget _thumbImage(String url) => Image.network(
  url,
  fit: BoxFit.cover,
  errorBuilder: (_, _, _) => _thumbBox(Icons.broken_image_outlined),
);

/// Ô ảnh trong lưới. API list không trả signed URL nên nếu [media] thiếu URL,
/// widget này gọi [AlbumProvider.resolveDisplayUrl] (chỉ GET detail để lấy URL)
/// rồi hiện ảnh. Có URL sẵn thì vẽ thẳng, không gọi mạng.
class _MediaThumb extends StatefulWidget {
  const _MediaThumb({required this.media});
  final AlbumMedia media;

  @override
  State<_MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<_MediaThumb> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _maybeResolve();
  }

  @override
  void didUpdateWidget(_MediaThumb old) {
    super.didUpdateWidget(old);
    // GridView tái sử dụng widget khi cuộn → media có thể đổi sang item khác.
    if (old.media.id != widget.media.id) _maybeResolve();
  }

  void _maybeResolve() {
    _future = widget.media.displayUrl.isNotEmpty
        ? null
        : context.read<AlbumProvider>().resolveDisplayUrl(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    final direct = widget.media.displayUrl;
    if (direct.isNotEmpty) return _thumbImage(direct);
    if (_future == null) {
      return _thumbPlaceholder(isVideo: widget.media.isVideo);
    }
    return FutureBuilder<String?>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _thumbBox(Icons.image_outlined);
        }
        final url = snap.data;
        if (url == null || url.isEmpty) {
          return _thumbPlaceholder(isVideo: widget.media.isVideo);
        }
        return _thumbImage(url);
      },
    );
  }
}
