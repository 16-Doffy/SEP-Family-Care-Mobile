import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../wear_widgets.dart';

/// UC51 — Xem và phản hồi cảnh báo SOS của người nhà, ngay trên đồng hồ.
///
/// Đây là **nơi duy nhất** trên đồng hồ phản hồi được cảnh báo của người khác:
/// `WearSosScreen` chỉ lo phát SOS của chính mình rồi `confirmSafety`, còn
/// `WearNotificationsScreen` chỉ hiển thị thông báo chứ không gọi được
/// `respond`/`resolveAlert`.
///
/// Màn này từng mất đường điều hướng sau lần dựng lại giao diện đồng hồ (không
/// tile nào trỏ tới), thành ra cả UC51 biến mất khỏi đồng hồ mà không ai thấy —
/// `flutter analyze` không báo, không test nào chạm tới `lib/wear/`.
class WearAlertsScreen extends StatefulWidget {
  const WearAlertsScreen({super.key});

  @override
  State<WearAlertsScreen> createState() => _WearAlertsScreenState();
}

class _WearAlertsScreenState extends State<WearAlertsScreen> {
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SosProvider>().fetchAlerts(),
    );
  }

  Future<void> _run(String alertId, Future<void> Function() action) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _busyId = alertId;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final myId = context.watch<AuthProvider>().user?.id;
    // Cảnh báo do chính mình phát thì không hiện nút "Đến ngay" — người phát
    // không tự đi cứu mình. Việc xác nhận an toàn nằm ở màn SOS.
    final others = sos.activeAlerts.where((a) => !a.isMine(myId)).toList();

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.emergency_share_rounded,
            label: 'Cảnh báo',
            color: WearPalette.sos,
            trailing: Text(
              '${others.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: WearPalette.sos,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: WearPalette.sosSoft),
            ),
            const SizedBox(height: 6),
          ],
          if (sos.loading && others.isEmpty)
            const WearEmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang tải cảnh báo',
              color: WearPalette.sos,
            )
          else if (others.isEmpty)
            const WearEmptyState(
              icon: Icons.verified_user_rounded,
              title: 'Cả nhà đang an toàn',
              subtitle: 'Chưa có cảnh báo nào',
              color: WearPalette.green,
            )
          else
            ...others.map((alert) => _alertCard(sos, alert)),
        ],
      ),
    );
  }

  Widget _alertCard(SosProvider sos, SosAlert alert) {
    final busy = _busyId == alert.id;
    final canResolve =
        context.watch<AuthProvider>().user?.canResolveSos == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearTile(
            icon: Icons.sos_rounded,
            title: alert.senderName.isEmpty ? 'Thành viên' : alert.senderName,
            subtitle: alert.message.isEmpty
                ? (alert.address.isEmpty ? 'Cần trợ giúp' : alert.address)
                : alert.message,
            color: WearPalette.sos,
            filled: true,
          ),
          const SizedBox(height: 6),
          WearPillButton(
            label: 'Tôi đang đến',
            icon: Icons.directions_run_rounded,
            color: WearPalette.green,
            loading: busy,
            onTap: busy
                ? null
                : () => _run(
                    alert.id,
                    () => sos.respond(
                      alert.id,
                      'VIEWED',
                      message: 'Tôi đang đến',
                    ),
                  ),
          ),
          // Chỉ Trưởng/Phó nhóm mới đóng được cảnh báo — BE trả 403 cho
          // thành viên thường (PATCH .../resolve).
          if (canResolve) ...[
            const SizedBox(height: 6),
            WearPillButton(
              label: 'Đã xử lý xong',
              icon: Icons.check_rounded,
              color: WearPalette.faint,
              outlined: true,
              onTap: busy
                  ? null
                  : () => _run(alert.id, () => sos.resolveAlert(alert.id)),
            ),
          ],
        ],
      ),
    );
  }
}
