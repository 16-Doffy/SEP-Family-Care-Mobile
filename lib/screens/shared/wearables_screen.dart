import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/wearable_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

class WearablesScreen extends StatefulWidget {
  const WearablesScreen({super.key});

  @override
  State<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends State<WearablesScreen> {
  static const _typeLabels = {
    'SMARTWATCH': 'Đồng hồ thông minh',
    'GPS_TRACKER': 'Thiết bị định vị',
    'BLE_DEVICE': 'Thiết bị Bluetooth',
    'SIMULATED_DEVICE': 'Thiết bị mô phỏng',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WearableProvider>().fetchCurrentDevice();
    });
  }

  void _snack(Object e, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WearableProvider>();
    final device = wp.currentDevice;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Thiết bị đeo',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<WearableProvider>().fetchCurrentDevice(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _introCard(device),
            const SizedBox(height: 12),
            if (wp.loading && device == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (device == null)
              _notConnectedCard(wp.error)
            else
              _connectedCard(device),
          ],
        ),
      ),
    );
  }

  Widget _introCard(WearableDevice? device) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.link.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.link.withValues(alpha: 0.16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          device == null ? Icons.watch_outlined : Icons.watch_rounded,
          color: AppColors.link,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device == null
                    ? 'Chưa kết nối wearable'
                    : 'Đã kết nối wearable',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mobile app đang đăng nhập thay mặt user để kết nối thiết bị. Mỗi tài khoản chỉ có một wearable đang kết nối.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _notConnectedCard(String? error) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.watch_off_rounded,
          size: 54,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 12),
        Text(
          error == null
              ? 'Chưa kết nối wearable'
              : 'Không tải được trạng thái wearable',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link),
            onPressed: _connectSimulator,
            icon: const Icon(Icons.link_rounded, color: Colors.white),
            label: Text(
              'Kết nối wearable',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _connectedCard(WearableDevice device) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.watch_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _typeLabels[device.deviceType] ?? device.deviceType,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _statusChip(device),
          ],
        ),
        const SizedBox(height: 14),
        _infoRow('Device ID', device.id),
        _infoRow('Identifier', device.deviceIdentifier),
        _infoRow('Last seen', _fmtTime(device.lastSeenAt)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _flagChip('GPS', device.gpsEnabled)),
            const SizedBox(width: 8),
            Expanded(child: _flagChip('SOS', device.sosEnabled)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _testEvent(device, sos: true),
                icon: const Icon(Icons.sos_rounded, size: 18),
                label: const Text('Test SOS'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _testEvent(device, sos: false),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('Fall'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => _confirmUnpair(device),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Ngắt kết nối'),
          ),
        ),
      ],
    ),
  );

  Widget _statusChip(WearableDevice d) {
    final (label, color) = d.isPaired
        ? ('Đã kết nối', AppColors.success)
        : d.isLost
        ? ('Mất kết nối', AppColors.danger)
        : ('Chưa kết nối', AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Không rõ' : value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _flagChip(String label, bool enabled) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: (enabled ? AppColors.success : AppColors.textMuted).withValues(
        alpha: 0.1,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: enabled ? AppColors.success : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.success : AppColors.textMuted,
          ),
        ),
      ],
    ),
  );

  Future<void> _connectSimulator() async {
    try {
      await context.read<WearableProvider>().pairDevice(
        deviceName: 'Wear OS Simulator',
        deviceType: 'SIMULATED_DEVICE',
        deviceIdentifier: 'wearos-emulator-001',
        gpsEnabled: true,
        sosEnabled: true,
      );
      _snack('Wearable simulator đã được kết nối.', ok: true);
    } catch (e) {
      _snack(e);
    }
  }

  void _confirmUnpair(WearableDevice device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngắt kết nối wearable?'),
        content: Text(
          'Ngắt kết nối "${device.deviceName}" khỏi tài khoản này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<WearableProvider>().unpairDevice(device.id);
                _snack('Đã ngắt kết nối wearable.', ok: true);
              } catch (e) {
                _snack(e);
              }
            },
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );
  }

  Future<void> _testEvent(WearableDevice device, {required bool sos}) async {
    try {
      final result = await context.read<WearableProvider>().createEvent(
        device.id,
        eventType: sos ? 'SOS_BUTTON_PRESSED' : 'FALL_DETECTED',
        severity: 'HIGH',
        rawValue: sos
            ? {'source': 'wearos-emulator', 'heartRate': 120, 'battery': 86}
            : {'source': 'wearos-emulator', 'gForce': 3.2, 'heartRate': 132},
      );
      if (!mounted) return;
      if (result.alertCreated) {
        _showAlertCreated(result.alertId);
      } else {
        _snack('Đã gửi sự kiện wearable.', ok: true);
      }
    } catch (e) {
      _snack(e);
    }
  }

  void _showAlertCreated(String? alertId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đã tạo cảnh báo SOS'),
        content: Text(
          alertId == null
              ? 'Sự kiện wearable đã tạo cảnh báo mới.'
              : 'Alert ID: $alertId',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime? t) {
    if (t == null) return 'Không rõ';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }
}
