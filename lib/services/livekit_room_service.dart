import 'package:livekit_client/livekit_client.dart';

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
  }
}
