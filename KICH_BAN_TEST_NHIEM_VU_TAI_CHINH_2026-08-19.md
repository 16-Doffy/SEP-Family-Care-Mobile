# Kịch bản test — Nhiệm vụ & Tài chính

**Bản test:** APK build 19/08/2026, commit `8c2571e`

**Cách dùng:** đi hết một kịch bản rồi mới sang kịch bản khác. Mỗi bước ghi
`✅ đúng` / `❌ sai` kèm mô tả thật thấy gì. Không nhảy cóc giữa chừng.

| Ký hiệu | Nghĩa |
|---|---|
| 🆕 | Vừa sửa trong bản này — cần soi kỹ |
| ⛔ | Đã biết hỏng do BE, **không phải lỗi FE** |

**Chuẩn bị:** 3 tài khoản cùng một gia đình — Manager, Deputy, Member. Gỡ bản
cũ trước khi cài nếu máy báo xung đột chữ ký.

---

## KB-1 · Manager giao việc thường cho Member

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Manager → Nhiệm vụ → tạo task, đặt hạn **sau hiện tại vài giờ** | Task hiện trong danh sách, chip "Đang chạy" | |
| 2 | Mở task → **Giao việc** | 🆕 Sheet **cuộn được**, mỗi người có dòng vai trò dưới tên | |
| 3 | Chọn Member → đặt hạn → Xác nhận | Phân công hiện trong "Phân công (n)" | |
| 4 | Mở **Giao việc** lần nữa | 🆕 Người vừa giao có nhãn đỏ *"đã được giao (Chờ làm)"* | |
| 5 | **Đặt thưởng** → MONEY_RECORD → nhập tiền → Lưu | Chip tiền hiện trên thẻ task | |
| 6 | Đăng nhập **Member** → Nhiệm vụ | Thấy task, dòng "Người giao: …", 🆕 **"Hạn: 19/8 21:30"** có giờ phút | |
| 7 | Bấm **Bắt đầu làm** | Trạng thái đổi "Đang làm" | |
| 8 | Bấm **Nộp nhiệm vụ**, không chọn ảnh, không gõ gì | 🆕 Nút "Nộp" **xám, bấm không được** | |
| 9 | Gõ ghi chú | 🆕 Nút "Nộp" **sáng lên ngay** khi vừa gõ | |
| 10 | Chọn 1 ảnh → Nộp | Báo "Đã nộp! Chờ Ba/Mẹ duyệt nhé" | |
| 11 | Mở lại thẻ task | 🆕 Có khối **"Bài nộp của bạn"**, bấm xem lại được ảnh + ghi chú | |
| 12 | Manager → mở task → **Duyệt** | Thấy ảnh và ghi chú của Member | |
| 13 | Gõ nhận xét → **Từ chối** | Trạng thái "Từ chối" | |
| 14 | Member mở lại thẻ task | 🆕 Khối **"Vì sao bị từ chối" TỰ MỞ SẴN**, đúng nhận xét vừa gõ | |
| 15 | Member **Nộp lại** kèm ảnh mới | Nộp được | |
| 16 | Manager **Duyệt** → Đồng ý | Trạng thái "Hoàn thành" | |
| 17 | Member → Nhiệm vụ | Banner cam "Phần thưởng … chờ xác nhận" + nút Đã nhận / Chưa nhận | |

---

## KB-2 · Đặt thưởng SAU khi đã duyệt (bẫy mất thưởng)

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Tạo task mới, giao Member, **không đặt thưởng** | | |
| 2 | Member làm và nộp; Manager duyệt | Trạng thái "Hoàn thành" | |
| 3 | **Bây giờ mới** Đặt thưởng → Lưu | 🆕 Cảnh báo cam *"Có 1 bài nộp đã duyệt TRƯỚC khi đặt thưởng…"* | |
| 4 | Mở lại task, nhìn hàng phân công | 🆕 Dòng cam *"Chưa có ghi nhận thưởng — thành viên chưa nhận được gì"* + nút **Xử lý →** | |
| 5 | Bấm **Xử lý →** → nút tạo ghi nhận thưởng | Tạo xong, dòng cảnh báo biến mất | |
| 6 | Member → Nhiệm vụ | Banner thưởng xuất hiện | |

---

