> # ✅ ĐÃ CÓ TRẢ LỜI ĐẦY ĐỦ — 2026-08-12 (Nghĩa, đợt 3). KHÔNG CÒN TREO.
>
> BE đã trả lời **toàn bộ 7 câu** (A.1–A.4, B.3, B.5, B.6) và đã **triển khai xong** đề xuất chính ở
> Phần B. Giữ file này làm **bản ghi lịch sử**; trạng thái thật hiện nay đọc ở `API_DOCS.md` mục
> **Calls** (đã cập nhật theo cấu trúc payload chính thức).
>
> **Tóm tắt phần quan trọng nhất (B.3):** push "cuộc gọi đến" (`referenceType=CALL` lúc `initiate()`)
> nay là **data-only message** — đúng đề xuất của FE, không cần sửa cấu trúc. `callEventType:
> "incoming" | "missed"` đã được thêm vào `data` để phân biệt 2 loại push (B.6). Thiết kế opt-in qua
> field `dataOnly`, không ảnh hưởng `referenceType` khác (B.5).
>
> **Việc còn lại là phía FE**, chưa BE: dựng notification `setFullScreenIntent()` kèm nút
> Nghe/Từ chối từ payload data này (`firebaseBackgroundHandler` phía Flutter), theo đúng mẫu
> `SosAlertLauncher`/`EmergencySosWatcherService` đã làm cho SOS. Chỉ có hiệu lực trên **Android**
> — iOS cần VoIP Push (PushKit), ngoài phạm vi đợt này.
>
> **Đáp án khác với giả định ban đầu của FE, cần nhớ:**
> - A.2: BE **không đặt giới hạn cứng** số người tối đa trong 1 cuộc gọi nhóm — giới hạn thực tế (nếu
>   có) tới từ gói LiveKit Cloud, không phải từ code BE.
> - `GET /calls/{callId}` dùng chung `callInclude` với `POST /calls` → `participants[]` **đầy đủ y
>   hệt**, không rút gọn theo số người (A.3, A.4).

# Câu hỏi & đề xuất cho BE — Video Call: gọi nhóm + push cuộc gọi đến, ngày 2026-08-12

**Người hỏi:** FE Mobile (Flutter)
**Người nhận:** VQuanCT (tác giả module Calls) · Nhật (lead) · Nghĩa — hoặc AI đang đọc source BE
**Nguồn tài liệu FE đang dựa vào:** `API_DOCS.md` mục **Calls** (đã chốt đợt 2 ngày 11/08, xem
`CAU_HOI_BE_VIDEO_CALL_2026-08-11.md` — file đó **đã có trả lời đầy đủ**, không hỏi lại nội dung
đã chốt ở đó)
**Trạng thái code FE tại thời điểm hỏi:** đã code xong phần gọi nhóm (mở nút gọi, layout lưới
nhiều người, logic rời phòng đúng), đã code xong phần bấm-vào-thông-báo-để-mở-màn-cuộc-gọi. Còn
đúng 1 việc bị chặn hoàn toàn bởi BE — nằm ở Phần B, đọc kỹ trước khi trả lời phần đó.

---

## Đọc phần này trước

Tài liệu này có **2 phần khác bản chất**, đừng gộp chung cách trả lời:

- **Phần A — câu hỏi làm rõ, không chặn code.** FE đã code xong gọi nhóm dựa trên suy luận hợp lý
  từ tài liệu đã có; các câu ở đây chỉ để xác nhận lại, sai chỗ nào FE sửa chỗ đó, không ai phải
  chờ ai.
- **Phần B — đề xuất thay đổi cách BE gửi push cho cuộc gọi đến, có chặn code.** Đây là việc
  **BE phải chủ động làm** (đổi code phía server), FE không có cách nào tự làm được ở phía mình.
  Không có phản hồi ở phần này thì tính năng "cuộc gọi đến tự bật màn trả lời khi app đang khoá
  máy/chạy nền" **không triển khai được**, chỉ dừng ở mức "có thông báo nhưng phải tự mở app".

**Cách trả lời mong muốn:** Phần A chỉ cần "đúng" / "sai — thực tế là X". Phần B cần trả lời rõ
**làm được hay không làm được**, nếu làm được thì theo đúng cấu trúc payload đề xuất ở mục B.3 (có
thể sửa nếu BE thấy cấu trúc khác hợp lý hơn, miễn báo lại cho FE biết), nếu không làm được thì nói
rõ lý do kỹ thuật để FE tìm hướng khác thay vì chờ vô thời hạn.

