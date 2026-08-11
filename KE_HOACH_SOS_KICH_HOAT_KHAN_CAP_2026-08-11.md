# Kế hoạch build — Kích hoạt SOS khi không mở được app

**Ngày lập:** 2026-08-11 · **Người lập:** phiên Claude Code (nhánh `giap`) · **Người thực hiện:** Codex
**Trạng thái repo lúc lập kế hoạch:** `origin/giap` = `55ac2bb`, `flutter test` 440/440 pass,
`flutter analyze --no-fatal-infos` 0 error.

> ### ⚠️ ĐỌC MỤC 1 TRƯỚC — có **hai** cơ chế, đã đo thực tế trên máy Oppo
> Yêu cầu gốc "bấm nút nguồn 5 lần" **làm được**, nhưng **không phải bằng cách tự đếm** — mà bằng
> cách **bám theo app SOS của hệ điều hành**. Đã đo bằng `adb logcat` trên OPPO CPH2159 / Android 13
> ngày 11/08, số liệu thật ở mục 1.3.
>
> - **Cơ chế A — Lắc mạnh:** chạy trên mọi máy, không cần quyền đặc biệt. **Làm trước.**
> - **Cơ chế B — Bám theo Emergency SOS hệ thống:** cho đúng trải nghiệm "bấm nguồn 5 lần", nhưng
>   phụ thuộc hãng máy và cần quyền đặc biệt. **Làm sau, tùy chọn.**
>
> Cả hai dùng chung một foreground service.

---

## 0. Bối cảnh và mục tiêu

**Vấn đề người dùng nêu:** người đang trong tình huống khẩn cấp thật sự có thể **không mở nổi điện
thoại, không mở nổi app**. Cần một cách kích hoạt SOS không đòi hỏi nhìn màn hình và thao tác chính xác.

**Đã có sẵn (làm ngày 11/08, đã push):**
- Route phẳng **`/sos-quick`** → `SOSScreen(autoTrigger: true)`: tự đếm ngược **3 giây** rồi gửi SOS,
  có nút **HỦY** to. **Dùng lại nguyên vẹn**, không sửa.
- Lối tắt màn hình chính (`res/xml/shortcuts.xml`) → deep link `familycare://app/sos-quick`.
- `SosProvider.sendSos()` + stream vị trí + buffer offline đã chạy ổn định.
- `FallDetectorService` — máy trạng thái thuần, đã test kỹ (`test/fall_detection_test.dart`),
  **nhưng chỉ chạy khi app đang mở** (giới hạn ghi rõ ở `fall_detector_service.dart:33-35`).

**Mục tiêu:** kích hoạt SOS được **khi màn hình đang tắt/khóa và app đã đóng**, bằng thao tác thô
không cần nhìn.

**Ngoài phạm vi:** iOS (repo chưa có thư mục `ios/`); Wear OS (đồng hồ đã có nút SOS riêng).

---

## 1. "Bấm nút nguồn 5 lần" — làm được, nhưng phải đổi cách nghĩ

### 1.1 Vì sao KHÔNG tự đếm số lần bấm

Thử trên **OPPO CPH2159 / Android 13 (ColorOS)** ngày 11/08: bấm nút nguồn 5 lần → **hệ điều hành
mở màn Emergency SOS riêng của nó**, kèm 3 số khẩn cấp **113 / 115 / 114**.

Cử chỉ này **đã bị hệ thống chiếm**. Kể cả app đếm đủ 5 lần rồi bắn full-screen intent, màn SOS của
app vẫn phải tranh chỗ với màn khẩn cấp hệ thống — **system UI luôn thắng**. Người dùng nhìn thấy
bảng quay số của máy, còn đếm ngược của app bị che: **tệ hơn cả không làm gì**, vì họ tưởng app đã
gửi mà thực ra chưa.

> Ghi chú: đo log cho thấy nút nguồn **vẫn** tạo chu kỳ bật/tắt màn hình bình thường
> (`Going to sleep due to power_button` → `Waking up ... WAKE_REASON_POWER_BUTTON`), nên **về kỹ
> thuật** cách đếm `ACTION_SCREEN_ON/OFF` chạy được. Loại nó là vì **va chạm giao diện**, không phải
> vì không đếm được.

### 1.2 Cách đúng: đừng tranh với hệ thống, hãy bám theo nó

Thay vì tự đếm, **phát hiện đúng lúc màn Emergency SOS của hệ thống bật lên** rồi gửi cảnh báo cho
gia đình. Hệ thống lo phần gọi 113/115/114, app lo phần báo người thân — **hai việc bổ sung nhau**.

### 1.3 Số liệu đo được (OPPO CPH2159, Android 13, ngày 11/08)

**Luồng thật gồm 2 activity**, khởi động bởi chính hệ thống (uid 1000):

```
START u0 {act=oplus.intent.action.LAUNCH_SOS_HELPER
          cmp=com.oplus.sos/.ui.LaunchEmergencyCallActivity  mCallingUid=1000} from uid 1000
START u0 {cmp=com.oplus.sos/.ui.EmergencyCallDetailActivity  mCallingUid=10114} from uid 10114
```

Activity thứ hai xuất hiện **~93 ms** sau activity thứ nhất.

**Xác nhận hoạt động cả khi MÁY ĐANG KHÓA** — đây là điều kiện then chốt vì tình huống thật là máy
khóa để trong túi:

```
onKeyguardStateChanged: isShowing:true secure:true     ← máy thật sự đang khóa
Changing focus from null to Window{... com.oplus.sos/...EmergencyCallDetailActivity}
```

**Kết luận đo được:**

| Điều cần biết | Kết quả |
|---|---|
| Màn SOS là Activity hay lớp phủ? | **Activity thật**, chiếm focus, nằm trong task stack → **quan sát được** |
| Có chạy khi máy khóa không? | **Có**, `keyguard isShowing:true secure:true` |
| Package | `com.oplus.sos` |
| Class | `.ui.LaunchEmergencyCallActivity` → `.ui.EmergencyCallDetailActivity` |
| Hệ thống có bắn **thông báo** không? | **KHÔNG** — đã grep log, trống hoàn toàn |
| Có chặn được bằng `intent-filter` không? | **KHÔNG** — là lệnh gọi component **tường minh** (`cmp=...`) |

