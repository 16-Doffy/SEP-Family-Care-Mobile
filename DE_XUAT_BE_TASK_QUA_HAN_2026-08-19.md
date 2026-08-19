# Đề xuất BE — Luật "nhiệm vụ quá hạn" chưa được định nghĩa

**Ngày:** 19/08/2026 · **Người gửi:** FE Mobile · **Mức độ:** Nên có (FE đã xử
lý tạm được, nhưng đang phải tự đoán luật)

## Hiện trạng

Enum trạng thái phân công của BE không có `OVERDUE`:

```
PENDING | ASSIGNED | IN_PROGRESS | SUBMITTED | APPROVED | REJECTED
| CANCELED | UNAVAILABLE
```

Quá hạn vì vậy **không phải một trạng thái**, chỉ là so sánh `dueAt` với thời
điểm hiện tại. FE đang tự tính và tự hiển thị nhãn "Quá hạn".

## Câu hỏi cần BE chốt

**1. Quá hạn có chặn nộp bài không?**

Hiện `POST .../assignments/{id}/submissions` vẫn nhận bài nộp sau `dueAt`. FE
**cố ý không tự chặn**: chặn ở FE là đặt ra luật thay BE, và người trễ 5 phút sẽ
mắc kẹt vĩnh viễn vì không còn đường nào đưa phân công về `APPROVED`.

FE tạm thời **cảnh báo mà vẫn cho nộp**: "Bài nộp này đã quá hạn. Bạn vẫn nộp
được, nhưng người quản lý sẽ thấy là nộp trễ."

Nếu BE muốn chặn thật thì nhờ trả 4xx kèm `code` riêng (vd `SUBMISSION_OVERDUE`)
để FE hiện đúng thông báo, thay vì FE tự đoán.

**2. Có đánh dấu bài nộp trễ không?**

Hiện response submission không có field nào cho biết bài này nộp sau hạn. Người
duyệt vì vậy không phân biệt được nộp đúng hạn hay trễ, trừ khi tự nhẩm ngày.
Đề xuất thêm `isLate: boolean` (hoặc `submittedAt` để FE tự so với `dueAt`).

**3. Quá hạn mà không nộp thì phân công có tự đổi trạng thái không?**

Hiện phân công nằm mãi ở `ASSIGNED`/`IN_PROGRESS`. Nếu BE có job tự chuyển sang
một trạng thái kết thúc (vd hết hạn / bỏ lỡ) thì nhờ cho biết tên trạng thái để
FE hiển thị đúng; nếu không có thì FE giữ nguyên cách hiện nhãn tự tính.

## FE đã làm gì trong lúc chờ

- Hiện nhãn "Quá hạn" ở cả màn quản lý và màn người làm (tự tính từ `dueAt`).
- Hạn hiển thị kèm **giờ phút** — trước chỉ có ngày/tháng nên người làm không
  hiểu vì sao đang bị tính là trễ.
- Nhãn quá hạn tự bật khi đến giờ, không cần thoát ra vào lại màn hình.
- Cảnh báo nộp trễ trong sheet nộp bài, không chặn.

---

# Phụ lục — Response sự kiện lịch không nói được trạng thái của chính người gọi

**Mức độ:** Nên có (FE đã tự xử lý, nhưng đang đoán schema)

## Hiện tượng

`POST /families/{fid}/calendar/events/{eventId}/respond` trả 2xx, app báo "Đã
cập nhật phản hồi". Nhưng gọi lại danh sách sự kiện thì chip vẫn là "Chưa phản
hồi" — trạng thái không đổi trên UI.

## Nguyên nhân phía FE (đã sửa)

Parser chỉ đọc `responseStatus` phẳng ở gốc object sự kiện, hoặc trong object
`myParticipant` / `participant`. Khi BE trả `participants` dạng **mảng object**
thì parser cũ chỉ moi `memberId` ra khỏi mảng đó, không hề đọc `responseStatus`
của từng phần tử. FE nay dò trong mảng để tìm phần tử của chính người đang
đăng nhập, khớp bằng cả `memberId` / `familyMemberId` / `userId` / `member.id` /
`member.user.id` / `user.id` vì không biết BE khoá theo cái nào.

## Nhờ BE chốt

1. **Response của `GET .../calendar/events` có field nào cho biết trạng thái
   phản hồi của người đang gọi không?** Nếu chưa có, đề xuất thêm
   `myResponseStatus` phẳng ở gốc mỗi sự kiện — đỡ phải quét cả mảng
   participants chỉ để tìm một dòng.
2. **Participant được khoá theo `familyMember.id` hay `user.id`?** FE đang chấp
   nhận cả hai vì Swagger chưa có schema cho phần tử `participants`.
3. **`POST .../respond` có trả về sự kiện đã cập nhật không?** Nếu có thì FE
   dùng thẳng, khỏi phải gọi lại danh sách.

Trong lúc chờ, FE giữ tạm phản hồi vừa gửi ở bộ nhớ máy (chỉ ghi lại kết quả
của request đã trả 2xx, không phải dữ liệu giả) để chip đổi ngay sau khi bấm.
Lớp này bị BE ghi đè ngay khi BE nói rõ được trạng thái.