## KB-3 · Task quá hạn

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Tạo task, giao Member, hạn **cách hiện tại ~2 phút** | | |
| 2 | Để màn Nhiệm vụ **mở nguyên**, chờ qua mốc hạn | 🆕 Chip đỏ "Quá hạn" **tự hiện trong 1 phút**, không cần thoát ra vào lại | |
| 3 | Nhìn kỹ hai chip | 🆕 "Quá hạn" có **icon đồng hồ**, khác kiểu chip trạng thái | |
| 4 | Member mở task đó | 🆕 **Không còn nút Nộp**, thay bằng ô cam *"Đã quá hạn… nhắn người quản lý giao lại"* | |
| 5 | Manager mở task → hàng phân công | 🆕 Nút cam **"Giao lại + hạn mới"** | |
| 6 | Bấm nút đó | 🆕 Cảnh báo *"Hãy đặt hạn mới bên dưới…"* + 🆕 **có ô chọn hạn** | |
| 7 | Chọn người khác + hạn mới → Xác nhận | Chuyển sang người mới, không còn quá hạn | |

> ⛔ **Không gia hạn cho chính người đang giữ được.** BE chưa có endpoint sửa
> `dueAt`; `reassign` bắt buộc đổi sang người khác.

---

## KB-4 · Task định kỳ

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Tạo task định kỳ | | |
| 2 | Mở task | 🆕 **Chỉ còn MỘT nút** "Lịch lặp & tạo phân công" | |
| 3 | Mở sheet lịch lặp | 🆕 Có **thanh kéo + nút X** góc phải | |
| 4 | Hàng ngày → **Lưu lịch** | Báo "Đã lưu lịch lặp"; 🆕 đóng được bằng nút X | |
| 5 | "Tạo phân công hàng loạt": chọn người, khoảng ngày, bấm ô **Hạn (tuỳ chọn)** chọn 17:30 | 🆕 Ô hiện **"Hạn: 17:30"**, không còn bị cắt chữ | |
| 6 | Bấm **Tạo phân công** | Báo tạo thành công | |
| 7 | Xem "Phân công (n)" | ⛔ Các dòng **vẫn giống hệt nhau, không có ngày** | |

> ⛔ **Bước 7 là lỗi BE.** FE đã dựng sẵn chỗ hiện "bắt đầu → hạn" nhưng
> `GET .../assignments` không trả `startAt`/`dueAt`. Vì vậy cũng chưa khoá được
> "mỗi ngày chỉ làm task của ngày đó".

---

## KB-5 · Deputy

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Manager giao một task cho **Deputy** | | |
| 2 | Đăng nhập Deputy → Nhiệm vụ | Thấy màn quản lý, không phải màn member | |
| 3 | Deputy tạo task, giao cho **Member** | Giao được | |
| 4 | Member nộp → Deputy bấm **Duyệt** | Duyệt được (BE cho Manager **hoặc** Deputy) | |
| 5 | Deputy mở task **của chính mình**, nộp bài | Nộp được | |
| 6 | Nhìn dòng trạng thái task của mình | 🆕 **"Chờ người quản lý duyệt"** (không còn "Chờ Manager duyệt") | |
| 7 | Deputy bấm **Duyệt** trên bài của chính mình | Báo *"Bạn không thể tự duyệt công việc do mình thực hiện"* | |
| 8 | Deputy bấm **Xem bài nộp** khi đang chờ duyệt | 🆕 Xem lại được | |
| 9 | Deputy thử **Đặt thưởng** cho task giao cho chính mình | ⛔ **Vẫn làm được** | |

> ⛔ **Bước 9 là lỗ hổng đã biết.** Deputy tự đặt thưởng cho mình. Phải BE chặn
> — rào ở FE chỉ là rào giao diện, ai có APK vẫn gọi thẳng API.

---

## KB-6 · Nộp lại nhiều lần rồi duyệt

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| 1 | Member nộp → Manager từ chối → nộp lại → từ chối lần 2 → nộp lần 3 | Có 3 bài nộp trên cùng một phân công | |
| 2 | Manager bấm **Duyệt** | 🆕 Mở đúng **bài mới nhất đang chờ**, không còn lỗi *"Chỉ có thể duyệt minh chứng đang chờ xem xét"* | |
| 3 | Duyệt xong, bấm **Xem bài nộp** | 🆕 Chế độ chỉ xem, **không còn nút Duyệt/Từ chối** | |
| 4 | Nếu bài nộp trễ hạn | 🆕 Có dòng **"Nộp sau hạn"** màu cam | |