### 1.4 Còn đúng 2 cách bắt tín hiệu

Vì không có thông báo và không chặn được intent, chỉ còn:

| Cách | Cơ chế | Ưu | Nhược |
|---|---|---|---|
| **`AccessibilityService`** | Nhận `TYPE_WINDOW_STATE_CHANGED`, lọc `packageName == "com.oplus.sos"` | **Tức thì**, hướng sự kiện nên **không tốn pin** khi rảnh | Màn xin quyền ghi *"toàn quyền kiểm soát thiết bị"* — đáng sợ với người già. Google Play hạn chế gắt (đồ án phát APK trực tiếp nên không vướng) |
| **`UsageStatsManager`** | Poll `queryEvents()` tìm `ACTIVITY_RESUMED` của `com.oplus.sos` | Quyền **đỡ đáng sợ hơn**, không dính tiếng xấu accessibility | Phải **poll liên tục** → tốn pin; trễ ~1 giây; dữ liệu có thể bị gom lô |

**Khuyến nghị: `AccessibilityService`.** Đây là tính năng khẩn cấp nên độ trễ quan trọng, và hướng
sự kiện thì không tốn pin khi không có gì xảy ra — ngược hẳn với poll mỗi giây suốt ngày.

### 1.5 Đã cân nhắc và loại

| Cách | Vì sao loại |
|---|---|
| **Tự đếm `SCREEN_ON/OFF`** | Đếm được nhưng va chạm giao diện với màn SOS hệ thống — xem 1.1 |
| **`NotificationListenerService`** | Đã đo: hệ thống **không bắn thông báo nào** khi kích hoạt SOS |
| **`intent-filter` bắt `LAUNCH_SOS_HELPER`** | Đã đo: gọi component tường minh, không qua phân giải intent |
| Bảo người dùng **tắt Emergency SOS** của máy | Bắt tắt một tính năng an toàn để dùng tính năng an toàn khác. Vô lý, và giải thích trước hội đồng rất dở |
| Đổi sang **4 hoặc 6 lần bấm** | Người dùng bấm 5 lần theo phản xạ vẫn kích hoạt hệ thống. Mỗi hãng đặt ngưỡng khác nhau |
| `AccessibilityService.onKeyEvent()` | Hệ thống lọc phím nguồn **trước** khi phân phối cho accessibility. Chỉ dùng được sự kiện **cửa sổ**, không dùng được sự kiện **phím** |
| Phím âm lượng | Không nhận được sự kiện khi màn hình tắt/khóa |
| Nút tai nghe (`MediaSession`) | Chạy được cả khi khóa máy, nhưng **phải cắm tai nghe** — không hợp người cao tuổi |

### 1.6 Giới hạn lớn nhất của cơ chế B: phụ thuộc hãng máy

`com.oplus.sos` là của **OPPO / OnePlus / Realme** (nhóm OPlus). Samsung, Xiaomi, máy Android gốc
dùng package **khác hoàn toàn**, chưa đo.

→ Phải viết dạng **danh sách package cấu hình được**, không hardcode một chuỗi. Khởi điểm:

```kotlin
val EMERGENCY_PACKAGES = setOf(
    "com.oplus.sos",        // OPPO / OnePlus / Realme — ĐÃ ĐO XÁC NHẬN 11/08
    // Dưới đây là PHỎNG ĐOÁN, chưa đo. Phải xác minh trước khi tin:
    "com.samsung.android.emergency",
    "com.android.emergency",     // Android gốc
)
```

**Không được ghi trong tài liệu là "chạy trên mọi máy Android".** Chỉ khẳng định đúng máy đã đo.

### 1.4 Điều này làm RÕ giá trị của app, không phải làm yếu đi

Emergency SOS của máy chỉ **gọi cơ quan chức năng**. Nó **không báo cho gia đình** và **không chia
sẻ vị trí trực tiếp** cho người thân.

→ Đây chính là câu trả lời nếu hội đồng hỏi *"sao không dùng luôn SOS có sẵn của điện thoại?"*.
Hai thứ **bổ sung cho nhau**, không thay thế nhau. Nên ghi ý này vào tài liệu bảo vệ.

---

## 2. Cơ chế A: LẮC MẠNH điện thoại — làm trước

### 2.1 Vì sao là lắc

- **Không va chạm** với bất kỳ cử chỉ hệ thống nào.
- **Chạy được khi màn hình tắt/khóa** — gia tốc kế vẫn hoạt động trong foreground service.
- **Không cần nhìn màn hình, không cần thao tác chính xác** — đúng bài toán gốc.
- **Tái dùng hạ tầng đã có**: `sensors_plus` đã trong `pubspec.yaml`; `FallDetector` đã là máy trạng
  thái thuần test được, `ShakeDetector` làm theo đúng khuôn đó.

### 2.2 Phần thưởng kèm theo — sửa luôn một giới hạn đang tồn tại

`FallDetectorService` hiện **chỉ chạy khi app đang mở**. Nghĩa là cài đặt `autoCreateAlertFromFall`
(BE đã có, FE đã có toggle) **gần như vô dụng trong thực tế** — người ngã lúc để điện thoại trong
túi với app đã đóng thì không có gì xảy ra.

Có foreground service rồi thì **chuyển luôn `FallDetectorService` vào đó** → phát hiện té ngã chạy
cả khi app đóng. **Đây là giá trị lớn nhất của cả kế hoạch này**, lớn hơn bản thân tính năng lắc.

### 2.3 Bộ ba kích hoạt sau khi xong (dùng để trình bày lúc bảo vệ)

