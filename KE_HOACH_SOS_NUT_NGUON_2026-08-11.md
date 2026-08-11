# Kế hoạch build — Kích hoạt SOS bằng cách bấm nút nguồn 5 lần

**Ngày lập:** 2026-08-11 · **Người lập:** phiên Claude Code (nhánh `giap`) · **Người thực hiện:** Codex
**Trạng thái repo lúc lập kế hoạch:** `origin/giap` = `55ac2bb`, `flutter test` 440/440 pass,
`flutter analyze --no-fatal-infos` 0 error.

---

## 0. Bối cảnh và mục tiêu

**Vấn đề người dùng nêu:** người đang trong tình huống khẩn cấp thật sự có thể **không mở nổi điện
thoại, không mở nổi app** — chỉ còn khả năng bấm nút nguồn. Cần một cách kích hoạt SOS chỉ bằng
thao tác đó.

**Đã có sẵn (làm trong ngày 11/08, đã push):**
- Route phẳng **`/sos-quick`** → `SOSScreen(autoTrigger: true)`: tự đếm ngược **3 giây** rồi gửi SOS,
  có nút **HỦY** to. Dùng lại nguyên vẹn được cho kế hoạch này.
- Lối tắt màn hình chính (`res/xml/shortcuts.xml`) mở đúng deep link `familycare://app/sos-quick`.
- `SosProvider.sendSos()` + stream vị trí + buffer offline đã chạy ổn định.

**Mục tiêu của kế hoạch này:** bấm nút nguồn **5 lần liên tiếp** (kể cả khi màn hình đang khóa) →
hiện màn SOS đếm ngược đè lên màn khóa → không bấm HỦY thì tự gửi SOS.

**Ngoài phạm vi:** iOS (repo chưa có thư mục `ios/`); Wear OS (đồng hồ đã có nút SOS riêng).

---

## 1. Giới hạn kỹ thuật — đọc kỹ trước khi code

Đây là phần quyết định vì sao kiến trúc phải làm như mục 2, đừng bỏ qua.

### 1.1 Không có cách nào bắt trực tiếp phím nguồn

| Cách | Kết luận |
|---|---|
| `Activity.onKeyDown(KEYCODE_POWER)` | ❌ Chỉ app hệ thống nhận được. App thường không bao giờ thấy sự kiện này. |
| `AccessibilityService.onKeyEvent()` | ❌ Hệ thống lọc phím nguồn **trước** khi phân phối cho accessibility. Ngoài ra Play Store cấm dùng accessibility sai mục đích. |
| `MediaSession` / phím âm lượng | ❌ Không nhận được khi màn hình tắt/khóa. |
| Emergency SOS 5 lần bấm của Android | ❌ Là tính năng **hệ thống**, app không hook vào được. |

### 1.2 Cách duy nhất chạy được: đếm broadcast bật/tắt màn hình

Mỗi lần bấm nút nguồn → màn hình đổi trạng thái → hệ thống phát
`Intent.ACTION_SCREEN_ON` hoặc `ACTION_SCREEN_OFF`. Đếm số lần trong cửa sổ thời gian ngắn là suy
ra được số lần bấm.

**Ràng buộc bắt buộc đi kèm:**

1. **Không khai được trong manifest.** Hai broadcast này là "protected broadcast", chỉ nhận được
   qua `context.registerReceiver()` lúc chạy. Nghĩa là **tiến trình app phải đang sống**.
2. Muốn tiến trình sống khi app đã đóng → **bắt buộc foreground service** (Android 8+), kèm **thông
   báo thường trực người dùng không tắt được**.
3. `targetSdk = 36` (Android 16) nên luật chặt: phải khai `foregroundServiceType` và xin đúng quyền
   tương ứng, xem mục 4.

### 1.3 Những thứ CHẮC CHẮN sẽ có người hỏi lúc bảo vệ — chuẩn bị câu trả lời

