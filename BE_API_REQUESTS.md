# Danh sách API cần BE bổ sung — Family Care Mobile

> Cập nhật: 2026-06-24
> Người tổng hợp: FE Team
> Mục đích: Gửi BE để ưu tiên triển khai, unblock các tính năng FE đang bị chặn.
> Đã re-verify trực tiếp qua Swagger (`GET /api/docs-json`) ngày 2026-06-24 — xem mục ✅ RESOLVED bên dưới.

---

## ✅ RESOLVED — Không còn cần BE làm gì

### SOS Alert System (trước đây ghi nhận là CRITICAL/thiếu API)

**Cập nhật 2026-06-21**: Verify lại qua Swagger phát hiện **BE đã triển khai đầy đủ** 8 endpoint dưới
`/api/v1/families/{familyId}/sos/alerts...` (tạo, list, chi tiết, gửi vị trí, phản hồi, confirm-safety, resolve, cancel).
Vấn đề thực ra là **FE gọi sai path** (`/sos` phẳng thay vì `/families/{familyId}/sos/alerts`) — đã sửa trong
`lib/providers/sos_provider.dart`. Không cần BE làm thêm gì cho SOS.

---

## 🐞 BE BUG — cần BE sửa (đã verify bằng kịch bản thật 2026-06-24)

### `GET /families/my` trả về cả gia đình mà user đã bị xoá (status REMOVED)

**Hiện trạng:** Sau khi Manager xoá 1 thành viên (`DELETE /families/{id}/members/{userId}`,
soft-delete → status REMOVED), thành viên đó đăng nhập lại thì `GET /families/my` **VẪN trả về
gia đình đó y hệt** (thậm chí `_count.members` chưa giảm). Trong khi mọi endpoint con
(`GET /families/{id}`, `.../tasks`, ...) lại trả **403 "Tư cách thành viên gia đình không còn
hoạt động"**. → Member kẹt ở màn hình gia đình rỗng (không có task/ví/dữ liệu).

**Mong muốn:** `GET /families/my` chỉ trả về gia đình mà user còn là thành viên **ACTIVE**
(lọc bỏ membership REMOVED/LEFT), nhất quán với check 403 ở các endpoint con.

**FE đã workaround (2026-06-24):** sau khi lấy family từ `/families/my`, gọi thêm
`GET /families/{id}` để xác thực — nếu 403 thì coi như user chưa có gia đình → đưa về
`/family-setup`. Workaround này tốn thêm 1 request mỗi lần login; bỏ được khi BE sửa
`/families/my`.

---

## 🔴 CRITICAL — Tính năng hoàn toàn không chạy được nếu thiếu

### 1. Location Sharing (Bản đồ gia đình)

| | |
|---|---|
| **Chức năng** | Hiển thị vị trí GPS từng thành viên trên bản đồ trong app (dùng flutter_map + OpenStreetMap) |
| **FE đã làm** | Map hiển thị, lấy GPS thiết bị của bản thân, hiện pin trên bản đồ |
| **Vấn đề** | **Verify qua Swagger (2026-06-21): BE chưa có bất kỳ endpoint location/tracking nào** — đã quét toàn bộ 107 path, không có `/location`, `/members/.../location`, `/tracking`. FE (`GpsProvider`) đang gọi `/location/family`, `/location/toggle`, `/location/update` — các path này chắc chắn 404. |
| **Cần thêm** | |

```
POST  /api/v1/families/{familyId}/locations
Body: { latitude, longitude, accuracy?, recordedAt? }
→ Thành viên gửi vị trí lên server (gọi định kỳ khi user cho phép)
   (đặt tên theo đúng convention BE đang dùng cho SOS: .../sos/alerts/{alertId}/locations)

GET   /api/v1/families/{familyId}/members/locations
→ Trả về tọa độ mới nhất của tất cả thành viên đã chia sẻ
Response: [{ userId, displayName, latitude, longitude, recordedAt, isSharing }]

PATCH /api/v1/families/{familyId}/members/me/location-sharing
Body: { isSharing: true | false }
→ Bật/tắt chia sẻ vị trí
```

| **Lý do** | FE đã có GpsProvider + FamilyMapScreen sẵn, chỉ cần BE expose endpoint là cắm vào được ngay. |
|---|---|

---

## 🟠 HIGH — Tính năng chạy được nhưng không đầy đủ

### 2. Chỉnh sửa Profile

| | |
|---|---|
| **Chức năng** | Thành viên chỉnh sửa họ tên, số điện thoại, ảnh đại diện |
| **FE đã làm** | UI edit profile đã có, POST đang mock |
| **Vấn đề** | Chỉ có `GET /auth/me` — không có endpoint UPDATE |
| **Cần thêm** | |

