# Danh sách API cần BE bổ sung — Family Care Mobile

> Cập nhật: 2026-07-07
> Người tổng hợp: FE Team (Giáp)
> Mục đích: Gửi BE để ưu tiên triển khai, unblock các tính năng FE đang bị chặn.
> Đã re-verify trực tiếp qua Swagger (`GET /api/docs-json`) ngày 2026-07-07 — xem mục ✅ RESOLVED bên dưới.

---

## ✅ RESOLVED — Không còn cần BE làm gì

### SOS Alert System
Verify 2026-06-21: BE đã có đủ 8 endpoint `/families/{familyId}/sos/alerts...`. Bug thực ra ở FE gọi sai path — đã sửa trong `sos_provider.dart`.

### Subscription Checkout (Stripe) — **[RESOLVED 07/07]**
BE đã expose:
```
GET  /families/{familyId}/subscription          → gói hiện tại
POST /families/{familyId}/subscription/checkout → CreateCheckoutDto { planCode }, tạo Stripe checkout
```
- `planCode` chuẩn: `PLUS | PREMIUM` (gói trả phí). Có `stripePriceId` trong plan.
- **FE việc cần làm**: sửa hardcode `FREE/FAMILY/PREMIUM` → `FREE/PLUS/PREMIUM`; nối nút Nâng cấp vào checkout.
- `[VERIFY]` còn 2 điểm hỏi Nghĩa: (1) response body trả field gì (`checkoutUrl`/`url`/`sessionId`?); (2) chọn FREE có phải luồng downgrade riêng không.

### Notifications (in-app) — **[RESOLVED 07/07]**
BE đã expose:
```
GET   /families/{familyId}/notifications?unreadOnly=
PATCH /families/{familyId}/notifications/read-all
PATCH /families/{familyId}/notifications/{notificationId}/read
```
- **FE việc cần làm**: đổi `notification_provider.dart` từ mock sang 3 endpoint này.
- ⚠️ Vẫn thiếu FCM token registration → **push** chưa làm được (xem mục 5 bên dưới).

### Invite Management (list + duyệt) — **[RESOLVED 07/07, flow đổi]**
BE đã đổi sang luồng **claim → approve**:
```
GET  /families/{familyId}/invitations?status=CLAIMED     → xem yêu cầu chờ duyệt
POST /invitations/{token}/claim                          → member gửi yêu cầu join
POST /families/{familyId}/invitations/{id}/approve       → Manager duyệt → tạo FamilyMember
POST /families/{familyId}/invitations/{id}/reject        → Manager từ chối
```
- **FE đã làm xong** (2026-07-07): `JoinFamilyScreen` gọi `/claim` + màn "chờ duyệt"; `InvitationRequestsScreen` cho Manager duyệt join request.
- ✅ Đã trả lời câu hỏi mở cũ: `claim` **có** check email khớp (403 nếu khác) → link mời không dùng chung cho người khác.

### Verify Email OTP — **[RESOLVED 07/07, FE đã wire]**
```
POST /auth/verify-email          Body: VerifyEmailDto { code }
POST /auth/resend-verification
```
- **FE đã làm xong** (2026-07-07): `VerifyEmailScreen` chèn giữa register → create-family, gate qua `AuthProvider.pendingEmailVerification` (xem `computeRedirect` trong `app_router.dart`).

### SOS Location Streaming — **[RESOLVED, FE đã wire 07/07]**
```
POST /families/{familyId}/sos/alerts/{alertId}/locations   Body: PushSosLocationDto
```
- **FE đã làm xong**: `SOSScreen` tự gửi vị trí mỗi 20s từ lúc SOS active tới confirm-safety.

### 4 endpoint BE bổ sung 07/11 — **[RESOLVED, FE đã wire]** (verify swagger 147 paths)
```
POST /auth/forgot-password   Body: { email }                         → BE gửi OTP 6 số
POST /auth/reset-password    Body: { email, code, newPassword }
GET  /families/{id}/sos/alerts/{alertId}/location/current            → vị trí mới nhất
POST /families/{id}/sos/alerts/{alertId}/locations/batch  Body: { points: [] }
```
- **FE đã làm xong**: `forgot_password_screen.dart` (2 bước OTP), `SosProvider.fetchCurrentLocation()` (đã gọi từ `sos_screen.dart`), `SosProvider.pushLocationBatch()` (method sẵn — **chưa nối UI trigger** cho luồng buffer offline).

