# Báo cáo test runtime — Kế hoạch ngân sách · Mục tiêu tiết kiệm · Cảnh báo · Báo cáo tài chính

**Ngày:** 19/08/2026 (22:05 – 23:00) · **Máy thật:** Oppo CPH2159 (`cc28c069`), APK đang cài
trên máy · **Tài khoản:** Manager `ngophamnhutduy050302@gmail.com`, gia đình **NDuy**
(`b0cc7942-…`) · **Cách test:** điều khiển UI thật qua `adb` + đối chiếu số liệu chéo giữa các
màn, không gọi API trực tiếp (token phiên trước đã hết hạn).

Toàn bộ số liệu dưới đây là **thật, đọc từ máy**, không phải suy đoán từ code. Chỗ nào chưa
verify được thì ghi rõ ở mục cuối.

---

## 0. Dữ liệu đã tạo trong lúc test (để em biết mà dọn)

| Thứ | Tên | Trạng thái cuối |
|---|---|---|
| Kế hoạch ngân sách | **Ngan sach thang 8-2026** (thu 30tr / chi 20tr; 2 dòng: `an uong QN` 6tr–mốc 4,5tr · `hoc phi` 3tr–mốc 2,5tr) | **Đang áp dụng** |
| Kế hoạch ngân sách | kế hoạch tháng 8 (của em) | **Đã đóng** (phải đóng mới kích hoạt được kế hoạch mới cùng kỳ) |
| Danh mục chi | **an uong QN** (Thiết yếu) | Đang hoạt động — ⚠️ **chưa gán hũ** |
| Mục tiêu | **Quy du phong y te** 60tr, hạn 31/12/2026, đã góp 11tr | Có nguy cơ không đạt |
| Mục tiêu | **ZZ Test huy muc tieu** | Đã hủy (tạo ra chỉ để test nút Hủy) |
| Giao dịch | Chi 5.000.000 ₫ "Cho thang 8" vào `an uong QN` | Đã ghi |
| Giao dịch | Góp cá nhân 8tr + 3tr + 5tr vào quỹ chung | Đã ghi |
| Kế hoạch đóng góp T8 của mục tiêu mới | Duy 5tr · MInh nhut 1tr · lê anh sĩ 2tr · GiapHN 2,8tr | Duy đã nộp & tự duyệt |

---

## 1. Những gì CHẠY ĐÚNG (đã verify tận nơi)

**Kế hoạch ngân sách**
- Validate form tạo: bỏ trống → *"Nhập tên kế hoạch, danh mục Chi và số tiền kế hoạch lớn hơn 0."*;
  dòng đầu > chi dự kiến → *"Dòng ngân sách đầu tiên không được lớn hơn Chi tiêu dự kiến."*
- Tạo danh mục Chi mới ngay trong sheet (`an uong QN`) → tạo kế hoạch một mạch, không kẹt.
- Kích hoạt khi đã có kế hoạch ACTIVE cùng kỳ → snackbar đỏ đúng thông điệp BE:
  *"Đã tồn tại kế hoạch ngân sách đang hoạt động cho cùng kỳ"* (409 được dịch đúng).
- Thêm / sửa / xóa dòng ngân sách, sửa kế hoạch (DRAFT), Đóng, Hủy, Kích hoạt: đều chạy.
- Kỳ tự nắn về mốc tròn 1/8 → 31/8 ⇒ **không có dải cam cảnh báo kỳ** (đúng, fix `95277a3` OK).

**Mục tiêu tiết kiệm**
- Bộ chọn ngày đã ra **tiếng Việt** ("Thứ Năm, 31 tháng 12, 2026") — fix `156e7bc` OK.
- Góp tiền cá nhân → tiến độ + "Còn thiếu" + thanh tiến độ cập nhật ngay.
- Sửa khoản góp **tăng** quá số tiền giao dịch nguồn → thông báo dịch rất rõ:
  *"Khoản góp này gắn với giao dịch nguồn… hãy tạo khoản góp mới nếu muốn góp thêm."*
  Sửa **giảm** thì OK.
- BE tính `AT_RISK` đúng: mục tiêu 60tr / hạn 31/12 / khai góp 5tr một tháng → cần 12tr/tháng
  ⇒ gắn cờ nguy cơ ngay. Mục tiêu **không có hạn** thì để "Đang tiết kiệm" (không cảnh báo bừa).
