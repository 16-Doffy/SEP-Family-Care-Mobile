# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-07-11**
Branch: `giap`
Latest commit: `02cb99a Merge origin/main vào giap: kéo 48 commit + verify MANDATORY`
Backend Swagger (live): `https://api.familycare-digital.com/api/docs` · docs-json 147 paths / 188 operations (verify 2026-07-11)
API base in app: `https://api.familycare-digital.com/api/v1` (default trong `api_client.dart`, override qua `--dart-define`)

> ⚠️ IP cũ `103.110.84.66` đã BỎ hẳn — mọi tài liệu nhắc IP này đều lỗi thời.

---

## Nguyên tắc làm việc (bắt buộc)

1. **Chỉ build trên endpoint ĐÃ TỒN TẠI trong Swagger live.** Field/response chưa rõ → đánh `[VERIFY]` hỏi Nghĩa, KHÔNG tự đoán.
2. **Giữ `API_DOCS.md` đồng bộ với code** mỗi khi wire endpoint mới.
3. **Không mock/fake call** cho tính năng BE chưa có endpoint — giữ placeholder UI.
4. Verify bằng **kịch bản thật** (chạy app đối chiếu BE) cho các luồng nhạy cảm, không chỉ tin unit test.

---

## Cấu trúc dự án (thực tế 2026-07-11)

```
lib/
├── main.dart · main_wear.dart (Wear OS entrypoint riêng — chưa có flavor build)
├── models/user.dart               (enum UserRole { manager, deputy, member } + capabilities)
├── navigation/
│   ├── app_router.dart            (go_router + computeRedirect thuần, unit-test được)
│   └── family_shell.dart          (bottom-nav shell dùng chung 3 role)
├── providers/                     (provider/ChangeNotifier)
│   ├── auth_provider.dart         family_provider.dart      invitation_provider.dart
│   ├── finance_provider.dart      finance_alert_provider.dart
│   ├── task_provider.dart         sos_provider.dart         notification_provider.dart
│   ├── wallet_provider.dart       money_provider.dart       support_request_provider.dart
│   └── gps_provider.dart          (location UI-only, BE chưa có endpoint độc lập)
├── screens/
│   ├── auth/   login · register · verify_email · forgot_password · family_setup · join_family
│   ├── parent/ (Manager/Deputy) home_dashboard · task_management · reward_management ·
│   │           wallet · finance_model · budget_plan(+detail) · financial_goal · goal_detail ·
│   │           goal_contribution · finance_reports · finance_alerts · support_request ·
│   │           subscription · member_list · invite_member · invitation_requests · calendar
│   ├── child/  (Member) child_home · child_tasks · child_wallet
│   └── shared/ profile · edit_profile · sos · notifications · chat* · album* · ai_assistant* ·
│               family_map* · payment_result · splash   (* = mock, BE chưa có endpoint)
├── services/api_client.dart       (singleton, Bearer + auto-refresh 401, unwrap {success,data})
├── theme/  app_colors.dart · app_theme.dart
├── utils/  validators.dart        (bộ Validators dùng chung — từ UI kit của main)
├── widgets/ app_input · money_input · empty_state · json_report_view · avatar_widget ·
│            ring_chart · waffle_chart · request_money_sheet
└── wear/   main_wear.dart + screens Wear OS (dùng chung provider)
```

---

## Trạng thái wiring — ĐÃ NỐI API THẬT

### Auth & Session
Login / register / logout / refresh / me — wired. Token qua `flutter_secure_storage`. `ApiClient` gắn `Bearer`, retry 1 lần khi 401 (refresh token), unwrap envelope `{ success, message, data }`.
- ✅ **Verify email OTP (BẮT BUỘC / mandatory)**: `POST /auth/verify-email {code}` + `/auth/resend-verification`. Router ép sang `/verify-email` khi `pendingEmailVerification && !hasFamily`. `POST /families` trả **403** nếu chưa verify — message thật là **tiếng Việt** ("Vui lòng xác thực tài khoản...") nên `createFamily` tin thẳng `statusCode==403` (KHÔNG check `contains('verif')` — bug đã sửa).
- ✅ **Quên mật khẩu** (2026-07-11, endpoint mới): `POST /auth/forgot-password {email}` → BE gửi OTP → `POST /auth/reset-password {email, code, newPassword}`. Màn `forgot_password_screen.dart`, link "Quên mật khẩu?" ở login.

### Role & Route
`familyRole` từ `/auth/me`: `FAMILY_MANAGER`→manager, `DEPUTY_MEMBER`→deputy, `FAMILY_MEMBER`→member. Capabilities trong `AppUser` — **hành động nhạy cảm KHÔNG dùng `isAdministrative` chung** mà tách riêng (`canInviteMembers`/`canRemoveMembers`/`canManageSubscription` chỉ Manager, đã verify BE trả 403 cho Deputy). Router guard chặn cross-shell.

### Family & Invitation (flow claim → approve)
GET/PATCH `/families/{id}` (đổi tên gia đình), DELETE member (soft-delete, lọc `status==ACTIVE`), POST invite, GET `/invitations/{token}` lookup, POST `/claim`, `/reject` (invitee tự chối), approve/reject (Manager). `InvitationRequestsScreen` cho Manager duyệt.
- 🐛 Race-condition đã sửa: dialog "Đã gửi yêu cầu" refetch `refreshFamilyContext()` trước khi điều hướng (Manager có thể duyệt ngay lúc member còn ở dialog).

