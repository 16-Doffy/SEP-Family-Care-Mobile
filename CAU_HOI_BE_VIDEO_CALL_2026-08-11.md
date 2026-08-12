> # ✅ ĐÃ CÓ TRẢ LỜI ĐẦY ĐỦ — 2026-08-11 (đợt 2). KHÔNG CÒN TREO.
>
> BE đã trả lời **toàn bộ 16 câu** và ship thêm khá nhiều thứ. Giữ file này làm **bản ghi lịch sử**;
> trạng thái thật hiện nay đọc ở `API_DOCS.md` mục **Calls** (đã cập nhật theo schema chính thức).
>
> **BE sửa/bổ sung sau khi đọc file này:**
> - **Bug thật do câu 5.1 phát hiện:** cuộc gọi không ai bắt máy nằm `RINGING` **vô thời hạn** và
>   **khoá luôn hội thoại** (không gọi lại được). → Đã sửa: job timeout **30 giây** tự chuyển `MISSED`
>   và giải phóng hội thoại.
> - **Endpoint mới `GET /calls/{callId}`** (câu 5.5/6.1) — trước phải lách qua `conversations/{cid}?limit=1`.
> - `decline`/`leave`/`end` nay trả thêm **`status`** (câu 1.3).
> - **11 mã lỗi ổn định** `code`/`errorCode` (câu 10.1) — trước chỉ có message tiếng Việt thô.
> - **Swagger khai đủ 7 endpoint + 11 schema** (câu 1.1/2.1) — trước hoàn toàn trống.
> - `referenceType` bổ sung `'CALL'` vào `NotificationResponseDto` — đúng chỗ Swagger tự mâu thuẫn ở câu 7.1.
> - `leave` bởi người khởi tạo lúc `RINGING` nay tương đương `end` → `CANCELED` (câu 5.4).
> - Thêm push riêng **"Cuộc gọi nhỡ"** cho người chưa bắt máy (câu 7.3).
> - Xử lý webhook `participant_connection_aborted` cho app bị kill/rớt mạng (câu 5.5).
>
> **Đáp án khác với giả định ban đầu của FE, cần nhớ:**
> - `chat:join` payload là **`{ workspaceId }`** — không phải `conversationId`/`familyId`. Join **1 lần**
>   là đủ cho mọi hội thoại; không cần mở màn chat mới nhận được `call:incoming`.
> - `/chat` là namespace chat **đầy đủ** (tin nhắn, typing, presence...), không riêng cho call.
> - Token LiveKit **TTL 10 phút**, reconnect dùng lại được, không phải gọi `join` lại.
> - Gọi nhóm: BE **không chặn**, FE tự quyết có hiện nút gọi hay không.

# Câu hỏi cho BE — Video Call (LiveKit), ngày 2026-08-11

**Người hỏi:** FE Mobile (Flutter — app điện thoại; app Wear OS dùng chung codebase nhưng **không** làm gọi video)
**Người nhận:** VQuanCT (tác giả module Calls) · Nhật (lead) · Nghĩa — hoặc AI đang đọc source BE
**Bản Swagger đối chiếu:** `236 path / 303 operation / 262 schema`, tải từ
`https://api.familycare-digital.com/api/docs-json` ngày 11/08/2026
**Nguồn tài liệu FE đang dựa vào:** tin bàn giao của VQuanCT ở Discord `#CallVideo` ngày 10/08/2026

---

## ⚠️ Đọc phần này trước

**Đây CHỈ LÀ CÂU HỎI.** Không có dòng nào yêu cầu BE thêm endpoint, đổi field, đổi enum hay đặt deadline.
Phần lớn câu dưới đây bọn mình đoán là **BE đã làm đúng rồi, chỉ là Swagger chưa mô tả** — nếu vậy thì BE
**không phải đụng một dòng code nào**, chỉ cần xác nhận bằng lời là xong.

**Vì sao phải hỏi:** cả **6/6 endpoint `/calls/*`** trong Swagger hiện khai đúng như thế này —

```json
"responses": { "201": { "description": "" } }
```

