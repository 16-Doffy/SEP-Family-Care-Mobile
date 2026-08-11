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

## Known Issues

- AI tạo giao dịch “ngay bây giờ” còn từng có báo cáo lệch giờ; cần verify runtime nếu demo phần AI tài chính.
- AI tạo khoản thu/chi hiện chưa tự gán `categoryId`, nên có thể rơi vào “Chưa gán hũ”; người dùng vẫn sửa danh mục được trong màn Ví.
- `GET /finance/monthly-finances/me/history` chưa có; biểu đồ member còn phải loop từng tháng.
- `authProviders` và `linkedExistingAccount` chưa có trong `/auth/me` hoặc `/auth/firebase`, nên FE chưa thể hiển thị chính xác trạng thái “Đăng nhập bằng Google/Mật khẩu”.
