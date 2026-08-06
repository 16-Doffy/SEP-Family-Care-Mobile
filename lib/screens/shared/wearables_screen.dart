import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/wear_quick_message_provider.dart';
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
      context.read<WearQuickMessageProvider>().load();
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
    final quick = context.watch<WearQuickMessageProvider>();
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
            _quickMessagesCard(quick),
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

  Widget _quickMessagesCard(WearQuickMessageProvider quick) => Container(
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
            const Icon(Icons.quickreply_rounded, color: AppColors.link),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tin nhắn nhanh trên wearable',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Khôi phục mặc định',
              onPressed: quick.saving ? null : _resetQuickMessages,
              icon: const Icon(Icons.restart_alt_rounded),
              color: AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 6),
        // KHÔNG hứa là danh sách này sẽ hiện trên đồng hồ: preset lưu bằng
        // flutter_secure_storage của CHÍNH thiết bị đang chạy app. Đồng hồ là
        // bản cài riêng, storage riêng → sửa ở đây không đổi được preset bên
        // đồng hồ. Muốn đồng bộ thật cần Wear Data Layer hoặc BE lưu theo tài
        // khoản (xem DE_XUAT_BE_WEARABLE_TOKEN_2026-08-04.md).
        Text(
          'Các câu gửi một chạm trong mục Tin nhắn. Danh sách lưu riêng trên '
          'từng thiết bị — sửa ở đây chỉ đổi cho máy này, đồng hồ cài app '
          'riêng thì phải chỉnh lại trên đồng hồ.',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (!quick.loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...quick.messages.asMap().entries.map((entry) {
            final index = entry.key;
            final text = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.progressTrack),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa',
                    visualDensity: VisualDensity.compact,
                    onPressed: quick.saving
                        ? null
                        : () => _editQuickMessage(index: index, initial: text),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: AppColors.link,
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    visualDensity: VisualDensity.compact,
                    onPressed: quick.saving
                        ? null
                        : () => _removeQuickMessage(index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.danger,
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: quick.loaded && quick.canAdd && !quick.saving
                ? () => _editQuickMessage()
                : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              quick.canAdd ? 'Thêm tin nhắn' : 'Tối đa 5 tin nhắn',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
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

  Future<void> _editQuickMessage({int? index, String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var canSave = initial.trim().isNotEmpty;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(index == null ? 'Thêm tin nhắn nhanh' : 'Sửa tin nhắn'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Đang chạy xe',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setDialogState(() => canSave = value.trim().isNotEmpty);
              },
              onSubmitted: (value) {
                final text = value.trim();
                if (text.isNotEmpty) Navigator.pop(ctx, text);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(ctx, controller.text.trim())
                    : null,
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || !mounted) return;

    final quick = context.read<WearQuickMessageProvider>();
    try {
      if (index == null) {
        await quick.add(result);
      } else {
        await quick.updateAt(index, result);
      }
      _snack('Đã lưu tin nhắn nhanh.', ok: true);
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _removeQuickMessage(int index) async {
    try {
      await context.read<WearQuickMessageProvider>().removeAt(index);
      _snack('Đã xóa tin nhắn nhanh.', ok: true);
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _resetQuickMessages() async {
    try {
      await context.read<WearQuickMessageProvider>().reset();
      _snack('Đã khôi phục tin nhắn nhanh mặc định.', ok: true);
    } catch (e) {
      _snack(e);
    }
  }

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
