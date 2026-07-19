# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-07-18**

## Snapshot hiện tại — đọc phần này trước

### Phạm vi hệ thống

- Mobile Flutter: `D:\Desktop\mobile-sep` — Family Manager, Deputy Member,
  Family Member và Wear OS.
- Admin Web: `D:\Desktop\sep` — `SYSTEM_ADMIN`, là Git repository độc lập.
- Hai frontend dùng chung backend và Swagger:
  `https://api.familycare-digital.com/api/docs`.
- OpenAPI JSON: `https://api.familycare-digital.com/api/docs-json`.
- API base Mobile: `https://api.familycare-digital.com/api/v1`.
- Swagger là nguồn chính cho endpoint/DTO/enum; SRS và Use Case Tracker là
  nguồn nghiệp vụ. Nếu khác nhau phải xác minh với BE, không fake API.
- `FinalReport_Template (1).docx` chứa nội dung TailorStore mẫu, không phải
  nghiệp vụ FamilyCare.

### Git và CI/CD Android

- Nhánh làm việc: `NDuy`.
- Commit thêm CI/release: `9c90557`.
- Commit sửa analyzer: `be9a470`.
- Pull Request `NDuy -> main` đã chạy cả push check và pull-request check xanh.
- Workflow Android Release đã chạy thành công trên `main`, head commit
  `1e7b12a`.
- Mobile CI tự chạy khi `push` hoặc `pull_request`:
  - `flutter analyze --no-fatal-infos`
  - `flutter test`
  - build APK debug
  - upload debug artifact
- Android Release chỉ chạy thủ công hoặc khi push tag `v*`; không tự phát hành
  sau mỗi commit thông thường.
- PR còn mang theo bốn sửa chức năng có chủ đích:
  - `lib/providers/family_provider.dart`
  - `lib/providers/task_provider.dart`
  - `lib/screens/parent/reward_management_screen.dart`
  - `lib/screens/parent/task_management_screen.dart`

### Release Android đã hoàn thành