- Kế hoạch đóng góp tháng: AI chia tiền theo khả năng từng người, xác nhận kế hoạch, nộp,
  ghi nhận — chạy hết. Thẻ đỏ *"Kế hoạch này chưa đủ đạt mục tiêu"* có lối thoát rõ ràng.

**Cảnh báo tài chính**
- "Tính lại cảnh báo" sinh cảnh báo mới đúng dữ liệu: sau khi chi 5tr vào `an uong QN`
  (mốc 4,5tr) → hiện **"Vượt ngân sách · Trung bình · …da vuot ngan sach 11%"** (5/4,5 = +11%).
- Cảnh báo cũ thuộc kế hoạch vừa **Đóng** tự biến mất sau khi tính lại — không rác.
- "Đã xem" → huy hiệu đỏ giảm 3→2→1→mất hẳn. "Đánh dấu đã xử lý" **có hỏi xác nhận** trước.
- Thẻ đỏ *"3 cảnh báo tài chính chưa xem"* trên Sổ thu chi hiện đúng, bấm vào đi đúng màn,
  xem hết thì **biến mất** (fix `8c2571e` OK).
- Chi tiết cảnh báo dịch tốt: Mốc cảnh báo / Giá trị thực tế / Kế hoạch ngân sách / Danh mục.

**Báo cáo tài chính**
- 4 tab đều tải được. **Số liệu khớp chéo:** tab Theo hũ (Spending 143.805.122 + Savings
  34.120.000 + Chưa gán 5.595.000) = **183.520.122 ₫** = đúng ô "Chi tiêu thực tế" ở tab Ngân sách.
- Xuất CSV: có toast *"Đã tạo CSV … và sao chép vào clipboard"*, clipboard có nội dung thật.
- Chọn kế hoạch trong dropdown: ACTIVE lên đầu, kế hoạch CANCELED bị loại — đúng.

---

## 2. Lỗi FE — nên sửa (xếp theo mức độ dễ bị hội đồng bắt)

> **Cập nhật 19/08/2026 khuya — đã sửa F1, F2, F3, F4, F5, F6, F7, F8, F11
> (phần format), F12, F13, F14, F15, F16.** `flutter analyze` 0 error/0
> warning (24 info nền cũ, không tăng), `flutter test` 601/601 pass. Còn
> **F9, F10** (validate + field còn thiếu ở sheet sửa) **chưa làm** — cần
> đổi cả payload gửi lên, rủi ro cao hơn nên để lại chờ xác nhận riêng. Chi
> tiết từng chỗ sửa xem ghi chú `// verify runtime 2026-08-19` ngay tại code.

### 🔴 F1. Báo cáo ghi ngược nghĩa: "Còn lại so với ngân sách"
`json_report_view.dart:82` map `varianceAmount` → **"Còn lại so với ngân sách"**, nhưng BE trả
`varianceAmount = đã chi − ngân sách`. Hệ quả trên máy:

| Dòng | Ngân sách | Đã chi | Màn hình ghi | Sự thật |
|---|---|---|---|---|
| `chi tieu` (kế hoạch tháng 8) | 10.000.000 | 143.305.122 | Còn lại **133.305.122 ₫** | Vượt 133 triệu |
| `hoc phi` | 3.000.000 | 500.000 | Còn lại **−2.500.000 ₫** | Còn dư 2,5 triệu |

Ngay dưới nó là dòng *"Đã vượt ngân sách: Có"* → một thẻ tự mâu thuẫn.
**Sửa:** đổi nhãn thành *"Chênh lệch so với ngân sách"* (hoặc đảo dấu khi hiển thị).

### 🔴 F2. "Đã vượt ngân sách: Có" khi chưa hề vượt ngân sách
Dòng `an uong QN`: Ngân sách 6.000.000 · Đã chi 5.000.000 · Mốc cảnh báo 4.500.000 →
**Đã vượt ngân sách: Có**. BE đang set `isOverBudget` theo **mốc cảnh báo**, không theo ngân sách.
**Sửa (FE):** đổi nhãn `isOverBudget` → *"Đã vượt mốc cảnh báo"*. (Cần BE xác nhận ngữ nghĩa —
xem B1.)

