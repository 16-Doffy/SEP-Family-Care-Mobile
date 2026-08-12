import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../services/livekit_room_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

/// Màn hình đang gọi — GĐ3 bước 3c của tính năng Video Call.
///
/// Chỉ hỗ trợ gọi 1-1 (đúng phạm vi BE đã xác nhận): video của người kia phủ
/// kín màn hình, video của mình là khung nhỏ **cố định** góc trên-phải (không
/// kéo-thả) — không có lưới nhiều người, không chia sẻ màn hình, không ghi
/// hình, không chat trong lúc gọi.
///
/// Màn này tự kết nối LiveKit qua [LivekitRoomService] (đã có sẵn từ bước 3b)
/// bằng [session] được [CallProvider.initiate]/`.join()` trả về ở màn trước.
class ActiveCallScreen extends StatefulWidget {
  final CallSession session;
  final String peerName;

  const ActiveCallScreen({
    super.key,
    required this.session,
    required this.peerName,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  VideoTrack? _remoteVideoTrack;
  VideoTrack? _localVideoTrack;

  bool _micOn = true;
  bool _camOn = true;
  bool _peerJoined = false;
  bool _connecting = true;
  bool _ending = false;
  String? _connectError;

  Timer? _durationTimer;
  Duration _duration = Duration.zero;

  CallProvider? _callProvider;

  @override
  void initState() {
    super.initState();
    _callProvider = context.read<CallProvider>()..addListener(_onCallEnded);
    _connect();
  }

  /// `call:ended` qua socket — bắt cả trường hợp LiveKit không tự báo được
  /// (vd người kia từ chối trước khi từng vào phòng LiveKit, nên không có
  /// `RoomEvent` nào bắn cho mình biết; chỉ socket mới biết).
  void _onCallEnded() {
    if (!mounted) return;
    if (_callProvider?.lastEndedCallId == widget.session.callId) {
      _hangUp(showEndedMessage: true);
    }
  }

  Future<void> _connect() async {
    if (!widget.session.canConnect) {
      setState(() {
        _connecting = false;
        _connectError = 'Máy chủ chưa bật tính năng gọi video.';
      });
      return;
    }
    try {
      await LivekitRoomService.instance.connect(
        url: widget.session.livekitUrl,
        token: widget.session.token,
      );
      await LivekitRoomService.instance.setCameraEnabled(true);
      await LivekitRoomService.instance.setMicrophoneEnabled(true);
      LivekitRoomService.instance.events
        ?..on<ParticipantConnectedEvent>((_) => _markPeerJoined())
        ..on<TrackSubscribedEvent>(_onTrackSubscribed)
        ..on<TrackUnsubscribedEvent>(_onTrackUnsubscribed)
        ..on<LocalTrackPublishedEvent>(_onLocalTrackPublished)
        ..on<ParticipantDisconnectedEvent>((_) => _onPeerLeft())
        ..on<RoomDisconnectedEvent>((_) => _onPeerLeft());

      // Người khác có thể đã ở trong phòng trước khi listener được gắn (vd
      // mình là người nghe máy, vào phòng sau).
      final alreadyThere =
          LivekitRoomService.instance.room?.remoteParticipants.isNotEmpty ??
          false;
      if (alreadyThere) _markPeerJoined();
      if (!mounted) return;
      setState(() => _connecting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectError = CallProvider.messageOf(e);
      });
    }
  }

  void _markPeerJoined() {
    if (_peerJoined || !mounted) return;
    setState(() => _peerJoined = true);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _duration += const Duration(seconds: 1));
    });
  }

  void _onTrackSubscribed(TrackSubscribedEvent event) {
    if (!mounted || event.track is! VideoTrack) return;
    setState(() => _remoteVideoTrack = event.track as VideoTrack);
  }

  void _onTrackUnsubscribed(TrackUnsubscribedEvent event) {
    if (!mounted || event.track is! VideoTrack) return;
    if (_remoteVideoTrack == event.track) {
      setState(() => _remoteVideoTrack = null);
    }
  }

  void _onLocalTrackPublished(LocalTrackPublishedEvent event) {
    final track = event.publication.track;
    if (!mounted || track is! VideoTrack) return;
    setState(() => _localVideoTrack = track as VideoTrack);
  }

  /// Người kia rời phòng LiveKit (rớt mạng hoặc bấm kết thúc) — gọi 1-1 nên
  /// coi như cuộc gọi đã xong, tự đóng màn thay vì để treo màn hình đen.
  void _onPeerLeft() {
    if (!mounted || _ending) return;
    _hangUp(showEndedMessage: true);
  }

  Future<void> _toggleMic() async {
    final next = !_micOn;
    await LivekitRoomService.instance.setMicrophoneEnabled(next);
    if (mounted) setState(() => _micOn = next);
  }

  Future<void> _toggleCam() async {
    final next = !_camOn;
    await LivekitRoomService.instance.setCameraEnabled(next);
    if (mounted) setState(() => _camOn = next);
  }

  Future<void> _hangUp({bool showEndedMessage = false}) async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    try {
      await context.read<CallProvider>().leave(widget.session.callId);
    } catch (_) {
      // Cuộc gọi có thể đã kết thúc phía BE (người kia vừa cúp) — vẫn phải
      // rời phòng LiveKit của mình nên không chặn lại vì lỗi này.
    }
    await LivekitRoomService.instance.disconnect();
    if (!mounted) return;
    if (showEndedMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuộc gọi đã kết thúc.')),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callProvider?.removeListener(_onCallEnded);
    if (!_ending) {
      // Phòng khi màn bị đóng bằng đường khác — dọn phòng LiveKit chứ không
      // để rò rỉ kết nối.
      unawaited(LivekitRoomService.instance.disconnect());
    }
    super.dispose();
  }

  String get _statusText {
    if (_connectError != null) return _connectError!;
    if (_connecting) return 'Đang kết nối...';
    if (!_peerJoined) return 'Đang đổ chuông...';
    final m = _duration.inMinutes.toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _remoteView()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _topBar(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              right: 16,
              child: _localPreview(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _bottomBar()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remoteView() {
    final track = _remoteVideoTrack;
    if (track != null) {
      return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
    return Container(
      color: const Color(0xFF1F2937),
      alignment: Alignment.center,
      child: AvatarWidget(
        initial: widget.peerName.isNotEmpty ? widget.peerName[0] : '?',
        color: AppColors.avatarBlue,
        size: 96,
      ),
    );
  }

  Widget _localPreview() {
    final track = _localVideoTrack;
    return Container(
      width: 96,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF374151),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: (track != null && _camOn)
          ? VideoTrackRenderer(track, fit: VideoViewFit.cover)
          : const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white54,
              size: 26,
            ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.peerName,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusText,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            background: Colors.white.withValues(alpha: 0.16),
            size: 56,
            iconSize: 24,
            onPressed: _toggleMic,
          ),
          _RoundButton(
            icon: Icons.call_end_rounded,
            background: AppColors.sos,
            size: 68,
            iconSize: 30,
            onPressed: () => _hangUp(),
          ),
          _RoundButton(
            icon: _camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            background: Colors.white.withValues(alpha: 0.16),
            size: 56,
            iconSize: 24,
            onPressed: _toggleCam,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.icon,
    required this.background,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
