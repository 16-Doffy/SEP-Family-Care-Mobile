# Kế hoạch build — Video Call: gọi nhóm + hiện đúng màn khi cuộc gọi đến lúc app chạy nền

**Ngày lập:** 2026-08-12 · **Người lập:** phiên Claude Code (nhánh `giap`) · **Người thực hiện:** Codex

> ### ⚠️ ĐỌC MỤC 0 TRƯỚC KHI LÀM BẤT CỨ GÌ
> Tài liệu này viết cho Codex **không có bất kỳ context nào** từ cuộc trò chuyện đã tạo ra nó —
> coi như bạn mới mở repo lần đầu. Mọi quyết định, lý do, số đo thực tế đã kiểm chứng trong phiên
> làm việc 12/08 đều được chép lại đầy đủ ở đây, không giả định bạn "nhớ" gì cả. Đọc hết mục 1–2
> trước khi động vào mục 3 (việc cần làm) — nếu bỏ qua bối cảnh rất dễ làm lại việc đã xong hoặc
> phá vỡ quyết định đã có lý do rõ ràng.

---

## 0. Vai trò tài liệu này và quy tắc bắt buộc của repo

Đây là file kế hoạch theo đúng khuôn đã dùng nhiều lần trong repo này (xem các file
`KE_HOACH_*.md` khác ở thư mục gốc, đặc biệt `KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` —
đáng đọc lướt qua để thấy văn phong/độ chi tiết kỳ vọng). Claude Code lập kế hoạch, Codex thực thi.

**Đọc `CLAUDE.md` ở gốc repo trước tiên** — đây là quy tắc bắt buộc của toàn bộ dự án, áp dụng cho
tài liệu này không ngoại lệ. Nhắc lại 4 điểm quan trọng nhất vì hay bị bỏ qua:

1. **`API_DOCS.md` là nguồn sự thật về API.** Trước khi gọi bất kỳ endpoint nào phải đọc file này.
   Phát hiện mismatch FE-BE → cập nhật `API_DOCS.md` ngay trong cùng thay đổi.
2. **Không mock/workaround khi BE thiếu.** Nếu FE cần thứ BE chưa có → dừng lại, viết đề xuất BE
   (method, path, request/response, mức độ Bắt buộc/Nên có) để user gửi team Backend. Mục 3.2 của
   tài liệu này **rất có thể** rơi vào trường hợp này — đọc kỹ phần "Cần BE xác nhận" trước khi code.
3. **Preview trước khi sửa.** Mô tả file sẽ đổi + lý do, logic cũ → mới, rủi ro; chỉ sửa sau khi
   user xác nhận. Áp dụng cho mọi thay đổi, kể cả "fix nhanh". Việc gọi nhóm (mục 3.1) là thay đổi
   lớn — **bắt buộc trình bày phương án trước, không tự quyết code ngay**.
4. **Đang sát đợt bảo vệ hội đồng** (ghi trong bộ nhớ phiên làm việc trước, chưa chắc còn đúng vào
   lúc bạn đọc — hỏi lại user nếu không chắc). Nếu đúng, ưu tiên ổn định, chọn cách ít rủi ro nhất
   thay vì "đẹp nhất về kiến trúc".

---

## 1. Bối cảnh — Video Call đang ở đâu (tính đến 12/08)

Module Calls (gọi video qua LiveKit) do BE ship 2026-08-10, FE làm theo 4 giai đoạn, **cả 4 đã
xong** trước phiên làm việc dẫn tới tài liệu này:

- **GĐ1**: tầng REST + model (`lib/providers/call_provider.dart`).
- **GĐ2**: signaling qua Socket.IO namespace `/chat` (`lib/services/chat_socket_service.dart`).
- **GĐ3**: LiveKit — `lib/screens/shared/incoming_call_screen.dart` (Từ chối/Nghe) và
  `active_call_screen.dart` (màn đang gọi). **Chỉ hỗ trợ 1-1**: video người kia phủ kín màn, video
  mình khung nhỏ cố định góc trên-phải, không lưới nhiều người, không chia sẻ màn hình, không ghi
  hình, không chat trong lúc gọi.
- **GĐ4**: nối `CallProvider` vào cây provider (`lib/main.dart`), `family_shell.dart` gọi
  `startRealtime()`/`stopRealtime()`, nhận `call:incoming` → mở `IncomingCallScreen`.

Sau đó có thêm một đợt (12/08, trước phiên dẫn tới tài liệu này) thêm `CallGuardService.kt` —
foreground service Android giữ camera/mic sống khi app xuống nền **trong lúc đang gọi** (không
liên quan tới việc *nhận* cuộc gọi đến, xem phân biệt ở mục 3.2).

**Đọc bắt buộc trước khi code**, theo đúng thứ tự:

1. `API_DOCS.md` — tìm heading `### Calls — gọi video qua LiveKit`. Đây là toàn bộ contract API,
   enum, mã lỗi, đã chốt với BE, không đoán field.
2. `lib/providers/call_provider.dart` — toàn bộ model (`Call`, `CallParticipant`,
   `CallMemberSummary`, `CallStatus`, `CallParticipantStatus`, `CallErrorCode`) + `CallProvider`
   (REST calls, realtime, `messageOf()`).