Câu có gắn 🔴 là **chặn**, không trả lời thì FE không làm tiếp phần liên quan được.

---

## Bảng tóm tắt — BE có thể trả lời nhanh ngay tại đây

| # | Câu hỏi | Trả lời |
|---|---|---|
| A.1 | `CallParticipantStatus.NO_ANSWER` có kế hoạch được BE set thật không, khi nào? | |
| A.2 | LiveKit/BE có giới hạn số người tối đa cho 1 phòng gọi không? | |
| A.3 | `GET /calls/{callId}` có trả `participants[]` đầy đủ giống `POST /calls` không? 🔴 | |
| A.4 | `call:incoming` cho hội thoại `GROUP` có đủ `participants[]` object như 1-1 không? 🔴 | |
| B.3 | 🔴 Đổi được push `referenceType=CALL` (loại cuộc gọi đến) sang **data-only message** (không có khối `notification`) không? | |
| B.5 | 🔴 Nếu đổi được, có ảnh hưởng gì tới các `referenceType` khác (SOS, TASK...) đang dùng chung code build payload không? | |
| B.6 | Push "Cuộc gọi nhỡ" (khi timeout `MISSED`) có cần đổi theo không, hay giữ nguyên dạng notification message? | |

---

## Phần A — Gọi nhóm: câu hỏi làm rõ (không chặn)

### Bối cảnh

`API_DOCS.md` (đợt 2, 11/08) đã ghi: *"Gọi nhóm: BE không chặn hội thoại `GROUP`; timeout 30 giây
áp dụng như nhau cho cả 1-1 lẫn nhóm. Có hiện nút gọi cho nhóm hay không là lựa chọn UI của FE."*

Dựa vào đó, FE đã tự làm luôn phần gọi nhóm phía UI (12/08): mở nút gọi cho mọi hội thoại đang
active (không chỉ `PRIVATE`), đổi `ActiveCallScreen` từ 1 remote track sang map nhiều track theo
`participant.identity = memberId`, render lưới nhiều ô, sửa logic rời phòng (group không tự đóng
màn khi 1 người rời, chỉ đóng khi hết remote participant). Phần này **đã xong và đã kiểm tra bằng
`flutter analyze`/`flutter test`**, chưa kiểm bằng cuộc gọi thật nhiều người.

Còn vài điểm suy luận cần BE xác nhận lại:

**A.1** `CallParticipantStatus.NO_ANSWER` — theo `API_DOCS.md` hiện **chưa bao giờ được BE set**
(timeout 30 giây chỉ xử lý ở cấp `Call.status → MISSED`, không đánh dấu riêng từng người trong gọi
nhóm). FE đã cố tình **không làm UI** dựa trên giá trị này. Hỏi: BE có kế hoạch set giá trị này cho
từng participant trong gọi nhóm không, và nếu có thì khoảng thời gian nào? Không cần cam kết ngày
cụ thể, chỉ cần biết "có dự định" hay "không, MVP dừng ở mức timeout cả cuộc gọi" để FE quyết định
có đáng đầu tư UI "X/Y người chưa bắt máy" hay không.

**A.2** LiveKit/BE có áp giới hạn số người tối đa cho 1 phòng gọi không (kỹ thuật hoặc chính sách)?
FE hiện chưa tự giới hạn số người mời vào cuộc gọi nhóm ở tầng UI — nếu BE có giới hạn cứng, FE cần
biết con số để chặn sớm ở phía client (báo lỗi rõ ràng thay vì để BE trả lỗi rồi FE hiển thị chung
chung).

**A.3** 🔴 `GET /calls/{callId}` (endpoint thêm ở đợt 2, FE mới bắt đầu dùng cho luồng bấm-vào-
thông-báo, xem Phần B) — response có trả `participants[]` **đầy đủ** giống hệt cấu trúc `call`
trong `POST /calls` không (từng object với `member.displayName`, `member.userId`...), hay chỉ trả
thông tin rút gọn? FE đang code với giả định là **đầy đủ**, dùng để dựng lại tên/avatar người tham
gia khi mở màn từ thông báo (không phải từ socket `call:incoming` trực tiếp).

**A.4** 🔴 Sự kiện `call:incoming` — với hội thoại `GROUP`, field `participants` có vẫn là **mảng
object đầy đủ** như `API_DOCS.md` đã xác nhận cho 1-1 không, hay với nhóm nhiều người BE có rút gọn
đi (ví dụ chỉ trả `memberId`) để giảm kích thước payload? FE đang code với giả định **không đổi
cấu trúc theo số người** — nếu sai thì màn cuộc gọi đến của nhóm sẽ hiện tên trống/sai cho tất cả
thành viên.

