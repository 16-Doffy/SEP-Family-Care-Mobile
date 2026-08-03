# Phân tích: chuyển tháng ở module Tài chính — 2026-08-02

> Bối cảnh: hôm nay là ngày 02/08, vừa qua mốc chuyển tháng. Người dùng báo 2 triệu chứng:
> 1. "Số dư ở tháng cũ không biết đi về đâu" — mở app thấy Tổng quỹ 0 ₫, lịch sử rỗng.
> 2. "Vào tháng mới không biết phải làm gì đầu tiên."
>
> Kết luận: **dữ liệu tháng 7 không mất**. Đây là lỗi FE — mọi màn tài chính đều hardcode
> `DateTime.now()` và **không có bộ chọn kỳ ở bất kỳ đâu**, nên qua 00:00 ngày 01/08 toàn bộ
> số liệu tháng 7 trở thành **không truy cập được từ UI**.

---

## 1. Nguyên nhân gốc — 9 điểm hardcode `DateTime.now()`

| File | Dòng | Gọi gì | Hệ quả khi sang tháng mới |
|---|---:|---|---|
| [wallet_provider.dart](lib/providers/wallet_provider.dart:228) | 228 | `/finance/summary?periodStart=01/08&periodEnd=31/08` | Hero card "Tổng quỹ gia đình" → 0 ₫ |
| [wallet_provider.dart](lib/providers/wallet_provider.dart:277) | 277 | `cash-flow-summary`, `category-spending-summary`, `member-contribution-summary` | 3 card phân tích → rỗng |
| [wallet_provider.dart](lib/providers/wallet_provider.dart:305) | 305 | `/finance/reports/overview` | Ghi đè `_monthlyIncome/_monthlyExpense` → 0 |
| [wallet_provider.dart](lib/providers/wallet_provider.dart:348) | 348 | `/finance/ledger/entries?month=8&year=2026` | Tab "Lịch sử" → "Chưa có giao dịch nào" |
| [finance_provider.dart](lib/providers/finance_provider.dart:959) | 959 | `/finance/monthly-finances/me` | Member → "Chưa khai báo hạn mức tháng" |
| [wallet_screen.dart](lib/screens/parent/wallet_screen.dart:105) | 105 | `reports/jar-target-actual` | Biểu đồ hũ → target/actual 0 |
| [finance_reports_screen.dart](lib/screens/parent/finance_reports_screen.dart:173) | 173 | 3 tab báo cáo | Báo cáo → rỗng, **không có filter kỳ** |
| [goal_detail_screen.dart](lib/screens/parent/goal_detail_screen.dart:724) | 724 | `surplus-availability` | Chỉ xin được số dư **tháng 8**, tháng 7 không vào được |
| [child_wallet_screen.dart](lib/screens/child/child_wallet_screen.dart:75) | 75 | `monthly-finances/me` | Member mất hạn mức đã khai tháng trước |

Không màn nào trong số này có widget chọn tháng. `goal_detail_screen.dart` có biến
`selectedMonth`/`selectedYear` (dòng 725–726) nhưng **không có UI nào ghi vào nó** —
sheet luôn khoá ở tháng hiện tại.

Ngoại lệ duy nhất: dialog **Chia quỹ theo mô hình**
([finance_model_screen.dart:813](lib/screens/parent/finance_model_screen.dart:813)) *có*
chọn kỳ tháng/năm. Đây là chỗ duy nhất trong app cho phép thao tác với kỳ khác tháng hiện tại.

---

## 2. Trả lời trực tiếp: "số dư tháng cũ đi về đâu?"

### Nó vẫn nằm ở BE, dưới tên **surplus của kỳ 7/2026**

`GET /finance/financial-goals/surplus-availability?month=7&year=2026`
→ `{ periodMonth, periodYear, totalSurplus, allocatedSurplus, availableSurplus }`

