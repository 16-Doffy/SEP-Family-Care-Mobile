# Đề xuất BE — Album Collection + analyze-draft

Ngày: **2026-08-16** · Người soạn: FE Mobile (nhánh `NDuy`)
Trạng thái: **đề xuất, chờ xác nhận — FE chưa code phần nào trong file này**

---

## Vì sao phải hỏi trước khi làm

Có 1 spec mô tả BE "vừa thêm" Album Collection và bước `analyze-draft` cho flow
Album. Đối chiếu với `API_DOCS.md` và `family-care-api.json` (swagger dump đang
dùng) thì **cả 2 nhóm endpoint dưới đây đều chưa có** — chỉ có đúng 14 endpoint
album hiện hữu (media CRUD, tags, moderation, face-scan/suggestions).

Theo quy tắc của repo, FE không tự đoán schema rồi code trước — dừng lại hỏi để
tránh lặp lại kiểu bug "FE tự suy đoán field/endpoint, đến lúc demo mới lộ" đã từng
xảy ra. Nội dung dưới đây là **đề xuất**, không phải yêu cầu bắt buộc BE phải làm
đúng y hệt — nếu BE đã làm/định làm khác, xin phản hồi lại để FE code đúng theo BE.

---

## Nhóm 1 — Album Collection · **Bắt buộc** (chặn Phase 1 FE)

### 1.1 CRUD collection

| Method | Path |
|---|---|
| GET | `/families/{familyId}/albums/collections` |
| POST | `/families/{familyId}/albums/collections` |
| PATCH | `/families/{familyId}/albums/collections/{collectionId}` |
| DELETE | `/families/{familyId}/albums/collections/{collectionId}` |

**Field tối thiểu FE cần trong response của 1 collection:**

```json
{
  "id": "uuid",
  "name": "Đi biển",
  "description": "Chuyến đi Vũng Tàu tháng 8",
  "createdAt": "2026-08-16T10:00:00Z",
  "mediaCount": 12
}
```

- `name`: bắt buộc khi POST.
- `description`: optional.
- `mediaCount`: không bắt buộc, nhưng nếu có sẵn thì FE hiển thị số ảnh/video trong
  card collection mà không cần gọi thêm request đếm.

### 1.2 Gán collection khi upload media

Media hiện upload qua `POST /families/{familyId}/albums/media` (multipart, field
`caption`, `visibilityScope`, `file`). Xin xác nhận: endpoint này **chấp nhận thêm
field `collectionId` (optional)** trong cùng multipart request, hay cần 1 bước
riêng (gán collection sau khi upload xong)?

### 1.3 Lọc media theo collection

`GET /families/{familyId}/albums/media` hiện hỗ trợ `mediaType`, `moderationStatus`,
`page`, `limit`. Xin thêm param `collectionId` (optional) để lọc theo collection.

**Yêu cầu quan trọng:** media cũ có `collectionId = null` (upload trước khi tính
năng này tồn tại) vẫn phải liệt kê được bình thường khi không truyền `collectionId`
(tức ở view "Tất cả ảnh") — không bị BE tự động ẩn/loại khỏi kết quả mặc định.

---

## Nhóm 2 — analyze-draft · **Nên có** (Phase 2, không chặn Phase 1)

```
POST /families/{familyId}/albums/media/analyze-draft
Content-Type: multipart/form-data

- file                    (bắt buộc)
- collectionId            (optional)
- topic                   (optional, string)
- declaredContentIntent   (optional, enum: PEOPLE | SCENE_OR_OBJECT)
```

Response mẫu FE đang dùng để tham khảo (xin BE xác nhận đúng schema thật, tên field
và giá trị enum chuẩn):

```json
{
  "recommendation": "WARN",
  "analysisStatus": "COMPLETED",
  "collectionId": "...",
  "topic": "Đi biển",
  "declaredContentIntent": "PEOPLE",
  "mediaType": "PHOTO",
  "hasPerson": false,
  "topicMatch": "MISMATCH",
  "topicConfidence": 0.91,
  "detectedLabels": ["snow", "skiing", "mountain"],
  "summary": "Cảnh trượt tuyết trên núi.",
  "warnings": [
    "Không phát hiện người trong ảnh.",
    "Ảnh có vẻ không khớp với chủ đề album Đi biển."
  ],
  "suggestedActions": ["CONFIRM_UPLOAD", "CHOOSE_ANOTHER_COLLECTION"]
}
```

**Câu hỏi cần BE xác nhận:**

1. `recommendation` có đúng 2 giá trị `ALLOW` / `WARN`, hay còn giá trị khác (vd
   `BLOCK`)?
2. `analysisStatus` ngoài `COMPLETED` còn `UNAVAILABLE` và `SKIPPED` như spec đề
   cập không? Ở 2 trạng thái này, FE hiểu là **vẫn cho phép upload tiếp** sau khi
   người dùng xác nhận (không coi là lỗi chặn) — BE xác nhận cách hiểu này đúng
   không?
3. `detectedLabels`/`summary`/`topicConfidence` có luôn có mặt khi
   `analysisStatus = COMPLETED`, hay có thể thiếu tùy trường hợp?
4. Response này có tạo ra media thật nào ở BE không, hay chỉ là bước phân tích
   thuần túy (draft), sau đó FE gọi `POST .../albums/media` upload thật như bình
   thường nếu người dùng xác nhận tiếp tục?

---

## Phạm vi FE sẽ làm sau khi có xác nhận

- Model/provider Collection mới (`AlbumCollection`, CRUD trong `AlbumProvider`).
- Nối vào tab "Bộ sưu tập" đã có sẵn UI shell trong `album_screen.dart` (hiện đang
  ẩn nút "Tạo album" chờ đúng tính năng này).
- Thêm bước gọi `analyze-draft` trước khi upload, hiển thị cảnh báo dạng bottom
  sheet khi `recommendation = WARN`.
- **Không đụng** face recognition (`AlbumFaceProvider`, `AlbumFaceSection`,
  face-scan/suggestions/confirm/reject) — flow này độc lập hoàn toàn, giữ nguyên.


