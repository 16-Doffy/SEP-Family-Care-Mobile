# Kịch bản bảo vệ — Nghiệp vụ 4 màn Tài chính + Luồng mời tham gia gia đình

**Mục đích:** trả lời câu hỏi hội đồng dạng *"vì sao làm vậy"*, *"logic nghiệp vụ ở đâu"*,
*"FE tính hay BE tính"* — không phải hướng dẫn dùng app. Mọi con số, tên field, tên hàm dưới
đây lấy trực tiếp từ code đang chạy (`lib/`) và `API_DOCS.md`, không suy đoán. Chỗ nào là
**quy ước riêng của FE** (không phải BE ép) sẽ ghi rõ "FE tự quyết" để không bị hỏi vặn là
"BE bắt vậy à?".

---

## 0. Sơ đồ quan hệ 4 màn — câu hỏi mở đầu thường gặp nhất

> *"4 màn này liên quan nhau thế nào, hay độc lập?"*

```
Mô hình tài chính (80/20, 5 lọ...)     Kế hoạch ngân sách        Mục tiêu tiết kiệm
     │ chỉ để CHIA HŨ                     │ đặt hạn mức chi          │ đặt số tiền cần đạt
     │ KHÔNG sinh cảnh báo                │ có ngưỡng cảnh báo       │ có deadline
     ▼                                    ▼                          ▼
Báo cáo "Theo hũ"                    ──────────► CẢNH BÁO TÀI CHÍNH ◄──────────
(so % mục tiêu vs % thực chi)         (nguồn 1: OVER_BUDGET)   (nguồn 2: GOAL_AT_RISK)
```

**Chốt nghiệp vụ quan trọng nhất của cả hệ thống tài chính** (đã verify runtime 2026-08-19,
đối chiếu ngược lại với `finance-alerts.service` qua hành vi thật): **Cảnh báo tài chính chỉ
sinh ra từ đúng 2 nguồn — Kế hoạch ngân sách vượt ngưỡng, và Mục tiêu tiết kiệm có nguy cơ
trễ hạn.** Mô hình hũ (80/20, 5 lọ...) chỉ dùng để **chia tiền theo tỷ lệ và vẽ báo cáo**, chi
vượt tỷ lệ hũ bao nhiêu cũng **không** tạo cảnh báo. Đây là quyết định thiết kế của BE, không
phải FE tự giới hạn — FE có ghi rõ dòng cảnh báo cam trong màn Sổ thu chi để người dùng không
hiểu nhầm "sao chi vượt hũ mà không thấy báo".

*Nếu hội đồng hỏi "tại sao không cảnh báo luôn khi vượt hũ?"* → trả lời: đây là quyết định
nghiệp vụ của BE — hũ là công cụ *phân bổ tham khảo*, còn Kế hoạch ngân sách mới là cam kết
*có ngưỡng cứng* do người dùng tự đặt cho từng danh mục. Tách 2 khái niệm này giúp người dùng
không bị dội cảnh báo liên tục chỉ vì lệch tỷ lệ vài phần trăm.

---

## 1. Kế hoạch ngân sách (Budget Plan)

### 1.1 Mục đích nghiệp vụ
Đặt hạn mức chi cho từng danh mục trong một kỳ (tháng/quý/năm), làm cơ sở để hệ thống tự
cảnh báo khi chi vượt.

### 1.2 Vòng đời trạng thái — `status`
```
DRAFT ──(activate)──► ACTIVE ──(close)──► CLOSED
  │                      │
  └──────(cancel)────────┴──────(cancel)──► CANCELED
```
- **DRAFT**: đang soạn, sửa/thêm/xóa dòng ngân sách thoải mái.
- **ACTIVE**: đang áp dụng, BE tính cảnh báo dựa trên các dòng của kế hoạch này.
- **CLOSED**: đã đóng — **không kích hoạt lại được**, phải tạo kế hoạch mới nếu cần dùng lại.
  Đây là quyết định UX của FE: đã thêm hộp xác nhận "Không kích hoạt lại được" trước khi đóng
  (2026-08-19) vì trước đó bấm là đóng ngay, không cảnh báo tính không-thể-đảo-ngược.