- **"Sao phải có thông báo thường trực?"** → Android bắt buộc, không có cách tắt. Đây là đánh đổi
  của mọi app chạy nền, không phải lựa chọn thiết kế.
- **"Máy Xiaomi/Oppo tắt app thì sao?"** → Các hãng này giết service nền rất mạnh. Người dùng phải
  tự vào Cài đặt → Pin → bỏ tối ưu hóa cho app. **App phải hướng dẫn việc này**, xem mục 5.4.
  Đây là giới hạn của hệ điều hành, không phải bug.
- **"Có trùng với Emergency SOS của Android không?"** → Có thể trùng nếu người dùng bật tính năng
  đó. Hai cái chạy song song, không xung đột. Xem mục 6.2.

---

## 2. Kiến trúc đề xuất

```
[Bấm nguồn x5]
      │
      ▼
ACTION_SCREEN_ON/OFF  ──►  PowerButtonReceiver (Kotlin, đăng ký lúc chạy)
                                   │  đếm trong cửa sổ 3 giây
                                   ▼
                           SosTriggerService (foreground service, Kotlin)
                                   │  đủ 5 lần
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

### 2.1 Vì sao chọn hướng này thay vì gọi API thẳng trong Kotlin

Hướng thay thế là để service Kotlin tự đọc token rồi gọi REST. **Không chọn**, vì:

- Token nằm trong `flutter_secure_storage`; đọc từ Kotlin phải hiểu cách plugin đó mã hóa, dễ vỡ khi
  nâng version plugin.
- Phải viết lại logic refresh token 401, lấy `familyId`, lấy GPS, xử lý lỗi — **nhân đôi** những thứ
  `ApiClient`/`SosProvider` đã làm và đã test.
- Người dùng sẽ **không thấy gì** trước khi SOS bay đi → chạm nhầm là báo động giả thật, không hủy
  được.

Hướng đã chọn tái dùng 100% phần Dart đã chạy ổn định. Kotlin chỉ làm đúng một việc: **đếm và mở màn
hình**.

---

## 3. Các bước thực hiện

> ⚠️ **Làm bước 3.0 TRƯỚC.** Nếu bước này thất bại trên máy demo thì toàn bộ kế hoạch không có giá
> trị, và biết sớm sẽ đỡ tốn công.

### 3.0 Spike đo thực tế (bắt buộc, làm đầu tiên)

**Mục đích:** xác nhận bấm nguồn 5 lần thật sự sinh ra 5 broadcast trên **máy sẽ dùng để demo**.
Một số máy bấm 2 lần mở camera, bấm nhanh quá màn hình không kịp đổi trạng thái → số broadcast
không khớp số lần bấm.

**Cách làm nhanh nhất, chưa cần viết service:**

1. Tạo nhánh `sos-power-button` từ `giap`.
2. Viết tạm một `BroadcastReceiver` đăng ký trong `MainActivity.onCreate()`, mỗi lần nhận
   `SCREEN_ON`/`SCREEN_OFF` thì `Log.d("SOSPWR", "...")` kèm timestamp.
3. Mở app, bấm nguồn 5 lần với các nhịp khác nhau (nhanh nhất có thể / khoảng 0,5 giây một lần).
4. `adb logcat -s SOSPWR` và đếm.

**Ghi lại kết quả vào file này** (số broadcast nhận được / số lần bấm, ở mỗi nhịp). Kết quả quyết
định tham số ở mục 6.1.

**Nếu số broadcast không ổn định:** dừng lại, báo lại trước khi làm tiếp — có thể phải đổi sang
ngưỡng 4 lần, hoặc chuyển sang phương án lắc mạnh ở mục 8.

### 3.1 Foreground service

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/SosTriggerService.kt`

Nhiệm vụ:
- `onCreate()`: tạo notification channel, `startForeground()` với thông báo thường trực.
- Đăng ký `PowerButtonReceiver` bằng `registerReceiver()` (KHÔNG khai trong manifest).
- `onDestroy()`: `unregisterReceiver()`.
- `onStartCommand()` trả `START_STICKY` để hệ thống dựng lại khi bị kill vì thiếu bộ nhớ.