---

## Phần B — Đề xuất: đổi push `CALL` sang data-only message 🔴

### B.1 Vấn đề đo được thực tế (không phải suy đoán)

FE đã **tái hiện trực tiếp** bằng cách gọi thật giữa 2 máy Android (1 máy Oppo CPH2159 thật + 1
emulator, tài khoản khác nhau cùng gia đình), theo dõi bằng `adb logcat`/`dumpsys` chứ không chỉ
nhìn giao diện:

- **App đang mở ở tiền cảnh (foreground):** cuộc gọi đến hoạt động đúng thiết kế — socket `/chat`
  nhận `call:incoming`, `IncomingCallScreen` tự mở ngay, có nút Từ chối/Nghe.
- **App bị đẩy xuống nền (bấm Home, KHÔNG kill tiến trình):** cuộc gọi đến **chỉ hiện được thông
  báo hệ thống trơn** (tiêu đề "Cuộc gọi video đến"), **không có nút Nghe/Từ chối trên thông báo**,
  bấm vào thông báo **không mở thẳng được** màn trả lời — phải tự mở app rồi tìm lại.

Đây khác hẳn trải nghiệm "cuộc gọi thật" mà người dùng quen thuộc (điện thoại/Messenger/Zalo): màn
hình trả lời phải tự bật lên **kể cả khi máy đang khoá**, không phải đợi người dùng tự mở app.

### B.2 Nguyên nhân kỹ thuật (phía FE đã xác định, không phải phỏng đoán)

`lib/services/push_service.dart` phía FE có `firebaseBackgroundHandler` — hàm chạy khi app ở
nền/đã tắt hẳn, nhưng **hiện chỉ log, không xử lý gì thêm**, vì lý do sau: FCM có 2 kiểu payload —

1. **"Notification message"** (payload có khối `notification: { title, body }`) — khi ở kiểu này,
   **hệ điều hành Android tự vẽ và giao thông báo thẳng tới khay hệ thống**, ứng dụng (kể cả
   `firebaseBackgroundHandler`) **không có cơ hội can thiệp** để build một thông báo tùy chỉnh
   (full-screen-intent, nút Nghe/Từ chối riêng...).
2. **"Data message"** (payload **chỉ có** khối `data`, **không có** khối `notification`) — khi ở
   kiểu này, Android **không tự vẽ gì cả**, giao toàn quyền xử lý cho code của app (kể cả khi app
   đã bị kill hẳn, miễn `firebaseBackgroundHandler` được đăng ký đúng cách — FE đã kiểm tra, làm
   được).

Dựa vào hành vi quan sát được (chỉ có thông báo trơn, không có gì khác), FE suy luận là hiện tại
BE đang gửi push cho `referenceType = CALL` theo kiểu **(1) notification message**. **Nhờ BE xác
nhận lại đúng/sai** — nếu FE suy luận sai thì cần biết nguyên nhân thật là gì.

### B.3 Đề xuất cụ thể 🔴

Đổi cách BE gửi FCM cho **riêng** `referenceType = CALL`, loại "cuộc gọi đến" (không nhất thiết áp
dụng cho loại "cuộc gọi nhỡ", xem B.6), từ notification message sang **data-only message**.

**Cấu trúc `data` đề xuất** (FE tự đề xuất dựa trên nhu cầu dựng lại `IncomingCallScreen`, BE có
thể sửa nếu thấy hợp lý hơn — miễn giữ đủ thông tin dưới đây):

```json
{
  "referenceType": "CALL",
  "referenceId": "<callId>",
  "callId": "<callId>",
  "conversationId": "<conversationId>",
  "callerName": "<tên người gọi, tiếng Việt, BE dựng sẵn>",
  "conversationType": "PRIVATE hoặc GROUP",
  "conversationName": "<tên hội thoại, chỉ cần cho GROUP, có thể rỗng với PRIVATE>"
}
```

Không cần `title`/`body` trong `data` — FE tự dựng nội dung hiển thị bằng tiếng Việt ở phía client
(giống cách `EmergencySosWatcherService`/`SosAlertLauncher` đã làm cho tính năng SOS, xem
`KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` nếu BE muốn đối chiếu một tính năng tương tự đã
triển khai được).

