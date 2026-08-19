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
import '../../providers/subscription_provider.dart';
import '../../services/album_pin_store.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'album_face_section.dart';
import 'album_people_screen.dart';

typedef _AlbumStatusBadgeBuilder =
    Widget Function(AlbumModerationStatus status);
typedef _AlbumActionListBuilder =
    Widget Function(
      BuildContext context,
      AlbumMedia media,
      VoidCallback onChanged,
    );

enum _PhotoHomeTab { library, collections }

/// Hành động người dùng chọn ở dialog cảnh báo analyze-draft khi
/// `recommendation = WARN`.
enum _AnalyzeWarnAction { confirmUpload, chooseAnotherCollection, cancel }

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Timer? _pollTimer;
  _PhotoHomeTab _tab = _PhotoHomeTab.library;

  // Ghim ảnh: trạng thái cục bộ theo máy, lưu qua AlbumPinStore để không mất
  // khi tắt app. BE chưa có field/endpoint ghim — xem DE_XUAT_BE_ALBUM_PIN.md.
  final Set<String> _pinnedIds = {};
  static const _pinStore = AlbumPinStore();

  // Chế độ chọn nhiều ảnh để xóa một lượt. Chỉ dùng ở tab Thư viện; chạm ô lúc
  // này là tick/bỏ tick chứ không mở màn chi tiết.
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _photoBackground =>
      _dark ? Colors.black : context.colors.background;
  Color get _photoSurface => _dark ? const Color(0xFF1C1C1E) : AppColors.white;
  Color get _photoChrome => _dark ? const Color(0xFF1F1F1F) : AppColors.white;
  Color get _photoText => _dark ? Colors.white : AppColors.textPrimary;
  Color get _photoSecondary => _dark ? Colors.white70 : AppColors.textSecondary;
  Color get _photoMuted => _dark ? Colors.white54 : AppColors.textMuted;
  Color get _photoBorder => _dark
      ? Colors.white.withValues(alpha: 0.08)
      : AppColors.progressTrack.withValues(alpha: 0.9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlbumProvider>().fetchMedia();
      context.read<AlbumProvider>().fetchCollections();
      context.read<FamilyProvider>().fetchMembers();
      _loadPinned();
      _startPolling();
    });
  }

  /// Nạp lại danh sách ghim đã lưu trên máy. Lỗi storage thì bỏ qua — mất ghim
  /// khó chịu nhưng không đáng chặn cả màn ảnh.
  Future<void> _loadPinned() async {
    final userId = context.read<AuthProvider>().user?.id;
    final familyId = ApiClient.instance.familyId;
    if (userId == null || familyId == null) return;
    try {
      final saved = await _pinStore.read(userId, familyId);
      if (!mounted || saved.isEmpty) return;
      setState(() => _pinnedIds.addAll(saved));
    } catch (e) {
      debugPrint('AlbumScreen: đọc danh sách ghim thất bại: $e');
    }
  }

  Future<void> _savePinned() async {
    final userId = context.read<AuthProvider>().user?.id;
    final familyId = ApiClient.instance.familyId;
    if (userId == null || familyId == null) return;
    try {
      await _pinStore.write(userId, familyId, _pinnedIds);
    } catch (e) {
      debugPrint('AlbumScreen: lưu danh sách ghim thất bại: $e');
    }
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
    if (video && !context.read<SubscriptionProvider>().canUploadVideo) {
      _snack(Exception('Gói hiện tại chưa hỗ trợ tải video lên album.'));
      return;
    }
    final picker = ImagePicker();
    List<XFile> files;
    if (video) {
      final file = await picker.pickVideo(source: source);
      files = file == null ? [] : [file];
    } else if (source == ImageSource.gallery) {
      // Chọn nhiều ảnh cùng lúc — chỉ áp dụng cho thư viện ảnh (camera luôn
      // chụp từng tấm, video giữ chọn đơn vì BE nhận đúng 1 file/request).
      files = await picker.pickMultiImage(imageQuality: 85);
    } else {
      final file = await picker.pickImage(source: source, imageQuality: 85);
      files = file == null ? [] : [file];
    }
    if (files.isEmpty || !mounted) return;
    _showUploadSheet(files);
  }

  void _showUploadSheet(
    List<XFile> files, {
    String? initialCaption,
    AlbumVisibilityScope? initialScope,
    String? initialCollectionId,
  }) {
    final captionCtrl = TextEditingController(text: initialCaption ?? '');
    var scope = initialScope ?? AlbumVisibilityScope.family;
    var collectionId = initialCollectionId;
    final collections = context.read<AlbumProvider>().collections;
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
                files.length > 1
                    ? 'Tải ${files.length} ảnh lên'
                    : 'Tải ảnh/video lên',
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
                  labelText: 'Mô tả',
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
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: collectionId,
                decoration: InputDecoration(
                  labelText: 'Album',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Không thuộc album nào'),
                  ),
                  ...collections.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        c.name.isEmpty ? '(Album không tên)' : c.name,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setS(() => collectionId = v),
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
                  label: const Text('Tải lên'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _analyzeAndUploadAll(
                      files,
                      caption: captionCtrl.text,
                      scope: scope,
                      collectionId: collectionId,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tải nhiều file đã chọn — xử lý tuần tự từng file (không song song) để
  /// mỗi sheet cảnh báo WARN chỉ hiện một lúc, không chồng nhau.
  Future<void> _analyzeAndUploadAll(
    List<XFile> files, {
    required String caption,
    required AlbumVisibilityScope scope,
    required String? collectionId,
  }) async {
    for (final file in files) {
      if (!mounted) return;
      await _analyzeAndUpload(
        file,
        caption: caption,
        scope: scope,
        collectionId: collectionId,
      );
    }
  }

  /// Dialog chờ ngắn khi gọi `analyze-draft` — bước này có thể mất vài giây
  /// (BE gọi AI phân tích), không hiện gì thì màn hình trông như bị đứng.
  /// Không cho bấm ra ngoài để đóng, tự đóng ngay khi có kết quả.
  void _showAnalyzingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Đang phân tích ảnh...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gọi `analyze-draft` trước khi tải lên thật. `ALLOW` (hoặc BE không phân
  /// tích được) thì tải lên luôn; `WARN` thì hỏi lại người dùng qua sheet cảnh
  /// báo. Face recognition không liên quan tới bước này — không đụng tới.
  Future<void> _analyzeAndUpload(
    XFile file, {
    required String caption,
    required AlbumVisibilityScope scope,
    required String? collectionId,
  }) async {
    final album = context.read<AlbumProvider>();
    _showAnalyzingDialog();
    Map<String, dynamic>? draft;
    try {
      draft = await album.analyzeDraft(
        filePath: file.path,
        collectionId: collectionId,
      );
    } catch (_) {
      draft = null; // Lỗi phân tích không chặn upload — coi như UNAVAILABLE.
    }
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(); // đóng dialog "Đang phân tích"

    final analysisStatus = draft?['analysisStatus']?.toString();
    final recommendation = draft?['recommendation']?.toString();

    if (draft == null ||
        analysisStatus == 'UNAVAILABLE' ||
        analysisStatus == 'SKIPPED') {
      final proceed = await _confirmSheet(
        title: 'Chưa phân tích được ảnh',
        message: 'Bạn có thể vẫn tải ảnh/video này lên bình thường.',
        confirmLabel: 'Vẫn tải lên',
      );
      if (proceed != true) return;
    } else if (recommendation == 'WARN') {
      final action = await _showAnalyzeWarnSheet(draft);
      if (action == null || action == _AnalyzeWarnAction.cancel) return;
      if (action == _AnalyzeWarnAction.chooseAnotherCollection) {
        if (!mounted) return;
        _showUploadSheet(
          [file],
          initialCaption: caption,
          initialScope: scope,
          initialCollectionId: collectionId,
        );
        return;
      }
      // confirmUpload -> tiếp tục tải lên với collection hiện tại.
    }

    try {
      await album.uploadMedia(
        filePath: file.path,
        caption: caption,
        visibilityScope: scope,
        collectionId: collectionId,
      );
    } catch (e) {
      _snack(e);
    }
  }

  /// Sheet cảnh báo khi `analyze-draft` trả `recommendation = WARN`. Hiện
  /// summary/warnings/detectedLabels nếu có, 3 nút theo đúng yêu cầu.
  Future<_AnalyzeWarnAction?> _showAnalyzeWarnSheet(
    Map<String, dynamic> draft,
  ) {
    final summary = draft['summary']?.toString();
    final warnings = (draft['warnings'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final labels = (draft['detectedLabels'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return showModalBottomSheet<_AnalyzeWarnAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ảnh này có thể chưa phù hợp',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(summary, style: GoogleFonts.inter(fontSize: 13)),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $w',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: labels
                    .map(
                      (l) => Chip(
                        label: Text(l, style: GoogleFonts.inter(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, _AnalyzeWarnAction.confirmUpload),
                child: const Text('Vẫn tải lên'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  _AnalyzeWarnAction.chooseAnotherCollection,
                ),
                child: const Text('Chọn album khác'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, _AnalyzeWarnAction.cancel),
                child: const Text('Hủy'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sheet xác nhận đơn giản dùng chung (vd khi analyze-draft UNAVAILABLE).
  Future<bool?> _confirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
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
    final members = context
        .watch<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
    // Current manual moderation contract is FAMILY_MANAGER only.
    final isAdmin =
        context.watch<AuthProvider>().user?.role == UserRole.manager;

    return Scaffold(
      backgroundColor: _photoBackground,
      appBar: _selecting
          ? _selectionAppBar(album)
          : AppBar(
              backgroundColor: _photoBackground,
              foregroundColor: _photoText,
              elevation: 0,
              title: const SizedBox.shrink(),
              actions: [
                // Hàng đợi kiểm duyệt thủ công của Manager/Deputy.
                if (isAdmin)
                  IconButton(
                    tooltip: 'Hàng đợi kiểm duyệt',
                    icon: const Icon(Icons.shield_outlined),
                    onPressed: _showModerationQueueSheet,
                  ),
                // Chỉ có nghĩa ở lưới ảnh; tab Bộ sưu tập không chọn ảnh được.
                if (_tab == _PhotoHomeTab.library && album.items.isNotEmpty)
                  IconButton(
                    tooltip: 'Chọn nhiều ảnh',
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    onPressed: () => setState(() => _selecting = true),
                  ),
                _filterMenu(album),
                IconButton(
                  tooltip: 'Làm mới',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => album.fetchMedia(refresh: true),
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () => album.fetchMedia(refresh: true),
              child: _tab == _PhotoHomeTab.library
                  ? _libraryBody(album, isAdmin)
                  : _collectionsBody(album, members, isAdmin),
            ),
          ),
          // Đang chọn ảnh thì ẩn thanh chuyển tab: đổi tab giữa chừng làm mất
          // lựa chọn, dễ gây hiểu nhầm.
          if (!_selecting)
            Positioned(left: 0, right: 0, bottom: 18, child: _photoTabs()),
        ],
      ),
      // Ẩn nút thêm ảnh khi đang chọn — thao tác lúc này là xóa, không phải tải lên.
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
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

  /// AppBar thay thế khi đang chọn nhiều ảnh: thoát · số đã chọn · chọn tất cả ·
  /// xóa. Nút xóa tắt khi chưa chọn gì để không mở dialog rỗng.
  PreferredSizeWidget _selectionAppBar(AlbumProvider album) {
    final all = album.items.map((m) => m.id).toSet();
    final allSelected = all.isNotEmpty && _selectedIds.containsAll(all);
    return AppBar(
      backgroundColor: _photoBackground,
      foregroundColor: _photoText,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Thoát chọn',
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelection,
      ),
      title: Text(
        _selectedIds.isEmpty ? 'Chọn ảnh' : 'Đã chọn ${_selectedIds.length}',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _photoText,
        ),
      ),
      actions: [
        IconButton(
          tooltip: allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          onPressed: () => setState(() {
            if (allSelected) {
              _selectedIds.clear();
            } else {
              _selectedIds
                ..clear()
                ..addAll(all);
            }
          }),
        ),
        IconButton(
          tooltip: 'Xóa ảnh đã chọn',
          icon: Icon(
            Icons.delete_outline_rounded,
            color: _selectedIds.isEmpty ? _photoMuted : AppColors.danger,
          ),
          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
        ),
      ],
    );
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String mediaId) {
    setState(() {
      if (!_selectedIds.remove(mediaId)) _selectedIds.add(mediaId);
    });
  }

  /// Xóa mềm toàn bộ ảnh đang chọn.
  ///
  /// BE chưa có endpoint xóa hàng loạt nên đây là N lần gọi
  /// `DELETE .../albums/media/{mediaId}` tuần tự — chạy lâu nên phải có tiến
  /// độ, và phải báo đúng số xóa được / số lỗi thay vì chỉ hiện "đã xóa".
  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirm = await _confirmSheet(
      title: 'Xóa ${ids.length} ảnh?',
      message:
          'Ảnh sẽ được xóa mềm, quản trị viên vẫn khôi phục lại được. '
          'Xóa nhiều ảnh có thể mất một lúc.',
      confirmLabel: 'Xóa ${ids.length} ảnh',
    );
    if (confirm != true || !mounted) return;

    final progress = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                ValueListenableBuilder<int>(
                  valueListenable: progress,
                  builder: (_, done, _) => Text(
                    'Đang xóa $done/${ids.length}...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final album = context.read<AlbumProvider>();
    Map<String, String> failures = {};
    try {
      failures = await album.softDeleteMany(
        ids,
        onProgress: (done, _) => progress.value = done,
      );
    } finally {
      progress.dispose();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    // Ảnh đã xóa thì gỡ khỏi danh sách ghim, không để ghim trỏ vào id không
    // còn tồn tại. Ảnh xóa lỗi thì giữ nguyên ghim.
    final removed = ids.where((id) => !failures.containsKey(id)).toSet();
    if (_pinnedIds.any(removed.contains)) {
      _pinnedIds.removeAll(removed);
      await _savePinned();
    }

    _exitSelection();
    final ok = ids.length - failures.length;
    if (failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa $ok ảnh'),
          backgroundColor: AppColors.safe,
        ),
      );
    } else {
      // Nói rõ lỗi đầu tiên của BE thay vì chỉ báo "thất bại" chung chung.
      _snack(
        'Đã xóa $ok/${ids.length} ảnh. ${failures.length} ảnh lỗi: '
        '${failures.values.first.replaceFirst('Exception: ', '')}',
      );
    }
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
                      'Hàng đợi kiểm duyệt${snap.hasData ? ' (${items.length})' : ''}',
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
                          'Không có ảnh/video nào chờ kiểm duyệt',
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
                            final canRetry =
                                status.toUpperCase() == 'PROCESSING';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        it['mediaType']?.toString() == 'VIDEO'
                                            ? Icons.movie_outlined
                                            : Icons.image_outlined,
                                        size: 18,
                                        color: AppColors.link,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _moderationQueueStatusLabel(status),
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
                                            label: 'An toàn',
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
                                          if (canRetry) ...[
                                            const SizedBox(width: 8),
                                            _queueAction(
                                              label: 'Thử quét lại',
                                              color: AppColors.link,
                                              onTap: () async {
                                                try {
                                                  await album.retryModeration(
                                                    mediaId,
                                                  );
                                                  if (ctx.mounted) {
                                                    setSheet(() {});
                                                  }
                                                } catch (e) {
                                                  _snack(e);
                                                }
                                              },
                                            ),
                                          ],
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

  String _moderationQueueStatusLabel(String status) {
    return switch (status.toUpperCase()) {
      'SAFE' => 'An toàn',
      'NEED_REVIEW' => 'Cần duyệt',
      'FLAGGED' => 'Bị gắn cờ',
      'PENDING' => 'Đang chờ',
      'PROCESSING' => 'Đang xử lý',
      _ => status.isEmpty ? 'Không rõ trạng thái' : status,
    };
  }

  Widget _filterMenu(AlbumProvider album) {
    return PopupMenuButton<String>(
      tooltip: 'Lọc ảnh',
      color: _photoSurface,
      icon: Icon(Icons.tune_rounded, color: _photoText),
      onSelected: (value) {
        switch (value) {
          case 'photo':
            album.fetchMedia(refresh: true, mediaType: AlbumMediaType.photo);
          case 'video':
            album.fetchMedia(refresh: true, mediaType: AlbumMediaType.video);
          case 'review':
            album.fetchMedia(
              refresh: true,
              moderationStatus: AlbumModerationStatus.needReview,
            );
          default:
            album.fetchMedia(refresh: true);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('Tất cả')),
        const PopupMenuItem(value: 'photo', child: Text('Ảnh')),
        const PopupMenuItem(value: 'video', child: Text('Video')),
        const PopupMenuItem(value: 'review', child: Text('Cần duyệt')),
      ],
    );
  }

  Widget _photoTabs() {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _photoChrome.withValues(alpha: _dark ? 0.92 : 0.96),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _photoBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _photoTabButton(
                icon: Icons.photo_library_rounded,
                label: 'Thư viện',
                selected: _tab == _PhotoHomeTab.library,
                onTap: () => setState(() => _tab = _PhotoHomeTab.library),
              ),
              _photoTabButton(
                icon: Icons.collections_bookmark_rounded,
                label: 'Bộ sưu tập',
                selected: _tab == _PhotoHomeTab.collections,
                onTap: () {
                  // Card "Tất cả ảnh"/"Video" dùng album.items để đếm số mục
                  // — nếu lần fetch gần nhất đang bị lọc theo 1 album/loại cụ
                  // thể (vd vừa xem xong album "anh LMH"), số hiển thị sẽ sai
                  // (chỉ còn vài mục thay vì tổng thật). Về lại tab này thì
                  // luôn nạp lại không lọc để số đếm đúng.
                  final album = context.read<AlbumProvider>();
                  if (album.collectionId != null || album.mediaType != null) {
                    album.fetchMedia(refresh: true);
                  }
                  setState(() => _tab = _PhotoHomeTab.collections);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoTabButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (_dark
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppColors.link.withValues(alpha: 0.10))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.link : _photoText),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.link : _photoText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryBody(AlbumProvider album, bool isAdmin) {
    if (album.loading && album.items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _photoText));
    }
    if (album.error != null && album.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_outlined, size: 42, color: _photoSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Không tải được ảnh',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: _photoText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              album.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _photoSecondary),
            ),
          ),
        ],
      );
    }
    if (album.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _libraryHeader(album.items.length),
          const SizedBox(height: 130),
          Icon(Icons.photo_library_outlined, size: 48, color: _photoSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Chưa có ảnh nào',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: _photoText,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tải ảnh/video gia đình lên để bắt đầu.',
              style: GoogleFonts.inter(fontSize: 12, color: _photoSecondary),
            ),
          ),
        ],
      );
    }

    final groups = _dayGroups(album.items);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _libraryHeader(album.items.length)),
        for (final group in groups) ...[
          SliverToBoxAdapter(child: _dayHeader(group.date)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _tile(group.items[i], isAdmin),
                childCount: group.items.length,
              ),
            ),
          ),
        ],
        if (album.hasMore)
          SliverToBoxAdapter(child: _loadMoreIndicator(album))
        else
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
      ],
    );
  }

  Widget _libraryHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ảnh',
            style: GoogleFonts.inter(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
              color: _photoText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // "Đã tải" vì đây là số item FE đã fetch (phân trang), KHÔNG phải
            // total toàn thư viện. Total thật cần BE trả trong list response.
            'Đã tải $count mục',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _photoSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(DateTime? date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            _dateLabel(date),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _photoText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _daySubtitle(date),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _photoMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreIndicator(AlbumProvider album) {
    album.fetchMedia(refresh: false);
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 124),
      child: Center(
        child: CircularProgressIndicator(color: _photoText, strokeWidth: 2),
      ),
    );
  }

  Widget _collectionsBody(
    AlbumProvider album,
    List<FamilyMember> members,
    bool isAdmin,
  ) {
    final pinned = album.items
        .where((media) => _pinnedIds.contains(media.id))
        .toList();
    final videos = album.items.where((media) => media.isVideo).toList();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Text(
              'Bộ sưu tập',
              style: GoogleFonts.inter(
                fontSize: 36,
                height: 1,
                fontWeight: FontWeight.w900,
                color: _photoText,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _collectionSection(
            title: 'Đã ghim',
            // Ghim đã sống qua lần mở app, nhưng vẫn là cục bộ theo máy vì BE
            // chưa có endpoint ghim — nói rõ để không hiểu nhầm là đồng bộ.
            note: 'chỉ trên máy này',
            children: pinned.isEmpty
                ? [
                    _collectionPlaceholderCard(
                      title: 'Chưa có ảnh ghim',
                      subtitle: 'Ghim ảnh yêu thích từ màn xem ảnh',
                      icon: Icons.push_pin_outlined,
                      fallbackGradient: _pinnedGradient,
                    ),
                  ]
                : pinned
                      .take(8)
                      .map(
                        (media) => _collectionMediaCard(
                          media: media,
                          title: media.caption?.isNotEmpty == true
                              ? media.caption!
                              : 'Ảnh đã ghim',
                          subtitle: _fmtDate(media.createdAt),
                          onTap: () => _openDetail(media, isAdmin),
                        ),
                      )
                      .toList(),
          ),
        ),
        SliverToBoxAdapter(
          child: _collectionSection(
            title: 'Album',
            children: [
              _collectionCreateCard(),
              _collectionMediaCard(
                media: album.items.isEmpty ? null : album.items.first,
                title: 'Tất cả ảnh',
                subtitle: '${album.items.length} mục',
                icon: Icons.photo_library_outlined,
                fallbackGradient: _libraryGradient,
                onTap: () {
                  // Reset filter về tất cả (kể cả collectionId) — media cũ
                  // collectionId null vẫn hiện bình thường ở đây.
                  album.fetchMedia(refresh: true);
                  setState(() => _tab = _PhotoHomeTab.library);
                },
              ),
              _collectionMediaCard(
                media: videos.isEmpty ? null : videos.first,
                title: 'Video',
                subtitle: '${videos.length} mục',
                icon: Icons.video_library_outlined,
                fallbackGradient: _videoGradient,
                onTap: () {
                  album.fetchMedia(
                    refresh: true,
                    mediaType: AlbumMediaType.video,
                  );
                  setState(() => _tab = _PhotoHomeTab.library);
                },
              ),
              for (final collection in album.collections)
                _collectionCustomCard(
                  collection: collection,
                  cover: _coverFor(album.items, collection.id),
                  onTap: () {
                    album.fetchMedia(
                      refresh: true,
                      collectionId: collection.id,
                    );
                    setState(() => _tab = _PhotoHomeTab.library);
                  },
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _collectionSection(
            title: 'Thành viên',
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlbumPeopleScreen()),
            ),
            children: members.isEmpty
                ? [
                    _collectionPlaceholderCard(
                      title: 'Chưa có thành viên',
                      subtitle: 'Thêm thành viên để phân loại ảnh',
                      icon: Icons.people_alt_outlined,
                    ),
                  ]
                : members
                      .take(8)
                      .map(
                        (member) => _memberCollectionCard(
                          member,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumMemberPhotosScreen(
                                memberId: member.id,
                                memberName: member.name,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 124)),
      ],
    );
  }

  Widget _collectionSection({
    required String title,
    required List<Widget> children,
    VoidCallback? onOpen,
    Widget? trailing,
    String? note,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 18, 10),
            child: Row(
              children: [
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onOpen,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _photoText,
                            ),
                          ),
                        ),
                        if (onOpen != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _photoText,
                            size: 26,
                          ),
                      ],
                    ),
                  ),
                ),
                // Nhãn cho mục chưa đồng bộ qua BE (vd Đã ghim chỉ lưu cục bộ
                // trên máy) — nói rõ phạm vi, tránh hiểu nhầm là dữ liệu chung.
                if (note != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _dark
                          ? Colors.white.withValues(alpha: 0.14)
                          : AppColors.link.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      note,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _photoMuted,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          SizedBox(
            height: 144,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionMediaCard({
    required AlbumMedia? media,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData icon = Icons.image_outlined,
    Gradient? fallbackGradient,
  }) {
    return _collectionCardFrame(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media == null)
            _collectionCardFallback(icon, gradient: fallbackGradient)
          else
            AlbumMediaThumb(media: media),
          _collectionCardScrim(),
          _collectionCardText(title: title, subtitle: subtitle),
        ],
      ),
    );
  }

  /// Tìm 1 ảnh/video thuộc collection trong danh sách đang tải để làm ảnh
  /// nền card — best-effort, chỉ tìm trong `items` đã tải (trang hiện tại),
  /// không gọi thêm request riêng.
  AlbumMedia? _coverFor(List<AlbumMedia> items, String collectionId) {
    for (final m in items) {
      if (m.collectionId == collectionId) return m;
    }
    return null;
  }

  /// Card cho 1 album do người dùng tạo — có ảnh nền thật nếu tìm được
  /// (đồng bộ style với "Tất cả ảnh"/"Video"), gradient màu thương hiệu khi
  /// album còn trống thay vì icon xám phẳng. Có nút "⋮" mở sửa/xóa.
  Widget _collectionCustomCard({
    required AlbumCollection collection,
    required AlbumMedia? cover,
    required VoidCallback onTap,
  }) {
    final title = collection.name.isEmpty
        ? '(Album không tên)'
        : collection.name;
    return _collectionCardFrame(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            AlbumMediaThumb(media: cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary500,
                    AppColors.link.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.collections_bookmark_outlined,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 38,
                ),
              ),
            ),
          _collectionCardScrim(),
          _collectionCardText(title: title, subtitle: 'Album'),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.32),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showCollectionOptionsSheet(collection),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCollectionOptionsSheet(AlbumCollection collection) {
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
                Icons.edit_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Sửa tên / mô tả'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditCollectionSheet(collection);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text('Xóa album'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await _confirmSheet(
                  title: 'Xóa album "${collection.name}"?',
                  message:
                      'Ảnh/video đã tải lên vẫn được giữ nguyên, chỉ album bị xóa.',
                  confirmLabel: 'Xóa album',
                );
                if (confirm != true || !mounted) return;
                try {
                  await context.read<AlbumProvider>().deleteCollection(
                    collection.id,
                  );
                } catch (e) {
                  _snack(e);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCollectionSheet(AlbumCollection collection) {
    final nameCtrl = TextEditingController(text: collection.name);
    final descCtrl = TextEditingController(text: collection.description ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'Sửa album',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Tên album',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Mô tả (không bắt buộc)',
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
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await context.read<AlbumProvider>().updateCollection(
                      collection.id,
                      name: name,
                      description: descCtrl.text,
                    );
                  } catch (e) {
                    _snack(e);
                  }
                },
                child: const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionPlaceholderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Gradient? fallbackGradient,
  }) {
    return _collectionCardFrame(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _collectionCardFallback(icon, gradient: fallbackGradient),
          _collectionCardText(title: title, subtitle: subtitle),
        ],
      ),
    );
  }

  /// Card "+ Tạo album" — mở sheet tạo collection mới (name bắt buộc, mô tả
  /// optional). Đặt đầu hàng "Album" cho dễ thấy. Style riêng (nền nhạt,
  /// viền, icon+chữ giữa) để đọc rõ là 1 nút hành động, không phải nội dung
  /// như các card ảnh khác.
  Widget _collectionCreateCard() {
    return _collectionCardFrame(
      onTap: _showCreateCollectionSheet,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary500.withValues(alpha: 0.08),
          border: Border.all(
            color: AppColors.primary500.withValues(alpha: 0.45),
            width: 1.4,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary500,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Tạo album',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateCollectionSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'Tạo album mới',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Tên album',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Mô tả (không bắt buộc)',
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
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await context.read<AlbumProvider>().createCollection(
                      name: name,
                      description: descCtrl.text,
                    );
                  } catch (e) {
                    _snack(e);
                  }
                },
                child: const Text('Tạo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCollectionCard(
    FamilyMember member, {
    required VoidCallback onTap,
  }) {
    return _collectionCardFrame(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Color(member.avatarColor)),
          Center(
            child: AvatarWidget(
              initial: member.avatarInitials,
              color: Color(member.avatarColor),
              size: 78,
            ),
          ),
          _collectionCardScrim(),
          _collectionCardText(
            title: member.name.isEmpty ? 'Thành viên' : member.name,
            subtitle: member.roleLabel,
          ),
        ],
      ),
    );
  }

  Widget _collectionCardFrame({required Widget child, VoidCallback? onTap}) {
    return SizedBox(
      width: 144,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
      ),
    );
  }

  Widget _collectionCardFallback(IconData icon, {Gradient? gradient}) {
    if (gradient != null) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 38,
          ),
        ),
      );
    }
    return Container(
      color: _dark ? const Color(0xFF3F3F46) : AppColors.progressTrack,
      alignment: Alignment.center,
      child: Icon(icon, color: _photoMuted, size: 38),
    );
  }

  // 3 gradient cố định cho từng loại card rỗng — chỉ để phân biệt trực quan
  // "Đã ghim" (ấm/hổ phách) / "Tất cả ảnh" (xanh dương) / "Video" (tím), dùng
  // lại đúng 2 màu theme sẵn có (AppColors.primary500/link) pha thêm sắc.
  static const _pinnedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6A93B), Color(0xFFEF7B45)],
  );
  static const _libraryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FA3E3), AppColors.link],
  );
  static const _videoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B6BE8), Color(0xFF5B3FC9)],
  );

  Widget _collectionCardScrim() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.68)],
        ),
      ),
    );
  }

  Widget _collectionCardText({
    required String title,
    required String subtitle,
  }) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }

  List<_MediaDayGroup> _dayGroups(List<AlbumMedia> items) {
    final groups = <String, _MediaDayGroup>{};
    for (final media in items) {
      final date = media.createdAt;
      final key = date == null
          ? 'unknown'
          : '${date.year}-${date.month}-${date.day}';
      groups
          .putIfAbsent(
            key,
            () => _MediaDayGroup(
              date == null ? null : DateTime(date.year, date.month, date.day),
            ),
          )
          .items
          .add(media);
    }
    final sorted = groups.values.toList();
    sorted.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return sorted;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Không rõ ngày';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _daySubtitle(DateTime? date) {
    if (date == null) return 'Ảnh chưa có ngày chụp';
    return 'Ảnh ngày ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime? date) => _dateLabel(date);

  Widget _tile(AlbumMedia media, bool isAdmin) {
    final selected = _selectedIds.contains(media.id);
    return GestureDetector(
      // Đang chọn: chạm = tick/bỏ tick. Bình thường: chạm = mở chi tiết, nhấn
      // giữ = vào chế độ chọn kèm tick luôn ô vừa giữ (kiểu Google Photos).
      onTap: () =>
          _selecting ? _toggleSelected(media.id) : _openDetail(media, isAdmin),
      onLongPress: _selecting
          ? null
          : () {
              setState(() => _selecting = true);
              _toggleSelected(media.id);
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AlbumMediaThumb(media: media),
            if (selected)
              Container(color: AppColors.link.withValues(alpha: 0.35)),
            if (media.isVideo)
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            if (media.moderationStatus != AlbumModerationStatus.safe)
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
            // Dấu tick góc phải: hiện khi đang chọn để thấy rõ ô nào đã tick,
            // ô nào chưa (viền trắng mờ), không chỉ dựa vào lớp phủ màu.
            if (_selecting)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.link : Colors.black26,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(1),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.circle_outlined,
                    size: 14,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(AlbumMedia initial, bool isAdmin) async {
    final items = context.read<AlbumProvider>().items;
    final initialIndex = items.indexWhere((m) => m.id == initial.id);
    if (!mounted) return;
    // Chip album trong viewer pop kèm collectionId khi người dùng bấm vào
    // để nhảy ra đúng album đó — không kèm gì thì đây là pop thường (back).
    final jumpToCollectionId = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => _AlbumDetailViewer(
          initialItems: items.isEmpty ? [initial] : items,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          isAdmin: isAdmin,
          statusBadgeBuilder: _statusBadge,
          actionListBuilder: (viewerContext, media, refreshDetail) =>
              _actionList(
                viewerContext,
                media,
                isAdmin,
                closeBeforeAction: false,
                onChanged: refreshDetail,
              ),
        ),
      ),
    );
    if (jumpToCollectionId == null || !mounted) return;
    context.read<AlbumProvider>().fetchMedia(
      refresh: true,
      collectionId: jumpToCollectionId,
    );
    setState(() => _tab = _PhotoHomeTab.library);
  }

  Widget _actionList(
    BuildContext sheetContext,
    AlbumMedia media,
    bool isAdmin, {
    bool closeBeforeAction = true,
    VoidCallback? onChanged,
  }) {
    final deleted = media.deletedAt != null;
    final pinned = _pinnedIds.contains(media.id);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: pinned ? AppColors.link : AppColors.textSecondary,
          ),
          title: Text(pinned ? 'Bỏ ghim' : 'Ghim ảnh'),
          onTap: () {
            setState(() {
              if (pinned) {
                _pinnedIds.remove(media.id);
              } else {
                _pinnedIds.add(media.id);
              }
            });
            _savePinned();
            onChanged?.call();
          },
        ),
        if (media.isSafe)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
            title: const Text('Sửa mô tả / quyền xem'),
            onTap: () {
              if (closeBeforeAction) Navigator.pop(sheetContext);
              _showEditSheet(
                media,
                hostContext: closeBeforeAction ? null : sheetContext,
                onSaved: onChanged,
              );
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.sell_outlined,
            color: AppColors.textSecondary,
          ),
          title: const Text('Gắn thẻ thành viên'),
          onTap: () {
            if (closeBeforeAction) Navigator.pop(sheetContext);
            _showTagSheet(
              media,
              hostContext: closeBeforeAction ? null : sheetContext,
              onTagged: onChanged,
            );
          },
        ),
        if (isAdmin && media.canManualReview)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined, color: AppColors.safe),
            title: const Text('Duyệt thủ công'),
            onTap: () {
              if (closeBeforeAction) Navigator.pop(sheetContext);
              _showReviewSheet(
                media,
                hostContext: closeBeforeAction ? null : sheetContext,
                onReviewed: onChanged,
              );
            },
          ),
        if (deleted)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded, color: AppColors.safe),
            title: const Text('Khôi phục'),
            onTap: () async {
              if (closeBeforeAction) Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().restore(media.id);
                if (!closeBeforeAction && sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
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
              if (closeBeforeAction) Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().softDelete(media.id);
                if (!closeBeforeAction && sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
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
              if (closeBeforeAction) Navigator.pop(sheetContext);
              try {
                await context.read<AlbumProvider>().permanentDelete(media.id);
                if (!closeBeforeAction && sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
              } catch (e) {
                _snack(e);
              }
            },
          ),
      ],
    );
  }

  void _showEditSheet(
    AlbumMedia media, {
    BuildContext? hostContext,
    VoidCallback? onSaved,
  }) {
    final captionCtrl = TextEditingController(text: media.caption ?? '');
    var scope = media.visibilityScope;
    var collectionId = media.collectionId;
    final collections = context.read<AlbumProvider>().collections;
    showModalBottomSheet(
      context: hostContext ?? context,
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
                  labelText: 'Mô tả',
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: collectionId,
                decoration: InputDecoration(
                  labelText: 'Album',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Không thuộc album nào'),
                  ),
                  ...collections.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        c.name.isEmpty ? '(Album không tên)' : c.name,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setS(() => collectionId = v),
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
                        collectionId: collectionId,
                      );
                      onSaved?.call();
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

  void _showTagSheet(
    AlbumMedia media, {
    BuildContext? hostContext,
    VoidCallback? onTagged,
  }) {
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();
    showModalBottomSheet(
      context: hostContext ?? context,
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
                'Gắn thẻ thành viên',
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
                        onTagged?.call();
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

  void _showReviewSheet(
    AlbumMedia media, {
    BuildContext? hostContext,
    VoidCallback? onReviewed,
  }) {
    final noteCtrl = TextEditingController(text: 'Đã kiểm tra thủ công.');
    var decision = 'MARK_SAFE';
    showModalBottomSheet(
      context: hostContext ?? context,
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
                title: Text('Đánh dấu an toàn'),
              ),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ghi chú duyệt',
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
                  child: const Text('Lưu duyệt'),
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
                      onReviewed?.call();
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
    final (icon, tip, color, bg) = switch (status) {
      AlbumModerationStatus.safe => (
        Icons.check_rounded,
        'An toàn',
        AppColors.safe,
        AppColors.safeLight,
      ),
      AlbumModerationStatus.needReview => (
        Icons.priority_high_rounded,
        'Cần duyệt',
        AppColors.accent500,
        AppColors.amberLight,
      ),
      AlbumModerationStatus.flagged => (
        Icons.close_rounded,
        'Bị gắn cờ',
        AppColors.danger,
        AppColors.dangerLight,
      ),
      AlbumModerationStatus.pending => (
        Icons.more_horiz_rounded,
        'Đang chờ xử lý',
        AppColors.textSecondary,
        AppColors.neutralBg,
      ),
    };
    return Tooltip(
      message: tip,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  static String _scopeLabel(AlbumVisibilityScope scope) {
    return switch (scope) {
      AlbumVisibilityScope.family => 'Gia đình',
      AlbumVisibilityScope.private => 'Riêng tư',
      AlbumVisibilityScope.managerOnly => 'Chỉ Trưởng/Phó nhóm',
    };
  }
}

class _MediaDayGroup {
  _MediaDayGroup(this.date);

  final DateTime? date;
  final List<AlbumMedia> items = [];
}

class _AlbumDetailViewer extends StatefulWidget {
  const _AlbumDetailViewer({
    required this.initialItems,
    required this.initialIndex,
    required this.isAdmin,
    required this.statusBadgeBuilder,
    required this.actionListBuilder,
  });

  final List<AlbumMedia> initialItems;
  final int initialIndex;
  final bool isAdmin;
  final _AlbumStatusBadgeBuilder statusBadgeBuilder;
  final _AlbumActionListBuilder actionListBuilder;

  @override
  State<_AlbumDetailViewer> createState() => _AlbumDetailViewerState();
}

class _AlbumDetailViewerState extends State<_AlbumDetailViewer> {
  late final PageController _pageController;
  late final List<AlbumMedia> _items;
  final Map<String, AlbumMedia> _details = {};
  final Set<String> _loadingIds = {};
  late int _index;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _items = List<AlbumMedia>.from(widget.initialItems);
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAround(_index));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  AlbumMedia get _media {
    final base = _items[_index];
    return _details[base.id] ?? base;
  }

  AlbumMedia _mediaAt(int index) {
    final base = _items[index];
    return _details[base.id] ?? base;
  }

  Future<void> _loadDetail(
    int index, {
    bool force = false,
    bool quiet = false,
  }) async {
    if (index < 0 || index >= _items.length) return;
    final id = _items[index].id;
    if (!force && (_details.containsKey(id) || _loadingIds.contains(id))) {
      return;
    }
    if (mounted) setState(() => _loadingIds.add(id));
    try {
      final detail = await context.read<AlbumProvider>().fetchDetail(id);
      if (!mounted || detail == null) return;
      setState(() => _details[id] = detail);
    } catch (e) {
      if (!quiet) _snack(e);
    } finally {
      if (mounted) setState(() => _loadingIds.remove(id));
    }
  }

  void _loadAround(int index) {
    _loadDetail(index);
    _loadDetail(index - 1, quiet: true);
    _loadDetail(index + 1, quiet: true);
  }

  void _refreshCurrent() {
    _loadDetail(_index, force: true);
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _snack(Object error, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (next) {
              setState(() => _index = next);
              _loadAround(next);
            },
            itemBuilder: (_, i) =>
                _AlbumDetailMediaPage(media: _mediaAt(i), onTap: _toggleChrome),
          ),
          if (_chromeVisible) _topBar(),
          if (_chromeVisible) _infoPanel(),
        ],
      ),
    );
  }

  Widget _topBar() {
    final media = _media;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: context.colors.textPrimary,
              ),
              Expanded(
                child: Text(
                  '${_index + 1}/${_items.length} · ${_fmtDate(media.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (media.isVideo)
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: context.colors.textPrimary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.06,
      maxChildSize: 0.78,
      builder: (_, controller) {
        final media = _media;
        final loading = _loadingIds.contains(media.id);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                Text(
                  media.caption?.isNotEmpty == true
                      ? media.caption!
                      : 'Chưa có mô tả',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${media.uploaderName} · ${_fmtDate(media.createdAt)} · ${_scopeLabel(media.visibilityScope)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    widget.statusBadgeBuilder(media.moderationStatus),
                    _albumChip(media),
                    ...media.tags.map((t) => _tagChip(media, t)),
                  ],
                ),
                const SizedBox(height: 14),
                AlbumFaceSection(
                  // Key theo mediaId để state (gợi ý đã xử lý) không bị dựng lại
                  // mỗi khi panel này rebuild và đổi số lượng con.
                  key: ValueKey('face-${media.id}'),
                  mediaId: media.id,
                  isImage: !media.isVideo,
                  isSafe: media.isSafe,
                  taggedMemberIds: media.tags
                      .map((t) => t.taggedMemberId)
                      .where((id) => id.isNotEmpty)
                      .toSet(),
                  // Tách riêng khỏi taggedMemberIds: có thẻ mà BE không trả id
                  // thì set trên rỗng, không dùng để kết luận "chưa có thẻ".
                  hasAnyTag: media.tags.isNotEmpty,
                  onChanged: _refreshCurrent,
                ),
                const SizedBox(height: 12),
                widget.actionListBuilder(context, media, _refreshCurrent),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Hiển thị album ảnh đang thuộc về — chữ mờ, không phải cảnh báo, khi
  /// ảnh chưa gán album nào (đa số ảnh cũ trước khi có tính năng này). Đã
  /// gán album thì bấm vào để nhảy thẳng ra danh sách ảnh của album đó
  /// (đóng viewer, `_openDetail` đọc kết quả pop để chuyển tab + lọc).
  Widget _albumChip(AlbumMedia media) {
    final collectionId = media.collectionId;
    if (collectionId == null || collectionId.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.colors.inputFill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 15,
              color: context.colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Không thuộc album',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    final collections = context.watch<AlbumProvider>().collections;
    AlbumCollection? match;
    for (final c in collections) {
      if (c.id == collectionId) {
        match = c;
        break;
      }
    }
    final label = match == null
        ? 'Album'
        : (match.name.isEmpty ? '(Album không tên)' : match.name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).pop(collectionId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary500.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary500.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.collections_bookmark_rounded,
                size: 15,
                color: AppColors.primary500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary500,
                ),
              ),
              const SizedBox(width: 1),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: AppColors.primary500.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(AlbumMedia media, AlbumTag tag) {
    return InputChip(
      label: Text('@${tag.taggedMemberName}'),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        color: context.colors.textSecondary,
      ),
      backgroundColor: context.colors.inputFill,
      deleteIcon: tag.canRemove
          ? const Icon(Icons.close_rounded, size: 16)
          : null,
      onDeleted: tag.canRemove
          ? () async {
              try {
                await context.read<AlbumProvider>().untagMember(
                  media.id,
                  tag.id,
                );
                _refreshCurrent();
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

class _AlbumDetailMediaPage extends StatefulWidget {
  const _AlbumDetailMediaPage({required this.media, required this.onTap});

  final AlbumMedia media;
  final VoidCallback onTap;

  @override
  State<_AlbumDetailMediaPage> createState() => _AlbumDetailMediaPageState();
}

class _AlbumDetailMediaPageState extends State<_AlbumDetailMediaPage> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _maybeResolve();
  }

  /// URL bản gốc đã hiện được, giữ lại để `fetchMedia(refresh: true)` thay
  /// `_items` bằng object không kèm URL cũng không làm trắng màn — cùng lý do
  /// với `_shownUrl` của [AlbumMediaThumbState].
  String? _shownUrl;

  @override
  void didUpdateWidget(_AlbumDetailMediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _shownUrl = null;
      _future = null;
      _maybeResolve();
    } else if ((widget.media.fileUrl ?? '').isEmpty &&
        _shownUrl == null &&
        _future == null) {
      _maybeResolve();
    }
  }

  /// Màn chi tiết luôn phải hiện **bản gốc** `fileUrl`, không phải
  /// `displayUrl` (= `thumbnailUrl ?? fileUrl`) như ô lưới — dùng displayUrl ở
  /// đây thì ảnh hiện ra là bản thu nhỏ, trông mờ hơn ảnh thật.
  void _maybeResolve() {
    final full = widget.media.fileUrl ?? '';
    if (full.isNotEmpty) {
      _shownUrl = full;
      _future = null;
      return;
    }
    _future = context.read<AlbumProvider>().resolveFullUrl(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.media.fileUrl ?? '';
    final best = full.isNotEmpty ? full : _shownUrl;
    if (best != null && best.isNotEmpty) {
      _shownUrl = best;
      return _media(best);
    }
    // Chưa có bản gốc: dùng thumbnail đang có làm ảnh tạm trong lúc chờ, không
    // để màn trống. Không có gì để hiện thì mới quay bánh xe.
    final thumb = widget.media.displayUrl;
    final future = _future;
    if (future == null) return thumb.isNotEmpty ? _media(thumb) : _empty();
    return FutureBuilder<String?>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          if (thumb.isNotEmpty) return _media(thumb);
          return Center(
            child: CircularProgressIndicator(color: context.colors.textPrimary),
          );
        }
        final url = snap.data ?? (thumb.isNotEmpty ? thumb : null);
        if (url == null || url.isEmpty) return _empty();
        _shownUrl = url;
        return _media(url);
      },
    );
  }

  Widget _media(String url) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            // KHÔNG bọc bằng Center: Center cho con ràng buộc lỏng nên Image tự
            // lấy kích thước gốc và BoxFit.contain mất tác dụng phóng to — ảnh
            // gốc nhỏ (screenshot ~150x110px) chỉ hiện bằng con tem giữa màn
            // hình. SizedBox.expand ép khung bằng cả trang để contain phóng
            // đúng nghĩa. filterQuality medium để ảnh nhỏ phóng lên đỡ rỗ
            // (ảnh gốc quá nhỏ thì vẫn mờ — giới hạn của dữ liệu, không phải UI).
            child: SizedBox.expand(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _empty(),
              ),
            ),
          ),
          if (widget.media.isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Center(
        child: Icon(
          widget.media.isVideo ? Icons.movie_outlined : Icons.image_outlined,
          color: context.colors.textSecondary,
          size: 52,
        ),
      ),
    );
  }
}

