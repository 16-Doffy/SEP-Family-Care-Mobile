
# Family Care — Mobile App

**SU26SE032** · Flutter Mobile Application · Capstone Project SEP

Ứng dụng quản lý gia đình toàn diện: tài chính, nhiệm vụ, lịch, SOS khẩn cấp và giao tiếp nội bộ gia đình.

---

## Thông tin dự án

| | |
|---|---|
| **Tên dự án** | Family Care |
| **Mã dự án** | SU26SE032 |
| **Platform** | Flutter (Android / Web). Wear OS: UI có sẵn ở `lib/wear/`, chưa cấu hình build app riêng. iOS: chưa setup (không có thư mục `ios/`) |
| **Backend** | `https://api.familycare-digital.com/api/v1` |
| **API Docs** | `https://api.familycare-digital.com/api/docs` |
| **Branch chính** | `main` |
| **Version** | 1.0.0+1 |

---

## Tech Stack

| Layer | Library | Version |
|---|---|---|
| Framework | Flutter | SDK ^3.12.0 |
| Navigation | go_router | ^14.3.0 |
| State Management | provider | ^6.1.2 |
| HTTP | http | ^1.2.0 |
| Font | google_fonts (Inter) | ^6.2.1 |
| Secure storage (session) | flutter_secure_storage | ^9.2.2 |
| Bản đồ | flutter_map + latlong2 | ^7.0.2 / ^0.9.1 |
| GPS | geolocator | ^13.0.0 |
| Chọn ảnh | image_picker | ^1.1.2 |
| Mở link ngoài | url_launcher | ^6.3.0 |

---

## Cấu trúc thư mục

```
lib/
├── main.dart
├── models/              # AppUser, MoneyRequest, ...
├── navigation/          # app_router.dart, manager_shell, member_shell
├── providers/           # AuthProvider, WalletProvider, TaskProvider,
│                        # FinanceProvider, FinanceAlertProvider, SupportRequestProvider, ...
├── screens/
│   ├── auth/            # LoginScreen, RegisterScreen, JoinFamilyScreen
│   ├── parent/          # HomeDashboard, WalletScreen, TaskManagement,
│   │                    # BudgetPlanScreen, FinancialGoalScreen, FinanceAlertsScreen,
│   │                    # SupportRequestScreen, ...
│   ├── child/           # ChildHome, ChildTasks, ChildWallet
│   └── shared/          # SOS, FamilyMapScreen, Chat, Album, Profile, AI Assistant, SplashScreen
├── services/            # ApiClient (singleton HTTP client, timeout + auto-refresh)
├── theme/               # AppColors, design tokens
└── widgets/             # RingChart, WaffleChart, ...

lib/wear/                # Wear OS companion UI (chưa cấu hình thành app/flavor riêng)
android/
web/
```

---

## Roles & Navigation

Cả 3 role dùng chung 1 widget `FamilyShell` (`lib/navigation/family_shell.dart`) — khác biệt chỉ ở
3 tab giữa (`middleTabs`) và route đích, định nghĩa ở `app_router.dart`. Tab Trang chủ (0) và Tôi (5)
cố định, slot SOS (3) luôn là nút tròn đỏ giống nhau ở cả 3 shell.

| Role | Bottom nav (Trang chủ / 1 / 2 / SOS / 4 / Tôi) | Vào từ |
|---|---|---|
| `MANAGER` (Trưởng nhóm) | Trang chủ, **Nhắn tin, Lịch**, SOS, **Album**, Tôi → `/manager/*` | Đăng ký mới → tự động |
| `DEPUTY` (Phó nhóm) | Trang chủ, **Nhiệm vụ, Ví**, SOS, **Chat**, Tôi → `/deputy/*` (mở thẳng màn hình quản lý — `TaskManagementScreen`/`WalletScreen`, không phải màn member) | Được Manager cấp quyền (UC18 — hiện chỉ làm được qua admin API, chưa có endpoint user-facing) |
| `MEMBER` (Thành viên) | Trang chủ, Nhiệm vụ, Ví, SOS, Chat, Tôi → `/member/*` | Tham gia qua link / QR / mã mời |

