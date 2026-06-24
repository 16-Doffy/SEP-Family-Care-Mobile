import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

// UC15 — Mời thành viên (Targeted Invite)
// Đã fix: Role enum (FAMILY_MEMBER/DEPUTY_MEMBER), Relationship enum (UPPERCASE)
// Giao diện 2 bước: Nhập thông tin -> Hiện kết quả

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key});
  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'FAMILY_MEMBER';
  String _selectedRelation = 'OTHER';
  
  bool _submitting = false;
  String? _inviteToken;
  String? _errorMsg;

  // 2 Roles chính xác theo Backend API
  final _roles = [
    (value: 'FAMILY_MEMBER', label: 'Thành viên', desc: 'Có thể nhận/làm task, gửi yêu cầu chi tiêu'),
    (value: 'DEPUTY_MEMBER', label: 'Phó nhóm', desc: 'Có quyền duyệt task & hỗ trợ quản lý ví'),
  ];

  // 8 Relationships chính xác theo Backend Enum (Uppercase)
  final _relations = [
    (value: 'FATHER',      label: 'Bố',      emoji: '👨'),
    (value: 'MOTHER',      label: 'Mẹ',      emoji: '👩'),
    (value: 'SPOUSE',      label: 'Vợ/Chồng', emoji: '💑'),
    (value: 'CHILD',       label: 'Con cái',   emoji: '🧒'),
    (value: 'SISTER',      label: 'Chị/Em gái', emoji: '👧'),
    (value: 'BROTHER',     label: 'Anh/Em trai', emoji: '👦'),
    (value: 'GRANDPARENT', label: 'Ông/Bà',    emoji: '👴'),
    (value: 'OTHER',       label: 'Khác',      emoji: '👤'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _errorMsg = 'Vui lòng nhập email hợp lệ');
      return;
    }

    final familyId = ApiClient.instance.familyId;
    if (familyId == null) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final data = await ApiClient.instance.post(
        '/families/$familyId/invitations',
        {
          'email': email,
          'familyRole': _selectedRole,
          'relationship': _selectedRelation,
        },
      );
      
      final token = data['token']?.toString() ?? data['id']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _inviteToken = token;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _inviteToken = null;
      _errorMsg = null;
      _emailCtrl.clear();
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
        ),
        title: Text('Mời thành viên', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _inviteToken == null ? _buildInputStep() : _buildResultStep(),
      ),
    );
  }

  // ── STEP 1: NHẬP THÔNG TIN ──────────────────────────────────────────────────
  Widget _buildInputStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Banner hướng dẫn
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(children: [
            const Text('✉️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text('Gửi lời mời trực tiếp qua email để đảm bảo tính bảo mật và định danh thành viên.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E40AF), height: 1.4))),
          ]),
        ),
        const SizedBox(height: 24),

        _label('Email người nhận'),
        const SizedBox(height: 8),
        _textField(
          controller: _emailCtrl,
          hint: 'nguyenvana@gmail.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        if (_errorMsg != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.sos),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMsg!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.sos, fontWeight: FontWeight.w600))),
            ]),
          ),
        
        const SizedBox(height: 24),
        _label('Vai trò trong gia đình'),
        const SizedBox(height: 12),
        ..._roles.map((r) => _roleCard(r)),

        const SizedBox(height: 24),
        _label('Mối quan hệ'),
        const SizedBox(height: 12),
        _relationGrid(),

        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _submitting ? null : _sendInvite,
            child: _submitting 
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text('Gửi lời mời', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── STEP 2: KẾT QUẢ ────────────────────────────────────────────────────────
  Widget _buildResultStep() {
    final token = _inviteToken!; // full UUID — dùng nguyên cho cả link & copy
    final link  = 'https://api.familycare-digital.com/join?token=$token';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Banner thành công
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCFCE7)),
          ),
          child: Column(children: [
            const Text('✅', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text('Lời mời đã sẵn sàng!', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF166534))),
            Text('Đã gửi thông tin tới ${_emailCtrl.text}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF15803D))),
          ]),
        ),
        const SizedBox(height: 24),

        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFF8FBF5), shape: BoxShape.circle), alignment: Alignment.center, child: Text(_relations.firstWhere((r) => r.value == _selectedRelation).emoji, style: const TextStyle(fontSize: 20))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_roles.firstWhere((r) => r.value == _selectedRole).label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('Quan hệ: ${_relations.firstWhere((r) => r.value == _selectedRelation).label} · Hết hạn trong 24h', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ])),
          ]),
        ),
        const SizedBox(height: 32),

        // QR Code Placeholder
        Center(
          child: Container(
            width: 180, height: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: const Size(150, 150), painter: _QrPlaceholderPainter()),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Text('FC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        _copyBox(label: 'Token mời (dán vào App)', value: token, isCode: true),
        const SizedBox(height: 16),
        _copyBox(label: 'Link tham gia', value: link, isCode: false),

        const SizedBox(height: 40),
        TextButton(
          onPressed: _reset,
          child: Center(child: Text('Mời thêm người khác', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary500))),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _label(String text) => Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _textField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          icon: Icon(icon, size: 20, color: AppColors.textMuted),
          border: InputBorder.none,
          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        ),
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _roleCard(dynamic r) {
    final sel = _selectedRole == r.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = r.value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.primary500 : const Color(0xFFF3F4F6), width: 2),
          boxShadow: sel ? [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.05), blurRadius: 10)] : null,
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? AppColors.primary500 : AppColors.textMuted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(r.desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relationGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: _relations.length,
      itemBuilder: (_, i) {
        final r = _relations[i];
        final sel = _selectedRelation == r.value;
        return GestureDetector(
          onTap: () => setState(() => _selectedRelation = r.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary500.withValues(alpha: 0.08) : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? AppColors.primary500 : const Color(0xFFF3F4F6), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(r.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppColors.primary500 : AppColors.textPrimary), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _copyBox({required String label, required String value, required bool isCode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Row(
            children: [
              Expanded(
                child: Text(value,
                  style: GoogleFonts.robotoMono(
                    fontSize: isCode ? 13 : 12,
                    fontWeight: isCode ? FontWeight.w700 : FontWeight.w400,
                    color: isCode ? AppColors.link : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm!'), backgroundColor: Color(0xFF111827), duration: Duration(seconds: 1)));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]),
                  child: const Icon(Icons.copy_all_rounded, size: 20, color: AppColors.primary500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111827)..style = PaintingStyle.fill;
    final cellSize = size.width / 10;
    final pattern = [
      [1,1,1,1,1,1,1,0,1,1], [1,0,0,0,0,0,1,0,0,1], [1,0,1,1,1,0,1,0,1,0], [1,0,1,1,1,0,1,1,0,1], [1,0,1,1,1,0,1,0,0,1],
      [1,0,0,0,0,0,1,0,1,1], [1,1,1,1,1,1,1,0,1,0], [0,0,0,0,0,0,0,0,1,1], [1,0,1,1,0,1,0,1,0,1], [1,1,0,1,1,1,0,0,1,1],
    ];
    for (int r = 0; r < pattern.length; r++) {
      for (int c = 0; c < pattern[r].length; c++) {
        if (pattern[r][c] == 1) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c * cellSize + 1, r * cellSize + 1, cellSize - 2, cellSize - 2), const Radius.circular(2)), paint);
        }
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
