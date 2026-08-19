# Đề xuất BE — Phân công quá hạn bị kẹt & thưởng đặt sau khi duyệt bị mất

**Ngày:** 19/08/2026 · **Người gửi:** FE Mobile

---

## 🔴 BẮT BUỘC — Không có endpoint gia hạn phân công, quá hạn là ngõ cụt tuyệt đối

Sau khi BE bật `SUBMISSION_OVERDUE`, một phân công quá hạn **không còn đường nào
để hoàn thành**:

| Ai | Làm gì | Kết quả |
|---|---|---|
| Người làm | `POST .../submissions` | **400 `SUBMISSION_OVERDUE`** |
| Người quản lý | muốn dời `dueAt` | **không có endpoint nào** |
| Người quản lý | `PATCH .../reassign` | Nhận `dueAt`, nhưng mô tả ghi *"Giao lại công việc cho **thành viên khác**"* nên không dùng để gia hạn cho chính người đang giữ |

Phân công nằm mãi ở `ASSIGNED`/`IN_PROGRESS`, không ai nộp được, không ai duyệt
được, và cũng không có trạng thái kết thúc nào để đóng lại.

**Đề xuất (chọn 1):**

1. `PATCH /families/{familyId}/tasks/assignments/{assignmentId}`
   body `{ dueAt?, startAt? }` — endpoint gia hạn riêng. **Ưu tiên phương án này.**
2. Hoặc cho phép `PATCH .../reassign` nhận lại chính `assignedToMemberId` hiện
   tại (chỉ đổi `dueAt`), và sửa mô tả endpoint cho khớp.

**FE đang làm gì trong lúc chờ:** thêm ô đặt hạn mới vào sheet "Phân công lại"
(BE vốn đã nhận `dueAt`, FE chỉ là chưa gửi), và cho nút đó hiện cả khi phân
công quá hạn chứ không chỉ khi người làm báo bận. Đây là **đường thoát duy nhất
được BE hỗ trợ hiện giờ**, nhưng nó bắt buộc phải đổi sang người khác — không
gia hạn cho đúng người đang làm dở được.

---

## 🟠 NÊN CÓ — Đặt thưởng sau khi duyệt thì thành viên mất thưởng, không ai biết

Swagger mô tả `CreateRewardSettingDto.autoCreateSettlement`:

> *"Tự tạo ghi nhận thưởng **khi bài nộp được duyệt**"*

Nó chạy đúng khoảnh khắc duyệt. Kịch bản rất thường gặp:

1. Người quản lý tạo task, giao việc
2. Người làm hoàn thành, người quản lý **duyệt**
3. Người quản lý **mới đặt thưởng**

Tới bước 3 thì không có gì hồi tố. Bài nộp đã duyệt **vĩnh viễn không có
settlement**, thành viên không nhận được gì và **không có dấu hiệu nào** cho
biết điều đó đã xảy ra.

**Đề xuất:**

- Khi `POST`/`PATCH .../reward-setting` với `autoCreateSettlement = true`, BE
  tạo bù settlement cho các bài nộp đã `APPROVED` của task đó.
- Hoặc tối thiểu: trả về **số bài nộp đã duyệt chưa có settlement** trong
  response, để FE cảnh báo ngay tại chỗ.

**FE đang làm gì:** cảnh báo ngay khi lưu cấu hình thưởng nếu task đã có bài nộp
được duyệt, và hiện dòng đỏ *"Chưa có ghi nhận thưởng cho bài nộp này — thành
viên chưa nhận được gì"* trên hàng phân công, kèm lối tắt tới nút tạo thủ công.
Trước đây nút đó nằm giấu trong sheet "Xem bài nộp" nên gần như không ai tìm ra.

---

## 🟡 HỎI — `POST .../submissions/{submissionId}/reward-settlement` không có request body

Swagger ghi endpoint này **không nhận body**. Nhờ xác nhận:

1. Số tiền/điểm lấy từ `reward-setting` hiện tại của task, đúng không?
2. Nếu người quản lý **đổi mức thưởng** sau khi bài nộp đã được duyệt, thì
   settlement tạo thủ công lấy **mức lúc duyệt** hay **mức hiện tại**?
3. Gọi hai lần trên cùng một `submissionId` thì BE chặn trùng hay tạo 2
   settlement? FE hiện chỉ ẩn nút khi đã thấy settlement trong danh sách — nếu
   BE không chặn thì cần thêm khoá phía FE.

---

## 🔴 BỔ SUNG — Phân công của task định kỳ không có mốc thời gian

FE gửi `POST .../tasks/{taskId}/schedule/generate-assignments` với đúng DTO của
BE:

```
GenerateTaskAssignmentsDto {
  assignedToMemberId*, fromDate*, toDate*, startTime "HH:mm", dueTime "HH:mm"
}
```

Ví dụ thật: `fromDate 19/8/2026`, `toDate 18/9/2026`, `startTime 09:00`.
BE tạo ra ~30 phân công — đúng số lượng.

**Nhưng `GET .../tasks/{taskId}/assignments` không trả `startAt`/`dueAt` cho
từng phân công.** Đo trên máy thật: 13 và 28 phân công hiển thị **giống hệt
nhau**, chỉ có tên + trạng thái, không phân biệt được phân công nào của ngày
nào. FE đã thêm chỗ hiển thị mốc thời gian nhưng không có dữ liệu để hiện.

**Hệ quả nghiêm trọng:** `startTime`/`dueTime` người quản lý đặt **bị mất**.
Người làm nhận 30 phân công cùng lúc và **làm hết 30 cái trong một ngày** —
task định kỳ mất hoàn toàn ý nghĩa "mỗi ngày một việc".

**Nhờ BE:**

1. Xác nhận `generate-assignments` có **lưu** `startAt`/`dueAt` riêng cho từng
   phân công theo ngày không (ngày N + `startTime`, ngày N + `dueTime`).
2. Nếu có lưu thì bổ sung 2 field đó vào response của
   `GET .../tasks/{taskId}/assignments` và `GET .../tasks/my-assignments`.
3. BE có chặn `PATCH .../assignments/{id}/start` khi **chưa tới** `startAt`
   không? FE muốn khoá nút "Bắt đầu làm" cho phân công của ngày mai trở đi,
   nhưng chỉ khoá ở UI thì không phải là ràng buộc thật.

Ghi chú: `GET .../tasks/{taskId}/assignments` hiện **không có response schema**
trong Swagger (`"200": { "description": "" }`) nên FE không có cách nào biết
field nào có, field nào không ngoài thử live.

## 🔴 BỔ SUNG — Deputy tự tư lợi trên task được giao cho chính mình

Manager giao task cho Deputy. Deputy có toàn quyền quản lý task nên có thể tự
**sửa hạn**, tự **huỷ nhiệm vụ**, tự **huỷ phân công của mình**, và nguy hiểm
nhất là tự **đặt mức thưởng** cho chính mình.

BE đã chặn đúng ca "tự duyệt bài của mình". Nhờ chặn nốt nhóm còn lại: người
đang là **assignee của task** thì không được sửa/huỷ task đó, không được
tạo/sửa/xoá `reward-setting` của nó, không được tự huỷ phân công của mình.

FE sẽ ẩn các nút tương ứng, nhưng đó chỉ là **rào giao diện** — ai có APK vẫn
gọi thẳng API được. Ràng buộc thật phải nằm ở BE.
