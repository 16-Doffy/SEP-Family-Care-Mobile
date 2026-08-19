# Báo cáo BE — Kết quả đối chiếu Swagger live sau khi BE push (19/08/2026)

FE đã tải Swagger live tại `https://api.familycare-digital.com/api/docs-json` và
đối chiếu với 3 contract BE thông báo. Bản dump `family-care-api.json` trong
repo đã được cập nhật theo bản live này.

## 1. Album / tag / face-scan — ✅ ĐÃ LÊN, xác nhận được

`AlbumTagResponseDto` có đúng field đã hứa:
`id, taggedMemberId, taggedByMemberId, tagNote, createdAt, taggedMember,
taggedBy, permissions`

`AlbumMediaResponseDto` có `tags[]` + `tagCount`. Có 22 schema mới và 3 path mới
(`albums/collections`, `albums/collections/{id}`, `albums/media/analyze-draft`).

**Cảm ơn phần mô tả field** — `taggedMemberId` ghi rõ "Stable family member id
used by FE to filter already-tagged face suggestions", đúng thứ FE cần.

## 2. Calendar `myResponseStatus` — ❓ KHÔNG kiểm được qua Swagger

Cả 7 endpoint calendar **vẫn không có response schema nào**:

```
POST   calendar/events                    -> không có schema
GET    calendar/events                    -> không có schema
GET    calendar/events/{eventId}          -> không có schema
PATCH  calendar/events/{eventId}          -> không có schema
PATCH  calendar/events/{eventId}/cancel   -> không có schema
POST   calendar/events/{eventId}/respond  -> không có schema
PATCH  calendar/events/{eventId}/reminder -> không có schema
```

Grep `myResponseStatus` / `myParticipant` / `CalendarEventParticipant` trong
Swagger live: **0 kết quả**. Đây **không phải bằng chứng chưa deploy** — chỉ là
Swagger không mô tả. FE đang xác minh bằng cách bấm thử trên máy thật.

**Nhờ BE bổ sung response schema cho nhóm calendar**, giống như đã làm rất tốt
với album. Không có schema thì mỗi lần đổi contract FE lại phải đoán và verify
thủ công.

## 3. `SUBMISSION_OVERDUE` — ❓ không nằm trong Swagger

Mã lỗi không được document (bình thường). FE đã bắt theo **mã**, không dò chuỗi
message. Đang verify bằng cách nộp bài quá hạn thật.

---

## Bug FE đã tự sửa (không cần BE làm gì)

Người duyệt mở sheet duyệt thì gặp lỗi BE:

```
Chỉ có thể duyệt minh chứng đang chờ xem xét
```

Gốc ở FE: `fetchLatestSubmission` lấy `list.last` — **phần tử cuối mảng**, không
phải bài mới nhất. Phân công đã nộp nhiều lần thì FE bốc trúng bài cũ (đã
APPROVED/REJECTED) và vẫn dựng nút Duyệt/Từ chối trên đó.

Đã sửa: chọn bài **WAITING_REVIEW mới nhất** theo `submittedAt`; không còn bài
nào chờ duyệt thì hạ sheet xuống chế độ chỉ xem. **Lỗi BE trả về là đúng**, FE
gọi sai.

## Cảm ơn 2 thứ BE làm thêm ngoài yêu cầu

1. **`isLate`** trong `TaskSubmissionListItemResponseDto` — đúng đề xuất của FE
   ở `DE_XUAT_BE_TASK_QUA_HAN_2026-08-19.md`. Đã wire, người duyệt thấy nhãn
   "Nộp sau hạn".
2. **`FaceScanJobSummaryResponseDto`** được document đầy đủ:
   `status, statuses, detectedFaceCount, suggestionCount, error, staleAt,
   retryDelaySeconds, forceRescanLimit, forceRescanCooldownSeconds,
   retryAllowed, retryEndpoint`.

---

## Còn cần BE xác nhận

**a) Enum trạng thái face-scan không có `NO_FACE`.**
Swagger ghi `status: PENDING | PROCESSING | COMPLETED | FAILED`. FE đang có
nhánh map `NO_FACE | NOFACE | NONE` — nhánh này **không bao giờ chạy**. Vậy
"ảnh không có khuôn mặt nào" được biểu diễn bằng `COMPLETED` +
`detectedFaceCount = 0`, đúng không? Xác nhận thì FE bỏ nhánh chết và dùng số
thật thay cho câu đoán hiện tại.

**b) Job face-scan treo ở PROCESSING** (báo sáng 19/08) đã xử lý chưa? Swagger
giờ có `staleAt` + `retryDelaySeconds`, nhưng chưa rõ worker đã chạy lại chưa.

**c) `GET .../assignments/{id}/submissions` sắp xếp theo thứ tự nào?**
FE đã tự sắp theo `submittedAt` nên không phụ thuộc nữa, nhưng nếu BE có bảo
đảm thứ tự thì nhờ ghi vào mô tả endpoint.

**d) Người đã gắn thẻ có bị loại khỏi gợi ý khuôn mặt không?** (hỏi từ sáng,
chưa có trả lời). FE đang viết câu thông báo theo giả định là CÓ.

**e) Response schema cho nhóm calendar** — xem mục 2.