```
PATCH /api/v1/auth/me
Body: { fullName?, phone?, avatarUrl? }
→ Cập nhật thông tin profile của user đang đăng nhập
```

| **Lý do** | `GET /auth/me` đã có → chỉ thiếu PATCH. Ảnh đại diện cần thêm file upload hoặc nhận URL. |
|---|---|

---

### 3. Invite Management (Quản lý lời mời)

> ✅ **Cập nhật 2026-06-24**: BE đã đổi flow sang 2 bước có duyệt (claim → approve) và đã có
> `GET /families/{familyId}/invitations` (lọc qua query `status`, KHÔNG nhận `limit`) — phần đề xuất
> GET ở dưới đã xong, FE đã dùng (`InvitationProvider`, `InvitationRequestsScreen`). Chỉ còn thiếu
> DELETE/cancel lời mời.

| | |
|---|---|
| **Chức năng** | Hủy lời mời đã gửi (chưa được claim) |
| **FE đã làm** | Màn hình invite gửi được; `GET .../invitations` + claim/approve/reject hoạt động đầy đủ |
| **Vấn đề** | Không có endpoint user-facing để hủy lời mời đã tạo nhưng chưa ai claim. Admin endpoint
(`DELETE /admin/invitations/{id}`) có nhưng không dùng được từ FE (SYSTEM_ADMIN only). |
| **Cần thêm** | |

```
DELETE /api/v1/families/{familyId}/invitations/{invitationId}
→ Hủy lời mời chưa được claim/approve (Manager only)
```

| **Lý do** | Manager mời nhầm email/role thì hiện không có cách rút lại — lời mời cứ tồn tại đến khi hết hạn. |
|---|---|

**Đề xuất quan trọng — bỏ bước duyệt thừa (2026-06-24, đã thống nhất với user, CHƯA áp dụng vào FE):**

| | |
|---|---|
| **Chức năng** | Member nhập token join thẳng vào gia đình, không cần Manager duyệt lại lần 2 |
| **Vấn đề hiện tại** | `POST /invitations/{token}/claim` chỉ tạo invitation status `CLAIMED`, phải gọi thêm `POST /families/{id}/invitations/{id}/approve` (Manager) mới tạo `family_member` — 2 bước cho một việc Manager đã "duyệt trước" khi tạo lời mời nhắm đúng email/role/relationship |
| **Cần đổi** | `claim` tạo `family_member` ngay (status `ACTIVE`) bằng `familyRole`/`relationship` đã ghi sẵn trong invitation lúc tạo, trả status `ACCEPTED` luôn — không cần endpoint mới, chỉ đổi logic nội bộ của `claim` |
| **Mức độ** | Nên có — không bắt buộc vì flow hiện tại (claim→approve) đã chạy đúng, chỉ là UX chậm hơn 1 bước |

**Gap khác (chưa cần BE làm ngay, ghi lại để theo dõi):**
- Design họp 19/05 (`COMPONENT_PATTERNS.md`) có mã mời 6 ký tự (vd `A7X-9P2`) để chia sẻ bằng lời
  nói/SMS thường, nhưng BE hiện **chỉ có secure token** (64 ký tự hex, không nhập tay được). Cần BE thêm
  `POST /invitations/code/{shortCode}/claim` (hoặc tương đương) nếu muốn giữ UX nhập mã tay.
- Đã xác nhận (2026-06-24): `claim` **cần đăng nhập** (khác `/accept` cũ là public) — token không tự
  khớp theo email, ai có token + đã login đều claim được, Manager mới là người quyết định duyệt hay
  không qua `approve`/`reject`.
- **Cập nhật 2026 — đã có domain HTTPS (`api.familycare-digital.com`)**: trước đây không làm được App
  Link/Universal Link vì chỉ có IP thô. Giờ domain ổn định + HTTPS rồi nên **khả thi** — chỉ cần BE host
  thêm `/.well-known/assetlinks.json` (Android) / `apple-app-site-association` (iOS, khi có ios/) để OS
  tự mở app khi bấm link `https://api.familycare-digital.com/join?token=...`, không cần copy/paste token
  tay nữa. Đây là việc nên làm tiếp sau khi domain ổn định.

---

### 4. Role Management (Cấp/thu hồi quyền Phó nhóm)

