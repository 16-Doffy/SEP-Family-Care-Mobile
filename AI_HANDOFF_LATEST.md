# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-07-22**

## 🚀 Snapshot mới nhất 2026-07-22 (Finance, Member UI Redesign & Multi-Admin Sync)

### 📌 Trạng thái Git / Branch Sync
- **Nhánh local:** `NDuy` và `main` đã được merge Fast-forward đồng bộ 100% tại commit `936006a`.
- **Remote:** Cả `origin/NDuy` và `origin/main` đều đã được push và đang ở commit `936006a`.
- **Kiểm thử:** **81/81 unit test PASS 100%**, `flutter analyze` clean (**0 error**).

### 🛠️ Chi tiết Fixes & Cập nhật Finance (Mobile)
1. **Lỗi Tạo Danh Mục (Category Creation 502 Error):**
   - Đã bổ sung `essentialType` mặc định (`ESSENTIAL`) cho danh mục Khoản Chi và giao diện form chọn loại thiết yếu -> Loại bỏ hoàn toàn lỗi Server 502 Bad Gateway.
2. **Lỗi `entryDate không đúng định dạng` & Chọn danh mục Thu/Chi:**
   - Chuẩn hóa định dạng `entryDate` sang chuỗi ISO UTC `YYYY-MM-DDTHH:mm:ssZ` (bỏ 6 chữ số thập phân microsecond).
   - Cập nhật popup Thu/Chi dùng `watch<FinanceProvider>()` -> Mới tạo danh mục xong là dropdown tự động cập nhật ngay.
3. **Phân bổ vào Mục tiêu (Goal Allocation):**
   - Bổ sung bộ lọc bắt lỗi khi sửa số tiền phân bổ mục tiêu: hiển thị thông báo tiếng Việt rõ ràng thay vì câu văng lỗi kỹ thuật.
4. **Phân quyền & Redesign UI Trang chủ / Sổ chi tiêu Member:**
   - **Phân quyền:** Member KHÔNG có quyền xem tổng quỹ gia đình (BE trả 403, chỉ Manager/Deputy được xem).
   - **Trang chủ Member (`child_home_screen.dart`):** Đã sửa ô lối tắt 💰 hiển thị tổng quỹ chung `51,171,111 đ` thành nhãn tính năng **"Tài chính"** (đồng bộ với AI, Album, Lịch).
   - **Sổ chi tiêu Member (`child_wallet_screen.dart`):** Loại bỏ thẻ mock `Số dư hiện tại: — đ (chưa có API)` -> Thay bằng thẻ **"Còn lại có thể tiêu"** (tính từ Hạn mức cá nhân - Đã chi tiêu) vô cùng minh bạch và chuyên nghiệp.
5. **Yêu cầu hỗ trợ (Support Requests):**
   - Sửa `_statusChip` hiển thị chính xác trạng thái `CANCELED` / `CANCELLED` thành nhãn màu xám **"Đã hủy"** trên cả màn danh sách chi tiết lẫn thẻ preview ngoài màn chính.
6. **Khai báo Tài chính theo tháng (Monthly Finance):**
   - Tự động fallback giữa `POST` và `PUT` khi đã tồn tại bản ghi khai báo tháng trước đó.

### 🌐 Trạng thái Web Admin Multi-Admin Rules (`d:\Desktop\sep`)
- Gỡ bỏ hoàn toàn Modal "Đổi vai trò" (Edit Role) và không truyền `userType` trong PATCH `/admin/users/:id` (được BE kiểm soát qua script/seed).
- Tự động `disabled` nút Khóa/Mở khóa đối với chính Admin đang đăng nhập (`u.id === user?.id`) và các tài khoản `SYSTEM_ADMIN` khác (`u.userType === 'SYSTEM_ADMIN'`).

---

## Snapshot hiện tại 2026-07-22 — Finance + Face Profile QA (đọc phần này trước)

### Git / commit handoff

