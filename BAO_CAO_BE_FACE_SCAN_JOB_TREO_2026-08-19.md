# Báo cáo BE — Job quét khuôn mặt treo ở PROCESSING, không bao giờ hoàn tất

**Ngày:** 19/08/2026 · **Người báo:** FE Mobile · **Mức độ:** Bắt buộc (tính năng
Face Suggestion hiện không dùng được trên máy thật)

## Hiện tượng

Ảnh album (4 người, mặt rõ, chụp gần) sau khi bấm quét thì đứng mãi ở trạng thái
"Đang quét". Khoảng 10 phút sau, chính BE trả về `retryAllowed: true` — tức là BE
tự xác nhận job đã vượt `maxProcessingSeconds` (600s) mà chưa xong. Bấm "Thử lại
tác vụ quét" thì job quay lại PENDING rồi lại treo tiếp.

Trước đó cùng luồng này còn gặp ca `scanStatus` về trạng thái đã quét nhưng
`GET .../face-suggestions` trả mảng rỗng.

## Đây là vấn đề phía BE, không phải FE

FE chỉ hiển thị đúng những gì BE trả:

| Endpoint | BE trả | FE hiển thị |
|---|---|---|
| `GET /families/{fid}/albums/media/{mediaId}/face-scan` | `status: PROCESSING`, `retryAllowed: true`, `maxProcessingSeconds: 600` | "Đang quét" + nút "Thử lại tác vụ quét" |
| `GET /families/{fid}/albums/media/{mediaId}/face-suggestions` | `[]` | "Chưa có gợi ý" |

`retryAllowed: true` là **do BE tự tính** (job FAILED, hoặc PROCESSING/PENDING quá
`maxProcessingSeconds`). BE đang tự nói rằng job của chính nó bị treo. FE không có
cách nào sửa được điều này.

FE cũng **không** tạo request trùng: khi trạng thái đang là PROCESSING và
`retryAllowed = false`, nút chỉ đọc lại trạng thái chứ không gọi
`POST .../face-scan` lần nữa.

## Nhờ BE kiểm tra

1. **Worker/queue xử lý face-scan có đang chạy không**, và job của `mediaId` này
   dừng ở bước nào. Nghi ngờ job được nhận vào queue nhưng consumer chết hoặc
   không có consumer nào chạy.
2. **Job treo có được đánh FAILED sau `maxProcessingSeconds` không.** Hiện job cứ
   ở PROCESSING vô hạn; nếu BE chuyển sang FAILED kèm lý do thì FE hiển thị được
   thông báo đúng thay vì bắt người dùng chờ mãi.
3. **`POST .../face-scan/retry` có thực sự đẩy lại job không**, hay chỉ reset
   timestamp. Sau khi retry, job lại treo y như cũ.
4. **Ca `status = SCANNED` nhưng `face-suggestions` rỗng:** đây là hai bước ghi
   riêng đúng không? Nếu đúng, nhờ BE chỉ đánh dấu job hoàn tất **sau khi** đã ghi
   xong bảng gợi ý, để không có khoảng thời gian FE đọc trúng trạng thái nửa vời.

## Câu hỏi về hành vi (cần xác nhận, FE đang phải suy đoán)

- **Người đã được gắn thẻ trong ảnh có bị loại khỏi danh sách gợi ý không?** FE
  đang đoán là CÓ, dựa trên hành vi quan sát được, và đã viết câu thông báo theo
  giả định đó. Swagger không mô tả. Nếu sai, FE sẽ sửa lại câu chữ.
- **Ngưỡng kích thước / độ tin cậy tối thiểu** để một khuôn mặt được coi là hợp lệ
  là bao nhiêu? Cần con số để viết hướng dẫn cho người dùng.

## Thiếu tài liệu (đã báo từ 02/08, vẫn còn)

Swagger vẫn **chưa có response schema** cho cả ba endpoint:
`POST .../face-scan`, `GET .../face-scan`, `POST .../face-scan/retry`.

FE vì vậy phải viết parser phòng thủ, chấp nhận nhiều biến thể tên field
(`scanStatus` / `faceScanStatus` / `status` / `state`, ở cả root lẫn trong object
`job` / `scan`). Nhờ BE bổ sung schema để bỏ được đoán mò này.

## Bổ sung 19/08 chiều — Tag trả về không có id thành viên

Sau khi worker chạy lại được, luồng quét đã ra gợi ý và xác nhận thành công.
Nhưng đo trên máy thật thấy một mismatch khác:

`GET /families/{fid}/albums/media/{mediaId}` trả tag có **tên** thành viên (chip
`@Vu Quan` hiện đúng) nhưng FE **không đọc được id** của thành viên đó. Parser
`AlbumTag.fromJson` đã thử lần lượt `taggedMemberId`, `memberId`, `userId`,
`taggedMember.id`, `user.id` — tất cả đều rỗng.

**Ảnh hưởng:** FE dùng id này để lọc gợi ý trùng cho người đã có thẻ
(`_alreadyTagged`). Id rỗng ⇒ bộ lọc vô hiệu ⇒ có thể gợi ý lại đúng người vừa
được gắn thẻ.

**Nhờ BE cho biết** id thành viên trong object tag nằm ở field nào, hoặc bổ sung
`taggedMemberId` vào response. Đây cũng là hệ quả của việc Swagger chưa có
schema cho tag trong response media detail.

FE tạm thời chỉ chuyển phần **chọn câu thông báo** sang đếm số tag thay vì dựa
vào id (thông tin chắc chắn có). Phần lọc gợi ý trùng vẫn phải chờ id từ BE.