| Tình huống | Cơ chế | Cần thao tác? |
|---|---|---|
| Ngã, bất tỉnh, không cử động được | **Phát hiện té ngã** (chạy nền) | Không |
| Tỉnh nhưng không mở nổi máy | **Lắc mạnh** | Thao tác thô |
| Còn cầm và nhìn được máy | **Lối tắt màn hình chính** (đã xong) | 1 chạm |

---

## 3. Kiến trúc

```
[Lắc mạnh]  hoặc  [Té ngã]
      │
      ▼
 Gia tốc kế ──► ShakeDetector / FallDetector (máy trạng thái thuần)
                          │
                          ▼
              SosGuardService (foreground service, Kotlin)
                          │
                          ▼
           Notification có setFullScreenIntent(...)
                          │
                          ▼
           MainActivity mở với familycare://app/sos-quick
           (showWhenLocked = true → hiện đè lên màn khóa)
                          │
                          ▼
           SOSScreen(autoTrigger: true) — ĐÃ CÓ SẴN
           đếm ngược 3 giây → SosProvider.sendSos()
```

### 3.1 Quyết định kiến trúc quan trọng: cảm biến chạy ở Kotlin hay Dart?

**Chọn: Kotlin.**

Lý do: khi người dùng vuốt tắt app khỏi đa nhiệm, Activity bị hủy và `FlutterEngine` có thể bị dọn,
nhưng **foreground service cùng tiến trình vẫn sống**. Nếu đặt bộ phát hiện ở Dart thì nó chết theo
engine — đúng vào tình huống cần nhất. Kotlin đọc `SensorManager` trực tiếp thì không phụ thuộc
engine.

**Hệ quả:** phải **viết lại thuật toán té ngã sang Kotlin**, không dùng lại được `FallDetector`
Dart. Chấp nhận được vì:
- Máy trạng thái chỉ ~60 dòng, đã có mô tả thuật toán rõ trong comment file Dart.
- **Giữ nguyên file Dart** để dùng cho lúc app đang mở (không xóa, không sửa) — tránh đụng vào thứ
  đang chạy ổn định sát ngày bảo vệ.
- Bản Kotlin có JVM test riêng, xem 4.2.

> ⚠️ **KHÔNG xóa `lib/services/fall_detector_service.dart` và `test/fall_detection_test.dart`.**
> Hai file này vẫn phục vụ luồng app đang mở và đang có test xanh.

---

## 4. Các bước thực hiện

> ⚠️ **Làm bước 4.0 TRƯỚC.** Nếu thất bại trên máy demo thì phần còn lại không có giá trị.

### 4.0 Spike đo thực tế (bắt buộc, làm đầu tiên)

**Mục đích:** xác nhận gia tốc kế **vẫn gửi dữ liệu khi màn hình tắt** trên máy demo (Oppo). Một số
máy tiết kiệm pin bằng cách giảm hoặc dừng hẳn cảm biến khi ngủ, hoặc chỉ giữ nếu có wakelock.

**Cách làm:**
1. Tạo nhánh `sos-shake` từ `giap`.
2. Viết tạm foreground service tối giản: đăng ký `SensorManager` với `TYPE_ACCELEROMETER`,
   `SENSOR_DELAY_GAME`, mỗi 50 mẫu ghi `Log.d("SOSSHAKE", ...)` kèm timestamp và độ lớn.
3. Chạy, **tắt màn hình**, để yên 2 phút rồi lắc mạnh vài lần.
4. `adb logcat -s SOSSHAKE` xem log có liên tục trong lúc màn tắt không, và biên độ lúc lắc là bao nhiêu.

**Ghi lại vào file này:** (a) log có liên tục khi màn tắt không, (b) độ lớn gia tốc đo được khi lắc
mạnh (dùng để đặt ngưỡng ở mục 6.1), (c) độ lớn khi đi bộ/để trong túi (để tránh báo nhầm).

**Nếu cảm biến bị dừng khi màn tắt:** dừng lại báo cáo. Cách chữa là giữ `PARTIAL_WAKE_LOCK`, nhưng
việc đó tốn pin đáng kể và phải cân nhắc lại toàn bộ.

### 4.1 Foreground service

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/SosGuardService.kt`

- `onCreate()`: tạo notification channel, `startForeground()`.
- Đăng ký `SensorManager` listener cho `TYPE_ACCELEROMETER`.
- `onStartCommand()` trả `START_STICKY`.
- `onDestroy()`: hủy đăng ký listener.
- Nhận cấu hình qua Intent extras: bật/tắt riêng phần **lắc** và phần **té ngã**.

Thông báo thường trực:
- Channel riêng, **`IMPORTANCE_LOW`** (nằm đó cả ngày, không được kêu/rung).
- Nội dung: tiêu đề **"Bảo vệ SOS đang bật"**, mô tả theo cấu hình thật, ví dụ
  *"Lắc mạnh để gửi cảnh báo"* hoặc *"Đang theo dõi té ngã"*.
- **Bắt buộc có action "Tắt"** để dừng ngay từ thanh thông báo. Không cho đường thoát là thiết kế
  tồi và chắc chắn bị hỏi lúc bảo vệ.

### 4.2 Hai bộ phát hiện — class thuần, test bằng JVM

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/ShakeDetector.kt`

Nhận timestamp qua tham số, **không** gọi `SystemClock` bên trong, để test được:

```kotlin
class ShakeDetector(
    private val threshold: Float = 25f,      // m/s², chỉnh theo spike 4.0
    private val requiredPeaks: Int = 4,      // số lần vượt ngưỡng
    private val windowMs: Long = 2000,
    private val cooldownMs: Long = 30_000,
) {
    private val peaks = ArrayDeque<Long>()
    private var lastTrigger = 0L
    private var above = false                // chống đếm nhiều lần trong 1 cú lắc

    /** Trả true đúng MỘT lần cho mỗi chuỗi lắc. */
    fun addSample(magnitude: Float, nowMs: Long): Boolean {
        if (lastTrigger != 0L && nowMs - lastTrigger < cooldownMs) return false

        // Chỉ tính 1 đỉnh cho mỗi lần vượt ngưỡng rồi tụt xuống lại.
        if (magnitude >= threshold) {
            if (!above) { above = true; peaks.addLast(nowMs) }
        } else if (magnitude < threshold * 0.6f) {
            above = false
        }

        while (peaks.isNotEmpty() && nowMs - peaks.first() > windowMs) peaks.removeFirst()

        if (peaks.size >= requiredPeaks) {
            peaks.clear(); above = false; lastTrigger = nowMs
            return true
        }
        return false
    }
}
```

