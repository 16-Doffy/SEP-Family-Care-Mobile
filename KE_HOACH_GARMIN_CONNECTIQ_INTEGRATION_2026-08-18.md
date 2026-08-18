# Garmin Connect IQ Android SDK — Tích hợp bridge FE

Ngày: 2026-08-18
Trạng thái: **Đã code xong, build/compile/test pass trên máy dev. CHƯA test
thật với Garmin Connect Mobile + watch app thật.**

## Bối cảnh

Backend wearable/SOS đã có sẵn (`POST /families/{familyId}/wearables`,
`POST /families/{familyId}/wearables/{deviceId}/events`) — không cần BE đổi
gì cho đợt này. Garmin watch app (Monkey C, do team khác code) chỉ là sensor
source, không gọi backend trực tiếp. Family Care Android là bridge duy nhất
giữa watch app và backend, qua **Garmin Connect IQ Mobile SDK** (giao tiếp
qua Garmin Connect Mobile, không phải BLE trực tiếp).

## Kiến trúc đã chọn

Giống tinh thần Fall Detection native (`SosEmergencyFlowService`,
`BAO_CAO_BE_FALL_DETECTION_NATIVE_IMPLEMENTED_2026-08-18.md`): fall detection
từ Garmin **phải** tự gửi được sự kiện lên backend kể cả khi app Family Care
đang nền hoặc bị kill — quyết định đã chốt qua trao đổi trực tiếp.

```
Garmin watch app (Monkey C, KHÔNG gọi backend)
  <-> Garmin Connect Mobile (bắt buộc cài, là kênh giao tiếp thật)
       <-> GarminBridgeService (Android, foreground service riêng,
            độc lập Activity/Flutter engine — sở hữu DUY NHẤT
            ConnectIQ SDK singleton)
            - onSdkReady: đăng ký lại listener cho watch đã pair
              (GarminDeviceCache, sống qua reboot/kill)
            - nhận PAIR_CONFIRMED gửi đi lúc pair
            - nhận FALL_DETECTED -> POST
              /families/{familyId}/wearables/{deviceId}/events
              dùng JWT cache trong TokenCache (TÁI DÙNG từ đợt Fall
              Detection native, không tạo cơ chế lưu token mới)
            <-- bind -->
       MainActivity (MethodChannel "com.familycare.family_care/garmin")
            - getKnownDevices, confirmPair, stopBridge
                <-- MethodChannel -->
       GarminBridge (lib/services/garmin_bridge.dart)
            <-- gọi từ -->
       WearablesScreen (nút "Ghép đồng hồ Garmin")
            - dùng LẠI API pair/event có sẵn qua WearableProvider
              (pairDevice, không có endpoint riêng cho Garmin)
```

## Payload đã dùng đúng theo mô tả

Pair (`confirmPair` -> watch), gửi bằng `ConnectIQ.sendMessage` dạng Map, KHÔNG
phải JSON string thô (SDK tự serialize Dictionary):

```
{ "type": "PAIR_CONFIRMED", "deviceId": "<backendDeviceId>", "memberName": "<tên thành viên>" }
```

Fall detected (nhận từ watch, forward `rawValue` gần như nguyên văn vào
`CreateSensorEventDto` đã có sẵn — không map lại field):

```json
POST /families/{familyId}/wearables/{deviceId}/events
{
  "eventType": "FALL_DETECTED",
  "severity": "HIGH",
  "rawValue": {
    "source": "garmin_fr735xt",
    "deviceIdentifier": "...",
    "magnitude": ..., "x": ..., "y": ..., "z": ...,
    "freeFallMs": ..., "impactMagnitude": ..., "stillSeconds": ..., "detectedAt": ...
  }
}
```

## File đã thêm/sửa

**Android native:**
- Mới `GarminBridgeService.kt` — foreground service sở hữu ConnectIQ SDK
  singleton; bound (cho MainActivity gọi có callback) + started (sống sau khi
  Activity unbind — quan trọng để không bị hệ thống dọn giữa lúc app nền).
- Mới `GarminDeviceCache.kt` — EncryptedSharedPreferences nhớ IQDevice đã pair
  (khác vòng đời `TokenCache`: theo thiết bị, không theo phiên đăng nhập).
- Sửa `MainActivity.kt` — bind/unbind `GarminBridgeService` theo vòng đời
  Activity (`onStart`/`onStop`), tự `GarminBridgeService.start()` trong
  `onCreate()` nếu đã có thiết bị Garmin cached (mở app sau khi bị kill vẫn
  chạy bridge nền), thêm `MethodChannel` `com.familycare.family_care/garmin`
  (`getKnownDevices`, `confirmPair`, `stopBridge`).
- Sửa `AndroidManifest.xml` — khai `GarminBridgeService`
  (`foregroundServiceType="connectedDevice"`) + quyền
  `FOREGROUND_SERVICE_CONNECTED_DEVICE` (bắt buộc Android 14+).
