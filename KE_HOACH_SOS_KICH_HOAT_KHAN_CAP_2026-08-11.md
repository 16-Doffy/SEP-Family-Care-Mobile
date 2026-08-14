# Kế hoạch build — Foreground service: kích hoạt SOS + giữ cuộc gọi video sống nền

**Ngày lập:** 2026-08-11 · **Cập nhật:** 2026-08-12 (gộp thêm phần Video Call) · **Người lập:** phiên
Claude Code (nhánh `giap`) · **Người thực hiện:** Codex
**Trạng thái repo lúc cập nhật 12/08:** `flutter test` 464/464 pass, `flutter analyze --no-fatal-infos`
0 error. Video Call đã xong đủ GĐ1–4 (REST/model → signaling Socket.IO → LiveKit UI → nối dây provider),
xem `API_DOCS.md` mục Calls. **Giới hạn còn lại của Call chính là thứ kế hoạch này giải quyết**: cuộc
gọi rớt khi khoá màn hình/xuống nền giữa chừng.

> ### ⚠️ ĐỌC MỤC 1 TRƯỚC — hướng làm đã ĐỔI so với ý tưởng ban đầu
> Yêu cầu gốc là "bấm nút nguồn 5 lần chặn phím cứng". **Đã thử nghiệm thực tế và phải loại bỏ** —
> xem mục 1. Cơ chế chính là **lắc mạnh điện thoại**. Phần hạ tầng (foreground service, mở màn đè
> lên màn khóa) giữ nguyên vì dùng chung cho mọi cơ chế kích hoạt.
>
> **Cập nhật 12/08 — có Cơ chế B riêng, KHÔNG mâu thuẫn với mục 1.** Người dùng vẫn muốn giữ thao
> tác "bấm nguồn 5 lần", nhưng bằng một kỹ thuật khác hẳn cái đã bị loại: thay vì chặn phím nguồn
> (bị hệ thống lọc trước, xem 1.2), app **theo dõi sự kiện đổi màn hình đang hiển thị**
> (`AccessibilityService` + `TYPE_WINDOW_STATE_CHANGED`) để phát hiện lúc **màn Emergency SOS của
> ColorOS đã hiện lên**, rồi tự gửi SOS của app ngay lập tức. Xem mục 13.
>
> ### 🛑 CẬP NHẬT 12/08 (lần 2) — TEST TRÊN MÁY OPPO THẬT: KHÔNG BẬT ĐƯỢC TÍNH NĂNG
> Đã test trên Oppo CPH2159 thật. Android 13's "Restricted settings" chặn việc bật
> `EmergencySosWatcherService` cho mọi app cài qua APK trực tiếp — đã thử hết các cách mở khoá
> (App info, ADB `settings put`, ADB `appops set`, đổi installer giả Play Store) đều thất bại.
> **Cơ chế B hiện KHÔNG demo được trên máy đang có**, dù code không lỗi — đây là chính sách hệ điều
> hành, không phải bug. Chi tiết đầy đủ + hướng ra còn lại: xem mục **13.7**.

> ### 📎 GỘP THÊM 12/08 — Video Call cũng cần foreground service
> Đây là **lý do gộp hai việc vào một kế hoạch**: cả SOS (mục 1–11) và Call (mục 12, thêm mới) đều cần
> foreground service để sống qua lúc màn hình tắt — làm chung một đợt để không tốn công dựng hạ tầng
> (channel notification, `MethodChannel` bridge, cách khai `<service>` trong manifest...) hai lần.
> **Nhưng đây là 2 SERVICE KHÁC NHAU**, không gộp chung 1 class — xem lý do ở 12.2. Nếu chỉ có thời
> gian làm một trong hai, **ưu tiên SOS** (an toàn tính mạng > trải nghiệm cuộc gọi).

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
- `flutter test` → **không được thấp hơn số hiện tại lúc bắt đầu làm** (464 tính đến 12/08 — chạy
  `flutter test` đo lại trước khi sửa gì, đừng tin cứng con số này vì có thể lệch theo thời gian).
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

