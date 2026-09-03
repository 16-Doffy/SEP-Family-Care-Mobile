# Giải thích toàn bộ flow Tài chính — tài liệu tham chiếu đầy đủ

**Cập nhật:** 31/08/2026 · Đối chiếu trực tiếp source code (không đoán tên
nút). Dùng kèm `KICH_BAN_DEMO_TAI_CHINH_CHI_TIET_2026-08-30.md` (bản đó là
đường đi tuyến tính để demo; file này là **bản đầy đủ mọi nhánh** trong
từng màn, để trả lời khi hội đồng hỏi sâu vào 1 góc cụ thể).

Sơ đồ tư duy tổng (nhắc lại nhanh):

```
Quỹ gia đình (Ví) ── chia theo % ──► Mô hình tài chính (các Hũ)
                                            │
                        gán Danh mục ───────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
          Kế hoạch ngân sách        Mục tiêu tài chính      Tài chính tháng cá nhân
          (định mức theo hũ)         (tách từ hũ Tiết kiệm)   (Member tự khai)
                    │                       │
                    ▼                       │
          Cảnh báo tài chính  ◄──────────────┘ (mục tiêu có nguy cơ cũng sinh cảnh báo)
                    │
                    ▼
          Báo cáo tài chính (tổng hợp 4 tab)

Member muốn chi vượt định mức → Yêu cầu hỗ trợ chi tiêu → Manager duyệt
```

---

## 1. Ví (Wallet) — trung tâm, mọi số liệu đổ về đây

### 1.1. Xem tổng quan
- Card đầu: **"Quỹ gia đình · [tháng]"** — số dư + tổng thu/chi trong kỳ.
- Chuyển kỳ xem tháng trước (không ghi giao dịch được ở kỳ cũ, chỉ xem).
- Bấm icon **?** cạnh tiêu đề → giải thích kỳ tính (`_showPeriodExplainerSheet`).

### 1.2. Ghi giao dịch
- 2 nút **"Thu" / "Chi"** ngay trên hero card.
- Sheet ghi có chọn **Danh mục** → BE tự route vào đúng hũ theo mapping đã
  đặt ở Mô hình tài chính (mục 2.3).

### 1.3. Checklist đầu tháng
- `MonthStartChecklist` — nhắc việc cần làm đầu tháng, có mục **"Kết
  chuyển số dư"** dư thừa tháng trước sang mục tiêu tiết kiệm (nếu gia đình
  chưa có mục tiêu nào, app tự nhắc tạo mục tiêu trước).

### 1.4. Tình hình tài chính gia đình
- Card link sang `/manager/family-finance-status` — xem thu/chi/đóng
  góp/mục tiêu/tiền dư theo tháng, dạng tổng hợp gọn.

### 1.5. Ngân sách tháng này (vòng tròn %)
- Ring chart % đã chi / thu nhập, kèm badge màu theo mức an toàn còn lại
  (đỏ <10%, vàng <30%, xanh còn lại).

### 1.6. Chia theo hũ (jar breakdown)
- Danh sách hũ với % mục tiêu + số tiền mục tiêu/thực tế mỗi hũ, dựa theo
  mô hình tài chính đang áp dụng — đây là chỗ **chứng minh trực quan nhất**
  việc chia hũ hoạt động đúng.

### 1.7. (Mới thêm 30/08) Lối tắt "Tài chính liên quan"
- Dải 6 nút bấm thẳng: Mô hình tài chính, Kế hoạch ngân sách, Mục tiêu tiết
  kiệm, Cảnh báo tài chính, Báo cáo tài chính, Hỗ trợ chi tiêu — không cần
  vòng qua menu "Tôi" nữa.

---

## 2. Mô hình tài chính — nền tảng chia hũ

### 2.1. Chọn kiểu mô hình
- 3 lựa chọn: **5 lọ** (mặc định cố định %), **80/20**, hoặc **Tuỳ chỉnh**
  (tự thêm/xoá hũ, tự đặt %).

### 2.2. Sửa % từng hũ
- Thanh trạng thái phân bổ trên cùng cho biết còn bao % chưa gán / đã
  vượt 100% chưa — có cảnh báo khi mất cân bằng.

### 2.3. Gán danh mục vào hũ
- Nút **"Gán danh mục vào hũ"** → chọn 1 danh mục Chi → gán vào 1 hũ cụ
  thể. Câu giải thích trong màn: *"Khi ghi khoản chi, chỉ cần chọn danh
  mục. Backend sẽ tự gán vào đúng hũ."*
- Danh mục **chưa gán hũ nào** thì khoản chi thuộc danh mục đó không được
  tính vào hũ nào cả (hiện ở phần "chưa gán" trong báo cáo theo hũ).