- Nhánh làm việc: `NDuy`.
- Working tree **chưa commit**. `git diff --check` đã pass.
- Nhóm thay đổi chức năng cần commit cùng nhau là 25 file tracked trong
  `API_DOCS.md`, `lib/` (Finance, Face Profile, Album, notification) và các
  file untracked sau:
  - `lib/providers/face_profile_provider.dart`;
  - `lib/screens/shared/face_suggestions_sheet.dart`;
  - `test/face_profile_provider_test.dart`.
- `BAO_CAO_BE_FACE_ROLE_FEATURE_2026-07-21.md` là báo cáo gửi BE, chỉ add nếu
  nhóm muốn version-control tài liệu này.
- Không add/commit `.claude/settings*.json` hoặc `.vscode/settings.json` nếu
  chưa thống nhất cấu hình dùng chung.
- Chưa chạy được full `dart format`/`flutter analyze` trong phiên này vì tiến
  trình Flutter/Android Studio đang giữ tool lâu quá timeout; đã kiểm tra diff
  tĩnh và `git diff --check`. Cần chạy CI hoặc `flutter analyze` + `flutter
  test` sau khi commit.

### Những thay đổi FE đã làm

#### Face Profile / Album

- Thêm `FaceProfileProvider`, UI thiết lập Face Profile tại member detail,
  upload từng ảnh, trạng thái enroll/enable/disable/delete và UI xem/xử lý AI
  face suggestions trong Album.
- Feature gate Face Profile/face suggestion theo subscription feature access;
  tài liệu endpoint được bổ sung vào `API_DOCS.md`.
- Đã test enroll với ảnh thật: FE gửi request đúng nhưng BE trả
  `Face image is not enrollable`. Đây là response/validation BE, không phải
  crash FE. Cần BE cung cấp tiêu chí ảnh hoặc mẫu ảnh được chấp nhận.

#### Finance — Budget, goal, alert, report

- Chuẩn hóa input tiền dùng dấu chấm (`100000` -> `100.000`) và parse an toàn
  tại các form Budget, Goal contribution, Monthly Finance và Ledger.
- Budget Plan: tạo DRAFT có dòng ngân sách đầu tiên; tạo category inline khi
  cần; thêm/sửa/xóa budget line; action activate/cancel/close hiển thị lỗi BE
  rõ ràng; report dropdown ẩn plan CANCELED, giữ CLOSED lịch sử và ưu tiên
  ACTIVE. Nút xem report không hiện ở plan đã hủy.
- Goal: sửa mapping trạng thái BE `ACHIEVED`; card/list hiển thị đúng số đã
  góp/mục tiêu, ngày `dd/MM/yyyy`, trạng thái hoàn thành và chặn góp thêm khi
  đã đạt. Detail rút từ JSON kỹ thuật xuống tiến độ dễ đọc; allocation có
  create/edit/delete.
- Goal Contribution Plan: sửa FE gửi `FamilyMember.id` (không phải `userId`),
  parse response BE bọc trong `members`, nhận status thực tế `PLANNED` và
  `PAID`, hiển thị card gọn thay JSON thô và tính thiếu hụt gọn theo plan.
- Finance Alert: làm rõ nút `Tính lại cảnh báo từ dữ liệu hiện tại`; trạng thái
  "Đã xem"/"Đã xử lý"; resolve không giả vờ thay đổi số liệu, recompute có thể
  tạo lại alert nếu điều kiện nguồn vẫn còn. Alert RESOLVED không còn ở list.
  Detail đã ẩn UUID/field kỹ thuật. Badge notification in-app/local notification
  cập nhật theo unread count (launcher badge tùy thiết bị).
- Finance Report: localize enum/ngày/số tiền, ẩn field kỹ thuật trong report
  mode và thêm mô tả nghiệp vụ cho ba tab.

#### Finance — Model, Monthly Finance, Ledger

- Finance Model: lưu 5 Jars/80-20/Custom ở lại màn hình, cập nhật banner model
  vừa áp dụng ngay, không `pop()` về tab Tôi và không để response tải cũ ghi đè
  state người dùng vừa chỉnh.