> **Phần Video Call (mục 12) là luồng riêng, làm sau hoặc xen kẽ đều được** — không phụ thuộc bước nào
> ở trên, chỉ dùng chung kinh nghiệm dựng `Service`/`MethodChannel`/notification channel. Nếu thiếu
> thời gian, **làm xong SOS (1–10) trước rồi mới tới mục 12** — đúng thứ tự ưu tiên đã nói ở đầu file.

---

## 11. Những gì kế hoạch này KHÔNG giải quyết — nói thẳng

- **Bấm nút nguồn 5 lần theo kiểu chặn phím cứng** → **không làm được**, hệ thống lọc phím trước
  khi tới app. Xem mục 1. **Có cách khác** (theo dõi màn hình Emergency SOS xuất hiện thay vì chặn
  phím) — xem mục 13, nhưng giới hạn theo máy (chỉ ColorOS) và chưa kiểm thử máy thật.
- **Máy đã tắt nguồn hẳn** → không có cách nào. Không phần mềm nào làm được.
- **OEM giết service** → giảm thiểu bằng hướng dẫn bỏ tối ưu pin, **không loại bỏ được**.
- **Không có mạng** → SOS không gửi đi được. `SOSScreen` đã có dialog báo lỗi kèm tọa độ GPS để
  người dùng tự chia sẻ tay. Buffer vị trí offline (commit `ae69a45`) chỉ áp dụng cho cảnh báo **đã
  tạo được**, không giúp cho việc tạo mới.
- **Lắc nhầm** → giảm bằng đếm ngược 3 giây + ngưỡng đã hiệu chỉnh, không loại bỏ hẳn. BE có sẵn
  `FALSE_ALARM` và `cancel` để đóng lại.
- **Người ngã bất tỉnh úp mặt xuống, máy trong túi chật** → gia tốc kế vẫn bắt được cú va đập, nhưng
  nếu máy bị kẹt không rơi tự do thì có thể không nhận ra. Không có giải pháp phần mềm thuần.

---

## 12. MỞ RỘNG — Video Call: giữ cuộc gọi sống khi khoá màn hình/xuống nền

### 12.1 Bối cảnh

Video Call đã xong đủ 4 giai đoạn (REST/model → signaling Socket.IO `/chat` → LiveKit UI → nối dây
provider), xem `API_DOCS.md` mục **Calls**. Giới hạn còn lại duy nhất, đã ghi rõ trong đó:

> Cuộc gọi **chưa chạy nền** — tắt màn hình/bấm Home giữa cuộc gọi sẽ rớt kết nối LiveKit.

Nguyên nhân **giống hệt** lỗi "tắt màn hình mất SOS" đã chẩn đoán ở mục 0 của kế hoạch này: Android
đóng băng tiến trình vài giây sau khi app xuống nền, kết nối WebRTC (audio/video) của LiveKit chết
theo. Cách chữa cũng là **foreground service** — đây là lý do gộp hai việc vào một kế hoạch.

**File liên quan (đã có sẵn, không cần đọc lại từ đầu):**
- `lib/services/livekit_room_service.dart` — `connect({url, token})`/`disconnect()`/
  `setCameraEnabled()`/`setMicrophoneEnabled()`. Đây là nơi bắt/nhả foreground service của Call.
- `lib/screens/shared/active_call_screen.dart` — gọi `LivekitRoomService.instance.connect(...)` rồi
  `setCameraEnabled(true)` + `setMicrophoneEnabled(true)` ngay sau khi kết nối thành công (trong
  `_connect()`). **Không sửa file này** — điểm nối nằm ở `livekit_room_service.dart`.
- `lib/providers/call_provider.dart` — `leave(callId)`/`end(callId)` báo BE kết thúc cuộc gọi, độc lập
  với việc rời phòng LiveKit.

### 12.2 Vì sao KHÔNG gộp chung 1 Service với SOS

Hai lý do kỹ thuật, không phải sở thích:

1. **`foregroundServiceType` khác nhau và bị Android 14 (API 34) ép đúng thực tế đang dùng.** `SosGuardService`
   khai `specialUse` (theo dõi cảm biến). Call cần khai `camera|microphone` — hệ thống **ném lỗi runtime**
   (`MissingForegroundServiceTypeException`/`SecurityException`) nếu service không khai đúng loại đang thật sự
   dùng. Gộp chung 1 service nghĩa là **lúc SOS chạy một mình** (không gọi video) service đó vẫn mang nhãn
   `camera|microphone` dù chẳng dùng camera/mic gì cả — sai bản chất, và Google Play (nếu sau này phát hành)
   sẽ từ chối lý do khai báo không khớp hành vi thật.
