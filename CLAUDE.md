# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Ứng dụng Flutter **Family Care** (SU26SE032) — quản lý gia đình: tài chính, nhiệm vụ, lịch, SOS,
album, chat. Toàn bộ tài liệu, comment và commit message trong repo viết bằng **tiếng Việt** —
giữ nguyên quy ước này khi thêm code/doc mới.

## Quy tắc làm việc bắt buộc

1. **`API_DOCS.md` là nguồn sự thật về API.** Trước khi gọi bất kỳ endpoint nào phải đọc file này
   (BE dùng prefix `/api/v1` + nested theo `familyId`; sai path là silent fail). Phát hiện endpoint
   mới / đổi schema / mismatch FE-BE → cập nhật `API_DOCS.md` ngay trong cùng thay đổi.
   `family-care-api.json` ở root là bản dump Swagger để đối chiếu.
2. **Không mock / workaround khi BE thiếu.** Nếu FE cần thứ BE chưa có → dừng lại, viết đề xuất BE
   (method, path, request/response, mức độ **Bắt buộc** vs **Nên có**) để user gửi team Backend. Repo
   đã có sẵn nhiều file mẫu `DE_XUAT_*.md` / `BAO_CAO_BE_*.md`.
3. **Preview trước khi sửa.** Mô tả file sẽ đổi + lý do, logic cũ → mới, rủi ro/side-effect; chỉ sửa
   sau khi user xác nhận. Áp dụng cho mọi thay đổi, kể cả "fix nhanh".
4. **Field không có schema trong Swagger thì đánh dấu `[VERIFY]`, không đoán tên field.** Pattern
   hiện có: render response chưa rõ schema bằng `JsonReportView` (key-value đệ quy) thay vì map sai.

## Lệnh thường dùng

```bash
flutter pub get
flutter analyze --no-fatal-infos      # đúng lệnh CI dùng; phải 0 error
flutter test                          # toàn bộ suite
flutter test test/sos_provider_test.dart              # 1 file
flutter test test/sos_provider_test.dart --plain-name "tên test"   # 1 test
dart format lib test                  # repo chưa format hết; CI chỉ báo, không fail
flutter run                           # mặc định API prod
flutter run --dart-define=API_BASE_URL=https://your-server/api/v1
flutter build apk --release
dart run flutter_launcher_icons        # sinh lại launcher icon sau khi đổi assets
```

CI (`.github/workflows/mobile-ci.yml`) chạy trên mọi push/PR với Flutter **3.44.0** stable + Java 21:
`pub get` → `dart format` (non-blocking) → `flutter analyze --no-fatal-infos` → `flutter test` →
build debug APK. `android-release.yml` build APK ký (chạy bằng tag `v*` hoặc workflow_dispatch),
xem `docs/RELEASE_ANDROID.md`.

## Kiến trúc

**Provider + go_router + một HTTP client singleton.** Không có repository/DI layer: `Provider`
(ChangeNotifier) gọi thẳng `ApiClient.instance` và tự parse JSON thành model khai báo trong chính
file provider đó (vd `FinanceJar`, `FinanceModel` nằm trong `finance_provider.dart`). Chỉ các model
dùng chéo nhiều nơi mới nằm ở `lib/models/`.

### `lib/services/api_client.dart` — mọi request đi qua đây

- Singleton `ApiClient.instance`, base URL từ `String.fromEnvironment('API_BASE_URL')`, timeout 15s.
- Tự **unwrap envelope** `{ success, data }` → trả thẳng `data`. Provider không tự bóc lớp này.
- **Auto-refresh 401** có lock (`_lockedRefresh`) chống race khi nhiều request 401 cùng lúc; thất bại
  → `onSessionExpired`.
- Lỗi ném `ApiException(statusCode, message, code, retryAfterSeconds, cooldownSeconds)`;
  `toString()` trả đúng message BE (thường là tiếng Việt) nên UI hiển thị được trực tiếp.
