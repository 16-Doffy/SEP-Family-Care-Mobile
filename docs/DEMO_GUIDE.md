# Demo Guide — Family Care Mobile/Wear

Ngày cập nhật: 2026-08-09

## Tổng quan

Tài liệu này dùng để chuẩn bị demo app mobile và Wear OS. Nội dung bám theo code hiện tại trong repo, không giả định endpoint ngoài Swagger.

## Prerequisites

- Mobile app đã đăng nhập tài khoản thuộc một gia đình.
- Wear OS app chạy bằng target `lib/wear/main_wear.dart`.
- Đồng hồ/máy ảo Wear OS đã được đặt vị trí GPS trước khi demo SOS có bản đồ.
- Nếu test tài khoản đã từng ghép bằng mã cũ, cần gỡ hẳn trạng thái `PAIRED` trước khi ghép lại bằng mã `FCW-XXXXXX`.

## Steps

### 1. Build và chạy app

```powershell
flutter build apk --release
flutter run -d <emulator> --target lib/wear/main_wear.dart
```

### 2. Ghép đồng hồ

1. Mở app Wear OS.
2. Đồng hồ gọi wearable activation và hiển thị mã dạng `FCW-XXXXXX`.
3. Trên mobile, vào **Hồ sơ → Thiết bị đeo**.
4. Nhập mã `FCW-XXXXXX` đang hiện trên đồng hồ.
5. Chờ đồng hồ poll đến trạng thái `PAIRED`, rồi claim token để đăng nhập.

Lưu ý migration: nếu tài khoản test còn wearable `PAIRED` bằng định danh cũ, hãy gỡ ghép trước rồi ghép lại bằng mã mới. Record `UNPAIRED` không nên được hiểu là còn đang ghép; nếu vẫn gặp `409 WEARABLE_ALREADY_PAIRED`, cần kiểm tra lại trạng thái thật bằng `GET /wearables/me`.

### 3. Đặt GPS cho máy ảo Wear OS

1. Mở emulator Wear OS.
2. Vào **Extended controls → Location**.
3. Chọn hoặc nhập một điểm trên bản đồ.
4. Bấm **Set**.

Đây là bước bắt buộc khi demo bản đồ từ đồng hồ. Nếu không đặt GPS, đồng hồ có thể hiện “Không lấy được GPS đồng hồ”; đây là hành vi đúng, không phải lỗi code.

### 4. Demo SOS thủ công từ đồng hồ

1. Trên Wear OS, mở màn **SOS**.
2. Giữ nút SOS 2 giây.
3. Sau khi cảnh báo được tạo, đồng hồ lấy GPS riêng của chính nó và gửi `WEARABLE_GPS` kèm `deviceId`.
4. Trên mobile của người nhà, mở chi tiết SOS để xem bản đồ, nguồn vị trí và đường đi nếu có nhiều điểm.
5. Trên đồng hồ, bấm **Tôi an toàn** để gọi `confirm-safety` và dừng gửi vị trí định kỳ.

### 5. Demo SOS cảm biến

1. Trên Wear OS, mở **Cảm biến SOS**.
2. Bật cảm biến thật, hoặc dùng 3 nút giả lập:
   - Giả lập té ngã
   - Giả lập nhịp tim cao
   - Giả lập nhịp tim thấp
3. Màn cảnh báo đếm ngược 20 giây; bấm **Con ổn/Đã ổn** để hủy trước khi gửi, hoặc bấm **Gửi SOS**.
4. Mỗi lần gửi event `HEART_RATE_ABNORMAL` có thể tạo SOS thật theo rule BE hiện tại. Khi demo, hãy báo trước cho cả nhóm vì mobile người nhà sẽ nhận cảnh báo thật.

### 6. Demo lối tắt SOS trên điện thoại (không cần mở app)

Điểm cần nói khi demo: SOS mà bắt mở app rồi tìm tab thì trong tình huống thật
là quá chậm. Lối tắt bỏ hẳn bước điều hướng.

1. Trên màn hình chính, **giữ icon Family Care** → hiện mục **“Gửi SOS khẩn cấp”**.
2. Ấn vào là app mở **thẳng** màn SOS và **tự đếm ngược 3 giây** rồi gửi — không
   phải giữ nút, không qua trang chủ.