### 🟠 F3. Nhãn tiếng Anh lọt ra ở biểu đồ báo cáo
`finance_reports_screen.dart:759 _label()` thiếu key nên rơi vào fallback tách camelCase:
**"actual Amount"**, **"variance Amount"**, **"projected Amount By Deadline"**, **"actual Value"**.
Ngoài ra `JsonReportView` còn để lọt **"Budget Line"**, **"Budget Line Id"**, **"Related Jar"**,
**"Currency"**.
Ghi chú kỹ thuật: đang có **hai từ điển nhãn song song** (`_label()` trong màn báo cáo và
`JsonReportView._dict`) lệch nhau — nên gộp một chỗ.

### 🟠 F4. Chuỗi ISO thô hiện thẳng cho người dùng
`goal_contribution_screen.dart:416`:
> *"Cần góp / tháng để kịp **2026-12-31T00:00:00.000Z**"*

Cùng lỗi hình thái: mọi ngày trong `JsonReportView` bị `_looksLikeIsoDateTime` bắt trước nên
nhánh `_fmtDate` cho `deadline`/`periodStart`/`periodEnd` **không bao giờ chạy** →
"Từ ngày **07:00** 01/08/2026", "Hạn hoàn thành **07:00** 17/09/2029".

### 🟠 F5. Thẻ đỏ "chưa đủ đạt mục tiêu" không tính theo kế hoạch đã chốt
`_plannedMonthlyTotal` (`goal_contribution_screen.dart:361`) cộng **gợi ý AI**, không cộng kế
hoạch đã xác nhận. Sau khi chốt kế hoạch 10.800.000 ₫/tháng, tải lại màn vẫn ghi
*"Tổng đang định góp / tháng 5.000.001 ₫ · Tỷ lệ đạt được đúng hạn 46%"*, trong khi ngay bên
dưới 4 dòng kế hoạch cộng lại đúng 10.800.000 ₫ và thẻ "Thiếu hụt tháng này" ghi
*"Kế hoạch 10.800.000 ₫"*. **Ba con số, hai câu chuyện, cùng một màn.**
**Sửa:** có kế hoạch thì lấy tổng `plannedAmount` của `_plans`, không có mới lấy gợi ý AI.

### 🟠 F6. "Chỉnh sửa kế hoạch tháng này" xóa trắng kế hoạch đã chốt
`goal_contribution_screen.dart:1117` — controller đã nạp đúng số cũ (dòng 1097-1105) rồi bị
**ghi đè ngay bằng gợi ý AI** vì `useAiSuggestion` mặc định `true` khi có gợi ý. Mở sheet ra là
5.000.000 → 3.067.485; bấm Xác nhận là kế hoạch cũ mất, kể cả người đã nộp đủ 5 triệu giờ bị
hạ kế hoạch xuống dưới số đã nộp. Chuyển sang "Tự nhập" cũng **không** lấy lại được số cũ.
**Sửa:** `useAiSuggestion = existingByMember.isEmpty && suggestionByMember.isNotEmpty`.

### 🟠 F7. Sheet xác nhận kế hoạch không tính lại khi gõ tay
Nhập đúng 10.800.000 ₫ (đủ 100%) mà đầu sheet vẫn đứng nguyên
*"Mức này chỉ đạt **46%** mục tiêu đúng hạn"*, và không có dòng tổng đang gõ.
**Sửa:** tính tổng live + cập nhật % ngay khi gõ.

### 🟠 F8. 5 hành động phá hủy, 0 hộp xác nhận
| Hành động | Hậu quả | Có hỏi? |
|---|---|---|
| Xóa dòng ngân sách (icon 71px cạnh icon sửa) | mất dòng | ❌ |
| Xóa khoản góp mục tiêu | tiến độ tụt | ❌ |
| Hủy kế hoạch ngân sách | không quay lại được | ❌ |
| Đóng kế hoạch ngân sách | không kích hoạt lại được | ❌ |
| Hủy mục tiêu tiết kiệm (nút "Hủy" nằm sát "Góp tiền") | mục tiêu chết | ❌ |
| *Đánh dấu cảnh báo đã xử lý* | *đổi 1 trạng thái* | ✅ có hỏi |

Đúng chỗ ít nguy hiểm nhất thì hỏi, 5 chỗ nguy hiểm thật thì không.