> Điểm dễ sai: **có ngưỡng tụt xuống (`threshold * 0.6f`) mới cho đếm đỉnh tiếp theo**. Thiếu chỗ
> này thì một cú lắc duy nhất tạo hàng chục mẫu vượt ngưỡng và bắn ngay lập tức.

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/FallDetector.kt` — port thuật
toán **rơi tự do → va đập** từ `lib/services/fall_detector_service.dart`. Đọc kỹ comment và sơ đồ
ASCII trong file Dart đó, giữ nguyên ngưỡng: rơi tự do `< 3.0`, tối thiểu `100ms`, va đập `>= 25.0`,
cửa sổ va đập `900ms`, cooldown `30s`.

**JVM test bắt buộc** (`android/app/src/test/kotlin/.../`):

`ShakeDetectorTest`:
- Lắc đủ mạnh, đủ số đỉnh, trong cửa sổ → `true` **đúng 1 lần**.
- Một cú lắc duy nhất (nhiều mẫu liên tiếp vượt ngưỡng) → **không** bắn.
- Đủ số đỉnh nhưng rải quá cửa sổ → không bắn.
- Bắn xong lắc tiếp ngay → bị cooldown chặn.
- Chuỗi mẫu mô phỏng **đi bộ** (biên độ ~12-15) → không bắn.

`FallDetectorTest`: chép các ca từ `test/fall_detection_test.dart` sang để hai bản Dart/Kotlin không
lệch nhau.

> Repo **chưa có** thư mục test JVM cho Android. Thêm `testImplementation("junit:junit:4.13.2")` vào
> `android/app/build.gradle.kts` — dependency **chỉ dùng cho test**, không vào APK.

### 4.3 Mở màn SOS đè lên màn khóa

Đây là phần **khó nhất và dễ sai nhất**.

**Vấn đề:** Android 10+ chặn app khởi chạy Activity từ nền. Foreground service **không** tự động
được miễn trừ.

**Cách đúng (giống app báo thức / cuộc gọi đến):** notification có `setFullScreenIntent()`:

```kotlin
val intent = Intent(Intent.ACTION_VIEW, "familycare://app/sos-quick".toUri()).apply {
    setPackage(context.packageName)
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
}
val pi = PendingIntent.getActivity(
    context, 0, intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
)
val n = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
    .setSmallIcon(R.drawable.ic_shortcut_sos)   // đã có sẵn từ lối tắt SOS
    .setContentTitle("Đang gửi cảnh báo SOS")
    .setPriority(NotificationCompat.PRIORITY_HIGH)
    .setCategory(NotificationCompat.CATEGORY_ALARM)
    .setFullScreenIntent(pi, true)              // ← điểm mấu chốt
    .build()
```

Channel này phải **`IMPORTANCE_HIGH`**, **khác** channel của thông báo thường trực ở 4.1.

**Phía Activity** — `MainActivity.kt` thêm vào `onCreate()`:

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
    setShowWhenLocked(true)
    setTurnScreenOn(true)
}
```

> ⚠️ **Điểm Codex phải tự xác minh, đừng tin sẵn:** từ Android 14 (API 34), quyền
> `USE_FULL_SCREEN_INTENT` **chỉ tự cấp** cho app nhóm gọi điện/báo thức. App khác phải xin qua
> `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`. Dự án `targetSdk 36` nên **rất có thể phải xin**.
> Kiểm tra bằng `NotificationManager.canUseFullScreenIntent()`; `false` thì đưa người dùng sang màn
> cài đặt đó. **Bỏ qua chỗ này là tính năng chết im trên Android 14+.**

**Fallback bắt buộc** khi không có quyền: vẫn bắn notification `IMPORTANCE_HIGH` kèm action
**"MỞ SOS"**. Phải chạm một lần — kém hơn nhưng còn hơn không có gì.

### 4.4 Bật/tắt từ Dart

**File mới:** `lib/services/sos_guard_service.dart` — bọc `MethodChannel`
(`com.familycare.family_care/sos_guard`): `start({shake, fallDetection})`, `stop()`, `isRunning()`.

**File sửa:** `MainActivity.kt` — đăng ký `MethodChannel` handler.

**File sửa:** `lib/screens/shared/sos_settings_screen.dart` — thêm **2 công tắc**:
- *"Lắc mạnh để gửi SOS"*
- *"Phát hiện té ngã cả khi đóng app"* — nối với cài đặt `autoCreateAlertFromFall` đã có.

Kèm dòng giải thích về thông báo thường trực.

> ⚠️ Cài đặt **cục bộ trên máy** (`SharedPreferences`), **KHÔNG** đẩy lên BE.
> `UpdateSosSettingsDto` không có field nào cho việc này, và Rule 2 của repo cấm tự đoán/thêm field
> API. Muốn đồng bộ nhiều thiết bị thì viết đề xuất BE riêng.

### 4.5 Khởi động lại sau khi tắt/bật máy (tùy chọn)

`RECEIVE_BOOT_COMPLETED` + receiver bật lại service. **Nên làm nếu còn thời gian** — người già tắt
máy là mất tính năng mà không biết. **Không chặn demo.**

---

## 4B. Cơ chế B — bám theo Emergency SOS hệ thống (tùy chọn, làm sau cơ chế A)

