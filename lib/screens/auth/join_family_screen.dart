import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../theme/app_colors.dart';

/// Public preview + authenticated join-request flow using an 8-character code.
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
