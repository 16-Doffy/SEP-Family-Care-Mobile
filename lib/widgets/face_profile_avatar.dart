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
  });

  final FaceProfile profile;
  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = profile.previewImageUrl;
    Widget fallback() =>
        AvatarWidget(initial: initial, color: color, size: size);
    if (url == null) return fallback();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback(),
        ),
      ),
    );
  }
}
