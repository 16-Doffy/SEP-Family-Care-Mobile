import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/app_colors.dart';

class SosAlertDetailScreen extends StatefulWidget {
  final String alertId;

  const SosAlertDetailScreen({super.key, required this.alertId});

  @override
  State<SosAlertDetailScreen> createState() => _SosAlertDetailScreenState();
}

class _SosAlertDetailScreenState extends State<SosAlertDetailScreen> {
  SosAlert? _alert;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final alert =
          await context.read<SosProvider>().fetchAlertDetail(widget.alertId);
      if (mounted) setState(() => _alert = alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showNoteDialog({
    required String title,
    required String confirmLabel,
    required Color confirmColor,
    required void Function(String note) onConfirm,
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ghi chú xử lý hoặc lý do...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm(ctrl.text.trim());
  }

  String _statusLabel(String status) => switch (status) {
        'ACTIVE' => 'Đang hoạt động',
        'ACKNOWLEDGED' => 'Đã tiếp nhận',
        'RESOLVED' => 'Đã giải quyết',
        'CANCELED' || 'CANCELLED' => 'Đã hủy',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'ACTIVE' => AppColors.sos,
        'ACKNOWLEDGED' => AppColors.accent500,
        'RESOLVED' => AppColors.safe,
        _ => AppColors.textMuted,
      };

  String _severityLabel(String severity) => switch (severity) {
        'CRITICAL' => 'Nguy cấp',
        'HIGH' => 'Cao',
        'MEDIUM' => 'Trung bình',
        'LOW' => 'Thấp',
        _ => severity,
      };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>().user;
    final canResolveSos = auth?.canResolveSos ?? false;
    final isOwnAlert = _alert != null && auth != null && _alert!.senderId == auth.id;
    final canCancel = canResolveSos || isOwnAlert;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text(
          'Chi tiết SOS',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alert == null
              ? Center(
                  child: Text(
                    'Không tìm thấy cảnh báo này',
                    style: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 20),
                      if (_error != null) _buildErrorBanner(),
                      if (_alert!.isActive) ...[
                        _buildSectionTitle('Phản hồi nhanh'),
                        const SizedBox(height: 10),
                        _buildQuickResponses(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Hành động'),
                        const SizedBox(height: 10),
                        _buildConfirmSafetyButton(),
                        const SizedBox(height: 10),
                        if (canResolveSos) _buildResolveButton(),
                        if (canResolveSos) const SizedBox(height: 10),
                        if (canCancel) _buildCancelButton(),
                      ] else
                        _buildClosedNotice(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.sos.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _error ?? '',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.sos),
        ),
      );

  Widget _buildSectionTitle(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );

  Widget _buildHeaderCard() {
    final alert = _alert!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(
                _statusLabel(alert.status),
                _statusColor(alert.status),
                _statusColor(alert.status).withOpacity(0.12),
              ),
              const SizedBox(width: 8),
              _badge(
                'Mức độ: ${_severityLabel(alert.severity)}',
                AppColors.textSecondary,
                AppColors.background,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            alert.message,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Người gửi: ${alert.senderName}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (alert.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Vị trí: ${alert.address}',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Thời gian: ${alert.createdAt}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color bgColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      );

  Widget _buildQuickResponses() {
    const chips = [
      ('VIEWED', 'Đã xem'),
      ('CONFIRM_SAFE', 'Tôi an toàn'),
      ('NEED_HELP', 'Cần giúp đỡ'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips.map((chip) {
        return GestureDetector(
          onTap: _busy
              ? null
              : () => _run(
                    () => context.read<SosProvider>().respondToAlert(
                          widget.alertId,
                          responseType: chip.$1,
                        ),
                    successMessage: 'Đã gửi phản hồi',
                  ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.progressTrack),
            ),
            child: Text(
              chip.$2,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmSafetyButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _busy
              ? null
              : () => _run(
                    () => context.read<SosProvider>().confirmSafety(widget.alertId),
                    successMessage: 'Đã xác nhận an toàn',
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.safe,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Xác nhận an toàn'),
        ),
      );

  Widget _buildResolveButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy
              ? null
              : () => _showNoteDialog(
                    title: 'Giải quyết cảnh báo SOS',
                    confirmLabel: 'Giải quyết',
                    confirmColor: AppColors.primary500,
                    onConfirm: (note) => _run(
                      () => context.read<SosProvider>().resolveAlert(
                            widget.alertId,
                            note: note.isNotEmpty ? note : 'Safety confirmed',
                          ),
                      successMessage: 'Đã giải quyết cảnh báo',
                    ),
                  ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary500,
            side: const BorderSide(color: AppColors.primary500),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Giải quyết cảnh báo'),
        ),
      );

  Widget _buildCancelButton() => SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _busy
              ? null
              : () => _showNoteDialog(
                    title: 'Hủy cảnh báo SOS',
                    confirmLabel: 'Hủy cảnh báo',
                    confirmColor: AppColors.sos,
                    onConfirm: (note) => _run(
                      () => context.read<SosProvider>().cancelAlert(
                            widget.alertId,
                            note: note.isNotEmpty ? note : 'False alarm',
                          ),
                      successMessage: 'Đã hủy cảnh báo',
                    ),
                  ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.sos,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Hủy SOS'),
        ),
      );

  Widget _buildClosedNotice() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.safe.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.safe),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cảnh báo này đã ${_statusLabel(_alert!.status).toLowerCase()}.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}