3. Bấm **HỦY** trong lúc đếm ngược để chứng minh chạm nhầm không tạo báo động giả.
4. Ấn tượng hơn: **kéo mục “Gửi SOS” đó ra màn hình chính** → thành nút SOS đỏ
   độc lập, từ đó **1 chạm** là chạy luôn kịch bản trên.

> Lối tắt cần Android 7.1 (API 25) trở lên. Máy API 24 sẽ không thấy mục này —
> `minSdk` của dự án là 24 nên không crash, chỉ là không có lối tắt.

## Expected Result

- Đồng hồ ghép thành công bằng mã `FCW-XXXXXX`.
- Giữ icon app trên điện thoại thấy lối tắt “Gửi SOS khẩn cấp”; ấn vào mở thẳng
  màn SOS đang đếm ngược, có nút HỦY.
- SOS thủ công và SOS cảm biến tạo cảnh báo mà không phải chờ GPS trước.
- Đồng hồ hiển thị trạng thái GPS: “Đang lấy vị trí…”, “Đã có vị trí”, hoặc “Không lấy được GPS đồng hồ”.
- Mobile hiển thị bản đồ từ `locationPoints`, nhãn “Vị trí từ đồng hồ/điện thoại/giả lập”, và đường đi khi có từ 2 điểm hợp lệ.
- Đồng hồ gửi vị trí định kỳ 30 giây/lần khi SOS còn `ACTIVE`, dừng khi confirm safety, dispose màn, alert không còn `ACTIVE`, hoặc lỗi liên tiếp 3 lần.

## Troubleshooting

| Hiện tượng | Cách kiểm tra / xử lý |
|---|---|
| Đồng hồ không có bản đồ | Kiểm tra đã set GPS trong Extended controls → Location chưa. |
| Ghép mã bị `409 WEARABLE_ALREADY_PAIRED` | Kiểm tra tài khoản còn wearable `PAIRED` không; gỡ và verify lại bằng `GET /wearables/me`. |
| Cảm biến SOS không gửi được | Tài khoản Wear phải đã ghép wearable; màn chính sẽ hiện “Chưa ghép thiết bị” nếu chưa đủ điều kiện. |
| Người nhận mở chi tiết SOS quá sớm chưa thấy bản đồ | Sheet chi tiết có retry `location/current`; chờ vài giây hoặc mở lại chi tiết. |
| Nhịp tim giả lập tạo cảnh báo thật | Đây là rule BE đã chốt cho `HEART_RATE_ABNORMAL`; không bấm demo nếu chưa báo trước. |
| Giữ icon app không thấy lối tắt SOS | Máy phải Android 7.1+ (API 25). Vừa cài đè bản cũ thì một số launcher cần khởi động lại launcher hoặc gỡ/cài lại mới nạp `shortcuts.xml`. |
| Ấn lối tắt nhưng app mở ở trang chủ thay vì màn SOS | Launcher không truyền URI `familycare://app/sos-quick`. Kiểm tra `targetPackage` trong `res/xml/shortcuts.xml` có khớp `applicationId` ở `android/app/build.gradle.kts` không — hai giá trị này hiện KHÁC nhau và phải sửa cùng lúc. |

## SOS nền và Call foreground service

Cập nhật 2026-08-12:

- Mobile Android đã có `SosGuardService` foreground service riêng cho SOS nền. Công tắc nằm trong **Cài đặt SOS -> Bảo vệ SOS trên máy này**:
  - `Lắc mạnh để mở SOS`
  - `Theo dõi té ngã khi chạy nền`
- Khi phát hiện lắc/té ngã, service mở deep link `familycare://app/sos-quick`; màn SOS vẫn đếm ngược 3 giây và có nút hủy.
- Mobile Android đã có `CallGuardService` foreground service riêng cho cuộc gọi video, bật khi `LivekitRoomService.connect()` và tắt khi `disconnect()`.
- Hai service tách riêng vì `foregroundServiceType` khác nhau: SOS dùng `specialUse`, Call dùng `camera|microphone`.

