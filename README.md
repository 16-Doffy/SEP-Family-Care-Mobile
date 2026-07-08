
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
- Đăng ký → role MANAGER. Số điện thoại **bắt buộc** (`{ email, password, fullName, phone }`) — validate
  ở FE, số đã tồn tại map thành thông báo rõ ràng
- ✅ **Verify email (BE 07/07, wire FE 2026-07-07)**: `POST /auth/verify-email { code }` (OTP 6 số) + `/auth/resend-verification`
  (cooldown 60s ở FE, BE tự rate-limit). `VerifyEmailScreen` chèn giữa register và create-family — router chặn qua
  `AuthProvider.pendingEmailVerification` (set `true` ngay sau `register()`, và reactive nếu `POST /families` trả 403
  "chưa verify" cho tài khoản cũ). Không chặn luồng join-by-invitation (`/invitations/{token}/claim` không cần verify).
- Đăng nhập → lấy familyId từ `/families/my`
- Đăng xuất (revoke refresh token)

### ✅ Finance (kết nối API thực)
- Xem tổng quan quỹ gia đình (`/finance/overview`)
- Lịch sử thu/chi (`/finance/ledger/entries`) — dấu +/- và tổng thu nhập tính theo `entryType`
  (`INCOME`/`TRANSFER_IN` = thu, `EXPENSE`/`TRANSFER_OUT` = chi) qua `signedAmount`, không suy đoán từ `amount > 0`
- Yêu cầu hỗ trợ chi tiêu (`/finance/support-requests`)
- Mô hình tài chính — 5 Jars, 80-20, Custom (`/finance/models`)
- Kế hoạch ngân sách, mục tiêu tài chính (`budget_plan_screen.dart`, `financial_goal_screen.dart`)
- ✅ **Báo cáo planned-vs-actual (2026-07-07)**: `FinanceReportsScreen` (`/manager/finance-reports`) — 3 tab
  gọi `budget-plans/{id}/report`, `reports/non-essential-spending`, `reports/budget-goal`. Response schema
  BE không document → render bằng `JsonReportView` (key-value đệ quy, generic), chưa structured theo field
  cụ thể — cần chạy thật để xác nhận tên field rồi nâng cấp UI.