2. **Vòng đời khác hẳn nhau.** `SosGuardService` là dịch vụ **bật/tắt bằng công tắc**, sống liên tục nhiều
   giờ/ngày một khi người dùng bật (mục 4.4). Foreground service của Call chỉ nên sống **đúng trong lúc đang
   gọi** — bắt đầu lúc `LivekitRoomService.connect()`, kết thúc lúc `.disconnect()`, thường chỉ vài phút.
   Gộp chung nghĩa là logic bật/tắt của hai luồng hoàn toàn khác nhau đan vào cùng một class → dễ vỡ, khó test.

**Vẫn dùng chung được:** notification channel builder, cách khai `<service>` trong manifest, cách bọc
`MethodChannel` phía Dart, và **`MainActivity.kt` chỉ cần sửa 1 lần** — `setShowWhenLocked(true)` +
`setTurnScreenOn(true)` đã thêm cho SOS ở mục 4.3 **tự động có lợi cho Call luôn** (màn cuộc gọi đang mở mà
khoá/mở lại máy thì không bị đẩy về màn khoá trước) — **không cần sửa gì thêm ở đây**.

### 12.3 Kiến trúc

```
ActiveCallScreen._connect()
        │
        ▼
LivekitRoomService.connect(url, token)
        │
        ├──► (MỚI) CallGuardService.start()  ── foreground service, type camera|microphone
        │            │                            PHẢI chạy trước bước dưới, xem 12.4 lưu ý thứ tự
        │            ▼
        │    Notification "Đang trong cuộc gọi video" (IMPORTANCE_LOW, không kêu/rung)
        │
        ▼
room.connect(url, token)  ──► setCameraEnabled(true) ──► setMicrophoneEnabled(true)
        (không đổi — code Dart đã có sẵn)


LivekitRoomService.disconnect()
        │
        ├──► room.disconnect() + room.dispose()   (không đổi)
        └──► (MỚI) CallGuardService.stop()
```

### 12.4 Các bước thực hiện

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/CallGuardService.kt`

- `onCreate()`: tạo notification channel **riêng** với channel của SOS (mục 4.1) —
  `IMPORTANCE_LOW`, nội dung cố định *"Đang trong cuộc gọi video"* (không cần tên người gọi — tránh
  phải truyền dữ liệu UI xuyên qua tầng transport, xem ghi chú ở 12.1).
- `onStartCommand()`: `startForeground(NOTIF_ID, notification, FOREGROUND_SERVICE_TYPE_CAMERA or FOREGROUND_SERVICE_TYPE_MICROPHONE)`,
  trả `START_NOT_STICKY` (khác SOS — service này **không nên** tự khởi động lại nếu bị hệ thống giết
  giữa chừng, vì lúc đó cuộc gọi coi như đã rớt, tự bật lại một service rỗng không giúp được gì).
- `onDestroy()`: không cần dọn gì thêm (không giữ sensor listener như SOS).

> ⚠️ **Thứ tự bắt buộc, dễ sai nhất mục này:** phải `startForeground()` xong **trước khi** app thật sự
> dùng camera/microphone. Từ Android 14, gọi API camera/mic mà chưa có foreground service loại tương
> ứng đang chạy sẽ bị hệ thống chặn. Nghĩa là bên Dart phải **await** lệnh start service xong rồi mới
> gọi `room.connect()` — không chạy song song, không "fire and forget".

**File mới:** `lib/services/call_guard_service.dart` — bọc `MethodChannel`
(`com.familycare.family_care/call_guard`, đặt tên khác kênh của `sos_guard` ở mục 4.4 để hai bên độc
lập): `Future<void> start()`, `Future<void> stop()`.

**File sửa:** `MainActivity.kt` — đăng ký thêm 1 `MethodChannel` handler cho `call_guard` (cạnh handler
`sos_guard` đã có từ mục 4.4, không đụng vào handler đó).

**File sửa:** `lib/services/livekit_room_service.dart`:
```dart
Future<Room> connect({required String url, required String token}) async {
  await disconnect();
  await CallGuardService.instance.start(); // MỚI — chờ xong mới connect()
  final room = Room();
  final listener = room.createListener();
  _room = room;
  _listener = listener;
  try {
    await room.connect(url, token);
  } catch (_) {
    await disconnect();
    rethrow;
  }
  return room;
}

