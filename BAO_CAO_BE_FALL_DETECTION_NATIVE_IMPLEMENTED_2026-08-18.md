# Báo cáo BE — Đã chuyển flow phát hiện té ngã sang Android native

Ngày: 2026-08-18
Người soạn: FE Mobile · trạng thái đối chiếu trên `main`/`origin/main`/`origin/NDuy` commit `adf72ea`
Liên quan: `BAO_CAO_BE_FALL_DETECTION_BACKGROUND_2026-08-18.md` (phân tích nguyên nhân), contract `triggerReason` đã chốt qua trao đổi trực tiếp (phương án b, BE đồng ý).

## Tóm tắt

Đã implement xong phần FE theo hướng đã thống nhất: toàn bộ luồng "phát hiện
té ngã → đếm ngược → lấy GPS → gửi SOS" chuyển sang chạy trong một Android
foreground service (`SosEmergencyFlowService`), độc lập với Activity/Flutter
engine. Notification không còn là điều kiện phải mở app.

**Cập nhật 2026-08-18 (sau khi gửi báo cáo này): BE đã xác nhận payload FE
đang dùng đúng contract, và rule `triggerReason=FALL_DETECTION` bỏ qua
`locationRequired` đã được implement — thiếu GPS vẫn trả `201`, không còn
`400`. Điều kiện còn lại: BE phải deploy migration + server rule này lên
đúng môi trường FE test trước khi FE chạy case thiếu GPS, nếu không vẫn có
thể gặp `400` theo rule cũ trên môi trường chưa deploy.**

APK release + `gradlew testDebugUnitTest` đã build/chạy pass sau báo cáo
này (sửa 1 lỗi import `CancellationTokenSource` phát hiện lúc build). Team
FE sẽ tự chạy 4 case thực tế trên thiết bị trước khi merge.

## Payload đã dùng đúng theo contract đã chốt

Fall detection (native, không kèm GPS khi timeout/fail):

```json
{
  "sourceType": "MOBILE_APP",
  "triggerReason": "FALL_DETECTION",
  "severity": "HIGH",
  "message": "Tự động tạo SOS do phát hiện té ngã — không lấy được vị trí ban đầu"
}
```

Fall detection (có GPS trong 5-6s):

```json
{
  "sourceType": "MOBILE_APP",
  "triggerReason": "FALL_DETECTION",
  "severity": "HIGH",
  "initialLatitude": ...,
  "initialLongitude": ...,
  "message": "Tự động tạo SOS do phát hiện té ngã"
}
```

Manual (nút SOS thủ công, hành vi giữ nguyên — chỉ thêm field tường minh):

```json
{
  "sourceType": "MOBILE_APP",
  "triggerReason": "MANUAL",
  "message": "..."
}
```

## Kiến trúc mới

```
SosGuardService (cảm biến, đã chạy nền từ trước)
  └─ fall event
       └─ SosEmergencyFlowService.start()   [MỚI — foreground service riêng]
            1. Fall detected            (log)
            2. Countdown started (10s)  — notification, action "Tôi ổn" / "Gửi SOS ngay"
            3. Countdown finished
            4. Resolving GPS             — FusedLocationProviderClient, timeout 6s
            5. Sending SOS               — POST /families/{familyId}/sos/alerts
            6. SOS API response
                 └─ nếu thiếu GPS lúc gửi: sau 15s thử lại 1 lần, vá bằng
                    POST /families/{familyId}/sos/alerts/{alertId}/locations
```

Notification action ("Tôi ổn" / "Gửi SOS ngay") xử lý bằng
`PendingIntent.getBroadcast()` → `SosFallActionReceiver` → forward action cho
service — **không mở `MainActivity`**, không cần Flutter engine sống.

State machine chống trùng trong `SosEmergencyFlowService`:
`idle → countingDown → sending → sent/failed/canceled`. Fall event mới đến
khi đang `countingDown`/`sending` bị bỏ qua.

`shake` (lắc mạnh) **giữ nguyên đường cũ** (`/sos-quick`, mở Flutter, đếm
ngược 3s) — chỉ `fall` (té ngã) chuyển sang native, vì lắc thường xảy ra lúc
đang cầm máy (còn thao tác được), khác với té ngã (có thể bất tỉnh).

## Session cho native — cách lấy JWT khi Flutter engine không sống

