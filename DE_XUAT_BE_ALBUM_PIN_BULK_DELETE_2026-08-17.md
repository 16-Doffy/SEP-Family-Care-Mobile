# Đề xuất BE — Ghim ảnh + Xóa nhiều ảnh một lượt (Album)

Ngày: **2026-08-17** · Người soạn: FE Mobile (nhánh `NDuy`)
Trạng thái: **đề xuất, không chặn** — FE đã có giải pháp tạm cho cả 2 mục, chạy
được và đã test runtime. Chỉ cần BE làm nếu muốn đúng về mặt sản phẩm.

---

## Bối cảnh

Đối chiếu `family-care-api.json` (swagger dump 2026-08-12) + `API_DOCS.md`: nhóm
album hiện có 14 endpoint (media CRUD, tags, moderation, face-scan/suggestions)
cộng nhóm collections thêm sau. **Không có** endpoint hay field nào cho 2 việc
dưới đây, nên FE phải tự xoay tạm — ghi rõ ra để BE biết chỗ nào là "tạm".

---

## Mục 1 — Ghim ảnh · mức **Nên có**

### Hiện trạng FE

Ghim đang lưu **cục bộ trên máy** (`AlbumPinStore`, dùng
`flutter_secure_storage`, khóa `album_pinned_{userId}_{familyId}`). Hệ quả:

- Ghim **không đồng bộ**: đổi điện thoại hoặc cài lại app là mất sạch.
- Thành viên khác trong gia đình **không thấy** ảnh người kia ghim.
- UI đã gắn nhãn "chỉ trên máy này" ngay cạnh mục "Đã ghim" để người dùng
  không hiểu nhầm là dữ liệu chung.

Đây là lựa chọn có chủ đích để kịp tiến độ, **không phải mock** — không có
endpoint giả, không suy đoán schema BE.

### Đề xuất

Cách gọn nhất, không cần bảng mới:

| Method | Path | Ý nghĩa |
|---|---|---|
| POST | `/families/{familyId}/albums/media/{mediaId}/pin` | Ghim ảnh cho **chính người gọi** |
| DELETE | `/families/{familyId}/albums/media/{mediaId}/pin` | Bỏ ghim |

Và thêm 2 thứ vào response media đang có:

```json
{
  "mediaId": "uuid",
  "isPinned": true,          // ghim bởi chính người đang gọi API
  "pinnedAt": "2026-08-17T10:00:00Z"
}
```

Kèm filter cho endpoint list đã có:
`GET /families/{familyId}/albums/media?isPinned=true`

**Câu hỏi cần BE chốt:** ghim là **cá nhân** (mỗi thành viên một danh sách
riêng — FE đang hiểu theo hướng này) hay **chung cả gia đình** (ai ghim thì cả
nhà thấy)? Hai hướng này khác nhau ở tầng dữ liệu, FE làm theo BE chốt.

---

## Mục 2 — Xóa nhiều ảnh một lượt · mức **Nên có**

### Hiện trạng FE

Màn Ảnh vừa có chế độ chọn nhiều để xóa. Vì BE chỉ có
`DELETE /families/{familyId}/albums/media/{mediaId}` (xóa từng cái), FE đang
gọi **tuần tự N request** (`AlbumProvider.softDeleteMany`), có thanh tiến độ
"Đang xóa 3/12" và báo lại đúng "đã xóa X/N, Y ảnh lỗi".

Chạy được, nhưng:

- Chọn 30–50 ảnh là 30–50 request → chậm thấy rõ, tốn pin/mạng.
- **Không có tính nguyên tử**: lỗi giữa chừng để lại trạng thái nửa vời (một
  phần đã xóa, một phần chưa). FE báo đúng số liệu nhưng không rollback được.

### Đề xuất

| Method | Path |
|---|---|
| POST | `/families/{familyId}/albums/media/bulk-delete` |

Request:

```json
{
  "mediaIds": ["uuid-1", "uuid-2", "uuid-3"],
  "reason": "Deleted from mobile app"
}
```

Response mong muốn — **báo rõ từng id thành công/thất bại**, đừng chỉ trả 200
trống, vì FE cần biết ảnh nào chưa xóa được để hiện lại đúng:

```json
{
  "deleted": ["uuid-1", "uuid-2"],
  "failed": [
    { "mediaId": "uuid-3", "reason": "NOT_FOUND" }
  ]
}
```

Ghi chú: nên là **xóa mềm**, giữ nguyên hành vi của endpoint xóa lẻ hiện tại
(quản trị viên vẫn khôi phục được qua `POST .../restore`).

Nếu BE làm `bulk-delete`, xin làm thêm `bulk-restore` tương ứng để hàng đợi
khôi phục không bị lệch trải nghiệm.

---

## Không cần BE làm gì cho các mục sau (chỉ ghi để đối chiếu)

- **Ảnh hiện nhỏ/mờ ở màn chi tiết**: đã xác định là **bug FE thuần**
  (`Center` bọc `Image` làm `BoxFit.contain` mất tác dụng), đã sửa xong. Không
  liên quan BE.
- **Ảnh gốc độ phân giải thấp vẫn mờ sau khi sửa**: đúng bản chất dữ liệu, ảnh
  145×106px không thể nét khi phóng full màn. Không phải lỗi.