### 🟡 F9. Validate ngân sách chỉ có ở lúc tạo, sau đó vô hiệu
- Sheet tạo chặn "dòng đầu > chi dự kiến", nhưng **Thêm dòng** và **Sửa dòng** thì không:
  chị đặt 1 dòng **50.000.000 ₫** trong kế hoạch có chi dự kiến 20.000.000 ₫ → lưu ngon lành.
- Sheet **Sửa kế hoạch** cho hạ chi dự kiến xuống **5.000.000 ₫** trong khi tổng dòng là
  9.000.000 ₫ → cũng lưu.
- Màn chi tiết **không hiện tổng các dòng**, cũng **không hiện kỳ (1/8 → 31/8)** — nên người
  dùng không có cách nào tự thấy mình vượt.

### 🟡 F10. Sửa kế hoạch / sửa mục tiêu thiếu hẳn field mà BE có
| Sheet | FE cho sửa | BE (`UpdateBudgetPlanDto` / `UpdateFinancialGoalDto`) nhận |
|---|---|---|
| Sửa kế hoạch ngân sách | tên, thu, chi | + **periodType, periodStart, periodEnd** |
| Sửa mục tiêu | tên, số tiền | + **deadline, monthlyContributionTarget, relatedJarId** |

⇒ Lỡ chọn sai kỳ (đúng cái bẫy đã ghi trong KB-8 B1) thì **không sửa được trong app**, phải
hủy rồi tạo lại. Mục tiêu cũng không giãn hạn được — trong khi thẻ đỏ của app lại khuyên
*"cân nhắc giãn hạn hoàn thành"*.

### 🟡 F11. Lịch sử đóng góp không có ngày, không có người góp
Mỗi dòng chỉ có số tiền **"6.000.000 ₫"**. Có 2 khoản góp thì không biết cái nào là cái nào mà
sửa/xóa. FE có nhánh hiện `createdAt` nhưng BE không trả (xem B4) — **và nếu BE trả thì FE đang
in thẳng chuỗi ISO** (`goal_detail_screen.dart:1090` in `a.createdAt!` không format).

### 🟡 F12. Trích số dư quỹ chung: giấu mất con số giải thích
Sheet hiện "Tổng số dư quỹ: **67.617.363 ₫**" và "Số dư khả dụng: **0 ₫**" rồi bảo không còn
tiền — nhìn như lỗi. `FundSurplus.allocatedSurplus` **đã parse sẵn** trong provider mà không
hiển thị. Thêm 1 dòng "Đã phân bổ" là hết thắc mắc.

### 🟡 F13. Chi tiết mục tiêu không hiện mức góp hàng tháng đã khai
Nhập "Góp hàng tháng dự kiến 5.000.000 ₫" lúc tạo, sau đó **không màn nào hiện lại**. Người
dùng chỉ thấy "Nên góp mỗi tháng 12.000.000 ₫" và trạng thái "Có nguy cơ" mà không hiểu vì sao.

### 🟡 F14. Vụn vặt nhưng thấy được
- Mức độ cảnh báo gọi **hai tên khác nhau**: thẻ ghi "Nghiêm trọng", chi tiết ghi "Cao" (cùng `HIGH`).
- Loại cảnh báo trong **báo cáo** để nguyên `OVER_BUDGET` / `SHORTAGE_RISK` — vì
  `json_report_view.dart:379` chỉ dịch giá trị cho key `alerttype`, còn báo cáo dùng key `type`.
  Thêm `'type'` vào danh sách là xong.
- Tiến độ mục tiêu trong báo cáo in **45.1190524%** (không làm tròn).
- Màn cảnh báo **không có cách xem lại cảnh báo đã xử lý** (API có `?status=RESOLVED`), cũng
  không có lọc theo loại/mức độ dù API hỗ trợ.
- Thẻ "Ngân sách tháng này" ở Sổ thu chi thực ra là **% thu nhập đã chi** (188.520.122 /
  256.137.485 = 74%), không liên quan kế hoạch ngân sách đang áp dụng.
- Nút "Ngân sách" ở Trang chủ mở **Mô hình tài chính**, không mở kế hoạch ngân sách.