> Chỉ làm sau khi cơ chế A đã chạy ổn. Đây là phần cho đúng trải nghiệm **"bấm nút nguồn 5 lần"**
> mà người dùng yêu cầu ban đầu. Số liệu đo ở mục 1.3.

### 4B.1 Accessibility service

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/EmergencyWatchService.kt`

```kotlin
class EmergencyWatchService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in EMERGENCY_PACKAGES) return
        // Chống bắn lặp: màn SOS hệ thống đổi focus nhiều lần liên tiếp
        // (đã thấy trong log: focus nhảy qua lại 4 lần trong ~1 giây).
        if (SystemClock.elapsedRealtime() - lastTrigger < COOLDOWN_MS) return
        lastTrigger = SystemClock.elapsedRealtime()
        SosGuardService.fireSos(this, reason = "system_emergency_sos")
    }
    override fun onInterrupt() {}
}
```

> ⚠️ **Chống bắn lặp là bắt buộc, không phải tối ưu.** Log đo được cho thấy focus của
> `EmergencyCallDetailActivity` **nhảy qua lại 4 lần trong khoảng 1 giây** (`Changing focus from ...
> to null` rồi ngược lại). Không chặn thì app gửi 4 cảnh báo SOS cho cùng một sự việc.

**File mới:** `android/app/src/main/res/xml/emergency_watch_config.xml`

```xml
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="false"
    android:description="@string/emergency_watch_description" />
```

> `canRetrieveWindowContent="false"` — ta **chỉ cần tên package**, không đọc nội dung màn hình. Khai
> đúng mức tối thiểu để màn xin quyền bớt đáng sợ và để trả lời được câu "app có đọc trộm màn hình
> không?" nếu hội đồng hỏi.

**Manifest:**

```xml
<service
    android:name=".EmergencyWatchService"
    android:exported="false"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/emergency_watch_config" />
</service>
```

### 4B.2 Hành vi khi phát hiện — KHÔNG hiện đếm ngược

Đây là điểm khác cơ chế A, và là lý do cơ chế B khả thi:

> **Gửi SOS NGAY**, rồi bắn thông báo `IMPORTANCE_HIGH`:
> **"Đã gửi cảnh báo cho gia đình — HỦY"**

Vì màn Emergency SOS của hệ thống đang chiếm màn hình, hiện đếm ngược cũng **không ai nhìn thấy**.
Mà bấm nguồn 5 lần thì ý định đã quá rõ, không cần hỏi lại.

Nút **HỦY** gọi `PATCH .../sos/alerts/{alertId}/cancel` mà BE đã có. Giữ thông báo ít nhất **60 giây**
để người bấm nhầm kịp thấy.

> Khác biệt quan trọng so với cơ chế A: cơ chế A hiện màn đếm ngược **trước khi** gửi; cơ chế B gửi
> trước rồi cho **hủy sau**. Hai luồng ngược nhau, đừng gộp code làm một.

> ### 🚫 KHÔNG được "thống nhất" cơ chế B thành có đếm ngược
>
> Sẽ có lúc thấy hai luồng ngược nhau là xấu và muốn sửa cho đồng bộ. **Đừng.** Ngoài lý do giao
> diện (màn hệ thống che mất đếm ngược), còn một lý do kỹ thuật nặng hơn — xem 7.3: **`Timer` của
> Dart có dấu hiệu bị dừng khi màn hình tắt / app xuống nền.** Cơ chế B chạy đúng lúc app nằm dưới
> màn Emergency SOS của hệ thống, tức **đang ở nền**. Thêm đếm ngược vào đây là tự tạo ra tình
> huống SOS không bao giờ được gửi mà không có lỗi nào hiện ra.

### 4B.3 Bật/tắt và xin quyền

- Công tắc riêng trong Cài đặt SOS: **"Gửi SOS khi bấm nút nguồn 5 lần"**, mặc định **TẮT**.
- Bật lên → kiểm tra service đã được cấp quyền chưa; chưa thì mở
  `Settings.ACTION_ACCESSIBILITY_SETTINGS` kèm dialog hướng dẫn tìm đúng mục.
- **Nói thẳng trong dialog** rằng màn hệ thống sẽ ghi *"toàn quyền kiểm soát thiết bị"*, và app
  **chỉ đọc tên ứng dụng đang mở**, không đọc nội dung. Người dùng thấy chữ đó mà không được báo
  trước sẽ hoảng và bỏ.
- Kiểm tra quyền còn hay không bằng `AccessibilityManager.getEnabledAccessibilityServiceList()` —
  người dùng có thể tắt bất cứ lúc nào trong Cài đặt, app phải phản ánh đúng trạng thái thật chứ
  không tin vào cờ đã lưu.

### 4B.4 Kiểm thử riêng cho cơ chế B

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| B1 | Chưa cấp quyền, bật công tắc | Mở đúng màn Cài đặt trợ năng, công tắc **không** tự bật |
| B2 | Khóa máy, bấm nguồn 5 lần | Gửi **đúng 1** cảnh báo (không phải 4 — xem 4B.1) |
| B3 | Bấm HỦY trên thông báo | Cảnh báo chuyển `CANCELED` trên BE |
| B4 | Bấm 5 lần hai đợt cách nhau 5 giây | Đợt 2 bị cooldown chặn |
| B5 | Tắt quyền trong Cài đặt hệ thống | Công tắc trong app phản ánh đúng là đã tắt |
| B6 | Máy **không phải OPPO** (nếu mượn được) | Không kích hoạt — ghi lại package của máy đó |

---

## 5. Manifest và quyền (targetSdk 36 — sai là crash lúc chạy)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.VIBRATE" />
<!-- chỉ khi làm mục 4.5 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

`POST_NOTIFICATIONS` **đã có sẵn**, không thêm lại. Gia tốc kế **không cần quyền**.

Khai service bên trong `<application>`:

```xml
<service
    android:name=".SosGuardService"
    android:exported="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Theo dõi cảm biến chuyển động để phát hiện té ngã và cử chỉ lắc khẩn cấp" />
