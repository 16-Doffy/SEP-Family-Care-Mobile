# Kế hoạch triển khai FE — Sau feedback thầy Huy (17/07/2026)

**Dự án:** Family Care — Mobile (Flutter) · **Mã:** SU26SE032
**Người thực hiện:** Giáp (SE171532 — FE Mobile)
**Repo:** `SEP-Family-Care-Mobile` · **Branch hiện tại:** `giap`
**Phạm vi tài liệu:** Chỉ phần FE Mobile theo 3 feedback của thầy Huy về FE.

---

## 1. Hiện trạng project (phân tích lại 17/07/2026)

### 1.1 Stack & cấu trúc

| Hạng mục | Giá trị |
|---|---|
| Flutter SDK | `^3.12.0` (channel stable, rev `559ffa3`) |
| State management | `provider ^6.1.2` (ChangeNotifier) |
| Routing | `go_router ^14.3.0` |
| Số file Dart | 80 file trong `lib/` |
| Module chính | `screens/{auth,parent,child,shared}`, `providers`, `services`, `navigation`, `wear`, `theme`, `widgets` |
| applicationId / namespace | `com.familycare.family_care` |
| Version | `1.0.0+1` (pubspec) |

Đã có sẵn `qr_flutter ^4.1.0` + `mobile_scanner ^7.2.0` (dùng cho invite QR) → **tái sử dụng được cho việc tạo QR link tải APK** (mục 4).

### 1.2 Những gì CHƯA có (gap so với feedback)

| Gap | Trạng thái | Ảnh hưởng feedback |
|---|---|---|
| **CI/CD** | ❌ Không có `.github/workflows/` — không có pipeline nào | Feedback #2 |
| **Dockerfile** | ❌ Không có `Dockerfile` / `.dockerignore` | Feedback #3 |
| **Release signing** | ⚠️ `android/app/build.gradle.kts` đang ký release bằng **debug keys** (`signingConfig = signingConfigs.getByName("debug")`, còn nguyên comment TODO) | Feedback #3 — APK phát hành phải ký release keystore |
| **App launcher icon** | ⚠️ Chưa có `flutter_launcher_icons` — icon app là icon Flutter mặc định | Liên quan #1 (branding) |
| **App label** | ⚠️ `AndroidManifest.xml` → `android:label="family_care"` (chữ thường, tên kỹ thuật) | Nên đổi thành `Family Care` |
| **Thư mục `ios/`** | ❌ **KHÔNG tồn tại** — project chỉ có `android/`, `web/`, `windows/` | 🔴 **Feedback #3 (link iOS) — blocker, xem 4.4** |
| **Logo trợ lý AI** | ⚠️ Đang dùng emoji `🤖` ở 4 vị trí, không phải logo thật | Feedback #1 |

### 1.3 Vị trí "logo trợ lý AI" hiện tại (emoji `🤖`)

| File | Dòng | Ngữ cảnh |
|---|---|---|
| `lib/screens/shared/ai_assistant_screen.dart` | 16 | Tin nhắn chào đầu ("Tôi là trợ lý AI của FamilyCare 🤖") |
| `lib/screens/shared/ai_assistant_screen.dart` | 45 | Icon tiêu đề AppBar màn hình chat AI |
| `lib/screens/parent/home_dashboard_screen.dart` | 521 | Card "Trợ lý AI" ở dashboard Manager/Deputy |
| `lib/screens/child/child_home_screen.dart` | 335 | Entry point Trợ lý AI ở home Member |

Asset sẵn có để làm logo: `assets/images/FamilyCare_logo.png`, và ở root repo `familycare_icon_1024.png` (1024×1024), `familycare_logo.png`.

---

## 2. Feedback #1 — Đổi logo trợ lý AI (giao diện FE)

### Mục tiêu
Thay emoji `🤖` bằng một logo/icon trợ lý AI nhất quán, có thương hiệu (không dùng emoji hệ điều hành — hiển thị khác nhau giữa máy).

### Các bước đề xuất

1. **Chốt asset logo AI.** 2 hướng:
   - (A) Icon vector Material phù hợp: `Icons.auto_awesome` / `Icons.smart_toy_rounded` / `Icons.psychology_rounded` — nhanh, nhất quán, không cần asset.
   - (B) Logo ảnh riêng cho trợ lý AI (ví dụ `assets/images/ai_assistant.png`) — cần file thiết kế. **[VERIFY]** thầy Huy/team muốn icon vector hay logo ảnh riêng.