Future<void> disconnect() async {
  final listener = _listener;
  final room = _room;
  _listener = null;
  _room = null;
  if (listener != null) await listener.dispose();
  if (room != null) {
    await room.disconnect();
    await room.dispose();
  }
  await CallGuardService.instance.stop(); // MỚI
}
```
Đây là **toàn bộ phần sửa Dart** — `active_call_screen.dart` và `call_provider.dart` không cần đụng
vào, vì cả hai đều gọi vào `LivekitRoomService` chứ không tự quản kết nối.

### 12.5 Manifest và quyền

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<!-- dùng chung với dòng đã thêm ở mục 5 cho SOS, không khai trùng 2 lần -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
```

`CAMERA` và `RECORD_AUDIO` **đã có sẵn** (thêm từ bước 3a của Video Call, xem `API_DOCS.md`), không
thêm lại.

```xml
<service
    android:name=".CallGuardService"
    android:exported="false"
    android:foregroundServiceType="camera|microphone" />
```

### 12.6 Kiểm thử

Không có logic thuần nào để unit test ở đây (khác `ShakeDetector`/`FallDetector` của SOS) — toàn bộ
giá trị nằm ở hành vi thật của Android, phải test trên máy:

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Đang gọi, khoá màn hình 10 giây, mở lại | Vẫn nghe thấy nhau, video khôi phục |
| 2 | Đang gọi, bấm Home rồi mở app khác 30 giây, quay lại | Cuộc gọi vẫn sống |
| 3 | Đang gọi, vuốt tắt app khỏi đa nhiệm | Cuộc gọi rớt (chấp nhận được — khác SOS, người dùng
    chủ động thoát thì coi như họ muốn dừng gọi; **không cố giữ bằng mọi giá**) |
| 4 | Kết thúc cuộc gọi bình thường (bấm nút đỏ) | Thông báo `CallGuardService` biến mất ngay |
| 5 | `flutter analyze --no-fatal-infos` → 0 error; `flutter test` → không thấp hơn baseline lúc bắt đầu |

**Ghi chú ca 3:** khác hẳn triết lý của SOS (phải sống bằng mọi giá vì là tính năng an toàn tính
mạng), cuộc gọi video ưu tiên **đơn giản, ít rủi ro** hơn — vuốt tắt app khỏi đa nhiệm là hành động chủ
động của người dùng, không cần cố sống sót qua đó.

### 12.7 Những gì mục 12 KHÔNG giải quyết

- **Nút "Kết thúc cuộc gọi" ngay trên thanh thông báo** — nice-to-have, không làm ở đợt này. Cần
  `PendingIntent`/`BroadcastReceiver` gọi ngược lại `CallProvider.leave()` (cần `FlutterEngine` đang
  chạy), phức tạp hơn hẳn nút "Tắt" của SOS (chỉ cần dừng service). **Không chặn demo** — mở lại app là
  bấm được nút đỏ trong `ActiveCallScreen`.
- **OEM diệt service mạnh tay** (Xiaomi/Oppo tối ưu pin) — giống mục 11 của SOS, giảm thiểu bằng hướng
  dẫn bỏ tối ưu pin, không loại bỏ được hoàn toàn.
- **Cuộc gọi khi máy đang trong cuộc gọi thoại GSM khác** — ngoài phạm vi, chưa có yêu cầu xử lý.

---

## 13. MỞ RỘNG 12/08 — Cơ chế B: bám theo Emergency SOS hệ thống (ColorOS)

### 13.1 Bối cảnh — vì sao thêm cái này dù mục 1 đã loại "bấm nguồn 5 lần"

Test thực tế 12/08 trên Oppo: bấm nguồn 5 lần, hệ thống hiện màn Emergency SOS riêng (đúng như mục
1 mô tả), nhưng **app không phát được cảnh báo của mình** — vì trước đó app không có cơ chế nào để
biết chuyện này vừa xảy ra. Người dùng yêu cầu rõ: **giữ thao tác "bấm nguồn 5 lần", nhưng app phải
tự phát hiện được lúc màn Emergency SOS xuất hiện rồi bắn SOS luôn**.