Không có `content`, không có schema, không khai cả mã lỗi nào (không 400/403/503). Trong toàn bộ 262 schema
chỉ có mỗi `InitiateCallDto` (request). Nghĩa là **mọi tên field FE đang đọc đều lấy từ tin nhắn Discord**,
chưa đối chiếu được với source. Gõ sai một tên field thì app không crash, không log — chỉ hiển thị trống hoặc
bấm không phản ứng, và thường tới lúc demo mới lộ. Đây đúng loại bug đã xảy ra vài lần ở module Notification
và AI trước đây, nên lần này bọn mình dừng lại hỏi trước khi code tiếp.

**Cách trả lời mong muốn:** với mỗi câu, chỉ cần **"đúng"** hoặc **"sai — thực tế là X"**, kèm tên file/hàm/enum
trong source BE để bọn mình tự đối chiếu. Không cần viết code hộ, không cần giải thích dài.

**FE đã làm tới đâu:** đã code xong tầng REST + model (`lib/providers/call_provider.dart`, 14 unit test mapping),
parse phòng thủ nên thiếu field không crash. **Chưa** gắn LiveKit, **chưa** có WebSocket, **chưa** có UI gọi.
Các câu dưới đây quyết định 3 phần còn lại đó.

Câu có gắn 🔴 là **chặn code**, không có câu trả lời thì không làm tiếp được.

---

## Bảng tóm tắt — BE có thể trả lời nhanh ngay tại đây

| # | Câu hỏi | Trả lời |
|---|---|---|
| 1.1 | Response 6 endpoint có đúng như bảng ở mục 1 không? 🔴 | |
| 2.1 | `/calls/*` có đi qua interceptor `{ success, message, data }` không? 🔴 | |
| 3.1 | `CallStatus` / `CallParticipantStatus` khai ở file nào, đủ giá trị chưa? | |
| 4.1 | Đồng hồ có phải tự `emit('chat:join')` không, hay server tự join room? 🔴 | |
| 4.2 | Payload 5 event `call:*` có đúng như mục 4 không? 🔴 | |
| 4.3 | Namespace `/chat` có bắn `chat:message:new` cho tin nhắn thường không? | |
| 5.1 | Không ai bắt máy thì cuộc gọi có tự kết thúc không? | |
| 5.2 | Người cuối rời phòng thì call tự sang `ENDED` chứ? | |
| 6.1 | LiveKit token sống bao lâu? Rớt mạng vào lại có phải gọi `join` lần nữa? 🔴 | |
| 6.2 | `participant.identity` = `memberId` — đúng chứ? 🔴 | |
| 7.1 | `referenceType` của push cuộc gọi là `"CALL"`? 🔴 | |
| 7.2 | Push gửi cho ai — mọi participant hay chỉ người chưa vào phòng? | |
| 8.1 | Message `messageType: CALL` có field `relatedCallId` không, nằm ở đâu? | |
| 8.2 | Nội dung "Cuộc gọi video · 5:32" do BE sinh sẵn hay FE tự dựng? | |
| 9.1 | Hội thoại `GROUP` có nên cho gọi ở bản này không? | |
| 10.1 | Lỗi call có `code`/`errorCode` ổn định không? | |

---

## 1. Response của 6 endpoint 🔴

Đây là câu quan trọng nhất. Dưới đây là **những gì FE đang code cứng theo tài liệu Discord**. Nhờ BE xác nhận
từng dòng hoặc sửa lại.

| Endpoint | FE đang giả định response (phần `data`) |
|---|---|
| `POST /calls` | `{ callId, roomName, token, livekitUrl, call: {...} }` |
| `POST /calls/{callId}/join` | `{ callId, roomName, token, livekitUrl }` — **không** kèm `call` |
| `POST /calls/{callId}/decline` | `{ callId }` |
| `POST /calls/{callId}/leave` | `{ callId }` |
| `POST /calls/{callId}/end` | `{ callId }` |
| `GET /calls/conversations/{cid}` | `{ items: Call[], nextCursor: string \| null }` |

Trong đó object `call` FE đang đọc:

```
id, conversationId, initiatedByMemberId, roomName, status,
startedAt, connectedAt, endedAt, endedReason,
initiatedByMember { id, displayName, familyRole, user { id, fullName, email, avatarUrl } },
participants[] { id, callId, memberId, status, invitedAt, joinedAt, leftAt, member { ...như trên... } }
```

**1.1** 🔴 Bảng trên đúng chưa? Chỗ nào sai thì tên thật là gì?

