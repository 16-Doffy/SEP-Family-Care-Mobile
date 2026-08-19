# Báo cáo & Kế hoạch gửi BE — Làm rõ UI cảm biến SOS trên Wear OS (Track A)

Ngày soạn: 2026-08-19 · Người soạn: FE (Claude Code, nhánh `giap`).

Mục đích tài liệu: trình bày đầy đủ bối cảnh + kế hoạch thay đổi phía FE (Track A trong
[`PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md`](PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md))
để **đồng bộ/thống nhất với BE trước khi code** — theo đúng quy tắc làm việc của repo này (preview
trước khi sửa). Không yêu cầu BE code gì mới; chỉ cần BE xác nhận 2 điểm ở mục 4 để FE yên tâm dựa
vào dữ liệu đã có sẵn.

---

## 1. Bối cảnh — vấn đề đang cần giải quyết

Trên đồng hồ (Wear OS), màn "Cảm biến SOS" (`WearSensorSosScreen`) có 3 nút demo: "Giả lập té ngã",
"Giả lập nhịp tim cao", "Giả lập nhịp tim thấp". Mỗi nút, khi bấm, mở một màn đếm ngược 20 giây rồi
gửi sự kiện cảm biến lên BE qua `POST /families/{familyId}/wearables/{deviceId}/events`.

**Vấn đề**: hiện tại UI không có gì phân biệt rõ ràng 3 nút này với nút "SOS" thủ công (giữ 2 giây ở
tab khác) — cả hai đều là "bấm → đếm ngược → tạo cảnh báo". Người xem (đặc biệt hội đồng chấm khoá
luận không rành kỹ thuật) rất dễ hiểu nhầm 3 nút giả lập chỉ là "một cách khác để bấm SOS", trong khi
thực chất phía sau là một luồng khác hẳn: BE tự quyết định có tạo cảnh báo hay không dựa trên cài đặt
gia đình đã bật (`device.sosEnabled`, family SOS `isEnabled`, và với riêng té ngã còn thêm
`autoCreateAlertFromFall`) — khác với SOS thủ công luôn tạo cảnh báo vô điều kiện.

Ngoài vấn đề nhận thức, còn có một rủi ro vận hành cụ thể: nếu bấm nút giả lập trong lúc 1 trong 3
điều kiện trên đang tắt, BE **âm thầm không tạo cảnh báo** (`alertCreated=false, alertId=null`),
trong khi UI chỉ đổi 1 chữ rất dễ bỏ sót ("Đã gửi sự kiện" thay vì "Đã gửi SOS"). Nếu demo trước hội
đồng mà không để ý, người trình bày có thể tưởng nhầm là đã tạo cảnh báo thành công.

## 2. Kế hoạch FE (Track A — thay đổi nhỏ, không đổi contract API)

Không thêm/sửa endpoint nào. Chỉ 2 thay đổi ở tầng UI/state của `wear_sensor_sos_screen.dart`:

### 2.1. Thêm dòng phụ đề giải thích

Dưới tiêu đề "Giả lập (demo)" (hiện ở dòng 402 của
[`wear_sensor_sos_screen.dart`](lib/wear/screens/wear_sensor_sos_screen.dart#L402)), thêm 1 dòng chữ
nhỏ, ví dụ: *"Gửi một sự kiện cảm biến lên máy chủ — máy chủ tự quyết định có tạo cảnh báo hay không,
khác với nút SOS thủ công."* Thuần UI, không gọi API, không ảnh hưởng logic.

### 2.2. Thêm tiền kiểm tra trước khi cho bấm nút giả lập

Hiện tại màn chỉ khoá nút khi `!device.isPaired`
([dòng 415](lib/wear/screens/wear_sensor_sos_screen.dart#L415)). Kế hoạch: tải thêm
`SosProvider.fetchSettings()` (đã có sẵn method, gọi `GET /families/{familyId}/sos/settings`) trong
`initState`, đối chiếu:

- `SosSettings.isEnabled` (family SOS có bật không)
- `WearableProvider.currentDevice.sosEnabled` (đã có sẵn field trong `GET /wearables/me`)
- Với riêng nút "Giả lập té ngã": thêm `SosSettings.autoCreateAlertFromFall`

Nếu 1 trong các điều kiện tương ứng đang tắt, khoá nút kèm dòng lý do rõ ràng (vd: *"Gia đình chưa
bật tự động tạo cảnh báo khi té ngã — vào Cài đặt SOS trên điện thoại để bật"*), thay vì để bấm được
rồi mới phát hiện không có gì xảy ra sau 20 giây đếm ngược.

**Không có thay đổi nào ở phía BE** — cả 2 endpoint dùng (`GET /sos/settings`, `GET /wearables/me`)
đã tồn tại, đã được FE dùng ở màn khác trong app (màn Cài đặt SOS, màn Thiết bị đeo), không phải field
mới.

## 3. File/vị trí sẽ đổi (để BE hình dung phạm vi, không cần review code)

| File | Thay đổi |
|---|---|
| `lib/wear/screens/wear_sensor_sos_screen.dart` | Thêm dòng phụ đề UI; thêm tải `SosSettings` + gate nút theo 3 điều kiện |
| Không đổi | Mọi provider/service/API call khác giữ nguyên |

## 4. Điều cần BE xác nhận trước khi FE triển khai

Không phải API mới — chỉ 2 câu hỏi để FE yên tâm gate UI đúng, tránh gate sai làm khoá nhầm nút demo
trước hội đồng:

1. **Độ trễ cập nhật cài đặt**: nếu Manager vừa đổi `autoCreateAlertFromFall` hoặc family SOS
   `isEnabled` từ điện thoại, gọi `GET /families/{familyId}/sos/settings` từ đồng hồ **ngay sau đó**
   có luôn thấy giá trị mới nhất không (không có cache/độ trễ phía server)? Nếu có độ trễ, cho biết
   khoảng bao lâu để FE cân nhắc có cần tự làm mới định kỳ hay không.
2. **`device.sosEnabled` trong `GET /wearables/me`**: xác nhận field này luôn có mặt và phản ánh
   đúng trạng thái mới nhất (không phải snapshot lúc pair) — FE sẽ dựa hoàn toàn vào field này để
   khoá/mở 3 nút giả lập.

Không cần trả lời gấp nếu 2 điều trên đã hiển nhiên đúng theo thiết kế hiện có (nhiều khả năng là
vậy, vì các field này đã dùng ổn định ở nơi khác) — chỉ cần 1 dòng xác nhận ngắn gọn là đủ để FE bắt
đầu code Track A.

## 5. Rủi ro & phạm vi ảnh hưởng

- Không đổi hành vi gửi SOS thật (endpoint, payload, luồng BE quyết định giữ nguyên 100%).
- Rủi ro duy nhất là UI: nếu gate sai điều kiện, có thể khoá nhầm nút demo dù đủ điều kiện thật — vì
  vậy cần BE xác nhận mục 4 trước khi code để giảm khả năng này.
- Không đụng tới cơ chế "tín hiệu → detector → cảnh báo" đã mất (Track B trong tài liệu phân tích
  chính) — việc đó tách riêng, không nằm trong phạm vi báo cáo này.

## 6. Trạng thái

Chờ BE xác nhận 2 điểm ở mục 4, sau đó FE sẽ triển khai Track A và test lại bằng `flutter analyze` +
`flutter test` trước khi bàn giao.
