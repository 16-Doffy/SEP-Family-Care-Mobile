# Tổng hợp các mục cần BE xử lý — Flow Nhiệm vụ (19/08/2026)

Gom toàn bộ phát hiện khi rà luồng **tạo task → giao việc → đặt thưởng → nộp
minh chứng → duyệt → nhận thưởng**, cho cả 3 vai Manager / Deputy / Member.

FE đã đối chiếu với Swagger live (`/api/docs-json`, tải 19/08) và **gọi đủ
47/47 endpoint task**; DTO của cả 6 bước cốt lõi khớp từng field. Các mục dưới
đây là những chỗ FE **không tự xử lý được**.

---

## 🔴 BẮT BUỘC

### 1. Không có endpoint gia hạn phân công — quá hạn là ngõ cụt tuyệt đối

Sau khi BE bật `SUBMISSION_OVERDUE`, một phân công quá hạn không còn đường nào
hoàn thành:

| Ai | Làm gì | Kết quả |
|---|---|---|
| Người làm | `POST .../submissions` | **400 `SUBMISSION_OVERDUE`** |
| Người quản lý | muốn dời `dueAt` | **không có endpoint nào** |
| Người quản lý | `PATCH .../reassign` | Nhận `dueAt` nhưng mô tả ghi *"cho **thành viên khác**"* → không gia hạn cho chính người đang giữ được |

Phân công nằm mãi ở `ASSIGNED`/`IN_PROGRESS`, không ai nộp được, không ai duyệt
được, không có trạng thái kết thúc nào để đóng lại.

**Đề xuất (chọn 1):**
1. `PATCH /families/{familyId}/tasks/assignments/{assignmentId}` body
   `{ dueAt?, startAt? }` — **ưu tiên**.
2. Hoặc cho `PATCH .../reassign` nhận lại chính `assignedToMemberId` hiện tại,
   và sửa mô tả endpoint cho khớp.

*FE tạm vá:* thêm ô hạn mới vào sheet "Phân công lại" và cho nút đó hiện cả khi
quá hạn. Nhưng cách này **bắt buộc phải đổi sang người khác**.

### 2. Phân công của task định kỳ không có `startAt` / `dueAt`

FE gửi đúng DTO:
```
GenerateTaskAssignmentsDto {
  assignedToMemberId*, fromDate*, toDate*, startTime "HH:mm", dueTime "HH:mm"
}
```
Ví dụ thật: `fromDate 19/8/2026`, `toDate 18/9/2026`, `startTime 09:00`.
BE tạo đúng ~30 phân công.

**Nhưng `GET .../tasks/{taskId}/assignments` không trả `startAt`/`dueAt` cho
từng phân công.** Đo trên máy thật: 13 và 28 phân công hiển thị **giống hệt
nhau**, chỉ có tên + trạng thái.

**Hệ quả:** giờ người quản lý đặt **bị mất**; người làm nhận 30 phân công cùng
lúc và làm hết trong một ngày — task định kỳ mất hoàn toàn ý nghĩa.

**Nhờ BE:**
- Xác nhận `generate-assignments` có **lưu** `startAt`/`dueAt` riêng theo từng
  ngày không (ngày N + `startTime`, ngày N + `dueTime`).
- Bổ sung 2 field vào response `GET .../tasks/{taskId}/assignments` và
  `GET .../tasks/my-assignments`.
- BE có chặn `PATCH .../assignments/{id}/start` khi **chưa tới** `startAt`
  không? FE muốn khoá nút "Bắt đầu làm" cho phân công ngày mai trở đi, nhưng
  khoá ở UI không phải ràng buộc thật.

### 3. Deputy tự tư lợi trên task được giao cho chính mình

Manager giao task cho Deputy → Deputy có toàn quyền quản lý nên tự **sửa hạn**,
tự **huỷ nhiệm vụ**, tự **huỷ phân công của mình**, và nguy hiểm nhất là tự
**đặt mức thưởng** cho chính mình.

BE đã chặn đúng ca "tự duyệt bài của mình". Nhờ chặn nốt: người đang là
**assignee của task** thì không được sửa/huỷ task đó, không được tạo/sửa/xoá
`reward-setting` của nó, không được tự huỷ phân công của mình.