Thông báo thường trực:
- Channel riêng, `IMPORTANCE_LOW` (không kêu, không rung — nó nằm đó cả ngày).
- Nội dung gợi ý: tiêu đề "Bảo vệ SOS đang bật", nội dung "Bấm nút nguồn 5 lần để gửi cảnh báo".
- Có action **"Tắt"** để người dùng dừng service ngay từ thanh thông báo. **Bắt buộc có** — không
  cho người dùng đường thoát là thiết kế tồi và sẽ bị hỏi lúc bảo vệ.

### 3.2 Bộ đếm

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/PowerPressCounter.kt`

Tách riêng **class thuần**, không phụ thuộc `Context`/`SystemClock` (nhận timestamp qua tham số) để
**unit test được bằng JVM test, không cần máy thật**:

```kotlin
class PowerPressCounter(
    private val requiredPresses: Int = 5,
    private val windowMs: Long = 3000,
) {
    private val timestamps = ArrayDeque<Long>()

    /** Trả true đúng MỘT lần khi đủ số lần bấm trong cửa sổ. */
    fun onPress(nowMs: Long): Boolean {
        timestamps.addLast(nowMs)
        while (timestamps.isNotEmpty() && nowMs - timestamps.first() > windowMs) {
            timestamps.removeFirst()
        }
        if (timestamps.size >= requiredPresses) {
            timestamps.clear()   // reset để không bắn liên tiếp
            return true
        }
        return false
    }
}
```

**Test JVM bắt buộc** (`android/app/src/test/kotlin/.../PowerPressCounterTest.kt`):
- Đủ 5 lần trong 3 giây → `true` đúng 1 lần.
- 5 lần nhưng rải trong 10 giây → không bắn.
- 10 lần liên tiếp → bắn đúng 2 lần, không phải 6 lần.
- Bắn xong bấm tiếp 4 lần → không bắn (đã reset).

> Repo hiện **chưa có** thư mục test JVM cho Android. Cần thêm `testImplementation("junit:junit:4.13.2")`
> vào `android/app/build.gradle.kts`. Đây là dependency **chỉ dùng cho test**, không vào APK.

### 3.3 Receiver

**File mới:** `android/app/src/main/kotlin/com/familycare/family_care/PowerButtonReceiver.kt`

- Nhận `ACTION_SCREEN_ON` và `ACTION_SCREEN_OFF`, mỗi cái tính là **1 lần bấm**.
- Gọi `PowerPressCounter.onPress(SystemClock.elapsedRealtime())`.

> Dùng `elapsedRealtime()` chứ **không** dùng `System.currentTimeMillis()`: cái sau nhảy khi đổi
> múi giờ hoặc đồng bộ NTP, làm cửa sổ đếm sai.

- Khi trả `true` → gọi hàm kích hoạt ở mục 3.4.

### 3.4 Mở màn SOS đè lên màn khóa

Đây là phần **khó nhất và dễ sai nhất**, làm cẩn thận.

**Vấn đề:** Android 10+ chặn app khởi chạy Activity từ nền. Foreground service **không** tự động
được miễn trừ.

**Cách đúng (giống app báo thức / cuộc gọi đến):** bắn notification có `setFullScreenIntent()`:

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

Channel cho thông báo này phải **`IMPORTANCE_HIGH`**, khác channel của thông báo thường trực ở 3.1.

**Phía Activity** — `MainActivity.kt` thêm vào `onCreate()`:

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
    setShowWhenLocked(true)
    setTurnScreenOn(true)
}
```

> ⚠️ **Điểm cần Codex tự xác minh, đừng tin sẵn:** từ Android 14 (API 34), quyền
> `USE_FULL_SCREEN_INTENT` **chỉ được cấp mặc định** cho app thuộc nhóm gọi điện/báo thức. App khác
> phải xin người dùng qua `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`. Dự án đang `targetSdk 36` nên
> **rất có thể rơi vào diện phải xin**. Kiểm tra bằng
> `NotificationManager.canUseFullScreenIntent()` và nếu `false` thì đưa người dùng sang màn cài đặt
> đó. **Không kiểm tra chỗ này là tính năng chết im trên máy Android 14+.**