---

## KB-7 · Tài chính — tỷ trọng hũ & kết chuyển số dư

Kịch bản này trả lời hai câu hay bị hiểu nhầm nhất:
*"Sao chi thêm thì hạn mức cũng tăng?"* và *"64 triệu kết chuyển đi đâu?"*

### Điều kiện đầu vào

Trước khi test, gia đình phải có sẵn:

- **Một mô hình tài chính đang áp dụng** (Tôi → Mô hình tài chính), ví dụ
  80/20: hũ *Spending* 80%, hũ *Savings* 20%.
- **Mapping danh mục → hũ** (Tôi → Mô hình tài chính → Gán danh mục vào hũ).
  Chưa gán thì khoản chi rơi vào nhóm *"Chưa gán hũ"* và không tính vào hũ nào.
- **Ít nhất một khoản chi** trong kỳ đang xem.

### Phần A — Tỷ trọng chi tiêu theo hũ

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| A1 | Manager → **Sổ chi tiêu**, cuộn tới mục tỷ trọng | 🆕 Tiêu đề là **"Tỷ trọng chi tiêu theo hũ"** — KHÔNG còn chữ "Hạn mức theo tỷ lệ thu nhập" | |
| A2 | Đọc dòng chú thích xám ngay dưới tiêu đề | 🆕 Ghi rõ *"…tính trên TỔNG CHI trong kỳ (**64.520.122 đ**) — không phải hạn mức lấy từ thu nhập"*, con số trong ngoặc **khớp** với ô "Chi tiêu" ở biểu đồ phía trên | |
| A3 | Nhìn một hàng hũ, ví dụ *Spending · 80%* | 🆕 Bên phải có **hai dòng**: dòng to là **"91% thực tế"**, dòng nhỏ mờ bên dưới là `58.805.122 / 51.616.098` | |
| A4 | So `91%` với `80%` ghi cạnh tên hũ | Vượt → cả số phần trăm lẫn thanh tiến độ **màu đỏ** | |
| A5 | Cộng nhẩm: tất cả các hàng hũ + hàng *"Chưa gán hũ"* | Tổng **đúng bằng** con số tổng chi ở bước A2 | |

### Phần B — Chứng minh "số bên phải tăng theo" là **đúng**, không phải lỗi

Đây là chỗ em thắc mắc. Làm đúng 3 bước này để tự thấy:

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| B1 | **Ghi lại 3 con số** của hàng *Spending*: phần trăm thực tế, số bên trái, số bên phải | Ví dụ `91%`, `58.805.122`, `51.616.098` | |
| B2 | Sổ chi tiêu → **Ghi nhận Chi** → 10.000.000 đ vào một danh mục **thuộc hũ Spending** → Lưu | Giao dịch xuất hiện trong sổ | |
| B3 | Quay lại mục tỷ trọng, so với 3 con số vừa ghi | **Số bên trái tăng 10 triệu** (đúng). **Số bên phải cũng tăng 8 triệu** (= 80% của 10 triệu) — **đây là hành vi đúng**, vì mẫu số là tổng chi chứ không phải thu nhập | |
| B4 | Nhìn phần trăm thực tế | Đây mới là con số biết nói: nó cho biết trong tổng tiền đã tiêu, bao nhiêu phần rơi vào hũ này | |
| B5 | Ghi 5.000.000 đ vào danh mục thuộc hũ **Savings** rồi quay lại | Phần trăm của *Spending* **giảm**, của *Savings* **tăng** — dù *Spending* không tiêu thêm đồng nào | |

> **Giải thích:** công thức của Backend là
> `số bên phải = tổng chi trong kỳ × tỷ lệ hũ`.
> Nên đây **không phải hạn mức**, mà là *"nếu tiêu đúng mô hình thì hũ này lẽ ra
> chiếm bao nhiêu"*. Tiêu nhiều thì cả hai vế cùng lớn lên. **Chỉ có phần trăm
> mới nói được em có đi đúng mô hình hay không.**
>
> Muốn có **hạn mức thật** (một con số đứng yên, tiêu quá thì báo động) thì phải
> dùng **Kế hoạch ngân sách** — xem KB-8.

