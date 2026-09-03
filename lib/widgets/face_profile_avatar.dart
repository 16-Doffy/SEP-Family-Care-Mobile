import 'package:flutter/material.dart';

import '../providers/face_profile_provider.dart';
import 'avatar_widget.dart';

/// Ảnh preview của Face Profile nếu BE có; mọi lỗi tải ảnh đều fallback avatar.
class FaceProfileAvatar extends StatelessWidget {
  const FaceProfileAvatar({
    super.key,
    required this.profile,
    required this.initial,
    required this.color,
    required this.size,
    this.onTap,
  });

  final FaceProfile profile;
  final String initial;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = profile.previewImageUrl;
    Widget fallback() =>
        AvatarWidget(initial: initial, color: color, size: size);
    final avatar = url == null
        ? fallback()
        : ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
            ),
          );
    if (onTap == null || url == null) return avatar;
    return Semantics(
      button: true,
      label: 'Mở ảnh khuôn mặt kích thước lớn',
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

/// Xem preview khuôn mặt ở kích thước lớn. [InteractiveViewer] cho phép
/// pinch-to-zoom và kéo ảnh; không cần tải lại dữ liệu Face Profile.
Future<void> showFaceProfilePreview(BuildContext context, String imageUrl) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const CircularProgressIndicator(color: Colors.white),
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Đóng',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
