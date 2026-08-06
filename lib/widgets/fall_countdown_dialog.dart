import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Đếm ngược trước khi tự gửi SOS do phát hiện té ngã.
///
/// Vì sao **bắt buộc** phải có bước này: gia tốc kế không phân biệt được "người
/// ngã" với "điện thoại rơi khỏi tay" — cả hai đều cho ra rơi tự do rồi va đập.
/// Gửi SOS ngay sẽ báo động cả nhà chỉ vì rơi điện thoại. Ngược lại, người ngã
/// thật mà bị thương thì không bấm được gì, nên **hết giờ là gửi** — im lặng
/// không được coi là "tôi ổn".
///
/// Trả `true` = gửi SOS (người dùng bấm gửi, hoặc hết giờ),
/// `false` = huỷ (người dùng bấm "Tôi ổn").
Future<bool> showFallCountdownDialog(
  BuildContext context, {
  Duration countdown = const Duration(seconds: 10),
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    // Không cho bấm ra ngoài / back để huỷ: huỷ phải là hành động có ý thức.
    builder: (_) => _FallCountdownDialog(countdown: countdown),
  );
  return result ?? true;
}

class _FallCountdownDialog extends StatefulWidget {
  final Duration countdown;
  const _FallCountdownDialog({required this.countdown});

  @override
  State<_FallCountdownDialog> createState() => _FallCountdownDialogState();
}

class _FallCountdownDialogState extends State<_FallCountdownDialog> {
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _left = widget.countdown.inSeconds;
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 3 && _left > 0) HapticFeedback.mediumImpact();
      if (_left <= 0) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(
          Icons.accessibility_new_rounded,
          color: AppColors.sos,
          size: 34,
        ),
        title: Text(
          'Bạn có ổn không?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Điện thoại nhận thấy một cú ngã. Nếu bạn không phản hồi, ứng '
              'dụng sẽ gửi cảnh báo SOS cho gia đình.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sos.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.sos, width: 3),
              ),
              child: Text(
                '$_left',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sos,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // "Tôi ổn" là hành động phụ nhưng phải dễ bấm — đây là nút chống báo
          // nhầm, không phải nút nguy hiểm.
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tôi ổn'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sos),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gửi ngay'),
          ),
        ],
      ),
    );
  }
}
