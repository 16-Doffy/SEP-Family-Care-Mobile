# Danh sách API cần BE bổ sung — Family Care Mobile

> Cập nhật: 2026-06-21
> Người tổng hợp: FE Team
> Mục đích: Gửi BE để ưu tiên triển khai, unblock các tính năng FE đang bị chặn.
> Đã re-verify trực tiếp qua Swagger (`GET /api/docs-json`) ngày 2026-06-21 — xem mục ✅ RESOLVED bên dưới.

---

## ✅ RESOLVED — Không còn cần BE làm gì

### SOS Alert System (trước đây ghi nhận là CRITICAL/thiếu API)

**Cập nhật 2026-06-21**: Verify lại qua Swagger phát hiện **BE đã triển khai đầy đủ** 8 endpoint dưới
`/api/v1/families/{familyId}/sos/alerts...` (tạo, list, chi tiết, gửi vị trí, phản hồi, confirm-safety, resolve, cancel).
Vấn đề thực ra là **FE gọi sai path** (`/sos` phẳng thay vì `/families/{familyId}/sos/alerts`) — đã sửa trong
`lib/providers/sos_provider.dart`. Không cần BE làm thêm gì cho SOS.

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

| | |
|---|---|
| **Chức năng** | Xem danh sách lời mời đang pending, hủy lời mời đã gửi |
| **FE đã làm** | Màn hình invite gửi được, join bằng UUID token hoạt động |
| **Vấn đề** | Không có endpoint user-facing để liệt kê/hủy lời mời. Admin endpoint có nhưng không dùng được từ FE. |
| **Cần thêm** | |

```
GET    /api/v1/families/{familyId}/invitations
→ Danh sách lời mời pending của gia đình (hiện cho manager)

DELETE /api/v1/families/{familyId}/invitations/{invitationId}
→ Hủy lời mời chưa được chấp nhận
```

| **Lý do** | `POST /families/{familyId}/invitations` đã có → thiếu GET/DELETE để quản lý. |
|---|---|

**Gap khác (chưa cần BE làm ngay, ghi lại để theo dõi — 2026-06-22):**
- Design họp 19/05 (`COMPONENT_PATTERNS.md`) có mã mời 6 ký tự (vd `A7X-9P2`) để chia sẻ bằng lời
  nói/SMS thường, nhưng BE hiện **chỉ có UUID token** (36 ký tự, không nhập tay được). Cần BE thêm
  `POST /invitations/code/{shortCode}/accept` (hoặc tương đương) nếu muốn giữ UX nhập mã tay.
- Cần xác nhận: `POST /invitations/{token}/accept` có yêu cầu user đăng nhập khớp `email` trong
  `CreateInvitationDto` không? Ảnh hưởng tới việc link mời có thể chia sẻ rộng (ai bấm cũng join được)
  hay chỉ dùng được bởi đúng người được nhắm tới qua email.
- Link mời hiện là HTTP thường tới IP backend (`http://103.110.84.66/join?token=...`), chưa phải App
  Link/Universal Link — muốn OS tự mở app khi bấm link cần domain HTTPS ổn định + file xác minh
  (`assetlinks.json`/`apple-app-site-association`), không làm được với IP thô.

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

| | |
|---|---|
| **Chức năng** | Xem lịch sử thông báo, đánh dấu đã đọc |
| **FE đã làm** | UI notifications screen mock |
| **Cần thêm** | |

```
GET   /api/v1/families/{familyId}/notifications?limit=20&page=1
PATCH /api/v1/families/{familyId}/notifications/{notificationId}/read
PATCH /api/v1/families/{familyId}/notifications/read-all

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

| | |
|---|---|
| **Chức năng** | Nâng cấp gói dịch vụ (FREE → PLUS → PREMIUM) |
| **FE đã làm** | `GET /subscription-plans` đã kết nối, hiển thị danh sách gói. Nút "Nâng cấp" đang show dialog "liên hệ hỗ trợ". |
| **Vấn đề** | Không có endpoint thanh toán/upgrade |
| **Cần thêm** | |

```
POST /api/v1/families/{familyId}/subscription/upgrade
Body: { planId, paymentMethod: "BANK_TRANSFER" | "MOMO" | ... }
→ Tạo đơn nâng cấp / redirect đến payment gateway