Đây **không phải quay lại cách đã bị loại ở 1.2**. Cách cũ (`AccessibilityService.onKeyEvent()`)
chặn *sự kiện phím nguồn* — bị hệ thống lọc trước khi tới bất kỳ app nào, không có cách nào lách.
Cách mới **không đụng tới phím nguồn**: nó theo dõi *sự kiện đổi cửa sổ đang hiển thị*
(`TYPE_WINDOW_STATE_CHANGED`) trên toàn hệ thống — một luồng dữ liệu khác, không bị chặn — để nhận
ra lúc Activity của `com.oplus.sos` (Emergency SOS của ColorOS) vừa lên màn hình, bất kể nó xuất
hiện do bấm nguồn 5 lần hay do người dùng tự mở tay. Từ đó app không cần biết *cách* màn đó được mở,
chỉ cần biết *nó đang mở*.

### 13.2 Giới hạn — đã trình bày với người dùng trước khi code (Rule 3)

1. **Chỉ chạy trên ColorOS** (Oppo/Realme/OnePlus) — package `com.oplus.sos` là của riêng ColorOS.
   Samsung/Xiaomi/Pixel có màn khẩn cấp khác tên gói hoặc không có — trên các máy đó tính năng này
   **im lặng không làm gì**, không lỗi, không crash.
2. **Cần quyền `AccessibilityService`** — quyền nặng, người dùng phải tự bật tay trong Cài đặt hệ
   thống > Trợ năng, app không có cách nào tự bật hộ.
3. **Xung đột màn hình tại thời điểm phát hiện**: lúc app nhận ra Emergency SOS đang hiện, chính
   màn đó đang chiếm toàn màn hình — app không thể vẽ đè lên để hỏi "Hủy hay Gửi". Người dùng đã
   chọn: **gửi ngay, không đếm ngược** (khác hẳn `/sos-quick` vốn có đếm 3 giây + nút Hủy).

### 13.3 Kiến trúc

```
[Bấm nguồn 5 lần HOẶC tự mở tay]
              │
              ▼
   Android hiện màn Emergency SOS (com.oplus.sos) — của HỆ THỐNG, app không đụng vào
              │
              ▼
   EmergencySosWatcherService (AccessibilityService, canRetrieveWindowContent = false)
   nhận TYPE_WINDOW_STATE_CHANGED toàn hệ thống
              │
              ▼
   EmergencySosMatcher (class thuần, JVM test được) — khớp package + tên lớp chứa
   "Emergency" + qua khỏi cooldown 30s
              │
              ▼
   SosAlertLauncher.launch(context, "sos-immediate")
   (dùng CHUNG hạ tầng full-screen-intent với SosGuardService ở mục 4.3 — đã tách ra
   object riêng để không lặp code)
              │
              ▼
   MainActivity mở với familycare://app/sos-immediate/<token>
              │
              ▼
   SOSScreen(immediate: true) — GỬI NGAY khi vào màn, không đếm ngược, không nút Hủy
   (khác /sos-quick — lý do ở 13.2 điểm 3)
```

### 13.4 File đã thêm/sửa (native Kotlin)

- **Mới** `EmergencySosMatcher.kt` — class thuần không phụ thuộc Android, cùng khuôn với
  `ShakeDetector`/`FallDetector` ở mục 4.2: nhận `packageName`/`className`/`nowMs` qua tham số, so
  khớp package `com.oplus.sos` + tên lớp chứa `"Emergency"` (so khớp lỏng bằng substring, không
  khớp cứng tên lớp đầy đủ, để hedge rủi ro nhớ sai tên lớp chính xác — xem 13.6), cooldown 30 giây
  giống các detector khác trong repo.
- **Mới** `EmergencySosWatcherService.kt` — `AccessibilityService`, đăng ký
  `eventTypes = TYPE_WINDOW_STATE_CHANGED`, `canRetrieveWindowContent = false` (không đọc nội dung
  màn hình, chỉ biết app/Activity nào đang hiện — tối thiểu hoá quyền xin). Không phải foreground
  service — vòng đời do hệ thống Trợ năng tự quản.