**Sửa thêm 2026-08-12 (Claude Code review lại bản Codex):** 3 lỗ hổng đã vá ở tầng code, **chưa verify
trên máy thật**:
- `SosGuardService` không kiểm tra `canUseFullScreenIntent()` (Android 14+) và có một dòng
  `pendingIntent.send()` thủ công không phải fallback hợp lệ (bị chặn bởi giới hạn
  background-activity-launch) — đã bỏ dòng đó, thêm nhánh kiểm tra quyền thật: có quyền thì để hệ
  thống tự mở màn qua `setFullScreenIntent`, không có quyền thì chỉ bắn thông báo phải chạm tay kèm nút
  "Cấp quyền ngay" (mở `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`) trong Cài đặt SOS.
- Service không dừng khi đăng xuất (rủi ro thiết bị dùng chung: người sau đăng nhập "thừa hưởng" cảm
  biến của người trước) — đã nối `SosGuardService` vào `ApiClient.addSessionResetListener`.
- Thiếu quyền `VIBRATE` nên rung chống báo động giả không hoạt động — đã thêm quyền + rung tường minh
  (mẫu rung riêng, tắt rung mặc định của channel để không rung chồng 2 lần).

Cần test trên máy thật trước khi demo hội đồng:

| # | Kịch bản | Trạng thái |
|---|---|---|
| 1 | Khóa màn hình, lắc mạnh | **Đã test trên Oppo CPH2159 thật (12/08) — PASS.** Log xác nhận `SosGuardService` bắt được lắc, bắn notification `familycare_sos_guard_alert` có `fullscreenIntent` hợp lệ, deep link `familycare://app/sos-quick` mở đúng. Máy đang khóa lúc lắc nên hệ thống chỉ hiện notification thường (không tự mở full-screen đè màn khóa) — đây là hành vi chuẩn của Android `setFullScreenIntent`, không phải lỗi (xem ghi chú bên dưới) |
| 1b | Mở khóa, lắc mạnh | **Đã test trên Oppo CPH2159 thật (12/08) — PASS.** Người dùng xác nhận chuyển đúng tới màn SOS đếm ngược |
| 2 | Đi bộ 5 phút, để máy trong túi | Chưa test trên máy thật |
| 3 | Đi xe máy 5 phút đường xóc | Chưa test trên máy thật |
| 4 | Để máy Oppo tắt màn hình 30 phút | Chưa test trên máy thật |
| 5 | Android 14+ chưa cấp full-screen intent → hiện nút "Cấp quyền ngay", bấm vào mở đúng màn cài đặt | Chưa test trên máy thật (máy test là Android 13 nên không áp dụng giới hạn này) |
| 6 | Đang gọi video, khóa màn hình 10 giây, mở lại | Chưa test trên máy thật |
| 7 | Đang gọi video, bấm Home 30 giây, quay lại | Chưa test trên máy thật |
| 8 | Lắc mạnh khi máy trong túi quần | Có rung mạnh cảm nhận được không — chưa test riêng |
| 9 | Bật lắc/té ngã, đăng xuất, đăng nhập tài khoản khác | Service phải dừng, không còn thông báo thường trực — chưa test riêng |

**Ghi chú ca 1 (quan trọng, giải thích trước khi demo):** `setFullScreenIntent()` chỉ tự mở đè lên màn
hình khi máy **thật sự đang khóa/tắt màn tại đúng thời điểm bắn thông báo**. Nếu người dùng đang thao
tác máy (kể cả chỉ vừa mở khóa ra) thì Android chỉ hiện notification thường, cần chạm để mở — đây là
hành vi mặc định của hệ thống, đã kiểm tra `fullscreenIntent` trong `dumpsys notification` không phải
`null` nên code đúng. Khi demo, nên khóa hẳn màn hình vài giây rồi mới lắc để thấy được hành vi tự mở
đè màn khóa.

