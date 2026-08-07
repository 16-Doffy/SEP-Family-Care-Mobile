import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/gps_provider.dart';
import '../../services/fall_detector_service.dart';
import '../wear_widgets.dart';

/// Trạng thái đồng hồ: người đeo, gia đình, vị trí, đăng xuất.
///
/// Đây là **nơi duy nhất trên đồng hồ có nút đăng xuất** — đừng gỡ tile này
/// khỏi menu, màn sẽ thành code chết như đã từng xảy ra.
///
/// Phần phát hiện té ngã trước ở đây **đã chuyển sang** `WearSensorSosScreen`:
/// theo spec Wear OS (Discord 04/08/2026), SOS tự động phải đi qua endpoint
/// wearable event chứ không gọi thẳng `/sos/alerts`. Giữ hai bản song song là
/// chắc chắn lệch nhau.
class WearStatusScreen extends StatefulWidget {
  const WearStatusScreen({super.key});

  @override
  State<WearStatusScreen> createState() => _WearStatusScreenState();
}

class _WearStatusScreenState extends State<WearStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final myId = user?.id ?? '';
    final loc = context
        .watch<GpsProvider>()
        .shares
        .where((s) => s.userId == myId && s.latitude != null)
        .firstOrNull;

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.watch_rounded,
            label: user?.name.isNotEmpty == true ? user!.name : 'Đồng hồ',
            color: WearPalette.green,
          ),
          const SizedBox(height: 8),
          // Tên gia đình + trạng thái kết nối: gộp từ WearConnectScreen (màn đó
          // chỉ hiển thị tĩnh, không có thao tác nào, nên đã xoá thay vì thêm
          // một tile nữa vào menu đồng hồ).
          WearTile(
            icon: Icons.home_rounded,
            title: user?.familyName.trim().isNotEmpty == true
                ? user!.familyName
                : 'FamilyCare',
            subtitle: user == null ? 'Cần ghép nối' : 'Đã kết nối',
            color: user == null ? WearPalette.faint : WearPalette.blue,
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: Icons.location_on_rounded,
            title: 'Vị trí',
            subtitle: loc == null
                ? 'Chưa có vị trí'
                : '${loc.latitude?.toStringAsFixed(3)}, '
                      '${loc.longitude?.toStringAsFixed(3)}',
            color: loc == null ? WearPalette.faint : WearPalette.green,
          ),
          const SizedBox(height: 12),
          WearPillButton(
            label: 'Đăng xuất',
            icon: Icons.logout_rounded,
            color: WearPalette.faint,
            outlined: true,
            onTap: () {
              HapticFeedback.lightImpact();
              // Dừng cảm biến trước khi mất phiên, tránh còn stream chạy nền.
              FallDetectorService.instance.stop();
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }
}