**1.2** `POST /calls` trả `callId` ở **ngoài cùng** đồng thời `call.id` ở trong — hai giá trị này luôn bằng nhau
chứ? (FE đang đọc `callId` trước, lùi về `call.id`.)

**1.3** `decline` / `leave` / `end` có trả gì hơn `{ callId }` không (ví dụ object call đã cập nhật `status`)?
Nếu có thì FE khỏi phải gọi lại lịch sử để biết trạng thái mới.

**1.4** `GET .../conversations/{cid}` khi hết trang thì `nextCursor` là `null` hay **thiếu hẳn field**? FE đang
xử lý được cả hai, chỉ muốn ghi đúng vào tài liệu.

---

## 2. Envelope 🔴

Ngày 09/08 BE đã xác nhận có **global interceptor bọc `{ success, message, data }`** cho toàn hệ thống, và
`ApiClient` bên FE tự bóc lớp này rồi trả thẳng `data` cho tầng trên.

**2.1** 🔴 Module Calls (mới ship 10/08) có **cũng đi qua** interceptor đó không? Nếu module này trả thẳng
object không bọc envelope thì FE sẽ bóc nhầm một lớp và nhận `null` toàn bộ — hỏng im lặng, không có lỗi nào
hiện ra.

---

## 3. Enum `CallStatus` và `CallParticipantStatus`

Tài liệu Discord mô tả 2 enum này nhưng **không có trong `components.schemas`** (đã kiểm tra cả 262 schema).

- `CallStatus`: `RINGING | ONGOING | ENDED | MISSED | DECLINED | CANCELED`
- `CallParticipantStatus`: `INVITED | JOINED | LEFT | DECLINED | NO_ANSWER`

**3.1** Hai enum này khai ở file nào trong source (Prisma enum? TypeScript union?), và danh sách trên đã **đủ**
chưa?

**3.2** Tài liệu ghi `MISSED` và `NO_ANSWER` **bản hiện tại chưa dùng** (dành cho gọi nhóm + timeout sau này) —
đúng chứ? FE đang code sao cho gặp giá trị lạ thì giữ nguyên chuỗi, không crash, nên nếu sau này BE bật 2 giá
trị đó lên cũng không vỡ; chỉ cần biết để không mất công làm UI cho trạng thái chưa bao giờ xuất hiện.

---

## 4. Signaling qua namespace `/chat` 🔴

Đây là phần FE phải **dựng mới hoàn toàn**: hiện `chat_provider.dart` đang chạy **REST polling, chưa có kết nối
WebSocket nào**. Namespace `/notifications` đã có sẵn nhưng khác namespace và khác cơ chế room nên không dùng
lại được.

**4.1** 🔴 Cơ chế vào room: namespace `/notifications` hiện **server tự join** room `user:<userId>` từ token,
client không phải emit gì. Còn `/chat` thì tài liệu ghi "room `conversation:<id>` mà client join sẵn khi
`chat:join`".

→ Client **có phải tự `emit('chat:join', ...)`** không? Nếu có: **tên event chính xác** và **payload** là gì
(`{ conversationId }`? `{ familyId }`? hay danh sách?). Handshake có giống `/notifications` là
`auth: { token: accessToken }` không?

**4.2** 🔴 Payload của 5 event — FE đang giả định theo tài liệu:

| Event | Payload FE giả định |
|---|---|
| `call:incoming` | `{ callId, conversationId, roomName, initiatedByMemberId, callerName, participants }` |
| `call:accepted` | `{ callId, memberId }` |
| `call:declined` | `{ callId, memberId }` |
| `call:participant-update` | `{ callId, memberId, status: "JOINED" \| "LEFT" }` |
| `call:ended` | `{ callId, status, endedReason, endedAt }` |

Đúng chưa? `participants` trong `call:incoming` là mảng **memberId** hay mảng **object** đầy đủ?

**4.3** Ngoài `call:*` và `chat:message:new`, namespace `/chat` còn bắn event nào khác không (tin nhắn thường,
typing, đã đọc...)?

→ Câu này quyết định thiết kế: nếu `/chat` **chỉ** phục vụ cuộc gọi thì FE chỉ cần mở kết nối lúc có cuộc gọi
liên quan. Nếu nó cũng bắn tin nhắn thường thì FE nên giữ kết nối suốt phiên và **bỏ luôn REST polling** — hai
hướng này khác nhau khá nhiều về khối lượng việc, nên muốn biết trước.