Deputy về bản chất vẫn là Family Member được cấp quyền hạn chế (không phải actor độc lập — theo
BR-ROLE-02), nên **không dùng chung shell với Manager**. Router (`computeRedirect` trong
`app_router.dart`) cô lập 3 shell theo `_managerShellPaths`/`_deputyShellPaths`/`_memberShellPaths`,
nhưng vẫn mở các route quản lý dùng chung (`/manager/members`, `/manager/wallet`,
`/manager/finance-model`, `/manager/budget-plans`...) cho Deputy vì các route này không nằm trong 3
set path kể trên.

### Capability matrix (`AppUser` trong `lib/models/user.dart`)

| Quyền | Manager | Deputy | Member |
|---|---|---|---|
| `canManageTasks` / `canManageFinance` / `canApproveSupportRequests` / `canManageCalendar` / `canResolveSos` | ✅ | ✅ | ❌ |
| `canManageMemberRoles` (cấp/thu Deputy) | ✅ | ❌ | ❌ |
| `canRemoveMembers` | ✅ | ❌ | ❌ |
| `canManageSubscription` | ✅ | ❌ | ❌ |
| `canInviteMembers` | ✅ | ❌ (đã verify BE thật trả 403 cho Deputy, 2026-06-22) | ❌ |

`isAdministrative` (= Manager hoặc Deputy) chỉ còn dùng cho nhóm quyền chung ở trên — các hành động
nhạy cảm (xoá thành viên, cấp/thu Deputy, mời, subscription) **không** dựa vào `isAdministrative` nữa,
tránh lỗ hổng Deputy gọi được API quản trị qua UI (đã xảy ra trước khi tách capability).

---

## Cài đặt & Chạy

### Yêu cầu

- Flutter SDK ≥ 3.12.0
- Dart ≥ 3.0.0
- Android Studio / VS Code

### Cài dependencies

```bash
flutter pub get
```

### Chạy app

```bash
# Android emulator / device
flutter run

# Chỉ định API URL khác (mặc định: https://api.familycare-digital.com/api/v1)
flutter run --dart-define=API_BASE_URL=https://your-server/api/v1
```

### Build APK

```bash
flutter build apk --release
```

---

## Flows đã implement

### ✅ Auth
- Đăng ký → tự động tạo gia đình → role MANAGER. Số điện thoại **bắt buộc** (BE yêu cầu đủ
  `{ email, password, fullName, phone }`) — bỏ trống bị validate ngay ở FE, số đã tồn tại được map
  thành thông báo rõ "Số điện thoại đã tồn tại" thay vì exception thô từ BE
- Đăng nhập → lấy familyId từ `/families/my`
- Đăng xuất (revoke refresh token)

### ✅ Finance (kết nối API thực)
- Xem tổng quan quỹ gia đình (`/finance/overview`)
- Lịch sử thu/chi (`/finance/ledger/entries`) — dấu +/- và tổng thu nhập tính theo `entryType`
  (`INCOME`/`TRANSFER_IN` = thu, `EXPENSE`/`TRANSFER_OUT` = chi) qua `signedAmount`, không suy đoán từ `amount > 0`
- Yêu cầu hỗ trợ chi tiêu (`/finance/support-requests`)
- Mô hình tài chính — 5 Jars, 80-20, Custom (`/finance/models`)
- Kế hoạch ngân sách, mục tiêu tài chính

### ✅ Task & Reward (kết nối API thực, `/families/{id}/tasks/...`)
- Tạo task ad-hoc (UC38) và định kỳ (UC39)
- Giao task / reassign (UC40, UC42)
- Báo bận — recurring task (UC41)
- Duyệt / từ chối task (UC44) — `TaskProvider.fetchLatestSubmission()` gọi riêng
  `GET .../assignments/{id}/submissions` trước khi mở sheet duyệt, vì endpoint danh sách assignment
  (`GET .../tasks/{taskId}/assignments`) không trả kèm submission nên field `latestSubmissionId`
  luôn null dù status đã `SUBMITTED` — sửa banner "Không tìm thấy bài nộp" xảy ra 100% các lần