FE sẽ ẩn nút tương ứng, nhưng đó chỉ là **rào giao diện** — ai có APK vẫn gọi
thẳng API được.

---

## 🟠 NÊN CÓ

### 4. Đặt thưởng sau khi duyệt thì thành viên mất thưởng, không ai biết

Swagger mô tả `autoCreateSettlement`: *"Tự tạo ghi nhận thưởng **khi bài nộp
được duyệt**"* — chạy đúng khoảnh khắc đó.

Kịch bản rất thường gặp: giao việc → người làm hoàn thành → **duyệt** → *sau đó
mới đặt thưởng*. Tới bước cuối thì không có gì hồi tố: bài đã duyệt **vĩnh viễn
không có settlement**, thành viên không nhận được gì và **không có dấu hiệu
nào** cho biết.

**Đề xuất:** khi `POST`/`PATCH .../reward-setting` với
`autoCreateSettlement = true`, tạo bù settlement cho các bài đã `APPROVED`. Hoặc
tối thiểu trả về **số bài nộp đã duyệt chưa có settlement** để FE cảnh báo.

### 5. Thiếu response schema cho nhóm assignment

`GET .../tasks/{taskId}/assignments` hiện là `"200": { "description": "" }` —
không có schema. FE không có cách nào biết field nào có ngoài thử live; đây
chính là lý do mục 2 mất cả buổi mới phát hiện.

Nhờ bổ sung giống như đã làm rất tốt với album/tag (`AlbumTagResponseDto`,
`AlbumMediaResponseDto`).

---

## 🟡 CẦN XÁC NHẬN

### 6. `POST .../submissions/{submissionId}/reward-settlement` không có request body

1. Số tiền/điểm lấy từ `reward-setting` hiện tại của task, đúng không?
2. Nếu đổi mức thưởng **sau khi** bài đã duyệt, settlement tạo thủ công lấy
   **mức lúc duyệt** hay **mức hiện tại**?
3. Gọi hai lần trên cùng `submissionId` thì BE chặn trùng hay tạo 2 settlement?
   FE hiện chỉ ẩn nút khi đã thấy settlement trong danh sách.

### 7. `proofs: []` có hợp lệ không?

`CreateTaskSubmissionDto.proofs` khai `required` nhưng **không có `minItems`**.
Nộp bài chỉ bằng `submissionNote` (không minh chứng nào) có được không? FE hiện
khoá nút Nộp khi không có ảnh lẫn ghi chú — nếu BE cho phép mảng rỗng thì FE nới
lại.

### 8. Deputy được làm gì ở cấp task?

Tạo task / huỷ task / xoá `reward-setting` — Deputy có quyền không? FE hiện
**không gate gì cả** ở màn quản lý (Deputy dùng chung màn với Manager), nên nếu
BE cấm thì Deputy bấm vào sẽ ăn 403 giữa chừng.

### 9. `GET .../assignments/{id}/submissions` sắp xếp theo thứ tự nào?

FE đã tự sắp theo `submittedAt` nên không phụ thuộc nữa, nhưng nếu BE có bảo
đảm thứ tự thì nhờ ghi vào mô tả endpoint.

---

## ✅ Đã xác nhận ĐÚNG, không cần làm gì

- **Ghi chú khi nộp + ý kiến khi duyệt**: `submissionNote` / `reviewNote` đã đủ,
  FE đã hiển thị cả hai cho người nộp. Không thiếu endpoint.
- **`isLate`** trong `TaskSubmissionListItemResponseDto` — BE đã bổ sung đúng
  đề xuất của FE, đã wire.
- **`SUBMISSION_OVERDUE`** — FE bắt theo mã, không dò chuỗi message.
- **DTO 6 bước cốt lõi** (`CreateTaskDto`, `CreateTaskAssignmentDto`,
  `CreateRewardSettingDto`, `CreateTaskSubmissionDto`, `TaskProofDto`,
  `ReviewTaskSubmissionDto`) — khớp từng field với FE.