- **CANCELED**: hủy — dùng cho kế hoạch tạo nhầm, không tính vào lịch sử báo cáo.

### 1.3 Quy tắc nghiệp vụ cốt lõi
1. **Một kỳ chỉ được có tối đa 1 kế hoạch ACTIVE.** BE trả `409 "Đã tồn tại kế hoạch ngân
   sách đang hoạt động cho cùng kỳ"` khi kích hoạt kế hoạch thứ 2 trùng kỳ. FE không tự chặn
   trước — để BE là nguồn sự thật, tránh FE và BE lệch logic xác định "trùng kỳ" (chồng lấn
   ngày hay trùng khớp tuyệt đối `periodStart`/`periodEnd`?).
2. **Kỳ được nắn về mốc tròn lịch**, không phải "hôm nay → hôm nay + N". Ví dụ tạo kế hoạch
   ngày 15/8 chọn "Hàng tháng" → kỳ ra `01/08 → 31/08`, không phải `15/08 → 15/09`. Đây là
   FE tự quyết (hàm `_planPeriodRange`) để khớp với cách mọi báo cáo khác đều tính theo
   tháng dương lịch — nếu để trôi ngày sẽ không so sánh được giữa các kỳ.
3. **Bắt buộc có ≥1 dòng ngân sách mới kích hoạt được.** BE yêu cầu điều này (kế hoạch không
   có dòng thì không có gì để tính cảnh báo).
4. **Ngưỡng cảnh báo (`thresholdAmount`) khác hạn mức (`plannedAmount`).** Ngưỡng là mốc báo
   sớm — ví dụ hạn mức 5.000.000đ, đặt ngưỡng 4.000.000đ để được nhắc trước khi chạm đáy.
   *[Điểm hội đồng dễ hỏi vặn]*: field `isOverBudget` mà BE trả về **hiện đang so với ngưỡng
   cảnh báo, không so với hạn mức** (verify runtime: chi 5tr trong hạn mức 6tr, ngưỡng 4,5tr
   → `isOverBudget = true`). FE đã đổi nhãn hiển thị thành "Đã vượt mốc cảnh báo" cho đúng ý
   nghĩa thật, và đã gửi câu hỏi xác nhận ngữ nghĩa cho BE (chưa có câu trả lời cuối).
5. **`CreateBudgetLineDto.thresholdAmount` không nullable** — nếu người dùng không đặt ngưỡng
   thì FE phải **bỏ hẳn key** ra khỏi payload, gửi `null` tường minh là sai contract, BE sẽ từ
   chối. Đây là chi tiết kỹ thuật hay bị hỏi "sao không gửi null cho gọn?".
6. **Dải cảnh báo cam "kỳ chưa bắt đầu/đã qua"** trên card kế hoạch ACTIVE — thuần UX của FE
   (không phải field BE trả), tính bằng cách so `DateTime.now()` với `periodStart`/`periodEnd`
   của chính kế hoạch. Lý do có tính năng này: từng có ca thật user tạo kế hoạch kỳ tháng 9
   rồi chi tháng 8, chờ mãi không thấy cảnh báo vì kỳ chưa tới.

### 1.4 Cách FE triển khai
- **Model**: `BudgetPlan`, `BudgetLine` trong `lib/providers/finance_provider.dart`.
- **API** (đều xác nhận từ `API_DOCS.md` + verify runtime):
  `GET/POST /finance/budget-plans`, `GET/PATCH .../budget-plans/{id}`,
  `PATCH .../activate|close|cancel`, `POST .../lines`, `PATCH/DELETE /finance/budget-lines/{id}`.
- **Validate ở FE trước khi gửi** (`budget_plan_screen.dart`): tên không rỗng, dòng đầu > 0,
  dòng đầu ≤ chi tiêu dự kiến, ngưỡng > 0 nếu có nhập. *Đây là validate tiện ích, không thay
  thế validate của BE* — nếu bỏ qua FE thì BE vẫn từ chối payload sai.