- Release keystore được tạo bên ngoài repository:
  `D:\FamilyCare-Secrets\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình:
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- Không bao giờ ghi giá trị secrets, mật khẩu hoặc Base64 vào source/handoff.
- Signed APK build thành công:
  `FamilyCare-1.0.0-1.apk`.
- Artifact: `familycare-android-1.0.0`, kèm file `.sha256`.
- Run Android Release thành công: `29637020372`.
- APK chỉ cài được trên Android. iOS cần IPA + Apple signing + TestFlight,
  hoặc dùng Web/PWA làm phương án thay thế.
- Phải giữ và backup đúng keystore trên cho mọi release sau; đổi/mất keystore
  có thể khiến APK mới không cập nhật đè lên bản đã cài.

### Verification gần nhất

- Mobile CI push: pass.
- Mobile CI pull request: pass.
- Android signed release workflow: pass.
- `flutter test`: **55/55 pass**.
- Analyze: không có error/warning; còn 11 lint mức `info`.
- APK debug build: pass.
- APK signed release build: pass.
- Chưa xác nhận runtime signed APK trên thiết bị Android sau khi tải về.

### Việc còn lại, theo thứ tự

1. Cài `FamilyCare-1.0.0-1.apk` trên Android và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile. Nếu đang cài debug APK có chữ
   ký khác, phải gỡ bản debug trước (sẽ mất dữ liệu local).
2. Backup keystore ở ít nhất hai nơi an toàn và lưu mật khẩu trong password
   manager.
3. Cấu hình Google Drive + QR:
   - tạo Google Cloud service account;
   - bật Google Drive API;
   - share folder đích cho service-account email;
   - thêm `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`;
   - tùy chọn variable `GDRIVE_UPLOAD_ON_TAG=true`;
   - chạy Android Release với Drive upload bật.
4. Mở workspace Admin `D:\Desktop\sep` và thêm CI/CD riêng cho Next.js/Docker.
   Admin repo đã có `apps/web/Dockerfile`, `apps/api/Dockerfile`,
   `docker-compose.yml`, `docker-compose.prod.yml` nhưng chưa có GitHub Actions.
5. Gửi `docs/BE_ADMIN_SECURITY_CHECKLIST.md` cho BE. Bảo mật nhiều Admin phải
   được enforce ở backend; FE route guard không phải security boundary.
6. Chốt phương án iOS: TestFlight nếu có Apple Developer + macOS/Xcode;
   nếu chưa có thì dùng Web/PWA cho thiết bị iPhone.

### Trạng thái local và quy tắc bàn giao

- Tài khoản/window Codex này chỉ sửa code; commit/push thực hiện ở window Git
  khác và phải báo danh sách file trước khi stage.
- Lần kiểm tra gần nhất local chỉ còn untracked `.claude/` và
  `.vscode/settings.json`; không commit nếu nhóm chưa chủ đích dùng chung.
- Sau khi main đã merge, window Git nên đồng bộ bằng:
  `git fetch origin`, `git switch main`, `git pull origin main`.
- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, Google
  credentials hoặc bất kỳ secret nào.
- File hướng dẫn release: `docs/RELEASE_ANDROID.md`.
- Checklist BE nhiều Admin: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

> Phần từ “Cập nhật 2026-07-16” trở xuống là snapshot lịch sử chi tiết. Một số
> thông tin nhánh/commit trong phần lịch sử đã lỗi thời; dùng snapshot
> 2026-07-18 ở trên làm trạng thái hiện hành.

> ⚠️ IP cũ `103.110.84.66` đã BỎ hẳn — mọi tài liệu nhắc IP này đều lỗi thời.

---

## 🆕 Cập nhật 2026-07-16 (phiên hiện tại)

Sau khi FF `giap` lên `origin/main` (`93612a9`), đã tái hoà WIP + thêm cải tiến — **9 commit local, chưa push**:

- **Invite chuyển hẳn sang MÃ MỜI 8 KÝ TỰ** (main `3c5f9cb` bỏ luồng `/invitations/{token}` cũ). FE thêm **QR thật + scanner** (`qr_flutter`, `mobile_scanner`): màn Mời hiện mã + QR encode `familycare://app/join?code=`; màn Tham gia có nút "Quét mã QR" → tự điền mã → `previewInviteCode` → `requestJoinByCode`. Quyền camera đã thêm AndroidManifest.
- **Thông báo real-time (tạm, không cần BE)**: `FamilyShell` poll toàn cục **15s** (`fetchAlerts` + `fetchNotifications`), dừng khi app nền, fetch lại khi resume. **Badge số** chưa đọc trên chuông 2 home. (BE chưa có FCM/WebSocket.)
- **SOS Response Timeline**: màn chi tiết cảnh báo (icon ℹ️) dựng timeline phản hồi từ `fetchAlertDetail().responses` — header đỏ, vị trí + mini-map, node 🚨→👀/🚗/🆘/✅→✔/✖. Parse phòng thủ (schema `responses[]` chưa document).
- **Home "Trạng thái gia đình"**: `widgets/family_status_card.dart` từ `activeAlerts` (an toàn / ai đang SOS). Bản rút gọn — chưa gắn vị trí (chờ BE location).
- **Family Map**: parse vị trí phòng thủ; **fix code chết `_pins`** trong `_locateMe`; **che raw "Cannot GET /location/family"** bằng note "🚧 đang phát triển" (cờ `sharingUnavailable`); khôi phục ±accuracy pin Tôi.
- **Task**: lọc `isActive` ở picker giao việc & reassign (tránh gán nhầm member REMOVED).
- **BE đã fix (team xác nhận 07/16)**: góp mục tiêu bỏ `ledgerEntryId`, gán task theo `FamilyMember.id` + bỏ chặn role, proof URL tự sinh lại. FE vốn đã tương thích → không phải sửa thêm (trừ lọc isActive).
- **Báo cáo BE mới**: `BAO_CAO_BE_SOS_2026-07-16.md` — 3 EP location sharing (`GET /location/family`, `POST /location/update`, `PATCH /location/toggle`) + 3 điểm SOS-detail (schema `responses[]`, enum `ON_THE_WAY`, phone thành viên).
- **Model/Build**: `userType` (SYSTEM_ADMIN) tách khỏi `familyRole` (main `fc59c69`); `planCode` đổi **FREE|MONTHLY|YEARLY**; hạ AGP 9.0.1→8.11.1 + giảm gradle heap. Verify: **55/55 test pass**, analyze 0 error.

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