- **Mới** `SosAlertLauncher.kt` — tách phần dựng notification `setFullScreenIntent()` (trước đây
  nằm trong `SosGuardService`, xem 4.3) thành object dùng chung, tham số hoá theo `deepLinkPath`.
  `SosGuardService` (lắc/té ngã → `sos-quick`) và `EmergencySosWatcherService` (→ `sos-immediate`)
  giờ gọi cùng một hàm — giữ nguyên cảnh báo quan trọng đã ghi trong code: **không được gọi
  `pendingIntent.send()` tay**, chỉ để hệ thống tự bắn từ notification (gọi tay bị chặn bởi giới
  hạn khởi chạy Activity nền của Android, đã từng vấp lỗi này trước đó trong dự án).
- **Sửa** `SosGuardService.kt` — refactor gọi qua `SosAlertLauncher.launch(this, "sos-quick")`,
  không đổi hành vi.
- **Mới** `res/xml/emergency_sos_watcher_config.xml` + string mô tả trong `strings.xml` (hiện trong
  danh sách Trợ năng của hệ thống — ghi rõ **không đọc nội dung màn hình, không đọc app khác**, chỉ
  theo dõi app nào đang hiện).
- **Sửa** `AndroidManifest.xml` — khai `<service>` cho `EmergencySosWatcherService` với
  `BIND_ACCESSIBILITY_SERVICE`.
- **Sửa** `MainActivity.kt` — thêm 2 action MethodChannel: `openAccessibilitySettings` (mở
  `Settings.ACTION_ACCESSIBILITY_SETTINGS`, chỉ mở danh sách chung, không deep-link được thẳng vào
  service cụ thể vì không có API chuẩn xuyên OEM) và `isEmergencyWatcherEnabled` (đọc
  `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`, so khớp `ComponentName` — chỉ đọc, không tự bật
  được).

### 13.5 File đã thêm/sửa (Dart)

- **Sửa** `lib/services/sos_guard_service.dart` — thêm `emergencyWatcherEnabled` vào
  `SosGuardStatus`, thêm `openAccessibilitySettings()` + `isEmergencyWatcherEnabled()`.
- **Sửa** `lib/screens/shared/sos_screen.dart` — thêm tham số `immediate` cho `SOSScreen`; khi
  `true` thì gửi SOS ngay trong `initState` (không đếm ngược), dùng lại nguyên UI loading/đã gửi có
  sẵn; message phân biệt rõ nguồn gốc ("phát hiện qua màn hình Cấp cứu khẩn cấp của máy").
- **Sửa** `lib/navigation/app_router.dart` — thêm route `/sos-immediate/:token` + hàm
  `sosImmediateFreshPath()` (bộ đếm **riêng**, không dùng chung với `_sosQuickSeq`, để hai nguồn bắn
  gần nhau không bao giờ trùng token — token trùng làm go_router không dựng lại màn, xem lỗi đã ghi
  ở mục 7 test file `sos_quick_shortcut_test.dart`).
- **Sửa** `lib/screens/shared/sos_settings_screen.dart` — thêm thẻ riêng "Bám theo Emergency SOS của
  máy" (không gộp vào thẻ "Bảo vệ SOS" của lắc/té ngã ở mục 4.4 vì đây là cơ chế độc lập, quyền
  khác nhau): badge trạng thái Đã bật/Chưa bật, giải thích giới hạn ColorOS + gửi ngay không đếm
  ngược, nút mở Cài đặt Trợ năng. Dùng `WidgetsBindingObserver` để tự refetch trạng thái khi quay
  lại app sau khi người dùng bật tay trong Cài đặt hệ thống.
- **Mới** test group trong `test/sos_quick_shortcut_test.dart` — mirror các test của
  `sosQuickFreshPath` cho `sosImmediateFreshPath`, cộng thêm 1 test khoá riêng: hai bộ đếm không bao
  giờ sinh ra giá trị trùng nhau.

### 13.6 Đã kiểm chứng — và CHƯA kiểm chứng được trong môi trường này