- Monthly Finance: thêm shortcut "Tài chính tháng của tôi" cho mọi role;
  format tiền và lưu/đọc lại expected income, personal expense, shared
  contribution cùng visibility.
- Ledger/Wallet: form ghi thu/chi dùng format tiền và danh mục; giao dịch gần
  đây + lịch sử hiển thị `dd/MM/yyyy HH:mm` thay ISO raw.

### Runtime test đã làm trên emulator

- Goal allocation/góp trực tiếp: tạo, sửa và xóa đã thao tác; status/progress
  cập nhật đúng (ví dụ 8.000.000 / 15.000.000 = 53%).
- Budget: tạo Draft, thêm dòng, sửa số tiền, xóa dòng, cancel plan; validation
  yêu cầu ít nhất một dòng trước activate đã hoạt động.
- Alerts: acknowledge/resolve/recompute đã test. Sau khi góp đủ mục tiêu và
  điều chỉnh budget threshold, alert tương ứng biến mất sau recompute.
- Reports: đã mở và đối chiếu Budget, Non-essential, Budget & Goal.
- Goal contribution plan: Manager confirm/update và GET list đã test; 3 member
  plan hiển thị được sau fix parser. **Chưa test** Member submit rồi
  Manager approve/reject.
- Monthly Finance: Manager lưu `20.000.000 / 7.000.000 / 1.000.000`, bật
  visibility, thoát vào lại vẫn còn đúng.
- Ledger: ghi một thu và một chi; dấu tiền/số dư cập nhật đúng. Thời gian đã
  format để dễ đọc.

### Cần test tiếp (cần đăng nhập Member)

1. Goal contribution plan: member `submit` -> Manager `approve`/`reject`.
2. Spending support request: Member create/cancel -> Manager approve/reject.
3. Monthly summary/privacy: tắt một visibility ở Member, Manager/Deputy xem
   summary phải thấy field private là null/"Riêng tư".

### Lỗi / câu hỏi cần báo BE

1. **Goal contribution plan actual bị tính sai ngữ cảnh:** Sau khi tạo plan
   tháng 7, response `GET .../contribution-plans?month=7&year=2026` gán khoản
   goal allocation cũ `8.100.000` của Manager vào `actualAmount` plan mới có
   `plannedAmount` chỉ `222.222`, status `PAID`. Xác nhận whether allocation
   lịch sử có được tính vào plan tạo sau đó hay chỉ giao dịch submit/approve
   của đúng plan mới được tính.
2. **Ledger timezone:** máy/emulator GMT+7 lúc 02:57 nhưng BE trả cùng wall
   clock với hậu tố `Z`, ví dụ `2026-07-22T02:56:26.705Z`. `Z` nghĩa UTC là sai
   ngữ nghĩa (nếu convert chuẩn sẽ lệch +7 giờ). FE đang hiển thị theo giờ local
   được người dùng nhập; BE cần trả UTC thật hoặc offset `+07:00` nhất quán.
3. **Face Profile enroll:** BE trả `Face image is not enrollable` với ảnh chân
   dung thực. Cần contract điều kiện ảnh/face quality và mã lỗi chi tiết để FE
   hướng dẫn người dùng.

---

## Snapshot hiện tại 2026-07-19 — đọc phần này trước

> Snapshot này thay thế các kết luận CI/CD trong snapshot 2026-07-18 và các
> phần lịch sử phía dưới. Không xóa lịch sử vì vẫn chứa thông tin wiring/API.

### Kết luận ngắn

- **Admin Web CI/CD: DONE.**
- **Mobile CI: DONE.**
- **Android signed release + Google Drive + QR: DONE.**
- **Bảo mật nhiều tài khoản Admin: chưa thể kết luận DONE; phải được BE enforce.**
- **iOS native/TestFlight: chưa thực hiện; iPhone dùng Web/PWA làm fallback.**

### Git và trạng thái repository

#### Mobile — `D:\Desktop\mobile-sep`

