import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/wearable_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Quản lý thiết bị đeo (đồng hồ/định vị) đã ghép với gia đình.
///
/// Ghép/gỡ/đổi cấu hình chỉ dành cho Manager/Deputy (giống các config gia đình
/// khác). Member xem read-only.
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

  static const _eventLabels = {
    'SOS_BUTTON_PRESSED': 'Nhấn nút SOS',
    'FALL_DETECTED': 'Phát hiện té ngã',
    'HARD_IMPACT': 'Va đập mạnh',
    'ABNORMAL_MOVEMENT': 'Chuyển động bất thường',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WearableProvider>().fetchDevices();
      context.read<FamilyProvider>().fetchMembers();
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
    final canManage =
        context.watch<AuthProvider>().user?.canResolveSos ?? false;

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
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.link,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Ghép thiết bị',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _showPairSheet,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => context.read<WearableProvider>().fetchDevices(),
        child: wp.loading && wp.devices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : wp.devices.isEmpty
            ? _empty(wp.error)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!canManage) _note(),
                  ...wp.devices.map((d) => _deviceCard(d, canManage)),
                ],
              ),
      ),
    );
  }

  Widget _empty(String? error) => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      const Icon(Icons.watch_outlined, size: 56, color: AppColors.textMuted),
      const SizedBox(height: 12),
      Center(
        child: Text(
          error == null
              ? 'Chưa ghép thiết bị đeo nào.'
              : 'Không tải được danh sách thiết bị.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ),
      ),
    ],
  );

  Widget _note() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'Chỉ Trưởng nhóm hoặc Phó nhóm mới ghép/gỡ thiết bị. Bạn đang xem ở chế '
      'độ chỉ đọc.',
      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
    ),
  );

  Widget _deviceCard(WearableDevice d, bool canManage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                d.deviceType == 'GPS_TRACKER'
                    ? Icons.location_searching_rounded
                    : Icons.watch_rounded,
                color: d.isPaired ? AppColors.link : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.deviceName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_typeLabels[d.deviceType] ?? d.deviceType}'
                      '${d.ownerName != null ? ' · ${d.ownerName}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(d),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Chia sẻ vị trí (GPS)',
              style: GoogleFonts.inter(fontSize: 13.5),
            ),
            value: d.gpsEnabled,
            onChanged: canManage ? (v) => _update(d.id, gpsEnabled: v) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Cho phép gửi SOS',
              style: GoogleFonts.inter(fontSize: 13.5),
            ),
            value: d.sosEnabled,
            onChanged: canManage ? (v) => _update(d.id, sosEnabled: v) : null,
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showEvents(d),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Lịch sử sự kiện'),
              ),
              const Spacer(),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _confirmUnpair(d),
                  icon: const Icon(
                    Icons.link_off_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: Text(
                    'Gỡ',
                    style: GoogleFonts.inter(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(WearableDevice d) {
    final (label, color) = d.isPaired
        ? ('Đã ghép', AppColors.success)
        : d.isLost
        ? ('Mất kết nối', AppColors.danger)
        : ('Chưa ghép', AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _update(String id, {bool? gpsEnabled, bool? sosEnabled}) async {
    try {
      await context.read<WearableProvider>().updateDevice(
        id,
        gpsEnabled: gpsEnabled,
        sosEnabled: sosEnabled,
      );
    } catch (e) {
      _snack(e);
    }
  }

  void _confirmUnpair(WearableDevice d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ thiết bị?'),
        content: Text('Gỡ "${d.deviceName}" khỏi gia đình?'),
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
                await context.read<WearableProvider>().unpairDevice(d.id);
                _snack('Đã gỡ thiết bị', ok: true);
              } catch (e) {
                _snack(e);
              }
            },
            child: const Text('Gỡ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEvents(WearableDevice d) async {
    List<WearableEvent> events = [];
    try {
      events = await context.read<WearableProvider>().fetchEvents(d.id);
    } catch (e) {
      _snack(e);
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sự kiện — ${d.deviceName}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Chưa có sự kiện nào.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView(
                    shrinkWrap: true,
                    children: events
                        .map(
                          (e) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _eventLabels[e.eventType] ?? e.eventType,
                              style: GoogleFonts.inter(fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '${e.severity} · ${_fmtTime(e.detectedAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPairSheet() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    var type = 'SMARTWATCH';
    var gps = true;
    var sos = true;
    String? ownerId;
    final members = context
        .read<FamilyProvider>()
        .members
        .where((m) => m.isActive)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghép thiết bị đeo',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thiết bị',
                    hintText: 'VD: Đồng hồ của bà',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã thiết bị (serial / MAC)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Loại thiết bị'),
                  items: _typeLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setS(() => type = v ?? 'SMARTWATCH'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Người dùng (tùy chọn)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Không gán —'),
                    ),
                    ...members.map(
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ),
                  ],
                  onChanged: (v) => setS(() => ownerId = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chia sẻ vị trí (GPS)'),
                  value: gps,
                  onChanged: (v) => setS(() => gps = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho phép gửi SOS'),
                  value: sos,
                  onChanged: (v) => setS(() => sos = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final ident = idCtrl.text.trim();
                      if (name.isEmpty || ident.isEmpty) {
                        _snack('Nhập tên và mã thiết bị');
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await context.read<WearableProvider>().pairDevice(
                          deviceName: name,
                          deviceType: type,
                          deviceIdentifier: ident,
                          gpsEnabled: gps,
                          sosEnabled: sos,
                          ownerMemberId: ownerId,
                        );
                        _snack('Đã ghép thiết bị', ok: true);
                      } catch (e) {
                        _snack(e);
                      }
                    },
                    child: Text(
                      'Ghép',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime? t) {
    if (t == null) return 'Không rõ';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }
}