### Phần C — Kết chuyển số dư tháng trước

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| C1 | Manager → Sổ chi tiêu, tìm checklist đầu tháng | Có dòng **"Kết chuyển số dư 7/2026"** kèm phụ đề *"Còn … đ chưa có đích đến"* | |
| C2 | Cuộn xuống tìm thẻ cam **"Kết chuyển tháng 7/2026"** | Hiện 3 số: **tổng dư**, **đã phân bổ**, **còn lại chưa phân bổ** | |
| C3 | Kiểm tra: tổng dư − đã phân bổ | **Đúng bằng** số "chưa phân bổ" hiện to ở giữa thẻ | |
| C4 | Tôi → **Mục tiêu tiết kiệm**, xem có mục tiêu nào đang ở trạng thái **"Có nguy cơ không đạt"** không | Ghi lại tên mục tiêu đó | |
| C5 | Quay lại, bấm vào **dòng checklist "Kết chuyển số dư"** | 🆕 **Có phản hồi ngay** — mở danh sách chọn mục tiêu. Trước đây bấm không có gì xảy ra | |
| C6 | Nhìn danh sách mục tiêu vừa mở | 🆕 Mục tiêu **"Có nguy cơ không đạt"** ở bước C4 **CÓ trong danh sách**. Đây là bug vừa sửa — trước đây nó bị giấu | |
| C7 | Chọn mục tiêu đó → nhập ví dụ 10.000.000 đ → xác nhận | Báo thành công | |
| C8 | Quay lại Sổ chi tiêu | Số "chưa phân bổ" **giảm đúng 10 triệu**; ô "đã phân bổ" **tăng đúng 10 triệu** | |
| C9 | Tôi → Mục tiêu tiết kiệm → mở mục tiêu vừa chọn | Số đã góp **tăng đúng 10 triệu**, thanh tiến độ nhích lên | |

### Phần D — Trường hợp không còn mục tiêu nào

Chỉ test được nếu gia đình **không có mục tiêu nào đang mở** (tất cả đã hoàn
thành hoặc đã huỷ). Bỏ qua nếu không dựng được tình huống này.

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| D1 | Bấm dòng **"Kết chuyển số dư"** | 🆕 Hộp thoại **"Chưa có mục tiêu để nhận số dư"** + hai nút *Để sau* / *Tạo mục tiêu* | |
| D2 | Bấm **Tạo mục tiêu** | Chuyển sang màn Mục tiêu tiết kiệm | |

> **Giải thích số kết chuyển:** đó là tiền quỹ chung tháng trước tiêu không hết.
> Nó **không mất đi**, cũng **không tự cộng** vào tháng này — nằm nguyên trong
> quỹ chung cho tới khi em chuyển vào một mục tiêu tiết kiệm cụ thể.

---

## KB-8 · Cảnh báo tài chính

Kịch bản này trả lời câu: *"Em chi vượt hũ 80% rồi mà sao không có cảnh báo?"*

### Điều quan trọng phải hiểu trước

Cảnh báo **chỉ sinh ra từ 2 nguồn**:

1. **Kế hoạch ngân sách** (`budget-plans`) → cảnh báo `Vượt ngân sách`
2. **Mục tiêu tiết kiệm** → cảnh báo `Mục tiêu có nguy cơ không đạt`

**Mô hình hũ 80/20 KHÔNG phải nguồn cảnh báo.** Chi vượt tỷ trọng hũ bao nhiêu
cũng không sinh cảnh báo nào. Đây là thiết kế của Backend, không phải lỗi.

### Phần A — Xác nhận màn cảnh báo lúc chưa có gì

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| A1 | Manager → **Tôi** → **Cảnh báo tài chính** | Mở được màn hình | |
| A2 | Nếu danh sách trống | 🆕 Ngoài dòng "Không có cảnh báo nào", có thêm đoạn giải thích *"Cảnh báo chỉ sinh ra từ kế hoạch ngân sách và mục tiêu tiết kiệm. Chi vượt tỷ lệ hũ… không tạo cảnh báo"* | |
| A3 | Bấm **"Tính lại cảnh báo từ dữ liệu hiện tại"** | Báo "Đã tính lại cảnh báo". Nếu đang có mục tiêu chậm tiến độ thì cảnh báo *Mục tiêu có nguy cơ* xuất hiện | |

### Phần B — Dựng cảnh báo "Vượt ngân sách" từ đầu