// ── Thumbnail lưới album ────────────────────────────────────────────────────
// Dùng chung visual cho cả ô lưới và fallback ở màn chi tiết.
Widget _thumbBox(IconData icon) => Container(
  color: AppColors.progressTrack,
  alignment: Alignment.center,
  child: Icon(icon, color: AppColors.textMuted),
);

Widget _thumbPlaceholder({required bool isVideo}) =>
    _thumbBox(isVideo ? Icons.movie_outlined : Icons.image_outlined);

/// Ô đang chờ lấy URL. Phải khác hẳn [_thumbPlaceholder] — trước đây cả hai
/// đều là ô xám kèm icon ảnh nên người dùng không phân biệt được "đang tải"
/// với "ảnh hỏng/không có", tưởng là mất ảnh.
Widget _thumbLoading() => Container(
  color: AppColors.progressTrack,
  alignment: Alignment.center,
  child: const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: AppColors.textMuted,
    ),
  ),
);

Widget _thumbImage(String url) => Image.network(
  url,
  fit: BoxFit.cover,
  errorBuilder: (_, _, _) => _thumbBox(Icons.broken_image_outlined),
);

/// Ô ảnh trong lưới. API list không trả signed URL nên nếu [media] thiếu URL,
/// widget này gọi [AlbumProvider.resolveDisplayUrl] (chỉ GET detail để lấy URL)
/// rồi hiện ảnh. Có URL sẵn thì vẽ thẳng, không gọi mạng.
class AlbumMediaThumb extends StatefulWidget {
  const AlbumMediaThumb({super.key, required this.media});
  final AlbumMedia media;