2. **Tạo 1 widget dùng chung** để tránh lặp 4 chỗ và dễ đổi về sau:
   ```dart
   // lib/widgets/ai_assistant_avatar.dart
   import 'package:flutter/material.dart';
   import '../theme/app_colors.dart';

   class AIAssistantAvatar extends StatelessWidget {
     final double size;
     const AIAssistantAvatar({super.key, this.size = 24});

     @override
     Widget build(BuildContext context) {
       // Hướng A: icon vector — đổi 1 chỗ, áp dụng toàn app
       return Container(
         width: size + 8,
         height: size + 8,
         decoration: BoxDecoration(
           color: AppColors.link.withValues(alpha: 0.12),
           shape: BoxShape.circle,
         ),
         alignment: Alignment.center,
         child: Icon(Icons.auto_awesome_rounded, size: size, color: AppColors.link),
       );
       // Hướng B (logo ảnh): thay bằng Image.asset('assets/images/ai_assistant.png', width: size, height: size)
     }
   }
   ```

3. **Thay 4 vị trí** `🤖` bằng `const AIAssistantAvatar(size: ...)`:
   - `ai_assistant_screen.dart:45` → thay `const Text('🤖', ...)` trong AppBar.
   - `home_dashboard_screen.dart:521` → thay `const Text('🤖', style: TextStyle(fontSize: 28))`.
   - `child_home_screen.dart:335` → thay tương tự.
   - `ai_assistant_screen.dart:16` → tin nhắn chào: bỏ emoji trong text hoặc giữ (text nội dung, không phải logo — **[VERIFY]** có cần đổi cả text không).

4. Nếu chọn hướng B: khai báo asset trong `pubspec.yaml` (mục `flutter.assets`) rồi `flutter pub get`.

5. **Test:** chạy `flutter analyze` + mở 3 màn (AI screen, home Manager, home Member) kiểm tra hiển thị.

> ⚠️ Đây là task **generate code Flutter** → theo quy ước project, code chi tiết thực hiện ở **Dev Chat project**, không ở project doc này. Tài liệu này chỉ định hướng + vị trí file.

---

## 3. Feedback #2 — FE setup CI/CD vào repository

### Mục tiêu
Thêm pipeline CI/CD ngay trong repo để tự động kiểm tra code và build APK.

### Bối cảnh
Repo host trên GitHub (remote `origin` có các branch `main`, `giap`, `NDuy`, `hopnhat`) → dùng **GitHub Actions** là hợp lý nhất (miễn phí cho repo, tích hợp sẵn).

### Các bước đề xuất

**Bước 3.1 — Pipeline CI (kiểm tra chất lượng), chạy mỗi push/PR:**

Tạo `.github/workflows/flutter-ci.yml`:
```yaml
name: Flutter CI
on:
  push:
    branches: [ main, giap, hopnhat ]
  pull_request:
    branches: [ main ]

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.12.0'   # [VERIFY] khớp SDK team đang dùng
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

**Bước 3.2 — Pipeline build APK (CD), chạy khi tạo tag `v*` hoặc thủ công:**

Tạo `.github/workflows/build-apk.yml`:
```yaml
name: Build Release APK
on:
  push:
    tags: [ 'v*' ]
  workflow_dispatch:        # cho phép bấm build tay trên GitHub

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'zulu', java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.12.0', channel: stable, cache: true }
      - run: flutter pub get
      # [VERIFY] Nếu đã có release keystore: decode từ secret trước khi build
      # - run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/release.jks
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: family-care-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