| | |
|---|---|
| **Chức năng** | Trưởng nhóm cấp quyền Deputy hoặc thu hồi quyền của thành viên |
| **FE đã làm** | UI member list hiển thị role, nút thay đổi role đang mock |
| **Vấn đề** | Chỉ có `PATCH /admin/family-members/{id}` — endpoint admin, không gọi được từ user thường |
| **Cần thêm** | |

```
PATCH /api/v1/families/{familyId}/members/{userId}/role
Body: { familyRole: "FAMILY_MEMBER" | "DEPUTY_MEMBER" | "MANAGER" }
→ Trưởng nhóm thay đổi role thành viên
```

| **Lý do** | Tránh dùng admin endpoint từ client app — cần endpoint user-facing với auth check (chỉ MANAGER mới gọi được). |
|---|---|

---

### 5. Wallet / Chi tiêu cá nhân từng thành viên

| | |
|---|---|
| **Chức năng** | Xem lịch sử giao dịch cá nhân của từng thành viên trong ví |
| **FE đã làm** | `expectedPersonalExpense` từ `monthly-finances/me` đã kết nối làm hạn mức. Lịch sử giao dịch đang mock. |
| **Vấn đề** | `GET /families/{id}/finance/ledger/entries` không có filter `memberId` → trả về ledger toàn gia đình |
| **Cần thêm** | |

```
GET /api/v1/families/{familyId}/finance/ledger/entries?memberId={userId}&month=&year=
→ Thêm optional query param memberId để lọc giao dịch theo thành viên

HOẶC:
GET /api/v1/families/{familyId}/members/{userId}/finance/summary
→ Tóm tắt tài chính cá nhân: tổng thu, tổng chi, số dư ước tính trong tháng
```

| **Lý do** | Hiện tại FE không thể phân biệt giao dịch của ai trong ledger chung. |
|---|---|

---

## 🟡 MEDIUM — Tính năng mới hoàn toàn, chưa implement FE

### 6. Chat gia đình

| | |
|---|---|
| **Chức năng** | Nhắn tin trong nhóm gia đình |
| **FE đã làm** | UI placeholder, chưa kết nối |
| **Cần thêm** | |

```
GET  /api/v1/families/{familyId}/messages?limit=50&before={messageId}
POST /api/v1/families/{familyId}/messages
Body: { content, type: "TEXT" | "IMAGE" }

WebSocket: ws://host/families/{familyId}/chat
→ Real-time nhận tin nhắn mới
```

| **Lý do** | REST polling dùng được cho demo, WebSocket cần nếu muốn real-time. |
|---|---|

---

### 7. Lịch gia đình

| | |
|---|---|
| **Chức năng** | Tạo/xem/sửa/xóa sự kiện gia đình |
| **FE đã làm** | UI calendar hiển thị, data mock |
| **Cần thêm** | |

```
GET    /api/v1/families/{familyId}/events?month=&year=
POST   /api/v1/families/{familyId}/events
Body:  { title, description?, startAt, endAt?, isAllDay, color?, assignedTo? }
PATCH  /api/v1/families/{familyId}/events/{eventId}
DELETE /api/v1/families/{familyId}/events/{eventId}
```

---

### 8. Album ảnh gia đình

| | |
|---|---|
| **Chức năng** | Upload và xem ảnh gia đình |
| **FE đã làm** | UI placeholder |
| **Cần thêm** | |

```
GET    /api/v1/families/{familyId}/albums
POST   /api/v1/families/{familyId}/albums
GET    /api/v1/families/{familyId}/albums/{albumId}/photos
POST   /api/v1/families/{familyId}/albums/{albumId}/photos
Body:  multipart/form-data { file, caption? }
DELETE /api/v1/families/{familyId}/albums/{albumId}/photos/{photoId}
```

---

### 9. Thông báo (Notifications)

> ✅ **RESOLVED 2026-06-26**: 3 endpoint dưới **đã tồn tại trên BE** (verify trực tiếp bằng kịch bản
> thật: trigger SOS alert → thấy notification sinh ra). FE đã wire đầy đủ — `NotificationProvider` +
> `notifications_screen.dart` (badge unread ở home Manager/Member, tap-routing theo `type` về
> `/manager|deputy|member/sos|tasks|wallet`). **Lưu ý field**: id thật là `notificationId`, KHÔNG phải
> `id` như hầu hết resource khác trong API này.
>
> Response thật (verify qua SOS alert):
> ```json
> { "notificationId": "...", "familyId": "...", "recipientMemberId": "...",
>   "type": "SOS", "priority": "CRITICAL", "title": "Cảnh báo SOS",
>   "body": "...", "referenceType": "SOS_ALERT", "referenceId": "...",
>   "isRead": false, "readAt": null, "createdAt": "..." }
> ```
> Chỉ verify được `type: SOS` (do tự trigger được) — chưa rõ BE còn sinh notification cho `TASK`/
> `FINANCE`/`INVITATION` hay không (claim/approve invitation, assign task không tạo notification nào
> khi test thử). FE đã code switch-case cho các type đó (`SOS|TASK|FINANCE`) phòng trường hợp BE sinh
> sau, nhưng chưa verify được thực tế.