### 2.4. Chia quỹ theo mô hình đang áp dụng
- Nút **"Chia quỹ theo mô hình đang áp dụng"** — khác Bước 2.3: dùng để
  chia lại **1 khoản tiền có sẵn** (không phải giao dịch mới) theo đúng %
  hiện tại, ví dụ sau khi đổi % hũ muốn áp dụng ngay cho số dư cũ.
- Có **"Lịch sử chia quỹ"** xem lại các lần đã chia.

### 2.5. Đổi mô hình đang áp dụng
- Sửa % khi đã có 1 mô hình đang active → hệ thống **không sửa trực
  tiếp**, tạo 1 bản điều chỉnh mới, giữ nguyên mapping danh mục cũ, chỉ áp
  tỷ lệ mới (tránh mất lịch sử).

---

## 3. Kế hoạch ngân sách

### 3.1. Tạo kế hoạch
- Nút **"Tạo kế hoạch ngân sách"** → nhập **Tên kế hoạch**, **Kỳ hạn**
  (tháng/quý/năm), thu/chi dự kiến chung.
- Trạng thái vòng đời: `DRAFT` → **"Kích hoạt"** → `ACTIVE` → **"Đóng"** →
  `CLOSED` (hoặc `CANCELED`).

### 3.2. Thêm dòng ngân sách (Budget Line)
- Mỗi dòng: chọn Danh mục, gắn Hũ, đặt **Ngân sách** (định mức) + **Mốc
  cảnh báo** (số tiền hoặc %).
- Ghi chi thật thuộc danh mục này → dòng cập nhật "Đã chi" theo thời gian
  thực, đổi màu khi vượt mốc.

### 3.3. Cảnh báo kỳ không hiệu lực
- Kế hoạch `ACTIVE` nhưng kỳ **chưa tới** hoặc **đã qua** hôm nay → banner
  cảnh báo riêng: chi hôm nay sẽ **không** được tính vào kế hoạch này và
  **không** sinh cảnh báo vượt ngân sách — tránh hiểu nhầm kế hoạch "hoạt
  động" là áp dụng ngay lập tức.

### 3.4. Xem báo cáo kế hoạch vs thực tế
- Link **"Xem báo cáo kế hoạch vs thực tế"** ngay trong card kế hoạch —
  dẫn sang đúng dữ liệu ở Báo cáo tài chính (mục 6) đã lọc theo kế hoạch
  này.

---

## 4. Mục tiêu tài chính (tiết kiệm)

### 4.1. Tạo mục tiêu
- Nút tạo → sheet **"Tạo mục tiêu tiết kiệm"**: **Tên mục tiêu**, **Số
  tiền mục tiêu (₫)**, **Góp hàng tháng dự kiến (₫, tùy chọn)** — đây
  chính là số "tự khai" của người tạo — **Hạn hoàn thành (tùy chọn)**.

### 4.2. Góp tiền cá nhân (Tiền túi)
- Nút **"Góp tiền cá nhân (Tiền túi)"** trên card chi tiết → nộp trực
  tiếp từ nguồn cá nhân vào mục tiêu. Có tuỳ chọn **liên kết với kế hoạch
  đóng góp hàng tháng** hay không.

### 4.3. Trích từ số dư quỹ chung (chỉ Manager/Deputy)
- Nút **"Trích từ số dư quỹ chung"** — dùng tiền dư thừa tích luỹ của
  tháng để góp vào mục tiêu, không phải tiền túi cá nhân.

### 4.4. Kế hoạch đóng góp theo tháng
- Xem/đặt kế hoạch góp đều mỗi tháng cho mục tiêu, tách biệt khỏi việc
  góp tay từng lần ở 4.2/4.3.

### 4.5. Chi tiết tiến độ
- Card "Tiến độ chi tiết": Đã góp / Mục tiêu / Còn thiếu / Tiến độ % / Hạn
  hoàn thành / Số ngày-tháng còn lại / **Mục tiêu góp mỗi tháng (đã
  khai)** (số tự khai lúc tạo) / **Nên góp mỗi tháng** (số BE tính =
  còn thiếu ÷ số tháng còn lại — **không phải AI**, không chia theo từng
  thành viên).
- Trạng thái: `ACTIVE` / `ACHIEVED` / `AT_RISK` (Có nguy cơ không đạt) /
  `CANCELED`.

### 4.6. Sửa/xoá lịch sử đóng góp
- Mỗi dòng trong "Lịch sử đóng góp" có icon bút chì (sửa số tiền) và
  thùng rác (xoá) — dùng khi ghi nhầm số.

### 4.7. Huỷ mục tiêu
- Nút **"Huỷ mục tiêu"** ở màn danh sách — có xác nhận trước khi huỷ.

---

## 5. Tài chính tháng cá nhân (Member tự khai)