**Đã chạy sạch (12/08):**
- `./gradlew.bat :app:compileDebugKotlin :app:testDebugUnitTest` — `BUILD SUCCESSFUL`, gồm 5 test
  JVM mới của `EmergencySosMatcher` (đúng package+lớp → bắn 1 lần rồi bị cooldown chặn; sai package
  → không bao giờ bắn; đúng package sai tên lớp → không bắn; package/lớp null → không bắn; qua khỏi
  cooldown → bắn lại được).
- `flutter analyze --no-fatal-infos` — 0 lỗi trên toàn bộ file Dart đã sửa.
- `flutter test` — 478/478 pass (tăng từ baseline 464 do thêm test mới, không có test nào đỏ).

**Đã test trên 2 máy ảo (12/08, HOH + MEM):** cài APK, khởi động sạch không crash;
`EmergencySosWatcherService` được `PackageManager` nhận diện đúng và **chạy thật** khi bật qua
`settings put secure enabled_accessibility_services` (chỉ làm được trên emulator — xem 13.7); deep
link `/sos-immediate/:token` vào thẳng `SOSScreen(immediate: true)` **không đếm ngược**, và vô tình
xác nhận được cả luồng thật tới BE (2 máy ảo có sẵn phiên đăng nhập cũ + GPS mặc định của Google
Play Services nên SOS gửi thành công, hiện trên bản đồ gia đình, tự đóng khi đóng màn "SOS đã gửi").
Đây là xác nhận **UI/route/gửi SOS đúng thiết kế**, không phải xác nhận phần phát hiện Emergency SOS
(emulator không có `com.oplus.sos`).

### 13.7 ⚠️ CHẶN THẬT tìm thấy trên máy Oppo CPH2159 (12/08) — đọc trước khi làm tiếp

Test trên máy Oppo CPH2159 thật (Android 13, ColorOS, bản build `CPH2159_11_F.43`): cài APK debug
thành công, `EmergencySosWatcherService` được `PackageManager` nhận diện đúng (`dumpsys package`
thấy `intent-filter` + quyền `BIND_ACCESSIBILITY_SERVICE`, giống hệt trên emulator).

Nhưng khi vào **Cài đặt > Trợ năng > Family Care** để bật, hệ thống chặn ngay bằng hộp thoại:

> **Chế độ cài đặt bị hạn chế** — Để đảm bảo an toàn cho bạn, chế độ cài đặt này hiện bị vô hiệu hoá.

Đây là cơ chế **"Restricted settings" của Android 13+** (chống malware lạm dụng Accessibility Service
qua app cài ngoài Play Store) — áp dụng cho **mọi** app cài qua APK trực tiếp/ADB, không phải lỗi
riêng của app này.

**Đã thử mọi cách mở khoá, đều thất bại trên máy này:**
1. Đường chính thức của AOSP (App info → menu 3 chấm → "Cho phép cài đặt bị hạn chế") — **menu 3
   chấm trên bản ColorOS này chỉ có "Gỡ cài đặt đối với tất cả người dùng", không có mục đó.**
2. Cài lại APK với installer giả làm Play Store (`adb install -i com.android.vending`) — không đổi
   gì, hộp thoại chặn vẫn hiện y hệt.
3. `adb shell settings put secure enabled_accessibility_services ...` — bị từ chối:
   `SecurityException: ... requires android.permission.WRITE_SECURE_SETTINGS` (khác hẳn emulator,
   nơi lệnh này chạy được bình thường vì shell trên emulator có quyền rộng hơn).
4. `adb shell appops set ... ACCESS_RESTRICTED_SETTINGS allow` (cách lách thường dùng cho case này)
   — cũng bị từ chối: `SecurityException: uid 2000 does not have MANAGE_APP_OPS_MODES`.
5. Tìm trong Cài đặt > Mật khẩu & bảo mật, Cài đặt > Ứng dụng, `com.oplus.safecenter` (Trung tâm bảo
   mật OPPO) — không tìm thấy màn quản lý "ứng dụng bị hạn chế" nào khác để mở khoá từ đó.

