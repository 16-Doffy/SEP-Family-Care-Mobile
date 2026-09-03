# Báo cáo: tinh chỉnh ngưỡng phát hiện té ngã (fall detection)

**Ngày:** 2026-09-03
**Yêu cầu từ:** Nhật (Leader) — "fall detection khó trigger, phải va/đập khá mạnh mới đạt
`impactThreshold = 25`, nên lúc rơi nhẹ có lúc detect được có lúc không".
**Phạm vi:** CHỈ tinh chỉnh ngưỡng. Không đụng luồng SOS, foreground service, đếm ngược/huỷ,
API, wake lock, cài đặt SOS, shake detection.

---

## 1. Giá trị tinh chỉnh — trước / sau

| Tham số | Trước | Sau | Ý nghĩa thay đổi |
|---|---|---|---|
| `freeFallThreshold` | 6.0 m/s² | **7.0 m/s²** | Nhận pha rơi tự do "nông" hơn (0.61g → 0.71g) |
| `minFreeFall` | 80 ms | **60 ms** | Chấp nhận pha rơi ngắn hơn |
| `impactThreshold` | 25.0 m/s² | **19.0 m/s²** | Va đập nhẹ hơn vẫn tính (2.55g → 1.94g) |
| `impactWindow` | 900 ms | **1200 ms** | Va đập được phép đến muộn hơn |
| `cooldown` | 30 s | **30 s** | Giữ nguyên theo yêu cầu |

Cả 4 thay đổi đều đi theo hướng **nới lỏng**, nên độ nhạy tăng cộng dồn chứ không bù trừ nhau.
Xem phần 5 để biết các chốt chặn báo động giả còn lại.

---

## 2. Danh sách file đã sửa

| File | Nội dung sửa |
|---|---|
| `android/app/src/main/kotlin/com/familycare/family_care_flutter/FallDetector.kt` | 4 giá trị mặc định + viết lại KDoc (bỏ câu "giữ nguyên 25.0 m/s²" nay đã sai, ghi rõ lý do hạ 25.0 → 19.0 kèm mốc ngày) |
| `lib/services/fall_detector_service.dart` | 4 giá trị mặc định trong `FallDetectionTuning` + cập nhật doc comment + sửa sơ đồ ASCII (`~25` → `~19`) |
| `android/app/src/test/kotlin/com/familycare/family_care/FallDetectorTest.kt` | Sửa 1 test vỡ, sửa 3 comment sai, thêm 5 test mới |
| `test/fall_detection_test.dart` | Sửa 1 test vỡ, sửa 1 comment sai, thêm 7 test mới |
| `PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md` | Cập nhật đoạn mô tả ngưỡng (dòng 104-107) — trước đây ghi `6.0 / 25.0 / 900ms` như là hiện trạng |

**KHÔNG sửa:** `SosEmergencyFlowService.kt`, `SosGuardService.kt`, `SosAlertLauncher.kt`,
`ShakeDetector.kt`, `sos_provider.dart`, `sos_settings_screen.dart`, `family_shell.dart`,
`fall_countdown_dialog.dart` và toàn bộ tầng API.

`KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` cũng nhắc ngưỡng cũ (`3.0 / 100ms / 25.0 / 900ms`)
nhưng **cố ý giữ nguyên** — đó là tài liệu kế hoạch có mốc ngày, ghi lại trạng thái tại thời điểm
11/08, không phải tài liệu mô tả hiện trạng.

---

## 3. Một test ĐÃ VỠ vì `impactWindow` và đã được sửa đúng cách

Test chống báo nhầm `va đập đến quá muộn sau khi hết rơi` (có ở **cả hai** ngôn ngữ) dùng chuỗi
mẫu: pha rơi kết thúc ở `t = 300ms`, va đập `30 m/s²` ở `t = 1400ms` → khoảng cách **1100 ms**.

- Cửa sổ cũ 900ms → 1100 > 900 → bị loại (đúng ý định của test).
- Cửa sổ mới 1200ms → 1100 < 1200 và 30 ≥ 19 → **TRIGGER**, test fail.

Đã dời mẫu va đập sang `t = 1700ms` (1400ms > 1200ms) để test giữ đúng ý nghĩa ban đầu, **thay vì
sửa `expect`** — đây là test chống báo động giả, hạ kỳ vọng của nó chính là làm mất chốt chặn.

Đồng thời sửa 4 comment đã sai từ trước: `// 40ms < minFreeFall 100ms` (thực tế lúc đó là 80),
`// 1100ms > impactWindow 900ms`, `// dưới ngưỡng 25`, và comment "không bao giờ xuống dưới 6.0"
trong test đi bộ.

