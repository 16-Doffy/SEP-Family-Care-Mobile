# Đề xuất BE — Giữ lại `boundingBox` khi tag khuôn mặt được xác nhận

Ngày: **2026-08-24** · Người soạn: FE Mobile (nhánh `NDuy`)
Trạng thái: **đề xuất, chờ xác nhận — FE chưa code phần lưu/hiển thị lâu dài**

---

## Bối cảnh

FE vừa làm xong bước 1: vẽ khung (bounding box) + tên đè lên đúng vị trí khuôn
mặt **trong lúc gợi ý AI còn đang chờ duyệt** (`GET .../face-suggestions` đã có
sẵn `boundingBox: {x, y, width, height}` theo Swagger
`FaceBoundingBoxResponseDto`, toạ độ tỉ lệ 0..1 theo ảnh gốc).

Nhưng mục tiêu thật của tính năng (theo yêu cầu người dùng) là: sau khi
**xác nhận** gợi ý (bấm ✓, `POST .../face-suggestions/{id}/confirm`), khung
phải **ở lại vĩnh viễn trên ảnh** — mọi thành viên gia đình mở lại ảnh đó vào
bất kỳ lúc nào cũng phải thấy khung + tên, giống cơ chế tag mặt của Instagram.
Đây không phải hiệu ứng tạm thời lúc duyệt, mà là dữ liệu cần **lưu lại và
đồng bộ** cho mọi người xem.

## Vấn đề — verify bằng data thật, không phải suy đoán

Gọi thật `GET /families/{familyId}/albums/media?limit=30` trên gia đình có ảnh
đã tag xong (kể cả loại tag tạo từ đúng flow "Confirmed from face suggestion"),
field `tags` của 3 ảnh có tag đều **không có `boundingBox`**:

```json
{
  "id": "f60be903-...",
  "taggedMemberId": "4c37637c-...",
  "taggedByMemberId": "8148194d-...",
  "tagNote": "Confirmed from face suggestion",
  "createdAt": "2026-07-30T06:36:04.166Z",
  "taggedMember": { "memberId": "...", "displayName": "...", "avatarUrl": null, "familyRole": "...", "memberStatus": "..." },
  "taggedBy": { "memberId": "...", "displayName": "..." },
  "permissions": { "canRemove": true }
}
```

Không có `boundingBox` ở đâu cả. Đối chiếu Swagger: `AddAlbumMediaTagDto` (tag
thủ công) cũng không có field này, và response của
`POST .../face-suggestions/{id}/confirm` lẫn `GET .../tags` đều **không được
document schema** (chỉ ghi `"200": { "description": "" }`) nên không chắc chắn
được từ Swagger — nhưng data thật đã trả lời rõ: **toạ độ bị bỏ ngay khi
confirm**, chỉ tồn tại tạm thời trong bảng gợi ý (`face-suggestions`), không
được copy sang bảng tag chính thức.

## Đề xuất

1. Khi `POST .../face-suggestions/{suggestionId}/confirm` tạo tag chính thức,
   lưu kèm `boundingBox` (lấy từ khuôn mặt gốc của gợi ý đó) vào bản ghi tag.
2. `GET .../albums/media` (field `tags`) và `GET .../albums/media/{mediaId}/tags`
   trả thêm `boundingBox: {x, y, width, height}` cho mỗi tag — cùng shape với
   `FaceBoundingBoxResponseDto` đã dùng ở face-suggestions, để FE tái dùng
   nguyên code parse/vẽ overlay đã có.
3. Với tag gắn **thủ công** (`POST .../tags` bằng `AddAlbumMediaTagDto`, không
   qua AI) thì không có khuôn mặt được AI phát hiện để lấy toạ độ — `boundingBox`
   ở trường hợp này để `null`/thiếu field là hợp lý, FE tự ẩn khung cho tag loại
   này (chỉ hiện tên, không hiện khung).
4. Tag cũ đã tạo trước khi có thay đổi này (không có `boundingBox` trong DB) —
   xin xác nhận: trả `null` cho các tag cũ đó là đủ, FE sẽ tự ẩn khung, không
   cần BE backfill.

## Câu hỏi cần BE xác nhận

1. BE có lưu toạ độ khuôn mặt gốc ở đâu đó sau khi job face-scan xong không
   (kể cả sau khi suggestion đã bị xoá/archive), hay cần FE gửi kèm
   `boundingBox` lên trong body của request `confirm` để BE lưu lại (tức BE
   không tự có sẵn, phải nhận lại từ FE)?
2. Đồng ý format field `boundingBox` giống hệt `FaceBoundingBoxResponseDto`
   hiện có (x/y/width/height tỉ lệ 0..1) để FE không phải viết code parse
   khác đi không?

## Phạm vi FE sẽ làm sau khi có xác nhận

- `AlbumTag` (`lib/models/album_media.dart`): thêm field `boundingBox`
  (tái dùng `FaceBoundingBox` đã có ở `album_face_provider.dart`).
- `album_screen.dart`: đưa danh sách tag đã confirm (không chỉ suggestion đang
  chờ duyệt) vào cùng cơ chế overlay (`_FaceOverlay`/`_FaceBox`) đã dựng sẵn ở
  bước 1 — khung ở lại vĩnh viễn trên ảnh cho mọi người xem, không chỉ hiện
  thoáng qua lúc duyệt.
