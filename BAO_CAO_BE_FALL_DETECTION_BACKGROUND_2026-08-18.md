# Báo cáo & xin confirm hướng giải quyết — Fall Detection phải tự chạy khi app background/khoá máy

Ngày: **2026-08-18** · Người soạn: FE Mobile · đối chiếu trên `main` (= `origin/main` = `origin/NDuy`, commit `adf72ea`)
Gửi: Backend, Leader
Mục đích: **confirm hướng kỹ thuật trước khi FE code**, không phải xin thêm việc cho BE — hầu hết phần sửa nằm ở Android native. Chỉ có 1 điểm (Yêu cầu #1) cần BE xác nhận.

---

## Phần 1 — Vấn đề

### Hiện tượng người dùng thấy được

Tính năng "Tự tạo cảnh báo SOS khi phát hiện té ngã" (`autoCreateAlertFromFall`) hoạt động đúng khi app đang mở. Nhưng khi app ở nền hoặc màn hình khoá:

- Cảm biến **vẫn phát hiện được cú ngã** — có bằng chứng: notification cảnh báo vẫn hiện ra khi thả rơi máy lúc app background.
- Nhưng **luồng SOS không tự chạy tiếp**. Người dùng phải tự mở lại app thì countdown mới bắt đầu chạy tiếp / SOS mới được gửi.

Với tính năng khẩn cấp, yêu cầu "phải tự mở app" là sai nghiệp vụ — người ngã bất tỉnh thì không ai mở app giúp họ.

### Nguyên nhân đã xác định (đọc code thật, không đoán)

App hiện có **2 đường phát hiện té ngã độc lập nhau**:

**Đường 1 — Dart, chỉ chạy foreground (`lib/navigation/family_shell.dart` + `lib/services/fall_detector_service.dart`)**

```dart
// family_shell.dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  _appInForeground = state == AppLifecycleState.resumed;
  if (!_appInForeground) FallDetectorService.instance.stop(); // tắt hẳn khi rời foreground
  ...
}

Future<void> _onFallDetected() async {
  ...
  final send = await showFallCountdownDialog(context); // cần BuildContext + UI sống
  ...
  await sos.sendSos(...);
}
```

Đường này tắt cảm biến ngay khi app rời `resumed`, và toàn bộ countdown dựa vào `showDialog(context)`. Đây rõ ràng không phải nguồn phát hiện được lúc app background — khớp với hiện tượng người dùng thấy (nếu chỉ có đường này thì sẽ *không* có notification nào cả lúc background).

**Đường 2 — Android native, có chạy khi background/khoá máy (`SosGuardService.kt` + `FallDetector.kt`)**

`SosGuardService` là foreground service, dùng wake-up sensor + `PARTIAL_WAKE_LOCK` để cảm biến không bị hệ điều hành đình lại khi màn khoá — **đây là lý do notification vẫn hiện được lúc thả máy dù app background**. Cảm biến không phải vấn đề.

Nhưng khi phát hiện té ngã (`fallDetector.addSample()` trả `true`), service chỉ làm một việc:

```kotlin
// SosGuardService.kt
SosAlertLauncher.launch(this, "sos-quick")
```

`SosAlertLauncher` bắn 1 **full-screen-intent notification** để mở Activity tới route `/sos-quick` → `SOSScreen(autoTrigger: true)` (Dart). Từ điểm này, **toàn bộ countdown → lấy GPS → gọi API gửi SOS lại chạy trong Flutter UI**, y hệt đường 1.

→ **Root cause thật sự:** cảm biến chạy nền tốt, nhưng quyết định "có gửi SOS hay không" và cách gửi vẫn phụ thuộc 100% vào việc Activity/Flutter engine thực sự mở lên và chạy trọn vẹn. Full-screen-intent có thể bị một số OEM chặn background-activity-launch, có thể chưa được cấp quyền (`Notification full-screen intent` — từ Android 14 phải người dùng tự cấp thủ công), hoặc Activity mở ra nhưng bị hệ thống giết giữa chừng lúc màn khoá → không có gì tự gửi SOS.

---

## Phần 2 — Hướng giải quyết FE dự định làm

**Chuyển toàn bộ "fall detected → countdown → lấy GPS → gửi SOS" vào bên trong `SosGuardService.kt`**, biến nó thành state machine tự chạy, không phụ thuộc Activity/Flutter engine:

1. **Bỏ/không dùng đường Dart `FallDetectorService` trong `FamilyShell` (mobile) cho emergency flow.** Giữ nguyên class Dart — `lib/wear/screens/wear_sensor_sos_screen.dart` và `lib/wear/screens/wear_status_screen.dart` (Wear OS) cũng như test hiện có (`test/fall_detection_test.dart`) còn dùng, không xoá file. Không đụng ngưỡng/thuật toán `FallDetector.kt` (native) — cảm biến đang đúng, không phải chỗ cần sửa.
2. **Cần một session snapshot riêng cho native đọc độc lập với Flutter engine.** Hiện JWT được Flutter quản lý qua `ApiClient` + `FlutterSecureStorage`; native (Kotlin) chưa có cách đọc trực tiếp, ổn định vào kho đó. Dự kiến: thêm `MethodChannel` để mỗi khi `AuthProvider` set/refresh/xoá token, đẩy `accessToken` + `familyId` + `userId` sang một kho lưu riêng cho native (dự kiến `EncryptedSharedPreferences`, cần thêm dependency Gradle `androidx.security:security-crypto` — **hiện chưa có trong `android/app/build.gradle`**).
3. **Trong `SosGuardService.kt`, khi phát hiện té ngã (`fall == true`, tách khỏi nhánh `shake`):**
   - Không mở Activity nữa. Dựng notification cảnh báo có 2 nút hành động (**"Tôi ổn"** / **"Gửi SOS ngay"**) dùng `PendingIntent.getBroadcast()` → `BroadcastReceiver`, **không** `getActivity()`.
   - Chạy countdown ngay trong service (giữ wake lock sẵn có), cập nhật số giây lên nội dung notification.
   - Bấm "Tôi ổn" → huỷ, không gửi gì.
   - Hết countdown không phản hồi, hoặc bấm "Gửi SOS ngay" → lấy GPS (dự kiến `FusedLocationProviderClient`, cần thêm dependency Gradle `com.google.android.gms:play-services-location` — **hiện chưa có**) → gọi thẳng `POST /families/{familyId}/sos/alerts` bằng HTTP client thuần Kotlin (dùng token đã đồng bộ ở bước 2).
   - Notification lúc này **chỉ để hiển thị**, không phải điều kiện để SOS chạy tiếp — countdown/gửi vẫn tự chạy dù người dùng không đụng vào notification.
   - **Chống trùng:** hiện `onSensorChanged` xử lý `shake || fall` trong cùng 1 nhánh, cùng gọi `SosAlertLauncher.launch(this, "sos-quick")`. Sau khi tách, dự kiến đổi thành `if (fall) chạy state machine native ở trên; else if (shake) giữ nguyên SosAlertLauncher.launch("sos-quick")`. State machine native cũng cần khoá/cooldown riêng (đang có `cooldownMs` ở `FallDetector.kt`, nhưng cần thêm cờ chặn không cho 1 cú ngã tạo nhiều countdown/nhiều request nếu sensor bắn `fall = true` liên tiếp trong lúc countdown đang chạy).
   - **Manifest cần bổ sung nếu native tự lấy GPS trong foreground service:** hiện `AndroidManifest.xml` mới có `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` + `FOREGROUND_SERVICE_SPECIAL_USE`, **chưa có** `FOREGROUND_SERVICE_LOCATION` và chưa khai `foregroundServiceType` gồm `location`. Cần thêm và kiểm lại hành vi Android 10+ về background location access trước khi merge.
4. Log đủ 6 bước để test được rõ ràng: `1. Fall detected` → `2. Countdown started` → `3. Countdown finished` → `4. Resolving GPS` → `5. Sending SOS` → `6. SOS API response`.
5. Flutter vẫn biết SOS đã được tạo qua kênh cũ đã có sẵn (poll + realtime Socket.IO `/sos`) khi app mở lại — không cần đường riêng.

**Phạm vi không đổi trong đợt này:** `EmergencySosWatcherService.kt` (bám theo màn Emergency SOS hệ thống, dành riêng Oppo/Realme/OnePlus) hiện **vẫn** gọi `SosAlertLauncher.launch(this, "sos-immediate")` rồi mở Flutter `SOSScreen(immediate: true)` — tức vẫn đi qua Flutter route, có cùng rủi ro phụ thuộc Activity như fall detection trước khi sửa. Báo cáo này **chỉ xử lý fall detection trước**; Emergency SOS hệ thống chưa đổi flow, sẽ đánh giá riêng sau nếu cần.

---

## Phần 3 — Câu hỏi cần BE xác nhận (chỉ 1 điểm, đã hỏi và treo từ báo cáo `DE_XUAT_BE_SOS_FALL_DETECTION_2026-08-04.md`)

### Yêu cầu #1 — `sourceType`/`triggerReason` cho SOS tự động — vẫn đang treo, cần chốt trước khi code phần native

Báo cáo trước (2026-08-04) đã nêu: `CreateSosAlertDto.sourceType` hiện chỉ có `MOBILE_APP | WEARABLE | SIMULATED_DEVICE`, không có giá trị nào phân biệt "người tự bấm" với "máy tự phát hiện té ngã". FE đang tạm gửi `MOBILE_APP` + ghi chú vào `message`.

**Vì sao hỏi lại lần này:** trước đây countdown/gửi SOS chạy trong Dart nên còn có thể vá tạm ở tầng UI (hiển thị theo `message`). Nếu chuyển hẳn sang native để chạy độc lập app, code build request SOS sẽ tồn tại ở **2 nơi** (Dart cho luồng thủ công, Kotlin cho luồng tự động) — càng cần chốt sớm để cả hai nơi cùng gửi đúng 1 kiểu dữ liệu, tránh lệch nhau ngay từ đầu thay vì phải sửa lại sau.

Xin BE chọn 1 trong 2, hoặc xác nhận giữ nguyên cách tạm:

```
(a) Thêm FALL_DETECTION vào enum sourceType:
    MOBILE_APP | WEARABLE | SIMULATED_DEVICE | FALL_DETECTION

(b) Thêm field riêng, ví dụ:
    triggerReason: MANUAL | FALL_DETECTION   (mặc định MANUAL)

(c) Giữ nguyên: FE tiếp tục gửi MOBILE_APP + ghi chú vào message,
    cả từ Dart lẫn từ Kotlin.
```

Nếu BE không có ý kiến trong đợt này, FE mặc định làm theo **(c)** để không chặn tiến độ, và giữ nguyên `[VERIFY]` trong `API_DOCS.md`.

---

## Phần 4 — Việc KHÔNG cần BE làm gì thêm (nói rõ để tránh hiểu nhầm phạm vi)

- Endpoint `POST /families/{familyId}/sos/alerts` đã đủ dùng, native sẽ gọi thẳng endpoint này giống hệt Dart đang gọi — không cần endpoint mới.
- Không cần BE đổi gì về push/socket cho SOS — kênh này đã được xác nhận hoạt động ở báo cáo 2026-08-04.
- Đồng bộ token xuống native (session snapshot riêng cho Kotlin), thêm dependency Gradle GPS/mã hoá, và bổ sung quyền `FOREGROUND_SERVICE_LOCATION` trong manifest đều là việc nội bộ FE, không phải API contract.

## Phần 5 — Kế hoạch test trước khi coi là xong

1. App đang mở → ngã → SOS gửi được (như hiện tại, không đổi hành vi).
2. App background (đã bấm Home, không tắt) → ngã → **tự gửi SOS**, không cần mở lại app.
3. Màn hình khoá → ngã → **tự gửi SOS**.
4. Không bấm vào notification cảnh báo → hết countdown → **vẫn tự gửi SOS**.

---

**Tóm tắt 1 dòng cho người bận:** cảm biến té ngã đã chạy tốt khi app nền/khoá máy, chỉ có bước gửi SOS đang bị buộc phải mở app mới chạy — FE dự kiến chuyển bước gửi đó vào Android native service có sẵn (`SosGuardService`), việc này cần thêm 2 dependency Gradle (GPS + mã hoá) và 1 quyền manifest mới, tất cả nội bộ FE; chỉ cần BE xác nhận 1 điểm về `sourceType`/`triggerReason` (Phần 3).