- 403 có dấu hiệu "chưa xác thực" (bắt cả tiếng Việt lẫn tiếng Anh) → gọi `onVerificationRequired`.
- Helper quan trọng: `familyPath('/finance/...')` ghép `/families/{familyId}/...`;
  `absoluteUrl()` cho path tương đối BE trả về; `utcIsoMs()` vs `localIsoMs()` — **không đổi
  semantic localIsoMs** nếu BE chưa xác nhận migrate sang UTC thật.
- Upload multipart phải truyền `contentType` đúng (đã verify live: `application/octet-stream` bị BE
  400). `uploadFiles()` gửi mảng binary trong 1 request (Face Profile cần 3–5 ảnh cùng lúc).

### Điều hướng: 3 shell × 9 branch (`lib/navigation/app_router.dart`)

- 3 role `UserRole.manager | deputy | member` → 3 `StatefulShellRoute.indexedStack` riêng với
  namespace `/manager/*`, `/deputy/*`, `/member/*`.
- **Mỗi role phải khai đủ 9 branch theo thứ tự cố định**: `0 home │ 1 chat │ 2 calendar │ 3 map │
  4 tasks │ 5 wallet │ 6 album │ 7 sos │ 8 profile`. Thứ tự này phải khớp `kShellBranchOrder` +
  `kSosBranchIndex`/`kProfileBranchIndex` trong `lib/models/tab_option.dart` — **đổi bên nào phải
  đổi bên kia**. Thanh nav chỉ hiện 6 ô nhưng branch không đổi được lúc runtime, nên phải khai đủ.
- Thanh nav: vị trí 0/3/5 cứng (Trang chủ / SOS / Tôi), vị trí 1/2/4 do người dùng chọn qua
  `TabConfigProvider` (lưu cục bộ theo `TabOption.id`, không dùng index).
- `computeRedirect()` là **hàm thuần, tách khỏi BuildContext để unit test được**
  (`test/app_router_redirect_test.dart`). Thứ tự gate: restoring → login → pending invite token →
  pending email verification → chưa có family → cô lập shell theo role.
- Cô lập role dựa trên 3 tập path sinh tự động (`_shellPathsOf`) + `_managerOnlyPaths` +
  `_memberSharedPaths`. Route quản lý dùng chung (`/manager/members`, `/manager/finance-model`…)
  **cố ý không nằm trong các tập đó** nên Deputy vẫn vào được. Route mới thêm vào branch sẽ tự động
  được chặn đúng; route phẳng mới thì phải tự cân nhắc.
- Deep link cold-start bị nuốt → router lưu `pendingDeepLink` khi `auth.restoring`, phát lại sau
  splash (dùng cho `familycare://app/payment-success|failed`, `/join?token=`).
- `/manager/wallet`, `/manager/tasks` là **branch của shell** → nơi gọi phải `context.go()`, dùng
  `push()` sẽ dựng shell thứ hai trùng `GlobalKey`.

### Phân quyền

Hai trục độc lập, không được lẫn:

- `familyRole` (`FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER`) → `UserRole` → capability getters
  trong `lib/models/user.dart`.
- `userType` (`NORMAL_USER | SYSTEM_ADMIN`) → chỉ là loại tài khoản hệ thống, **không suy ra quyền
  trong gia đình**.

`isAdministrative` (Manager||Deputy) chỉ dùng cho nhóm quyền chung (`canManageTasks`,
`canManageFinance`, `canResolveSos`…). Các hành động nhạy cảm phải dùng capability riêng
(`canManageMemberRoles`, `canRemoveMembers`, `canManageSubscription`, `canInviteMembers` — tất cả
Manager-only, đã verify BE trả 403 cho Deputy). **Không quay lại gate bằng `isAdministrative`** —
đó chính là lỗ hổng đã từng xảy ra. Màn hình tự gate nút bấm theo capability; router chỉ chặn path.

Gating theo gói subscription: `lib/models/feature_access.dart` đọc `featureAccess` từ
`GET /families/{id}/subscription`. Map rỗng ⇒ `isUnknown` ⇒ nơi gọi phải **fail-open** và để BE trả
403 quyết định (fail-closed sẽ chặn nhầm cả tính năng gói Free).