---

## 4. Test đã sửa / thêm mới

### Dart — `test/fall_detection_test.dart` (11 → 18 test)

| Test | Loại |
|---|---|
| `rơi tự do 6–7 m/s² rồi va đập ~20 m/s² → phát hiện té ngã` | **Mới** — đúng ca Nhật yêu cầu; bộ ngưỡng cũ bỏ sót hoàn toàn |
| `va đập đúng bằng ngưỡng 19.0 → vẫn tính là ngã` | **Mới** — khoá biên `>=` |
| `va đập đến ở mép cuối cửa sổ 1200ms → vẫn tính là ngã` | **Mới** — khoá biên trên của cửa sổ |
| `biên độ chạm 7.5 m/s² (chưa dưới ngưỡng 7.0) → không phát hiện` | **Mới** — chuyển động không có pha rơi hợp lệ |
| `ngồi phịch xuống ghế (va đập ~15 m/s²) → không phát hiện` | **Mới** — chốt chặn của ngưỡng 19 |
| `đi lại bình thường → không phát hiện` | **Mới** — đồng bộ với bản Kotlin |
| `cooldown chặn cả cú ngã mềm đi theo ngay sau đó` | **Mới** |
| `giá trị mặc định khớp với FallDetector.kt phía Android` | **Mới** — khoá cứng 5 con số, ai đổi một bên mà quên bên kia sẽ thấy ngay |
| `va đập đến quá muộn sau khi hết rơi → không phát hiện` | **Sửa** (1400 → 1700ms) |
| `rơi tự do quá ngắn (cú xóc) → không phát hiện` | Giữ nguyên, sửa comment |
| `rơi tự do nhưng hạ cánh nhẹ → không phát hiện` | Giữ nguyên |
| `rung mạnh mà KHÔNG có pha rơi tự do → không phát hiện` | Giữ nguyên |

### Kotlin — `FallDetectorTest.kt` (12 → 17 test)

Thêm bản đối ứng của các ca trên: `roi tu do 6 den 7 roi va dap khoang 20…`,
`va dap dung bang nguong 19…`, `va dap o mep cuoi cua so 1200ms…`,
`bien do cham 7 phay 5 chua duoi nguong…`, `cooldown chan ca cu nga mem…`;
sửa `va dap den qua muon…` (1400 → 1700ms).

4 ca Nhật yêu cầu đều đã có ở **cả hai** ngôn ngữ:

1. Rơi tự do 6–7 m/s² rồi va đập ~19–22 m/s² → **trigger** ✅
2. Chuyển động không có pha rơi hợp lệ → **không trigger** ✅
3. Rơi tự do mà không có va đập → **không trigger** ✅
4. Cooldown vẫn chặn trigger trùng → ✅

### Kết quả chạy

```
flutter test test/fall_detection_test.dart              →  18/18 pass
flutter test (toàn bộ)                                  →  637/637 pass
gradlew :app:testDebugUnitTest --tests *FallDetectorTest*
                                                        →  17 tests, 0 failures, 0 errors
```

---

## 5. Foreground và background còn đồng bộ không?

**Số thì đồng bộ tuyệt đối** — 5 giá trị giống hệt nhau ở hai file, và nay đã có test khoá lại
phía Dart (`giá trị mặc định khớp với FallDetector.kt phía Android`). Thuật toán máy trạng thái
(`idle → freeFall → awaitingImpact`) vẫn giống nhau từng bước.

**Nhưng hành vi thì không hoàn toàn giống, vì tần số lấy mẫu khác nhau:**

- Bản Dart (`FallDetectorService`) lấy mẫu **mỗi 50 ms**.
- Bản native (`SosGuardService`) dùng `SENSOR_DELAY_GAME`, lưới mẫu **~20 ms**.

Hệ quả cụ thể: trên lưới 50 ms, khoảng rơi đo được chỉ có thể là 50, 100, 150 ms… nên **60 ms và
80 ms loại/nhận y hệt nhau** (đều loại 50 ms, đều nhận 100 ms). Tức là thay đổi
`minFreeFall 80 → 60` **chỉ thực sự có tác dụng ở bản Android native**, còn phía Flutter là no-op.
Đã ghi chú rõ điều này trong doc comment của `FallDetectionTuning` để lần sau không ai mất thời
gian đi tìm "vì sao sửa mà không thấy khác". Vẫn giữ hai bên bằng nhau về cấu hình đúng theo yêu cầu.