### Family & Invitation — **MÃ MỜI 8 KÝ TỰ (main `3c5f9cb`, thay luồng token cũ)**
GET/PATCH `/families/{id}` (đổi tên), DELETE member (soft-delete, lọc `status==ACTIVE`). **Luồng mời mới kiểu Zalo/Discord** (`invitation_provider.dart` viết lại):
- Manager: `GET /families/{id}/invite-code` (mã hiện tại) · `POST .../invite-code/regenerate` (tạo/đổi mã, mã cũ vô hiệu ngay).
- Người xin vào: `GET /invite-codes/{code}` (preview, public) · `POST /invite-codes/{code}/join-requests` (gửi yêu cầu, chỉ cần đăng nhập, KHÔNG cần verify email) · `GET /me/join-requests` (poll trạng thái) · `POST /me/join-requests/{id}/cancel`.
- Manager duyệt: `GET /families/{id}/join-requests` · `POST .../{id}/approve` (chọn role+quan hệ) · `POST .../{id}/reject`. `InvitationRequestsScreen` (fetch 1 lần + refresh tay, chưa poll).
- Mã 8 ký tự alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (bỏ I/O/0/1). **FE thêm QR + scanner** (xem changelog 07/16). `savePendingInviteToken` giữ tên cũ nhưng giá trị nay là **mã** (không phải token).
- 🐛 Race-condition đã sửa: dialog "Đã gửi yêu cầu" refetch `refreshFamilyContext()` trước điều hướng (Manager có thể duyệt ngay lúc member còn ở dialog).
- ⚠️ **Chưa realtime** cho join-request (module notifications còn stub) → Manager phải bấm refresh; Member poll `/me/join-requests` ~12s khi mở "Yêu cầu của tôi".

### Finance (module sâu nhất — 42/42 endpoint mobile đã nối)
Overview · ledger · jars/models · categories · budget-plans (+lines +report +detail edit) · financial-goals (+detail +progress +allocations sửa/xóa) · **goal contribution plans** (suggestions/confirm/submit/approve/reject/shortage — `GoalContributionScreen`) · alerts (+detail +recompute) · monthly-finances/me · reports (planned-vs-actual, `FinanceReportsScreen`) · support-requests (+detail). Response schema chưa document → render qua `JsonReportView` generic.

### Tasks & Reward
Full CRUD task/recurring/schedule (+generate-assignments) · assignments (assign/reassign/start/cancel/detail) · submissions (+review) · proof upload · reward-setting (create/read/update/delete) · **`RewardManagementScreen`** (3 tab: Thanh toán/Tranh chấp/Báo bận). Enum reward settlement đúng BE: `PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED`. Score/XP tính từ task status thật — **không có endpoint gamification**.
- Còn thiếu UI: `PATCH/DELETE tasks/proofs/{proofId}` (luồng upload+submit gộp 1 lần, chưa có bước sửa proof).

