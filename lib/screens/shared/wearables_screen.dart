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

  /// Đủ 5 giá trị `CreateSensorEventDto.eventType` của BE.
  /// `HEART_RATE_ABNORMAL` là giá trị BE mới bổ sung (bản OpenAPI 04/08/2026);
  /// trước đó FE mới chỉ gửi được 2 loại.
  ///
  /// `rawValue` là JSON tự do ("Số liệu thô từ cảm biến, tùy thiết bị") nên mỗi
  /// loại gửi đúng số đo có ý nghĩa với nó, thay vì nhồi chung một mẫu.
  static const _eventTypes = <_SensorEventType>[
    _SensorEventType(
      code: 'SOS_BUTTON_PRESSED',
      label: 'Bấm nút SOS',
      hint: 'Người đeo chủ động bấm nút khẩn cấp',
      icon: Icons.sos_rounded,
      severity: 'CRITICAL',
      rawValue: {'source': 'wearos-emulator', 'heartRate': 120, 'battery': 86},
    ),
    _SensorEventType(
      code: 'FALL_DETECTED',
      label: 'Phát hiện té ngã',
      hint: 'Gia tốc kế thấy rơi tự do rồi va đập',
      icon: Icons.accessibility_new_rounded,
      severity: 'HIGH',
      rawValue: {'source': 'wearos-emulator', 'gForce': 3.2, 'heartRate': 132},
    ),
    _SensorEventType(
      code: 'HEART_RATE_ABNORMAL',
      label: 'Nhịp tim bất thường',
      hint: 'Nhịp tim vượt ngoài ngưỡng an toàn',
      icon: Icons.monitor_heart_rounded,
      severity: 'HIGH',
      rawValue: {
        'source': 'wearos-emulator',
        'heartRate': 156,
        'restingHeartRate': 72,
        'durationSeconds': 180,
      },
    ),
    _SensorEventType(
      code: 'HARD_IMPACT',
      label: 'Va đập mạnh',
      hint: 'Cú va chạm lớn, có thể do tai nạn',
      icon: Icons.crisis_alert_rounded,
      severity: 'HIGH',
      rawValue: {'source': 'wearos-emulator', 'gForce': 6.8, 'heartRate': 141},
    ),
    _SensorEventType(
      code: 'ABNORMAL_MOVEMENT',
      label: 'Chuyển động bất thường',
      hint: 'Không cử động lâu, hoặc cử động lạ',
      icon: Icons.directions_walk_rounded,
      severity: 'MEDIUM',
      rawValue: {
        'source': 'wearos-emulator',
        'stillSeconds': 900,
        'heartRate': 58,
      },
    ),
  ];

  // `WearableProvider.fetchEvents` trả thẳng danh sách chứ không giữ state, nên
  // màn tự giữ. Trước đây hàm này không có nơi nào gọi — lịch sử sự kiện đã
  // wire ở provider nhưng chưa từng hiển thị.
  List<WearableEvent> _events = const [];
  bool _eventsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final wp = context.read<WearableProvider>();
      context.read<WearQuickMessageProvider>().load();
      await wp.fetchCurrentDevice();
      final id = wp.currentDevice?.id;
      if (id != null && mounted) await _loadEvents(id);
    });
  }

  Future<void> _loadEvents(String deviceId) async {
    setState(() => _eventsLoading = true);
    try {
      final list = await context.read<WearableProvider>().fetchEvents(deviceId);
      if (mounted) setState(() => _events = list);
    } catch (_) {
      // Lịch sử sự kiện chỉ là thông tin phụ — hỏng thì để trống, không chặn
      // các thao tác ghép nối/ngắt kết nối phía trên.
      if (mounted) setState(() => _events = const []);
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
    }
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
            else ...[
              _connectedCard(device),
              const SizedBox(height: 12),
              _eventHistoryCard(device),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventHistoryCard(WearableDevice device) => Container(
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
            const Icon(Icons.history_rounded, color: AppColors.link),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sự kiện cảm biến gần đây',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _eventsLoading ? null : () => _loadEvents(device.id),
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_eventsLoading && _events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          Text(
            'Chưa có sự kiện nào. Dùng "Giả lập sự kiện cảm biến" ở trên để '
            'thử luồng cảnh báo.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          )
        else
          ..._events.take(10).map(_eventRow),
      ],
    ),
  );

  Widget _eventRow(WearableEvent e) {
    final type = _eventTypes.where((t) => t.code == e.eventType).firstOrNull;
    final color = switch (e.severity.toUpperCase()) {
      'CRITICAL' => AppColors.danger,
      'HIGH' => AppColors.danger,
      'MEDIUM' => AppColors.amberText,
      _ => AppColors.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(type?.icon ?? Icons.sensors_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // BE có thể thêm eventType mới trước khi FE kịp cập nhật →
                  // hiện mã gốc thay vì "Không rõ", để còn đối chiếu được.
                  type?.label ?? e.eventType,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_severityLabel(e.severity)} · ${_fmtTime(e.detectedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _severityLabel(String s) => switch (s.toUpperCase()) {
    'CRITICAL' => 'Nguy cấp',
    'HIGH' => 'Cao',
    'MEDIUM' => 'Trung bình',
    'LOW' => 'Thấp',
    _ => s,
  };

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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickTestEvent(device),
            icon: const Icon(Icons.sensors_rounded, size: 18),
            label: const Text('Giả lập sự kiện cảm biến'),
          ),
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

  Future<void> _pickTestEvent(WearableDevice device) async {
    final picked = await showModalBottomSheet<_SensorEventType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Giả lập sự kiện từ thiết bị đeo',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ..._eventTypes.map(
              (e) => ListTile(
                leading: Icon(e.icon, color: AppColors.danger),
                title: Text(
                  e.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  e.hint,
                  style: GoogleFonts.inter(fontSize: 12.5),
                ),
                onTap: () => Navigator.pop(ctx, e),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _testEvent(device, picked);
  }

  Future<void> _testEvent(WearableDevice device, _SensorEventType type) async {
    try {
      final result = await context.read<WearableProvider>().createEvent(
        device.id,
        eventType: type.code,
        severity: type.severity,
        rawValue: type.rawValue,
      );
      if (!mounted) return;
      // Sự kiện vừa gửi phải xuất hiện ngay trong lịch sử bên dưới.
      await _loadEvents(device.id);
      if (!mounted) return;
      if (result.alertCreated) {
        _showAlertCreated(result.alertId);
      } else {
        // alertCreated=false là hành vi hợp lệ: BE chỉ tạo cảnh báo với một số
        // loại sự kiện / mức độ, không phải mọi sự kiện đều báo động.
        _snack(
          'Đã gửi "${type.label}" — BE không tạo cảnh báo cho sự kiện này.',
          ok: true,
        );
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

/// Một loại sự kiện cảm biến của thiết bị đeo, khớp `CreateSensorEventDto`.
class _SensorEventType {
  final String code;
  final String label;
  final String hint;
  final IconData icon;
  final String severity;
  final Map<String, dynamic> rawValue;

  const _SensorEventType({
    required this.code,
    required this.label,
    required this.hint,
    required this.icon,
    required this.severity,
    required this.rawValue,
  });
}