### Finance Reports + Goal Contribution Plans — **[RESOLVED, FE đã wire 07/07 — nhưng response schema cần verify]**
```
GET  .../budget-plans/{id}/report
GET  .../reports/non-essential-spending
GET  .../reports/budget-goal
GET  .../financial-goals/{goalId}/contribution-suggestions?month&year
POST .../financial-goals/{goalId}/contribution-plans/confirm
GET  .../financial-goals/{goalId}/contribution-plans?month&year
POST .../financial-goals/{goalId}/contribution-plans/{planId}/submit
POST .../financial-goals/{goalId}/contribution-plans/{planId}/approve|reject
GET  .../financial-goals/{goalId}/contribution-shortage?month&year
```
- **FE đã làm xong**: `FinanceReportsScreen` (3 tab), `GoalContributionScreen` (workflow confirm→submit→approve/reject).
- ⚠️ **[VERIFY với Nghĩa]** — 6/6 endpoint GET ở trên **không có response schema trong Swagger** (chỉ có mô tả ngắn dạng text). FE phải:
  - Render report bằng widget generic (`JsonReportView`, key-value đệ quy) vì không biết tên field thật.
  - Với `contribution-plans`, **đoán** field `status` (PENDING/SUBMITTED/APPROVED/REJECTED) và `memberId` (giả định = `user.id`, không phải `familyMember.id`).
  - **Đề nghị BE bổ sung response schema (`@ApiResponse` type) cho 6 endpoint GET này** để FE thay `JsonReportView` bằng UI structured đúng field, và xác nhận `memberId` semantics.

---

## 🔴 CRITICAL — Tính năng hoàn toàn không chạy được nếu thiếu

### 1. Location Sharing (Bản đồ gia đình)

| | |
|---|---|
| **Chức năng** | Hiển thị vị trí GPS từng thành viên trên bản đồ (flutter_map + OpenStreetMap) |
| **FE đã làm** | Map hiển thị, lấy GPS thiết bị bản thân, hiện pin |
| **Vấn đề** | **Verify Swagger 07/07: vẫn không có endpoint location/tracking độc lập.** Chỉ có location trong ngữ cảnh 1 SOS alert (`.../sos/alerts/{alertId}/locations`). `GpsProvider` gọi `/location/family`, `/location/toggle`, `/location/update` → 404. |
| **Cần thêm** | |

```
POST  /api/v1/families/{familyId}/locations
Body: { latitude, longitude, accuracy?, recordedAt? }

GET   /api/v1/families/{familyId}/members/locations
Response: [{ userId, displayName, latitude, longitude, recordedAt, isSharing }]

PATCH /api/v1/families/{familyId}/members/me/location-sharing
Body: { isSharing: true | false }
```

| **Lý do** | FE đã có `GpsProvider` + `FamilyMapScreen`, chỉ chờ endpoint. Đây là 1 trong 2 điểm quan trọng nhất theo Thầy Tài (cùng Finance). |

---

## 🟠 HIGH — Tính năng chạy được nhưng không đầy đủ

### 2. Chỉnh sửa Profile

| | |
|---|---|
| **Vấn đề** | Vẫn chỉ có `GET /auth/me` — chưa có endpoint UPDATE |
| **Cần thêm** | `PATCH /api/v1/auth/me` — Body `{ fullName?, phone?, avatarUrl? }` |

### 3. Role Management (Cấp/thu quyền Phó nhóm — UC18)

| | |
|---|---|
| **Vấn đề** | Vẫn chỉ có `PATCH /admin/family-members/{id}` (admin, không gọi được từ user app) |
| **Cần thêm** | |

```
PATCH /api/v1/families/{familyId}/members/{userId}/role
Body: { familyRole: "FAMILY_MEMBER" | "DEPUTY_MEMBER" | "MANAGER" }
```

| **Lý do** | Cần endpoint user-facing với auth check (chỉ MANAGER). **UC18 vẫn blocked cho tới khi có endpoint này.** |

### 4. Manager hủy lời mời PENDING đã gửi

| | |
|---|---|
| **Vấn đề** | Verify Swagger 07/07: không có `DELETE /families/{familyId}/invitations/{id}` cho Manager. Chỉ có `DELETE /admin/invitations/{id}` (admin-only, không gọi được từ user app). Có 1 endpoint mới `POST /invitations/{token}/reject` nhưng đó là **người được mời tự chối** ("Decline an invitation sent to me"), khác mục đích — Manager không tự hủy được lời mời mình đã gửi nếu gửi nhầm/muốn thu hồi. |
| **Cần thêm** | |

```
DELETE /api/v1/families/{familyId}/invitations/{id}
```
Chỉ cho phép khi status = PENDING (chưa ai claim). Manager-only.

### 5. Wallet / Chi tiêu cá nhân từng thành viên