Đây là phần chứng minh vì sao chi 50 triệu vào hũ Spending mà không có cảnh báo.

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| B1 | Tôi → **Kế hoạch ngân sách** → tạo kế hoạch mới. ⚠️ **Kỳ phải bao gồm ngày hôm nay** — đang là 19/8 thì chọn 1/8 → 31/8, KHÔNG chọn tháng 9 | Kế hoạch ở trạng thái *Nháp* | |
| B1b | Sau khi kích hoạt, nhìn thẻ kế hoạch trong danh sách | 🆕 Nếu lỡ chọn kỳ tương lai/quá khứ, có **dải cam** *"Kỳ của kế hoạch này chưa bắt đầu — các khoản chi hôm nay KHÔNG được tính vào đây"*. Không có dải cam = kỳ đúng | |
| B2 | Thêm **dòng ngân sách**: chọn danh mục (ví dụ *ăn uống*), đặt hạn mức ví dụ **5.000.000 đ** | Dòng hiện trong kế hoạch | |
| B3 | Bấm **Kích hoạt** kế hoạch | Trạng thái đổi sang *Đang áp dụng* | |
| B4 | Sổ chi tiêu → **Ghi nhận Chi** → **8.000.000 đ** vào đúng danh mục *ăn uống* | Giao dịch được lưu | |
| B5 | Tôi → Cảnh báo tài chính → **Tính lại cảnh báo** | Xuất hiện cảnh báo **"Chi tiêu vượt ngân sách"** | |
| B6 | Đọc mức độ nghiêm trọng trên thẻ cảnh báo | Có nhãn *Nhẹ / Trung bình / Nghiêm trọng* | |

> **Kết luận cho câu hỏi ban đầu:** chi 50 triệu vào hũ Spending **không** sinh
> cảnh báo vì lúc đó chưa có kế hoạch ngân sách nào. Muốn được nhắc khi vượt
> chi thì **bắt buộc** phải làm bước B1–B3.

### Phần C — Cảnh báo nổi lên đúng chỗ

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| C1 | Quay ra **Sổ chi tiêu** | 🆕 Thẻ **đỏ** ở gần đầu màn: *"N cảnh báo tài chính chưa xem"* kèm phụ đề *"Vượt ngân sách hoặc mục tiêu có nguy cơ không đạt"* | |
| C2 | Bấm vào thẻ đỏ đó | Đi thẳng tới màn Cảnh báo tài chính | |
| C3 | Bấm **"Đã xem"** trên một cảnh báo | Cảnh báo đổi trạng thái, số trên huy hiệu đỏ ở tiêu đề giảm | |
| C4 | Quay ra Sổ chi tiêu lần nữa | 🆕 Số trên thẻ đỏ **giảm tương ứng**. Xem hết mọi cảnh báo thì thẻ đỏ **biến mất** | |
| C5 | Bấm **"Đánh dấu đã xử lý"** trên một cảnh báo | Hỏi xác nhận trước, đồng ý thì cảnh báo chuyển sang đã xử lý | |

### Phần D — Vai Member

| # | Bước | Kết quả mong đợi | Thật thấy |
|---|---|---|---|
| D1 | Đăng nhập **Member**, mở khay thông báo, tìm thông báo về ngân sách | Có thông báo | |
| D2 | Bấm vào thông báo đó | 🆕 **Mở được màn Cảnh báo tài chính**. Trước đây bấm vào **không đi đâu cả** | |
| D3 | Nhìn kỹ màn hình ở vai Member | 🆕 **KHÔNG có** nút *"Tính lại cảnh báo từ dữ liệu hiện tại"* ở đầu màn | |
| D4 | Nhìn từng thẻ cảnh báo | 🆕 **KHÔNG có** nút *"Đã xem"* và *"Đánh dấu đã xử lý"* — Member chỉ đọc | |
| D5 | Bấm vào một thẻ cảnh báo | Vẫn mở được chi tiết để đọc | |

> Danh sách Member nhìn thấy có thể **ít hơn** của Manager: Backend chỉ trả
> *"cảnh báo có thể xem"* theo quyền. Danh sách rỗng ở vai Member **không phải
> lỗi**.

## Cách ghi lỗi

Ghi đủ 4 dòng thì mới sửa nhanh được:

    Kịch bản / bước :  KB-3 bước 4
    Vai             :  Member
    Mong đợi        :  không còn nút Nộp
    Thật thấy       :  vẫn có nút Nộp, bấm vào báo lỗi tiếng Anh
