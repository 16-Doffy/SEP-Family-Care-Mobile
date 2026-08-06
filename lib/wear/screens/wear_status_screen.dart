import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/gps_provider.dart';
import '../../providers/sos_provider.dart';
import '../../services/fall_detector_service.dart';
import '../wear_widgets.dart';

/// UC58 — Trạng thái đồng hồ: thông tin người đeo, vị trí, phát hiện té ngã,
/// đăng xuất.
///
/// Màn này từng mất đường điều hướng sau lần dựng lại giao diện đồng hồ. Nó là
/// **nơi duy nhất trên đồng hồ** có nút đăng xuất và công tắc phát hiện té ngã,
/// nên không xoá được — đã nối lại vào menu chính.
///
/// Thuật toán phát hiện đổi sang [FallDetectorService] dùng chung với app điện
/// thoại: bản cũ ở đây chỉ so một ngưỡng gia tốc (> 25 m/s²) nên đi xe máy đường
/// xóc cũng kích hoạt, lại **gửi SOS ngay lập tức** không có cách nào huỷ.
class WearStatusScreen extends StatefulWidget {
  const WearStatusScreen({super.key});

  @override
  State<WearStatusScreen> createState() => _WearStatusScreenState();
}

class _WearStatusScreenState extends State<WearStatusScreen> {
  bool _fallEnabled = false;
  bool _confirming = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    FallDetectorService.instance.stop();
    super.dispose();
  }

  void _toggleFall(bool enabled) {
    HapticFeedback.mediumImpact();
    setState(() {
      _fallEnabled = enabled;
      _error = null;
    });
    if (enabled) {
      FallDetectorService.instance.start(onFall: _onFallDetected);
    } else {
      FallDetectorService.instance.stop();
      _cancelCountdown();
    }
  }

  void _onFallDetected() {
    if (!mounted || _confirming || _sending) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _confirming = true;
      _countdown = 10;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 3 && _countdown > 0) HapticFeedback.mediumImpact();
      if (_countdown <= 0) {
        _timer?.cancel();
        _sendFallSos();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _confirming = false;
        _countdown = 0;
      });
    }
  }

  Future<void> _sendFallSos() async {
    setState(() {
      _confirming = false;
      _sending = true;
      _error = null;
    });
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final loc = context
        .read<GpsProvider>()
        .shares
        .where((s) => s.userId == myId && s.latitude != null)
        .firstOrNull;
    try {
      await context.read<SosProvider>().sendSos(
        message: 'Phát hiện té ngã từ đồng hồ — cần hỗ trợ ngay!',
        address: loc == null
            ? ''
            : 'GPS: ${loc.latitude?.toStringAsFixed(5)}, '
                  '${loc.longitude?.toStringAsFixed(5)}',
        latitude: loc?.latitude,
        longitude: loc?.longitude,
        sourceType: 'WEARABLE',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirming) return _countdownView();

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
            trailing: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WearPalette.sos,
                    ),
                  )
                : null,
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
          if (_error != null) ...[
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: WearPalette.sosSoft),
            ),
            const SizedBox(height: 6),
          ],
          WearTile(
            icon: Icons.location_on_rounded,
            title: 'Vị trí',
            subtitle: loc == null
                ? 'Chưa có vị trí'
                : '${loc.latitude?.toStringAsFixed(3)}, '
                      '${loc.longitude?.toStringAsFixed(3)}',
            color: loc == null ? WearPalette.faint : WearPalette.green,
          ),
          const SizedBox(height: 6),
          WearTile(
            icon: _fallEnabled ? Icons.shield_rounded : Icons.shield_outlined,
            title: 'Phát hiện té ngã',
            subtitle: _fallEnabled
                ? 'Đang bật · có 10 giây để huỷ'
                : 'Chạm để bật',
            color: _fallEnabled ? WearPalette.green : WearPalette.faint,
            filled: _fallEnabled,
            onTap: () => _toggleFall(!_fallEnabled),
            trailing: Icon(
              _fallEnabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 24,
              color: _fallEnabled ? WearPalette.green : WearPalette.faint,
            ),
          ),
          const SizedBox(height: 12),
          WearPillButton(
            label: 'Đăng xuất',
            icon: Icons.logout_rounded,
            color: WearPalette.faint,
            outlined: true,
            onTap: () {
              HapticFeedback.lightImpact();
              FallDetectorService.instance.stop();
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }

  /// Toàn màn hình thay vì dialog: trên màn tròn ~1.2 inch, dialog của Material
  /// bị cắt. Guideline Wear OS cũng khuyên dùng full-screen takeover.
  Widget _countdownView() {
    return WearPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.accessibility_new_rounded,
            size: 26,
            color: WearPalette.sos,
          ),
          const SizedBox(height: 6),
          const Text(
            'Bạn có ổn không?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Không phản hồi sẽ gửi SOS sau $_countdown giây',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: WearPalette.faint),
          ),
          const SizedBox(height: 10),
          // "Tôi ổn" là nút chống báo nhầm nên phải to và dễ bấm nhất.
          WearPillButton(
            label: 'Tôi ổn',
            icon: Icons.check_rounded,
            color: WearPalette.green,
            onTap: _cancelCountdown,
          ),
          const SizedBox(height: 7),
          WearPillButton(
            label: 'Gửi ngay',
            icon: Icons.sos_rounded,
            color: WearPalette.sos,
            onTap: () {
              _timer?.cancel();
              _sendFallSos();
            },
          ),
        ],
      ),
    );
  }
}