- Sửa `build.gradle.kts` — thêm
  `com.garmin.connectiq:ciq-companion-app-sdk:2.4.0@aar` (**có trên Maven
  Central, KHÔNG cần tải `.aar` thủ công** — đã verify `mavenCentral()` có
  sẵn trong `settings.gradle.kts`, build thật đã resolve được dependency này).

**Flutter/Dart:**
- Mới `lib/services/garmin_bridge.dart` — wrapper `MethodChannel`, model
  `GarminIqDevice`.
- Sửa `lib/screens/shared/wearables_screen.dart` — nút "Ghép đồng hồ Garmin"
  trong `_notConnectedCard`, flow: liệt kê thiết bị Garmin đã pair với Garmin
  Connect Mobile → (nếu >1) cho chọn → nhập mã watch app (`FCG-735XT-XXXXXX`)
  → `WearableProvider.pairDevice()` (API có sẵn, không đổi) →
  `GarminBridge.confirmPair()`. Gọi `GarminBridge.stopBridge()` khi ngắt kết
  nối (`_confirmUnpair`).

## App UUID

`GARMIN_APP_UUID = "b15c3d2e-6f42-4c2b-8f8d-4a8e0f0f735a"` (hardcode trong
`GarminBridgeService.kt`, theo giá trị team Garmin watch app cung cấp, khai
trong `garmin/watch-app/manifest.xml` phía họ). **Phải khớp chính xác** — sai
UUID thì `registerForAppEvents` không bao giờ nhận được message.

## Đã verify được (không cần thiết bị Garmin thật)

- `flutter analyze --no-fatal-infos`: 0 error (25 info lint cũ, không liên
  quan file mới).
- `flutter test`: 510/510 pass.
- `./gradlew :app:compileDebugKotlin`: **BUILD SUCCESSFUL** — xác nhận
  dependency Maven Central resolve được và API `com.garmin.connectiq.*` dùng
  đúng (class/method: `ConnectIQ.getInstance`, `.initialize`,
  `.knownDevices`, `.registerForDeviceEvents`, `.registerForAppEvents`,
  `.sendMessage`, `IQDevice`, `IQApp` — đối chiếu trực tiếp với sample chính
  thức `garmin/connectiq-android-sdk` "Comm Android" trên GitHub, không đoán
  API).
- `./gradlew :app:testDebugUnitTest`: BUILD SUCCESSFUL.

## CHƯA làm / CHƯA verify được (cần thiết bị thật)

1. **Chưa test thật** với Garmin Connect Mobile cài trên máy + Garmin
   Forerunner 735XT + watch app "Family Care Garmin" thật. Không có cách nào
   verify các hành vi runtime của SDK (pairing qua Connect Mobile, format
   Dictionary thật watch gửi, timing `onSdkReady`) mà không có phần cứng.
2. **Package visibility (Android 11+)**: chưa thêm `<queries>` cho
   `com.garmin.android.apps.connectmobile` — theo docs Garmin, SDK AAR
   thường tự bundle khai báo này qua manifest merge, nhưng CHƯA verify được
   trên máy thật. Nếu gặp `ServiceUnavailableException` dù đã cài Garmin
   Connect Mobile, đây là chỗ cần xem đầu tiên.
3. **Không tự khởi động lại sau khi điện thoại reboot** nếu người dùng không
   tự mở app — thiếu `BroadcastReceiver` cho `BOOT_COMPLETED`. Hiện chỉ tự
   chạy lại khi mở `MainActivity` (do `onCreate()` check
   `GarminDeviceCache`). Cân nhắc thêm receiver nếu team thấy cần thiết —
   chưa làm trong đợt này để giữ phạm vi gọn.
4. **Không có nút "Gửi lại xác nhận"**: nếu `pairDevice()` (backend) thành
   công nhưng `confirmPair()` (gửi `PAIR_CONFIRMED` xuống watch) thất bại
   (vd watch tắt lúc đó), UI chỉ báo lỗi rõ ràng chứ chưa có cách retry riêng
   — người dùng phải tự ngắt rồi ghép lại.
5. **Token hết hạn (15 phút)** nếu app bị kill lâu trước khi watch phát hiện
   té ngã — rủi ro giống hệt đã nêu ở Fall Detection native, chưa có giải
   pháp (dùng chung `TokenCache`).
6. Chưa viết unit test Kotlin cho `GarminBridgeService`/`GarminDeviceCache`.
7. Chưa commit.

## Việc cần từ team Garmin watch app (Monkey C)

- Xác nhận watch app gửi Dictionary đúng field/kiểu dữ liệu như mô tả (số là
  `Number`, không phải `String`) — Android nhận `message.first()` dạng
  `Map<*, *>`, sai kiểu sẽ khiến `payload["magnitude"] as? Number` trả `null`
  âm thầm thay vì lỗi rõ ràng.
- Xác nhận UUID `b15c3d2e-6f42-4c2b-8f8d-4a8e0f0f735a` là bản mới nhất, không
  đổi khi họ build lại watch app.
