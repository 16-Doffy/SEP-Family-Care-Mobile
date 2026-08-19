import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../services/sos_guard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Cài đặt SOS của gia đình — 4 công tắc khớp UpdateSosSettingsDto.
///
/// **2026-08-19**: BE đã nới guard `PATCH .../sos/settings` cho cả 3 vai trò
/// (FAMILY_MANAGER / DEPUTY_MEMBER / FAMILY_MEMBER — xác nhận qua Swagger),
/// nên 4 công tắc này giờ mọi thành viên đều sửa được. Danh bạ khẩn cấp
/// (thêm/sửa/xoá) vẫn Manager/Deputy-only — Swagger 2 endpoint đó chưa đổi.
class SosSettingsScreen extends StatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  State<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends State<SosSettingsScreen>
    with WidgetsBindingObserver {
  SosGuardStatus _guardStatus = SosGuardStatus.off;
  bool _guardLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final sos = context.read<SosProvider>();
        sos.fetchSettings();
        sos.fetchEmergencyContacts();
        _loadGuardStatus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Bật/tắt EmergencySosWatcherService chỉ làm được trong Cài đặt hệ thống
  // (Trợ năng), ngoài app — quay lại màn này phải đọc lại trạng thái thật,
  // không thì công tắc hiện sai so với thực tế.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _loadGuardStatus();
  }

  Future<void> _loadGuardStatus() async {
    setState(() => _guardLoading = true);
    try {
      final status = await SosGuardService.instance.getStatus();
      if (!mounted) return;
      setState(() => _guardStatus = status);
    } finally {
      if (mounted) setState(() => _guardLoading = false);
    }
  }

  Future<void> _setGuard({bool? shakeEnabled, bool? fallEnabled}) async {
    final nextShake = shakeEnabled ?? _guardStatus.shakeEnabled;
    final nextFall = fallEnabled ?? _guardStatus.fallEnabled;
    setState(() {
      _guardLoading = true;
      _guardStatus = SosGuardStatus(
        running: nextShake || nextFall,
        shakeEnabled: nextShake,
        fallEnabled: nextFall,
      );
    });
    try {
      await SosGuardService.instance.start(
        shakeEnabled: nextShake,
        fallEnabled: nextFall,
      );
      // Không gọi lại _loadGuardStatus() ở đây: startForegroundService() phía Kotlin
      // chạy bất đồng bộ, onStartCommand() có thể chưa kịp cập nhật cờ trạng thái khi
      // đọc lại ngay — đọc phải giá trị cũ rồi ghi đè mất trạng thái optimistic vừa bật
      // đúng ở trên (đo được trên máy Oppo thật 12/08: công tắc nhảy về OFF dù service
      // đã chạy). Tin vào state optimistic; chỉ đồng bộ lại khi có lỗi thật (nhánh catch).
      if (!mounted) return;
      setState(() => _guardLoading = false);
    } catch (e) {
      await _loadGuardStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không bật được bảo vệ SOS: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      await SosGuardService.instance.openBatteryOptimizationSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được cài đặt pin: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _openFullScreenIntentSettings() async {
    try {
      await SosGuardService.instance.openFullScreenIntentSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được cài đặt quyền: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await SosGuardService.instance.openAccessibilitySettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được Cài đặt Trợ năng: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showContactForm([EmergencyContact? contact]) async {
    final name = TextEditingController(text: contact?.contactName ?? '');
    final phone = TextEditingController(text: contact?.phoneNumber ?? '');
    final relation = TextEditingController(
      text: contact?.relationshipNote ?? '',
    );
    final priority = TextEditingController(
      text: contact?.priorityOrder?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact == null ? 'Thêm liên hệ khẩn cấp' : 'Sửa liên hệ',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Tên liên hệ'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tên liên hệ'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập số điện thoại'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: relation,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Quan hệ/ghi chú (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: priority,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Thứ tự ưu tiên (từ 1)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final value = int.tryParse(v.trim());
                  return value == null || value < 1
                      ? 'Thứ tự ưu tiên phải từ 1'
                      : null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final order = priority.text.trim().isEmpty
                        ? null
                        : int.parse(priority.text.trim());
                    try {
                      final sos = context.read<SosProvider>();
                      if (contact == null) {
                        await sos.addEmergencyContact(
                          contactName: name.text,
                          phoneNumber: phone.text,
                          relationshipNote: relation.text,
                          priorityOrder: order,
                        );
                      } else {
                        await sos.updateEmergencyContact(
                          contact.id,
                          contactName: name.text,
                          phoneNumber: phone.text,
                          relationshipNote: relation.text,
                          priorityOrder: order,
                        );
                      }
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext, true);
                      }
                    } catch (e) {
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: Text(
                    contact == null ? 'Thêm liên hệ' : 'Lưu thay đổi',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    relation.dispose();
    priority.dispose();
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa liên hệ khẩn cấp?'),
        content: Text('Xóa ${contact.contactName} khỏi danh bạ gia đình.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<SosProvider>().deleteEmergencyContact(contact.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _toggle(SosSettings next) async {
    try {
      await context.read<SosProvider>().updateSettings(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không lưu được cài đặt: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    final s = sos.settings ?? const SosSettings();
    // Danh bạ khẩn cấp (thêm/sửa/xoá) vẫn Manager/Deputy-only theo Swagger.
    final canEditContacts =
        context.watch<AuthProvider>().user?.canResolveSos ?? false;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Cài đặt SOS',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: sos.settingsLoading && sos.settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _deviceGuardSection(),
                _emergencyWatcherSection(),
                _tile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Bật SOS',
                  subtitle: 'Cho phép gửi cảnh báo khẩn cấp trong gia đình.',
                  value: s.isEnabled,
                  onChanged: (v) => _toggle(s.copyWith(isEnabled: v)),
                ),
                _tile(
                  icon: Icons.groups_rounded,
                  title: 'Báo cho tất cả thành viên',
                  subtitle:
                      'Khi có SOS, gửi thông báo tới mọi người trong nhà.',
                  value: s.notifyAllMembers,
                  onChanged: (v) => _toggle(s.copyWith(notifyAllMembers: v)),
                ),
                _tile(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Tự cảnh báo khi phát hiện té ngã',
                  // Cài đặt cấp gia đình. Muốn điện thoại này theo dõi nền thì
                  // bật thêm công tắc cục bộ ở nhóm "Bảo vệ SOS trên máy này".
                  subtitle:
                      'Điện thoại dùng gia tốc kế để nhận biết cú ngã, có 10 '
                      'giây để bạn bấm "Tôi ổn" trước khi gửi. Cài đặt này áp '
                      'dụng cho quy tắc SOS của gia đình.',
                  value: s.autoCreateAlertFromFall,
                  onChanged: (v) =>
                      _toggle(s.copyWith(autoCreateAlertFromFall: v)),
                ),
                _tile(
                  icon: Icons.location_on_rounded,
                  title: 'Bắt buộc chia sẻ vị trí',
                  subtitle:
                      'Yêu cầu đính kèm vị trí khi gửi SOS để người nhà tìm nhanh.',
                  value: s.locationRequired,
                  onChanged: (v) => _toggle(s.copyWith(locationRequired: v)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Danh bạ khẩn cấp',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (canEditContacts)
                      IconButton(
                        tooltip: 'Thêm liên hệ',
                        onPressed: _showContactForm,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                  ],
                ),
                if (sos.emergencyContacts.isEmpty)
                  _note('Gia đình chưa có liên hệ khẩn cấp.')
                else
                  ...sos.emergencyContacts.map(
                    (contact) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.dangerLight,
                          child: const Icon(
                            Icons.phone_in_talk_outlined,
                            color: AppColors.danger,
                          ),
                        ),
                        title: Text(contact.contactName),
                        subtitle: Text(
                          [
                            contact.phoneNumber,
                            if (contact.relationshipNote?.isNotEmpty == true)
                              contact.relationshipNote!,
                            if (contact.priorityOrder != null)
                              'Ưu tiên ${contact.priorityOrder}',
                          ].join(' · '),
                        ),
                        trailing: canEditContacts
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showContactForm(contact);
                                  } else if (value == 'delete') {
                                    _deleteContact(contact);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Chỉnh sửa'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Xóa'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _deviceGuardSection() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.progressTrack),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.sos),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bảo vệ SOS trên máy này',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_guardLoading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Khi bật, Android sẽ hiển thị thông báo thường trực để Family Care '
          'có thể theo dõi cảm biến kể cả lúc khóa màn hình.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.vibration_rounded,
          title: 'Lắc mạnh để mở SOS',
          subtitle:
              'Lắc điện thoại nhiều nhịp trong khoảng ngắn để mở màn SOS đếm ngược 3 giây.',
          value: _guardStatus.shakeEnabled,
          onChanged: _guardLoading ? null : (v) => _setGuard(shakeEnabled: v),
        ),
        _tile(
          icon: Icons.accessibility_new_rounded,
          title: 'Theo dõi té ngã khi chạy nền',
          subtitle:
              'Dùng gia tốc kế trong foreground service. Vẫn giữ màn đếm ngược để hủy báo nhầm.',
          value: _guardStatus.fallEnabled,
          onChanged: _guardLoading ? null : (v) => _setGuard(fallEnabled: v),
        ),
        if ((_guardStatus.shakeEnabled || _guardStatus.fallEnabled) &&
            !_guardStatus.fullScreenIntentGranted)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa có quyền mở màn hình khẩn cấp. Khi lắc/té ngã, máy chỉ '
                  'bắn được thông báo phải chạm tay, không tự mở màn SOS đè '
                  'lên màn khóa được.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.dangerDark,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openFullScreenIntentSettings,
                    child: const Text('Cấp quyền ngay'),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openBatterySettings,
            icon: const Icon(Icons.battery_saver_rounded),
            label: const Text('Mở cài đặt tối ưu pin'),
          ),
        ),
      ],
    ),
  );

  // Tách riêng khỏi _deviceGuardSection() vì đây là cơ chế kích hoạt HOÀN
  // TOÀN khác (bám theo màn Emergency SOS của hệ thống, không phải cảm biến
  // gia tốc), độc lập bật/tắt, và app không tự bật hộ được — chỉ mở đúng màn
  // Cài đặt hệ thống để người dùng tự bật.
  Widget _emergencyWatcherSection() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.progressTrack),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emergency_share_rounded, color: AppColors.sos),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bám theo Emergency SOS của máy',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _guardStatus.emergencyWatcherEnabled
                    ? AppColors.safeLight
                    : AppColors.neutralBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _guardStatus.emergencyWatcherEnabled ? 'Đã bật' : 'Chưa bật',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _guardStatus.emergencyWatcherEnabled
                      ? AppColors.safeDark
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Khi máy tự mở màn Cấp cứu khẩn cấp của Android (ví dụ sau khi bấm '
          'nút nguồn nhiều lần), Family Care tự gửi SOS ngay cho gia đình — '
          'không cần mở app, không đếm ngược. Chỉ hoạt động trên một số máy '
          'Oppo/Realme/OnePlus (ColorOS); máy hãng khác bật công tắc này '
          'cũng không có tác dụng gì.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          'Cần bật thủ công trong Cài đặt hệ thống > Trợ năng — app không tự '
          'bật hộ được (quyền hệ thống).',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openAccessibilitySettings,
            icon: const Icon(Icons.accessibility_new_rounded),
            label: Text(
              _guardStatus.emergencyWatcherEnabled
                  ? 'Mở cài đặt Trợ năng'
                  : 'Bật ngay trong Cài đặt Trợ năng',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
    ),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: Icon(icon, color: AppColors.sos),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
      ),
      value: value,
      onChanged: onChanged,
    ),
  );
}