`SosEmergencyFlowService` không đọc được `ApiClient` (Dart). Giải pháp: mỗi
khi Flutter set token/familyId (login, refresh, restore session), gọi
MethodChannel `com.familycare.family_care/native_session` → `TokenCache.kt`
lưu access token + familyId + base URL vào `EncryptedSharedPreferences` riêng
của native (không dùng chung keystore của `flutter_secure_storage`, không có
API chính thức để đọc trực tiếp).

- Chỉ cache **access token**, không cache refresh token.
- Access token sống 15 phút. Nếu app bị kill quá lâu trước khi ngã, cache có
  thể hết hạn → native nhận 401, ghi log bước 6 kèm mã lỗi, không tự refresh.
  **Đây là rủi ro còn tồn tại, chưa có giải pháp** — nếu BE có phương án cấp
  token sống lâu hơn riêng cho luồng khẩn cấp, FE sẵn sàng trao đổi thêm.
- `clearSession()` (logout) xoá cache native ngay, tránh máy dùng chung gia
  đình bị gửi SOS nhầm tên người trước.

## File đã sửa/thêm (Android native)

- **Mới** `android/.../SosEmergencyFlowService.kt` — foreground service chính,
  `foregroundServiceType="location"`.
- **Mới** `android/.../SosFallActionReceiver.kt` — BroadcastReceiver cho 2 action.
- **Mới** `android/.../TokenCache.kt` — EncryptedSharedPreferences.
- Sửa `SosGuardService.kt` — tách `fall` sang `SosEmergencyFlowService`, giữ
  `shake` như cũ.
- Sửa `MainActivity.kt` — thêm MethodChannel `native_session`
  (`cacheSession`/`clearSession`).
- Sửa `AndroidManifest.xml` — thêm quyền `FOREGROUND_SERVICE_LOCATION`, khai
  2 component mới.
- Sửa `build.gradle.kts` — thêm dependency
  `com.google.android.gms:play-services-location:21.3.0`,
  `androidx.security:security-crypto:1.1.0-alpha06`.

## File đã sửa (Flutter/Dart)

- **Mới** `lib/services/native_session_bridge.dart` — gọi MethodChannel trên.
- Sửa `lib/services/api_client.dart` — `setToken`/`setFamilyId` tự đồng bộ
  xuống native; `clearSession()` xoá cache native.
- Sửa `lib/providers/sos_provider.dart` — `sendSos()` thêm tham số
  `triggerReason` (default `MANUAL`, truyền tường minh).
- Sửa `lib/navigation/family_shell.dart` — luồng phát hiện té ngã **foreground**
  (`FallDetectorService` Dart, dùng khi app đang mở) gửi `triggerReason:
  'FALL_DETECTION'` thay vì ghi nguồn vào `message` như trước.
- Cập nhật `API_DOCS.md` — field `triggerReason` trong `CreateSosAlertDto`.

**Không đổi** `lib/services/fall_detector_service.dart` (Dart) — vẫn dùng cho
Wear OS (`wear_sensor_sos_screen.dart`, `wear_status_screen.dart`) và cho
luồng foreground-only trên điện thoại (`family_shell.dart`), không liên quan
tới bug nền đã sửa.

## Đã chạy

- `flutter analyze --no-fatal-infos`: 0 error, chỉ info lint cũ + 1 info mới
  không đáng kể (`empty_catches` ở `native_session_bridge.dart`, cố ý — không
  chặn Flutter nếu native chưa build lại).

## Chưa làm / cần làm tiếp

1. **Chưa build APK thật và test trên thiết bị** — cần build lại (dependency
   mới) rồi chạy đủ 4 case:
   - App đang mở → ngã → SOS
   - App background → ngã → tự SOS
   - Lock screen → ngã → tự SOS
   - Không bấm notification → hết countdown vẫn tự SOS
2. ~~Xác nhận với BE: rule `triggerReason=FALL_DETECTION` bỏ qua
   `locationRequired`~~ — **BE đã xác nhận payload đúng contract và rule đã
   implement (2026-08-18)**. Còn lại: xác nhận rule đã **deploy lên đúng môi
   trường FE test** trước khi chạy case thiếu GPS, tránh gặp `400` theo rule
   cũ trên môi trường chưa deploy.
3. Chưa viết unit test Kotlin cho state machine/countdown của
   `SosEmergencyFlowService` (mẫu có sẵn: `FallDetectorTest.kt`).
4. Chưa commit — theo yêu cầu, phần commit/test làm sau khi review lại toàn
   bộ thay đổi.
5. Rủi ro token hết hạn khi app bị kill quá lâu (nêu ở mục "Session cho
   native") vẫn còn treo, chưa có giải pháp — cần bạn cân nhắc thêm.