3. `lib/screens/shared/incoming_call_screen.dart` và `active_call_screen.dart` — toàn bộ UI hiện
   có, đọc kỹ comment đầu file (mô tả rõ giới hạn 1-1 hiện tại).
4. `lib/navigation/family_shell.dart` — hàm `_onIncomingCall` (khoảng dòng 126–155) — cách app mở
   `IncomingCallScreen` khi có `call:incoming`, và **chỉ khi nào việc này chạy được** (mục 3.2 giải
   thích chi tiết giới hạn).
5. `android/app/src/main/kotlin/com/familycare/family_care_flutter/CallGuardService.kt` — có một
   comment quan trọng (dòng 78–85) giải thích vì sao **không** dùng `Notification.CATEGORY_CALL`:
   kết hợp với foreground service type `camera|microphone`, một số ROM OEM tự vẽ đè thanh "cuộc gọi
   đang diễn ra" ở đầu màn hình, xung đột với `_bottomBar()` tự vẽ trong `active_call_screen.dart`
   (nút không nối được, có máy vỡ hình). **Bài học này áp dụng luôn cho việc ở mục 3.2** — đừng lặp
   lại cách tiếp cận đó cho notification cuộc gọi đến.
6. `lib/services/push_service.dart` — cách FCM hiện được xử lý (chi tiết ở mục 3.2.2, quan trọng).

---

## 2. Việc ĐÃ XONG trong phiên làm việc 12/08 — không làm lại

Phiên làm việc ngay trước khi tài liệu này được viết đã tìm và sửa 2 việc, **cả hai đã test xong
trên máy Oppo CPH2159 thật + emulator thật, xác nhận hoạt động đúng bằng cách gọi thật giữa 2
máy**. Không cần làm lại, chỉ nêu ở đây để Codex hiểu code hiện tại đã ở trạng thái nào.

### 2.1 Sửa lỗi giao diện `ActiveCallScreen` lệch/dồn lên trên

**Triệu chứng (ảnh chụp máy thật do user cung cấp):** toàn bộ nội dung màn hình đang gọi (mic,
avatar, nút video, tên người gọi, trạng thái) bị dồn vào một dải nhỏ ở phía trên cùng màn hình,
phần còn lại là màu đen trơn. Đã hỏi kỹ user và xác nhận đây là **toàn màn hình thật**, không phải
cửa sổ nổi/thu nhỏ của ColorOS.

**Nguyên nhân (đã xác định chắc chắn):** `lib/screens/shared/active_call_screen.dart`, `build()`
dùng `Stack` KHÔNG khai `fit`. Mặc định `StackFit.loose`: kích thước của `Stack` được xác định bởi
child **KHÔNG bọc `Positioned`** — trong file này chỉ có top bar
(`SafeArea(child: Padding(child: _topBar()))`) là child trần, còn `_remoteView()`, `_localPreview()`,
`_bottomBar()` đều bọc `Positioned`/`Positioned.fill` (không tính vào kích thước Stack). Kết quả:
cả `Stack` co lại vừa đúng kích thước nhỏ của top bar, kéo mọi child khác (kể cả `Positioned.fill`)
theo kích thước nhỏ đó, phần còn lại của `Scaffold` (nền đen) lộ ra.

**Đã sửa:** thêm `fit: StackFit.expand,` vào `Stack(...)` ở `active_call_screen.dart` (khoảng dòng
205). Đã build lại APK debug, cài lên Oppo CPH2159 thật + 1 emulator, gọi thật giữa 2 máy — xác
nhận layout đúng hoàn toàn (top bar/khung nhỏ/thanh dưới đúng vị trí, video full màn hình).

### 2.2 Phân biệt trạng thái cuộc gọi trong khung chat + thông báo "đang bận"

