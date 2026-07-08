import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_request_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/json_report_view.dart';

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key});
  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportRequestProvider>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final provider  = context.watch<SupportRequestProvider>();
    final isManager = auth.user?.isAdministrative ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Yêu cầu hỗ trợ chi tiêu',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              if (!isManager)
                GestureDetector(
                  onTap: () => _showCreateDialog(context, provider),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.link,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.add_rounded,
                        size: 22, color: Colors.white),
                  ),
                )
              else
                const SizedBox(width: 40),
            ]),
          ),

          // ── Info banner ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD))),
              child: Row(children: [
                const Text('ℹ️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isManager
                        ? 'Phê duyệt hoặc từ chối yêu cầu hỗ trợ chi tiêu từ thành viên.'
                        : 'Gửi yêu cầu hỗ trợ chi tiêu tới trưởng nhóm. Đây là yêu cầu ảo — không có tiền thực.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0369A1)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? _errorView(provider)
                    : provider.requests.isEmpty
                        ? _emptyView(isManager)
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchRequests(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: provider.requests.length,
                              itemBuilder: (ctx, i) => _RequestCard(
                                request: provider.requests[i],
                                isManager: isManager,
                                provider: provider,
                              ),
                            ),
                          ),
          ),

          if (!isManager)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.link,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _showCreateDialog(context, provider),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text('Gửi yêu cầu hỗ trợ',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _emptyView(bool isManager) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📋', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text('Chưa có yêu cầu nào',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(isManager ? 'Chưa có thành viên nào gửi yêu cầu'
                     : 'Nhấn dấu + để gửi yêu cầu hỗ trợ',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
    ]),
  );

  Widget _errorView(SupportRequestProvider provider) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () => provider.fetchRequests(),
        child: const Text('Thử lại'),
      ),
    ]),
  );

  void _showCreateDialog(BuildContext ctx, SupportRequestProvider provider) {
    final amountCtrl  = TextEditingController();
    final purposeCtrl = TextEditingController();
    bool submitting   = false;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Gửi yêu cầu hỗ trợ',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số tiền (₫)',
                hintText: 'VD: 250000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: purposeCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Mục đích',
                hintText: 'VD: Mua sách giáo khoa',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.link,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: submitting ? null : () async {
                final amt = double.tryParse(
                  amountCtrl.text.replaceAll(',', '').replaceAll('.', ''));
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')));
                  return;
                }
                if (purposeCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập mục đích')));
                  return;
                }
                setS(() => submitting = true);
                try {
                  await provider.createRequest(
                    amount: amt, purpose: purposeCtrl.text.trim());
                  if (dCtx.mounted) Navigator.of(dCtx).pop();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Đã gửi yêu cầu hỗ trợ'),
                        backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  setS(() => submitting = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'),
                          backgroundColor: AppColors.danger));
                  }
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Gửi',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SupportRequest request;
  final bool isManager;
  final SupportRequestProvider provider;

  const _RequestCard({
    required this.request,
    required this.isManager,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor  = _statusColor(request.status);
    final statusLabel  = _statusLabel(request.status);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: request.isPending
                ? statusColor.withValues(alpha: 0.4)
                : const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.link.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Text('💬', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.requesterName,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(_formatDate(request.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999)),
            child: Text(statusLabel,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),

        const SizedBox(height: 12),
        Text('Số tiền: ${_fmtAmount(request.amount)} ₫',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(request.purpose,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),

        if (request.decisionNote != null && request.decisionNote!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Ghi chú: ${request.decisionNote}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],

        // Manager action buttons for pending requests
        if (isManager && request.isPending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: () => _reviewDialog(context, 'REJECT'),
                child: Text('Từ chối',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.danger)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                onPressed: () => _reviewDialog(context, 'APPROVE'),
                child: Text('Phê duyệt',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ],
      ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _RequestDetailSheet(requestId: request.id),
    );
  }

  void _reviewDialog(BuildContext context, String decision) {
    final noteCtrl  = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(decision == 'APPROVE' ? '✅ Phê duyệt yêu cầu' : '❌ Từ chối yêu cầu',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${request.requesterName} · ${_fmtAmount(request.amount)} ₫',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: decision == 'APPROVE' ? AppColors.success : AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: submitting ? null : () async {
                setS(() => submitting = true);
                try {
                  await provider.review(
                    requestId: request.id,
                    decision: decision,
                    decisionNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                  if (dCtx.mounted) Navigator.of(dCtx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(decision == 'APPROVE' ? 'Đã phê duyệt' : 'Đã từ chối'),
                        backgroundColor: decision == 'APPROVE' ? AppColors.success : AppColors.danger));
                  }
                } catch (e) {
                  setS(() => submitting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'),
                          backgroundColor: AppColors.danger));
                  }
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(decision == 'APPROVE' ? 'Xác nhận duyệt' : 'Xác nhận từ chối',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'APPROVED' => AppColors.success,
        'REJECTED' => AppColors.danger,
        _          => const Color(0xFFF59E0B),
      };

  static String _statusLabel(String s) => switch (s) {
        'APPROVED' => 'Đã duyệt',
        'REJECTED' => 'Từ chối',
        _          => 'Chờ duyệt',
      };

  static String _fmtAmount(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _formatDate(DateTime d) {
    final now  = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// GET /families/{familyId}/finance/support-requests/{requestId} — chi tiết.
class _RequestDetailSheet extends StatefulWidget {
  final String requestId;
  const _RequestDetailSheet({required this.requestId});
  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await context.read<SupportRequestProvider>().fetchRequestDetail(widget.requestId);
      if (mounted) setState(() { _detail = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🔍 Chi tiết yêu cầu', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_error != null)
          Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))
        else
          JsonReportView(data: _detail ?? {}),
      ]),
    );
  }
}