### 🔴 F15. Tạo danh mục nhanh → mọi khoản chi rơi vào "Chưa gán hũ"
Sheet ghi nhận chi trấn an: *"Hũ sẽ được Backend tự gán theo danh mục và mô hình tài chính đang
áp dụng."* Nhưng danh mục `an uong QN` vừa tạo trong sheet kế hoạch **chưa được gán hũ**, nên
khoản chi 5.000.000 ₫ chạy thẳng vào **"Chưa gán hũ"** (5.595.000 → **10.595.000 ₫**, đúng
+5 triệu) và **không được tính vào Spending/Savings**.
**Sửa:** sau khi tạo danh mục mới thì nhắc gán hũ, hoặc cảnh báo "danh mục chưa gán hũ" ngay ở
form ghi chi.

### 🟠 F16. Kỳ chưa có dữ liệu thì mất luôn cả % mục tiêu của mô hình
*(Phát hiện 19/08 tối, sau khi so sánh với báo cáo — không phải lỗi chị gây ra hôm nay.)*

`wallet_screen.dart:454-462` (`_jarBreakdown`): khi `GET /finance/reports/jar-target-actual`
trả `items: []` cho kỳ hiện tại (gia đình chưa có giao dịch khớp kỳ đó), toàn bộ khối "Tỷ trọng
chi tiêu theo hũ" **biến mất hoàn toàn**, chỉ còn một dòng xám *"Chưa có dữ liệu target/actual
theo hũ cho kỳ này."* — không còn thấy mô hình đang áp dụng là gì (5 lọ hay 80/20), tỷ lệ bao
nhiêu %.

Trước `2026-07-28` phần này **tự tính ở FE** từ % của `FinanceModel` đang ACTIVE (file
`jar_allocation.dart`) nên luôn hiện, có giao dịch hay không cũng thấy được đang áp dụng mô hình
gì. Commit `1c452e1 chore(finance): xoa jar_allocation da thanh code chet` xóa hẳn cách tính cũ,
chuyển hẳn sang chờ BE trả report — đây là đánh đổi có chủ đích (đã ghi trong `API_DOCS.md:472`)
nhưng bỏ sót phần fallback: không có dữ liệu thực tế thì vẫn nên hiện **% mục tiêu tĩnh** của
model (đã có sẵn trong `FinanceProvider`, không cần gọi thêm API), kèm dòng phụ "chưa có giao
dịch để so thực tế" thay vì bỏ trắng hẳn.
**Sửa:** khi `report == null || report.items.isEmpty`, vẫn build rows từ
`model.allocations` (tên khoản + % mục tiêu), chỉ để trống phần "% thực tế".

---

## 3. 📋 Cần báo BE

**B1. `isOverBudget` so với mốc cảnh báo hay so với ngân sách?**
Dòng `an uong QN`: `plannedAmount` 6.000.000, `actualAmount` 5.000.000, `thresholdLimit`
4.500.000 → BE trả `isOverBudget = true`. Nếu đây là **cố ý** thì FE đổi nhãn thành "Đã vượt
mốc cảnh báo"; nếu là **nhầm** thì BE sửa. Xin một câu trả lời dứt khoát.

**B2. `varianceAmount` là chênh lệch có dấu — xin xác nhận công thức**
Quan sát: `varianceAmount = actualAmount − plannedAmount` (âm khi còn dư). FE sẽ đổi nhãn theo
đúng nghĩa này. Nếu BE định nghĩa khác thì báo lại.