| | |
|---|---|
| **Còn thiếu** | Push notification (FCM) — chỉ có in-app list, không có khi app background/closed |
| **Cần thêm** | |

```
Push notifications: Firebase FCM token registration
POST /api/v1/auth/fcm-token
Body: { token, platform: "android" | "ios" }
```

---

### 10. AI Assistant

| | |
|---|---|
| **Chức năng** | Chat với AI để tư vấn tài chính gia đình |
| **FE đã làm** | UI chat screen mock |
| **Cần thêm** | |

```
POST /api/v1/families/{familyId}/ai/chat
Body: { message, context?: "finance" | "general" }
Response: { reply, suggestions? }
```

| **Lý do** | BE tích hợp OpenAI/Gemini — FE chỉ cần 1 endpoint đơn giản. |
|---|---|

---

### 11. Subscription / Thanh toán

> ✅ **RESOLVED 2026-06-26**: `GET .../subscription` và `POST .../subscription/checkout` **đã tồn
> tại trên BE** (family-scoped, không phải admin-only → trong scope mobile). FE đã wire:
> `_fetchCurrentSubscription()` lấy gói thật thay hardcode `'FREE'`, `_subscribe()` gọi checkout rồi
> mở URL Stripe qua `url_launcher` (`LaunchMode.externalApplication`).
>
> Verify được response `GET .../subscription`:
> ```json
> { "id": "...", "familyId": "...", "planId": "...", "status": "ACTIVE",
>   "stripeCustomerId": null, "stripeSubscriptionId": null,
>   "currentPeriodEnd": null, "cancelAtPeriodEnd": false,
>   "plan": { "id": "...", "planCode": "FREE", "name": "Gói Miễn phí",
>             "annualPrice": "0", "maxMembers": 3, "storageLimit": 1024, ... } }
> ```
> **Bug FE đã fix**: fallback plan dùng sai mã `FAMILY` — `CreateCheckoutDto.planCode` enum thật là
> `FREE | PLUS | PREMIUM` (verify qua Swagger), đã đổi `'FAMILY'` → `'PLUS'` trong
> `subscription_screen.dart`.

| | |
|---|---|
| **Lưu ý quan trọng** | ⚠️ **Hệ thống KHÔNG giữ tiền người dùng** — chỉ xử lý thanh toán cho gói dịch vụ subscription. Mọi giao dịch tài chính trong app là ghi nhận/kế hoạch, không phải chuyển tiền thực. |
|---|---|

---

## ❓ CẦN BE/PRODUCT XÁC NHẬN — Jar không liên kết với Ledger Entry

> Verify 2026-06-26: `CreateLedgerEntryDto` chỉ có `categoryId`, không có `jarId`/`financeModelId`.
> Nghĩa là khi ghi nhận 1 giao dịch thu/chi thật (`POST /finance/ledger/entries`), tiền **không tự
> động được phân bổ vào lọ nào** trong mô hình tài chính (5 Jars/80-20/Custom) — Jar chỉ là % mục
> tiêu tĩnh, không có field số dư (`balance`), không track được "đã tiêu bao nhiêu % so với target
> của lọ X".

**Cần xác nhận**: đây có phải thiết kế chủ ý (Jar chỉ mang tính tham khảo/giáo dục, Budget Plan +
Category mới là cơ chế theo dõi thật) hay là gap cần bổ sung? Nếu muốn Jar có tác dụng thật, cần thêm:
```
- categoryId trên Jar (hoặc ngược lại) để biết category nào thuộc lọ nào
- Báo cáo "đã chi theo lọ" tương tự reports/overview nhưng group theo jar
```
FE hiện đã sửa màn "Mô hình tài chính" để lưu đúng % người dùng chỉnh + activate đúng flow, nhưng
không thể hiện được "tiến độ chi tiêu theo lọ" vì BE chưa có cơ chế liên kết.

---

## ❓ CẦN BE XÁC NHẬN TRƯỚC KHI HOÀN THIỆN — Subscription Checkout (Stripe)

