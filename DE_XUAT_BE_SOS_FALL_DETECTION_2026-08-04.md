# Báo cáo & đề xuất BE — Tự cảnh báo SOS khi phát hiện té ngã

Ngày: **2026-08-04** · Người soạn: FE Mobile (nhánh `giap`)
Gửi: Nghĩa (Backend), Nhật (Leader)

---

## Phần 1 — Chuyện gì đã xảy ra (đọc phần này là đủ hiểu)

### Cái đã có từ trước

Trong `UpdateSosSettingsDto` của BE **đã có sẵn** một tuỳ chọn:

```
autoCreateAlertFromFall  (boolean)
   "Tự tạo cảnh báo SOS khi thiết bị phát hiện té ngã"
```

App điện thoại cũng **đã có** cái công tắc đó ở **Cài đặt SOS**, bật/tắt lưu lên
server bình thường.

### Vấn đề

**Công tắc đó bật lên nhưng điện thoại không làm gì cả.**

Chỉ có app trên **đồng hồ** là có đoạn code nhận biết té ngã. Mà màn hình chứa
đoạn code đó (`wear_status_screen.dart`) sau lần dựng lại giao diện đồng hồ thì
**không còn nút nào bấm vào được nữa** — code vẫn còn trong repo, vẫn biên dịch
được, nhưng người dùng không có cách nào mở tới. Nói cách khác: tính năng này
trước giờ **chưa từng chạy trên điện thoại**, và trên đồng hồ thì cũng không vào
được.

Đây là loại lỗi không có công cụ nào bắt được: `flutter analyze` báo sạch,
`flutter test` xanh, API gọi đúng — chỉ là cái công tắc không nối vào đâu.

### Cái FE vừa làm

Nối công tắc đó vào thật, trên **điện thoại**:

1. Bật công tắc → app đọc gia tốc kế của điện thoại.
2. Nhận thấy một cú ngã → hiện hộp thoại **"Bạn có ổn không?"** đếm ngược **10
   giây**.
3. Người dùng bấm **"Tôi ổn"** → không gửi gì. Bấm **"Gửi ngay"** hoặc **để hết
   10 giây** → gửi cảnh báo SOS như bình thường, kèm vị trí GPS.
4. Sau khi gửi, app tự chuyển sang tab SOS để theo dõi.

**Vì sao phải có 10 giây đếm ngược:** gia tốc kế không phân biệt được "người
ngã" với "điện thoại rơi khỏi tay" — cả hai đều cho ra cùng một dạng tín hiệu.
Không có bước đếm ngược thì rơi điện thoại một cái là báo động cả nhà. Ngược
lại, người ngã thật mà bị thương thì không bấm được gì, nên **hết giờ là gửi** —
im lặng không được coi là "tôi ổn".

### Cách nhận biết té ngã — và vì sao không dùng "rung mạnh"

Cách đơn giản nhất là đo độ rung, vượt ngưỡng thì báo. Nhưng như vậy **đi xe máy
đường xóc, chạy bộ, hay điện thoại trong túi lúc đi nhanh đều vượt ngưỡng** →
báo nhầm liên tục, người dùng sẽ tắt tính năng ngay.

Thay vào đó FE bắt đúng *hình dạng* của một cú ngã, gồm **hai pha bắt buộc, đúng
thứ tự**:

```
 độ lớn gia tốc
   ~9.8 ┤───────╮                        ╭──── nằm yên sau khi ngã
        │       │        va đập ──▶ ╱╲   │
   ~25  ┤       │                 ╱   ╲  │
        │       ╰────────╮       ╱     ╲╱
   ~0   ┤   rơi tự do    ╰──────╯
        └────────────────────────────────────▶ thời gian
```

| Pha | Điều kiện | Ý nghĩa |
|---|---|---|
| 1. Rơi tự do | độ lớn < **3 m/s²** trong ít nhất **100 ms** | Khi rơi, gia tốc kế đo được gần 0 vì mất "trọng lực biểu kiến". Nằm yên thì đo được ≈ 9.8 |
| 2. Va đập | độ lớn > **25 m/s²**, đến trong vòng **900 ms** sau khi hết pha 1 | Cú đập xuống sàn |
| Nghỉ | **30 giây** sau mỗi lần phát hiện | Tránh một cú ngã bị tính thành nhiều lần |

Thiếu một trong hai pha là **không** tính là ngã. Lắc mạnh mà chưa bao giờ rơi →
bỏ qua. Rơi rồi hạ cánh nhẹ → bỏ qua.

### Đã kiểm chứng

- **10 test tự động** cho riêng logic này (`test/fall_detection_test.dart`),
  gồm 5 test chống báo nhầm: lắc mạnh không có pha rơi, rơi quá ngắn, hạ cánh
  nhẹ, va đập đến quá muộn, và cooldown.
- `flutter analyze`: **0 error, 0 warning**.
- `flutter test`: **154/154 pass**.

### Giới hạn — phải nói đúng trong báo cáo và khi demo