**Fallback bắt buộc** khi không có quyền full-screen intent: vẫn bắn notification `IMPORTANCE_HIGH`
kèm action "MỞ SOS". Người dùng phải chạm một lần — kém hơn nhưng còn hơn không có gì.

### 3.5 Bật/tắt service từ Dart

**File mới:** `lib/services/sos_trigger_service.dart` — bọc `MethodChannel`
(`com.familycare.family_care/sos_trigger`) với 3 hàm: `start()`, `stop()`, `isRunning()`.

**File sửa:** `MainActivity.kt` — đăng ký `MethodChannel` handler.

**File sửa:** `lib/screens/shared/sos_settings_screen.dart` — thêm công tắc
**"Bấm nút nguồn 5 lần để gửi SOS"**, kèm dòng giải thích ngắn về thông báo thường trực.

> ⚠️ Đây là cài đặt **cục bộ trên máy** (`SharedPreferences`), **KHÔNG** đẩy lên BE.
> `UpdateSosSettingsDto` không có field nào cho việc này, và theo Rule 2 của repo thì **không được
> tự thêm field hay đoán API**. Nếu thấy cần đồng bộ nhiều thiết bị thì viết đề xuất BE riêng, đừng
> tự chế.

### 3.6 Khởi động lại sau khi tắt/bật máy (tùy chọn)

Thêm `RECEIVE_BOOT_COMPLETED` + receiver `BOOT_COMPLETED` để bật lại service.

**Đánh giá:** nên làm nếu còn thời gian, vì người già tắt/bật máy là mất tính năng mà không biết.
Nhưng **không chặn demo** — có thể để phase sau.

---

## 4. Manifest và quyền (targetSdk 36 — làm sai là crash lúc chạy)

Thêm vào `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<!-- chỉ khi làm mục 3.6 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

`POST_NOTIFICATIONS` **đã có sẵn**, không thêm lại.

Khai service **bên trong `<application>`**:

```xml
<service
    android:name=".SosTriggerService"
    android:exported="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Phát hiện chuỗi bấm nút nguồn để gửi cảnh báo khẩn cấp SOS" />
</service>
```

**Lưu ý về `specialUse`:** nếu sau này phát hành lên Google Play thì loại này bị Google xét duyệt
thủ công. Đồ án phát hành APK trực tiếp nên **không vướng**, nhưng phải biết để không hứa nhầm.

Đã cân nhắc và loại các loại khác: `health` cần quyền cảm biến sức khỏe không liên quan;
`location` sai bản chất vì service này không theo dõi vị trí.

---

## 5. Trải nghiệm người dùng

### 5.1 Chống báo động giả — quan trọng nhất

Nút nguồn bị bấm nhầm rất dễ (trong túi, trẻ con nghịch). Bắt buộc:
- **Giữ nguyên đếm ngược 3 giây + nút HỦY** của `/sos-quick`. Không được bỏ qua để "cho nhanh".
- Màn hình bật sáng + rung khi kích hoạt, để người bấm nhầm biết mà hủy.

### 5.2 Nội dung thông báo thường trực
Ngắn, không gây lo lắng: **"Bảo vệ SOS đang bật — bấm nút nguồn 5 lần để gửi cảnh báo"**, kèm nút
**"Tắt"**.

### 5.3 Lần đầu bật công tắc
Hiện dialog nói rõ 3 điều: (1) sẽ có thông báo thường trực không tắt được, (2) cần cho phép chạy
nền, (3) hướng dẫn bỏ tối ưu hóa pin.

### 5.4 Hướng dẫn bỏ tối ưu hóa pin
Mở thẳng màn hệ thống bằng `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`.

> ⚠️ **KHÔNG** dùng `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (loại hiện hộp thoại xin trực
> tiếp) — Google Play cấm với app thường và có thể bị gỡ. Chỉ mở màn cài đặt để người dùng tự chọn.

