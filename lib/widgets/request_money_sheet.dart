import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/money_request.dart';
import '../providers/auth_provider.dart';
import '../providers/money_provider.dart';
import '../theme/app_colors.dart';

/// Bottom sheet cho Member gửi yêu cầu tiền đến Trưởng / Phó nhóm.
///
/// Cách dùng từ bất kỳ màn hình nào:
/// ```dart
/// RequestMoneySheet.show(context);
/// ```
class RequestMoneySheet extends StatefulWidget {
  const RequestMoneySheet({super.key});

  /// Convenience helper — không cần `showModalBottomSheet` thủ công.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const RequestMoneySheet(),
    );
  }

  @override
  State<RequestMoneySheet> createState() => _RequestMoneySheetState();
}

class _RequestMoneySheetState extends State<RequestMoneySheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  int? _selectedPreset; // null = custom
  bool _triedSubmit = false;

  static const _presets = [20000, 50000, 100000, 200000];
  static const _maxReason = 80;
  static const _minAmount = 1000; // 1,000 ₫
  static const _maxAmount = 10000000; // 10,000,000 ₫

  // ── Helpers ────────────────────────────────────────────────────────────────

  int get _parsed => int.tryParse(_amountCtrl.text) ?? 0;

  String _chipLabel(int n) {
    if (n >= 1000000) return '${n ~/ 1000000}M';
    return '${n ~/ 1000}k';
  }

  String _fmtFull(int n) =>
      '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₫';

  String? _amountError() {
    if (!_triedSubmit) return null;
    if (_parsed <= 0) return 'Vui lòng nhập số tiền';
    if (_parsed < _minAmount) return 'Tối thiểu ${_fmtFull(_minAmount)}';
    if (_parsed > _maxAmount) return 'Tối đa ${_fmtFull(_maxAmount)} mỗi lần';
    return null;
  }

  bool get _isValid => _parsed >= _minAmount && _parsed <= _maxAmount;

  // ── Handlers ───────────────────────────────────────────────────────────────

  void _pickPreset(int amount) {
    _amountFocus.unfocus();
    setState(() {
      _selectedPreset = amount;
      _amountCtrl.text = amount.toString();
      _amountCtrl.selection = TextSelection.collapsed(
        offset: _amountCtrl.text.length,
      );
    });
  }

  void _onAmountChanged(String val) {
    final n = int.tryParse(val) ?? 0;
    setState(() {
      _selectedPreset = _presets.contains(n) ? n : null;
    });
  }

  void _submit() {
    setState(() => _triedSubmit = true);
    if (!_isValid) return;

    // Capture refs TRƯỚC khi pop — context bị unmount sau pop
    final messenger = ScaffoldMessenger.of(context);
    final money = context.read<MoneyProvider>();
    final user = context.read<AuthProvider>().user;
    final amount = _parsed;
    final reason = _reasonCtrl.text.trim().isEmpty
        ? 'Không có lý do'
        : _reasonCtrl.text.trim();

    money.addRequest(
      MoneyRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: user?.id ?? 'anon',
        senderName: user?.name ?? 'Thành viên',
        senderAvatarInitial: user?.avatarInitials ?? 'TV',
        senderAvatarColor: user?.avatarColor ?? 0xFFEA580C,
        amount: amount.toDouble(),
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );

    Navigator.pop(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã gửi yêu cầu ${_fmtFull(amount)} đến Trưởng nhóm'),
        backgroundColor: AppColors.safe,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final err = _amountError();
    final parsed = _parsed;
    final reasonLen = _reasonCtrl.text.length;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ───────────────────────────────────────────────────────
            Text(
              'Xin tiền',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Gửi yêu cầu đến Trưởng / Phó nhóm để duyệt',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Label: Số tiền ────────────────────────────────────────────────
            Text(
              'Số tiền',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // ── Preset chips ──────────────────────────────────────────────────
            Row(
              children: _presets.map((p) {
                final active = _selectedPreset == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _pickPreset(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary500
                            : AppColors.primary50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColors.primary500
                              : AppColors.progressTrack,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _chipLabel(p),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.primary600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // ── Amount input ──────────────────────────────────────────────────
            TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onAmountChanged,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.progressTrack,
                  letterSpacing: -0.5,
                ),
                suffixText: ' ₫',
                suffixStyle: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: err != null
                    ? const Color(0xFFFEF2F2)
                    : AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary500,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.sos,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),

            // Error message hoặc formatted preview
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 4),
                child: Text(
                  err,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.sos),
                ),
              )
            else if (parsed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 4),
                child: Text(
                  '= ${_fmtFull(parsed)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ── Reason input ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lý do',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$reasonLen / $_maxReason',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: reasonLen >= _maxReason
                        ? AppColors.sos
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLength: _maxReason,
              maxLines: 2,
              // Ẩn counter mặc định — đã custom ở Row trên
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Mua sách, ăn sáng, tiền học phí...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary500,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValid
                      ? AppColors.primary500
                      : AppColors.progressTrack,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  _isValid ? 'Gửi ${_fmtFull(parsed)}' : 'Nhập số tiền trước',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _isValid ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
