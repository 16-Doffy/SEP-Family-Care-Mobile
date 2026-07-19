# Đề xuất chi tiết — Đổi mật khẩu · Verify-later prompt · Thoát gia đình

> Phạm vi: **FE Mobile (Flutter)**. Code hiện tại `giap` @ `e4f283c`. API đối chiếu Swagger prod Tuần 9.
> Ký hiệu: **[LÀM ĐƯỢC NGAY]** đủ API · **[CẦN BE]** thiếu endpoint phía backend · **[VERIFY]** cần xác nhận.

---

## 0. Tóm tắt điều hành

| Tính năng | Hiện trạng | Chặn bởi |
|---|---|---|
| **Đổi mật khẩu** (user đã đăng nhập) | ❌ Chưa có. Tile "Bảo mật" trong Profile `onTap` rỗng. Chỉ có `forgot_password_screen` (dành cho user **đăng xuất**, qua OTP) | BE thiếu `change-password`; interim tái dùng OTP được |
| **Verify-later + prompt điều hướng** | ⚠️ Có gating **nhưng yếu**: cờ `pendingEmailVerification` là **local session, không persist, không đọc từ `/auth/me`**; chỉ chặn khi `!hasFamily`. Không có prompt per-feature khi đụng 403 | Cần BE expose trạng thái verify + FE bắt 403 |
| **Thoát gia đình + báo cả nhà** | ❌ Chưa có. Không có endpoint self-leave (chỉ Manager `DELETE members/{userId}`). Notifications FE read-only | BE thiếu `leave` + emit notification |

Cả 3 đều **đúng như Zap nhận định là còn thiếu**. Chi tiết + đề xuất bên dưới.

---

## 1. ĐỔI MẬT KHẨU

### 1.1. Hiện trạng
- `lib/screens/auth/forgot_password_screen.dart` — route `/forgot-password`, dành cho **chưa đăng nhập**:
  - Bước 1: `POST /auth/forgot-password {email}` → BE gửi OTP 6 số.
  - Bước 2: `POST /auth/reset-password {email, code, newPassword}` → ⚠️ **revoke toàn bộ session** (đăng xuất mọi thiết bị).
- `profile_screen.dart` dòng ~102: `_tile('🔒', 'Bảo mật', onTap: () {})` → **rỗng**, không dẫn đi đâu.
- Không có màn "Đổi mật khẩu" cho user đang đăng nhập.

### 1.2. API backend
| Có | Thiếu |
|---|---|
| `POST /auth/forgot-password` (`{email}`) · `POST /auth/reset-password` (`{email, code, newPassword}`) | ❌ **`POST /auth/change-password {currentPassword, newPassword}`** cho user đã đăng nhập (xác thực bằng mật khẩu cũ, không cần OTP) |

### 1.3. Đề xuất
**[CẦN BE]** Thêm `POST /auth/change-password` — body `{currentPassword, newPassword}`, verify mật khẩu cũ, tùy chọn **không** revoke session hiện tại (chỉ revoke thiết bị khác). Đây là chuẩn UX đổi mật khẩu trong-app.

**[LÀM ĐƯỢC NGAY — interim, chờ BE]** Wire tile "Bảo mật" → màn **Đổi mật khẩu** tái dùng luồng OTP:
- User đã đăng nhập → prefill `email` từ `/auth/me` (ẩn ô email) → `forgot-password` (gửi OTP) → nhập OTP + mật khẩu mới → `reset-password`.
- ⚠️ Vì `reset-password` **revoke all sessions**, sau khi đổi xong phải **đăng xuất + điều hướng `/login`** kèm thông báo "Đổi mật khẩu thành công, vui lòng đăng nhập lại". Chấp nhận được tạm thời; khi có `change-password` thì bỏ bước re-login.

**File cần đụng:** `profile_screen.dart` (wire tile) · `lib/screens/shared/change_password_screen.dart` (**MỚI**) · `auth_provider.dart` (method `changePassword()` khi BE sẵn sàng).

---

## 2. VERIFY-LATER + PROMPT ĐIỀU HƯỚNG

### 2.1. Hiện trạng (đọc kỹ — có lỗ hổng)
Cơ chế verify hiện tại dựa trên **cờ local** `_pendingEmailVerification` trong `auth_provider.dart`:
- Set `true` **chỉ** ngay sau `register()` (cùng phiên), hoặc 1 nhánh login đặc biệt (dòng ~129).
- Comment trong code ghi rõ: *"Không dựa vào field nào từ `/auth/me`"* — tức **không đọc trạng thái verify thật từ BE**.
- **Không persist** (`flutter_secure_storage` không lưu cờ này).

Router (`app_router.dart`) chỉ ép verify khi:
```dart
if (pendingEmailVerification && !hasFamily && !onJoin) return '/verify-email';
```
→ Chỉ chặn user **chưa có gia đình**. Khi đã có gia đình (hoặc đang ở `/join`) → **không chặn gì**.