**Bước 3.3 — Cấu hình:**
- Thêm GitHub Secrets cho signing: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` (sau khi tạo keystore ở mục 4.1).
- **[VERIFY]** với Leader (Nhật): CI/CD đặt ở branch nào là canonical, có bật branch protection require CI pass trên `main` không.

**Bước 3.4 — Nghiệm thu:** Push thử 1 commit → thấy Actions chạy `analyze` + `test` xanh; chạy `workflow_dispatch` → tải được artifact APK.

> ⚠️ `flutter test` hiện có thư mục `test/` — **[VERIFY]** test hiện có pass không, nếu chưa có test thật thì bước `flutter test` có thể để `--no-fatal` hoặc tạm bỏ để CI không đỏ.

---

## 4. Feedback #3 — Dockerfile + release APK lên Google Drive + QR cho hội đồng

Feedback gốc: *"Frontend viết dockerfile và release file APK luôn đưa lên gg drive → sau đó tạo mã QR cho hội đồng vào bằng iOS hoặc Android link để download về."*

Chia thành 4 phần: (4.1) ký release, (4.2) Dockerfile build, (4.3) Drive + QR, (4.4) vấn đề iOS.

### 4.1 — Ký release keystore (BẮT BUỘC trước khi phát hành)

Hiện release đang ký bằng **debug key** → APK không hợp lệ để phát hành/cập nhật. Cần:

1. Tạo keystore (chạy 1 lần, **lưu file `.jks` an toàn, KHÔNG commit lên git**):
   ```bash
   keytool -genkey -v -keystore family-care-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias familycare
   ```
2. Tạo `android/key.properties` (thêm vào `.gitignore`):
   ```properties
   storePassword=<...>
   keyPassword=<...>
   keyAlias=familycare
   storeFile=../family-care-release.jks
   ```
3. Sửa `android/app/build.gradle.kts`: load `key.properties`, thay `signingConfigs.getByName("debug")` bằng `signingConfigs.getByName("release")` trỏ tới keystore trên.
4. **[VERIFY]** thống nhất với team ai giữ keystore (mất keystore = không update được app).

### 4.2 — Dockerfile build APK (môi trường build tái lập)

> Lưu ý: app mobile không "chạy" trong Docker. Dockerfile ở đây để **đóng gói môi trường build APK tái lập** — hữu ích cho CI hoặc build local giống nhau giữa các máy.

Tạo `Dockerfile` ở root:
```dockerfile
# Build APK release trong container tái lập
FROM ghcr.io/cirruslabs/flutter:3.12.0   # [VERIFY] tag khớp SDK team

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build apk --release

