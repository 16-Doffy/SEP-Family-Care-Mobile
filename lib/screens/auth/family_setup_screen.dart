import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

// UC-ONBOARD — Sau đăng ký: chọn Tạo gia đình mới hoặc Tham gia qua mã mời
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

enum _Mode { choose, createFamily, joinFamily }

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  _Mode _mode = _Mode.choose;

  // Create family
  final _famNameCtrl = TextEditingController();
  bool _creating = false;

  // Join family
  final _codeCtrl = TextEditingController();
  bool _lookingUp = false;
  bool _joining   = false;
  String? _joinError;
  Map<String, dynamic>? _preview;

  @override
  void dispose() {
    _famNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Tạo gia đình mới ─────────────────────────────────────────────────────

  Future<void> _createFamily() async {
    final name = _famNameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Vui lòng nhập tên gia đình');
      return;
    }
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    try {
      await auth.createFamily(name);
      if (mounted) context.go('/manager/home');
    } catch (e) {
      // Chưa verify email → AuthProvider đã set pendingEmailVerification và
      // router sẽ tự đưa sang /verify-email, không cần báo lỗi ở đây.
      if (!auth.pendingEmailVerification) {
        messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ── Tham gia gia đình qua mã ─────────────────────────────────────────────

  Future<void> _lookupCode() async {
    final token = _codeCtrl.text.trim();
    if (token.length < 32) return;
    setState(() { _lookingUp = true; _joinError = null; _preview = null; });
    try {
      final data = await ApiClient.instance.get('/invitations/$token');
      if (mounted) setState(() => _preview = data is Map ? Map<String, dynamic>.from(data) : null);
    } catch (_) {
      if (mounted) setState(() => _joinError = 'Mã không hợp lệ hoặc đã hết hạn');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _joinFamily() async {
    final token = _codeCtrl.text.trim();
    if (token.isEmpty) return;
    setState(() { _joining = true; _joinError = null; });
    try {
      await ApiClient.instance.post('/invitations/$token/claim', {});
      if (mounted) _showRequestSentDialog();
    } catch (e) {
      if (mounted) setState(() => _joinError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _showRequestSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Đã gửi yêu cầu',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Yêu cầu tham gia đã được gửi đến Trưởng nhóm. Bạn sẽ vào được gia đình sau khi yêu cầu được duyệt.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            // Manager có thể đã duyệt NGAY TRONG LÚC người này còn đứng ở
            // dialog (claim → approve rất nhanh) — trước đây bấm "Đã hiểu"
            // chỉ setState về màn chọn, không refetch, nên dù đã là member
            // thật vẫn bị đá về "Thiết lập gia đình" thay vì vào dashboard.
            // Refetch family context trước khi quyết định đi đâu.
            onPressed: () async {
              Navigator.pop(context);
              final auth = context.read<AuthProvider>();
              await auth.refreshFamilyContext();
              if (!mounted) return;
              if (auth.hasFamily) {
                context.go(switch (auth.user?.role) {
                  UserRole.manager => '/manager/home',
                  UserRole.deputy => '/deputy/home',
                  _ => '/member/home',
                });
              } else {
                setState(() {
                  _mode = _Mode.choose;
                  _codeCtrl.clear();
                  _preview = null;
                  _joinError = null;
                });
              }
            },
            child: Text('Đã hiểu', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_mode) {
              _Mode.choose       => _buildChoose(),
              _Mode.createFamily => _buildCreateFamily(),
              _Mode.joinFamily   => _buildJoinFamily(),
            },
          ),
        ),
      ),
    );
  }

  // ── Màn hình chọn ─────────────────────────────────────────────────────────

  Widget _buildChoose() {
    return Column(
      key: const ValueKey('choose'),
      children: [
        const SizedBox(height: 32),
        const Text('🏠', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 20),
        Text('Thiết lập gia đình',
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Bạn muốn tạo gia đình mới hay tham gia gia đình đã có?',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 48),

        // Tạo mới
        _choiceCard(
          emoji: '✨',
          title: 'Tạo gia đình mới',
          subtitle: 'Bạn sẽ là Trưởng nhóm và mời thành viên khác vào',
          color: AppColors.link,
          onTap: () => setState(() => _mode = _Mode.createFamily),
        ),
        const SizedBox(height: 16),

        // Tham gia
        _choiceCard(
          emoji: '🔗',
          title: 'Tham gia gia đình',
          subtitle: 'Nhập mã mời từ Trưởng nhóm để tham gia',
          color: const Color(0xFF7C3AED),
          onTap: () => setState(() => _mode = _Mode.joinFamily),
        ),
        const SizedBox(height: 40),

        // Đăng xuất
        TextButton(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) context.go('/login');
          },
          child: Text('Đăng xuất',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted)),
        ),
      ],
    );
  }

  Widget _choiceCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ]),
      ),
    );
  }

  // ── Tạo gia đình mới ─────────────────────────────────────────────────────

  Widget _buildCreateFamily() {
    return Column(
      key: const ValueKey('create'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backHeader('Tạo gia đình mới'),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Đặt tên cho gia đình',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Tên gia đình sẽ hiển thị với tất cả thành viên',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),

            // Input
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.home_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _famNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Gia đình Nguyễn',
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                    style: GoogleFonts.inter(
                        fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.link.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Text('👑', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn sẽ là Trưởng nhóm gia đình. Mời thành viên khác qua link / QR / mã mời sau.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.link, height: 1.5),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _creating ? null : _createFamily,
                child: _creating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Tạo gia đình',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Tham gia gia đình ─────────────────────────────────────────────────────

  Widget _buildJoinFamily() {
    return Column(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backHeader('Tham gia gia đình'),
        const SizedBox(height: 32),

        Center(
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 44))),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: Text('Nhập mã mời',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Mã được cung cấp bởi Trưởng / Phó nhóm gia đình',
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
              color: _joinError != null
                  ? AppColors.danger
                  : _preview != null
                      ? AppColors.success
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nhập token lời mời...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18),
                ),
                onChanged: (v) {
                  setState(() { _joinError = null; _preview = null; });
                  if (v.trim().length >= 32) _lookupCode();
                },
              ),
            ),
            if (_lookingUp)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_preview != null)
              const Icon(Icons.check_circle_rounded, color: AppColors.success)
            else if (_joinError != null)
              const Icon(Icons.error_rounded, color: AppColors.danger),
          ]),
        ),

        if (_joinError != null) ...[
          const SizedBox(height: 6),
          Text(_joinError!,
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
        ],

        // Preview card
        if (_preview != null) ...[
          const SizedBox(height: 14),
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    (_preview!['family'] as Map?)?['name']?.toString() ??
                        _preview!['familyName']?.toString() ??
                        'Gia đình',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'Mời bởi: ${(_preview!['inviter'] as Map?)?['fullName']?.toString() ?? 'Quản trị viên'}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.success),
                  ),
                ]),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_joining || _lookingUp || _preview == null) ? null : _joinFamily,
            child: _joining
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Gửi yêu cầu tham gia',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),

        // Paste clipboard
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final clip = await Clipboard.getData(Clipboard.kTextPlain);
              if (clip?.text != null && mounted) {
                _codeCtrl.text = clip!.text!.trim();
                _lookupCode();
              }
            },
            icon: const Icon(Icons.paste_rounded,
                size: 16, color: AppColors.link),
            label: Text('Dán từ clipboard',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.link,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _backHeader(String title) {
    return Row(children: [
      GestureDetector(
        onTap: () => setState(() {
          _mode = _Mode.choose;
          _famNameCtrl.clear();
          _codeCtrl.clear();
          _preview = null;
          _joinError = null;
        }),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: AppColors.textPrimary),
      ),
      const SizedBox(width: 12),
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
    ]);
  }
}