**4.4** Người **không mở màn chat** có nhận được `call:incoming` không? Cụ thể: nếu người dùng đang ở màn Trang
chủ hoặc màn Ví, FE có bắt buộc phải join room `conversation:<id>` từ trước thì mới nhận được cuộc gọi đến
không? (Nếu có, FE phải join sẵn **tất cả** hội thoại ngay sau khi đăng nhập, chứ không phải chỉ hội thoại đang
mở.)

---

## 5. Vòng đời cuộc gọi và các tình huống biên

Tài liệu ghi rõ bản MVP **chưa có timeout** cho người không bắt máy. Vậy:

**5.1** Người gọi bấm gọi nhưng **không ai bắt máy** và người gọi cũng không bấm gì — cuộc gọi có tự chuyển
khỏi `RINGING` không, hay nằm `RINGING` vô thời hạn? Nếu vô thời hạn thì hội thoại đó có bị **khóa không gọi
lại được** không (vì `POST /calls` trả 400 khi đang có cuộc gọi `RINGING`/`ONGOING`)? Đây là tình huống rất dễ
xảy ra lúc demo.

**5.2** Người **cuối cùng** rời phòng (`leave`) thì BE có tự chuyển call sang `ENDED` không, hay phải có ai đó
gọi `end`?

**5.3** Gọi 1-1, người kia bấm `decline` → call sang `DECLINED` và tự kết thúc luôn cho người gọi chứ? Người
gọi lúc đó có nhận `call:ended` không, hay chỉ nhận `call:declined`?

**5.4** Người gọi bấm huỷ **trước khi ai bắt máy** thì gọi endpoint nào — `end` hay `leave`? Trạng thái kết quả
là `CANCELED` đúng không?

**5.5** App bị **kill** giữa cuộc gọi (vuốt tắt, hết pin) — BE có tự nhận ra qua webhook LiveKit
`participant_disconnected` và cập nhật participant sang `LEFT` không, hay bản ghi treo ở `JOINED` mãi?

---

## 6. LiveKit token 🔴

**6.1** 🔴 Token trả về từ `POST /calls` / `join` sống bao lâu? Nếu người dùng rớt mạng 30 giây rồi vào lại,
FE **dùng lại token cũ** để `room.connect()` được, hay **bắt buộc gọi `join` lần nữa** để lấy token mới?

**6.2** 🔴 Tài liệu ghi `participant.identity` trong LiveKit chính là **`memberId`** (không phải `userId`) —
xác nhận giúp. FE dùng cái này để map người trong phòng với `participants[].memberId` mà hiện tên/avatar; map
nhầm thì mọi ô video đều hiện sai tên.

**6.3** Một tài khoản đăng nhập **2 thiết bị** cùng join một cuộc gọi thì sao? LiveKit mặc định đá thiết bị cũ
ra khi trùng `identity` — BE có xử lý gì thêm không, hay FE phải tự chặn?

**6.4** `livekitUrl` có cố định cho toàn hệ thống không, hay có thể khác nhau giữa các cuộc gọi? (FE đang lưu
theo từng phiên gọi nên kiểu gì cũng chạy, chỉ hỏi để biết có nên cache không.)

---

## 7. Push notification khi app ở nền 🔴

**7.1** 🔴 **Đây là chỗ Swagger đang tự mâu thuẫn**, nên phải hỏi:

- `NotificationType` (field `type`) **đã có** `CALL` — 10 giá trị.
- `SendMessageDto.messageType` **đã có** `CALL` — 6 giá trị.
- Nhưng `NotificationResponseDto.properties.referenceType` **vẫn 11 giá trị cũ, KHÔNG có `CALL`**:
  `SOS_ALERT | ALBUM_MEDIA | JOIN_REQUEST | FAMILY | FAMILY_MEMBER | TASK_ASSIGNMENT | CALENDAR_EVENT |
  BUDGET_ALERT | FINANCIAL_GOAL | CONVERSATION | SUPPORT_REQUEST`

Trong khi tài liệu Discord viết payload FCM là `"referenceType": "CALL", "referenceId": "<callId>"`.