**Bug đã phát hiện và ĐÃ SỬA (12/08):** công tắc "Lắc mạnh để mở SOS" trong Cài đặt SOS đôi khi hiện
lại OFF ngay sau khi bật, dù `SosGuardService` đã chạy thật (đã xác nhận qua `dumpsys` lúc bắt được
bug — service sống, notification thường trực hiện đúng, lắc vẫn hoạt động). Nguyên nhân: sau khi gọi
native `start()`, code gọi lại `_loadGuardStatus()` ngay lập tức trong khi `startForegroundService()`
phía Kotlin chưa kịp chạy xong `onStartCommand()` để cập nhật cờ trạng thái, nên đọc lại giá trị cũ
(`false`) và ghi đè lên UI đã bật đúng trước đó. Đã sửa ở `_setGuard()`
(`lib/screens/shared/sos_settings_screen.dart`): bỏ lệnh gọi lại `_loadGuardStatus()` thừa sau khi
`start()` thành công, tin vào state optimistic đã set trước đó; chỉ đồng bộ lại khi có lỗi thật.
**Đã build lại + cài lại + test trên chính máy Oppo CPH2159, xác nhận công tắc hiện đúng ngay lập
tức** (không cần chờ resume app nữa), `SosGuardService` vẫn chạy thật qua `dumpsys`. `flutter test`
478/478 pass, `flutter analyze` 0 lỗi sau khi sửa.

Không coi tính năng SOS nền là đã sẵn sàng demo công khai nếu các ca trên chưa có kết quả trên máy thật.

### Bám theo Emergency SOS hệ thống (chỉ ColorOS) — thêm 2026-08-12 — 🛑 KHÔNG DEMO ĐƯỢC, xem bên dưới

Người dùng yêu cầu giữ thao tác "bấm nguồn 5 lần", nhưng bằng kỹ thuật khác với cách đã bị loại bỏ
ở lần thử đầu (chặn phím nguồn — bị hệ thống lọc trước, không lách được). Cách mới: app dùng
`EmergencySosWatcherService` (`AccessibilityService`, chỉ theo dõi sự kiện đổi màn hình đang hiện,
**không đọc nội dung màn hình**) để phát hiện lúc màn Emergency SOS của ColorOS
(`com.oplus.sos`) vừa xuất hiện — do bấm nguồn 5 lần hoặc tự mở tay đều được — rồi tự gửi SOS của
app **ngay lập tức, không đếm ngược, không nút hủy** (vì màn hệ thống đang chiếm chỗ, không vẽ đè
UI xác nhận được).

- Bật/tắt: **Cài đặt SOS → Bám theo Emergency SOS của máy** → nút mở Cài đặt Trợ năng (app không tự
  bật hộ được, đây là giới hạn của hệ điều hành).
- Chỉ có tác dụng trên ColorOS (Oppo/Realme/OnePlus). Máy hãng khác: mục vẫn hiện trong Cài đặt SOS
  nhưng bật lên cũng không có tác dụng gì (không lỗi, không crash).
- Chi tiết kiến trúc + toàn bộ danh sách chưa-kiểm-chứng: xem mục 13 của
  `KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md`.

**Đã chạy sạch:** `flutter analyze` 0 lỗi, `flutter test` 478/478 pass, Gradle
`compileDebugKotlin` + `testDebugUnitTest` (JVM test cho `EmergencySosMatcher`) build thành công.

**Đã test trên 2 máy ảo (HOH, MEM):** app cài/chạy sạch, `EmergencySosWatcherService` được
`PackageManager` nhận đúng và **chạy thật** khi bật (chỉ bật được trên emulator, xem lý do bên
dưới); deep link `/sos-immediate` vào thẳng màn gửi ngay, **không đếm ngược**, đúng thiết kế — kể cả
tình cờ xác nhận được cả luồng gửi SOS thật tới BE. Nhưng đây chỉ xác nhận phần UI/route, **không**
xác nhận được phần quan trọng nhất: tự phát hiện màn Emergency SOS thật (emulator không có
`com.oplus.sos`).

**🛑 Test trên máy Oppo CPH2159 thật (12/08) — phát hiện CHẶN THẬT, không phải "chưa test":**