  @override
  State<AlbumMediaThumb> createState() => AlbumMediaThumbState();
}

class AlbumMediaThumbState extends State<AlbumMediaThumb> {
  Future<String?>? _future;

  /// URL đã hiện được cho **đúng media này**, giữ lại trong State.
  ///
  /// Bắt buộc phải có: `fetchMedia(refresh: true)` (poll 8s, kéo làm mới, đổi
  /// bộ lọc) thay sạch `_items` bằng object mới **không kèm URL**, mà
  /// `didUpdateWidget` lại chỉ resolve lại khi đổi `media.id`. Không nhớ URL
  /// thì ô đã hiện ảnh bị rơi về ô xám và kẹt ở đó tới khi widget được dựng
  /// lại — đúng triệu chứng "vào tab Ảnh thì mất ảnh, lúc sau mới hiện lại".
  String? _shownUrl;

  @override
  void initState() {
    super.initState();
    _maybeResolve();
  }

  @override
  void didUpdateWidget(AlbumMediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GridView tái sử dụng widget khi cuộn → media có thể đổi sang item khác.
    // Đổi media thì phải quên URL cũ, nếu không ô sẽ hiện nhầm ảnh trước đó.
    if (oldWidget.media.id != widget.media.id) {
      _shownUrl = null;
      _future = null;
      _maybeResolve();
    } else if (widget.media.displayUrl.isEmpty &&
        _shownUrl == null &&
        _future == null) {
      // Cùng media nhưng URL vừa bị mất do refresh, mà chưa từng hiện được ảnh
      // nào → phải gọi lại, không để ô đứng im mãi.
      _maybeResolve();
    }
  }

  void _maybeResolve() {
    final direct = widget.media.displayUrl;
    if (direct.isNotEmpty) {
      _shownUrl = direct;
      _future = null;
      return;
    }
    _future = context.read<AlbumProvider>().resolveDisplayUrl(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    // Ưu tiên URL mới nhất từ provider, rơi về URL đã hiện được trước đó.
    final direct = widget.media.displayUrl;
    final url = direct.isNotEmpty ? direct : _shownUrl;
    if (url != null && url.isNotEmpty) {
      _shownUrl = url;
      return _thumbImage(url);
    }
    if (_future == null) {
      return _thumbPlaceholder(isVideo: widget.media.isVideo);
    }
    return FutureBuilder<String?>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done)
          return _thumbLoading();
        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) {
          return _thumbPlaceholder(isVideo: widget.media.isVideo);
        }
        // Ghi thẳng, không setState: khung hình này đã vẽ ảnh rồi, đây chỉ là
        // ghi nhớ để lần refresh sau không làm trắng ô.
        _shownUrl = resolved;
        return _thumbImage(resolved);
      },
    );
  }
}