### SOS (10 operations)
Create alert · GET list/detail · respond (`responseType`) · confirm-safety · resolve/cancel (Manager/Deputy) · **push location** + `locations/batch` (buffer offline, `pushLocationBatch` — chưa nối UI) + `location/current` (`fetchCurrentLocation`, đã gọi từ `sos_screen.dart`). Location streaming mỗi 20s khi alert active.
- ⚠️ 2 nhóm enum `sourceType` KHÁC nhau: alert = `MOBILE_APP/WEARABLE/SIMULATED_DEVICE`; location = `MOBILE_GPS/WEARABLE_GPS/SIMULATED_GPS`. Không lẫn.
- ✅ **2 fix từ main (2026-07-10, verify live BE)**: id đọc từ **`sosAlertId`** (không phải `id`) → sửa bug 404 "Tôi đang đến"; GPS treo → `timeout(10s)` + `getLastKnownPosition` + chốt cứng **15s** ở `_triggerSOS` (quá 15s vẫn gửi SOS không kèm toạ độ). `SosAlert` thêm `severity`/`resolutionNote`/`resolvedByName`.

### Chat gia đình — **[MỚI, wire thật 2026-07-11]**
BE ship 18 endpoint REST `/families/{fid}/chat/conversations/...` → FE wire xong (`chat_provider.dart` 517 dòng, `chat_screen.dart` viết lại). GROUP/PRIVATE · gửi ảnh (image_picker) · reaction · ghim · sửa/thu hồi · participants · read. `ChatProvider` đăng ký trong `main.dart`. **Transport REST polling** (`startPolling`/`stopPolling`), KHÔNG phải WebSocket.
- ✅ **Tin an toàn nhanh (2026-07-13)**: nút khiên trong input bar → sheet 4 tin mẫu, gửi `messageType: SOS_QUICK_MESSAGE` tường minh; bubble cam + nhãn "TIN AN TOÀN". Verify live BE echo đúng messageType.

### Album gia đình — **[MỚI 2026-07-13, BE ship 14 EP, swagger 223 ops]**
Giáp wire 13 EP (`album_provider.dart` + `album_screen.dart` viết lại: upload, thùng rác, tag, moderation per-media, filter). NDuy gán nốt `GET /albums/moderation` — hàng đợi kiểm duyệt toàn gia đình (nút 🛡️ AppBar, duyệt nhanh MARK_SAFE/KEEP_FLAGGED, hiển thị riskScore AI). File URL là signed URL có hạn.
- **Mọi role đều dùng được album** (verify live: member GET media 200, moderation 403 đúng thiết kế). Manager: tab shell `/manager/album`. Deputy/Member: route phẳng `/album` — entry từ trang Tôi ("Album gia đình") + shortcut 🖼️ ở Trang chủ member. Màn album tự gate nút kiểm duyệt theo `isAdministrative`.

### Xem tài chính member — **[MỚI 2026-07-13, UC gap #5 BE đã đáp ứng]**
3 EP mới: `monthly-finances/members/{memberId}` + `monthly-summary/me|members/{memberId}` (đều cần `month&year`, verify live OK). `MemberFinanceScreen` (route `/manager/member-finance?memberId&name`): chọn tháng, 3 card khai báo/quỹ gia đình/mục tiêu; field private BE trả null → hiện "🔒 Riêng tư". Entry: Member List → sheet "Xem tài chính tháng" (gate `canManageFinance` — Manager/Deputy; member route bị guard chặn, member xem của mình trong ví riêng).

### Notifications
GET list · PATCH read · read-all. Tap routing theo `referenceType`. Field id thật là `notificationId`.

### Subscription
GET current · GET `/subscription-plans` · POST `/checkout {planCode}`. `planCode` chuẩn **`FREE | MONTHLY | YEARLY`** (main `359d12b` — đổi từ FREE|PLUS|PREMIUM). Nút Nâng cấp → checkout → `url_launcher` mở Stripe.
- ✅ **UX hạ gói (2026-07-13)**: CTA đổi thành "Hạ xuống {tên}" khi gói rẻ hơn gói đang dùng (so sánh `priceValue`) + dialog xác nhận trước checkout.
- ✅ **Hết nháy FREE (main `627b2c4`)**: `_currentPlan` nullable = đang tải → hiện spinner, khoá checkout khi chưa biết gói (trước bị nháy FREE 2–3s).
- ⚠️ `[VERIFY]` response `/checkout` **vẫn trống schema** trong Swagger — FE hiện chỉ đọc `data['checkoutUrl']` (chưa fallback `url`/`sessionId`). Hỏi Nghĩa field thật + luồng chọn FREE (downgrade?).