Vào Cài đặt > Trợ năng > Family Care để bật thì bị chặn ngay bởi hộp thoại hệ thống **"Chế độ cài
đặt bị hạn chế"** — cơ chế "Restricted settings" của Android 13+ chống lạm dụng Accessibility Service,
áp dụng cho **mọi** app cài qua APK trực tiếp/ADB (không phải lỗi riêng của app này).

Đã thử hết các cách mở khoá thường dùng, **đều thất bại trên máy này**: menu "Cho phép cài đặt bị
hạn chế" chuẩn AOSP không tồn tại trong menu 3 chấm của App info trên bản ColorOS này; cài lại APK
giả installer Play Store không có tác dụng; `adb shell settings put secure
enabled_accessibility_services` bị từ chối quyền (`WRITE_SECURE_SETTINGS`); `adb shell appops set
... ACCESS_RESTRICTED_SETTINGS allow` cũng bị từ chối quyền (`MANAGE_APP_OPS_MODES`); không tìm thấy
đường mở khoá thay thế trong Cài đặt hệ thống hay app Trung tâm bảo mật OPPO.

**Đã xác nhận lại bằng tay thật (12/08):** người dùng tự chạm màn hình thật (không qua ADB) vào
Cài đặt > Trợ năng > Family Care, bấm nút gạt — hiện đúng y hệt hộp thoại "Chế độ cài đặt bị hạn
chế", chỉ có nút OK. **Không phải do ADB giả lập chạm — chặn thật ở cấp hệ điều hành, tay thật cũng
vậy.**

**Kết luận: hiện KHÔNG demo được Cơ chế B trên máy Oppo CPH2159 này ở dạng APK trực tiếp — không
phải vì code lỗi, mà vì chính sách hệ điều hành chặn từ bước bật quyền.** Xem đầy đủ + hướng ra còn
lại (máy/bản ColorOS khác; phát hành qua kênh tin cậy) ở mục 13.7 của kế hoạch.

| # | Kịch bản | Trạng thái |
|---|---|---|
| 10 | Bật Trợ năng cho `EmergencySosWatcherService` | **Bị chặn** — "Chế độ cài đặt bị hạn chế", xem chi tiết ở trên |
| 11 | Bấm nguồn 5 lần → màn Emergency SOS hiện → `SOSScreen(immediate)` tự mở, gửi tới BE | Không test được (phụ thuộc ca 10) |
| 12 | Chưa bật Trợ năng, bấm nguồn 5 lần | Đúng thiết kế theo suy luận (chưa bật được Trợ năng nên chắc chắn không phản ứng) |
| 13 | Bấm nguồn 5 lần 2 lần liên tiếp trong 30 giây | Không test được (phụ thuộc ca 10) |
| 14 | Tên gói/lớp `com.oplus.sos` có còn đúng như đã nhớ lại từ lần đo trước không | Chưa đối chiếu lại — không tới được bước này vì bị chặn từ ca 10 |

**Không demo tính năng này trước hội đồng ở trạng thái hiện tại.** Nếu bị hỏi, trả lời bằng phát
hiện thật này: đây là giới hạn nền tảng Android 13+ đã biết đối với app cài ngoài Play Store, không
phải thiếu sót thiết kế — tương tự cách mục 1 của kế hoạch đã trình bày lý do loại "chặn phím nguồn".

Không demo tính năng này trước hội đồng nếu ca 10–11 chưa chạy được trên máy Oppo thật ít nhất một
lần — đây là phần rủi ro nhất vì phụ thuộc tên gói/lớp nội bộ của OEM mà Google không công bố chính
thức.

## Known Issues

- AI tạo giao dịch “ngay bây giờ” còn từng có báo cáo lệch giờ; cần verify runtime nếu demo phần AI tài chính.
- AI tạo khoản thu/chi hiện chưa tự gán `categoryId`, nên có thể rơi vào “Chưa gán hũ”; người dùng vẫn sửa danh mục được trong màn Ví.
- `GET /finance/monthly-finances/me/history` chưa có; biểu đồ member còn phải loop từng tháng.
- `authProviders` và `linkedExistingAccount` chưa có trong `/auth/me` hoặc `/auth/firebase`, nên FE chưa thể hiển thị chính xác trạng thái “Đăng nhập bằng Google/Mật khẩu”.