# APK nằm ở: build/app/outputs/flutter-apk/app-release.apk
CMD ["bash"]
```

Tạo `.dockerignore`:
```
build/
.dart_tool/
.git/
android/app/*.jks
android/key.properties
```

Cách dùng:
```bash
docker build -t family-care-apk .
docker create --name fc family-care-apk
docker cp fc:/app/build/app/outputs/flutter-apk/app-release.apk ./app-release.apk
docker rm fc
```

**[VERIFY]** Nếu build có ký release keystore trong Docker → phải mount/COPY keystore an toàn (không đưa keystore vào image public).

### 4.3 — Đưa APK lên Google Drive + tạo QR

1. Build APK release: `flutter build apk --release` (hoặc lấy từ CI ở mục 3.2 / Docker ở 4.2).
   - Cân nhắc `--split-per-abi` để giảm dung lượng, nhưng cho hội đồng tải demo thì **1 APK universal** đơn giản hơn.
2. Upload `app-release.apk` lên Google Drive của team → **chia sẻ "Anyone with the link"** → lấy link tải trực tiếp.
   - Link Drive thường mở trang preview; để tải thẳng có thể dùng dạng:
     `https://drive.google.com/uc?export=download&id=<FILE_ID>`  **[VERIFY]** (file lớn Drive có thể chèn màn xác nhận virus scan).
3. Tạo **QR code** trỏ tới link Drive. 3 cách:
   - Nhanh nhất: dùng web tạo QR (qr-code-generator, hoặc `qrencode` CLI).
   - Trong repo đã có `qr_flutter` → có thể tạo 1 màn/asset QR ngay trong app nếu muốn "made in app".
   - Sinh QR bằng script (không cần app):
     ```bash
     # cần cài qrencode
     qrencode -o family-care-apk-qr.png "https://drive.google.com/uc?export=download&id=<FILE_ID>"
     ```
4. Đưa QR vào slide demo / poster cho hội đồng quét tải.

### 4.4 — 🔴 Vấn đề iOS link (cần chốt với thầy Huy)

Feedback nói *"tải bằng iOS hoặc Android link"*, nhưng:

- **Project hiện KHÔNG có thư mục `ios/`** (chỉ có `android`, `web`, `windows`).
- Kể cả khi thêm iOS, để tải/cài app iOS ngoài App Store cần: **máy macOS + tài khoản Apple Developer (99 USD/năm)** + TestFlight hoặc ad-hoc provisioning theo UDID. **Không thể** phát hành file `.ipa` cài trực tiếp qua "link tải" như APK.

**Đề xuất trình bày với thầy Huy (chọn 1):**

| Phương án | Mô tả | Chi phí/độ khó |
|---|---|---|
| A (khuyến nghị) | Demo **Android APK** qua QR; hội đồng dùng máy Android hoặc emulator. iOS để "ngoài phạm vi demo". | Thấp — làm được ngay |
| B | Build **web** (đã có `web/`) → deploy (Firebase Hosting / GitHub Pages) → QR trỏ web app, mở được trên cả iOS & Android qua trình duyệt. | Trung bình — không cần Apple Dev |
| C | Làm iOS thật qua **TestFlight** | Cao — cần macOS + Apple Developer account |

> 🔴 **[VERIFY] BẮT BUỘC:** Hỏi thầy Huy iOS có thật sự bắt buộc cho demo không. Nếu chỉ cần "quét QR tải về xem được" thì **Phương án B (web link)** đáp ứng cả iOS lẫn Android mà không tốn Apple Developer.

---

## 5. Roadmap tổng hợp — thứ tự thực hiện

| # | Việc | Feedback | Ưu tiên | Phụ thuộc |
|---|---|---|---|---|
| 1 | Chốt asset + đổi logo AI (widget dùng chung, 4 vị trí) | #1 | Cao | [VERIFY] chọn icon/logo |
| 2 | Tạo release keystore + sửa `build.gradle.kts` ký release | #3 | **Cao (chặn phát hành)** | — |
| 3 | Thêm `flutter_launcher_icons` + đổi `android:label` = "Family Care" | #1 | Trung bình | — |
| 4 | Tạo CI workflow (`flutter-ci.yml`): analyze + test | #2 | Cao | [VERIFY] test pass |
| 5 | Tạo CD workflow (`build-apk.yml`) + GitHub Secrets keystore | #2, #3 | Cao | #2 |
| 6 | Viết `Dockerfile` + `.dockerignore` build APK | #3 | Trung bình | #2 |
| 7 | Build APK release → upload Drive → tạo QR | #3 | Cao | #2 |
| 8 | Chốt phương án iOS với thầy Huy (A/B/C) | #3 | **Cao (blocker)** | [VERIFY] |

---

## 6. Danh sách [VERIFY] cần chốt trước khi làm

1. **[VERIFY]** Logo AI: dùng icon vector Material hay logo ảnh thiết kế riêng?
2. **[VERIFY]** Có cần đổi cả emoji trong *nội dung tin nhắn* chào của AI không, hay chỉ đổi icon giao diện?
3. **[VERIFY]** Phiên bản Flutter SDK chính xác team thống nhất cho CI/Docker (`3.12.0` là bản tối thiểu theo pubspec — cần bản build cụ thể).
4. **[VERIFY]** Thư mục `test/` hiện có test pass không (ảnh hưởng bước `flutter test` trong CI).
5. **[VERIFY]** Branch canonical cho CI/CD + có bật branch protection trên `main` không (hỏi Nhật).
6. **[VERIFY]** Ai giữ release keystore của team.
7. **[VERIFY]** Link tải trực tiếp Google Drive cho file APK lớn (màn xác nhận virus scan).
8. 🔴 **[VERIFY]** iOS có bắt buộc cho demo hội đồng không — quyết định A/B/C ở mục 4.4.

---

## 7. Ghi chú phạm vi

- Các mục **generate code Flutter** (đổi logo, sửa `build.gradle.kts`, widget mới) — theo quy ước project, thực hiện chi tiết ở **Dev Chat project**; tài liệu này chỉ định hướng + vị trí file + snippet mẫu.
- Docker/CI/infra thường thuộc phạm vi cross-team — nếu cần thống nhất runner/secret với Backend (Nghĩa) thì trao đổi thêm.

---

*Tài liệu tạo 17/07/2026 — dựa trên phân tích repo `SEP-Family-Care-Mobile` (branch `giap`) và feedback FE của thầy Huy.*
