# Ghi nhận lỗi FE — Ngắt kết nối wearable báo thành công khống

Ngày: **2026-08-06** · Người soạn: FE Mobile (nhánh `giap`)
Trạng thái: **đã xác định nguyên nhân — lỗi phía FE, không phải BE**

> ⚠️ **Bản trước của file này quy kết sai cho BE.** Nó viết rằng bản ghi
> `UNPAIRED` vẫn chiếm quota một-tài-khoản-một-wearable. **Điều đó không đúng.**
> BE đã xác nhận: bản ghi `UNPAIRED` không chiếm chỗ; ghép lại cùng
> `deviceIdentifier` cũ thì BE pair lại chính record đó, còn identifier mới thì
> tạo record mới miễn là user không còn wearable `PAIRED`. Toàn bộ nội dung dưới
> đây là bản đã sửa.

---

## 1. Hiện tượng

Người dùng bấm **Ngắt kết nối**, app báo "Đã ngắt kết nối wearable", màn hình
chuyển sang **"Chưa kết nối wearable"**. Nhưng bấm **Kết nối** lại thì nhận
**409 "Tài khoản này đã kết nối một wearable"** — kể cả khi thử từ máy khác.

## 2. Nguyên nhân — lỗi FE

BE chẩn đoán đúng: *"nếu vẫn báo tài khoản đã kết nối wearable thì nghĩa là
backend vẫn còn record PAIRED, FE cần check lại request unpair có thành công
thật không."*

Có **hai** chỗ trong `lib/providers/wearable_provider.dart` khiến FE hiển thị
"đã gỡ" mà không hề biết server có gỡ thật hay không:

**a. Cập nhật lạc quan trước khi gửi request.**
`updateDevice()` ghi trạng thái mới vào `_currentDevice` rồi `notifyListeners()`
**trước khi** gọi PATCH. Màn hình đổi sang "Chưa kết nối" ngay lập tức, trước cả
khi server nhận được gì.

**b. Bỏ qua response của server khi gỡ.**

```dart
// TRƯỚC (sai)
_currentDevice = pairingStatus == 'UNPAIRED' ? null : _deviceFrom(data);
```

Khi gỡ, FE gán thẳng `null` theo trạng thái **được yêu cầu**, **không đọc** dữ
liệu BE trả về. Nếu PATCH không thực sự áp dụng `UNPAIRED` vì bất kỳ lý do gì,
FE vẫn hiển thị "đã gỡ".

Kết quả: **màn hình và server nói hai chuyện khác nhau**. Server còn record
`PAIRED` → lần ghép sau đúng quy tắc mà trả 409, còn người dùng thì không hiểu
vì sao vì UI bảo là chưa có thiết bị nào.

## 3. Đã sửa

Theo đúng khuyến nghị của BE — *"chỉ báo success sau khi PATCH thành công và/hoặc
`GET /wearables/me` xác nhận không còn wearable đang paired"*:

```dart
// SAU (đúng)
if (pairingStatus == 'UNPAIRED') {
  await fetchCurrentDevice();               // GET /wearables/me = nguồn sự thật
  if (_currentDevice != null && _currentDevice!.isPaired) {
    throw Exception('Máy chủ vẫn ghi nhận thiết bị đang kết nối. '
                    'Chưa gỡ được, vui lòng thử lại.');
  }
} else {
  _currentDevice = _deviceFrom(data);
}
```

- Bỏ cập nhật lạc quan cho riêng thao tác gỡ (vẫn giữ cho đổi tên / bật-tắt
  GPS-SOS, vì hiển thị sai ở đó không gây kẹt).
- Chỉ hiện toast "Đã ngắt kết nối" khi provider **không ném lỗi**, tức là
  `GET /wearables/me` đã xác nhận không còn thiết bị PAIRED.

## 4. Các sửa phụ đi kèm

| Sửa | Lý do |
|---|---|
| Không đè message thật của BE khi 409 | Trước đây **mọi** 409 đều bị thay bằng một câu cứng của FE, nên không đọc được BE thực sự báo gì — chính điều này che mất chẩn đoán |
| Card **"Thiết bị đeo của gia đình"** (`GET /families/{familyId}/wearables`) | Hiện mọi bản ghi kèm `pairingStatus` để đối chiếu trạng thái thật trên server. Hai API này đã wire ở provider từ trước nhưng chưa màn nào gọi |
| `deviceIdentifier` sinh riêng từng máy, lưu cố định | Thay hằng số `wearos-emulator-001` dùng chung cho mọi máy. `PairWearableDto` mô tả identifier "unique within a family" nên hai máy trong cùng gia đình gửi trùng là sai contract. Mã cố định theo từng bản cài nên vẫn thoả điều kiện "ghép lại cùng identifier thì pair lại record cũ" |

## 5. Không cần BE làm gì

Hành vi BE đúng như mô tả. Không có yêu cầu thay đổi nào.

Chỉ có một điểm **nếu tiện thì tốt hơn**, không chặn gì: khi trả 409 cho
`POST /families/{familyId}/wearables`, nếu response kèm `code` riêng (ví dụ
`WEARABLE_ALREADY_PAIRED` so với `DEVICE_IDENTIFIER_TAKEN`) thì FE hiển thị được
hướng dẫn đúng cho từng trường hợp thay vì dùng chung một câu.

## 6. Bài học cho FE

Cập nhật lạc quan (optimistic update) **không được dùng cho thao tác mà việc
hiển thị sai trạng thái sẽ làm người dùng kẹt**. Gỡ ghép nối là một trong số đó:
hiển thị sai không chỉ gây khó chịu mà còn khoá luôn đường ghép lại, và người
dùng không có cách nào tự nhận ra.

Cùng loại với lỗi đã gặp trước đây trong repo: FE tự kết luận thay vì đọc dữ liệu
server trả về.
