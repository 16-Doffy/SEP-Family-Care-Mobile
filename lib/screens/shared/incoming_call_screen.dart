import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';
import 'active_call_screen.dart';

/// Màn hình cuộc gọi đến — mở khi nhận `call:incoming` qua socket `/chat`.
///
/// Màn này dùng chung cho 1-1 và gọi nhóm. Với nhóm, socket `call:incoming`
/// đã có participant object để FE hiển thị ngữ cảnh cơ bản; vẫn chỉ có hai
/// hành động Từ chối / Nghe, chưa có invite thêm người trong lúc gọi.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String conversationId;
  final String callerName;
  final String? conversationName;
  final String conversationType;
  final Map<String, String> participantNames;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.conversationId,
    required this.callerName,
    this.conversationName,
    this.conversationType = 'PRIVATE',
    this.participantNames = const {},
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _responding = false;
  CallProvider? _callProvider;

  bool get _isGroupCall =>
      widget.conversationType == 'GROUP' || widget.participantNames.length > 2;

  String get _title {
    if (!_isGroupCall) return widget.callerName;
    final name = widget.conversationName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Cuộc gọi nhóm';
  }

  int get _memberCount {
    final count = widget.participantNames.length + 1;
    return count < 2 ? 2 : count;
  }

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
          builder: (_) => ActiveCallScreen(
            session: session,
            peerName: widget.callerName,
            conversationName: widget.conversationName,
            conversationType: widget.conversationType,
            participantNames: widget.participantNames,
          ),
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
                  _isGroupCall
                      ? 'Cuộc gọi video nhóm đến'
                      : 'Cuộc gọi video đến',
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
                  _title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_isGroupCall) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${widget.callerName} đang gọi · $_memberCount thành viên',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
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

/// Entry route cho notification/deep link CALL khi app mở từ nền hoặc cold
/// start. Payload push có thể chỉ có `referenceId = callId`, nên màn này fetch
/// lại call trước rồi mới dựng [IncomingCallScreen].
class IncomingCallEntryScreen extends StatefulWidget {
  final String callId;

  const IncomingCallEntryScreen({super.key, required this.callId});

  @override
  State<IncomingCallEntryScreen> createState() =>
      _IncomingCallEntryScreenState();
}

class _IncomingCallEntryScreenState extends State<IncomingCallEntryScreen> {
  Future<Call>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.callId.isNotEmpty) {
      _future = context.read<CallProvider>().getCall(widget.callId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.callId.isEmpty) {
      return _CallUnavailableScreen(message: 'Thiếu mã cuộc gọi.');
    }
    return FutureBuilder<Call>(
      future: _future!,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF111827),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _CallUnavailableScreen(
            message: CallProvider.messageOf(snap.error!),
          );
        }

        final call = snap.data!;
        if (!call.isLive) {
          return const _CallUnavailableScreen(
            message: 'Cuộc gọi này đã kết thúc.',
          );
        }

        final myUser = context.read<AuthProvider>().user;
        final callerName = call.initiatedByMember?.name ?? 'Thành viên';
        final participantNames = {
          for (final p in call.participants)
            if (p.member?.userId != myUser?.id) p.memberId: p.displayName,
        };
        final isGroup = call.participants.length > 2;
        return IncomingCallScreen(
          callId: call.id,
          conversationId: call.conversationId,
          callerName: callerName,
          conversationType: isGroup ? 'GROUP' : 'PRIVATE',
          participantNames: participantNames,
        );
      },
    );
  }
}

class _CallUnavailableScreen extends StatelessWidget {
  final String message;

  const _CallUnavailableScreen({required this.message});

  String _chatPath(UserRole? role) => switch (role) {
    UserRole.manager => '/manager/chat',
    UserRole.deputy => '/deputy/chat',
    UserRole.member => '/member/chat',
    _ => '/login',
  };

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white54,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(_chatPath(role)),
                  child: const Text('Về chat'),
                ),
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