---

## Backend Gaps — KHÔNG fake call

Swagger live vẫn **0 endpoint** cho (Chat & Album nay đã CÓ — xem các mục trên):
- **AI assistant**, **Calendar events** (`/events`), **FCM token** push (→ đang poll tạm ở `FamilyShell`)
- **Location sharing độc lập** ngoài SOS (chỉ có toạ độ trong ngữ cảnh 1 alert) → **đã có báo cáo chính thức `BAO_CAO_BE_SOS_2026-07-16.md`**; FE che raw 404 bằng note "đang phát triển".
- **PATCH /auth/me** (sửa profile), **role management user-facing** (UC18)
- **Wearable pairing / SOS device settings**
- ⚠️ **SOS alert detail** thiếu document `responses[]` + enum "đang đến" + phone thành viên (3 câu trong báo cáo trên).

25 endpoint `/admin/*` mới (audit-logs, backups, docker infra, revenue, provisioning...) thuộc **Admin Web**, ngoài phạm vi FE Mobile.

---

## `[VERIFY]` đang chờ Nghĩa

1. **[Payment]** `POST /subscription/checkout` trả field nào để redirect Stripe (`checkoutUrl`/`url`/`sessionId`)? Chọn FREE là downgrade riêng hay cũng qua `/checkout`?
2. **[Chat]** Transport hiện là REST polling — BE có kế hoạch chuyển WebSocket realtime không? Giới hạn `limit` khi load lịch sử, encode emoji trong URL reaction.

---

## Verification (2026-07-16)

`flutter test` → **55/55 pass** · `flutter analyze lib` → **0 error** (11 info-lint pre-existing/từ main). Build APK debug OK (Gradle 9.1.0 / AGP 8.11.1 / Kotlin 2.3.20).
Test phủ: router redirect (verify mandatory), auth/role capabilities (+2 test mới từ main), register error mapping, SOS provider parse/guard. **Chưa verify runtime** (cần device): SOS Timeline khi có `responses[]` thật; badge/poll thông báo; quét QR mã mời.
- ⚠️ Windows build: cần **bật Developer Mode** (symlink cho plugin); nếu build lỗi lạ (BuildConfig exists / Dart compiler exited) → `flutter clean` (kill dart/java nếu `.dart_tool` bị khoá).

---

## Nhánh & Git

`giap` đã **FF tới `origin/main` (`93612a9`)** rồi chồng **9 commit local** (invite QR-code, poll+badge, map fix, SOS timeline, Home status, task isActive, map 404, build-config, docs). **Chưa push** (origin/giap còn ở `cb050e9`). Backup: `giap-backup-before-ff-20260715` (@cb050e9), `giap-backup-before-ff-20260711`, `giap-backup-20260710`.

## Next Suggested Work

1. **Push `giap`** lên origin (9 commit) khi sẵn sàng.
2. Gửi `BAO_CAO_BE_SOS_2026-07-16.md` cho Nghĩa (location sharing + 3 điểm SOS-detail) + hỏi fix task định kỳ (`generate-assignments`) có bỏ chặn role chưa.
3. **Verify runtime trên device**: quét QR mã mời (2 máy), badge/poll thông báo, SOS Timeline với alert có phản hồi thật, block "Trạng thái gia đình".
4. Khi BE ship location: đổi path `GpsProvider` (parse đã sẵn) → mở marker nhiều thành viên + family cards có vị trí.
5. `[VERIFY]` tồn đọng: checkout field Stripe, chat WebSocket.