> Cập nhật 2026-06-26: đã wire checkout cơ bản (xem mục 11). Còn 3/4 điểm dưới đây vẫn cần xác nhận
> trước khi coi flow thanh toán là hoàn chỉnh — chưa test được full vòng đời thanh toán thật vì không
> nên tự tạo Stripe session thật khi không có ý định thanh toán.

### 1. ✅ Mã gói (planCode) — ĐÃ XÁC NHẬN

Verify qua Swagger (`CreateCheckoutDto.planCode`): enum thật là `FREE | PLUS | PREMIUM`. FE đã sửa
fallback plan từ `FAMILY` → `PLUS`, và `_fetchCurrentSubscription()` lấy `planCode` trực tiếp từ
`GET .../subscription` response (không tự ánh xạ theo tên hiển thị).

### 2. ✅ Response schema của checkout endpoint — ĐÃ XÁC NHẬN (2026-06-26)

Verify bằng cách bấm "Nâng cấp" thật trên app + đọc log: response trả `{ checkoutUrl: "https://checkout.stripe.com/..." }`.
FE đã hardcode field đúng, bỏ các fallback tên đoán mù.

### 3. Webhook là nguồn xác nhận thanh toán duy nhất

Deep link `familycare://subscription/success` chỉ cho biết trình duyệt đã quay lại app — **không chứng minh thanh toán đã
thành công** (app khác hoặc user có thể tự gọi URI này). Luồng đề xuất:

1. Stripe redirect về app → FE hiển thị "Đang xác nhận thanh toán".
2. FE gọi `GET /families/{id}/subscription`.
3. BE chỉ trả gói mới sau khi **Stripe webhook đã xác nhận** — không dựa vào `session_id` trong deep link.
4. FE retry ngắn hạn nếu webhook chưa xử lý xong.

⚠️ **Cần xác nhận**: BE đã xử lý Stripe webhook chưa, có kiểm tra session thuộc đúng user/family không, và `GET
/families/{id}/subscription` trả schema gì (đặc biệt là field thể hiện gói đang chờ xác nhận vs. đã active).

### 4. Ý nghĩa của checkout khi chọn gói FREE

Cần xác nhận chọn gói FREE là downgrade, hủy subscription, hay vẫn tạo Stripe Checkout session. Thông thường downgrade/cancel
có lifecycle khác với nâng cấp trả phí (không qua Stripe Checkout).

⚠️ **Cần xác nhận**: endpoint/luồng riêng cho downgrade-to-FREE (nếu có), hay vẫn dùng chung endpoint checkout.

---

## 📊 Tổng kết ưu tiên

| Mức độ | API | Unblock tính năng |
|--------|-----|-------------------|
| ✅ Resolved | SOS endpoints | Đã có sẵn trên BE — bug nằm ở FE, đã sửa |
| ✅ Resolved | Notifications (list/read/read-all) | Đã có sẵn trên BE, FE đã wire đầy đủ (2026-06-26) |
| ✅ Resolved | Subscription GET + checkout cơ bản | Đã có sẵn trên BE, FE đã wire (2026-06-26) — còn 3 câu hỏi webhook/response/FREE ở mục riêng |
| 🔴 Critical | Location sharing | Bản đồ gia đình — BE chưa có endpoint nào |
| 🟠 High | `PATCH /auth/me` | Chỉnh sửa profile |
| 🟠 High | Invite GET/DELETE | Quản lý lời mời |
| 🟠 High | Role management | Cấp/thu quyền Deputy |
| 🟠 High | Ledger `?memberId` filter | Ví cá nhân thành viên |
| 🟡 Medium | Chat | Nhắn tin gia đình |
| 🟡 Medium | Calendar CRUD | Lịch gia đình |
| 🟡 Medium | Album + file upload | Album ảnh |
| 🟡 Medium | Push notification (FCM) | Notification khi app background/closed |
| 🟡 Medium | AI chat | Trợ lý AI |
| 🟡 Medium | Subscription webhook + deep-link return | Xác nhận thanh toán Stripe an toàn (không dựa session_id từ deep link) |

---

## 📌 Ghi chú kỹ thuật

- **Auth**: Tất cả endpoint cần `Authorization: Bearer {accessToken}` header. FE đã có auto-refresh token (401 → POST `/auth/refresh` → retry).
- **Family context**: Hầu hết endpoint dùng path `/families/{familyId}/...` — FE lấy `familyId` từ login response.
- **Response format**: BE đang wrap tất cả response trong `{ success: bool, data: any, message?: string }` — FE đã auto-unwrap, giữ nguyên format này.
- **Pagination**: Dùng `?limit=&page=` hoặc `?limit=&before=cursor` (cursor-based tốt hơn cho real-time chat).
