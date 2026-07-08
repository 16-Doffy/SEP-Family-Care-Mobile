import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

// UC13 — Tham gia gia đình qua lời mời (link / mã 6 ký tự / QR)
// Màn hình dành cho người được mời chưa có tài khoản hoặc đã có tài khoản nhưng chưa có gia đình

class JoinFamilyScreen extends StatefulWidget {
  final String? initialCode; // deep-link truyền code vào
  const JoinFamilyScreen({super.key, this.initialCode});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading   = false;
  String? _error;
  Map<String, dynamic>? _preview; // thông tin gia đình preview trước khi join

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupCode());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // GET /invitations/{token} — xem thông tin gia đình trước khi accept
  // token = secure token của lời mời (64 ký tự hex, KHÁC với invitation.id)
  Future<void> _lookupCode() async {
    final token = _codeCtrl.text.trim();
    if (token.length < 32) return; // token đủ dài mới lookup (tránh gọi sớm).
    setState(() { _loading = true; _error = null; _preview = null; });
    try {
      final data = await ApiClient.instance.get('/invitations/$token');
      if (!mounted) return;
      setState(() => _preview = data is Map ? Map<String, dynamic>.from(data) : null);
    } catch (e) {
      if (mounted) setState(() => _error = 'Mã không hợp lệ hoặc đã hết hạn');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // POST /invitations/{token}/claim — gửi YÊU CẦU tham gia (cần đăng nhập).
  // BE đổi flow 2026-06: không còn join tức thì, phải chờ Trưởng nhóm duyệt.
  Future<void> _joinFamily() async {
    final token = _codeCtrl.text.trim();
    if (token.isEmpty) return;

    // claim cần đăng nhập — nếu chưa login, lưu token rồi đưa sang đăng nhập.
    // Sau khi login/register xong, router tự đưa lại /join?token=... (xem
    // computeRedirect: pendingInviteToken) để bấm gửi yêu cầu.
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await auth.savePendingInviteToken(token);
      if (mounted) context.go('/login');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/invitations/$token/claim', {});
      await auth.clearPendingInviteToken();
      if (mounted) _showRequestSentDialog();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        // claim cần đăng nhập — nếu chưa login BE trả 401
        setState(() => _error = msg.contains('hết hạn') || msg.contains('401')
            ? 'Bạn cần đăng nhập trước khi gửi yêu cầu tham gia.'
            : msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _declineInvitation() async {
    final token = _codeCtrl.text.trim();
    if (token.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<InvitationProvider>().declineInvitation(token);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Đã từ chối lời mời'),
          backgroundColor: AppColors.textMuted,
        ));
        setState(() { _preview = null; _codeCtrl.clear(); });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRequestSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('📨', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Đã gửi yêu cầu!',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Text(
          'Yêu cầu tham gia đã được gửi đến Trưởng nhóm. '
          'Bạn sẽ vào được gia đình ngay khi Trưởng nhóm duyệt.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.link),
            // Manager có thể đã duyệt ngay trong lúc user còn đứng ở dialog
            // này — trước đây bấm "Đã hiểu" chỉ go('/login') mù quáng, router
            // dựa vào AuthProvider.hasFamily (cache cũ, chưa có gì refetch)
            // nên vẫn đá về /family-setup dù BE đã có family thật. Refetch
            // trước khi quyết định đi đâu, giống fix ở family_setup_screen.dart.
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              if (auth.isLoggedIn) {
                await auth.refreshFamilyContext();
              }
              if (!mounted) return;
              if (auth.hasFamily) {
                final homePath = switch (auth.user?.role) {
                  UserRole.manager => '/manager/home',
                  UserRole.deputy => '/deputy/home',
                  _ => '/member/home',
                };
                context.go(homePath);
              } else {
                context.go('/login');
              }
            },
            child: Text('Đã hiểu',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Text('Tham gia gia đình',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 32),

            // Illustration
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: AppColors.link.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 52)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Text('Nhập mã mời',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Dán token được gửi bởi Trưởng / Phó nhóm gia đình',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 28),

            // Code input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _error != null ? AppColors.danger
                       : _preview != null ? AppColors.success
                       : const Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
                    ],
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Dán token / link mời từ Trưởng nhóm',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onChanged: (v) {
                      setState(() { _error = null; _preview = null; });
                      if (v.trim().length >= 32) _lookupCode();
                    },
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_preview != null)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success)
                else if (_error != null)
                  const Icon(Icons.error_rounded, color: AppColors.danger),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
            ],

            // Family preview
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Text('🏠', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        (_preview!['family'] as Map?)?['name']?.toString() ??
                            _preview!['familyName']?.toString() ?? 'Gia đình',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Mời bởi: ${(_preview!['inviter'] as Map?)?['fullName']?.toString() ?? 'Quản trị viên'} · Token hợp lệ',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.success),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            // Join button
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_loading || (_preview == null && _codeCtrl.text.trim().length < 32)) ? null : (_preview == null ? _lookupCode : _joinFamily),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_preview == null ? 'Kiểm tra mã mời' : 'Gửi yêu cầu tham gia',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),

            // Từ chối lời mời — POST /invitations/{token}/reject, cần đăng
            // nhập (BE xác định "lời mời gửi cho tôi" qua email đã login).
            if (_preview != null && context.watch<AuthProvider>().isLoggedIn) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _declineInvitation,
                  child: Text('Từ chối lời mời này',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Divider
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('hoặc', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),

            // Paste from clipboard
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    final raw = data!.text!.trim();
                    // Thử extract UUID từ query param ?token=...
                    final uriToken = Uri.tryParse(raw)?.queryParameters['token'];
                    // Regex UUID: 8-4-4-4-12 hex digits
                    final uuidPattern = RegExp(
                      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
                    final uuid = uriToken ?? uuidPattern.firstMatch(raw)?.group(0) ?? raw;
                    _codeCtrl.text = uuid;
                    setState(() { _error = null; _preview = null; });
                    _lookupCode();
                  }
                },
                icon: const Icon(Icons.paste_rounded, size: 16, color: AppColors.link),
                label: Text('Dán từ clipboard',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.link, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
