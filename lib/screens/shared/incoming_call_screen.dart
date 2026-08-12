import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'active_call_screen.dart';

/// Màn hình cuộc gọi đến — mở khi nhận `call:incoming` qua socket `/chat`.
///
/// Module BE chỉ hỗ trợ ổn định gọi 1-1 (xem `CAU_HOI_BE_VIDEO_CALL_2026-08-11.md`
/// mục 9) nên màn này không có danh sách người tham gia, không có nút "thêm
/// người" — chỉ Từ chối / Nghe.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String conversationId;
  final String callerName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.conversationId,
    required this.callerName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _responding = false;
  CallProvider? _callProvider;

  @override
  void initState() {
    super.initState();
    _callProvider = context.read<CallProvider>()..addListener(_onCallEnded);
  }

  @override
  void dispose() {
    _callProvider?.removeListener(_onCallEnded);
    super.dispose();
  }

  /// Người gọi tự huỷ trước khi mình kịp trả lời (`call:ended` qua socket) —
  /// tự đóng màn thay vì để đổ chuông một cuộc gọi đã không còn ai chờ.
  void _onCallEnded() {
    if (!mounted || _responding) return;
    if (_callProvider?.lastEndedCallId == widget.callId) {
      Navigator.of(context).pop();
    }
  }

  void _snackErr(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(CallProvider.messageOf(e)),
        backgroundColor: AppColors.sos,
      ),
    );
  }

  Future<void> _decline() async {
    if (_responding) return;
    setState(() => _responding = true);
    try {
      await context.read<CallProvider>().decline(widget.callId);
    } catch (e) {
      _snackErr(e);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    try {
      final session = await context.read<CallProvider>().join(widget.callId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ActiveCallScreen(session: session, peerName: widget.callerName),
        ),
      );
    } catch (e) {
      _snackErr(e);
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Cuộc gọi đến bắt buộc phải chọn Từ chối/Nghe — bấm back không được
      // âm thầm bỏ qua vì người gọi vẫn đang đổ chuông chờ.
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  'Cuộc gọi video đến',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                AvatarWidget(
                  initial: widget.callerName.isNotEmpty
                      ? widget.callerName[0]
                      : '?',
                  color: AppColors.avatarBlue,
                  size: 104,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.callerName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionButton(
                      icon: Icons.call_end_rounded,
                      background: AppColors.sos,
                      label: 'Từ chối',
                      onPressed: _responding ? null : _decline,
                    ),
                    _CallActionButton(
                      icon: Icons.videocam_rounded,
                      background: AppColors.safe,
                      label: 'Nghe',
                      onPressed: _responding ? null : _accept,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback? onPressed;

  const _CallActionButton({
    required this.icon,
    required this.background,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: onPressed == null
              ? background.withValues(alpha: 0.5)
              : background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}