Ba tham số còn lại (`freeFallThreshold`, `impactThreshold`, `impactWindow`) có tác dụng như nhau ở
cả hai bản.

---

## 6. Rủi ro cần biết trước khi test thực tế

1. **Kịch bản nghiệm thu có thể vẫn chưa đạt.** Yêu cầu là "thả xuống đệm/bề mặt mềm, không đập
   máy". Đệm hấp thụ xung nên đỉnh gia tốc thực tế thường chỉ 12–16 m/s² — có thể vẫn **dưới 19**.
   Code đã sẵn công cụ đo: `SosGuardService` in log mỗi 10 giây
   `sensor alive: N mẫu/10s |a| min=… max=…`, và in mỗi lần đổi pha `fall phase: idle -> free_fall`.
   Thả máy xuống đệm 10 lần rồi đọc `max` là biết chính xác cần ngưỡng bao nhiêu, thay vì đoán.

2. **Ngưỡng 19.0 đang là chốt chặn cuối.** Test `ngồi phịch xuống ghế` dùng va đập 15 m/s² — hạ
   ngưỡng xuống 15 là ca ngồi phịch bắt đầu báo giả. Khoảng an toàn còn lại chỉ là 15 → 19.

3. **Ngưỡng 7.0 sát nhịp đi bộ.** Đáy mỗi bước chân rơi vào khoảng 6.8–7.2 m/s², tức là đã **lọt
   vào** pha rơi tự do. Thứ duy nhất chặn lại là phải có va đập ≥ 19 ngay sau đó (test
   `đi lại bình thường` khoá ca này). Nếu thấy báo giả khi đi bộ/chạy, tham số cần lùi trước tiên
   là `freeFallThreshold`, không phải `impactThreshold`.

4. **Báo giả lúc chạy nền nguy hiểm hơn lúc app mở.** Khi máy trong túi, luồng native tự đếm ngược
   rồi **tự gửi SOS thật** cho cả nhà; người dùng chỉ có rung (400ms × 3) để nhận biết mà bấm huỷ.
   Nên test kỹ ca "để máy trong túi đi bộ 10 phút" trước khi demo.

5. **Trùng trigger khi app đang mở.** `SosGuardService` không dừng khi app lên foreground, nên
   detector Dart và detector native cùng ăn một cú ngã. Hiện chỉ được chặn một phần bởi kiểm tra
   `sos.activeAlerts.any(isMine)` trong `family_shell.dart`. Nhạy hơn thì xác suất trùng cao hơn —
   cần test có chủ đích. **Đây là vấn đề có sẵn, không do lần sửa này tạo ra**, và nằm ngoài phạm
   vi "chỉ chỉnh ngưỡng" nên chưa đụng tới.

6. **Shake vẫn giữ ngưỡng 25.** `ShakeDetector(threshold = 25f)` không đổi, nên hai tính năng nay
   lệch chuẩn nhau (fall nhạy hơn shake). Không xung đột về logic — shake cần 4 đỉnh ≥ 25 trong
   2 giây, còn fall bắt buộc phải có pha rơi trước đó — nhưng cần biết khi đọc log.

---

## 7. Kịch bản test thực tế đề nghị

1. Bật "Theo dõi té ngã khi chạy nền" trong Cài đặt SOS, khoá màn hình, chờ 2 phút.
2. `adb logcat -s SosGuardService` — xác nhận dòng `sensor alive:` vẫn in đều. Nếu **ngừng in**
   thì lỗi nằm ở tầng đánh thức CPU, không phải ở ngưỡng — đừng chỉnh số tiếp.
3. Thả máy xuống đệm/thảm từ độ cao ~1 m, **không đập**. Ghi lại `max` trong log.
4. Lặp 10 lần, đếm tỉ lệ trigger.
5. Đối chứng báo giả: bỏ máy vào túi quần đi bộ 10 phút, ngồi phịch xuống ghế 5 lần, đặt máy
   xuống bàn mạnh tay 5 lần → kỳ vọng **0 lần** trigger.
6. Lặp lại bước 3 với app đang mở (foreground) để kiểm tra ca trùng trigger ở mục 6.5.

---

## 8. Ghi chú môi trường build (Windows)

Hai lệnh cần chạy trước khi test nếu gặp lỗi `Unable to delete directory` / `failed to delete a
directory`:

```
attrib -R "ios\Flutter\ephemeral\*" /S /D
attrib -R "build\*" /S /D
```

Và `gradlew.bat` cần `JAVA_HOME` (chưa set cấp User):
`$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"`.