</service>
```

**Đã cân nhắc và loại `health`** (cần quyền cảm biến sức khỏe không liên quan) và **`location`**
(sai bản chất — service này không theo dõi vị trí).

**Lưu ý `specialUse`:** nếu phát hành lên Google Play thì loại này bị xét duyệt thủ công. Đồ án phát
hành APK trực tiếp nên **không vướng**, nhưng phải biết để không hứa nhầm.

---

## 6. Tham số và tình huống biên

### 6.1 Tham số mặc định — PHẢI chỉnh theo số đo ở spike 4.0

| Tham số | Giá trị khởi điểm | Ghi chú |
|---|---|---|
| Ngưỡng lắc | 25 m/s² | Bằng ngưỡng va đập của phát hiện té ngã, giữ nhất quán |
| Ngưỡng tụt để đếm đỉnh tiếp | 60% ngưỡng trên | Chống đếm nhiều lần trong 1 cú lắc |
| Số đỉnh cần | 4 | Đủ để phân biệt với va chạm ngẫu nhiên |
| Cửa sổ | 2000 ms | Lắc chủ ý thường 3-5 nhịp/giây |
| Cooldown | 30 giây | Trùng `FallDetectionTuning.cooldown` |

**Chống báo nhầm — phải test bằng chuỗi mẫu thật:** đi bộ, chạy, đi xe máy đường xóc, để trong túi
quần, rơi điện thoại xuống bàn. Ghi kết quả vào bảng ở 7.2.

### 6.2 Đang có SOS `ACTIVE`
`SOSScreen` đã tự xử lý: có alert đang chạy thì hiện màn theo dõi thay vì tạo mới. Không cần code
thêm — **nhưng phải test lại** vì lần này vào từ đường khác.

### 6.3 Chưa đăng nhập / chưa có gia đình
`computeRedirect` đã chặn sẵn: `/sos-quick` khi chưa đăng nhập → `/login`; chưa có gia đình →
`/family-setup` (xem `test/sos_quick_shortcut_test.dart`). **Không sửa gì.**

Nhưng service **không nên chạy** khi chưa đăng nhập — kiểm tra trước khi `start()` ở tầng Dart.

### 6.4 Vẫn giữ Emergency SOS của hệ thống
Không xung đột — hai cơ chế độc lập, cử chỉ khác nhau. **Nói trước khi demo** rằng bấm nguồn 5 lần
là tính năng của máy, không phải của app (xem mục 1).

---

## 7. Kiểm thử

### 7.1 Tự động (bắt buộc)
- **JVM test `ShakeDetector` + `FallDetector`** — xem 4.2. Đây là phần logic duy nhất test máy được,
  phải phủ kỹ, đặc biệt các ca **báo nhầm**.
- `flutter analyze --no-fatal-infos` → **0 error**.
- `flutter test` → **không được thấp hơn 440**.
- `flutter build apk --debug` phải chạy được (thêm service + quyền, dễ vỡ manifest merge).

### 7.2 Máy thật (không tự động được)

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Bật công tắc → xem thanh thông báo | Có thông báo thường trực, có nút "Tắt" |
| 2 | **Khóa màn, để trong túi, lắc mạnh** | Màn SOS hiện **đè lên màn khóa**, đang đếm ngược |
| 3 | Bấm HỦY | **Không** có cảnh báo nào được tạo trên BE |
| 4 | Để đếm hết | Người nhà nhận được SOS |
| 5 | Vuốt tắt app khỏi đa nhiệm rồi lắc | Vẫn chạy (service sống) |
| 6 | **Đi bộ 5 phút** với máy trong túi | **Không** kích hoạt lần nào |
| 7 | **Đi xe máy 5 phút đường xóc** | **Không** kích hoạt lần nào |
| 8 | Rơi điện thoại xuống bàn/giường | Ghi lại có kích hoạt không (té ngã có thể bắt — đúng thiết kế, vì có đếm ngược để hủy) |
| 9 | Kích hoạt 2 lần liên tiếp trong 30 giây | Lần 2 bị cooldown chặn |
| 10 | Tắt công tắc | Thông báo biến mất, lắc không còn tác dụng |
| 11 | **Máy Oppo, để yên 30 phút màn tắt** | Ghi lại service còn sống không (kỳ vọng: **có thể bị giết**) |
| 12 | Android 14+ chưa cấp full-screen intent | Rơi về fallback ở 4.3, **không im lặng** |

**Ghi kết quả kịch bản 6, 7, 11, 12 vào `docs/DEMO_GUIDE.md`** — bốn cái này quyết định có nên demo
tính năng này trước hội đồng hay không.

### 7.3 🔴 HAI LỖI ĐÃ XÁC NHẬN BẰNG ĐO THỰC TẾ — phải sửa trước khi xây tiếp

Đo ngày 11/08 trên **OPPO CPH2159 / Android 13** (bản debug cài 19:31) + **máy ảo `emulator-5554`**
đóng vai người thân, điều khiển bằng `adb`, chụp màn hình cả hai máy làm bằng chứng.

#### Đối chứng: luồng đầu-cuối CHẠY ĐÚNG khi màn hình sáng

Giữ màn hình sáng suốt quá trình (bắn liên tục `KEYCODE_WAKEUP`), bắn deep link
`familycare://app/sos-quick` → máy người thân nhận đủ:
- Banner đỏ **"SOS Zap đang cần trợ giúp!"**
- Thông báo **"Cảnh báo SOS — Zap đã kích hoạt SOS"**
- Bản đồ vẽ **"Đường tới Điểm SOS · 12653.8 km"** → **GPS thật được gửi kèm đúng**

→ Bản thân luồng gửi SOS **không có vấn đề gì**. Hai lỗi dưới đây nằm ở chỗ khác.

#### 🔴 LỖI 1 — Tắt màn hình giữa lúc đếm ngược thì SOS KHÔNG BAO GIỜ được gửi