- **Xử lý 409 trùng danh mục khi tạo nhanh**: sheet tạo kế hoạch cho tạo danh mục Chi mới
  ngay tại chỗ; nếu tên trùng danh mục đã có (BE trả 409), FE tự `fetchAll()` rồi tra lại theo
  tên thay vì báo lỗi treo — người dùng không cần hiểu khái niệm "danh mục trùng", họ chỉ
  muốn dùng cái tên đó.

### 1.5 Câu hỏi hội đồng dự kiến
- *"Sao không cho sửa lại kỳ (periodStart/periodEnd) khi đã tạo?"* → Hiện sheet Sửa kế hoạch
  chỉ cho sửa tên/thu/chi dự kiến, chưa cho sửa kỳ dù `UpdateBudgetPlanDto` của BE **có** nhận
  `periodType/periodStart/periodEnd`. Đây là **thiếu sót đã ghi nhận** (chưa kịp làm), không
  phải giới hạn của BE — trả lời thẳng, đừng né.
- *"Xóa dòng ngân sách có ảnh hưởng gì tới cảnh báo đã sinh ra chưa?"* → Không tự động dọn —
  cảnh báo cũ vẫn còn tới khi người dùng bấm "Tính lại cảnh báo" (xem mục 3).

---

## 2. Mục tiêu tiết kiệm (Financial Goal)

### 2.1 Mục đích nghiệp vụ
Đặt một khoản tiền cần đạt (mua xe, quỹ khám sức khỏe...) có hạn chót tùy chọn, theo dõi tiến
độ, và **chia việc góp tiền cho từng thành viên theo tháng**.

### 2.2 Trạng thái — `status`
`ACTIVE | ACHIEVED | CANCELED | AT_RISK`

**Điểm nghiệp vụ hay bị hỏi nhất của màn này**: `AT_RISK` **không phải trạng thái đóng**, nó
là *cảnh báo tiến độ* chồng lên trạng thái ACTIVE — mục tiêu AT_RISK vẫn nhận góp tiền, vẫn
tính vào danh sách "cần chuyển số dư quỹ vào" bình thường. Có một bug thật đã sửa
(`c2d94c1`) vì trước đó FE lọc `status == 'ACTIVE'` khi liệt kê mục tiêu nhận số dư kết
chuyển — vô tình loại đúng cái mục tiêu đang cần tiền nhất (AT_RISK). *Nếu hội đồng hỏi "sao
biết được đây là bug chứ không phải cố ý?"* → vì bản chất AT_RISK vẫn là ACTIVE về mặt cho
phép hành động, chỉ khác ở cờ cảnh báo hiển thị.

### 2.3 Ba cách tiền vào một mục tiêu — đây là nơi hội đồng dễ hỏi nhất
| Cách | Endpoint | Ý nghĩa nghiệp vụ | Tiền từ đâu |
|---|---|---|---|
| Góp cá nhân | `POST .../allocations {amount, note?}` | Thành viên bỏ tiền túi nạp thêm | **Tiền MỚI** — tăng cả Tổng quỹ gia đình lẫn tiến độ mục tiêu |
| Trích số dư quỹ chung | `POST .../surplus-allocations {periodMonth, periodYear, amount, note?}` | Dùng phần dư (thu − chi) của một tháng đã qua chưa dùng hết | **Tiền CÓ SẴN** — không tạo tiền mới, chỉ chuyển nhãn |
| Kế hoạch đóng góp theo tháng | xem mục 2.4 | Cam kết trước, theo dõi ai đã góp ai chưa | Cuối cùng vẫn đi qua "Góp cá nhân" ở bước submit |