**Lỗ hổng thực tế:**
1. User đăng ký → chưa verify → **đóng app** → mở lại (restore session): cờ `_pendingEmailVerification` = `false` → client coi như đã verify → chỉ **vỡ khi đụng 403** từ BE (VerifiedGuard).
2. `ApiClient` **không** có xử lý riêng cho 403-verify → chỉ ném `ApiException(403, "Vui lòng xác thực tài khoản...")` như lỗi thường, không có prompt điều hướng.
3. `verify_email_screen` sau khi verify **cứng** `context.go('/family-setup')` — không quay lại đúng màn user đang thao tác.

### 2.2. API backend
| Có | Thiếu / cần xác nhận |
|---|---|
| `POST /auth/verify-email {code}` · `POST /auth/resend-verification` (đã wire trong `auth_provider`) | ⚠️ **`/auth/me` không có response DTO** trong Swagger; `verificationStatus` chỉ thấy ở `AdminUpdateUserDto`. **`[VERIFY]`**: response `/auth/me` thật có trả `isVerified`/`verificationStatus` không? |

Các action **cần verify** (VerifiedGuard — theo tài liệu tích hợp mã mời + Swagger): **tạo gia đình** (`POST /families`), **đổi mã mời** (`invite-code/regenerate`), **duyệt join request** (`join-requests/{id}/approve`). Ngược lại **gửi/hủy join request KHÔNG cần verify**.

### 2.3. Đề xuất (đúng ý: "hiển thị thông báo rồi click điều hướng sang trang verify")

**[CẦN BE / VERIFY]** Expose `isVerified` (hoặc `verificationStatus: PENDING|VERIFIED`) trong response `/auth/me` — để client biết **chắc** trạng thái thay vì đoán bằng cờ local. Đây là gốc rễ; có field này thì gating đáng tin.

**[LÀM ĐƯỢC NGAY] Bắt 403-verify ở tầng chung → prompt điều hướng:**
- Thêm callback `onVerificationRequired` vào `ApiClient` (giống `onSessionExpired` đã có). Khi response **403** và message chứa "xác thực"/"verify" → gọi callback.
- Callback (đăng ký ở `family_shell`/root) hiện **dialog**:
  > "Tài khoản chưa xác thực — Bạn cần xác thực email để dùng tính năng này." → nút **[Xác thực ngay]** → `context.push('/verify-email?returnTo=<màn hiện tại>')`; nút **[Để sau]**.

**[LÀM ĐƯỢC NGAY] Banner cố định trên Home** (mọi role) khi chưa verify:
- Dải màu cảnh báo ở đầu `home_dashboard_screen` + `child_home_screen`: "⚠️ Email chưa xác thực — Xác thực ngay →" → push `/verify-email`.
- Điều kiện hiển thị: dùng `isVerified` từ `/auth/me` (khi BE expose); tạm thời fallback cờ local.

**[LÀM ĐƯỢC NGAY] `verify_email_screen` nhận `returnTo`:**
- Thay `context.go('/family-setup')` cứng bằng: verify xong → nếu có `returnTo` thì quay lại đó, không thì theo role/family như router.

**Luồng tổng (đúng yêu cầu):**
```
User chưa verify bấm 1 tính năng cần verify
   → BE trả 403 "Vui lòng xác thực..."
   → ApiClient bắt 403-verify → onVerificationRequired()
   → Dialog "Chưa xác thực" [Xác thực ngay]
   → push /verify-email?returnTo=...
   → nhập OTP → verifyEmail() OK → quay lại màn cũ, thao tác lại
```

**File cần đụng:** `api_client.dart` (callback 403-verify) · `family_shell.dart` (đăng ký callback + dialog) · `home_dashboard_screen.dart` + `child_home_screen.dart` (banner) · `verify_email_screen.dart` (returnTo) · `auth_provider.dart` (đọc `isVerified` từ `/auth/me` khi BE có).

---

## 3. THOÁT GIA ĐÌNH + THÔNG BÁO CẢ NHÀ

### 3.1. Hiện trạng
- **Không có** nút "Rời gia đình" ở bất kỳ đâu.
- `family_provider.dart` chỉ có `removeMember(userId)` = Manager **xoá người khác** (`DELETE /families/{familyId}/members/{userId}`).
- `member_detail_screen.dart` có label `'REMOVED' => 'Đã rời gia đình'` — chỉ **hiển thị trạng thái**, không có hành động tự rời.
- Notifications: FE **read-only** (`GET /families/{id}/notifications`, mark-read). Không có POST tạo/broadcast. Module notifications từng ghi **stub**, chưa realtime.

### 3.2. API backend
| Có | Thiếu |
|---|---|
| `DELETE /families/{familyId}/members/{userId}` — Swagger ghi **MANAGER only** | ❌ **Endpoint member tự rời** (self-leave). ❌ Cơ chế **notify toàn bộ member** khi có người rời |
| `GET /families/{id}/notifications` (đọc) | ❌ **NotificationType** cho sự kiện rời (không thấy enum `MEMBER_LEFT` trong schema) |

### 3.3. Đề xuất