| | |
|---|---|
| **Vấn đề** | `GET .../finance/ledger/entries` vẫn không có filter `memberId` → trả ledger toàn gia đình |
| **Cần thêm** | Thêm optional query `memberId` cho ledger, HOẶC `GET .../members/{userId}/finance/summary` |

---

## 🟡 MEDIUM — Tính năng mới, chưa có endpoint

### 6. Push Notifications (FCM)
In-app notification đã có (mục RESOLVED). Còn thiếu đăng ký token đẩy:
```
POST /api/v1/auth/fcm-token
Body: { token, platform: "android" | "ios" }
```
> ⚠️ pubspec chưa có Firebase dependency — cần thêm khi làm push.

### 7. Chat gia đình
```
GET  /api/v1/families/{familyId}/messages?limit=50&before={messageId}
POST /api/v1/families/{familyId}/messages   Body: { content, type: "TEXT" | "IMAGE" }
WebSocket: wss://.../families/{familyId}/chat
```
> `[VERIFY]` transport thật (REST polling vs WS) với Nghĩa trước khi wire `chat_screen.dart`.

### 8. Lịch gia đình (Calendar)
```
GET/POST/PATCH/DELETE /api/v1/families/{familyId}/events
Body: { title, description?, startAt, endAt?, isAllDay, color?, assignedTo? }
```

### 9. Album ảnh gia đình
```
GET/POST /api/v1/families/{familyId}/albums
GET/POST/DELETE /api/v1/families/{familyId}/albums/{albumId}/photos  (multipart)
```

### 10. AI Assistant
```
POST /api/v1/families/{familyId}/ai/chat
Body: { message, context?: "finance" | "general" }
```

---

## ✅ Việc FE Mobile phát sinh từ thay đổi 07/07 — ĐÃ LÀM XONG (không chờ BE)

1. ✅ `JoinFamilyScreen`: đổi `POST /invitations/{token}/accept` → `/claim`; thêm state/màn "chờ Manager duyệt" (`CLAIMED`).
2. ✅ Manager UI: thêm màn duyệt join request — `GET /invitations?status=CLAIMED` + `/approve` + `/reject`.
3. ✅ `subscription_screen.dart`: sửa hardcode `FREE/FAMILY/PREMIUM` → `FREE/PLUS/PREMIUM`; nối nút Nâng cấp vào `POST /subscription/checkout`.
4. ✅ Luồng đăng ký: chèn bước OTP `POST /auth/verify-email` trước khi `POST /families` (`VerifyEmailScreen`, 2026-07-07).
5. ✅ `notification_provider.dart`: mock → 3 endpoint notifications thật.
6. ✅ `monthly-finances/me`: thêm query `month`/`year` bắt buộc khi gọi GET.
7. ✅ SOS gửi vị trí liên tục khi alert active (`SOSScreen`, mỗi 20s, 2026-07-07).
8. ✅ Finance Reports (planned-vs-actual, 3 endpoint) + Goal Contribution Plans (6 endpoint, full workflow) — `FinanceReportsScreen` + `GoalContributionScreen`, 2026-07-07.

---

## 📊 Tổng kết ưu tiên (cập nhật 07/07 — sau khi làm xong P0+P1 phía FE)

| Mức độ | API | Trạng thái |
|--------|-----|-----------|
| ✅ Resolved | SOS (đủ, kể cả location streaming) · Subscription checkout · Notifications · Invite claim/approve · Verify email · Finance Reports · Goal Contribution Plans | FE đã wire xong, có trên BE |
| 🔴 Critical | Location sharing độc lập (ngoài SOS) | BE chưa có endpoint — **chặn hoàn toàn**, FE không tự làm được |
| 🟠 High | `PATCH /auth/me` | Edit profile — **chặn hoàn toàn** |
| 🟠 High | `PATCH .../members/{userId}/role` | UC18 Deputy — vẫn blocked |
| 🟠 High | `DELETE /families/{familyId}/invitations/{id}` | Manager hủy lời mời PENDING — mới phát hiện 07/07 |
| 🟠 High | Ledger `?memberId` filter | Ví cá nhân |
| 🟡 Medium | Response schema cho 6 report/contribution GET endpoint | FE đang render generic (`JsonReportView`) vì thiếu schema |
| 🟡 Medium | FCM token · Chat · Calendar · Album · AI | Chưa có endpoint nào — verify lại 07/07, vẫn 0 |

---

## 📌 Ghi chú kỹ thuật
- **Auth**: mọi endpoint cần Bearer token; FE auto-refresh (401 → `/auth/refresh` → retry).
- **Response format**: `{ success, data, message? }` — FE auto-unwrap.
- **Pagination**: `?page=&limit=`.
- **Verify gate mới**: chưa verify email → `POST /families` trả 403.
