# Kịch bản demo chi tiết — Module Tài chính

**Cập nhật:** 30/08/2026 · Theo đúng thứ tự em chọn (Quỹ chung → Mô hình
tài chính → thu/chi → Ngân sách → Mục tiêu), đối chiếu code thật nên tên
nút/nhãn dưới đây là chính xác 100% với app, không phải đoán.

## Sơ đồ tư duy (nói trước khi bấm)

```
Quỹ gia đình (Ví) — điểm bắt đầu, cho hội đồng thấy "có gì trong đó"
          │
          ▼
Mô hình tài chính: chia quỹ thành các HŨ theo %
          │
          ▼
Gán mỗi DANH MỤC (Ăn uống, Điện nước...) vào 1 HŨ cụ thể
          │
          ▼
Ghi 1 khoản Thu/Chi, CHỌN đúng danh mục vừa gán
          │
          ▼
BE tự động cộng/trừ đúng vào hũ đã gán — quay lại Ví thấy số hũ đổi
          │
          ▼
Kế hoạch ngân sách: đặt định mức chi cho từng danh mục/hũ
          │
          ▼
Mục tiêu tài chính: tách 1 phần hũ Tiết kiệm thành mục tiêu có hạn,
hệ thống gợi ý mức cần góp mỗi tháng để kịp hạn
```

**2 điều chỉnh lời nói so với ý ban đầu của em — bắt buộc sửa trước khi
lên hội đồng:**

| Đừng nói | Nói đúng thế này |
|---|---|
| "AI sẽ tính ra số tiền" | "Hệ thống tự tính mức gợi ý nên góp mỗi tháng" — công thức đơn giản: `(số còn thiếu) ÷ (số tháng còn lại)`, không phải AI/ML. |
| "Mỗi thành viên sẽ đóng bao nhiêu" | "Hệ thống gợi ý **tổng mức cần góp mỗi tháng** cho cả mục tiêu — chia ai góp bao nhiêu thì gia đình tự thống nhất, app chưa tự động chia theo từng người." |

---

## Bước 1 — Quỹ chung gia đình (Ví)

*Vai: Manager*

1. Tab **Ví** → chỉ vào card đầu tiên **"Quỹ gia đình · [tháng]"** — số
   dư hiện tại + tổng thu/chi trong kỳ.
2. Cuộn xuống card **"Tình hình tài chính gia đình"** → chỉ vào phần chia
   theo hũ (mỗi hũ hiện % mục tiêu, số tiền mục tiêu/thực tế).
3. Nói: *"Đây là bức tranh tổng — số này được cộng dồn từ 2 nguồn: đóng
   góp chung của các thành viên, và các khoản thu/chi được ghi trực
   tiếp vào sổ quỹ."*

---

## Bước 2 — Thiết lập Mô hình tài chính (chia hũ theo %)

*Vai: Manager*

1. **Tôi → Mô hình tài chính**.
2. Xem/sửa % từng hũ (thanh trạng thái phân bổ ở trên cùng cho biết còn
   bao nhiêu % chưa gán, có cân bằng đủ 100% chưa).
3. Thử sửa để tổng **vượt 100%** → chỉ ra cảnh báo hiện ra ngay (phần UX
   đã rà lại đúng yêu cầu).
4. Sửa lại đúng 100%, lưu.

---

## Bước 3 — Gán danh mục vào hũ

*Vai: Manager, vẫn ở màn Mô hình tài chính*

1. Bấm nút **"Gán danh mục vào hũ"**.
2. Chọn 1 danh mục Chi (vd "Ăn uống") → gán vào hũ "Sinh hoạt".
3. Đọc to câu giải thích ngay trong màn: *"Khi ghi khoản chi, chỉ cần
   chọn danh mục. Backend sẽ tự gán vào đúng hũ."*