**Kết luận thật, không tô hồng:** trên máy demo hiện có, **không có cách nào bật được
`EmergencySosWatcherService` qua APK cài trực tiếp** — kể cả bằng tay thật (không chỉ do giới hạn
của việc điều khiển qua ADB, vì các đường ADB-only cũng bị chặn quyền y hệt UI). Nghĩa là **toàn bộ
Cơ chế B hiện KHÔNG demo được trên máy Oppo CPH2159 này ở dạng APK debug/trực tiếp**, dù code không
có lỗi — đây là chính sách hệ điều hành, không phải bug.

**Xác nhận bằng tay thật (12/08, không qua ADB):** người dùng tự chạm màn hình máy Oppo thật vào
Cài đặt > Trợ năng > Family Care rồi bấm nút gạt để bật — hiện **đúng y hệt hộp thoại "Chế độ cài
đặt bị hạn chế"** như khi test qua ADB, chỉ có nút OK, không có đường nào khác trên hộp thoại đó.
**Kết luận chốt: đây là chặn thật ở cấp hệ điều hành, không phải do cách ADB giả lập chạm màn hình
— thao tác tay thật cho kết quả giống hệt.**

**Hướng ra còn lại (ngoài phạm vi phiên này):**
- Ký + phát hành qua kênh được hệ thống tin cậy (vd Play Store nội bộ/closed testing) thường không bị
  áp Restricted settings — nhưng khác hẳn cách phát hành APK trực tiếp đang dùng cho đồ án.
- Máy Android khác/bản ColorOS khác có thể có menu "Cho phép cài đặt bị hạn chế" đầy đủ — **chưa có
  máy thứ 2 để đối chiếu.**

**Khuyến nghị cho phần bảo vệ:** nói rõ đây là **giới hạn nền tảng đã biết của Android 13+ đối với
app cài ngoài Play Store**, không phải thiếu sót thiết kế — và nêu nó như một hạn chế thẳng thắn của
Cơ chế B, tương tự cách mục 1 đã trình bày lý do loại bỏ "chặn phím nguồn". Nếu hội đồng hỏi tại sao
không demo trực tiếp bấm nguồn 5 lần → trả lời bằng đúng phát hiện này.

**Kịch bản kiểm thử máy thật cần bổ sung vào bảng 7.2:**

| # | Kịch bản | Kỳ vọng | Kết quả 12/08 |
|---|---|---|---|
| 13 | Bật Trợ năng cho `EmergencySosWatcherService`, bấm nguồn 5 lần | Màn Emergency SOS của máy hiện, **sau đó** `SOSScreen(immediate)` mở đè lên, SOS gửi tới BE không cần chạm tay | **Không làm được** — bị "Chế độ cài đặt bị hạn chế" chặn từ bước bật Trợ năng, xem 13.7 |
| 14 | Chưa bật Trợ năng, bấm nguồn 5 lần | Chỉ có màn Emergency SOS của máy, app không phản ứng gì (đúng thiết kế, không phải lỗi) | **Đã test thật (12/08)** — bấm nguồn 5 lần, Trợ năng chưa bật (`enabled_accessibility_services` rỗng, xác nhận qua `adb shell settings get`), app không phản ứng gì, đúng thiết kế |
| 15 | Bấm nguồn 5 lần 2 lần liên tiếp trong 30 giây | Lần 2 bị cooldown chặn, không gửi 2 SOS trùng | Chưa test được (phụ thuộc ca 13) |
| 16 | Test trên máy KHÔNG phải ColorOS (nếu có) | Tính năng im lặng không hoạt động, không crash | Chưa có máy khác để test |

**Xác nhận thật ca 14 (12/08):** lúc màn Emergency SOS đang hiện, `adb shell dumpsys activity
activities` bắt được `topResumedActivity=ActivityRecord{... com.oplus.sos/.ui.EmergencyCallDetailActivity ...}`
— **lần đầu tiên tên lớp đầy đủ được xác nhận bằng log thật** (`com.oplus.sos.ui.EmergencyCallDetailActivity`),
không còn chỉ dựa vào trí nhớ như ghi ở 13.6. Lớp này chứa chuỗi `"Emergency"` nên khớp đúng với cách
so khớp lỏng (substring) mà `EmergencySosMatcher` đang dùng — **giả định thiết kế ban đầu đúng**.
Màn hình hiện đúng như mô tả ở mục 1.1: tiêu đề "SOS khẩn cấp", 3 số 113/115/114.