**B.3** 🔴 Đổi theo hướng này được không? Nếu BE build payload FCM ở một hàm dùng chung cho **mọi**
loại thông báo (SOS, TASK, CALENDAR...), xin cho biết tên file/hàm đó để FE hiểu được phạm vi ảnh
hưởng trước khi BE sửa.

### B.4 Vì sao chỉ xin đổi riêng `CALL`, không đổi hết

Đổi toàn bộ push sang data-only sẽ **phá vỡ** cơ chế đang chạy ổn định cho các loại thông báo khác
(SOS, TASK, CALENDAR, FINANCE...) — hiện các loại đó **đang dựa vào** đúng hành vi "Android tự vẽ
notification" (comment trong `push_service.dart`: *"Android tự vẽ notification cho message có khối
`notification`, không cần FE làm gì thêm"*). Đổi hết sẽ bắt FE phải tự build lại thông báo cho toàn
bộ 10 loại `NotificationType`, không cần thiết và rủi ro cao ngay trước đợt bảo vệ hội đồng của FE.
**Chỉ cần đổi đúng loại `CALL`** là đủ cho mục tiêu này.

### B.5 Câu hỏi ảnh hưởng phạm vi 🔴

**B.5** Nếu B.3 làm được: việc đổi có ảnh hưởng gì tới các `referenceType` khác không (do dùng
chung hàm/template build payload)? Nếu có rủi ro ảnh hưởng, BE có thể tách riêng nhánh code cho
`CALL` mà không đụng nhánh chung được không?

### B.6 Push "Cuộc gọi nhỡ" — có cần đổi theo không?

`API_DOCS.md` ghi: khi cuộc gọi timeout thành `MISSED`, người **chưa từng bắt máy** nhận thêm 1
push riêng `body: "Cuộc gọi nhỡ"`. Push này **khác bản chất** với push "cuộc gọi đến" ở B.1–B.3 —
đây chỉ là thông báo **thông tin** (cuộc gọi đã kết thúc, không cần hành động ngay, không cần full-
screen-intent). FE **không đề xuất đổi push này** — giữ nguyên dạng notification message hiện tại
là hợp lý.

**B.6** Xác nhận giúp: đúng là 2 push này (cuộc gọi đến vs cuộc gọi nhỡ) là **2 lần gửi riêng biệt**
với `referenceType` giống nhau (`CALL`) nhưng thời điểm/nội dung khác nhau, chứ không phải cùng 1
push? FE cần phân biệt được 2 case này ở tầng `data` nếu B.3 được làm — có thể thêm 1 field như
`callEventType: "incoming" | "missed"` vào `data` để FE tách rõ, hay BE đã có cách phân biệt khác
muốn đề xuất?

---

## Phần C — Bảng tóm tắt để chốt

| # | Việc | Ai làm | Mức độ | Không làm thì sao |
|---|---|---|---|---|
| B.3 | Đổi push `referenceType=CALL` (cuộc gọi đến) sang data-only message | BE | **Bắt buộc cho mục tiêu "tự bật màn cuộc gọi đến khi app nền"** | Cuộc gọi đến khi app nền/khoá máy chỉ có thông báo trơn, người nhận phải tự mở app mới trả lời được — tình huống đúng như hiện tại |
| A.1–A.4 | Xác nhận các điểm suy luận về gọi nhóm | BE | Nên có (chỉ xác nhận) | FE giữ nguyên suy luận hiện tại, sửa lại nếu sau này phát hiện sai qua test thật |
| — | Gọi nhóm (mở nút gọi, layout lưới, logic rời phòng) | FE | ✅ **Đã xong**, chưa test bằng cuộc gọi thật nhiều người | — |
| — | Bấm vào thông báo `CALL` mở đúng màn cuộc gọi (khi app đang mở) | FE | ✅ **Đã xong** | — |
| — | Tự bật `IncomingCallScreen` full-screen khi app nền/khoá máy | FE | Chờ B.3 | Không triển khai được nếu không có B.3 |

## Ghi chú cuối

File `CAU_HOI_BE_VIDEO_CALL_2026-08-11.md` đã có trả lời đầy đủ cho đợt hỏi trước (REST, envelope,
enum, socket, LiveKit token, push cơ bản, mã lỗi) — **không hỏi lại** nội dung đó ở đây. Tài liệu
này chỉ hỏi phần phát sinh từ việc triển khai thực tế gọi nhóm + kiểm thử cuộc gọi đến trên máy
thật ngày 12/08.
