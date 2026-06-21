# Danh sách API cần BE bổ sung — Family Care Mobile

> Cập nhật: 2026-06-16  
> Người tổng hợp: FE Team  
> Mục đích: Gửi BE để ưu tiên triển khai, unblock các tính năng FE đang bị chặn.

---

## 🔴 CRITICAL — Tính năng hoàn toàn không chạy được nếu thiếu

### 1. SOS Alert System

| | |
|---|---|
| **Chức năng** | UC51/54 — Gửi SOS khẩn cấp, thông báo đến các thành viên gia đình |
| **FE đã làm** | UI giữ 3 giây → lấy GPS thực → cố POST API → graceful fallback (show tọa độ nhưng không notify ai) |
| **Vấn đề** | `POST /api/v1/sos` → **404 Not Found** — endpoint chưa tồn tại |
| **Cần thêm** | |

```
POST   /api/v1/families/{familyId}/sos
Body:  { message, address?, latitude?, longitude? }
→ Tạo SOS alert, push notification đến tất cả thành viên trong gia đình

GET    /api/v1/families/{familyId}/sos
→ Danh sách SOS alerts (manager xem)

PATCH  /api/v1/families/{familyId}/sos/{alertId}
Body:  { status: "ACKNOWLEDGED" | "RESOLVED" | "CANCELLED" }
→ Cập nhật trạng thái SOS

GET    /api/v1/families/{familyId}/sos/active
→ Lấy các alert đang active (để hiện global banner)
```

| **Lý do quan trọng** | Đây là tính năng an toàn — nếu không có API, SOS chỉ chạy cục bộ trên thiết bị gửi, không ai nhận được thông báo. |
|---|---|

---

### 2. Location Sharing (Bản đồ gia đình)

| | |
|---|---|
| **Chức năng** | Hiển thị vị trí GPS từng thành viên trên bản đồ trong app (dùng flutter_map + OpenStreetMap) |
| **FE đã làm** | Map hiển thị, lấy GPS thiết bị của bản thân, hiện pin trên bản đồ |
| **Vấn đề** | Không có API → chỉ xem được vị trí của chính mình, không thấy thành viên khác |
| **Cần thêm** | |

```
POST  /api/v1/families/{familyId}/members/location
Body: { latitude, longitude, accuracy?, updatedAt }
→ Thành viên gửi vị trí lên server (gọi định kỳ khi user cho phép)

GET   /api/v1/families/{familyId}/members/locations
→ Trả về tọa độ mới nhất của tất cả thành viên đã chia sẻ
Response: [{ userId, displayName, latitude, longitude, updatedAt, isSharing }]

PATCH /api/v1/families/{familyId}/members/location/toggle
Body: { isSharing: true | false }
→ Bật/tắt chia sẻ vị trí
```

| **Lý do** | FE đã có GpsProvider sẵn, chỉ cần BE expose endpoint là cắm vào được ngay. |
|---|---|

---

## 🟠 HIGH — Tính năng chạy được nhưng không đầy đủ

### 3. Chỉnh sửa Profile

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

### 4. Invite Management (Quản lý lời mời)

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

---

### 5. Role Management (Cấp/thu hồi quyền Phó nhóm)

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

### 6. Wallet / Chi tiêu cá nhân từng thành viên

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

### 7. Chat gia đình

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

### 8. Lịch gia đình

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

### 9. Album ảnh gia đình

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

### 10. Thông báo (Notifications)

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

### 11. AI Assistant

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

### 12. Subscription / Thanh toán

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

## 📊 Tổng kết ưu tiên

| Mức độ | API | Unblock tính năng |
|--------|-----|-------------------|
| 🔴 Critical | SOS endpoints | An toàn khẩn cấp — core feature |
| 🔴 Critical | Location sharing | Bản đồ gia đình |
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