### Finance (module sâu nhất — 42/42 endpoint mobile đã nối)
Overview · ledger · jars/models · categories · budget-plans (+lines +report +detail edit) · financial-goals (+detail +progress +allocations sửa/xóa) · **goal contribution plans** (suggestions/confirm/submit/approve/reject/shortage — `GoalContributionScreen`) · alerts (+detail +recompute) · monthly-finances/me · reports (planned-vs-actual, `FinanceReportsScreen`) · support-requests (+detail). Response schema chưa document → render qua `JsonReportView` generic.

### Tasks & Reward
Full CRUD task/recurring/schedule (+generate-assignments) · assignments (assign/reassign/start/cancel/detail) · submissions (+review) · proof upload · reward-setting (create/read/update/delete) · **`RewardManagementScreen`** (3 tab: Thanh toán/Tranh chấp/Báo bận). Enum reward settlement đúng BE: `PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED`. Score/XP tính từ task status thật — **không có endpoint gamification**.
- Còn thiếu UI: `PATCH/DELETE tasks/proofs/{proofId}` (luồng upload+submit gộp 1 lần, chưa có bước sửa proof).

### SOS (10 operations)
Create alert · GET list/detail · respond (`responseType`) · confirm-safety · resolve/cancel (Manager/Deputy) · **push location** + 🆕 **`locations/batch`** (buffer offline, có method `pushLocationBatch` — chưa nối UI) + 🆕 **`location/current`** (`fetchCurrentLocation`, đã gọi từ `sos_screen.dart`). Location streaming mỗi 20s khi alert active.
- ⚠️ 2 nhóm enum `sourceType` KHÁC nhau: alert = `MOBILE_APP/WEARABLE/SIMULATED_DEVICE`; location = `MOBILE_GPS/WEARABLE_GPS/SIMULATED_GPS`. Không lẫn.

### Notifications
GET list · PATCH read · read-all. Tap routing theo `referenceType`. Field id thật là `notificationId`.

### Subscription
GET current · GET `/subscription-plans` · POST `/checkout {planCode}`. `planCode` chuẩn **`FREE | PLUS | PREMIUM`** (annual-only, bỏ hardcode `FAMILY`). Nút Nâng cấp → checkout → `url_launcher` mở Stripe.
- ⚠️ `[VERIFY]` response `/checkout` **vẫn trống schema** trong Swagger — FE hiện chỉ đọc `data['checkoutUrl']` (chưa fallback `url`/`sessionId`). Hỏi Nghĩa field thật + luồng chọn FREE (downgrade?).

---

## Backend Gaps — KHÔNG fake call

Swagger live (147 paths) vẫn **0 endpoint** cho:
- **Chat** (0 path message/chat/ws — Nghĩa báo "xong" nhưng có thể ở WS gateway ngoài Swagger, cần `[VERIFY]` URL wss + event format + REST load lịch sử)
- **Album / photo**, **AI assistant**, **Calendar events** (`/events`), **FCM token** push
- **Location sharing độc lập** ngoài SOS (chỉ có toạ độ trong ngữ cảnh 1 alert)
- **PATCH /auth/me** (sửa profile), **role management user-facing** (UC18)
- **Wearable pairing / SOS device settings**

25 endpoint `/admin/*` mới (audit-logs, backups, docker infra, revenue, provisioning...) thuộc **Admin Web**, ngoài phạm vi FE Mobile.

---

## `[VERIFY]` đang chờ Nghĩa

1. **[Payment]** `POST /subscription/checkout` trả field nào để redirect Stripe (`checkoutUrl`/`url`/`sessionId`)? Chọn FREE là downgrade riêng hay cũng qua `/checkout`?
2. **[Chat]** URL `wss://...`, event format, REST path load lịch sử tin nhắn (Swagger REST hiện 0 path chat).

---

## Verification (2026-07-11)

`flutter test` → **51/51 pass** · `flutter analyze lib test` → **0 error, 0 warning** (7 info-lint pre-existing).
Test phủ: router redirect (verify mandatory), auth/role capabilities, register error mapping, SOS provider parse/guard. **Chưa có** integration test cho các luồng API mới (subscription/SOS-new/forgot-password) — cần chạy app thật đối chiếu BE.

---

## Nhánh & Git

`giap` = `origin/main` (48 commit) + 2 commit riêng (`2d747da` verify-optional gốc, `02cb99a` merge chọn mandatory + giữ 2 fix). **Chưa push.** Backup: `giap-backup-20260710`. Khi PR `giap → main`: nêu 2 fix (403-message + race-condition) vì main đang thiếu.

## Next Suggested Work

1. `[VERIFY]` 2 câu với Nghĩa (checkout field, chat WS).
2. Harden checkout: `data['checkoutUrl'] ?? data['url'] ?? data['sessionId']`.
3. Nối `pushLocationBatch` vào luồng buffer offline (provider sẵn, thiếu UI trigger).
4. Test thủ công trên device: verify-email, create family, claim/approve, checkout, SOS, forgot-password.