`GET .../surplus-availability?month&year` trả `{totalSurplus, allocatedSurplus,
availableSurplus}` — **BE tính sẵn cả 3 số**, FE không tự trừ. Quan sát runtime: tháng đang
diễn ra (chưa kết thúc) luôn có `availableSurplus = 0` dù `totalSurplus` khác 0 — nghi ngờ BE
chỉ cho trích số dư của **kỳ đã đóng sổ**, nhưng FE **chưa nhận được xác nhận chính thức** từ
BE, đang để nguyên câu hỏi mở (đừng khẳng định chắc nịch nếu hội đồng hỏi sâu công thức, nói
rõ đây là quan sát chưa verify).

### 2.4 Kế hoạch đóng góp theo tháng (Goal Contribution Plan) — luồng 3 bước
```
Manager/Deputy "Xác nhận kế hoạch"  →  Member "Tôi đã đóng góp"  →  Manager/Deputy Duyệt/Từ chối
   POST .../contribution-plans/confirm     POST .../{planId}/submit      POST .../{planId}/approve|reject
   {periodMonth, periodYear, dueDate,      {amount, note?}
    members: [{memberId, plannedAmount}]}
```
- **Số tiền mỗi người**: BE có sẵn API gợi ý `GET .../contribution-suggestions?month&year` —
  chia theo *"khả năng còn lại"* của từng người (thu nhập − chi tiêu cá nhân − đã góp quỹ
  chung), kèm `recommendedMonthlyContribution` (mức BE khuyên góp/tháng để kịp hạn) và
  `remainingAmount`. Người xác nhận **được sửa tay** từng số trước khi chốt — AI chỉ là gợi ý
  khởi điểm, không bắt buộc theo.
- **Auto-approve khi tự góp**: nếu người bấm "Tôi đã đóng góp" có quyền `canManageFinance`
  (Manager/Deputy), FE gọi `submit` xong gọi luôn `approve` — không bắt họ tự duyệt đơn nộp
  của chính mình theo 2 bước riêng.
  ⚠️ **Đây là điểm hội đồng RẤT dễ xoáy vào — trả lời thẳng, đừng giấu**: khác với luồng Nhiệm
  vụ (nơi BE đã verify chặn Deputy tự duyệt việc của chính mình, trả 403), ở luồng này **BE
  hiện KHÔNG chặn** Manager/Deputy tự duyệt khoản góp của chính họ — verify runtime 2026-08-19,
  Manager tự nộp rồi tự duyệt, trạng thái nhảy thẳng "Đã hoàn thành", tiền vào sổ ngay không ai
  kiểm lại. Đây là **lỗ hổng nghiệp vụ đã ghi nhận và gửi câu hỏi cho BE xác nhận có nên chặn
  hay không** — chưa có câu trả lời cuối cùng tại thời điểm bảo vệ.
- **Thiếu hụt (Shortage) khác Thiếu hụt cảnh báo (Shortfall)**: `GET .../contribution-shortage`
  là số **BE tính** cho tháng đó (kế hoạch − đã đóng thật). Thẻ đỏ "chưa đủ đạt mục tiêu" ở
  đầu màn là **FE tự tính** (so tổng kế hoạch với `recommendedMonthlyContribution` của BE) —
  hai con số nhìn giống nhau nhưng nguồn khác nhau, dễ bị hỏi "sao 2 chỗ không khớp số" nếu
  cách làm tròn khác nhau.

### 2.5 Ràng buộc toàn vẹn dữ liệu — Goal Allocation
Mỗi khoản góp (`allocations`) có thể **gắn với một giao dịch sổ chi tiêu nguồn**
(`ledgerEntryId`). Sửa/xóa allocation **không được vượt quá số tiền còn lại của giao dịch nguồn
đó** — BE chặn bằng lỗi rõ ràng ("vượt quá số tiền còn có thể phân bổ"), FE dịch lại thành câu
dễ hiểu: *"Khoản góp này gắn với giao dịch nguồn... hãy tạo khoản góp mới nếu muốn góp thêm."*
Lý do ràng buộc: tránh một giao dịch chi tiêu 1 lần bị "phân bổ ảo" vượt quá số tiền thật đã
chi, giữ tổng sổ sách khớp.