Đây chính là "phần dư tháng 7 chưa dùng đến". Đường đi nghiệp vụ đã có sẵn:
`POST /finance/financial-goals/{goalId}/surplus-allocations { periodMonth: 7, periodYear: 2026, amount }`
→ chuyển sang mục tiêu tài chính. Quỹ chung **không đổi**, chỉ là bút toán nội bộ
(xem [API_DOCS.md:441](API_DOCS.md:441)).

**Vấn đề FE:** card "Số dư quỹ tháng" ở [wallet_screen.dart:2154](lib/screens/parent/wallet_screen.dart:2154)
dẫn vào sheet đã khoá `month = 8`. Ngày 01/08 sheet đó báo *"Không còn số dư quỹ tháng 8"* —
đúng theo dữ liệu, nhưng người dùng đọc thành "mất tiền tháng 7".

### Còn "Tổng quỹ gia đình 0 ₫" thì sao?

Hero card đọc `budget.actualBalance` từ `/finance/summary` **có kèm `periodStart`/`periodEnd`**
([wallet_provider.dart:245](lib/providers/wallet_provider.dart:245)). Nếu BE tính field này
theo kỳ (thu − chi trong khoảng ngày truyền vào) thì 0 ₫ là kết quả đúng của một tháng chưa
có giao dịch — nhưng nhãn "**Tổng** quỹ gia đình" đang nói dối: nó là *số tháng này*, không
phải quỹ luỹ kế.

> ⚠️ **[CẦN VERIFY VỚI BE]** Ngữ nghĩa của `budget.actualBalance`: luỹ kế toàn thời gian hay
> theo kỳ truyền vào? `family-care-api.json` trong repo (150 endpoint, 62 schema) **đã cũ** và
> không chứa schema này; `API_DOCS.md` cũng chưa ghi. Không kết luận thay BE — nhưng dù đáp án
> là gì thì nhãn hiện tại vẫn sai với ít nhất một trong hai nghĩa.

---

## 3. Trả lời trực tiếp: "vào tháng mới phải làm gì đầu tiên?"

Nghiệp vụ **đã có đủ 5 bước**, nằm rải ở 5 màn khác nhau, không có màn nào gom lại:

| # | Việc | Ai làm | Ở đâu hiện tại |
|---|---|---|---|
| 1 | Kết chuyển số dư tháng trước vào mục tiêu | Trưởng/Phó | Chi tiết mục tiêu → sheet surplus (đang khoá tháng hiện tại) |
| 2 | Khai báo thu nhập / hạn mức chi cá nhân tháng mới | **Mọi thành viên** | Hồ sơ → Tài chính tháng (`monthly-finances/me` POST) |
| 3 | Chia quỹ tháng mới theo mô hình | Trưởng/Phó | Mô hình tài chính → "Chia quỹ theo mô hình" |
| 4 | Tạo + kích hoạt kế hoạch ngân sách kỳ mới | Trưởng/Phó | Kế hoạch ngân sách (`budget-plans` → `/activate`) |
| 5 | Đóng kế hoạch ngân sách tháng cũ | Trưởng/Phó | Chi tiết kế hoạch → `/close` |

Không có nhắc nhở, không có checklist, không có badge. Người dùng mở app ngày 01 và thấy
mọi thứ về 0 — không có tín hiệu nào nói "đây là tháng mới, làm 5 việc này".

Ràng buộc cần nhớ khi làm UI: **mỗi kỳ chỉ chia quỹ được một lần**, khoá chống trùng là
`familyId + periodMonth + periodYear`, đổi mô hình rồi chia lại vẫn `409`
([API_DOCS.md:455](API_DOCS.md:455)) → checklist phải đọc trạng thái thật trước khi hiện nút,
không được để user bấm rồi ăn 409.

---

## 4. Đã thi công (2026-08-02, thứ tự A → C → D → B)

> Trạng thái: `flutter analyze` toàn dự án — **0 error**, 20 info đều là mục có sẵn từ trước
> (không mục nào thuộc file mới/sửa trong đợt này).

### A — Chọn kỳ, dùng chung toàn module ✅