- Reward settlement flow: PENDING → SETTLED → CONFIRMED / DISPUTED (UC46–48)

### ✅ Family Management
- Mời thành viên: QR / link / token (UC15, UC16) — **Manager only**, Deputy đã verify BE trả 403
- Tham gia qua token — **BE đổi flow 2026-06-24, không còn join tức thì**:
  1. Member dán token vào `JoinFamilyScreen` → `POST /invitations/{token}/claim` (**cần đăng nhập**,
     khác với `/accept` cũ là public) → status `CLAIMED`, chờ Manager duyệt
  2. Manager duyệt/từ chối qua `InvitationRequestsScreen` (`/manager/invite-requests`, manager-only,
     badge đỏ số người chờ ở `member_list_screen`) → `POST .../invitations/{id}/approve|reject` → tạo
     `family_member` thật
  - `claim` cần đăng nhập nên nếu user chưa login, token được lưu lại (`AuthProvider.pendingInviteToken`,
    qua `flutter_secure_storage` — sống sót qua cold-start) và tự điều hướng lại `/join?token=...` sau
    khi login/register xong, không bị mất
  - Đã fix (2026-06-24): `InvitationProvider.fetchInvitations()` gọi thừa `?limit=100` — BE chỉ nhận
    query `status` (enum), gửi `limit` bị validation chặn toàn bộ request → màn duyệt luôn báo
    "Lỗi tải dữ liệu", badge luôn 0. Đã bỏ param thừa.
  - ⚠️ Đã đề xuất BE (chưa áp dụng): đổi `claim` tự tạo member ngay (bỏ bước `approve` riêng) vì
    invitation đã được Manager target sẵn 1 email/role/relationship cụ thể lúc tạo — coi như đã duyệt
    trước. Khi BE đổi, cần sửa lại `join_family_screen.dart` (bỏ dialog "chờ duyệt"),
    `invitation_provider.dart`, có thể bỏ badge "Yêu cầu" ở `member_list_screen.dart`
  - ⚠️ Link mời hiện là `https://api.familycare-digital.com/join?token=<64-hex>` (chưa phải App
    Link/Universal Link thật) — chỉ hoạt động qua copy/dán/clipboard trong `JoinFamilyScreen`,
    **chưa wire Android Intent Filter / iOS Universal Link** nên OS chưa tự mở app khi bấm link
  - ⚠️ Mã mời 6 ký tự trong design (COMPONENT_PATTERNS) chưa có endpoint BE tương ứng — chỉ token
    64-hex, xem `BE_API_REQUESTS.md` mục Invite Management
- Danh sách thành viên (UC20) — Manager/Deputy xem đầy đủ + có hành động quản lý; Member xem read-only
  qua route dùng chung `/manager/members`
- Cấp/thu quyền Phó nhóm (UC18) — **Manager only**, đang chờ BE endpoint user-facing (xem
  `BE_API_REQUESTS.md` mục 4), FE chỉ hiện action khi `canManageMemberRoles`
- Xoá thành viên (UC19) — **Manager only** (`canRemoveMembers`). BE **soft-delete**
  (`DELETE /families/{id}/members/{userId}` chỉ set `status: REMOVED`, không xoá khỏi `members` array
  của `GET /families/{id}`) — đã fix (2026-06-24): `FamilyProvider.fetchMembers()` lọc
  `status == ACTIVE`, `removeMember()` nuốt lỗi 404 "not found" (nghĩa là đã xoá trước đó) thay vì ném
  lỗi gây bối rối

### ✅ SOS & Safety (kết nối API thực, `/families/{id}/sos/alerts...`)
- Nút SOS giữ 3 giây (UC50)
- Nhận cảnh báo SOS từ thành viên khác, global banner ở `FamilyShell` (chung cho cả 3 role, banner
  bấm vào chuyển tab SOS trong shell hiện tại — không dùng route `/sos` cố định) (UC51)
