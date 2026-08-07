# Báo cáo & đề xuất BE — Trợ lý AI (AI Chatbot)

Ngày: **2026-08-07** · Người soạn: FE Mobile (nhánh `NDuy`)
Gửi: Nghĩa (Backend), Nhật (Leader)
Nguồn đối chiếu: bản dump OpenAPI `family-care-api.json` trong repo mobile

---

## Tóm tắt một dòng

Luồng AI đã chạy được đầu-cuối cho **ghi thu chi**, **tạo nhiệm vụ**, **từ chối
đề xuất** và **quản lý hội thoại**. Phần còn kẹt gần như toàn bộ nằm ở chỗ
**Swagger không mô tả `pendingAction`** — FE đang phải đoán tên `actionType`, và
đoán sai thì hỏng im lặng, không có lỗi nào để bắt.

---

## 1. `pendingAction` không có schema — mục quan trọng nhất

### Hiện trạng

Cả 7 endpoint AI Chatbot đều **không có response schema nào**:

| Method | Path | Response được khai |
|---|---|---|
| POST | `/families/{familyId}/ai-chatbot/conversations` | 201 (không schema) |
| GET | `/families/{familyId}/ai-chatbot/conversations` | 200 (không schema) |
| GET | `.../conversations/{conversationId}/messages` | 200 (không schema) |
| POST | `.../conversations/{conversationId}/messages` | **chỉ có 502, 503** |
| POST | `.../messages/{messageId}/confirm-action` | **chỉ có 409, 410** |
| POST | `.../messages/{messageId}/reject-action` | 200 (không schema) |
| DELETE | `.../conversations/{conversationId}` | 200 (không schema) |

`POST .../messages` thậm chí không khai response thành công (200/201) — chỉ có
hai nhánh lỗi. Trong `components.schemas` chỉ có `CreateAiConversationDto` và
`SendAiMessageDto` (đều là **request**), **không có schema response nào** tên
kiểu `AiMessageResponseDto` / `PendingActionResponseDto`.

Mô tả của endpoint nói:

> "Nếu AI đề xuất hành động ghi, response chứa `pendingAction` — client gọi
> confirm-action để thực hiện."

Nhưng không nói `pendingAction` có những field gì, `actionType` nhận giá trị nào.

### Hậu quả trên FE

FE đang **đoán** cấu trúc và đỡ mọi biến thể có thể nghĩ ra:

- field bọc: `pendingAction` ở cấp gốc **hoặc** lồng trong message;
- id: `messageId` / `aiMessageId` / `id`;
- nội dung xem trước: `preview` / `payload` / `data`;
- tin nhắn: `aiMessage` / `message` / `content` ở cấp gốc;
- `actionType`: đoán 7 tên (xem mục 2).

Nếu đoán sai `actionType`, hành vi là **hỏng im lặng**: người dùng bấm Xác nhận,
BE tạo dữ liệu thật, FE không nhận ra loại đó nên trước đây không refresh gì cả
— màn hình nhìn như chẳng có chuyện gì xảy ra. Không có exception, không có log,
QA không bắt được.

### Đề nghị BE

1. Bổ sung response DTO cho cả 7 endpoint, đặc biệt `POST .../messages` (thêm
   200/201) và `confirm-action` (thêm 200).
2. Khai `actionType` thành **enum** trong schema, không để `type: string` trần.
3. Cho một sample JSON đầy đủ của response có `pendingAction`.

FE tạm thời đã vá phần rủi ro nhất (2026-08-07): actionType lạ thì refresh cả
ba nguồn dữ liệu và **hiện mã thô ra UI** để không còn hỏng im lặng. Nhưng đây
là băng dán, không thay được contract.

---

## 2. Danh sách `actionType` chính thức

FE hiện nhận diện 7 tên, mỗi nghiệp vụ đoán 2–3 biến thể vì không biết BE đặt
tên theo quy ước nào:

| Nghiệp vụ | Tên FE đang đoán |
|---|---|
| Ghi thu chi | `CREATE_LEDGER_ENTRY`, `CREATE_TRANSACTION`, `FINANCE_LEDGER_CREATE` |
| Tạo nhiệm vụ | `CREATE_TASK`, `TASK_CREATE` |
| Tạo sự kiện lịch | `CREATE_CALENDAR_EVENT`, `CALENDAR_EVENT_CREATE` |