### 2.6 Câu hỏi hội đồng dự kiến
- *"Xóa mục tiêu thì tiền đã góp đi đâu?"* → App chưa hoàn tiền tự động khi hủy mục tiêu —
  Cancel chỉ đổi `status`, số tiền đã ghi vào `allocations`/sổ chi tiêu **không bị rút lại**.
  Đây là hành vi hiện tại, chưa xác nhận có đúng ý BE hay cần thêm luồng hoàn tiền.
- *"Vì sao AT_RISK lại tính ra được — công thức nào?"* → BE tính hoàn toàn (so
  `targetAmount`, `deadline`, tốc độ góp hiện tại), FE chỉ đọc `status` trả về, không tự suy
  luận AT_RISK từ phía client.

---

## 3. Cảnh báo tài chính (Finance Alerts)

### 3.1 Hai nguồn sinh cảnh báo — nhắc lại từ mục 0
`alertType`: `OVER_BUDGET` (từ Kế hoạch ngân sách) | `GOAL_AT_RISK` (từ Mục tiêu tiết kiệm) |
`NON_ESSENTIAL_TOO_HIGH` (chi không thiết yếu cao — ít gặp trong test thật).

### 3.2 Vòng đời cảnh báo
```
NEW ──(Đã xem)──► ACKNOWLEDGED ──(Đánh dấu đã xử lý)──► RESOLVED
```
- Không tự phát sinh nền theo thời gian thực — phải gọi
  `POST /finance/alerts/recompute {budgetPlanId?, goalId?, periodStart?, periodEnd?, scope?}`
  (`scope`: `ALL|BUDGET|GOAL|NON_ESSENTIAL`) để BE tính lại từ dữ liệu hiện có. Nút "Tính lại
  cảnh báo" ở đầu màn chính là gọi hàm này với `scope=ALL`.
  *[Câu hỏi hay gặp]* "Vậy user phải tự nhớ bấm à?" → Đúng, hiện tại **không có job nền tự
  động recompute phía FE biết tới** — recompute là hành động thủ công. Đây là giới hạn thật
  của thiết kế hiện tại, không né tránh khi bị hỏi.
- **"Đánh dấu đã xử lý" không đổi số liệu gốc** — chỉ đổi `status` sang RESOLVED, không sửa
  khoản thu/chi hay mục tiêu liên quan. Nếu số liệu vẫn còn vượt ngưỡng, recompute lần sau
  cảnh báo **có thể xuất hiện lại**. FE có dòng cảnh báo này ngay trong hộp xác nhận trước khi
  bấm, để người dùng không hiểu nhầm "xử lý" = "đã sửa xong vấn đề".

### 3.3 Phân quyền — capability, không phải role cứng
`canManageFinance` (Manager + Deputy) mới thấy nút "Tính lại", "Đã xem", "Đánh dấu đã xử lý".
Member chỉ đọc — bấm vào vẫn xem được **chi tiết** cảnh báo, chỉ không có 3 nút hành động. BE
trả `403` nếu Member cố gọi thẳng API (verify contract), FE **ẩn nút thay vì để bấm ăn lỗi** —
đúng nguyên tắc phân quyền của cả app: *router chỉ chặn đường dẫn, còn từng nút bấm tự gate
theo capability của chính màn đó* (ghi rõ trong `CLAUDE.md` của repo, không phải chị tự đặt).

### 3.4 Liên kết với thông báo đẩy
`BudgetAlert.id` trong bảng route thông báo của app map thẳng tới `/manager/finance-alerts`
— bấm push notification về ngân sách đi thẳng vào đúng cảnh báo, không phải màn chung chung.

### 3.5 Câu hỏi hội đồng dự kiến
- *"Cảnh báo Mục tiêu tiết kiệm và cảnh báo trong sheet Kế hoạch đóng góp theo tháng có phải
  một không?"* → **Không.** `GOAL_AT_RISK` (mục 3.1) là `FinanceAlert` chính thức, có
  `status`, hiện ở màn Cảnh báo tài chính, tính bằng recompute. Thẻ đỏ trong sheet đóng góp
  (mục 2.4) là cảnh báo cục bộ FE tự vẽ tại chỗ, không lưu trạng thái, không phải bản ghi BE.