GET  /api/v1/families/{familyId}/subscription
→ Xem gói hiện tại của gia đình, ngày hết hạn
```

| **Lưu ý quan trọng** | ⚠️ **Hệ thống KHÔNG giữ tiền người dùng** — chỉ xử lý thanh toán cho gói dịch vụ subscription. Mọi giao dịch tài chính trong app là ghi nhận/kế hoạch, không phải chuyển tiền thực. |
|---|---|

---

## ❓ CẦN BE XÁC NHẬN TRƯỚC KHI FE TRIỂN KHAI — Subscription Checkout (Stripe)

> Bối cảnh: FE đang lên kế hoạch nối nút "Nâng cấp" (`lib/screens/parent/subscription_screen.dart:178`) vào checkout thật qua
> Stripe + deep link `familycare://subscription/success`. Trước khi sửa code, cần BE xác nhận 4 điểm sau để tránh đoán sai
> contract dẫn đến lỗi thanh toán.

### 1. Mã gói (planCode) chính xác

BE được mô tả dùng `FREE | PLUS | PREMIUM`, trong khi FE đang fallback hardcode `FREE | FAMILY | PREMIUM`
(`lib/screens/parent/subscription_screen.dart:17`). Nếu FE gửi sai mã gói, checkout có thể trả 400.

⚠️ **Cần xác nhận**: enum `planCode` chính xác trả về từ `GET /subscription-plans`. FE sẽ dùng trực tiếp giá trị này, không tự
ánh xạ theo tên hiển thị.

### 2. Response schema của checkout endpoint

Tài liệu nội bộ hiện ghi `POST /subscription/upgrade` (mục 12 ở trên), nhưng cần xác nhận lại tên endpoint thật
(`/subscription/checkout`?) và schema response chính xác, ví dụ:

```
{ "checkoutUrl": "https://checkout.stripe.com/...", "sessionId": "cs_..." }
```

⚠️ **Cần xác nhận**: tên field thật là `url`, `checkoutUrl`, hay nằm trong `data.url`; và danh sách mã lỗi có thể trả về.

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
| 🔴 Critical | Location sharing | Bản đồ gia đình — BE chưa có endpoint nào |
| 🟠 High | `PATCH /auth/me` | Chỉnh sửa profile |
| 🟠 High | Invite GET/DELETE | Quản lý lời mời |
| 🟠 High | Role management | Cấp/thu quyền Deputy |
| 🟠 High | Ledger `?memberId` filter | Ví cá nhân thành viên |
| 🟡 Medium | Chat | Nhắn tin gia đình |
| 🟡 Medium | Calendar CRUD | Lịch gia đình |
| 🟡 Medium | Album + file upload | Album ảnh |
| 🟡 Medium | Notifications + FCM | Push notifications |
| 🟡 Medium | AI chat | Trợ lý AI |
| 🟡 Medium | Subscription upgrade | Nâng cấp gói |

---

## 📌 Ghi chú kỹ thuật

- **Auth**: Tất cả endpoint cần `Authorization: Bearer {accessToken}` header. FE đã có auto-refresh token (401 → POST `/auth/refresh` → retry).
- **Family context**: Hầu hết endpoint dùng path `/families/{familyId}/...` — FE lấy `familyId` từ login response.
- **Response format**: BE đang wrap tất cả response trong `{ success: bool, data: any, message?: string }` — FE đã auto-unwrap, giữ nguyên format này.
- **Pagination**: Dùng `?limit=&page=` hoặc `?limit=&before=cursor` (cursor-based tốt hơn cho real-time chat).