- Xác nhận an toàn (`confirm-safety`) / phản hồi (`responses`: VIEWED) / resolve & cancel (UC52, UC53)
  — đã sửa lại đúng theo Swagger thật (2026-06-22):
  - Bỏ status `ACKNOWLEDGED` giả (BE chỉ có `ACTIVE/RESOLVED/CANCELED/FALSE_ALARM`) — "Tôi đang đến" giờ
    gọi đúng `/responses` (VIEWED) thay vì vô tình đóng cảnh báo qua `/resolve`
  - Tách `resolveAlert()`/`cancelAlert()` riêng (bỏ `updateAlert()` ánh xạ ngầm); nút "Đã xử lý"/"Xong"
    chỉ hiện với Manager/Deputy (`canResolveSos`) — khớp role-restriction `/resolve`, `/cancel` của BE
  - Người gửi tự đóng SOS của mình qua `confirm-safety` (không bị 403 như `/cancel`)
  - Không gửi `address` lên BE (field không có trong `CreateSosAlertDto`, tránh rủi ro 400)
  - `sendSos()` bắt buộc trả `alertId`, mọi action mutating throw rõ khi thiếu family context hoặc lỗi
    mạng — UI hiển thị lỗi qua SnackBar, khoá nút khi đang gửi
  - Test riêng cho `SosProvider`: `test/sos_provider_test.dart`
  - ⚠️ Chưa làm: gửi vị trí liên tục khi SOS active (`POST .../locations`), xem chi tiết 1 alert
    (`GET .../alerts/{id}`), nhận cảnh báo realtime (hiện chỉ fetch 1 lần lúc vào màn hình)

### ✅ Calendar
- 5 loại sự kiện màu sắc riêng: Task / Sự kiện / Du lịch / Sinh nhật / Sức khỏe (UC70, UC71)

### ✅ Subscription
- Xem / chọn gói: Free / Family (99k₫) / Premium (299k₫) (UC76, UC77)
- Nút "Nâng cấp" hiện chỉ show dialog — checkout/thanh toán thật chưa làm, xem mục "Subscription / Thanh toán" trong `BE_API_REQUESTS.md`

### ⚠️ Chờ Backend
- GPS / Location sharing (`/location/...`) — **BE chưa có endpoint nào** cho location (đã verify qua Swagger `/api/docs-json`), `GpsProvider`/`FamilyMapScreen` hiện không hoạt động
- Profile PATCH (`/auth/me`) — BE chỉ có `GET`, chưa có `PATCH` để cập nhật họ tên/SĐT/avatar
- Subscription checkout (Stripe) — BE chỉ có `GET /subscription-plans`, chưa có endpoint tạo checkout session

---

## API Reference

Xem chi tiết tại [`API_DOCS.md`](API_DOCS.md) hoặc Swagger UI: `https://api.familycare-digital.com/api/docs`

---

## Wear OS

Companion UI cho Wear OS nằm trong `lib/wear/` (`main_wear.dart` + `screens/wear_*`). Dùng chung
`AuthProvider`/`SosProvider`/`GpsProvider` với app điện thoại — **chưa đóng gói thành app/flavor riêng** để cài lên đồng hồ thật.
- Xem trạng thái SOS, danh sách cảnh báo
- Trigger SOS từ đồng hồ (UC57) — dùng `SosProvider` đã sửa đúng path `/families/{id}/sos/alerts` (xem mục SOS & Safety)
- Hiển thị task và thông báo (UC58)
- ⚠️ Vị trí GPS gửi qua `GpsProvider` vẫn không hoạt động — BE chưa có endpoint location (xem mục "Chờ Backend")

---

## Commit Convention

```
feat:   Tính năng mới
fix:    Sửa lỗi
refactor: Tái cấu trúc code
chore:  Cập nhật dependencies, config
```