| File | Việc |
|---|---|
| [lib/models/finance_period.dart](lib/models/finance_period.dart) | **Mới.** Kiểu `FinancePeriod(year, month)` — `start`/`end`/`startIso`/`endIso`/`previous`/`next`/`isCurrent`/`isPast`/`label`. Thay cho việc mỗi màn tự tách `DateTime.now()`. |
| [lib/widgets/month_switcher.dart](lib/widgets/month_switcher.dart) | **Mới.** `◀ Tháng 8/2026 ▶` + nhãn "Kỳ đã qua" + nút "Tháng này". Chặn tiến quá kỳ hiện tại. |
| [wallet_provider.dart](lib/providers/wallet_provider.dart) | Kỳ nằm **trong provider**, không ở screen — xử lý đúng rủi ro đã nêu ở preview. `fetchWallets({period})`. Xóa `_lastDay()` không còn dùng. |
| [finance_provider.dart](lib/providers/finance_provider.dart) | Thêm `fetchMonthlyFinanceFor(period)`. `monthlyFinance` **cố ý giữ nguyên tháng hiện tại** vì nó quyết định POST/PUT của `upsertMonthlyFinance`. |
| [wallet_screen.dart](lib/screens/parent/wallet_screen.dart) | `MonthSwitcher` trên hero; báo cáo theo hũ đi theo kỳ; tiêu đề section theo kỳ. |
| [finance_reports_screen.dart](lib/screens/parent/finance_reports_screen.dart) | `MonthSwitcher` trên TabBar; 3/4 tab nhận kỳ và `didUpdateWidget` nạp lại. Tab "Ngân sách" không đổi — plan tự mang kỳ của nó. |
| [goal_detail_screen.dart](lib/screens/parent/goal_detail_screen.dart) | Sheet phân bổ số dư có `MonthSwitcher`; nhận kỳ mở sẵn qua `surplusPeriod`. |
| [child_wallet_screen.dart](lib/screens/child/child_wallet_screen.dart) | `MonthSwitcher`; hạn mức đọc theo kỳ. |
| [app_router.dart](lib/navigation/app_router.dart) | `/manager/goal-detail?period=YYYY-M`. |

Hai quyết định phát sinh khi code:
1. **Nút Thu/Chi bị ẩn khi đang xem kỳ cũ**, thay bằng dòng "Đang xem kỳ đã qua…". `entryDate`
   luôn là thời điểm hiện tại nên ghi trong kỳ cũ sẽ rơi vào tháng này rồi biến mất khỏi màn.
2. **`recordEntry` tự kéo kỳ về tháng hiện tại** sau khi ghi, vì lý do trên.

### C — Card "Kết chuyển tháng trước" ✅

Ở đầu tab Tổng quan: *"Kết chuyển tháng 7/2026 — 3.500.000 ₫ chưa phân bổ"* + nút mở picker mục
tiêu đã set sẵn kỳ 7. Có thêm dòng phụ khi đã phân bổ một phần (tổng dư / đã phân bổ). Gate
`canManageFinance`; không có mục tiêu ACTIVE thì vẫn báo số nhưng không dựng nút dẫn vào danh
sách rỗng. Sau khi phân bổ xong, quay lại màn là card tự nạp lại.

> **Bỏ điều kiện "ngày ≤ 10"** đã nêu ở preview. Số dư chưa phân bổ là sự thật đứng yên, và BE
> chưa xác nhận có job tự chốt kỳ (mục 5.4) — ẩn card sau ngày 10 sẽ dựng lại đúng cái bẫy
> "tiền biến mất" mà nó sinh ra để xử lý. Card tự ẩn khi `availableSurplus <= 0`.

### D — Checklist "Bắt đầu tháng" ✅

[lib/widgets/month_start_checklist.dart](lib/widgets/month_start_checklist.dart) — chỉ hiện ở
**kỳ hiện tại**, mỗi dòng tự đọc trạng thái thật:

| Dòng | Nguồn trạng thái | Ai thấy |
|---|---|---|
| Kết chuyển số dư kỳ trước | `surplus-availability(kỳ trước).availableSurplus` | Trưởng/Phó |
| Khai báo thu nhập & hạn mức | `monthly-finances/me` kỳ này | **Mọi vai trò** |
| Chia quỹ kỳ này theo mô hình | `fund-allocations?periodMonth&periodYear` | Trưởng/Phó |
| Kế hoạch ngân sách phủ kỳ này | lọc `budgetPlans` ACTIVE giao với kỳ | Trưởng/Phó |
| Đóng kế hoạch kỳ trước | `budgetPlans` ACTIVE có `periodEnd` < đầu kỳ | Trưởng/Phó |

- Mỗi mục **tự chịu lỗi riêng** — một endpoint hỏng không làm cả checklist biến mất, vì đúng lúc
  đó người dùng lại không biết phải làm gì.
- Dòng "chia quỹ" ghi rõ *mỗi kỳ chỉ chia được một lần* để không ai bấm rồi ăn `409`.
- Xong hết **và** đã qua ngày 7 thì card tự ẩn.
- Thành viên thường chỉ thấy 1 dòng và **không gọi** 4 endpoint Manager-only (tránh 403 vô ích).

### B — Hero card ✅ (phần không phụ thuộc BE)

- Nhãn `Tổng quỹ gia đình` → **`Quỹ gia đình · 8/2026`**. Con số lấy từ `/finance/summary` có kèm
  `periodStart`/`periodEnd`; gắn kỳ vào nhãn là đúng dưới **cả hai** cách hiểu của
  `actualBalance`, nên không cần chờ BE.
- Dòng phụ `Tháng này +x / -y` đổi theo kỳ đang xem.
- Thêm icon **?** → bottom sheet *"Tiền của tháng trước đi đâu?"* giải thích 3 ý: số liệu tính
  theo kỳ nên tháng mới về 0 (không phải mất tiền), cách xem lại kỳ cũ, và số dư chưa tiêu hết
  nằm ở mục Kết chuyển.

**Còn treo:** tách thành 2 số `Quỹ tích luỹ` + `Số dư kỳ` — chờ BE trả lời mục 5.1. Chưa bịa ra
số luỹ kế khi chưa có nguồn.

---

## 4b. Đề xuất FE gốc (giữ để đối chiếu)

### A. `MonthSwitcher` — thanh chọn kỳ dùng chung
Widget mới `lib/widgets/month_switcher.dart`: `◀ Tháng 7/2026 ▶` + nhãn "Tháng này" khi đang
ở kỳ hiện tại. Chặn tiến quá tháng hiện tại.

Gắn vào: Sổ thu chi gia đình (dưới hero), Báo cáo tài chính, sheet phân bổ số dư, Sổ chi tiêu
của member.

Thay đổi provider: `WalletProvider.fetchWallets({int? month, int? year})` và
`FinanceProvider._fetchMonthlyFinance({month, year})` — nhận kỳ từ ngoài thay vì tự lấy `now()`,
mặc định vẫn là tháng hiện tại (không đổi hành vi mặc định).

**Rủi ro:** `fetchWallets()` đang được gọi từ nhiều nơi (record/update/void entry đều gọi lại).
Phải giữ kỳ đang chọn trong provider, nếu không sau khi ghi giao dịch màn sẽ nhảy về tháng hiện tại.

### B. Tách hero card thành 2 số
`Tổng quỹ gia đình` → `Quỹ tích luỹ` (luỹ kế) + `Số dư tháng 8` (theo kỳ), thay vì một số mập mờ.
**Phụ thuộc câu trả lời của BE ở mục 2** — nếu BE không có số luỹ kế thì chỉ đổi nhãn thành
"Số dư tháng 8/2026" cho đúng sự thật, chưa thêm số mới.

### C. Card "Kết chuyển tháng trước"
Hiện ở đầu Sổ thu chi khi: ngày hiện tại ≤ 10 **và** `surplus-availability(tháng trước).availableSurplus > 0`.
Nội dung: *"Tháng 7 còn dư 3.500.000 ₫ chưa phân bổ"* + nút mở sheet **đã set sẵn kỳ = tháng 7**.
Gate `canManageFinance`. Đây là thứ trả lời trực tiếp câu "số dư tháng cũ đi đâu".