| Giới hạn | Chi tiết |
|---|---|
| **Chỉ chạy khi app đang mở** | App xuống nền là tắt cảm biến. Muốn chạy nền 24/7 cần *foreground service* + quyền `FOREGROUND_SERVICE_SPECIAL_USE`, kèm một notification thường trực không tắt được, và các máy Xiaomi/Oppo/Vivo vẫn hay tắt service nền. **Không hứa "phát hiện té ngã 24/7"** |
| **Rơi điện thoại cũng bị nhận** | Đây là giới hạn vật lý của gia tốc kế, không phải lỗi. Đó là lý do có 10 giây đếm ngược |
| **Không phải thiết bị y tế** | Đây là tính năng hỗ trợ, không phải phát hiện té ngã cấp y tế. Đã ghi vào phần loại trừ phạm vi |
| **Chưa có nút điều chỉnh độ nhạy** | Ngưỡng cố định như bảng trên, vì BE chưa có field để lưu. Xem yêu cầu #2 |

### Không liên quan tới Emergency SOS của Android

Cần nói rõ để tránh hiểu sai khi báo cáo: **không thể** móc vào tính năng
Emergency SOS có sẵn của điện thoại (bấm 5 lần nút nguồn).

- Nút nguồn (`KEYCODE_POWER`) bị hệ thống Android chặn ở tầng dưới, **không bao
  giờ** tới được app của người thường.
- Emergency SOS **không phát tín hiệu công khai nào** cho app bên thứ ba. Không
  có API, không có quyền nào mở được.
- iOS thì hoàn toàn không có đường nào.

Tức là: cái FE làm là **app tự phát hiện té ngã**, chứ **không phải** "tích hợp
với Emergency SOS của điện thoại". Hai chuyện khác nhau.

---

## Phần 2 — Yêu cầu gửi Backend

### Yêu cầu #1 — Thêm giá trị `sourceType` cho cảnh báo do máy tự phát hiện — **Bắt buộc**

**Vấn đề bằng một câu:** hiện không có cách nào phân biệt "người tự bấm nút SOS"
với "máy tự phát hiện té ngã".

`CreateSosAlertDto.sourceType` hiện chỉ có:

```
MOBILE_APP | WEARABLE | SIMULATED_DEVICE
```

Cả ba đều là *thiết bị nào gửi*, không có giá trị nào nói *vì sao gửi*. Cảnh báo
do té ngã vẫn là từ điện thoại nên FE **tạm gửi `MOBILE_APP`** và ghi nguồn vào
`message` ("Phát hiện té ngã từ điện thoại — cần hỗ trợ ngay!").

**Hệ quả của cách tạm này:** màn hình duyệt cảnh báo và lịch sử SOS chỉ đọc
`sourceType`, nên hiển thị y như một lần bấm nút thủ công. Người nhà không biết
đây là cảnh báo tự động **có thể là báo nhầm**. Với một cảnh báo khẩn cấp, đó là
thông tin quan trọng.

**Đề xuất:** thêm `FALL_DETECTION` vào enum `sourceType` (cả
`CreateSosAlertDto`, `SosAlertResponseDto` và `SosAlertListItemResponseDto`):

```
MOBILE_APP | WEARABLE | SIMULATED_DEVICE | FALL_DETECTION
```

Nếu BE muốn giữ `sourceType` thuần là "thiết bị nào" thì phương án hai là thêm
một field riêng, ví dụ:

```
triggerReason: MANUAL | FALL_DETECTION   (mặc định MANUAL)
```

**FE chấp nhận cả hai hướng.** Chỉ cần chốt một hướng — FE **không tự bịa giá
trị enum** để tránh silent fail như các lần trước.

Nếu BE **không** làm mục này: FE giữ nguyên cách ghi vào `message`, nhưng phần
`[VERIFY]` này sẽ nằm lại trong báo cáo và màn cảnh báo vẫn không phân biệt được
hai loại.

### Yêu cầu #2 — Lưu độ nhạy phát hiện té ngã — **Nên có**

Ngưỡng hiện đang cố định trong code. Người già thì cần nhạy hơn, người hay chạy
nhảy thì cần bớt nhạy. Nếu BE thêm một field vào `UpdateSosSettingsDto`:

```
fallDetectionSensitivity: LOW | MEDIUM | HIGH   (mặc định MEDIUM)
```

thì FE hiện được thanh chọn độ nhạy trong Cài đặt SOS, và cài đặt theo được cả
gia đình chứ không mất khi cài lại app. **Không có cũng không chặn gì** — FE
chạy với ngưỡng cố định.

### Yêu cầu #3 — Xác nhận việc gửi thông báo khi có SOS — **Bắt buộc, nhưng chỉ là xác nhận**

Đây **không phải** yêu cầu xây thêm. FE đã có đủ ba đường nhận thông báo:

| Kênh | Trạng thái FE |
|---|---|
| FCM push (app ở nền hoặc đã tắt) | ✅ Đã đăng ký token qua `POST /devices/tokens`, có kênh riêng cho SOS với độ ưu tiên cao nhất |
| Socket.IO `/notifications` (app đang mở) | ✅ Đã kết nối, tự reconnect |
| REST poll 15 giây | ✅ Dự phòng khi socket rớt |

Câu hỏi cho BE, xin trả lời rõ 3 ý:

1. Khi có **SOS alert mới**, BE **có** gửi FCM push và/hoặc socket event không?
2. Nếu có thì **gửi cho ai** — mọi thành viên, hay theo đúng cờ `notifyAllMembers`
   trong cài đặt SOS (true = mọi người, false = chỉ Trưởng/Phó nhóm)?
3. Trong payload push, `type` (hoặc `referenceType`) có đúng giá trị `SOS` không?
   FE đang dựa vào đó để chọn kênh notification ưu tiên cao và âm báo riêng.

**Vì sao quan trọng:** nếu BE không gửi push cho SOS, thì người nhà **chỉ biết
khi tự mở app** — lúc đó việc phát hiện té ngã gần như vô nghĩa. Đây là mắt xích
cuối của cả luồng.

> Ghi chú cho nhóm: có tài liệu nội bộ trước đây viết rằng *"FE chưa có Firebase,
> chưa có push real-time, cần BE xây transport"*. **Điều đó không đúng.**
> `pubspec.yaml` đã có `firebase_core`, `firebase_messaging`;
> `android/app/google-services.json` đã có và khớp `applicationId`;
> `lib/services/push_service.dart` đã gọi `POST /devices/tokens` sau khi đăng
> nhập. Endpoint cũng không phải `POST /auth/fcm-token` như tài liệu đó viết.
> Đừng lên kế hoạch dựa trên bản mô tả cũ.

---

## Phần 3 — Bảng tóm tắt để chốt trong buổi họp

| # | Việc | Ai làm | Mức độ | Không làm thì sao |
|---|---|---|---|---|
| 1 | Thêm `FALL_DETECTION` vào `sourceType` (hoặc field `triggerReason`) | BE | **Bắt buộc** | Cảnh báo tự động hiển thị y như bấm tay, người nhà không biết có thể là báo nhầm |
| 2 | Field `fallDetectionSensitivity` | BE | Nên có | Ngưỡng cố định, không điều chỉnh được theo người dùng |
| 3 | Xác nhận có gửi push/socket khi có SOS + gửi cho ai | BE | **Bắt buộc** (chỉ xác nhận) | Người nhà chỉ biết khi tự mở app → phát hiện té ngã mất tác dụng |
| 4 | Phát hiện té ngã trên điện thoại | FE | ✅ **Đã xong** | — |
| 5 | Chạy nền 24/7 (foreground service) | FE | Chưa làm | Chỉ phát hiện khi app đang mở — đã ghi rõ trong UI và báo cáo |

## Phần 4 — File đã thay đổi

| File | Việc |
|---|---|
| `lib/services/fall_detector_service.dart` | **Mới.** Máy trạng thái rơi tự do → va đập, tách thuần để test được |
| `lib/widgets/fall_countdown_dialog.dart` | **Mới.** Hộp thoại đếm ngược 10 giây |
| `lib/services/sos_location.dart` | **Mới.** Tách hàm lấy GPS ra khỏi `sos_screen` để nút SOS thủ công và phát hiện té ngã dùng **cùng một** đường lấy vị trí |
| `lib/navigation/family_shell.dart` | Bật/tắt detector theo cài đặt + vòng đời app; tải cài đặt SOS sau đăng nhập |
| `lib/screens/shared/sos_screen.dart` | Dùng helper GPS chung thay cho bản sao nội bộ |
| `lib/screens/shared/sos_settings_screen.dart` | Mô tả đúng cách hoạt động và giới hạn "chỉ khi app đang mở" |
| `test/fall_detection_test.dart` | **Mới.** 10 test, gồm 5 test chống báo nhầm |
| `API_DOCS.md` | Ghi nhận lệch `sourceType` và việc shell tải cài đặt SOS |

## Phần 5 — Checklist trước khi demo

1. Bật **Cài đặt SOS → Tự cảnh báo khi phát hiện té ngã** (cần quyền Trưởng hoặc
   Phó nhóm).
2. Mở app, **để app ở màn hình chính** (không khoá máy, không chuyển app khác).
3. Thả điện thoại xuống đệm/gối từ khoảng 1 mét → hộp thoại đếm ngược phải hiện.
4. Bấm **"Tôi ổn"** để thử đường huỷ, rồi thả lại và **để hết 10 giây** để thử
   đường gửi thật.
5. Kiểm tra trên máy của thành viên khác: có nhận được cảnh báo hay không — đây
   chính là chỗ phụ thuộc yêu cầu #3.
6. Lưu ý: sau mỗi lần phát hiện có **30 giây nghỉ**, thả liên tục sẽ không kích
   hoạt lại ngay.