---

## 4. Báo cáo tài chính (Finance Reports)

### 4.1 Bốn tab, bốn nguồn dữ liệu độc lập
| Tab | Endpoint | Đơn vị thời gian |
|---|---|---|
| Ngân sách | `GET /finance/budget-plans/{id}/report` | Tự mang kỳ riêng của plan đã chọn |
| Theo hũ | `GET /finance/reports/jar-target-actual?periodStart&periodEnd&financeModelId` | Theo tháng đang chọn ở đầu màn |
| Chi không thiết yếu | `GET /finance/reports/non-essential-spending` | Theo tháng đang chọn |
| Ngân sách & Mục tiêu | `GET /finance/reports/budget-goal` | Theo tháng đang chọn |

Tab 1 (Ngân sách) **không** dùng bộ chọn tháng chung ở đầu màn — nó chọn **kế hoạch cụ thể**
từ dropdown, vì kế hoạch tự mang kỳ riêng (có thể là quý/năm, không nhất thiết theo tháng).
3 tab còn lại dùng chung model `FinancePeriod` (đơn vị tháng dương lịch, có nút tháng
trước/sau) — đây là quyết định kiến trúc của FE để tránh mỗi màn tự gọi `DateTime.now()` rồi
lệch nhau qua mốc đổi tháng.

### 4.2 Công thức "Theo hũ" — điểm hay bị hỏi nhất của cả 4 màn
> **`targetAmount = trackedAmount × targetPercentage / 100`**
> `trackedAmount` = **TỔNG CHI đã theo dõi trong kỳ**, KHÔNG PHẢI thu nhập.

Đây từng là một bug thật đã sửa (`82e5a78`): nhãn cũ ghi "Hạn mức theo tỷ lệ thu nhập" nhưng
công thức BE dùng mẫu số là tổng chi, không phải thu nhập — nghĩa là **chi càng nhiều thì cả
số mục tiêu lẫn số thực tế cùng tăng**, con số tiền không nói lên gì, chỉ có **tỷ lệ phần
trăm** là đáng nhìn. FE đã đổi nhãn thành "Tỷ trọng chi tiêu theo hũ" và ghi rõ giải thích
ngay trong card. *Nếu hội đồng hỏi "sao không so với thu nhập cho dễ hiểu?"* → vì mô hình
80/20 (hay 5 lọ) vốn định nghĩa tỷ lệ trên phần **đã tiêu**, không phải phần **kiếm được** —
đúng bản chất "theo dõi mình đang tiêu lệch mô hình bao nhiêu", không phải "mình được phép
tiêu bao nhiêu" (đó là việc của Kế hoạch ngân sách).

`status` của mỗi hũ: `ON_TRACK | OVER_TARGET | UNDER_TARGET` — **BE tính và trả thẳng**, FE
chỉ dịch nhãn, không tự so target/actual để suy ra trạng thái.

Trường `isSavingLike` (hũ nào "vượt tỷ lệ là chuyện tốt", tô xanh thay vì đỏ) là **FE tự đoán
theo tên hũ** (`jarCode`/`jarName` chứa "sav", "tiết kiệm", "invest", "LTSS", "FFA"...) —
**không phải dữ liệu thật từ BE**, vì `FinanceJar` hiện chưa có field phân loại chính thức.
Đây là hạn chế đã biết, đã đề xuất BE thêm field `jarType` để không phải đoán theo tên (đoán
trượt chỉ sai màu hiển thị, không sai số liệu).

