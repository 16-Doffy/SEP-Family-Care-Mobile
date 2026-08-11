# Kế hoạch build — Kích hoạt SOS khi không mở được app

**Ngày lập:** 2026-08-11 · **Người lập:** phiên Claude Code (nhánh `giap`) · **Người thực hiện:** Codex
**Trạng thái repo lúc lập kế hoạch:** `origin/giap` = `55ac2bb`, `flutter test` 440/440 pass,
`flutter analyze --no-fatal-infos` 0 error.

> ### ⚠️ ĐỌC MỤC 1 TRƯỚC — hướng làm đã ĐỔI so với ý tưởng ban đầu
> Yêu cầu gốc là "bấm nút nguồn 5 lần". **Đã thử nghiệm thực tế và phải loại bỏ** — xem mục 1.
> Cơ chế chính nay là **lắc mạnh điện thoại**. Phần hạ tầng (foreground service, mở màn đè lên màn
> khóa) giữ nguyên vì dùng chung cho mọi cơ chế kích hoạt.

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

## 1. Vì sao KHÔNG dùng "bấm nút nguồn 5 lần" — đã kiểm chứng thực tế

### 1.1 Bằng chứng

Thử trên **điện thoại Oppo thật (ColorOS)** ngày 11/08: bấm nút nguồn 5 lần → **hệ điều hành hiện
màn Emergency SOS riêng của nó**, kèm 3 số khẩn cấp Việt Nam **113 / 115 / 114**.

Tức là cử chỉ này **đã bị hệ thống chiếm**.

### 1.2 Ba lý do phải loại bỏ

1. **Va chạm giao diện không thể thắng.** Kể cả app đếm đủ 5 lần và bắn full-screen intent, màn SOS
   của app phải tranh chỗ với màn khẩn cấp của hệ thống. **System UI luôn thắng.** Người dùng nhìn
   thấy bảng quay số 113/115/114, còn đếm ngược của app bị che — tệ hơn cả không làm gì, vì họ tưởng
   app đã gửi mà thực ra chưa.
2. **Số broadcast không còn đáng tin.** Khi hệ thống chiếm cử chỉ, màn hình không bật/tắt theo nhịp
   bình thường nữa, nên cách đếm `ACTION_SCREEN_ON`/`OFF` có thể không bao giờ đủ 5.
3. **Không có API để hook vào.** Android không cho app đăng ký làm "nhà cung cấp SOS" cho Emergency
   SOS hệ thống. Không có cửa nào khác.

### 1.3 Đã cân nhắc và loại các cách chữa cháy

| Cách | Vì sao loại |
|---|---|
| Bảo người dùng **tắt Emergency SOS** của máy | Bắt người dùng tắt một tính năng an toàn để dùng tính năng an toàn khác. Vô lý, và giải thích trước hội đồng rất dở. |
| Đổi sang **4 hoặc 6 lần bấm** | Người dùng bấm 5 lần theo phản xạ vẫn kích hoạt hệ thống. Mỗi hãng đặt ngưỡng khác nhau → không có con số nào an toàn trên mọi máy. |
| `AccessibilityService.onKeyEvent()` | Hệ thống lọc phím nguồn **trước** khi phân phối cho accessibility. Ngoài ra Play Store cấm dùng accessibility sai mục đích. |
| Phím âm lượng | Không nhận được sự kiện khi màn hình tắt/khóa. |
| Nút tai nghe (`MediaSession`) | Chạy được cả khi khóa máy, nhưng **phải cắm tai nghe** — không hợp với người cao tuổi. |

### 1.4 Điều này làm RÕ giá trị của app, không phải làm yếu đi

Emergency SOS của máy chỉ **gọi cơ quan chức năng**. Nó **không báo cho gia đình** và **không chia
sẻ vị trí trực tiếp** cho người thân.

→ Đây chính là câu trả lời nếu hội đồng hỏi *"sao không dùng luôn SOS có sẵn của điện thoại?"*.
Hai thứ **bổ sung cho nhau**, không thay thế nhau. Nên ghi ý này vào tài liệu bảo vệ.

---

## 2. Cơ chế đã chọn: LẮC MẠNH điện thoại

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
| 1 | Spike 4.0 — đo cảm biến khi màn hình tắt | ✅ **Bắt buộc dừng, báo số đo** |
| 2 | `ShakeDetector` + `FallDetector` Kotlin + JVM test | Không |
| 3 | Service + manifest, build APK chạy được | Không |
| 4 | Full-screen intent + `showWhenLocked` | ✅ **Dừng nếu Android 14+ chặn quyền** |
| 5 | MethodChannel + 2 công tắc trong Cài đặt SOS | Không |
| 6 | Chạy bảng kiểm thử 7.2 trên máy thật | ✅ **Dừng, báo kết quả ca 6, 7, 11, 12** |
| 7 | Cập nhật `docs/DEMO_GUIDE.md` | Không |

**Ước lượng:** bước 1 khoảng 30 phút. Bước 2-5 là phần chính. Bước 6 **phải làm trên máy thật**,
không có cách rút ngắn — và ca 6, 7 (đi bộ, đi xe máy) cần ra ngoài thật.

---

## 11. Những gì kế hoạch này KHÔNG giải quyết — nói thẳng

- **Bấm nút nguồn 5 lần** → **không làm được**, hệ thống đã chiếm. Xem mục 1.
- **Máy đã tắt nguồn hẳn** → không có cách nào. Không phần mềm nào làm được.
- **OEM giết service** → giảm thiểu bằng hướng dẫn bỏ tối ưu pin, **không loại bỏ được**.
- **Không có mạng** → SOS không gửi đi được. `SOSScreen` đã có dialog báo lỗi kèm tọa độ GPS để
  người dùng tự chia sẻ tay. Buffer vị trí offline (commit `ae69a45`) chỉ áp dụng cho cảnh báo **đã
  tạo được**, không giúp cho việc tạo mới.
- **Lắc nhầm** → giảm bằng đếm ngược 3 giây + ngưỡng đã hiệu chỉnh, không loại bỏ hẳn. BE có sẵn
  `FALSE_ALARM` và `cancel` để đóng lại.
- **Người ngã bất tỉnh úp mặt xuống, máy trong túi chật** → gia tốc kế vẫn bắt được cú va đập, nhưng
  nếu máy bị kẹt không rơi tự do thì có thể không nhận ra. Không có giải pháp phần mềm thuần.