**Vấn đề trước khi sửa:**
- Tin nhắn log cuộc gọi (`messageType == 'CALL'`, nội dung do BE sinh sẵn — vd "Cuộc gọi video ·
  5:32", "Cuộc gọi nhỡ") render y hệt tin nhắn chữ thường, không có icon/kiểu riêng, khó nhận ra
  ngay là log cuộc gọi.
- Khi gọi vào hội thoại đang có cuộc gọi khác (`CALL_ALREADY_ACTIVE`), `_startCall()` trong
  `chat_screen.dart` gọi `_snackErr(e)` → hiện `e.toString()` = message thô của BE, **bỏ qua**
  `CallProvider.messageOf(e)` vốn đã map mã lỗi này thành câu rõ ràng "Đang có cuộc gọi khác trong
  hội thoại này." — đây là lý do trạng thái "đang bận" không rõ ràng.

**Đã sửa:**
- `lib/providers/chat_provider.dart` — `ChatMessage` thêm field `relatedCallId` (nullable String,
  parse từ `j['relatedCallId']`). BE xác nhận field này tồn tại (`API_DOCS.md` mục Calls > "Message
  log") nhưng **chưa khai trong Swagger** — không phải suy đoán, đã có xác nhận bằng văn bản của BE.
- `lib/screens/shared/chat_screen.dart`:
  - `_startCall()` catch block: đổi sang dùng `CallProvider.messageOf(e)` thay vì `_snackErr(e)`.
  - `_bubble()`: thêm nhánh đầu hàm `if (m.messageType == 'CALL') return _callLogRow(m);` —
    return sớm, không đi vào logic bubble chữ thường.
  - Thêm widget mới `_callLogRow(ChatMessage m)`: dòng hệ thống căn giữa (không phải bong bóng chat
    trái/phải), icon + nội dung BE sinh sẵn, nền `AppColors.neutralBg` bo tròn. Icon/màu chọn qua
    từ khoá `content.contains('nhỡ')` (khớp với chuỗi push notification "Cuộc gọi nhỡ" đã xác nhận
    trong `API_DOCS.md`) → `Icons.call_missed_rounded` màu `AppColors.danger`; còn lại
    `Icons.videocam_rounded` màu `AppColors.textMuted`. **Cố ý không suy luận trạng thái từ enum**
    (không có access tới `Call.status` ngay tại tin nhắn, xem giải thích dưới) — chỉ dựa vào chuỗi
    `content` đã có sẵn, tránh đoán field/enum chưa xác nhận.
  - Vì `_callLogRow()` không có `GestureDetector`/`onLongPress`, tin nhắn `CALL` **tự động không mở
    được** menu Sửa/Thả cảm xúc/Ghim — đúng yêu cầu BE (BE trả 400 cho các hành động đó với loại tin
    này, ghi trong `API_DOCS.md`), không cần sửa gì thêm ở `_showMessageMenu`.

**Giới hạn đã biết, chưa giải quyết (không phải lỗi, chỉ là chưa làm hết mức):** icon hiện chỉ phân
biệt được "nhỡ" vs "còn lại" (gộp ended/declined/canceled vào cùng 1 icon trung tính). Muốn tách
hẳn icon riêng cho từng trạng thái (declined riêng, canceled riêng...) cần fetch `GET
/calls/{callId}` theo `relatedCallId` để lấy `Call.status` thật — **không nên làm N+1 fetch cho mỗi
tin nhắn trong danh sách chat**, cần cân nhắc cache/batch nếu làm. Chưa có yêu cầu cụ thể nào đòi
tách kỹ hơn mức hiện tại — nếu Codex thấy cần, viết ra hỏi user trước khi làm, đừng tự quyết.

**Đã kiểm chứng:** `flutter analyze` 0 lỗi, `flutter test` 478/478 pass. Test trực tiếp trên máy
Oppo thật: mở hội thoại riêng với "Zap MEM 2", thấy hàng loạt tin `Cuộc gọi nhỡ` (icon đỏ) và
`Cuộc gọi đã hủy` (icon xám) render đúng dạng pill mới — xác nhận bằng mắt trên dữ liệu thật, không
chỉ đọc code.

---

## 3. Việc CHƯA XONG — đây là phần Codex cần làm

### 3.1 Gọi nhóm (Group Call)

#### 3.1.1 BE đã sẵn sàng đến đâu — đọc kỹ trước khi cho rằng cần đề xuất BE

`API_DOCS.md` mục Calls có dòng xác nhận rõ:

> **Gọi nhóm:** BE **không chặn** hội thoại `GROUP`; timeout 30 giây áp dụng như nhau cho cả 1-1
> lẫn nhóm. Có hiện nút gọi cho nhóm hay không là **lựa chọn UI của FE**. Phần còn thiếu cho gọi
> nhóm chỉ là UX (`NO_ANSWER` riêng từng người), không phải bug chặn.

Nghĩa là: `POST /api/v1/calls { conversationId }` gọi được cho hội thoại `GROUP` ngay hôm nay,
không cần BE làm gì thêm. Việc gọi nhóm hiện KHÔNG chạy được **hoàn toàn vì FE tự giới hạn**, không
phải vì thiếu API.

**Giới hạn thật sự duy nhất phía BE:** `CallParticipantStatus.noAnswer` (`NO_ANSWER`) **chưa bao
giờ được set** — xác nhận trong `call_provider.dart` (đọc comment ở class `CallParticipantStatus`,
dòng ~66–72) và `API_DOCS.md`. Timeout 30 giây hiện chỉ xử lý ở cấp **cả cuộc gọi**
(`Call.status → MISSED`), không đánh dấu riêng "người X không bắt máy" trong gọi nhóm. Nghĩa là với
gọi nhóm, UI **không thể** hiện "3/5 người chưa bắt máy" theo từng người — chỉ biết cả cuộc gọi có
kết thúc bằng `MISSED` hay không.

#### 3.1.2 FE hiện đang tự chặn ở đâu — 2 chỗ, phải sửa cả hai

1. **Nút gọi bị ẩn cho hội thoại nhóm.** `lib/screens/shared/chat_screen.dart`, hàm `_startCall()`
   (khoảng dòng 880) và chỗ hiện nút gọi trong AppBar — tìm điều kiện kiểm tra
   `conversation.type == 'PRIVATE'` (hoặc tương đương, đọc kỹ code hiện tại vì đã đổi qua vài lần
   trong các phiên trước, dòng số có thể lệch) và bỏ điều kiện chặn `GROUP`.
2. **`ActiveCallScreen` cứng layout 1-1.** `lib/screens/shared/active_call_screen.dart` hiện có
   đúng 1 biến `_remoteVideoTrack` (VideoTrack? — một track duy nhất) và 1 biến `_localVideoTrack`.
   Toàn bộ logic `_onTrackSubscribed`/`_onTrackUnsubscribed`/`_markPeerJoined`/`_onPeerLeft` viết
   cho **đúng 1 người kia**. Gọi nhóm cần:
   - Đổi `_remoteVideoTrack` thành `Map<String, VideoTrack>` hoặc `List<...>` theo
     `participant.identity` (= `memberId`, xem ghi chú LiveKit trong `API_DOCS.md`).
   - `_onPeerLeft`/`_markPeerJoined` hiện tự đóng màn khi **người kia duy nhất** rời phòng
     (`ParticipantDisconnectedEvent`) — với gọi nhóm, chỉ nên tự đóng khi **TẤT CẢ** đã rời
     (`room.remoteParticipants.isEmpty` sau event, không phải cứ có ai rời là đóng).
   - Viết layout dạng lưới (grid) thay cho "1 full-screen + 1 góc nhỏ cố định". Cân nhắc: 2 người
     kia → chia đôi màn; 3–4 người → lưới 2x2; nhiều hơn → cần quyết định UX riêng (cuộn? thu nhỏ
     thumbnail?). **Đây là quyết định thiết kế lớn — trình bày phương án cụ thể (mockup/mô tả) cho
     user duyệt trước khi code**, đúng Rule 3.
   - `_topBar()` hiện hiện `widget.peerName` (1 tên cố định truyền từ nơi gọi). Gọi nhóm cần hiện
     tên nhóm hoặc danh sách người đang trong cuộc gọi — cần lấy từ đâu? `ActiveCallScreen` hiện
     KHÔNG nhận `Call`/danh sách participant đầy đủ, chỉ nhận `CallSession` (vé vào phòng) +
     `peerName` (String đơn). Cần mở rộng constructor để nhận thêm thông tin hội thoại/participant,
     hoặc tự suy participant từ `room.remoteParticipants` (LiveKit tự có, nhưng chỉ có
     `identity`/`memberId`, không có tên hiển thị — cần map ngược qua `ChatConversation.participants`
     đã có sẵn trong `chat_provider.dart`).
3. `IncomingCallScreen` hiện cũng chỉ hiện 1 `callerName` — với gọi nhóm, người nhận cần biết đây là
   cuộc gọi nhóm nào, ai gọi, có những ai khác được mời (không bắt buộc phải hiện đủ danh sách ngay
   bước này, nhưng ít nhất phải phân biệt được "đây là cuộc gọi nhóm X" chứ không lẫn với 1-1).

#### 3.1.3 Việc CẦN hỏi user trước khi code (không tự quyết)

- Layout lưới bao nhiêu người thì chuyển kiểu hiển thị (2 người / 3-4 / nhiều hơn)?
- Có giới hạn số người tối đa cho 1 cuộc gọi nhóm không (LiveKit không giới hạn cứng, nhưng UI/băng
  thông máy thật có thể cần giới hạn hợp lý, ví dụ 6-8 người)?
- Có cần nút "mời thêm người" giữa cuộc gọi đang diễn ra không, hay chỉ gọi được nhóm nguyên vẹn từ
  đầu (tất cả thành viên hội thoại đều được mời ngay lúc `POST /calls`)?
- Ưu tiên: làm gọi nhóm trước hay mục 3.2 (cuộc gọi đến khi chạy nền) trước? Hai việc độc lập nhau
  nhưng đều lớn — không nên làm song song nếu chỉ có 1 người code.

### 3.2 Cuộc gọi ĐẾN không hiện màn khi app đang chạy nền

> ### ✅ CẬP NHẬT 12/08 (đợt 3) — BE ĐÃ GỠ CHỐT CHẶN Ở MỤC 3.2.3
> Nghĩa (BE) đã trả lời đầy đủ file `CAU_HOI_BE_VIDEO_CALL_NHOM_VA_PUSH_2026-08-12.md` và **đã
> triển khai xong** đề xuất data-only message cho push "cuộc gọi đến". Mục 3.2.3 dưới đây **không
> còn là việc cần hỏi** — đọc thẳng "Cấu trúc payload đã xác nhận" ngay sau mục 3.2.2 rồi làm tiếp
> mục 3.2.4. Route `/incoming-call/:token` + `IncomingCallEntryScreen` (nhắc ở 3.2.4) **đã có sẵn**
> từ đợt code 12/08 trước đó — chỉ còn thiếu đúng phần native Android dựng full-screen-intent từ
> payload data mới này.

Phiên làm việc 12/08 đã **tái hiện trực tiếp** vấn đề user báo cáo, bằng cách gọi thật giữa Oppo
CPH2159 và 1 emulator, dùng `adb`:

- **App đang mở nền trước (foreground):** gọi từ máy A → máy B tự mở `IncomingCallScreen` ngay,
  đúng thiết kế, có nút Từ chối/Nghe.
- **App bị đẩy xuống nền (bấm Home, KHÔNG kill process) trên máy nhận:** gọi từ máy A → máy B
  **chỉ hiện thông báo hệ thống** (tiêu đề "Cuộc gọi video đến", không có nút Nghe/Từ chối trên
  thông báo, bấm vào không mở thẳng `IncomingCallScreen`). Không có màn nào tự mở.

Đây đúng là điều user đã báo cáo. **Kết luận: không phải bug logic** (code `_onIncomingCall` trong
`family_shell.dart` chạy đúng khi có điều kiện) — mà là **giới hạn kiến trúc**: `call:incoming` đi
qua Socket.IO namespace `/chat`, mà socket này **chỉ sống khi tiến trình Flutter đang chạy và có
kết nối mạng active** (giống hệt `NotificationSocketService` — xem `CLAUDE.md` mục "Realtime &
notification"). App xuống nền, hệ điều hành có thể tạm dừng luồng nền của Flutter engine bất kỳ
lúc nào → socket rớt → `call:incoming` không tới được nữa, chỉ còn kênh push FCM.

**Phân biệt QUAN TRỌNG với giới hạn đã biết trước đó** (ghi trong `API_DOCS.md`, mục "Giới hạn đã
chốt: cuộc gọi chưa chạy nền"): giới hạn đó nói về cuộc gọi **ĐANG DIỄN RA** bị rớt kết nối LiveKit
khi khoá màn hình/xuống nền — đã được giảm nhẹ một phần bằng `CallGuardService` (mục 1 tài liệu
này). Còn giới hạn ở mục 3.2 này là **cuộc gọi CHƯA AI BẮT MÁY** không hiện được màn trả lời khi app
đang nền — hai vấn đề khác nhau, cùng gốc là "chưa có foreground/background call infra" nhưng phải
giải quyết bằng cơ chế khác nhau (một cái giữ *đang gọi*, một cái phải *đánh thức app để hiện cuộc
gọi đến* — gần giống cơ chế wake-up đã làm cho SOS).

#### 3.2.2 Nguyên nhân kỹ thuật cụ thể — vì sao chỉ có thông báo trơn

Đọc `lib/services/push_service.dart`, hàm `start()`: comment ghi rõ *"App đang mở: FCM KHÔNG tự vẽ
notification"* nhưng khi app ở nền thì khác — `firebaseBackgroundHandler` (top-level function, chạy
trong isolate riêng khi app nền/tắt) **chỉ log**, không làm gì thêm:

```dart
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('Push(bg): ${message.messageId} data=${message.data}');
}
```

Comment ngay phía trên giải thích: *"Android tự vẽ notification cho message có khối `notification`,
không cần FE làm gì thêm."* Điều này có nghĩa: BE hiện đang gửi FCM dạng **"notification message"**
(có khối `notification` trong payload) — với dạng này, hệ điều hành Android **tự vẽ thông báo và
giao hàng thẳng tới khay hệ thống**, ứng dụng (kể cả `firebaseBackgroundHandler`) **không có cơ hội
can thiệp** để build một notification tuỳ chỉnh (full-screen-intent, nút Nghe/Từ chối riêng...). Đây
chính là lý do quan sát được: chỉ có thông báo trơn, không có gì khác.

**Để làm full-screen-intent như SOS đã làm (xem mục 3.2.3), bắt buộc phải đổi sang "data message"**
(payload chỉ có khối `data`, không có `notification`) — khi đó Android **không** tự vẽ gì cả, giao
toàn quyền xử lý cho `firebaseBackgroundHandler` (kể cả khi app đã bị kill, miễn còn
`@pragma('vm:entry-point')`), và code Kotlin/Dart tự quyết định vẽ full-screen-intent notification y
hệt cách `SosAlertLauncher` đã làm.

#### 3.2.3 ✅ ĐÃ ĐƯỢC BE XÁC NHẬN VÀ TRIỂN KHAI (12/08, đợt 3) — không còn cần hỏi

BE (Nghĩa) xác nhận đã đổi push `referenceType=CALL` loại "cuộc gọi đến" sang **data-only message**
(không có khối `notification`), thiết kế opt-in qua field `dataOnly` trong
`EphemeralNotificationInput`, chỉ bật ở `CallsService.initiate()`, **không ảnh hưởng** các
`referenceType` khác (SOS, TASK, CALENDAR...) vì chúng không set field này — đúng câu trả lời cho
B.5 trong file câu hỏi.

**Cấu trúc `data` thật đã xác nhận** (khớp gần như y hệt đề xuất của FE, KHÔNG cần đoán nữa):

```json
{
  "referenceType": "CALL",
  "referenceId": "<callId>",
  "callId": "<callId>",
  "conversationId": "<conversationId>",
  "callerName": "<tên người gọi, tiếng Việt>",
  "conversationType": "PRIVATE hoặc GROUP",
  "conversationName": "<rỗng nếu PRIVATE>",
  "callEventType": "incoming",
  "title": "<tên người gọi>",
  "body": "Cuộc gọi video đến",
  "notificationId": "",
  "type": "CALL",
  "familyId": "<familyId>"
}
```

⚠️ **Push "Cuộc gọi nhỡ" là push RIÊNG, KHÁC bản chất** — vẫn giữ dạng notification message bình
thường (Android tự vẽ, không cần full-screen-intent, vì chỉ là thông tin không cần hành động ngay).
Phân biệt 2 loại bằng field `callEventType: "incoming" | "missed"` trong `data`. **Đừng viết code
full-screen-intent cho case `"missed"`** — chỉ áp dụng cho `"incoming"`.

**Việc còn lại — chỉ còn phần FE/native Android, không còn phụ thuộc BE nữa:** dựng
`Notification.Builder` với `setFullScreenIntent()` trong `firebaseBackgroundHandler` khi nhận được
message có `data.callEventType == "incoming"`, theo đúng mẫu `SosAlertLauncher`/
`EmergencySosWatcherService` đã làm cho SOS. Xem kiến trúc cụ thể ở mục 3.2.4.

#### 3.2.4 Kiến trúc đề xuất (SAU KHI BE xác nhận data-only) — mô phỏng đúng mẫu SOS

Tham khảo trực tiếp cách đã làm cho SOS (đọc
`KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` mục 4.3 và mục 13, cùng code thật:
`android/app/src/main/kotlin/com/familycare/family_care_flutter/SosAlertLauncher.kt`,
`EmergencySosWatcherService.kt`) — đây KHÔNG phải gợi ý mơ hồ, là pattern đã chạy được thật trên máy
Oppo cho SOS, chỉ cần áp dụng lại cho luồng gọi đến:

```
BE gửi FCM data-only cho referenceType=CALL
        │
        ▼
firebaseBackgroundHandler (Dart, chạy dù app đã kill, cần @pragma('vm:entry-point'))
   HOẶC xử lý ở tầng native Android (FirebaseMessagingService tuỳ biến) — cân nhắc cả 2,
   xem ghi chú "Dart vs Kotlin" dưới đây
        │
        ▼
Dựng Notification.Builder với setFullScreenIntent(pendingIntent, true)
   — PendingIntent trỏ tới MainActivity kèm deep link kiểu
     familycare://app/incoming-call/<callId>?callerName=...&conversationId=...
   — Channel RIÊNG, IMPORTANCE_HIGH, category CATEGORY_CALL cân nhắc kỹ (xem cảnh báo dưới)
        │
        ▼
MainActivity đã có sẵn setShowWhenLocked(true)/setTurnScreenOn(true) từ SOS (mục 4.3
kế hoạch SOS) — TỰ ĐỘNG có lợi cho luồng này, không cần sửa lại
        │
        ▼
go_router: /incoming-call/:token?callId=... — ĐÃ CÓ SẴN (đợt code 12/08 trước), KHÔNG
cần làm lại. PendingIntent chỉ cần trỏ deep link familycare://app/incoming-call/<token
mới>?callId=<callId>, dùng đúng hàm incomingCallFreshPath(callId) đã có trong
app_router.dart
        │
        ▼
IncomingCallEntryScreen fetch GET /calls/{callId} → dựng IncomingCallScreen nếu call
còn live — ĐÃ CÓ SẴN, không cần sửa UI, chỉ cần notification native trỏ đúng deep link
```

**Cảnh báo quan trọng, đọc kỹ trước khi chọn `CATEGORY_CALL`:** comment trong `CallGuardService.kt`
(dòng 78–85, đã trích ở mục 1.5) ghi rõ lý do KHÔNG dùng `CATEGORY_CALL` cho notification giữ cuộc
gọi đang diễn ra — vì kết hợp với foreground service type `camera|microphone` khiến một số ROM OEM
tự vẽ đè thanh hệ thống, xung đột với UI tự vẽ. **Tình huống ở mục 3.2 này KHÁC** (đây là notification
cho cuộc gọi ĐẾN, chưa có foreground service `camera|microphone` nào đang chạy), nên `CATEGORY_CALL`
**có thể** dùng được ở đây và thực ra là category đúng ngữ nghĩa nhất cho incoming call — nhưng
**PHẢI tự test trên máy Oppo thật trước khi tin tưởng**, đừng giả định an toàn chỉ vì tình huống
khác nhau. Nếu thấy hiện tượng tương tự (thanh lạ, vỡ hình) thì lùi về category thường + đủ
`setFullScreenIntent` là đạt yêu cầu chính (không bắt buộc phải có look-and-feel "cuộc gọi hệ
thống" đẹp như Google Dialer).

**Dart vs Kotlin — cân nhắc giống hệt lý do đã chọn ở kế hoạch SOS (mục 3.1 kế hoạch đó):** khi app
bị vuốt tắt khỏi đa nhiệm, Flutter engine có thể bị dọn, nhưng `firebaseBackgroundHandler` chạy
trong **isolate Dart riêng do FCM SDK tự quản lý** (không phải FlutterEngine chính) nên vẫn sống
được kể cả khi app đã kill — đây là điểm khác SOS (SOS phải dùng foreground service Kotlin vì cảm
biến cần chạy liên tục, còn FCM background handler chỉ cần chạy **một lần, ngắn** lúc có push tới).
Nhiều khả năng làm thẳng bằng Dart (`firebaseBackgroundHandler` gọi qua `MethodChannel` tới Kotlin
để build notification — bản thân Notification API chỉ có ở Android/Kotlin, Dart không tự vẽ
notification native được) là đủ, **không nhất thiết cần một `Service` Kotlin riêng như
`EmergencySosWatcherService`**. Nhưng đây là điểm Codex phải tự xác minh bằng cách đọc tài liệu
`firebase_messaging` package hiện dùng (`pubspec.yaml`) và thử nghiệm thật — đừng tin chắc theo suy
luận ở trên, ghi rõ kết quả thật đo được vào tài liệu test (mục 4).

#### 3.2.5 Việc CẦN hỏi user trước khi code

- ~~Có chấp nhận trì hoãn việc này tới khi BE xác nhận xong data-only message không~~ — **hết hiệu
  lực, BE đã xác nhận + triển khai xong (mục 3.2.3)**. Có thể bắt đầu code phần native ngay.
- Nút Nghe/Từ chối ngay trên notification (không cần mở app trước) — có bắt buộc ngay đợt này
  không, hay chỉ cần full-screen-intent mở `IncomingCallScreen` là đủ (người dùng bấm Nghe/Từ chối
  trong app như bình thường)? Làm nút trực tiếp trên notification cần thêm
  `PendingIntent`/`BroadcastReceiver` gọi ngược action `decline`/`accept` — phức tạp hơn hẳn, nên
  làm sau nếu có thời gian (giống cách đã hoãn "nút Kết thúc cuộc gọi trên notification" ở
  `CallGuardService`, xem `API_DOCS.md` mục 12.7 kế hoạch SOS).

---

## 4. Định hướng chung và thứ tự làm

1. **Đọc hết mục 1–2** — không bỏ qua.
2. Với mục 3.1 (gọi nhóm): **trình bày phương án layout cụ thể cho user duyệt trước** (mục 3.1.3),
   chỉ code sau khi có xác nhận.
3. Với mục 3.2 (cuộc gọi đến khi nền): **xác nhận với BE về data-only message trước** (mục 3.2.3),
   không code phần native/full-screen-intent trước khi có câu trả lời đó — có thể tranh thủ làm
   trước phần không phụ thuộc BE nếu muốn (route `/incoming-call/:token`, sửa
   `IncomingCallScreen`/`ActiveCallScreen` để nhận tham số qua deep link thay vì chỉ qua
   `Navigator.push` trực tiếp từ `family_shell.dart`).
4. Cả hai việc đều là thay đổi lớn, có rủi ro phá vỡ luồng 1-1 đang chạy ổn định — **viết/chạy test
   cho luồng 1-1 cũ trước khi bắt đầu sửa, để có baseline so sánh** (tương tự cách phiên trước luôn
   chạy `flutter test` đo baseline trước khi sửa).
5. Sau khi xong (hoặc xong một phần), cập nhật lại chính tài liệu này — đánh dấu phần đã làm, y hệt
   cách `KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` đã được cập nhật nhiều lần trong ngày
   12/08 khi có kết quả test mới.

---

## 5. Codex cần tự phân tích/xác minh trước khi code (không suy đoán từ tài liệu này)

- [ ] Đọc lại **toàn bộ** `lib/screens/shared/chat_screen.dart` hiện tại — số dòng trong tài liệu
      này có thể đã lệch do các phiên sau chỉnh sửa thêm. Tìm bằng nội dung (`_startCall`,
      `PRIVATE`), đừng tin cứng số dòng.
- [x] ~~Xác nhận với BE về khả năng gửi FCM data-only cho `referenceType = CALL`~~ — **đã xác nhận
      + đã triển khai 12/08 (đợt 3)**, xem cấu trúc payload thật ở mục 3.2.3. Không còn là việc cần
      làm, chỉ cần đọc lại payload cho đúng trước khi code native.
- [ ] Tự kiểm tra hành vi thật của `Notification.CATEGORY_CALL` trên máy Oppo CPH2159 (hoặc máy
      Android thật khác nếu Oppo không còn khả dụng) trước khi quyết định dùng hay không — đừng
      suy luận từ mục 3.2.4 mà không đo lại.
- [ ] Đọc kỹ enum `CallParticipantStatus`/`CallStatus` trong `call_provider.dart` trước khi thêm
      bất kỳ logic nào dựa trên trạng thái từng người trong gọi nhóm — nhắc lại: `NO_ANSWER` chưa
      từng được BE set, đừng viết UI cho case này.
- [ ] Kiểm tra phiên bản package `firebase_messaging` trong `pubspec.yaml` và đọc changelog/docs
      chính thức về hành vi data-only message trên Android (đặc biệt khác biệt giữa Android 13 và
      14+ về giới hạn khởi chạy Activity nền — bài học đã có từ SOS: gọi `pendingIntent.send()` thủ
      công từ context nền bị chặn bởi background-activity-launch restriction, CHỈ có thông báo tự
      bắn từ hệ thống mới được miễn trừ, xem cảnh báo trong `SosAlertLauncher.kt`).
- [ ] Trước khi sửa `ActiveCallScreen`/`IncomingCallScreen` cho gọi nhóm, chạy thử luồng 1-1 hiện
      tại trên máy thật một lần để có điểm đối chiếu — tránh trường hợp sửa xong phát hiện đã lỡ
      phá luồng 1-1 mà không biết lúc nào bắt đầu hỏng.

---

## 6. Kiểm thử

Không có test tự động nào cho phần LiveKit/hành vi Android thật (giống toàn bộ module Call hiện
tại) — bắt buộc test tay trên **ít nhất 2 thiết bị/emulator thật gọi nhau**, đúng cách phiên làm
việc 12/08 đã làm (1 máy Oppo CPH2159 thật + 1 emulator, tài khoản khác nhau cùng gia đình, mở
`adb logcat`/`dumpsys` để xác nhận thay vì chỉ nhìn ảnh chụp màn hình).

Bảng tối thiểu cần chạy qua trước khi báo "xong":

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Gọi nhóm 3 người, cả 3 cùng bắt máy | Cả 3 thấy nhau, layout lưới không tràn/chồng |
| 2 | Gọi nhóm, 1 người từ chối, 2 người còn lại bắt máy | Cuộc gọi vẫn tiếp tục bình thường giữa 2 người còn lại |
| 3 | Gọi nhóm, tất cả rời phòng | Màn tự đóng đúng 1 lần, không đóng sớm khi mới 1 người rời |
| 4 | App B chạy nền (bấm Home, chưa kill), máy A gọi B | (sau khi làm xong 3.2) Máy B tự mở `IncomingCallScreen` đè màn khoá/nền, không chỉ có thông báo trơn |
| 5 | App B đã bị kill hẳn (vuốt tắt khỏi đa nhiệm), máy A gọi B | Ghi lại kết quả thật — có thể vẫn không mở được (giới hạn cứng của Android với app đã kill hẳn, khác "chạy nền"), đừng hứa quá tay nếu chưa test |
| 6 | Luồng 1-1 cũ (không đụng gì) | Vẫn hoạt động y hệt trước — chạy lại để đối chiếu baseline mục 5 |
| 7 | `flutter analyze --no-fatal-infos` → 0 error; `flutter test` → không thấp hơn baseline (478 tính đến 12/08, đo lại trước khi bắt đầu vì có thể đã tăng) |

**Ghi kết quả thật vào chính tài liệu này** (thêm cột "Kết quả" vào bảng trên, theo đúng thói quen
đã dùng ở `KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md`) — đừng tạo file kết quả riêng, giữ mọi
thứ liền mạch trong 1 chỗ để người đọc sau không phải lục nhiều file.

---

## 7. Những gì tài liệu này KHÔNG quyết định thay Codex

- Thiết kế UI/UX chi tiết cho lưới gọi nhóm (số cột, animation chuyển đổi khi có người vào/ra...) —
  chỉ nêu yêu cầu chức năng, phần hình ảnh cụ thể Codex tự đề xuất rồi trình user duyệt.
- Có làm nút Nghe/Từ chối trực tiếp trên notification hay không (mục 3.2.5) — để ngỏ, hỏi user.
- Thứ tự làm 3.1 trước hay 3.2 trước — để ngỏ, hỏi user (gợi ý: 3.1 không phụ thuộc BE nên có thể
  bắt đầu ngay, 3.2 phải chờ BE xác nhận trước).

---

## 8. Cập nhật Codex 12/08 — đã thực hiện theo thứ tự đề ra

### 8.1 Đã hoàn thành phần FE cho gọi nhóm

- `chat_screen.dart`: nút gọi video không còn bị giới hạn ở `PRIVATE`; hội thoại active chưa archived đều có thể gọi.
- `ActiveCallScreen`: mở rộng constructor để nhận `conversationType`, `conversationName`, `participantNames`; remote video track chuyển sang map theo `participant.identity = memberId`; group call render dạng grid, 1-1 giữ layout cũ.
- Logic rời phòng: 1-1 vẫn tự đóng khi remote rời; group không tự đóng chỉ vì một người rời, chỉ đóng khi không còn remote participant hoặc nhận `call:ended`.
- `IncomingCallScreen` và `family_shell.dart`: truyền metadata participant từ socket/cache chat để hiển thị cuộc gọi nhóm và chuyển tiếp đúng sang màn active.

### 8.2 Đã hoàn thành phần FE độc lập cho tap notification CALL

- Thêm route `/incoming-call/:token?callId=...`.
- `NotificationRouter` đổi `referenceType=CALL` có `referenceId` sang route incoming-call thay vì chỉ về chat.
- `IncomingCallEntryScreen` fetch `GET /calls/{callId}`; nếu call còn live thì dựng `IncomingCallScreen`, nếu đã kết thúc thì hiển thị thông báo và cho về chat.
- Thiếu `referenceId/callId` vẫn fallback về chat theo role.

### 8.3 Vẫn chưa thể hoàn tất full-screen incoming khi app chạy nền

Phần tự bung `IncomingCallScreen` khi app đang background/khoá màn hình vẫn cần BE xác nhận đổi push `CALL` sang data-only message. Nếu BE vẫn gửi FCM có `notification` block, Android tự vẽ notification và FE không có điểm can thiệp hợp lệ để dựng full-screen-intent/nút Nghe-Từ chối.

### 8.4 Kiểm chứng tự động

- `dart format`: đã chạy cho các file sửa.
- `flutter analyze`: không có error/warning mới; còn 23 `info` cũ ngoài phạm vi video call.
- `flutter test`: 478/478 pass.