### 4.3 Vì sao dùng `JsonReportView` thay vì model gõ cứng
4 endpoint report **không được Swagger document schema response** (chỉ có mô tả ngắn) — nếu
FE tự đặt tên field theo đoán, sai tên là mất luôn field đó (không lỗi, chỉ im lặng biến mất).
Giải pháp: `JsonReportView` là widget đệ quy, hiển thị **đúng những gì BE trả về**, tự nhận
diện định dạng tiền/ngày/enum theo TÊN và HÌNH DẠNG field (không phải map cứng từng response),
kèm từ điển dịch tiếng Việt cho các key đã biết. Field mới toanh chưa có trong từ điển vẫn hiện
được (rơi về tách camelCase tự động), không bao giờ crash hay mất dữ liệu.
*[Câu hỏi hay gặp]* "Vậy sao không xin BE tài liệu hóa response luôn cho chắc?" → đã hỏi trong
nhiều vòng trao đổi trước, xem `API_DOCS.md` ghi các mục "chưa document response" — đây là hạn
chế phía tài liệu BE, FE chọn giải pháp phòng thủ thay vì chờ.

### 4.4 Xuất CSV
Không có endpoint export riêng — FE tự "đi bộ" (walk) cây JSON đã nhận, làm phẳng thành các
dòng `Trường dữ liệu, Giá trị`, rồi copy vào clipboard. Không phải file thật gửi ra ngoài máy.

---

## 5. Luồng mời tham gia gia đình (Invite / Join Family)

*(Thêm mục này vì vừa sửa 2 lỗi UX trong buổi làm việc — hội đồng có thể hỏi ngay khi thấy
lịch sử commit gần nhất.)*

### 5.1 Cơ chế: mã mời 8 ký tự dùng lại nhiều lần — KHÔNG phải link 1 lần
⚠️ **Đính chính quan trọng**: `API_DOCS.md` bản cũ có ghi một luồng khác (token 1-lần,
`/invitations/{token}/claim`) — đã xác nhận qua code **luồng đó không còn được gọi ở đâu
trong FE nữa** (0 kết quả grep). Luồng thật đang chạy:

```
Trưởng nhóm: GET/POST /families/{id}/invite-code[/regenerate]  →  mã 8 ký tự (vd L7B3U4C9)
                                                                       │ chia sẻ mã/QR
                                                                       ▼
Người được mời: GET /invite-codes/{code}  (PUBLIC, không cần đăng nhập)
                     → preview tên gia đình
                     → POST /invite-codes/{code}/join-requests  (CẦN đăng nhập, KHÔNG cần verify email)
                                                                       │
                                                                       ▼
Trưởng nhóm: GET /families/{id}/join-requests?status=PENDING
             POST .../join-requests/{id}/approve | reject
```

### 5.2 Quy tắc nghiệp vụ cốt lõi
1. **Mã dùng lại được nhiều lần**, không phải link 1-lần-dùng — đổi mã (`regenerate`) mới làm
   mã cũ mất hiệu lực. Khác hẳn cơ chế token cũ (mỗi lời mời 1 token, gắn với 1 email cụ thể,
   403 nếu email đăng nhập khác email được mời).
2. **Không cần xác thực email để gửi yêu cầu tham gia** — khác hẳn tạo gia đình mới
   (`POST /families` đòi verify trước). Lý do nghiệp vụ: tạo gia đình là hành động có quyền
   lực (trở thành Manager ngay), còn xin tham gia là hành động **vô hại và cần người khác
   duyệt** — không có rủi ro gì khi cho phép tài khoản chưa verify gửi yêu cầu.
3. **`claim` (nếu còn tồn tại phía BE) ≠ tạo thành viên ngay**. Ở luồng mới cũng vậy:
   `join-requests` chỉ tạo bản ghi PENDING, `FamilyMember` chỉ sinh ra khi Manager gọi
   `approve` — tách hẳn "xin" và "được nhận" thành 2 bước có thể audit riêng.
4. **Token lời mời đang chờ (`pendingInviteToken`) sống sót qua đăng nhập** — nếu người dùng
   gõ mã lúc chưa đăng nhập, FE lưu mã vào secure storage (sống qua cả tắt-mở app), router tự
   điều hướng về đúng màn `/join?token=...` sau khi đăng nhập xong, không bắt gõ lại mã.