**[CẦN BE]** Thêm **self-leave**: `POST /families/{familyId}/leave` (member tự rời) — hoặc nới quyền cho member gọi `DELETE members/{ownUserId}` **`[VERIFY]`**. Khi xử lý leave, BE phải:
- Đổi status member → `REMOVED` (soft-delete, khớp cơ chế hiện tại).
- **Tạo notification `MEMBER_LEFT`** gửi cho **toàn bộ member còn lại** (+ push khi có FCM sau này). Đây là phần "báo cả nhà" — **BE bắt buộc emit**, FE không tự broadcast được.

**[CẦN BE] Rule cho Manager rời:** Manager là chủ gia đình → **không được rời khi còn là Manager duy nhất**. BE cần: (a) chặn + yêu cầu **chuyển quyền Manager** cho member khác trước (liên quan `PATCH members/{userId}` đang thiếu — xem đề xuất hồ sơ), hoặc (b) hỗ trợ **giải tán gia đình**. `[VERIFY hướng với BE]`

**[LÀM ĐƯỢC NGAY khi BE ship leave] FE:**
- Thêm nút **"Rời gia đình"** (đỏ) trong `profile_screen` nhóm "Gia đình" cho **Member/Deputy** → dialog xác nhận: *"Bạn sẽ rời khỏi {tên gia đình} và mất quyền xem dữ liệu chung. Tiếp tục?"* → gọi `leaveFamily()` → **clear family context** (xóa familyId khỏi `ApiClient`/`auth`) → điều hướng `/family-setup`.
- Với **Manager**: hiện biến thể "Chuyển quyền trước khi rời" / "Giải tán gia đình" thay vì nút rời trực tiếp.
- `family_provider.dart`: thêm `Future<void> leaveFamily()` gọi endpoint mới.

**[LÀM ĐƯỢC NGAY] Nhận thông báo "có người rời":**
- Đã có sẵn hạ tầng: `family_shell.dart` poll `notifications` mỗi 15s + badge chuông. Khi BE tạo `MEMBER_LEFT`, `notifications_screen` render là xong — **không cần thêm gì phía FE** ngoài việc map icon/label cho type mới.

**Luồng tổng:**
```
Member bấm "Rời gia đình" → confirm
   → POST /families/{id}/leave
   → BE: status=REMOVED + tạo notification MEMBER_LEFT cho các member còn lại
   → FE (người rời): clear family context → /family-setup
   → FE (các member khác): lần poll notifications kế tiếp → chuông đỏ + dòng "X đã rời gia đình"
```

**File cần đụng:** `family_provider.dart` (`leaveFamily()`) · `profile_screen.dart` (nút + confirm) · `auth_provider.dart` (clear family context) · `notifications_screen.dart` (label type `MEMBER_LEFT`).

---

## 4. Bảng ưu tiên tổng hợp

| Ưu tiên | Việc | Loại |
|---|---|---|
| 🔴 P0 | **Verify:** bắt 403-verify → dialog "Xác thực ngay" + banner Home | [LÀM ĐƯỢC NGAY] |
| 🔴 P0 | **Verify:** `verify_email_screen` nhận `returnTo` (bỏ go cứng /family-setup) | [LÀM ĐƯỢC NGAY] |
| 🟠 P1 | **Đổi mật khẩu:** wire tile Bảo mật → màn OTP interim (re-login sau đổi) | [LÀM ĐƯỢC NGAY] |
| 🟠 P1 | **Leave:** nút "Rời gia đình" + `leaveFamily()` (bật khi BE ship endpoint) | [LÀM ĐƯỢC NGAY*] |
| 🟡 P2 | Gửi BE: expose `isVerified` trong `/auth/me` | [CẦN BE] |
| 🟡 P2 | Gửi BE: `POST /auth/change-password` | [CẦN BE] |
| 🟡 P2 | Gửi BE: `POST /families/{id}/leave` + notification `MEMBER_LEFT` + rule Manager rời | [CẦN BE] |

\* phần FE làm sẵn được, chỉ chờ endpoint để bật.

---

## 5. Việc gửi Backend (gộp để nhắn team)

1. **`POST /auth/change-password {currentPassword, newPassword}`** — đổi mật khẩu trong-app, không revoke session hiện tại.
2. **Expose `isVerified`/`verificationStatus` trong `GET /auth/me`** (kèm response DTO) — để FE gating verify đáng tin, không đoán bằng cờ local.
3. **`POST /families/{familyId}/leave`** (member tự rời) — soft-delete status `REMOVED` + **emit notification `MEMBER_LEFT`** cho toàn bộ member còn lại; định nghĩa **rule Manager rời** (chuyển quyền / giải tán).
4. Xác nhận `NotificationType` có value cho sự kiện rời/tham gia để FE map icon/label. `[VERIFY]`

---

*Mọi endpoint/nhận định lấy từ code `giap@e4f283c` + Swagger prod Tuần 9 (16/07). Mục `[VERIFY]` cần xác nhận với BE trước khi wire.*
