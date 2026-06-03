import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _lookupCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) return;
    setState(() { _loading = true; _error = null; _preview = null; });
    try {
      final data = await ApiClient.instance.get('/family/invite/$code');
      if (!mounted) return;
      setState(() => _preview = data is Map ? Map<String, dynamic>.from(data) : null);
    } catch (e) {
      setState(() => _error = 'Mã không hợp lệ hoặc đã hết hạn');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinFamily() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.post('/family/join', {'inviteCode': code});
      // Cập nhật token mới nếu có
      final token = (data as Map<String, dynamic>?)?['accessToken'] as String?;
      if (token != null) ApiClient.instance.setToken(token);
      // Điều hướng về login để re-authenticate với gia đình mới
      if (mounted) context.go('/login');
    } catch (_) {
      // Nếu không re-login được, thử reload user
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              child: Text('Nhập mã mời 6 ký tự',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 8),
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
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 28, fontWeight: FontWeight.w700,
                          letterSpacing: 6, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onChanged: (v) {
                      setState(() { _error = null; _preview = null; });
                      if (v.length == 6) _lookupCode();
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
                        _preview!['familyName']?.toString() ?? 'Gia đình',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_preview!['memberCount'] ?? '?'} thành viên · Mã hợp lệ',
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
                onPressed: (_loading || _preview == null) ? null : _joinFamily,
                child: Text('Tham gia gia đình',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
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
                    final code = data!.text!.trim().toUpperCase();
                    // Extract code from link if needed
                    final match = RegExp(r'[A-Z0-9]{6}').firstMatch(code);
                    if (match != null) {
                      _codeCtrl.text = match.group(0)!;
                      _lookupCode();
                    }
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
