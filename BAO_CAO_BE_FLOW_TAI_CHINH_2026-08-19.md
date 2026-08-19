# Báo cáo BE — Flow tài chính (cảnh báo, mô hình hũ, kết chuyển) 19/08/2026

FE đã rà `finance/alerts`, `finance/reports/jar-target-actual`,
`finance/financial-goals/surplus-availability` và đối chiếu Swagger live.

## ✅ Không có gì sai ở BE — 3 điểm đã xác nhận đúng

1. **`jar-target-actual` tính đúng như tài liệu.**
   `targetAmount = trackedAmount * targetPercentage / 100`. Mẫu số là **tổng
   chi đã theo dõi**, không phải thu nhập. FE trước đây đặt tên mục là "Hạn mức
   theo tỷ lệ thu nhập" nên người dùng tưởng BE tính sai — **lỗi của FE**, đã
   sửa lại thành "Tỷ trọng chi tiêu theo hũ".

2. **Cảnh báo chỉ sinh từ ngân sách + mục tiêu.** Đúng như mô tả
   `POST alerts/recompute`. Chi vượt tỷ lệ hũ của mô hình 80/20 **không** tạo
   cảnh báo — FE đã ghi rõ điều này ra màn hình để người dùng khỏi tưởng hỏng.

3. **5 endpoint cảnh báo tài chính** FE đã gọi đủ, 3 loại `OVER_BUDGET` /
   `GOAL_AT_RISK` / `NON_ESSENTIAL_TOO_HIGH` đều đã dịch và hiển thị.

## 🟡 Nhờ BE xác nhận / bổ sung

### 1. `jar-target-actual` có trả `trackedAmount` ở top-level không?

FE cần hiện thẳng con số mẫu số ra UI (nếu không, người dùng thấy "hạn mức" tự
tăng mỗi lần chi thêm và tưởng app tính sai). Hiện FE **cộng bù** bằng tổng
`actualAmount` các hũ + `unmappedAmount`. Nếu BE có sẵn field này thì nhờ cho
biết tên chính xác; response endpoint này chưa có schema trong Swagger.

### 2. `GET .../financial-goals/surplus-availability` — response schema

Endpoint trả `"200": { "description": "So du quy thang va phan da phan bo vao
muc tieu" }`, không có schema. FE đang đọc `totalSurplus` /
`allocatedSurplus` / `availableSurplus` theo phỏng đoán. Nhờ bổ sung schema.

### 3. Mục tiêu `AT_RISK` có được nhận phân bổ số dư không?

FE hiểu `AT_RISK` là **cảnh báo tiến độ**, không phải trạng thái đóng mục tiêu,
nên vẫn cho góp tiền vào (chỉ `ACHIEVED`/`CANCELED` mới chặn). Nhờ xác nhận
`POST .../financial-goals/{goalId}/surplus-allocations` **không** chặn mục tiêu
`AT_RISK` — nếu BE chặn thì FE phải lọc lại.

Đây là ca thực tế: gia đình có 64.981.111 đ chưa phân bổ và một mục tiêu đang
`AT_RISK` thiếu 340 triệu. Chặn nhầm thì tiền không có chỗ đi.

## 🐞 Bug FE đã tự sửa (ghi lại để BE khỏi phải kiểm)

- Card "Kết chuyển tháng trước" báo *"chưa có mục tiêu tài chính nào đang
  chạy"* dù đang có mục tiêu, vì FE lọc `status == 'ACTIVE'` nên loại luôn mục
  tiêu `AT_RISK`. Đúng cái mục tiêu cần tiền nhất lại bị giấu. Đã đổi sang lọc
  theo "còn nhận góp được".
- Nhãn "Hạn mức theo tỷ lệ thu nhập" nói sai công thức của BE (xem mục ✅ 1).