### 5.1. Khai báo
- Chỉnh sửa hồ sơ → 3 cặp field **dự kiến / tự khai**: Thu nhập, Chi tiêu
  cá nhân, Đóng góp chung. Mỗi cặp có công tắc **"Chia sẻ với Trưởng/Phó
  nhóm"** cho thu nhập và chi tiêu (đóng góp chung luôn hiển thị chung,
  không có toggle riêng).

### 5.2. Xem tài chính tháng của mình
- Card "Khai báo thu chi" (số tự khai) + card "Đóng góp quỹ gia đình" (4
  dòng: Kế hoạch / Tự khai báo / Ghi nhận sổ quỹ / **Thực tế, chính
  thức**) + card "Đóng góp mục tiêu" (tổng kế hoạch/đã góp theo từng mục
  tiêu đang tham gia).

### 5.3. Manager xem tài chính thành viên khác
- Hồ sơ thành viên → card "Tài chính tháng này": Thu nhập/Chi tiêu dự
  kiến (ẩn thành "Riêng tư" nếu member không bật chia sẻ), **Đóng góp
  chung tự khai**, **Đóng góp quỹ (thực tế, chính thức)** → nút **"Xem tài
  chính chi tiết"** sang màn 5.2 với dữ liệu member đó.

---

## 6. Cảnh báo tài chính

### 6.1. Xem danh sách
- 3 loại cảnh báo: **Vượt ngân sách** (`OVER_BUDGET`), **Mục tiêu có nguy
  cơ** (`GOAL_AT_RISK`), **Chi không thiết yếu cao** (`NON_ESSENTIAL_TOO_HIGH`).
- Mức độ: Cao / Trung bình / Thấp (màu đỏ/cam/xám tương ứng).

### 6.2. Tính lại cảnh báo
- Nút **"Tính lại cảnh báo từ dữ liệu hiện tại"** — bấm để BE quét lại
  toàn bộ số liệu và sinh cảnh báo mới nhất (không tự động realtime).

### 6.3. Xử lý cảnh báo (chỉ Manager/Deputy — Member chỉ xem)
- **"Đã xem"** (`ACKNOWLEDGED`) → **"Đánh dấu đã xử lý"** (`RESOLVED`,
  có xác nhận trước khi đánh dấu).

---

## 7. Báo cáo tài chính (4 tab)

1. **Ngân sách** — báo cáo kế hoạch vs thực tế theo từng dòng ngân sách.
2. **Theo hũ** — target/actual mỗi hũ theo kỳ (cùng nguồn dữ liệu jar
   breakdown ở Ví).
3. **Chi không thiết yếu** — tỷ lệ chi không thiết yếu / tổng chi.
4. **Ngân sách & Mục tiêu** — trạng thái `ON_TRACK` (Đúng kế hoạch) /
   `OVER_TARGET` (Vượt mục tiêu) / `UNDER_TARGET` (Dưới mục tiêu).

- Có nút **"Xuất CSV"** — xuất báo cáo ra file, điểm cộng nếu hội đồng
  hỏi về khả năng tích hợp/báo cáo cho kế toán gia đình.
- Field nào Swagger chưa document schema thì render qua `JsonReportView`
  (đã dịch tiếng Việt đầy đủ 30/08) thay vì đoán sai tên field.

---

## 8. Yêu cầu hỗ trợ chi tiêu

### 8.1. Member tạo yêu cầu
- Nút **"Gửi yêu cầu hỗ trợ"** → nhập **Số tiền (₫)** + **Mục đích** →
  gửi.

### 8.2. Manager xử lý
- 2 nút **"Từ chối" / "Phê duyệt"**, có ô ghi chú quyết định (tuỳ chọn).

### 8.3. Member huỷ yêu cầu
- Nút **"Hủy yêu cầu"** (chỉ khi còn chờ duyệt) → xác nhận huỷ.

---

## Bảng tra nhanh — hỏi gì, trả lời ở mục nào

| Hội đồng hỏi | Xem mục |
|---|---|
| Tiền chia vào hũ như thế nào? | 2.1–2.3 |
| Sao ghi 1 khoản chi mà hũ tự trừ? | 2.3 + 1.2 |
| Khác gì giữa "auto-route" và nút chia quỹ thủ công? | 2.3 vs 2.4 |
| Vượt ngân sách thì sao? | 3.2 → 6.1 |
| Mục tiêu tính mức góp/tháng kiểu gì? | 4.5 (nhấn mạnh: công thức, không phải AI) |
| Sao có 3 số cho "đóng góp"? | 5.2 (Tự khai / Ghi nhận sổ quỹ / Thực tế chính thức) |
| Member muốn chi thêm ngoài định mức thì sao? | 8.1–8.2 |
| Có xuất báo cáo ra ngoài không? | 7 (Xuất CSV) |
