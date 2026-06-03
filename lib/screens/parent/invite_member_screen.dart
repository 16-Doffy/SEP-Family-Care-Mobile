import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

// UC15 — Mời thành viên vào gia đình
// UC16 — Quản lý lời mời đang chờ xử lý
// Theo FAMILY_CARE_SYSTEM.md Section 10: 3 cơ chế mời

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key});
  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Mock: mã 6 ký tự (không dùng O/0, I/1, l)
  // TODO: lấy từ API GET /family/invite-code
  final String _inviteCode = 'A7X-9P2';
  final String _inviteLink =
      'https://familycare.app/join?code=A7X-9P2&exp=24h';
  bool _codeCopied = false;
  bool _linkCopied = false;

  // UC16 — Danh sách lời mời đang chờ
  final _pendingInvites = [
    _InviteData(
        email: 'me@example.com', sentAt: '02/06 14:30', status: 'pending'),
    _InviteData(
        email: 'gra@example.com', sentAt: '01/06 09:15', status: 'pending'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, {required bool isCode}) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() {
      if (isCode) {
        _codeCopied = true;
      } else {
        _linkCopied = true;
      }
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _codeCopied = false;
          _linkCopied = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCode ? 'Đã sao chép mã mời!' : 'Đã sao chép link!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20)
                      ]),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Mời thành viên',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 40),
            ]),
          ),

          // ── Tab bar ───────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ]),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                  color: AppColors.link,
                  borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: '📷 QR Code'),
                Tab(text: '🔗 Link'),
                Tab(text: '🔢 Mã'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _qrTab(),
                _linkTab(),
                _codeTab(),
              ],
            ),
          ),

          // ── UC16 — Pending invites ─────────────────────────
          if (_pendingInvites.isNotEmpty)
            _pendingSection(),
        ]),
      ),
    );
  }

  // ── Tab 1: QR Code ────────────────────────────────────────────────────────
  Widget _qrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        Text('Cho thành viên quét QR này',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Phù hợp cho người dùng trẻ, cùng phòng',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 24),

        // QR placeholder — thay bằng qr_flutter package khi có
        Container(
          width: 220, height: 220,
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 8))
              ]),
          child: Stack(alignment: Alignment.center, children: [
            // Mock QR grid (placeholder visual)
            CustomPaint(
              size: const Size(180, 180),
              painter: _QrPlaceholderPainter(),
            ),
            // Center logo
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.link,
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Text('FC',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Expire info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⏱️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('Hết hạn sau 24 giờ · Dùng 1 lần',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E))),
          ]),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.link,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: () {
              // TODO: refresh QR / call API generate new code
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Đã tạo QR Code mới ✅'),
                  backgroundColor: AppColors.success));
            },
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: Colors.white),
            label: Text('Tạo QR mới',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Tab 2: Share Link ─────────────────────────────────────────────────────
  Widget _linkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        Text('Gửi link mời qua Zalo / SMS',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Phù hợp khi không cùng phòng',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 24),

        // Link box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE5E7EB), width: 1.5)),
          child: Row(children: [
            const Icon(Icons.link_rounded,
                size: 20, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _inviteLink,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _linkCopied ? AppColors.success : AppColors.link,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                onPressed: () =>
                    _copyToClipboard(_inviteLink, isCode: false),
                icon: Icon(
                    _linkCopied
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 18,
                    color: Colors.white),
                label: Text(_linkCopied ? 'Đã sao chép!' : 'Sao chép link',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              onPressed: () {
                // TODO: Share.share(_inviteLink) — dùng share_plus package
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Chia sẻ qua ứng dụng khác...'),
                    backgroundColor: Color(0xFF06B6D4)));
              },
              icon: const Icon(Icons.share_rounded,
                  size: 18, color: Colors.white),
              label: Text('Chia sẻ',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ]),

        const SizedBox(height: 20),
        _expireNote(),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Tab 3: Mã 6 ký tự ─────────────────────────────────────────────────────
  Widget _codeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        Text('Đọc mã qua điện thoại',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Phù hợp cho ông bà, thiết bị cũ',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 32),

        // Code display — ký tự to, dễ đọc
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 8))
              ]),
          child: Column(children: [
            Text('Mã mời gia đình',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              _inviteCode,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.link,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text('Không chứa O, 0, I, 1, l để tránh nhầm',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    _codeCopied ? AppColors.success : AppColors.link,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            onPressed: () =>
                _copyToClipboard(_inviteCode, isCode: true),
            icon: Icon(
                _codeCopied
                    ? Icons.check_rounded
                    : Icons.copy_rounded,
                size: 18,
                color: Colors.white),
            label: Text(
                _codeCopied ? 'Đã sao chép!' : 'Sao chép mã',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),

        _expireNote(),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── UC16 — Pending invites section ────────────────────────────────────────
  Widget _pendingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Lời mời đang chờ',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.link.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('${_pendingInvites.length}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.link)),
            ),
          ]),
          const SizedBox(height: 12),
          ..._pendingInvites.asMap().entries.map((entry) {
            final inv = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.mail_outline_rounded,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.email,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        Text('Gửi lúc ${inv.sentAt}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ]),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: API cancel invite
                    setState(() => _pendingInvites.removeAt(entry.key));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã huỷ lời mời'),
                        backgroundColor: AppColors.danger));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Huỷ',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _expireNote() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Text('⏱️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'Hết hạn sau 24 giờ · Chỉ dùng được 1 lần',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF92400E))),
          ),
        ]),
      );
}

class _InviteData {
  final String email;
  final String sentAt;
  final String status;
  const _InviteData(
      {required this.email, required this.sentAt, required this.status});
}

// ── Custom QR placeholder painter ─────────────────────────────────────────
class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 10;

    // Đơn giản hóa: vẽ pattern chấm để giống QR
    final pattern = [
      [1,1,1,1,1,1,1,0,1,0],
      [1,0,0,0,0,0,1,0,0,1],
      [1,0,1,1,1,0,1,0,1,0],
      [1,0,1,1,1,0,1,0,1,1],
      [1,0,1,1,1,0,1,0,0,0],
      [1,0,0,0,0,0,1,0,1,0],
      [1,1,1,1,1,1,1,0,0,1],
      [0,0,0,0,0,0,0,0,1,0],
      [1,0,1,1,0,1,1,0,1,1],
      [0,1,0,0,1,0,0,1,0,1],
    ];

    for (int row = 0; row < pattern.length; row++) {
      for (int col = 0; col < pattern[row].length; col++) {
        if (pattern[row][col] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                col * cellSize + 1, row * cellSize + 1,
                cellSize - 2, cellSize - 2,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPlaceholderPainter old) => false;
}