---

## 6. Tham số và tình huống biên

### 6.1 Tham số mặc định (điều chỉnh theo kết quả spike 3.0)

| Tham số | Giá trị | Lý do |
|---|---|---|
| Số lần bấm | 5 | Đúng yêu cầu; đủ hiếm để không chạm nhầm |
| Cửa sổ thời gian | 3000 ms | Người già bấm chậm hơn người trẻ; 2 giây có thể quá gắt |
| Nghỉ sau khi bắn | 30 giây | Trùng `cooldown` của `FallDetectionTuning`, giữ nhất quán |

### 6.2 Trùng với Emergency SOS của hệ thống
Nếu người dùng bật Emergency SOS của Android thì bấm 5 lần sẽ kích hoạt **cả hai**. Không xung đột
kỹ thuật. **Phải nói trước khi demo** để hội đồng không tưởng là lỗi.

### 6.3 Đang có SOS `ACTIVE`
`SOSScreen` đã tự xử lý: có alert đang chạy thì hiện màn theo dõi thay vì tạo cái mới. Không cần
làm gì thêm — **nhưng phải test lại** vì lần này vào từ đường khác.

### 6.4 Chưa đăng nhập / chưa có gia đình
`computeRedirect` đã chặn sẵn: `/sos-quick` khi chưa đăng nhập → `/login`; chưa có gia đình →
`/family-setup`. Xem `test/sos_quick_shortcut_test.dart`. Không sửa gì.

---

## 7. Kiểm thử

### 7.1 Tự động (bắt buộc)
- **JVM test cho `PowerPressCounter`** — xem 3.2. Đây là phần logic duy nhất test máy được, phải phủ kỹ.
- `flutter analyze --no-fatal-infos` → **0 error**.
- `flutter test` → **không được thấp hơn 440**.
- `flutter build apk --debug` phải chạy được (đang thêm service + quyền, dễ vỡ manifest merge).

### 7.2 Máy thật (không tự động được)
| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Bật công tắc → xem thanh thông báo | Có thông báo thường trực, có nút "Tắt" |
| 2 | Khóa màn, bấm nguồn 5 lần | Màn SOS hiện **đè lên màn khóa**, đang đếm ngược |
| 3 | Bấm HỦY | Không có cảnh báo nào được tạo trên BE |
| 4 | Để đếm hết | Người nhà nhận được SOS |
| 5 | Vuốt tắt app khỏi đa nhiệm, bấm 5 lần | Vẫn chạy (service sống) |
| 6 | Bấm 5 lần rải trong 10 giây | **Không** kích hoạt |
| 7 | Kích hoạt 2 lần liên tiếp trong 30 giây | Lần 2 bị chặn bởi cooldown |
| 8 | Tắt công tắc | Thông báo biến mất, bấm 5 lần không còn tác dụng |
| 9 | Máy Xiaomi/Oppo, để yên 30 phút | Ghi lại service còn sống không (kỳ vọng: có thể bị giết) |
| 10 | Android 14+ chưa cấp full-screen intent | Rơi về fallback ở 3.4, không im lặng |

**Ghi kết quả kịch bản 9 và 10 vào `docs/DEMO_GUIDE.md`** — hai cái này quyết định có nên demo tính
năng này trước hội đồng hay không.

---

## 8. Phương án dự phòng nếu spike 3.0 thất bại

Nếu số broadcast không khớp số lần bấm trên máy demo, **đừng cố chỉnh tham số cho vừa** — chuyển
sang **lắc mạnh điện thoại**:

- Repo đã có `sensors_plus` và `FallDetectorService` với máy trạng thái thuần đã test kỹ
  (`test/fall_detection_test.dart`) — dùng lại được ngay cơ chế đó.