- ✅ **Goal Contribution Plans (2026-07-07)**: `GoalContributionScreen` (`/manager/goal-contribution?goalId=`), vào
  từ nút trên thẻ mục tiêu trong `financial_goal_screen.dart`. Workflow: Manager/Deputy "Xác nhận kế hoạch" (confirm,
  per-member) → Member "Tôi đã đóng góp" (submit) → Manager/Deputy "Duyệt/Từ chối" (approve/reject). Có gợi ý đóng
  góp (contribution-suggestions) và báo cáo thiếu hụt (contribution-shortage, qua `JsonReportView`).
  ⚠️ **`status` (PENDING/SUBMITTED/APPROVED/REJECTED) và `memberId` = `user.id` là SUY LUẬN**, BE không document
  response schema của 3 endpoint GET — chưa verify trực tiếp trên BE thật (xem `API_DOCS.md` mục "Goal Contribution
  Plans", có `[VERIFY]`).
- ✅ **Toàn bộ endpoint Finance BE-có-nhưng-FE-chưa-gọi đã nối xong (2026-07-08)** — 10 endpoint còn lại trong 42
  endpoint Finance:
  - `BudgetPlanDetailScreen` (`/manager/budget-plans/detail?planId=`, tap vào thẻ plan): GET chi tiết kèm `lines`,
    PATCH sửa plan DRAFT, PATCH/DELETE từng dòng ngân sách.
  - `GoalDetailScreen` (`/manager/goal-detail?goalId=`, tap vào thẻ mục tiêu): GET chi tiết, PATCH sửa, GET tiến độ
    chi tiết, GET/PATCH/DELETE lịch sử từng lần góp (`goal-allocations`).
  - `FinanceAlertsScreen`: tap vào cảnh báo → chi tiết (`_AlertDetailSheet`); nút 🔄 → tính lại cảnh báo (`recompute`).
  - `SupportRequestScreen`: tap vào yêu cầu → chi tiết (`_RequestDetailSheet`).
  - `FinanceModelScreen`: nút ℹ️ → xem mẫu mô hình BE (`model-templates`, chỉ tham khảo).
  - Tất cả field GET không có schema document đều render qua `JsonReportView` — không đoán tên field sai.

### ✅ Task & Reward (kết nối API thực, `/families/{id}/tasks/...`)
- Tạo task ad-hoc (UC38) và định kỳ (UC39)
- Giao task / reassign (UC40, UC42)
- Báo bận — recurring task (UC41)
- Duyệt / từ chối task (UC44) — `TaskProvider.fetchLatestSubmission()` gọi riêng
  `GET .../assignments/{id}/submissions` trước khi mở sheet duyệt, vì endpoint danh sách assignment
  (`GET .../tasks/{taskId}/assignments`) không trả kèm submission nên field `latestSubmissionId`
  luôn null dù status đã `SUBMITTED` — sửa banner "Không tìm thấy bài nộp" xảy ra 100% các lần
- Reward settlement flow thật (sửa 2026-07-08, dòng cũ ghi sai enum): `PENDING_SETTLEMENT` (Manager chưa trả)
  → `WAITING_CONFIRMATION` (Manager mark-paid, chờ Member xác nhận) → `SETTLED` (Member confirm-received), hoặc
  → `DISPUTED` nếu Member báo chưa nhận (UC46–48)
- ✅ **Audit toàn diện + `RewardManagementScreen` mới (2026-07-08)**: verify lại 35 endpoint Task/Reward, phát
  hiện 18/36 operation có method trong `task_provider.dart` nhưng **chưa từng gọi từ UI** — trái với ghi chú cũ
  "Task system đầy đủ". Đã build:
  - `RewardManagementScreen` (`/manager/reward-management`, nút 💰 trong `task_management_screen.dart`) — 3 tab
    hoàn toàn mới phía Manager: **Thanh toán** (mark-paid/hủy settlement), **Tranh chấp** (chấp nhận/từ chối
    dispute), **Báo bận** (xử lý/hủy unavailability report). Trước đó Member đã tạo dispute/báo bận từ lâu
    nhưng Manager **không có màn hình nào** để xử lý.
  - Task detail: sửa task (`updateTask`), hủy 1 assignment, sửa/xóa reward-setting, đổi tên category (giữ lâu
    chip), sửa lịch lặp + tạo phân công hàng loạt cho task RECURRING (`_ScheduleSheet`).
  - **4 bug sai enum/DTO phát hiện khi build** (đã sửa — xem `API_DOCS.md` mục Tasks để biết chi tiết từng bug):
    `RewardSettlement.status` sai hoàn toàn (khiến nút "Tôi đã nhận thưởng" phía Member không bao giờ hiện —
    bug có từ trước, không phải do hôm nay), `markRewardPaid`/`resolveDispute`/`createAllocation` gửi sai body key.
  - Còn thiếu: `PATCH/DELETE .../tasks/proofs/{proofId}` — cần redesign luồng upload proof (hiện upload+submit
    dồn 1 lần bấm trong `child_tasks_screen.dart`, chưa có điểm để sửa/xóa proof đã upload trước khi nộp).

### ✅ Family Management
- Mời thành viên (UC15, UC16) — **Manager only**, Deputy đã verify BE trả 403. Body `CreateInvitationDto
  { email, familyRole, relationship }`
- ⚠️ **Invite flow đổi (BE 07/07): `accept` → `claim` + `approve` (2 bước)** — cần sửa FE:
  - `POST /invitations/{token}/claim` — member gửi yêu cầu join (đòi đăng nhập, **check email khớp**, 403
    nếu khác email được mời) → lời mời chuyển sang trạng thái `CLAIMED`
  - `POST /families/{familyId}/invitations/{id}/approve` — **Manager duyệt mới tạo FamilyMember**
  - `POST /families/{familyId}/invitations/{id}/reject` — Manager từ chối
  - `GET /families/{familyId}/invitations?status=CLAIMED` — Manager xem yêu cầu chờ duyệt
  - 🔧 **Việc FE cần làm**: `JoinFamilyScreen` đang gọi `/accept` (đã bị bỏ → 404), phải đổi sang `/claim`
    + thêm màn "chờ Manager duyệt"; thêm UI Manager duyệt join request. Xem `BE_API_REQUESTS.md`.
  - Token vẫn lưu `AuthProvider.pendingInviteToken` qua `flutter_secure_storage` (sống sót cold-start),
    tự điều hướng lại `/join?token=...` sau khi login/register
  - ⚠️ Link mời vẫn là `https://.../join?token=<UUID>` — chưa wire Android Intent Filter / iOS Universal
    Link nên OS chưa tự mở app; mã mời 6 ký tự trong design vẫn chưa có endpoint BE (chỉ UUID token)
- Danh sách thành viên (UC20) — Manager/Deputy xem đầy đủ + hành động quản lý; Member read-only qua
  route dùng chung `/manager/members`
- Cấp/thu quyền Phó nhóm (UC18) — **Manager only**, **vẫn chờ BE endpoint user-facing**
  `PATCH /families/{familyId}/members/{userId}/role` (verify Swagger 07/07: chưa có, chỉ admin endpoint).
  FE chỉ hiện action khi `canManageMemberRoles`
- Xoá thành viên (UC19) — **Manager only** (`canRemoveMembers`)
- ✅ **Đổi tên gia đình (2026-07-08)**: `PATCH /families/{id}`, nút ✏️ cạnh tên gia đình trong
  `member_list_screen.dart` (Manager only)
- ✅ **Từ chối lời mời (2026-07-08)**: `POST /invitations/{token}/reject` (người ĐƯỢC MỜI tự chối, khác Manager
  reject yêu cầu CLAIMED) — nút "Từ chối lời mời này" trong `join_family_screen.dart` sau khi xem preview,
  cần đăng nhập

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
  - ✅ Chi tiết 1 alert (2026-07-08): icon ℹ️ trên alert card → `_SosAlertDetailSheet` (`GET .../alerts/{id}`)
  - ✅ Gửi vị trí liên tục khi SOS active (2026-07-07): `SOSScreen._startLocationStreaming()` gọi
    `POST .../locations` mỗi 20s từ lúc gửi SOS thành công tới khi confirm-safety/rời màn hình
  - ⚠️ Vẫn chưa làm: xem chi tiết 1 alert kèm lịch sử vị trí (`GET .../alerts/{id}`), nhận cảnh báo
    realtime phía Manager/Deputy (hiện chỉ fetch 1 lần lúc vào màn hình, chưa poll)

### ✅ Notifications (in-app — API thật, BE 07/07)
- `GET .../notifications?unreadOnly=`, `PATCH .../notifications/read-all`,
  `PATCH .../notifications/{id}/read`
- 🔧 Việc FE cần làm: đổi `notification_provider.dart` từ mock sang 3 endpoint này
- ⚠️ **FCM push chưa làm được** — chưa có `POST /auth/fcm-token` và chưa có Firebase trong pubspec

### ✅ Calendar
- 5 loại sự kiện màu sắc riêng: Task / Sự kiện / Du lịch / Sinh nhật / Sức khỏe (UC70, UC71)
  ⚠️ **data vẫn mock** — BE chưa có endpoint `/events` (xem "Chờ Backend")

### ✅ Subscription
- Xem / chọn gói (UC76, UC77). `planCode` chuẩn từ BE: **`FREE / PLUS / PREMIUM`** (annual-only, có
  `stripePriceId`). ⚠️ FE đang hardcode `FREE/FAMILY/PREMIUM` → gửi checkout sẽ 400, **cần sửa**.
- ⚠️ **Checkout thật đã có (BE 07/07)**: `GET /families/{familyId}/subscription` +
  `POST /families/{familyId}/subscription/checkout { planCode }` (Stripe).
  🔧 Việc FE cần làm: nối nút "Nâng cấp" vào checkout.
  `[VERIFY]` response schema (`checkoutUrl`/`url`/`sessionId`?) và luồng chọn FREE (downgrade?) — hỏi Nghĩa.

### ⚠️ Chờ Backend (verify Swagger 07/07)
- GPS / Location sharing — **BE vẫn chưa có endpoint location độc lập** (chỉ có location trong ngữ cảnh 1
  SOS alert). `GpsProvider`/`FamilyMapScreen` chưa hoạt động
- Profile PATCH (`/auth/me`) — vẫn chỉ có `GET`, chưa có `PATCH`
- Role Management user-facing (`PATCH .../members/{userId}/role`) — **UC18 vẫn blocked**
- FCM token (`POST /auth/fcm-token`) — chưa có → push chưa làm được
- Chat messages / WebSocket — chưa có endpoint
- Calendar events (`/events`), Album (`/albums`), AI chat (`/ai/chat`) — chưa có
- Ledger filter theo `memberId` — chưa có (ledger trả toàn gia đình)

> ✅ Đã resolved so với bản 06: Subscription checkout, Notifications (in-app), Invite claim/approve.

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
