import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/sos_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../services/sos_location.dart';
import '../wear_widgets.dart';

class WearSosScreen extends StatefulWidget {
  const WearSosScreen({super.key});

  @override
  State<WearSosScreen> createState() => _WearSosScreenState();
}

class _WearSosScreenState extends State<WearSosScreen>
    with SingleTickerProviderStateMixin {
  bool _holding = false;
  bool _sent = false;
  bool _sending = false;
  String? _sentAlertId;
  String? _error;
  String? _locationNotice;
  int _countdown = 2;
  Timer? _holdTimer;

  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_sent || _sending) return;
    HapticFeedback.mediumImpact();
    _pulse.stop();
    setState(() {
      _holding = true;
      _countdown = 2;
      _error = null;
    });
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _countdown--);
      HapticFeedback.heavyImpact();
      if (_countdown <= 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _onHoldEnd() {
    if (_sent || _sending) return;
    _holdTimer?.cancel();
    _pulse.repeat(reverse: true);
    setState(() {
      _holding = false;
      _countdown = 2;
    });
  }

  Future<void> _triggerSOS() async {
    setState(() {
      _sending = true;
      _holding = false;
      _locationNotice = null;
    });
    HapticFeedback.heavyImpact();

    try {
      final alertId = await context.read<SosProvider>().sendSos(
        message: 'SOS từ đồng hồ FamilyCare',
        address: 'Vị trí đang cập nhật',
        sourceType: 'WEARABLE',
      );
      if (!mounted) return;
      setState(() {
        _sentAlertId = alertId;
        _sent = true;
        _sending = false;
        _error = null;
      });
      // Không hỏi GPS trước khi tạo SOS vì có thể tốn tới 10 giây. Cảnh báo phải
      // được tạo ngay, sau đó đồng hồ tự đẩy vị trí của chính nó nếu lấy được.
      await _pushPosition(alertId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _holding = false;
        _countdown = 2;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _pulse.repeat(reverse: true);
    }
  }

  /// Best-effort, chạy sau khi SOS đã được tạo: cả hai hàm bên dưới đều không
  /// ném lỗi ra ngoài nên hỏng bước này cũng không ảnh hưởng cảnh báo.
  Future<void> _pushPosition(String alertId) async {
    setState(() => _locationNotice = 'Đang lấy vị trí…');
    final pos = await resolveWearableSosPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _locationNotice = 'Không lấy được GPS đồng hồ');
      return;
    }
    await context.read<SosProvider>().pushLocation(
      alertId,
      pos.lat,
      pos.lng,
      accuracy: pos.accuracy,
      sourceType: 'WEARABLE_GPS',
      deviceId: context.read<WearableProvider>().currentDevice?.id,
    );
    if (!mounted) return;
    setState(() => _locationNotice = 'Đã có vị trí');
  }

  Future<void> _confirmSafe() async {
    if (context.read<SosProvider>().sending) return;
    final alertId = _sentAlertId;
    if (alertId == null) {
      setState(() => _error = 'Không xác định được cảnh báo');
      return;
    }

    try {
      await context.read<SosProvider>().confirmSafety(alertId);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _sent = false;
      _sentAlertId = null;
      _countdown = 2;
      _error = null;
      _locationNotice = null;
    });
    _pulse.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sending) return _loadingView();
    if (_sent) return _sentView();

    final size = MediaQuery.of(context).size;
    final buttonSize = min(size.width, size.height) * 0.46;

    return WearPage(
      child: Column(
        children: [
          WearHeader(
            icon: Icons.sos_rounded,
            label: 'SOS',
            color: _holding ? WearPalette.sos : WearPalette.faint,
          ),
          const Spacer(),
          Text(
            _holding ? 'Thả để hủy' : 'Giữ 2 giây',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: WearPalette.faint),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTapDown: (_) => _onHoldStart(),
            onTapUp: (_) => _onHoldEnd(),
            onTapCancel: _onHoldEnd,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _holding ? 1.04 : _scale.value,
                child: child,
              ),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _holding ? WearPalette.sosPressed : WearPalette.sos,
                  boxShadow: [
                    BoxShadow(
                      color: WearPalette.sos.withValues(alpha: 0.45),
                      blurRadius: _holding ? 22 : 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emergency_share_rounded,
                      size: 27,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _holding ? '$_countdown' : 'SOS',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Nhà sẽ nhận cảnh báo ngay',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: WearPalette.faint),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const WearPage(
      child: WearEmptyState(
        icon: Icons.sos_rounded,
        title: 'Đang gửi SOS',
        subtitle: 'Chờ trong giây lát',
        color: WearPalette.sos,
      ),
    );
  }

  Widget _sentView() {
    return WearPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emergency_share_rounded,
            size: 38,
            color: WearPalette.sos,
          ),
          const SizedBox(height: 7),
          const Text(
            'SOS đã gửi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: WearPalette.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gia đình đã được báo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: WearPalette.faint),
          ),
          const SizedBox(height: 13),
          WearPillButton(
            label: 'Tôi an toàn',
            icon: Icons.check_rounded,
            color: WearPalette.green,
            onTap: _confirmSafe,
          ),
          if (_error != null) ...[
            const SizedBox(height: 5),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
          ],
          if (_locationNotice != null) ...[
            const SizedBox(height: 5),
            Text(
              _locationNotice!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: WearPalette.faint),
            ),
          ],
        ],
      ),
    );
  }
}