**B3. Câu chữ cảnh báo đang thiếu dấu và lặp từ**
Nội dung BE trả: `"Chi tieu chi tieu da vuot ngan sach 1492% trong ky nay."` →
(1) không dấu tiếng Việt, (2) **lặp "Chi tieu chi tieu"** (template ghép "Chi tiêu" + tên danh
mục "chi tieu"). Nội dung push khác của BE thì lại có dấu đầy đủ ("Mục tiêu … có nguy cơ không
đạt đúng hạn") ⇒ chỉ cần sửa template của `OVER_BUDGET`.

**B4. `GET /financial-goals/{goalId}/allocations` thiếu `createdAt` và người góp**
Danh sách trả về không có thời điểm góp lẫn thành viên góp → lịch sử đóng góp chỉ là một cột
số tiền. Xin bổ sung `createdAt`, `createdByMemberId`/`memberName`, và `note` nếu có.

**B5. Nội dung push chưa format tiền**
> *"Quỹ mục tiêu còn thiếu đóng góp — Quy du phong y te tháng 8/2026 còn thiếu **5800000**."*

Xin format `5.800.000 ₫`.

**B6. Tự duyệt khoản đóng góp của chính mình**
Manager bấm "Tôi đã đóng góp" → FE gọi `submit` rồi gọi luôn `approve` (vì có
`canManageFinance`) → BE **cho qua**, trạng thái nhảy thẳng "Đã hoàn thành", tiền vào sổ ngay.
Trong khi ở luồng Nhiệm vụ, BE **đã chặn** Deputy tự duyệt việc của mình (verify 19/08).
Đề nghị BE chốt: có chặn `approve` khi người duyệt trùng người nộp (ít nhất với `DEPUTY_MEMBER`)
hay không? Chưa test được vai Deputy nên chưa biết BE đang xử lý thế nào với vai đó.

**B7. `availableSurplus` của tháng hiện tại luôn = 0?**
Tháng 8: `totalSurplus` 67.617.363 ₫ nhưng `availableSurplus` 0 ₫ (tháng 7: 77.981.111 / 0;
tháng 6: 0 / 0). Xin cho biết công thức — có phải chỉ tính phần dư của **kỳ đã đóng** không?
FE cần biết để viết câu giải thích đúng thay vì để người dùng nghĩ app hỏng.

**B8. Kỳ báo cáo đang là `[01/08 00:00Z … 31/08 00:00Z]`**
FE gửi `periodStart=2026-08-01`, `periodEnd=2026-08-31` (chuỗi ngày). Báo cáo trả về hiển thị
"07:00 01/08" → "07:00 31/08" (giờ VN) ⇒ **cửa sổ kết thúc lúc 7 giờ sáng 31/8**. Nếu BE không
tự nới `periodEnd` đến hết ngày thì mọi giao dịch cuối tháng bị rơi khỏi báo cáo. Xin xác nhận;
nếu BE để nguyên thì FE sẽ gửi `periodEnd` là ngày đầu tháng sau.
*(Chưa dựng được giao dịch ngày 31/8 để đo trực tiếp — đây là suy luận từ dữ liệu BE trả về.)*

**B9. Báo cáo trả `type: "SHORTAGE_RISK"`** — enum này không có trong danh sách `alertType` của
`GET /finance/alerts` (`OVER_BUDGET | GOAL_AT_RISK | NON_ESSENTIAL_TOO_HIGH`). Xin bổ sung vào
tài liệu để FE dịch cho đủ.

---

## 4. Chưa test được (nói thẳng, không tính là "đã xong")

1. **Duyệt / Từ chối khoản đóng góp của người khác** — cần một tài khoản Member nộp trước;
   phiên này chỉ có tài khoản Manager.
2. **Vai Deputy và Member** trên cả 4 màn (KB-8 phần D: Member không được thấy nút "Tính lại"
   và "Đã xem") — chưa đăng nhập được vai khác.
3. **Trích số dư quỹ chung thành công** — cả 3 tháng đều `availableSurplus = 0`, chỉ test được
   trạng thái rỗng.
4. **Ranh giới ngày 31/8** của kỳ báo cáo (B8).
5. **Báo cáo của kỳ quá khứ / kế hoạch đã đóng** — mới xem tháng 8.

---

## 5. Đề xuất thứ tự sửa

| Ưu tiên | Việc | Lý do |
|---|---|---|
| 1 | F1 + F2 (nhãn variance & isOverBudget) | Báo cáo đang nói **ngược sự thật về tiền**, hội đồng nhìn thẻ là thấy |
| 2 | F5 + F6 (kế hoạch đóng góp) | F6 làm **mất dữ liệu** của người dùng |
| 3 | F8 (hộp xác nhận cho 5 hành động phá hủy) | Rẻ, chặn mất dữ liệu |
| 4 | F3 + F4 + F14 (nhãn Anh/ISO/enum thô) | Rẻ, sạch màn hình demo |
| 5 | F15 (danh mục chưa gán hũ) | Sai lệch số liệu mô hình tài chính |
| 6 | F9 + F10 (validate & field còn thiếu) | Sửa được kỳ sai ngay trong app |
| 7 | F11 – F13 (thiếu thông tin hiển thị) | Bổ sung, không chặn |

> Theo quy ước repo (CLAUDE.md rule 3), **chưa sửa gì cả** — chờ em chọn nhóm nào làm trước.
