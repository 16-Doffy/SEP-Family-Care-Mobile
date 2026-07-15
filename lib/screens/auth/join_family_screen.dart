import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';

/// Public preview + authenticated join-request flow using an 8-character code.
///
/// Hỗ trợ QUÉT QR (mobile_scanner) và DÁN từ clipboard. Cả hai đi qua
/// [_extractCode] để tách đúng mã 8 ký tự từ: deep link `familycare://join?code=`,
/// URL `?code=`/`?token=`, hoặc mã dán trực tiếp. Không còn dùng token cũ.
class JoinFamilyScreen extends StatefulWidget {
  final String? initialCode;
  const JoinFamilyScreen({super.key, this.initialCode});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _codeCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  Timer? _poller;
  Map<String, dynamic>? _preview;
  bool _loading = false;
  String? _error;
  bool _showMyRequests = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!.trim().toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _previewCode());
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _codeCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _hasFullCode => _codeCtrl.text.trim().length == 8;

  // Tách mã 8 ký tự từ chuỗi thô: deep link/URL có ?code= hoặc ?token=, hoặc
  // cụm 8 ký tự [A-Z0-9] đầu tiên (alphabet mã mời, đã bỏ I/O/0/1), hoặc raw.
  String _extractCode(String raw) {
    raw = raw.trim();
    final uri = Uri.tryParse(raw);
    final q = uri?.queryParameters;
    final fromQuery = q?['code'] ?? q?['token'];
    if (fromQuery != null && fromQuery.trim().isNotEmpty) {
      return fromQuery.trim().toUpperCase();
    }
    final match = RegExp(r'[A-Za-z0-9]{8}').firstMatch(raw)?.group(0);
    if (match != null) return match.toUpperCase();
    return raw.toUpperCase();
  }

  // Nạp mã đã tách vào ô nhập rồi preview — dùng chung cho quét QR & dán.
  void _applyCode(String rawValue) {
    if (!mounted) return;
    final code = _extractCode(rawValue);
    _codeCtrl.text = code.length > 8 ? code.substring(0, 8) : code;
    setState(() {
      _error = null;
      _preview = null;
    });
    if (_hasFullCode) _previewCode();
  }

  // Mở scanner toàn màn — quét QR mã mời là tự điền, "quét là nhận".
  Future<void> _scanQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen(), fullscreenDialog: true),
    );
    if (scanned != null && scanned.isNotEmpty) _applyCode(scanned);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) return;
    _applyCode(raw);
  }

  Future<void> _previewCode() async {
    if (!_hasFullCode) return;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final data = await context
          .read<InvitationProvider>()
          .previewInviteCode(_codeCtrl.text.trim().toUpperCase());
      if (mounted) setState(() => _preview = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (!auth.isLoggedIn) {
      await auth.savePendingInviteToken(code);
      if (mounted) context.go('/login');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<InvitationProvider>().requestJoinByCode(
            code,
            message: _messageCtrl.text,
          );
      if (mounted) {
        setState(() => _showMyRequests = true);
        await _loadMyRequests();
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyRequests() async {
    final invitationProvider = context.read<InvitationProvider>();
    final auth = context.read<AuthProvider>();
    try {
      await invitationProvider.fetchMyJoinRequests();
      if (!mounted) return;
      final approved = invitationProvider.myJoinRequests
          .any((request) => request.status.toUpperCase() == 'APPROVED');
      if (approved) {
        await auth.refreshFamilyContext();
        if (!mounted) return;
        if (auth.hasFamily) {
          _poller?.cancel();
          context.go(switch (auth.user?.role) {
            UserRole.manager => '/manager/home',
            UserRole.deputy => '/deputy/home',
            _ => '/member/home',
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) => _loadMyRequests());
  }

  Future<void> _cancel(JoinRequest request) async {
    setState(() => _loading = true);
    try {
      await context.read<InvitationProvider>().cancelMyJoinRequest(request.id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<InvitationProvider>();
    final family = _preview?['family'] is Map
        ? Map<String, dynamic>.from(_preview!['family'] as Map)
        : <String, dynamic>{};
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text('Tham gia gia đình', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: _showMyRequests
          ? _myRequests(provider)
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.group_add_rounded, size: 64, color: AppColors.primary500),
                const SizedBox(height: 16),
                Text('Nhập mã mời 8 ký tự', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Bạn không cần xác thực email để gửi yêu cầu tham gia.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                  style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Mã mời', counterText: ''),
                  onChanged: (_) {
                    setState(() {
                      _error = null;
                      _preview = null;
                    });
                    if (_hasFullCode) _previewCode();
                  },
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
                ),
                // Quét QR / Dán mã — "quét là nhận, không phải gõ tay".
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _scanQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('Quét mã QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      label: const Text('Dán mã'),
                    ),
                  ),
                ]),
                if (family.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.home_rounded, color: AppColors.safe),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Bạn sắp gửi yêu cầu vào ${family['name'] ?? 'gia đình này'}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _messageCtrl,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Lời nhắn (không bắt buộc)'),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading || !_hasFullCode ? null : (_preview == null ? _previewCode : _submit),
                    child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(
                      _preview == null ? 'Kiểm tra mã' : auth.isLoggedIn ? 'Gửi yêu cầu tham gia' : 'Đăng nhập để gửi yêu cầu',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _myRequests(InvitationProvider provider) {
    return RefreshIndicator(
      onRefresh: _loadMyRequests,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Yêu cầu của tôi', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Tự động kiểm tra trạng thái mỗi 12 giây.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (provider.myJoinRequests.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có yêu cầu nào')))
          else
            ...provider.myJoinRequests.map((request) => Card(
              child: ListTile(
                title: Text(request.familyName ?? 'Gia đình', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                subtitle: Text('${request.statusLabel}${request.message == null ? '' : '\n${request.message}'}'),
                isThreeLine: request.message != null,
                trailing: request.isPending ? TextButton(onPressed: _loading ? null : () => _cancel(request), child: const Text('Hủy')) : null,
              ),
            )),
        ],
      ),
    );
  }
}

/// Màn quét QR toàn màn hình. Trả về chuỗi thô của mã QR đầu tiên quét được
/// (deep link `familycare://join?code=...` hoặc mã 8 ký tự) qua Navigator.pop.
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false; // chống pop nhiều lần khi camera bắn liên tục.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.trim().isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Quét mã QR mời', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Khung ngắm để người dùng canh mã.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            bottom: 48,
            child: Text('Đưa mã QR mời vào khung',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
