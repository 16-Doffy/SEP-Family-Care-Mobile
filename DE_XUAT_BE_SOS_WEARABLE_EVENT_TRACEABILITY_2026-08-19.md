# Đề xuất Backend — Truy vết sự kiện SOS Wearable (té ngã / nhịp tim)

Ngày soạn: 2026-08-19 · Người soạn: FE (Claude Code, nhánh `giap`).

Bối cảnh: đang rà lại luồng `POST /families/{familyId}/wearables/{deviceId}/events` để đảm bảo
người xem/hội đồng không hiểu nhầm nút "giả lập" trên đồng hồ là một cách tạo SOS tuỳ tiện. BE đã
xác nhận đầy đủ cơ chế cốt lõi ở nhiều vòng trao đổi trước (16–17/08/2026 — điều kiện auto-create,
chống trùng SOS active, quyền sở hữu thiết bị). Tài liệu này **không lặp lại** các câu đã có câu trả
lời — chỉ nêu 2 điểm mới, cả hai đều ở mức **Nên có**, không chặn demo/launch.

---

## 1. [Nên có] `reasonCode` khi `alertCreated=false`

### Hiện trạng
`WearableEventIngestResponseDto` (`POST /families/{familyId}/wearables/{deviceId}/events`) trả:

```json
{ "event": {...}, "alertId": null, "alertCreated": false }
```

khi BE quyết định không tạo cảnh báo. Có ít nhất 4 lý do khác nhau có thể dẫn tới kết quả này (theo
xác nhận trước đó của BE):

1. `device.sosEnabled = false`
2. Family SOS `isEnabled = false`
3. `FALL_DETECTED` mà `autoCreateAlertFromFall = false`
4. Người đeo đã có SOS `ACTIVE` khác — **trường hợp này BE đã trả `alertId` khác null**, phân biệt
   được với 3 case trên qua `alertId != null`, nên không cần thêm gì cho case này.

Với 3 case đầu (1-3), response hiện tại giống hệt nhau (`alertCreated:false, alertId:null`) — FE
không có cách nào phân biệt trừ khi tự đối chiếu lại 3 điều kiện bằng dữ liệu đã tải sẵn ở client
(có thể lệch nếu cache cũ).

### Đề xuất
Thêm field `reasonCode` (tuỳ chọn, chỉ xuất hiện khi `alertCreated=false && alertId=null`), ví dụ:

```json
{ "event": {...}, "alertId": null, "alertCreated": false, "reasonCode": "DEVICE_SOS_DISABLED" }
```

Gợi ý enum: `DEVICE_SOS_DISABLED | FAMILY_SOS_DISABLED | FALL_AUTO_CREATE_DISABLED`.

### Lý do đề xuất
Không phải để sửa lỗi hiện có — FE có thể tự kiểm tra 3 điều kiện trước khi cho bấm nút (đang lên kế
hoạch làm ở phía FE). `reasonCode` chỉ là lớp phòng vệ thứ 2: nếu cache FE lệch với dữ liệu BE tại
thời điểm gửi (vd gia đình vừa tắt cài đặt ở thiết bị khác ngay trước khi FE gửi event), FE vẫn hiển
thị đúng lý do thay vì một câu chung chung, tránh tình huống trong demo/thực tế người dùng hỏi "tại
sao không có cảnh báo?" mà không ai trả lời được chính xác.

**Mức độ**: Nên có. Không cần cho buổi bảo vệ sắp tới (FE tự kiểm tra trước là đủ), có thể làm sau.

---

## 2. [Nên có] Cờ phân biệt sự kiện demo/giả lập với sự kiện cảm biến thật trong audit log

### Hiện trạng
`CreateSensorEventDto` không có field nào đánh dấu nguồn sự kiện là "người dùng bấm nút giả lập trên
UI" hay "cảm biến vật lý thật phát hiện". FE hiện gửi thông tin này (nếu có) lồng trong `rawValue`
dạng chuỗi tự do không có schema, ví dụ `rawValue.source: "wear_os_emulator"` hoặc
`"real_accelerometer"` — BE lưu nguyên trạng nhưng không xử lý/lọc được theo field này.

### Vì sao đáng quan tâm
Sau khi có dữ liệu demo thật trong hệ thống (đã xảy ra — xem log 16/08: 3 event demo đã được ghi vào
`familyId 67453c6b-...`, `deviceId b90c9809-...`), nếu sau này gia đình đó tiếp tục dùng app thật,
lịch sử `GET /wearables/{deviceId}/events` sẽ lẫn cả sự kiện demo và sự kiện thật, không lọc được.
Với một sản phẩm chăm sóc sức khoẻ/an toàn gia đình, khả năng phân biệt "đây là dữ liệu demo, không
phải một lần té ngã thật" có giá trị cho cả người dùng (xem lại lịch sử) lẫn đội vận hành (audit).

### Đề xuất
Thêm field tuỳ chọn `isSimulated: boolean` (mặc định `false`) vào `CreateSensorEventDto`, lưu kèm
`SensorEvent`, hiển thị được ở `GET .../events`. Không cần validate/enforce gì đặc biệt ở giai đoạn
này — chỉ cần lưu và trả lại đúng giá trị.

**Mức độ**: Nên có, không khẩn — có thể gộp vào đợt cải tiến sau ngày bảo vệ. Nêu ra sớm để BE cân
nhắc, không cần phản hồi gấp.

---

## Không cần trả lời gấp

Cả 2 mục trên đều không chặn demo trước hội đồng hay launch — chỉ ghi lại để BE cân nhắc khi có thời
gian rảnh sau mùa bảo vệ. Nếu BE thấy không cần thiết, FE vẫn hoạt động đúng với contract hiện tại.