### Realtime & notification (3 kênh)

- `NotificationSocketService` — Socket.IO namespace `/notifications`, handshake `auth: { token }`,
  server tự join room; tự quản reconnect/backoff để mỗi lần thử lại đọc token mới nhất từ
  `ApiClient` (JWT sống 15 phút). Chỉ foreground.
- `PushService` — FCM, kênh **duy nhất** khi app ở nền/đã tắt; đăng ký `POST /devices/tokens` sau
  login, `unregister` khi logout. Background handler phải là top-level + `@pragma('vm:entry-point')`.
- `LocalNotificationService` — hiển thị local khi tiến trình còn sống.
- REST polling vẫn dùng cho chat (`ChatProvider.startPolling`) — không phải WebSocket.

### Wear OS

`lib/wear/` dùng **chung provider tree** với app điện thoại; `main.dart` phát hiện màn hình đồng hồ
bằng heuristic kích thước (`_isWearDisplay`: shortestSide ≤ 300, aspect 0.75–1.35) rồi thay toàn bộ
cây bằng `WearNavigatorRoot`. Chưa có flavor/entry point riêng — `main_wear.dart` tồn tại nhưng
build chính vẫn qua `main.dart`.

### Theme

`lib/theme/`: `AppTheme.light/dark` (Material 3, seed color, Inter qua google_fonts),
`AppColors`, `AppSurfaceColors`, `AppUiTokens`. Màn hình mới dùng widget mặc định là đã đúng style —
không hardcode màu. Tham chiếu design system: `COLOR_TOKENS.md`, `TYPOGRAPHY_SPACING.md`,
`COMPONENT_PATTERNS.md`, `familycare_design_philosophy.md`.

## Test

`test/` gồm unit test cho logic thuần (`computeRedirect`, capability matrix, parser/mapping của
provider: `fund_allocation_mapping_test`, `task_reward_mapping_test`, `album_face_mapping_test`…) và
vài widget test. Không có test tích hợp gọi BE thật. Khi sửa mapping JSON của provider, thêm/ sửa
test mapping tương ứng — đây là chỗ bắt các bug enum/DTO sai đã từng xảy ra nhiều lần.

## Tài liệu trong repo

- `AI_HANDOFF_LATEST.md` — **đọc snapshot trên cùng trước khi bắt đầu**: trạng thái nhánh, việc đang
  dở, `[VERIFY]` còn treo. Các snapshot phía dưới là lịch sử, có thể đã lỗi thời.
- `API_DOCS.md` — contract API + ghi chú bug/quirk đã verify live (xem Rule 1).
- `README.md` — tổng quan flow đã implement; một số mục đã cũ so với source (vd phần "Chờ Backend",
  trạng thái Firebase/iOS) — khi mâu thuẫn thì tin source + `AI_HANDOFF_LATEST.md`.
- `docs/RELEASE_ANDROID.md` — quy trình build/ký/phát hành APK.

## Git

- Nhánh chính `main`, nhánh làm việc theo tên người (`giap`, `NDuy`).
- Commit convention: `feat:` / `fix:` / `refactor:` / `chore:`, mô tả tiếng Việt.
- `.gitattributes` ép LF trong repo (trừ `.bat`/`.ps1`) — nếu thấy cả file "modified" mà không sửa gì
  thì là nhiễu CRLF, không phải thay đổi thật.
- Commit message chỉ mô tả **thay đổi kỹ thuật thật**: API/CRUD đã nối, bug đã sửa, cách verify.
  Không đưa quy ước làm việc nội bộ vào message.
- `flutter analyze --no-fatal-infos` (0 error) + `flutter test` (toàn bộ pass) trước mỗi commit.
- Merge `NDuy` → `main` chỉ khi fast-forward sạch; `git fetch origin` và đối chiếu `origin/giap`
  trước khi push để không đè commit của người khác.
- Dọn `git status --short` trước khi `git add`: loại file tạm lúc test (`tmp_*.png`, `tmp_*.xml`,
  `.tmp_report_audit/`) khỏi commit code.
