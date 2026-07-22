import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/album_media.dart';
import '../../providers/album_provider.dart';
import '../../providers/face_profile_provider.dart';
import '../../providers/family_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'album_screen.dart' show AlbumMediaThumb;

/// "Thành viên" — chia ảnh theo từng thành viên (tham khảo Google Photos).
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
  final Map<String, Future<FaceProfile>> _profileFutures = {};
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

  Future<FaceProfile> _profileFor(String memberId) {
    return _profileFutures.putIfAbsent(
      memberId,
      () => context.read<FaceProfileProvider>().load(memberId),
    );
  }

  Future<void> _refreshPeople() async {
    setState(() {
      _photoFutures.clear();
      _profileFutures.clear();
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
            var photos = const <AlbumMedia>[];
            var profile = FaceProfile(
              memberId: member.id,
              status: FaceProfileStatus.notEnrolled,
            );
            try {
              photos = await _photosFor(member.id);
            } catch (_) {}
            try {
              profile = await _profileFor(member.id);
            } catch (_) {}
            return _AlbumMemberPreview(
              member: member,
              photos: photos,
              profile: profile,
            );
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        title: Text(
          'Thành viên',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        // Mô tả trung thực: khớp theo hồ sơ khuôn mặt thành viên đã đăng ký,
        // KHÔNG phải cluster mặt lạ như Google Photos.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Ảnh được nhận diện theo thành viên gia đình',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),
            ),
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
                        color: context.colors.textMuted,
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
                          childAspectRatio: 0.64,
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
          const SizedBox(height: 6),
          _profileChip(preview),
        ],
      ),
    );
  }

  Widget _profileChip(_AlbumMemberPreview preview) {
    final profile = preview.profile;
    final disabled = profile.isDisabled;
    final enrolled = profile.isEnrolled && profile.enabled;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => FaceEnrollScreen(member: preview.member),
            ),
          )
          .then((_) => _refreshPeople()),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enrolled
              ? AppColors.safe.withValues(alpha: 0.10)
              : disabled
              ? AppColors.accent100
              : AppColors.primary500.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          enrolled
              ? 'Đã bật'
              : disabled
              ? 'Đang tắt'
              : 'Đăng ký',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: enrolled
                ? AppColors.safe
                : disabled
                ? AppColors.accent500
                : AppColors.primary600,
          ),
        ),
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
  const _AlbumMemberPreview({
    required this.member,
    required this.photos,
    required this.profile,
  });

  final FamilyMember member;
  final List<AlbumMedia> photos;
  final FaceProfile profile;

  String get name => member.name.isEmpty ? 'Thành viên' : member.name;
}

class FaceEnrollScreen extends StatefulWidget {
  const FaceEnrollScreen({super.key, required this.member});

