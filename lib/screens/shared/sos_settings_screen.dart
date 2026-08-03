import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Cài đặt SOS của gia đình — 4 công tắc khớp UpdateSosSettingsDto.
///
/// Chỉ Manager/Deputy được đổi (config cấp gia đình, cùng nhóm quyền với
/// canResolveSos). Member xem read-only kèm ghi chú.
class SosSettingsScreen extends StatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  State<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends State<SosSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final sos = context.read<SosProvider>();
        sos.fetchSettings();
        sos.fetchEmergencyContacts();
      }
    });
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
    final canEdit = context.watch<AuthProvider>().user?.canResolveSos ?? false;

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
                if (!canEdit)
                  _note(
                    'Chỉ Trưởng nhóm hoặc Phó nhóm mới thay đổi được cài đặt '
                    'SOS. Bạn đang xem ở chế độ chỉ đọc.',
                  ),
                _tile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Bật SOS',
                  subtitle: 'Cho phép gửi cảnh báo khẩn cấp trong gia đình.',
                  value: s.isEnabled,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(isEnabled: v))
                      : null,
                ),
                _tile(
                  icon: Icons.groups_rounded,
                  title: 'Báo cho tất cả thành viên',
                  subtitle:
                      'Khi có SOS, gửi thông báo tới mọi người trong nhà.',
                  value: s.notifyAllMembers,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(notifyAllMembers: v))
                      : null,
                ),
                _tile(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Tự cảnh báo khi phát hiện té ngã',
                  subtitle:
                      'Tự động tạo cảnh báo SOS khi thiết bị nhận thấy cú ngã.',
                  value: s.autoCreateAlertFromFall,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(autoCreateAlertFromFall: v))
                      : null,
                ),
                _tile(
                  icon: Icons.location_on_rounded,
                  title: 'Bắt buộc chia sẻ vị trí',
                  subtitle:
                      'Yêu cầu đính kèm vị trí khi gửi SOS để người nhà tìm nhanh.',
                  value: s.locationRequired,
                  onChanged: canEdit
                      ? (v) => _toggle(s.copyWith(locationRequired: v))
                      : null,
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
                    if (canEdit)
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
                        trailing: canEdit
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