- Chạy trong cùng foreground service ở mục 3.1, phần còn lại của kế hoạch **giữ nguyên**.
- Với người không mở nổi điện thoại thì lắc mạnh có khi còn dễ hơn bấm nguồn 5 nhịp chuẩn.

**Lợi ích kèm theo:** hiện `FallDetectorService` **chỉ chạy khi app đang mở** — giới hạn đã ghi rõ
trong chính file đó (dòng 33-35) và trong `sos_settings_screen`. Có foreground service rồi thì
`autoCreateAlertFromFall` chạy được cả khi app đóng, **sửa luôn một giới hạn đang tồn tại**.
Cân nhắc làm việc này ngay cả khi phương án nút nguồn thành công.

---

## 9. Quy tắc bắt buộc của repo (đọc `CLAUDE.md` trước khi bắt đầu)

1. **Preview trước khi sửa** — mô tả file sẽ đổi, logic cũ → mới, rủi ro; chỉ sửa sau khi user xác
   nhận. Áp dụng cho **mọi** thay đổi, kể cả sửa nhanh.
2. **Không mock/workaround khi BE thiếu.** Tính năng này thuần client, **không cần BE gì cả** — nếu
   phát sinh nhu cầu thì viết đề xuất BE riêng, không tự chế field.
3. **Tiếng Việt** cho toàn bộ comment, tài liệu, commit message.
4. **Commit:** tác giả chỉ Giáp, **KHÔNG** thêm trailer `Co-Authored-By: Claude`. Mỗi commit một
   concern, tách code khỏi docs. Verify bằng `git log --format='%an <%ae> | %(trailers)'`.
5. **KHÔNG đụng vùng AI Chatbot** (`lib/models/ai_chatbot.dart`,
   `lib/screens/shared/ai_assistant_screen.dart`, `lib/providers/ai_chatbot_provider.dart`,
   `test/ai_*.dart`) — do Duy phụ trách trên nhánh `NDuy`.
6. **Đang sát đợt bảo vệ hội đồng** — ưu tiên ổn định. Khi có nhiều cách làm, chọn cách **ít thay
   đổi nhất**, không phải cách "đẹp nhất về kiến trúc".

---

## 10. Thứ tự làm và điểm dừng

| Bước | Nội dung | Dừng lại báo cáo? |
|---|---|---|
| 1 | Spike 3.0 đo broadcast trên máy demo | ✅ **Bắt buộc dừng, báo kết quả** |
| 2 | `PowerPressCounter` + JVM test | Không |
| 3 | Service + receiver + manifest, build APK chạy được | Không |
| 4 | Full-screen intent + `showWhenLocked` | ✅ **Dừng nếu Android 14+ chặn quyền** |
| 5 | MethodChannel + công tắc trong Cài đặt SOS | Không |
| 6 | Chạy bảng kiểm thử 7.2 trên máy thật | ✅ **Dừng, báo kết quả kịch bản 9 và 10** |
| 7 | Cập nhật `docs/DEMO_GUIDE.md` | Không |

**Ước lượng:** bước 1 khoảng 30 phút. Bước 2-5 là phần chính. Bước 6 phải làm trên máy thật, không
có cách rút ngắn.

---

## 11. Những gì kế hoạch này KHÔNG giải quyết — nói thẳng

- **Máy đã tắt nguồn hẳn** → không có cách nào. Không phần mềm nào làm được.
- **OEM giết service** → giảm thiểu được bằng hướng dẫn bỏ tối ưu pin, **không loại bỏ được**.
- **Không có mạng** → SOS không gửi đi được. `SOSScreen` đã có dialog báo lỗi kèm tọa độ GPS để
  người dùng tự chia sẻ tay; buffer vị trí offline đã làm ở commit `ae69a45` chỉ áp dụng cho cảnh
  báo **đã tạo được**, không giúp cho việc tạo mới.
- **Bấm nhầm** → giảm bằng đếm ngược 3 giây, không loại bỏ hẳn. BE có sẵn trạng thái `FALSE_ALARM`
  và `cancel` để đóng lại.