> Nếu hội đồng hỏi "sao không thấy nút chia quỹ theo % ngay lập tức" —
> giải thích thêm: có 1 nút riêng **"Chia quỹ theo mô hình đang áp
> dụng"** ngay bên dưới, dùng khi muốn chia lại 1 khoản tiền lớn có sẵn
> theo đúng % model — khác với việc tự động route theo từng giao dịch ở
> Bước 4.

---

## Bước 4 — Ghi khoản thu/chi để hũ tăng/giảm

*Vai: Manager hoặc Member có quyền*

1. Quay lại tab **Ví** → bấm **"Thu"** (hoặc "Chi") ở card đầu.
2. Nhập số tiền, **chọn đúng Danh mục** vừa gán ở Bước 3.
3. Xác nhận ghi.
4. Cuộn xuống phần chia theo hũ → chỉ ra số của hũ "Sinh hoạt" đã đổi
   đúng bằng số tiền vừa ghi — **chứng minh trực tiếp cơ chế tự động
   route theo danh mục**, đây là điểm ấn tượng nhất của bước này.

---

## Bước 5 — Kế hoạch ngân sách (đặt định mức chi)

*Vai: Manager*

1. **Tôi → Kế hoạch ngân sách** → tạo kế hoạch mới, chọn kỳ.
2. Thêm 1 dòng ngân sách cho đúng danh mục "Ăn uống": đặt định mức (vd
   5.000.000đ) + mốc cảnh báo (vd 80%).
3. (Tuỳ chọn) Ghi thêm 1 khoản chi ở Ví, cùng danh mục, đủ để vượt mốc
   cảnh báo → mở lại kế hoạch, chỉ ra dòng ngân sách đổi trạng thái/màu.
4. Nếu muốn cho hội đồng thấy luôn Cảnh báo tài chính sinh ra từ đây:
   **Tôi → Cảnh báo tài chính** → chỉ vào cảnh báo vừa xuất hiện.

---

## Bước 6 — Mục tiêu tài chính (tiết kiệm có hạn)

*Vai: Manager*

1. **Tôi → Mục tiêu tiết kiệm** → **Tạo mục tiêu mới**.
2. Nhập tên (vd "Mua xe"), **số tiền mục tiêu**, **hạn hoàn thành** (vd 6
   tháng nữa).
3. Sau khi tạo → mở chi tiết mục tiêu → chỉ vào dòng **mức gợi ý nên góp
   mỗi tháng** (BE tự tính = số còn thiếu ÷ số tháng còn lại).
4. Nói đúng câu đã chỉnh ở bảng trên — **không** gọi là AI, **không**
   nói tự chia theo từng thành viên.
5. (Tuỳ chọn) Góp thử 1 khoản thủ công vào mục tiêu → xem tiến độ (%)
   cập nhật.

---

## Câu hỏi hội đồng hay hỏi — chuẩn bị sẵn câu trả lời

| Câu hỏi | Trả lời ngắn |
|---|---|
| Vì sao hũ tự tăng khi ghi giao dịch? | Danh mục đã được gán sẵn vào 1 hũ (Bước 3) — BE tự route tiền theo mapping đó khi ghi giao dịch chọn đúng danh mục. |
| Mức gợi ý góp mỗi tháng tính thế nào? | Công thức: số tiền còn thiếu chia cho số tháng còn lại tới hạn — không phải AI/ML. |
| Có tự động chia mức góp cho từng thành viên không? | Chưa — hệ thống chỉ đưa ra tổng mức cần góp/tháng cho cả gia đình, việc chia ai góp bao nhiêu do gia đình tự thống nhất ngoài app. |
| Khác gì giữa "route tự động theo giao dịch" và nút "Chia quỹ theo mô hình"? | Route tự động áp dụng cho từng giao dịch mới ghi; "Chia quỹ theo mô hình" dùng khi cần chia lại 1 khoản tiền có sẵn theo đúng % của model đang áp dụng (vd sau khi đổi % hũ). |