**Cách tái hiện (đã chạy, kết quả nhất quán):**
1. App đang mở, máy đã mở khóa
2. Bắn deep link → màn SOS hiện, đếm ngược bắt đầu
3. Sau 1,2 giây (đếm ngược còn ~2) → `KEYCODE_SLEEP` tắt màn hình
4. Chờ 15 giây → kiểm tra máy người thân

**Kết quả:** máy người thân **không nhận được gì** — không banner, không nhãn SOS trong danh sách
thành viên, bản đồ không có điểm SOS. Máy gửi thì quay về màn khóa.

So sánh trực tiếp, **chỉ khác đúng một biến**:

| Lần chạy | Màn hình | Kết quả |
|---|---|---|
| Đối chứng | **Sáng** suốt quá trình | ✅ Người thân nhận ngay |
| Ca 13 | **Tắt** lúc còn ~2 giây | ❌ Không có gì |

**Vì sao nghiêm trọng:** đúng kịch bản thật — bấm lối tắt SOS rồi bỏ máy vào túi, màn hình tắt →
**SOS không bao giờ được gửi, và không có lỗi nào hiện ra**. Người dùng tưởng đã báo được cho gia
đình. Với tính năng khẩn cấp thì đây là kiểu hỏng tệ nhất có thể.

**Hai hướng sửa** (chọn hướng ít thay đổi hơn, theo quy tắc mục 9):
1. **Giữ `PARTIAL_WAKE_LOCK`** trong lúc đếm ngược, nhả ngay sau khi gửi xong hoặc khi người dùng
   hủy. Chỉ giữ 3 giây nên gần như không tốn pin.
2. **Bỏ đếm ngược khi vào từ nền**: phát hiện app không ở foreground thì gửi ngay rồi cho hủy qua
   thông báo — tức dùng đúng luồng của cơ chế B (mục 4B.2).

#### 🔴 LỖI 2 — Bắn deep link lần thứ hai vào cùng route thì KHÔNG kích hoạt lại đếm ngược

**Phát hiện tình cờ khi chạy ca 14.** Sau khi ca 13 bị cắt ngang, màn SOS bị kẹt ở trạng thái chờ
(nút hiện chữ "SOS", chữ dưới *"Giữ 3 giây để gửi SOS"*) — **không đếm ngược, không báo lỗi, không
phải màn đã gửi**. Bắn deep link lần nữa vào đúng `/sos-quick`: **vẫn đứng im**.

**Nguyên nhân:** go_router thấy vị trí đích **trùng vị trí hiện tại** nên không dựng lại widget →
`initState` không chạy lại → `autoTrigger` không bao giờ được gọi.

**Vì sao nghiêm trọng:** người dùng bấm lối tắt SOS, thấy đếm ngược, bấm HỦY (hoặc bị cắt ngang như
trên). Sau đó bấm lối tắt **lần nữa** → **không có gì xảy ra**. Không lỗi, không phản hồi. Đây là
lỗi của **lối tắt hiện tại đã phát hành**, không riêng gì cơ chế B.

**Hướng sửa gợi ý:** đừng dựa vào `initState` để kích hoạt. Cho deep link mang tham số thay đổi mỗi
lần (ví dụ `/sos-quick?t=<timestamp>`) để go_router coi là vị trí mới, **hoặc** bắt sự kiện điều
hướng ở tầng router và kích hoạt lại đếm ngược ngay cả khi widget được tái dùng.

#### Ca kiểm thử phải chạy lại sau khi sửa

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 13 | Lối tắt SOS → **tắt màn hình ngay** → chờ 15 giây | SOS **đã được gửi** |
| 14 | Lối tắt SOS → **bấm Home** (màn hình vẫn sáng) → chờ 15 giây | SOS **đã được gửi** |
| 15 | Lối tắt SOS → để yên màn hình sáng | Gửi sau đúng 3 giây *(đã xác nhận chạy)* |
| 16 | Lối tắt SOS → **bấm HỦY** → bấm lối tắt **lần nữa** | Đếm ngược **chạy lại từ đầu** |
| 17 | Lối tắt SOS 2 lần liên tiếp thật nhanh | Chỉ **một** cảnh báo được tạo, không phải hai |

> **Không được bỏ qua các ca này** vì "bấm tay thấy chạy" — lúc test tay thì màn hình luôn sáng và
> thường chỉ bấm một lần, đúng hai điều kiện che mất cả hai lỗi trên.

---

## 8. Trải nghiệm người dùng

### 8.1 Chống báo động giả — quan trọng nhất
- **Giữ nguyên đếm ngược 3 giây + nút HỦY** của `/sos-quick`. Không được bỏ để "cho nhanh".
- **Rung mạnh + bật sáng màn hình** khi kích hoạt, để người lỡ lắc biết mà hủy.

### 8.2 Lần đầu bật công tắc
Dialog nói rõ 3 điều: (1) sẽ có thông báo thường trực không tắt được, (2) cần cho phép chạy nền,
(3) hướng dẫn bỏ tối ưu hóa pin.

### 8.3 Hướng dẫn bỏ tối ưu hóa pin
Mở màn hệ thống bằng `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`.

