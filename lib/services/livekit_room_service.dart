import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_guard_service.dart';

/// Quản lý **vòng đời kết nối phòng LiveKit** — giai đoạn 3 của tính năng gọi
/// video. Chỉ transport, không giữ state UI (đó là việc của tầng màn hình gọi
/// ở giai đoạn sau).
///
/// `token`/`livekitUrl` lấy từ `CallSession` (`CallProvider.initiate()` hoặc
/// `.join()`, giai đoạn 1) — không tự sinh, không tự đoán.
///
/// Không bọc thêm tầng trừu tượng quanh [Room]/[RoomEvent]: nơi gọi tự
/// `room.createListener()` (đã có sẵn qua [events]) rồi `.on<TrackSubscribedEvent>()`
/// v.v. đúng như tài liệu chính thức của LiveKit, để không lệch khỏi API gốc
/// khi package cập nhật.
class LivekitRoomService {
  LivekitRoomService._();
  static final LivekitRoomService instance = LivekitRoomService._();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;
  EventsListener<RoomEvent>? get events => _listener;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  /// Vào phòng LiveKit ứng với một cuộc gọi. Tự dọn phòng cũ nếu còn (an toàn
  /// khi gọi lại giữa chừng, ví dụ người dùng bấm join lần nữa sau khi rớt
  /// mạng) — không bao giờ để tồn tại 2 phòng cùng lúc.
  Future<Room> connect({required String url, required String token}) async {
    await disconnect();
    // Xin quyền camera/micro TRƯỚC khi bật CallGuardService — đã verify thật
    // trên máy ảo (Android 14): startForeground() với type camera|microphone
    // mà RECORD_AUDIO/CAMERA runtime chưa được cấp thì hệ thống ném thẳng
    // SecurityException, crash cả app ngay tại đó (không phải lỗi bắt được
    // bằng try/catch phía Dart, service chết trước khi kịp trả lỗi về).
    if (!await _ensureMediaPermissions()) {
      throw Exception('Cần cấp quyền camera và micro để gọi video.');
    }
    await CallGuardService.instance.start();
    final room = Room();
    final listener = room.createListener();
    _room = room;
    _listener = listener;
    try {
      await room.connect(url, token);
    } catch (_) {
      // Kết nối thất bại thì đừng để lại phòng nửa vời — dọn ngay để lần gọi
      // connect() kế tiếp (retry) không đụng phải rác của lần trước.
      await disconnect();
      rethrow;
    }
    return room;
  }

  /// `request()` tự no-op nếu đã cấp rồi, chỉ hiện hộp thoại hệ thống khi
  /// chưa từng hỏi — an toàn gọi lại mỗi lần connect().
  Future<bool> _ensureMediaPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Bật/tắt camera của chính mình. Không ném lỗi nếu chưa vào phòng nào —
  /// gọi nhầm lúc chưa connect không nên làm sập màn hình đang gọi.
  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  /// Bật/tắt micro của chính mình.
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Rời phòng và giải phóng tài nguyên. **Thứ tự bắt buộc**: hủy listener
  /// trước khi hủy room — ngược lại thì các callback còn treo có thể chạy
  /// nhắm vào một room đã dispose.
  Future<void> disconnect() async {
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    if (listener != null) await listener.dispose();
    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }
    await CallGuardService.instance.stop();
  }
}