5. **[Sửa 2026-08-19] Tự gửi tiếp sau khi đăng nhập, không bắt bấm 2 lần** — trước đó người
   dùng phải bấm "gửi" 2 lần cho cùng một ý định (1 lần trước khi bị bắt login, 1 lần sau khi
   login xong). FE thêm cờ tạm trong bộ nhớ (`pendingInviteAutoSubmit`, one-shot) — chỉ set
   khi CHÍNH người dùng đã bấm gửi trước đó, để phân biệt với trường hợp mở `/join` lần đầu
   lúc đã đăng nhập sẵn (không được tự gửi khi chưa ai xác nhận ý định).
6. **[Sửa 2026-08-19] Màn chờ duyệt từng là ngõ cụt** — vì màn này hầu như luôn được điều
   hướng tới bằng `context.go()` (thay hẳn stack điều hướng, không phải đẩy chồng lên), nên
   Flutter không tự vẽ nút back (không còn gì để pop về). Đã tự vẽ nút back, xử lý theo thứ
   tự ưu tiên: pop nếu còn gì để pop → về `/family-setup` nếu đã đăng nhập nhưng chưa có gia
   đình → về đúng home theo vai nếu đã có gia đình → về `/login` nếu chưa đăng nhập.
7. **Poll trạng thái mỗi 12 giây** khi đang ở màn "Yêu cầu của tôi" — không dùng WebSocket cho
   luồng này (khác luồng thông báo real-time dùng Socket.IO). Khi thấy yêu cầu chuyển
   `APPROVED`, tự gọi lại `refreshFamilyContext` rồi điều hướng thẳng vào home theo vai.

### 5.3 Câu hỏi hội đồng dự kiến
- *"Sao có 2 tài liệu API khác nhau cho cùng tính năng mời?"* → Đã phát hiện và sửa trong
  buổi làm việc này: `API_DOCS.md` chưa cập nhật theo lần đổi thiết kế trước đó, đã bổ sung
  đính chính ngay trong repo (không phải hội đồng tự tìm ra trước).
- *"Vì sao không dùng deep link email như nhiều app khác?"* → Đây là lựa chọn thiết kế của
  BE (mã ngắn, dễ đọc-dán-gõ tay qua tin nhắn/gọi điện, không phụ thuộc app mail mở được link)
  — FE chỉ triển khai theo hợp đồng API đã có, không phải FE tự chọn cơ chế.

---

## 6. Bảng tổng hợp "câu trả lời né được vs không né được"

| Câu hỏi | Có thể trả lời chắc | Phải nói "chưa xác nhận từ BE" |
|---|---|---|
| Vì sao `varianceAmount`/`isOverBudget` từng hiển thị sai | ✅ đã sửa nhãn, đúng dữ liệu BE trả | Ngữ nghĩa gốc BE có đúng ý muốn hay không — đang chờ |
| Công thức "Theo hũ" tính trên chi hay thu | ✅ tính trên tổng chi (Swagger + verify) | — |
| `AT_RISK` tính thế nào | — | BE tính hoàn toàn, FE không có công thức để show |
| `availableSurplus` sao luôn 0 ở tháng hiện tại | Quan sát đúng vậy | Có phải chỉ tính kỳ đã đóng sổ — chưa BE xác nhận |
| Deputy tự duyệt khoản góp của mình được không | ✅ hiện tại được (lỗ hổng đã ghi nhận) | Có nên chặn hay không — đang chờ BE quyết |
| Xóa mục tiêu thì tiền góp có hoàn không | ✅ không tự hoàn | Có đúng ý thiết kế hay cần thêm luồng — chưa rõ |

**Nguyên tắc trả lời chung khi bí**: nói rõ *"đây là số/API do Backend trả, Frontend chỉ hiển
thị đúng nguyên văn"* khi câu hỏi đụng vào công thức tính (AT_RISK, isOverBudget, surplus...).
Đừng bịa công thức để trả lời cho trôi — hội đồng hỏi vặn tiếp là lộ ngay.