- Repository: `16-Doffy/SEP-Family-Care-Mobile`.
- `origin/main`: merge commit `5fe0708` (PR #2).
- Commit triển khai Google Drive OAuth: `18d43ae`.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- CI/CD đã được commit, push và merge vào `main`; không còn code CI/CD cần
  commit/push.
- Working tree local còn:
  - modified `AI_HANDOFF_LATEST.md`;
  - untracked `.claude/`;
  - untracked `.vscode/settings.json`.
- Chỉ commit `AI_HANDOFF_LATEST.md` sau cập nhật này. Không tự động commit
  `.claude/` hoặc `.vscode/settings.json` nếu nhóm chưa thống nhất dùng chung.

#### Admin Web — `D:\Desktop\sep`

- Repository GitHub hiện dùng: `16-Doffy/SEP-Family-Care-WEB`
  (remote cũ có thể redirect từ tên `SEP-Family-Care-Third-s`).
- `origin/main`: merge commit `15038e8` (PR #1).
- Commit CI/CD chính:
  - `25bb110` — thêm Web Admin CI/CD;
  - `2360f89` — chuyển deployment sang Vercel, bỏ VPS deployment.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- Các file untracked như `.claude/`, script Swagger và file tạm không thuộc
  CI/CD; không commit chung nếu chưa review.

### Admin Web CI/CD — DONE

- Workflow nằm tại root repository:
  `.github/workflows/web-admin.yml`.
- Monorepo dùng pnpm workspace; Admin Next.js nằm tại `apps/web`.
- GitHub Actions đã chạy thành công:
  - type-check/build shared package và Admin Web;
  - Next.js production build;
  - verify Docker build bằng `apps/web/Dockerfile`.
- GitHub Actions không SSH/VPS và không push GHCR ở phương án hiện tại.
- CD dùng Vercel Git Integration:
  - PR/branch tạo Preview deployment;
  - merge/push `main` tạo Production deployment.
- Production URL:
  `https://family-care-admin.vercel.app`.
- Vercel Environment Variables đã cấu hình cho Production/Preview:
  - `NEXT_PUBLIC_API_URL`;
  - `NEXT_PUBLIC_SOCKET_URL`;
  - `BACKEND_API_ORIGIN`.
- Các Vercel API project cũ đã disconnect khỏi Git repository. Dấu đỏ lịch sử
  trong commit/check cũ không phản ánh Web Admin CI/CD hiện tại.
- Tài liệu: `D:\Desktop\sep\docs\WEB_ADMIN_CICD.md`.

### Mobile CI — DONE

- Workflow: `.github/workflows/mobile-ci.yml`.
- Tự chạy khi `push` hoặc `pull_request`.
- Các bước chính:
  - `flutter analyze --no-fatal-infos`;
  - `flutter test`;
  - build APK debug;
  - upload build artifact.
- Run gần nhất đã kiểm tra: pass.

### Android signed release, Google Drive và QR — DONE

- Workflow: `.github/workflows/android-release.yml`.
- Có thể chạy:
  - thủ công bằng `workflow_dispatch`; hoặc
  - tự động khi push tag `v*`.
- Release keystore được giữ bên ngoài repository:
  `D:\Desktop\FamilyCare-Release-Keys\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình, chỉ ghi tên, không ghi giá trị:
  - `ANDROID_KEYSTORE_BASE64`;
  - `ANDROID_KEYSTORE_PASSWORD`;
  - `ANDROID_KEY_ALIAS`;
  - `ANDROID_KEY_PASSWORD`;
  - `GDRIVE_CLIENT_ID`;
  - `GDRIVE_CLIENT_SECRET`;
  - `GDRIVE_REFRESH_TOKEN`;
  - `GDRIVE_FOLDER_ID`.
- Google Drive dùng **OAuth cá nhân**, không còn dùng Service Account.
- Google Cloud project: `FamilyCare-Mobile-Release`.
- Google Drive API đã bật; OAuth app/client đã cấu hình.
- Folder Drive đích: `FamilyCare-APK-Releases`.
- Android Release run thành công:
  - run ID: `29675484478`;
  - source: `main` tại merge commit `5fe0708`;
  - status: Success;
  - artifacts: 2;
  - signed APK: `FamilyCare-1.0.0-3.apk`;
  - APK đã upload vào Google Drive;
  - QR tải APK đã được tạo.
- Artifact trực tiếp:
  - QR:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438908227`;
  - signed APK:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438906932`.
- QR hiện được upload lên GitHub Actions artifact. Nếu muốn ảnh QR cũng nằm
  trong Google Drive thì upload thủ công, hoặc bổ sung một bước upload QR vào
  workflow ở lần cải tiến sau.
- Tài liệu: `docs/RELEASE_ANDROID.md`.

### Hành vi release về sau

- Không cần cấu hình lại Google Cloud, OAuth, GitHub Secrets hoặc keystore.
- Mỗi commit/PR thông thường chỉ chạy Mobile CI; không phát hành APK để tránh
  tạo quá nhiều bản release.
- Khi cần phát hành thủ công:
  1. Actions → Android Release → Run workflow;
  2. chọn `main`;
  3. nhập version hoặc để trống để dùng version trong `pubspec.yaml`;
  4. bật `Upload APK to Google Drive and generate a QR code`;
  5. chạy workflow.
- Muốn tag release tự upload Drive, tạo Repository Variable:
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó push tag, ví dụ `v1.0.1`.
- Không tái sử dụng/version-overwrite tùy tiện. Phải backup đúng release
  keystore; mất/đổi keystore có thể làm APK mới không cập nhật đè lên bản cũ.

### Bảo mật và dữ liệu nhạy cảm

- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, OAuth
  Client Secret, refresh/access token, mật khẩu hoặc Base64 keystore.
- GitHub Secrets/Variables là cấu hình ngoài Git; không ghi giá trị vào handoff.
- Bảo mật nhiều Admin phải do BE enforce:
  - RBAC/permission server-side cho mọi `/admin/*`;
  - không tin role do FE gửi;
  - session revocation, audit log, rate limit và MFA nếu áp dụng;
  - kiểm thử `401`/`403` và nhiều Admin độc lập.
- Checklist: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

### Việc còn lại/khuyến nghị

1. Quét QR bằng thiết bị Android, tải/cài APK và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile.
2. Backup release keystore ở ít nhất hai nơi an toàn; lưu mật khẩu trong
   password manager.
3. Tùy chọn đặt `GDRIVE_UPLOAD_ON_TAG=true` nếu nhóm muốn tag release tự upload
   Drive.
4. Tùy chọn cập nhật workflow để upload cả ảnh QR lên Google Drive.
5. Nếu cần iOS native: chuẩn bị macOS/Xcode, Apple Developer, signing và
   TestFlight. APK không cài được trên iPhone; hiện dùng Web/PWA fallback.
6. Tiếp tục làm việc với BE về checklist bảo mật nhiều Admin và hợp đồng
   Notifications realtime.

### Audit API và flow FE — tiếp tục ở phiên sau

- **Mục tiêu:** audit toàn diện Mobile Flutter theo Swagger production, SRS, UC
  Flow Tracker và báo cáo đề tài; không chỉ kiểm tra tên endpoint mà phải đối
  chiếu request/response DTO, role/permission, state transition và UI flow.
- **Nguồn cần dùng:** Swagger live
  `https://api.familycare-digital.com/api/docs` (OpenAPI:
  `/api/docs-json`), cùng các tài liệu ngoài workspace:
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_GSU26SE042_FAMILY_CARE_DIGITAL_FAMILY_MANAGEMENT_SO_HUYNX.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\Report3_Software Requirement Specification.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_FamilyCare_UC_Flow_Tracker (2).xlsx`.
  `FinalReport_Template (1).docx` là template tham khảo, không dùng làm nguồn
  nghiệp vụ chính.
- **Kết quả đã có trước khi tạm dừng:** Swagger production hiện có endpoint
  location sharing chuẩn theo family (`GET /families/{familyId}/members/locations`,
  `POST /families/{familyId}/locations`, `PATCH /families/{familyId}/members/me/location-sharing`),
  trong khi `lib/providers/gps_provider.dart` vẫn gọi các path cũ `/location/*`.
  Đây là lỗi FE cần sửa và test trong phiên audit kế tiếp; **chưa sửa/commit**.
- **Cách bàn giao:** sửa các lỗi FE xác định được và chạy analyze/test; các
  thiếu/sai contract hoặc lỗi runtime của BE phải lập danh sách gửi BE với
  endpoint, payload/response thực tế, role bị ảnh hưởng và bước tái hiện.

## Snapshot 2026-07-18 — lịch sử

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

### Trạng thái yêu cầu mentor

#### 1. Bảo mật khi mở rộng nhiều Admin — phụ thuộc BE

- **Chưa hoàn thành ở cấp hệ thống.** FE route guard chỉ hỗ trợ UX, không phải
  ranh giới bảo mật.
- Checklist cần gửi và thống nhất với BE nằm tại
  `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.
- BE cần:
  - cấm đăng ký công khai với `SYSTEM_ADMIN`;
  - tách `SUPER_ADMIN`/`ADMIN` hoặc permission tương đương;
  - enforce authorization trên mọi `/admin/*`, mặc định từ chối;
  - không tin role/permission do FE gửi;
  - bảo vệ Super Admin cuối cùng;
  - hỗ trợ MFA, rate limit, quản lý/thu hồi session;
  - vô hiệu session sau đổi mật khẩu, đổi role hoặc khóa tài khoản;
  - ghi audit log bất biến cho hành động nhạy cảm.
- QA cần kiểm tra `401` khi chưa đăng nhập, `403` với user không đủ quyền,
  session bị thu hồi sau khi Admin bị khóa/hạ quyền và audit actor tách biệt
  giữa nhiều Admin.

#### 3. FE setup CI/CD

- **Mobile Flutter: DONE.** CI khi push/PR đã chạy analyze, 55 tests, build
  debug APK và upload artifact; signed Android Release trên `main` đã pass.
- **Admin Web: CHƯA DONE.** Repo `D:\Desktop\sep` đã có Dockerfile/Compose
  nhưng chưa có GitHub Actions CI/CD riêng và chưa verify Docker image trên CI.
- Khi làm Admin Web CI/CD cần BE xác nhận API production URL, CORS, cookie
  domain và health-check endpoint.

#### 4. Dockerfile, APK, Google Drive, QR và iOS

- **Signed Android APK: DONE.** Đã build có chữ ký, tạo SHA-256 và upload
  GitHub Actions artifact.
- **Google Drive + QR: PARTIAL.** Workflow/code upload Drive và sinh QR đã có,
  nhưng chưa cấu hình service account/secrets và chưa chạy thử với Drive bật.
- Còn cần `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`, tùy chọn
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó chạy release và kiểm tra link/QR thật.
- **iOS: CHƯA DONE.** APK không cài được trên iPhone. Muốn phát hành iOS cần
  macOS/Xcode, Apple Developer, signing và TestFlight; nếu chưa có thì dùng
  Web/PWA. QR cuối nên điều hướng Android tới APK và iOS tới TestFlight/PWA.
- Dockerfile không dùng để tạo APK Flutter. Dockerfile hiện liên quan chủ yếu
  tới Admin Web/deployment web.

### Notifications realtime — hợp đồng BE mới nhận 2026-07-18

- Thông tin lịch sử phía dưới nói “BE chưa có FCM/WebSocket” đã **lỗi thời**.
- BE đã cung cấp hợp đồng Socket.IO namespace `/notifications`, tự join room
  `user:<userId>` bằng access token; không có Client → Server event.
- Server events:
  - `notification:new`;
  - `notification:unread-count`;
  - `notification:error`.
- REST notification vẫn dùng để list, lấy unread count, mark read/read-all.
- FCM token theo user/device:
  - `POST /api/v1/devices/tokens`;
  - `DELETE /api/v1/devices/tokens/:token` khi logout.
- `notification:new.id != null`: notification persisted, được thêm vào list và
  badge. `id == null`: push-only, chỉ toast/banner tức thời, không thêm list và
  không tăng badge.
- CHAT hiện là push-only và FCM có thể chứa toàn bộ nội dung tin nhắn; cần chốt
  với BE/Product chính sách ẩn nội dung nhạy cảm trên lock screen.
- **FE chưa tích hợp Socket.IO/FCM theo hợp đồng mới.** Polling 15 giây trong
  snapshot lịch sử chỉ là giải pháp tạm.
- Trước khi code cần BE xác nhận:
  1. URL Socket.IO production, Socket.IO path và server version;
  2. `/devices/tokens` đã deploy production và xuất hiện trên Swagger;
  3. thống nhất payload dùng `id` hay `notificationId`;
  4. unread count là theo family hay tổng tài khoản;
  5. chiến lược REST resync sau reconnect để lấy sự kiện bị bỏ lỡ;
  6. Firebase Android config và APNs/iOS config;
  7. chính sách hiển thị nội dung CHAT trên lock screen;
  8. test account/kịch bản token hết hạn, nhiều thiết bị và bị xóa khỏi family.

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
6. Gửi các câu hỏi Notifications realtime ở trên cho BE, sau đó tích hợp
   Socket.IO, REST resync và FCM token lifecycle vào Mobile.
7. Chốt phương án iOS: TestFlight nếu có Apple Developer + macOS/Xcode;
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
- **Kiểm chứng Swagger prod 16/07** (fetch trọn `docs-json`, so canonical với bản Tuần 9): **giống hệt 100%** (183 paths / 133 schemas) — BE chưa ship gì mới sau 15/07. Kết quả soi SOS schemas:
  - `responses[]` **ĐÃ được document** (`SosResponseResponseDto`): field chuẩn là **`responderMember`** `{displayName, familyRole, user{fullName, email, avatarUrl}}` + `responseType` + `respondedAt` + `message` → **FE đã sửa parse timeline** đưa `responderMember` lên đầu chuỗi fallback (trước đó thiếu key này → tên hiện "Thành viên").
  - `responseType` enum = `VIEWED|CONFIRM_SAFE|NEED_HELP|RESOLVED|CANCELED` — **xác nhận KHÔNG có `ON_THE_WAY`** → "Tôi đang đến" vẫn phải dựa text message (còn nợ BE).
  - `SosMemberUserResponseDto` **không có `phone`** → nút Gọi người khác vẫn chờ BE (còn nợ).
  - `status` alert có giá trị thứ 4 **`FALSE_ALARM`** — FE chưa có nhãn riêng (TODO nhỏ, hiện rơi về hiển thị raw).
  - `/location/family|toggle|update` **xác nhận không tồn tại** → Bug 1 báo cáo BE còn nguyên hiệu lực.

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

1. ~~Push~~ ✅ **Đã push** `giap` + merge FF vào `main` và push `origin/main` (16/07).
2. Gửi `BAO_CAO_BE_SOS_2026-07-16.md` cho Nghĩa — còn nợ BE: **location 3 EP** (Bug 1) + **enum `ON_THE_WAY`** + **`phone` trong `SosMemberUserResponseDto`**. Kèm câu hỏi: fix gán task có áp cho `generate-assignments` (định kỳ) chưa.
3. **Verify runtime trên device**: quét QR mã mời (2 máy), badge/poll thông báo, SOS Timeline với alert có phản hồi thật (tên phải hiện đúng sau fix `responderMember`), block "Trạng thái gia đình".
4. Khi BE ship location: đổi path `GpsProvider` (parse đã sẵn) → mở marker nhiều thành viên + family cards có vị trí.
5. TODO nhỏ: nhãn hiển thị cho status **`FALSE_ALARM`** (detail sheet + alert card đang rơi về raw).
6. `[VERIFY]` tồn đọng: checkout field Stripe, chat WebSocket.
