import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surface_colors.dart';

/// Manager-only screen for the current reusable family invite-code flow.
///
/// QR chạy trên MÃ MỜI 8 KÝ TỰ (không còn token). QR encode deep link
/// `familycare://join?code=<CODE>` — người được mời quét bằng nút "Quét mã QR"
/// trong màn Tham gia là tự điền mã, KHÔNG cần gõ tay. Không phụ thuộc BE.
class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  String? _code;
  bool _loading = true;
  String? _error;

  // Deep link nhúng trong QR — dùng scheme+host 'familycare://app' khớp
  // intent-filter trong AndroidManifest (path /join khớp route go_router) để
  // quét bằng camera hệ thống cũng mở thẳng app. Scanner in-app thì tách ?code=
  // từ chuỗi này bất kể scheme.
  String get _deepLink => 'familycare://app/join?code=${_code ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await context.read<InvitationProvider>().fetchInviteCode();
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenerate() async {
    final replacing = _code != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(replacing ? 'Đổi mã mời?' : 'Tạo mã mời?'),
        content: Text(
          replacing
              ? 'Mã cũ sẽ bị vô hiệu ngay lập tức.'
              : 'Mã này có thể chia sẻ cho thành viên muốn xin vào gia đình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(replacing ? 'Đổi mã' : 'Tạo mã'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final code =
          await context.read<InvitationProvider>().regenerateInviteCode();
      if (mounted) {
        setState(() => _code = code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(replacing ? 'Đã đổi mã mời' : 'Đã tạo mã mời')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text('Mã mời gia đình', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(onPressed: _loading ? null : _loadCode, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.group_add_rounded, size: 56, color: AppColors.primary500),
                  const SizedBox(height: 16),
                  Text('Mời thành viên bằng mã',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Người nhận nhập mã, gửi yêu cầu và chờ bạn duyệt.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  if (_code != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary100),
                      ),
                      child: Column(children: [
                        // QR thật — encode deep link chứa mã 8 ký tự.
                        Container(
                          width: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary100),
                          ),
                          child: QrImageView(
                            data: _deepLink,
                            version: QrVersions.auto,
                            size: 168,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF111827),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Cho người được mời quét mã này',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        Text(_code!, style: GoogleFonts.robotoMono(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: _code!));
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Đã sao chép mã mời')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Sao chép mã'),
                        ),
                      ]),
                    )
                  else
                    Text(_error ?? 'Gia đình chưa có mã mời.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: _error == null ? AppColors.textMuted : AppColors.danger)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _regenerate,
                      icon: Icon(_code == null ? Icons.add_rounded : Icons.autorenew_rounded),
                      label: Text(_code == null ? 'Tạo mã mời' : 'Đổi mã mời'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}