→ Giá trị **chính thức** của `referenceType` cho thông báo cuộc gọi là gì? FE cần biết để thêm đúng
`case` vào `NotificationRouter` — sai giá trị thì bấm vào thông báo cuộc gọi **không mở gì cả**, không báo lỗi.

**7.2** Push cuộc gọi đến gửi cho **ai**: mọi participant của hội thoại, hay chỉ những người **chưa** ở trong
phòng? (Người đang mở app và đã vào phòng mà vẫn nhận push báo "có cuộc gọi đến" thì hơi kỳ.)

**7.3** Khi cuộc gọi **nhỡ** hoặc **kết thúc**, BE có gửi thêm một push nữa không (kiểu "Cuộc gọi nhỡ từ Ba")?

---

## 8. Tin nhắn log cuộc gọi trong khung chat

Tài liệu ghi: khi call kết thúc, BE bắn `chat:message:new` với `messageType: "CALL"` và `relatedCallId`, hiện
trong khung chat như "Cuộc gọi video · 5:32", "Cuộc gọi nhỡ".

**8.1** `relatedCallId` **không xuất hiện trong bất kỳ schema nào** của Swagger (đã kiểm tra cả 262 schema).
Field này có thật không, và nằm ở đâu trong object message — cùng cấp với `content`, hay lồng trong object con?

**8.2** Chuỗi hiển thị ("Cuộc gọi video · 5:32") do **BE sinh sẵn** trong `content` (tiếng Việt), hay BE chỉ trả
dữ liệu thô và **FE tự dựng câu**? Nếu BE sinh sẵn thì FE hiển thị thẳng, khỏi tính lại thời lượng.

**8.3** Tài liệu ghi loại tin này **không cho** sửa / thả cảm xúc / ghim (BE trả 400). FE sẽ ẩn luôn các nút đó
cho `messageType == 'CALL'` — xác nhận giúp là đúng ý định chứ không phải bug.

---

## 9. Gọi nhóm

Tài liệu ghi bản MVP **chỉ ổn định cho gọi 1-1**; gọi nhóm dùng chung API nhưng chưa có timeout.

**9.1** Với hội thoại `GROUP` (gồm cả nhóm chat chung của gia đình), FE **nên ẩn nút gọi** ở bản này, hay cứ
cho gọi và chấp nhận giới hạn? Bọn mình nghiêng về **chỉ hiện nút gọi ở hội thoại `PRIVATE`** cho chắc ăn lúc
demo — nhưng đây là quyết định sản phẩm nên muốn hỏi ý BE/lead trước.

---

## 10. Mã lỗi

Swagger **không khai mã lỗi nào** cho cả 6 endpoint. Tài liệu Discord có nhắc `400`, `403`, `503`.

**10.1** Các lỗi này có kèm `code`/`errorCode` **ổn định** như module Wearable đang làm
(`WEARABLE_ALREADY_PAIRED`, `DEVICE_IDENTIFIER_TAKEN`...) không? Nếu có, xin danh sách.

Cụ thể FE cần phân biệt 4 tình huống dưới đây để hiện 4 câu khác nhau — hiện tại **chỉ dựa vào `message` tiếng
Việt của BE**, mà bắt theo chuỗi thì BE sửa chính tả một phát là FE hỏng:

| Tình huống | FE muốn hiện |
|---|---|
| Hội thoại đang có cuộc gọi khác | "Cuộc gọi khác đang diễn ra trong nhóm này" |
| Hội thoại đã lưu trữ / dưới 2 thành viên | "Không gọi được trong hội thoại này" |
| Không nằm trong danh sách được mời (403) | "Bạn không có trong cuộc gọi này" |
| Server chưa cấu hình LiveKit (503) | "Máy chủ chưa bật tính năng gọi video" |

**10.2** `503` — bọn mình hiểu là server thiếu `LIVEKIT_API_KEY/SECRET/URL`, tức lỗi **cấu hình phía server**
chứ không phải lỗi mạng của người dùng, nên FE hiện câu riêng và **không** bảo người dùng thử lại. Đúng chứ?

---

## Ghi chú cuối

Câu hỏi về **SOS push/socket** (không liên quan Video Call) nằm ở file riêng
`CAU_HOI_BE_2026-08-11.md` — tách ra để BE trả lời độc lập, không phải đọc lẫn.