  final FamilyMember member;

  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends State<FaceEnrollScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  FaceProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _consent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await context.read<FaceProfileProvider>().load(
        widget.member.id,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickGallery() async {
    if (_images.length >= 5) {
      _showMessage('Chỉ chọn tối đa 5 ảnh.');
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    final remaining = 5 - _images.length;
    final existing = _images.map((e) => e.path).toSet();
    final next = picked
        .where((e) => !existing.contains(e.path))
        .take(remaining);
    setState(() => _images.addAll(next));
    if (picked.length > remaining) {
      _showMessage('Đã giữ 5 ảnh đầu tiên để đăng ký.');
    }
  }

  Future<void> _pickCamera() async {
    if (_images.length >= 5) {
      _showMessage('Chỉ chọn tối đa 5 ảnh.');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    if (_images.any((e) => e.path == picked.path)) return;
    setState(() => _images.add(picked));
  }

  void _removeImage(String path) {
    setState(() => _images.removeWhere((e) => e.path == path));
  }

  Future<void> _submit() async {
    if (_images.length < 3 || _images.length > 5) {
      _showMessage('Vui lòng chọn từ 3 đến 5 ảnh khuôn mặt.');
      return;
    }
    if (!_consent) {
      _showMessage('Cần xác nhận đồng ý trước khi đăng ký.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final faceProvider = context.read<FaceProfileProvider>();
      await faceProvider.enroll(
        widget.member.id,
        _images.map((e) => e.path).toList(),
      );
      final profile = await faceProvider.load(widget.member.id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _images.clear();
        _consent = false;
        _saving = false;
      });
      _showMessage('Đã đăng ký khuôn mặt cho ${widget.member.name}.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  Future<void> _toggleEnabled() async {
    final profile = _profile;
    if (profile == null || !profile.isEnrolled) return;
    setState(() => _saving = true);
    try {
      final face = context.read<FaceProfileProvider>();
      await face.setEnabled(widget.member.id, !profile.enabled);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  Future<void> _deleteProfile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hồ sơ khuôn mặt?'),
        content: const Text(
          'Thao tác này sẽ xóa dữ liệu đăng ký khuôn mặt của thành viên này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<FaceProfileProvider>().delete(widget.member.id);
      if (!mounted) return;
      setState(() {
        _profile = FaceProfile(
          memberId: widget.member.id,
          status: FaceProfileStatus.notEnrolled,
        );
        _saving = false;
      });
      _showMessage('Đã xóa hồ sơ khuôn mặt.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  String _statusText(FaceProfile profile) {
    if (!profile.isEnrolled) return 'Chưa đăng ký khuôn mặt';
    if (profile.enabled) return 'Đã đăng ký và đang bật';
    return 'Đã đăng ký nhưng đang tắt';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final memberName = widget.member.name.isEmpty
        ? 'Thành viên'
        : widget.member.name;
    final profile =
        _profile ??
        FaceProfile(
          memberId: widget.member.id,
          status: FaceProfileStatus.notEnrolled,
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Hồ sơ khuôn mặt',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _profileHeader(profile, memberName),
                const SizedBox(height: 14),
                _consentCard(),
                const SizedBox(height: 14),
                _imagePickerCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sos,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.face_retouching_natural_rounded),
                  label: Text(
                    profile.isEnrolled
                        ? 'Đăng ký lại khuôn mặt'
                        : 'Đăng ký khuôn mặt',
                  ),
                ),
                if (profile.isEnrolled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _toggleEnabled,
                    icon: Icon(
                      profile.enabled
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    label: Text(
                      profile.enabled
                          ? 'Tạm tắt nhận diện'
                          : 'Bật lại nhận diện',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _deleteProfile,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Xóa hồ sơ khuôn mặt'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.sos),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _profileHeader(FaceProfile profile, String memberName) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          AvatarWidget(
            initial: widget.member.avatarInitials,
            color: Color(widget.member.avatarColor),
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _statusText(profile),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: profile.isEnrolled
                        ? (profile.enabled
                              ? AppColors.safe
                              : AppColors.accent500)
                        : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _consentCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đồng ý sử dụng dữ liệu khuôn mặt',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dữ liệu này chỉ dùng để nhận diện ảnh gia đình và có thể tạm tắt hoặc xóa bất cứ lúc nào.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: _saving
                ? null
                : (v) => setState(() => _consent = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Tôi đồng ý đăng ký khuôn mặt cho thành viên này',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePickerCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ảnh khuôn mặt (${_images.length}/5)',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Cần 3-5 ảnh',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final image in _images) _imageThumb(image),
              if (_images.length < 5) _addImageButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageThumb(XFile image) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(image.path),
            width: 78,
            height: 78,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _saving ? null : () => _removeImage(image.path),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageButton() {
    final colors = context.colors;
    return PopupMenuButton<String>(
      enabled: !_saving,
      onSelected: (value) {
        if (value == 'gallery') _pickGallery();
        if (value == 'camera') _pickCamera();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'gallery',
          child: ListTile(
            leading: Icon(Icons.photo_library_rounded),
            title: Text('Chọn từ thư viện'),
          ),
        ),
        PopupMenuItem(
          value: 'camera',
          child: ListTile(
            leading: Icon(Icons.photo_camera_rounded),
            title: Text('Chụp ảnh'),
          ),
        ),
      ],
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: colors.textSecondary,
        ),
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        title: Text(
          widget.memberName.isEmpty ? 'Ảnh thành viên' : widget.memberName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
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