### D. Checklist "Bắt đầu tháng 8"
Card ở Sổ thu chi (Trưởng/Phó) + Trang chủ (member), hiện trong 7 ngày đầu tháng, 5 dòng theo
bảng mục 3, mỗi dòng tự đọc trạng thái thật để tick sẵn:
- Đã khai `monthly-finances/me` tháng này? → GET
- Đã chia quỹ kỳ này? → `GET /finance/fund-allocations?periodMonth&periodYear`
- Có `budget-plan` ACTIVE phủ kỳ này? → lọc `budgetPlans`
- Tháng trước còn `availableSurplus`? → GET
- Còn `budget-plan` ACTIVE của kỳ cũ chưa đóng? → lọc `periodEnd < đầu tháng này`

Member chỉ thấy dòng 1.

**Thứ tự đề nghị làm:** A → C → D → B (B chờ BE).

---

## 5. Đề xuất Backend (Rule 2)

### 🔴 Bắt buộc — chặn mục B

1. **Chốt ngữ nghĩa `budget.actualBalance` trong `GET /finance/summary`.**
   Luỹ kế toàn thời gian, hay chỉ trong `periodStart..periodEnd`?
   - Nếu **theo kỳ**: xin bổ sung `openingBalance` (số dư đầu kỳ) và `closingBalance` (cuối kỳ)
     vào response. Không có 2 field này thì FE **không thể** hiển thị đúng "quỹ gia đình đang
     có bao nhiêu" — đó là con số người dùng tìm đầu tiên khi mở app.
   - Nếu **luỹ kế**: chỉ cần xác nhận, FE tự sửa nhãn.

2. **Cập nhật `family-care-api.json` trong repo.** Bản đang có 150 endpoint / 62 schema, thiếu
   hẳn `FinanceSummaryResponseDto`. Mọi kết luận về finance hiện phải suy đoán từ runtime —
   đã có tiền lệ đoán sai tên field làm card hiện 0 đ âm thầm ([API_DOCS.md:176](API_DOCS.md:176)).

### 🟡 Nên có — cải thiện UX

3. `GET /finance/monthly-finances/me/history?fromMonth&toMonth` — đã ghi nhận là **chưa có**
   ([API_DOCS.md:18](API_DOCS.md:18)). Không có nó, biểu đồ xu hướng của member phải loop từng
   tháng, mỗi tháng 1 request.

4. Xác nhận hành vi **cuối tháng**: BE có tự động làm gì lúc 00:00 ngày 01 không (đóng kỳ, chốt
   surplus, sinh alert, auto-close budget plan)? Nếu **không** thì `availableSurplus` của tháng 7
   sẽ nằm đó vô thời hạn — FE cần biết để quyết định card mục C nên hiện bao lâu, hay hiện mãi
   cho tới khi được phân bổ hết.

5. Cân nhắc `POST /finance/periods/{year}/{month}/close` — chốt kỳ tường minh. Hiện tại không có
   khái niệm "đã chốt sổ tháng 7", nên không phân biệt được "tháng 7 chưa ai xem" với
   "tháng 7 đã xử lý xong".

---

## 6. Không đổi so với báo cáo 29/07

Các mục P0/P1 trong [PHAN_TICH_TIEN_TRINH_VA_DE_XUAT_FE_UIUX_2026-07-29.md](PHAN_TICH_TIEN_TRINH_VA_DE_XUAT_FE_UIUX_2026-07-29.md)
vẫn giữ nguyên độ ưu tiên. Báo cáo này **bổ sung một P0 mới**: *chuyển tháng ở Finance* — vì nó
làm người dùng tin rằng app mất tiền của họ, mức độ nghiêm trọng cao hơn mọi mục UIUX còn lại.

Liên quan tới mục "P1 — Finance information architecture" (tách 5 khu vực): việc chọn kỳ nên làm
**trước** khi tách IA, vì mọi khu vực đều cần chung một bộ chọn kỳ.