> ⚠️ **KHÔNG** dùng `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (hộp thoại xin trực tiếp) — Google
> Play cấm với app thường. Chỉ mở màn cài đặt để người dùng tự chọn.

---

## 9. Quy tắc bắt buộc của repo (đọc `CLAUDE.md` trước khi bắt đầu)

1. **Preview trước khi sửa** — mô tả file sẽ đổi, logic cũ → mới, rủi ro; chỉ sửa sau khi user xác
   nhận. Áp dụng cho **mọi** thay đổi, kể cả sửa nhanh.
2. **Không mock/workaround khi BE thiếu.** Tính năng này thuần client, **không cần BE gì cả**.
3. **Tiếng Việt** cho toàn bộ comment, tài liệu, commit message.
4. **Commit:** tác giả chỉ Giáp, **KHÔNG** trailer `Co-Authored-By: Claude`. Mỗi commit một concern,
   tách code khỏi docs. Verify bằng `git log --format='%an <%ae> | %(trailers)'`.
5. **KHÔNG đụng vùng AI Chatbot** (`lib/models/ai_chatbot.dart`,
   `lib/screens/shared/ai_assistant_screen.dart`, `lib/providers/ai_chatbot_provider.dart`,
   `test/ai_*.dart`) — do Duy phụ trách trên nhánh `NDuy`.
6. **KHÔNG xóa/sửa** `lib/services/fall_detector_service.dart` và `test/fall_detection_test.dart` —
   vẫn phục vụ luồng app đang mở, đang có test xanh (xem 3.1).
7. **Đang sát đợt bảo vệ hội đồng** — ưu tiên ổn định. Nhiều cách làm thì chọn cách **ít thay đổi
   nhất**, không phải cách "đẹp nhất về kiến trúc".

---

## 10. Thứ tự làm và điểm dừng

| Bước | Nội dung | Dừng lại báo cáo? |
|---|---|---|
| **VIỆC 0 — làm TRƯỚC MỌI THỨ** | | |
| 0 | **Sửa 2 lỗi đã xác nhận ở mục 7.3** (tắt màn hình → mất SOS; bắn deep link lần 2 → không kích hoạt lại), rồi chạy lại ca 13–17 | ✅ **Bắt buộc dừng, báo kết quả** |
| **CƠ CHẾ A — lắc mạnh (làm trước)** | | |
| 1 | Spike 4.0 — đo cảm biến khi màn hình tắt | ✅ **Bắt buộc dừng, báo số đo** |
| 2 | `ShakeDetector` + `FallDetector` Kotlin + JVM test | Không |
| 3 | Service + manifest, build APK chạy được | Không |
| 4 | Full-screen intent + `showWhenLocked` | ✅ **Dừng nếu Android 14+ chặn quyền** |
| 5 | MethodChannel + 2 công tắc trong Cài đặt SOS | Không |
| 6 | Chạy bảng kiểm thử 7.2 trên máy thật | ✅ **Dừng, báo kết quả ca 6, 7, 11, 12** |
| **CƠ CHẾ B — bấm nguồn 5 lần (chỉ làm khi A đã ổn)** | | |
| 7 | `EmergencyWatchService` + config XML + manifest | Không |
| 8 | Luồng gửi-ngay + thông báo HỦY (4B.2) | Không |
| 9 | Công tắc + dialog xin quyền trợ năng (4B.3) | Không |
| 10 | Bảng kiểm thử 4B.4 trên máy Oppo | ✅ **Dừng, báo kết quả B2 và B6** |
| **CHUNG** | | |
| 11 | Cập nhật `docs/DEMO_GUIDE.md` | Không |

**Ước lượng:** bước 1 khoảng 30 phút. Bước 2-5 là phần chính. Bước 6 **phải làm trên máy thật**,
không rút ngắn được — ca 6, 7 (đi bộ, đi xe máy) cần ra ngoài thật.

> **Vì sao bước 0 đứng trước cả spike cảm biến:** hai lỗi ở mục 7.3 nằm ở **luồng gửi SOS dùng
> chung** cho cả lối tắt hiện có, cơ chế A và cơ chế B. Không sửa trước thì mọi thứ xây lên trên đều
> thừa hưởng lỗi, và làm xong cơ chế A rồi mới phát hiện thì phải quay lại sửa cả hai.
>
> **Lỗi 2 còn ảnh hưởng tính năng ĐANG PHÁT HÀNH** (lối tắt màn hình chính, commit `e01e0e4`) —
> đây là lý do nó được xếp lên trước mọi việc khác chứ không phải vì cơ chế mới.

**Nếu thiếu thời gian:** làm xong cơ chế A là đã đủ demo. Cơ chế B là phần "wow" nhưng phụ thuộc
hãng máy nên rủi ro cao hơn — **đừng hy sinh độ ổn định của A để kịp B**.

---

## 11. Những gì kế hoạch này KHÔNG giải quyết — nói thẳng

- **Bấm nút nguồn 5 lần trên máy KHÔNG phải OPPO/OnePlus/Realme** → chưa đo, gần như chắc chắn
  **không chạy** vì package khác. Xem 1.6. Cơ chế A (lắc) không có giới hạn này.
- **Người dùng không chịu cấp quyền trợ năng** → cơ chế B không hoạt động, không có đường vòng.
- **Máy đã tắt nguồn hẳn** → không có cách nào. Không phần mềm nào làm được.
- **OEM giết service** → giảm thiểu bằng hướng dẫn bỏ tối ưu pin, **không loại bỏ được**.
- **Không có mạng** → SOS không gửi đi được. `SOSScreen` đã có dialog báo lỗi kèm tọa độ GPS để
  người dùng tự chia sẻ tay. Buffer vị trí offline (commit `ae69a45`) chỉ áp dụng cho cảnh báo **đã
  tạo được**, không giúp cho việc tạo mới.
- **Lắc nhầm** → giảm bằng đếm ngược 3 giây + ngưỡng đã hiệu chỉnh, không loại bỏ hẳn. BE có sẵn
  `FALSE_ALARM` và `cancel` để đóng lại.
- **Đếm ngược khi màn hình tắt** → **đã xác nhận HỎNG**, xem lỗi 1 mục 7.3. Chưa sửa thì mọi luồng
  có đếm ngược đều không đáng tin.
- **Bấm lối tắt lần thứ hai** → **đã xác nhận KHÔNG phản hồi**, xem lỗi 2 mục 7.3. Ảnh hưởng cả
  tính năng đang phát hành.
- **Người ngã bất tỉnh úp mặt xuống, máy trong túi chật** → gia tốc kế vẫn bắt được cú va đập, nhưng
  nếu máy bị kẹt không rơi tự do thì có thể không nhận ra. Không có giải pháp phần mềm thuần.