**Xin BE xác nhận đúng tên thật**, kèm quy ước đặt tên cho các loại về sau.

Cũng xin xác nhận các field trong `preview` để FE hiển thị đúng nhãn tiếng Việt
thay vì in key thô. FE đang đọc: `amount`, `categoryName`, `category`,
`description`, `note`, `title`, `dueAt`, `dueDate`, `assignee`, `startTime`,
`endTime`, `location`.

---

## 3. `CREATE_CALENDAR_EVENT` — có thật hay là code chết?

Mô tả của `confirm-action` chỉ nói **"tạo giao dịch/công việc"**, không nhắc
lịch. Nhưng FE đã map sẵn `CREATE_CALENDAR_EVENT` / `CALENDAR_EVENT_CREATE`.

**Câu hỏi:** AI có bao giờ đề xuất tạo sự kiện lịch không?

- Nếu **có** → xin bổ sung vào mô tả và enum `actionType`.
- Nếu **không** → FE sẽ xóa nhánh đó cho gọn. Hiện FE giữ lại vì code vô hại
  (không bao giờ khớp thì không bao giờ chạy), nhưng nó gây hiểu lầm cho người
  đọc code sau này.

---

## 4. Chia ngân sách theo hũ — chưa có `actionType` nào

Nghiệp vụ `POST /families/{familyId}/finance/fund-allocations` là ứng viên rõ
ràng nhất để AI hỗ trợ ("chia lương tháng này theo mô hình 6 hũ"), nhưng hiện
**không có `actionType` nào cho nó**.

Nếu BE muốn mở, cần thống nhất trước vì nghiệp vụ này phức tạp hơn hẳn ghi
thu chi:

- cần `financeModelId` của mô hình **đang ACTIVE**, không phải model bất kỳ;
- cần kỳ (`periodMonth` + `periodYear`);
- ràng buộc tổng tỷ lệ các hũ phải bằng **100%**;
- ràng buộc quỹ khả dụng;
- unique rule `familyId + periodMonth + periodYear` — một gia đình chỉ chia một
  lần trong một kỳ, đổi model cũng không được chia lại;
- đã có 6 mã lỗi riêng, trong đó `409 FUND_ALLOCATION_ALREADY_EXISTS`.

**Đề nghị:** nếu mở cho AI thì `preview` phải hiện đủ **model + kỳ + số tiền
từng hũ** trước khi người dùng bấm xác nhận, và confirm-action phải trả nguyên
văn 6 mã lỗi trên để FE hiển thị đúng, không nuốt thành lỗi chung.

Nếu chưa làm kịp thì cứ để nguyên — FE không mock, sẽ không hiện nút nào.

---

## 5. Ba key gói cước AI chưa có endpoint

Trong enum `featureAccess` của `CreateSubscriptionPlanDto` có 4 key AI:

| Key | Endpoint tương ứng |
|---|---|
| `ai.assistant` | ✅ có (7 endpoint ai-chatbot) |
| `ai.financeSummary` | ❌ không tìm thấy endpoint nào |
| `ai.taskSummary` | ❌ không tìm thấy endpoint nào |
| `ai.savingSuggestions` | ❌ không tìm thấy endpoint nào |

Ba key sau bán được trong gói nhưng không có API để dùng. Xin xác nhận:

- BE sẽ làm endpoint riêng cho chúng, hay
- chúng chỉ là cờ điều khiển hành vi **bên trong** chatbot (ví dụ gói Free thì
  AI từ chối tóm tắt tài chính)?

Câu trả lời quyết định FE gate chúng ở đâu. Hiện FE chỉ đọc để hiển thị quyền
lợi ở màn Gói đăng ký, không gọi API nào.

---

## 6. Cần xác nhận: AI tra cứu dữ liệu theo quyền người hỏi

Mô tả endpoint ghi:

> "AI có thể tra cứu dữ liệu gia đình theo quyền của người hỏi."

Về lý thuyết chạy được, nhưng **chưa ai kiểm chứng thật**. Đây là ranh giới
bảo mật nên FE không dám tự khẳng định. Xin BE xác nhận hoặc cùng test:

1. `FAMILY_MEMBER` hỏi *"tháng này nhà mình chi bao nhiêu?"* — Member vốn bị
   403 ở `GET /finance/ledger/entries` (đã chốt là **by design**). Vậy AI có
   được phép trả lời con số đó không? Nếu AI trả lời thì **AI đang là cửa sau
   vòng qua RBAC**.
2. Member hỏi về khai báo tài chính tháng của **thành viên khác** đã bật riêng
   tư — AI có tôn trọng cờ visibility không?
3. Member hỏi về nội dung chat riêng của người khác — có bị chặn không?

Đây là mục em xin đưa lên **ưu tiên cao**, vì nếu lọt thì hỏng cả mô hình phân
quyền chứ không chỉ hỏng một màn hình.

---

## 7. Đề xuất ranh giới quyền cho AI (xin BE chốt)

Nguyên tắc FE đề nghị: **AI được TẠO, không được DUYỆT, không được XOÁ.**

### Không nên mở cho AI

| Nghiệp vụ | Lý do |
|---|---|
| Duyệt/từ chối yêu cầu chi tiêu | Quyết định tiền bạc thuộc người có quyền |
| Duyệt/từ chối minh chứng công việc | Kéo theo trả thưởng |
| Xử lý tranh chấp thưởng | Cần phán đoán của người |
| Resolve/cancel cảnh báo SOS | Đóng nhầm một cảnh báo thật là nguy hiểm tính mạng |
| Xoá thành viên, trao quyền trưởng nhóm, đổi vai trò | Swagger đã chặn cứng Manager-only, đừng mở lại qua cửa AI |
| Xoá vĩnh viễn ảnh/video | Không hoàn tác được |
| Kích hoạt mô hình tài chính | Đổi model làm giao dịch cũ rơi vào `unmapped` |
| Thanh toán/nâng gói | Dính tiền thật qua Stripe |

### Vùng xám — mở được nhưng `preview` phải rất rõ

| Nghiệp vụ | Điều kiện |
|---|---|
| Giao việc cho thành viên | Preview phải nêu rõ **giao cho ai, hạn nào** |
| Tạo việc lặp lại | Sai lịch lặp là sinh hàng loạt phân công |
| Tạo yêu cầu hỗ trợ chi tiêu | An toàn hơn vì vẫn phải Trưởng nhóm duyệt — 2 lớp chặn |
| Tạo mục tiêu tài chính / danh mục | Sai thì sửa một dòng, rủi ro thấp |
| Gửi tin nhắn vào nhóm chat | Không hoàn tác được về mặt xã hội, dù có API thu hồi |

Nếu BE đồng ý danh sách này, xin phản ánh vào enum `actionType`: **chỉ khai
những loại được phép**, để FE không phải tự phán đoán cái gì an toàn.

---

## Phụ lục — FE đã tự sửa gì trong ngày 2026-08-07

Không cần BE làm gì cho bốn mục này, ghi lại để hai bên khỏi trùng việc:

1. **Sai tên feature key.** FE đọc `ai.enabled` / `ai.chatbot` — cả hai đều
   không nằm trong 26 key chính thức, nên dòng "Trợ lý AI" ở màn Gói đăng ký
   không bao giờ hiện kể cả gói trả phí. Đã đổi sang `ai.assistant` và render
   danh sách quyền lợi bằng cách duyệt đúng 26 key chính thức.
2. **Gate theo gói.** Trước đây icon Trợ lý AI hiện với mọi gói, gói Free bấm
   vào là ăn 403 rồi mới báo. Nay FE đọc `featureAccess` trước, biết chắc không
   có quyền thì hiện màn mời nâng gói, không gọi API. Vẫn **fail-open** khi BE
   trả `featureAccess` rỗng.
3. **Gợi ý câu hỏi.** Màn AI nay có bảng gợi ý chia ba nhóm (tra cứu tài chính /
   tra cứu nhiệm vụ & lịch / nhờ AI tạo), mở khoá phần hỏi đáp vốn đã chạy được
   nhưng không ai dùng vì mở ra chỉ thấy ô nhập trống.
4. **actionType lạ.** Nay refresh cả ba nguồn và hiện mã thô ra UI (xem mục 1).
