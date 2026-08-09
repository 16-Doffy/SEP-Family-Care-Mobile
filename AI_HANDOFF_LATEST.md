# Family Care Mobile — AI Handoff (Latest)

Last updated: **2026-08-09**

## Test sau merge Giáp — 1 fix FE + 4/5 actionType tài chính mới chưa có pendingAction

Sau khi merge code Giáp (SOS/wearable/Google login) vào `main`/`NDuy`, user
test lại theo script (regression + 5 loại đề xuất tài chính mới vừa chốt
9 `actionType` chính thức). Kết quả:

**Regression (Rửa bát, khoản chi 50k):** chạy đúng — xác nhận/từ chối vẫn ra
banner đúng màu. Riêng khoản chi 50k lần này AI **tự gán được `categoryId`**
(tính năng BE mới làm) nhưng field "Danh mục" hiện **nguyên UUID thô**
(`0a3d7df8-517a-4fc8-...`) — **ĐÃ SỬA**: thêm `resolveCategoryName()`
(top-level, `lib/screens/shared/ai_assistant_screen.dart`) tra ngược qua
`FinanceProvider.categories` (đã tải sẵn ở app scope) để hiện tên thật thay
vì ID; áp dụng cho cả `_PendingActionCard._previewRow` (đang chờ xác nhận)
lẫn `_ResultCard._detailRow` (đã xử lý xong) — cả hai đều có thể hiện field
Danh mục. Không tìm thấy danh mục (đã xóa/chưa tải kịp) thì lùi về hiện ID
thô, không giả vờ có tên. Test mới: `test/ai_category_name_test.dart` (3
test, `testWidgets` vì hàm cần `BuildContext` để đọc provider).

**5 actionType tài chính mới — chỉ 1/5 hoạt động, 4/5 thiếu `pendingAction`:**
- ✅ `CREATE_BUDGET_LINE` ("Thêm dòng ngân sách 2.000.000đ cho mục ăn uống")
  — ra thẻ đầy đủ, xác nhận thành công.
- ❌ `CREATE_FINANCIAL_GOAL`, `CREATE_GOAL_ALLOCATION`,
  `CREATE_GOAL_CONTRIBUTION_PLAN`, `ALLOCATE_FUND_BY_MODEL` — AI chỉ trả lời
  bằng chữ ("Đề xuất đã được tạo... bạn hãy vào ứng dụng để xác nhận nhé!")
  **không kèm `pendingAction`/thẻ nào cả** — đúng pattern lỗi "chập chờn" đã
  gặp với `CREATE_LEDGER_ENTRY` trước đây, giờ lặp lại có hệ thống với 4/5
  loại mới. Nhiều khả năng giống `ACTION_PLAN_CARD` trước đó: BE mới thêm
  vào Swagger/schema nhưng AI chưa thực sự được dạy sinh đúng cấu trúc cho 4
  loại này.

**Cần báo BE**: 4 actionType tài chính mới (`CREATE_FINANCIAL_GOAL`,
`CREATE_GOAL_ALLOCATION`, `CREATE_GOAL_CONTRIBUTION_PLAN`,
`ALLOCATE_FUND_BY_MODEL`) chưa thực sự sinh `pendingAction` dù đã có trong
danh sách `AiActionType` chính thức — chỉ `CREATE_BUDGET_LINE` hoạt động
đúng trong 5 loại vừa thêm.

Verify: `flutter analyze` 0 error, `flutter test` 403/403 pass. Chưa verify
runtime cho fix `resolveCategoryName` — nhờ user test lại đúng field Danh
mục có hiện tên thay vì UUID không.

## BE fix nốt 4/4 mục còn lại — FE hầu như không cần đổi gì (2026-08-09)

BE phản hồi và fix cả 4 mục cuối cùng còn treo:

1. **Giờ "ngay bây giờ" lệch** — BE sửa lấy đúng timestamp hiện tại theo giờ
   VN trước khi gắn `+07:00` (ví dụ `2026-08-09T10:04:05+07:00`). Thuần BE,
   không có gì để FE sửa — nhờ user test lại luồng "... ngay bây giờ" để
   xác nhận hết lệch.
2. **Title thẻ phân biệt thu/chi** — EXPENSE → "Tạo khoản chi", INCOME →
   "Tạo khoản thu", nhãn nút Xác nhận/Sửa cũng phân biệt theo loại. FE
   **không cần đổi gì** vì đã tin thẳng `uiHints.title`/`primaryActionLabel`/
   `secondaryActionLabel`/`editActionLabel` từ Sprint 2 — tự động ăn theo
   ngay khi BE đổi chữ, không cần deploy lại FE.
3. **Phân trang ledger entries** — BE đổi sort mặc định thành `createdAt desc`
   rồi mới tới `entryDate desc`, khoản mới tạo (AI hay thủ công) luôn nổi
   lên trang đầu. FE **không cần đổi gì** — `WalletProvider._fetchEntries`
   vẫn giữ nguyên lớp sort lại theo `createdAt` ở client làm lá chắn thứ hai
   (giờ chỉ là no-op vô hại vì BE đã trả đúng thứ tự sẵn, không xung đột).
4. **AI tự gán danh mục khi rõ nghĩa** — BE chỉnh prompt để AI gọi
   `list_finance_categories` và gửi `categoryId` khi nội dung khớp rõ danh
   mục (không khớp thì để trống, không chặn user); có `categoryId` thì BE
   tự map sang `jarId` theo mô hình đang áp dụng, giống hệt luồng tạo thủ
   công. **1 chỗ FE đã vá phòng ngừa**: nhánh fallback cũ (khi BE không gửi
   `uiHints.fields`, dùng trực tiếp `preview`) thiếu `categoryId` trong danh
   sách khóa nhận diện — thêm vào `_fieldsFromLegacyPreview`/`_legacyFieldLabel`
   (`lib/models/ai_chatbot.dart`) để không bị rơi mất field Danh mục nếu rơi
   vào nhánh dự phòng này. Thêm 1 test khóa hành vi trong `ai_ui_hints_test.dart`.

**BE cũng đề xuất thêm màn "Sửa danh mục" cho giao dịch đã tạo** (xử lý dữ
liệu cũ/giao dịch chưa gắn danh mục) — trùng với đề xuất chị đã nêu trước đó
(`WalletProvider.updateLedgerEntry()` có sẵn nhưng chưa màn nào gọi). Vẫn
đang chờ user quyết định có làm ngay không.

Verify: `flutter analyze` 0 error, `flutter test` 305/305 pass (thêm 1 test
mới). Chưa verify runtime — nhờ user test lại cả 4 mục, đặc biệt xem chữ
"Tạo khoản chi"/"Tạo khoản thu" và field Danh mục (nếu AI nhận diện được)
có hiện đúng không.

## Snapshot cuối phiên 2026-08-09 — AI Chatbox coi như ổn định, phát hiện thêm 2 việc ở Sổ thu chi

**Trạng thái AI Chatbox: ỔN ĐỊNH**, đã test đủ vòng đời (chat thường, action
đơn lẻ đủ 3 outcome màu đúng, `ACTION_PLAN_CARD` nhiều bước xác nhận/từ chối
độc lập, phân quyền theo vai trò, Daily Brief, markdown). Không còn bug FE
nào treo trong tính năng này.

**Còn 4 mục cần báo BE (đã tổng hợp gửi user):**
1. Giờ tạo khoản thu/chi qua "ngay bây giờ" bị lệch so với giờ thật (BE
   tính `now()` sai trước khi gắn nhãn `+07:00`, đã xác minh không phải FE).
2. `uiHints.title` cho `CREATE_LEDGER_ENTRY` dùng chung "Tạo giao dịch tài
   chính", nên phân biệt EXPENSE/INCOME (đã có field `Loại` sẵn để phân biệt).
3. **[Mới]** Phân trang `finance/ledger/entries` nên theo `createdAt` giảm
   dần thay vì `entryDate` — giao dịch AI vừa tạo hôm nay (09/08) bị kẹt ở
   trang 2 vì các khoản "Allocate fund to X" (chia quỹ, tạo từ trước) có
   `entryDate` = cuối tháng (31/08, tương lai) nên luôn được BE xếp lên
   trang 1 nếu BE phân trang theo `entryDate`. Fix `WalletProvider._fetchEntries`
   trước đó (sort lại theo `createdAt`) chỉ sắp xếp đúng THỨ TỰ trong 1 trang
   đã tải — không kéo được item từ trang 2 lên trang 1 vì đó là ranh giới do
   BE quyết định, FE không sửa được nếu không tải dư nhiều trang (tốn kém).
4. **[Mới]** AI tạo khoản chi/thu không gửi kèm `categoryId` — khoản đó
   không được BE tự gán hũ theo mô hình tài chính (rơi vào "Chưa gán hũ").
   Xác nhận qua: (a) không thẻ AI nào từng hiện field Danh mục, (b) form tạo
   giao dịch thủ công có ô chọn danh mục kèm chú thích "Backend tự gán hũ
   theo danh mục", (c) số "Chưa gán hũ" ở màn Ngân sách khớp với các khoản
   AI tạo. Cần BE quyết định: AI có nên hỏi/gợi ý danh mục khi tạo khoản chi
   không.

**Phát hiện thêm, đang chờ user quyết định hướng làm:** `WalletProvider.updateLedgerEntry()`
đã viết sẵn (PATCH `/finance/ledger/entries/{id}`, nhận `categoryId`/`jarId`)
nhưng **chưa có màn nào trong app gọi tới nó** — hiện không có cách nào sửa
lại danh mục của một giao dịch đã tạo (dù AI tạo hay tạo tay quên chọn danh
mục). Có thể làm 1 màn "Sửa danh mục" tận dụng hàm có sẵn này nếu user muốn,
thay vì chỉ báo BE mục 4 ở trên.

## `ACTION_PLAN_CARD` — XÁC NHẬN HOẠT ĐỘNG ĐÚNG qua test thật (2026-08-09)

Sau nhiều lần test qua lại (ban đầu tưởng chưa hoạt động, sau lại tưởng có
lỗ hổng an toàn — cả hai đều do đọc thiếu ảnh chụp, đã đính chính), **user
chụp đủ trình tự đầy đủ và xác nhận rõ ràng cả 2 điểm còn treo trước đó**:

- Câu "Giúp tôi chuẩn bị cho chuyến du lịch: tạo lịch đi chơi cuối tuần này
  và ghi khoản chi 500.000đ tiền đặt cọc" ra ĐÚNG 1 tin nhắn (1 avatar AI
  duy nhất) chứa 2 thẻ xếp chồng (`pendingActions[]` 2 phần tử: lịch +
  khoản chi) — đúng contract `ACTION_PLAN_CARD` Sprint 3.
- Xác nhận/từ chối từng thẻ **độc lập với nhau**: hủy thẻ lịch xong, thẻ
  khoản chi vẫn giữ nguyên "Chờ xác nhận", không bị ảnh hưởng — đúng thiết
  kế `actionIndex` riêng từng bước.
- **Endpoint reject-theo-step (`POST .../actions/:actionIndex/reject`) chạy
  đúng, không lỗi 404/mạng nào** — xác nhận path FE từng đoán (đối xứng với
  `/confirm`) là ĐÚNG. Bỏ hẳn cờ `[VERIFY]` cho endpoint này.
- Khi TOÀN BỘ các bước trong 1 kế hoạch đều bị từ chối, BE trả về đúng 1 thẻ
  tổng kết "Kế hoạch đã hủy" — vòng đời plan (xác nhận/từ chối riêng từng
  bước + tổng kết khi hoàn tất) hoạt động đúng đầu-cuối.

**Kết luận: rút cả 2 mục `ACTION_PLAN_CARD` chưa hoạt động và endpoint
reject chưa xác nhận khỏi danh sách "Cần báo BE" — không cần hỏi BE gì thêm
về Sprint 3 nữa.** Đã cập nhật `API_DOCS.md` xóa cờ `[VERIFY]` tương ứng.

## Làm rõ 3 quan sát ngày/giờ + AI hỏi lại — không sửa code FE (2026-08-09)

User gửi 3 ảnh chụp test tạo khoản thu/chi qua AI, nhờ làm rõ logic. Đã đọc
kỹ lại `formatAiPreviewValue`/`formatAiPreviewDateTime`
(`ai_assistant_screen.dart`) và `_fmtDateTime` (`json_report_view.dart`) để
xác nhận chắc chắn trước khi kết luận — **không có gì cần sửa ở FE cho cả 3
mục**:

1. **"Tạo khoản thu ... hôm nay" → ngày đúng nhưng giờ vẫn `00:00`** — ĐÚNG
   THIẾT KẾ. BE đã xác nhận trước đó: `entryDate` là field "ngày sổ sách"
   (ngày lịch), chuẩn hóa về mốc đầu ngày khi người dùng không nói giờ cụ
   thể — không phải timestamp chính xác. FE hiển thị đúng nguyên giá trị.
2. **AI hỏi lại khi câu lệnh thiếu thông tin (không nói rõ thu/chi, số
   tiền)** — ĐÚNG HÀNH VI MONG MUỐN. AI tự bịa số tiền thay vì hỏi lại mới là
   vấn đề nghiêm trọng hơn (tạo nhầm dữ liệu tài chính bằng số AI tự nghĩ
   ra). Không phải lỗi hiển thị/logic FE.
3. **"Tạo khoản chi ... ngay bây giờ" → giờ hiển thị lệch so với giờ thật** —
   LÀ BUG THẬT, nhưng ở phía BE. Đã rà lại 2 hàm format hiển thị: chỉ có
   `DateTime.tryParse(...).toLocal()`, không có phép cộng/trừ giờ thủ công
   nào. Theo đúng semantics Dart, chuỗi ISO có offset tường minh (`+07:00`)
   được quy đổi đúng về một thời điểm tuyệt đối ngay lúc parse — FE không có
   cách nào làm lệch giá trị này thêm lần nữa. Nếu giờ hiển thị sai thì giá
   trị BE gửi về đã sai TỪ TRƯỚC khi tới FE.

Xem mục "Cần báo BE" phía dưới cho chi tiết mục 3 kèm bằng chứng.

## Ví dụ "Nhờ AI tạo" trộn cả thu lẫn chi + phát hiện bug ngày sai — 2026-08-09

User hỏi ý kiến: chip "Tạo thu/chi" nên gộp chung hay tách riêng "Tạo khoản
chi"/"Tạo khoản thu" thành 2 nút/submenu? **Đề xuất & đã làm**: giữ gộp
chung một chip (đây chỉ là gợi ý mở đầu câu chat, không phải form — tách nút
chỉ chật dải chip, không giúp AI hiểu tốt hơn), nhưng mở rộng bộ mẫu random
(`_ledgerPromptSamples`, đổi tên từ `_expensePromptSamples`/
`_randomExpensePrompt` → `_randomLedgerPrompt`) để **trộn cả ví dụ khoản
thu** (lương, thưởng, lì xì, làm thêm) bên cạnh các ví dụ khoản chi có sẵn —
người dùng tự khám phá được cả hai khả năng khi bấm lại nhiều lần, không cần
thêm nút. Cập nhật `test/ai_prompt_role_test.dart` (assertion đổi từ cố định
"ghi khoản chi" sang "ghi khoản" chung để không bị flaky theo kết quả random).

**[Cần báo BE]** Ảnh test cho thấy field "Ngày" của khoản chi tạo qua câu
"... tuần này" ra `00:00 06/08/2026` trong khi ngày thật lúc test là
09/08/2026 — lệch tận 3 ngày, không phải lỗi timezone (giờ `00:00` là đúng
theo thiết kế BE đã nói rõ: `entryDate` chuẩn hóa về mốc đầu ngày
`YYYY-MM-DDT00:00:00+07:00`, không phải timestamp thật — FE hiển thị đúng y
nguyên giá trị nhận được, không có phép cộng/trừ giờ nào ở đây). Vấn đề DUY
NHẤT là ngày bị sai — nghi AI dùng sai mốc "hôm nay" khi suy luận cụm từ
tương đối như "tuần này"/"hôm nay" lúc tạo `entryDate`, không liên quan gì
đến format vừa fix. Cần BE xác nhận ngữ cảnh "ngày hiện tại" AI dùng để suy
luận các cụm tương đối có đúng giờ VN thời điểm request không.

Về chữ "giao dịch" còn xuất hiện trong tiêu đề thẻ ("Tạo giao dịch tài
chính", "Đề xuất đã hủy") dù đã có field `Loại: EXPENSE/INCOME` sẵn: đây là
`uiHints.title` do BE tự sinh, KHÔNG phải hardcode ở FE (đã grep xác nhận) —
theo đúng nguyên tắc đã thống nhất (tin thẳng `uiHints`, không tự đoán/sửa
lại chữ BE gửi), FE không tự đổi chữ này. **Cần báo BE**: nên phân biệt tiêu
đề theo `Loại` (`Tạo khoản chi`/`Tạo khoản thu`) thay vì dùng chung một câu
"Tạo giao dịch tài chính" cho mọi trường hợp.

Verify: `flutter analyze` 0 error, `flutter test` 304/304 pass (chạy lại
`ai_prompt_role_test.dart` 5 lần liên tiếp xác nhận hết flaky). Xác nhận
runtime (từ ảnh user gửi): **màu outcome đã đúng** — Xác nhận ra xanh, Hủy
ra xám — fix `_ResultCard` outcome-aware ở mục dưới đã hoạt động tốt.

## BE fix 5/8 mục đã báo cáo — FE cập nhật theo, ĐÃ XONG (2026-08-09)

BE phản hồi và fix 5 trong 8 mục ở danh sách "Cần báo BE" (2 mục còn lại về
`ACTION_PLAN_CARD`/endpoint reject-theo-step vẫn treo, chưa có tin BE; mục
thiếu tên hiển thị chỉ cần verify lại, không có code FE để đổi).

1. **`CREATE_LEDGER_ENTRY` chập chờn (BE fix, FE cần test lại)** — nguyên
   nhân là `entryDate` do AI sinh format không ổn định. BE đã normalize
   trước khi validate (`YYYY-MM-DD` → thêm giờ 00:00 +07:00, thiếu timezone
   → tự thêm +07:00, không parse được → fallback ngày hiện tại giờ VN).
   **Không có code FE nào cần đổi** — nhờ user test lại luồng "Ghi khoản chi
   ... hôm nay/tuần này" nhiều lần xem còn chập chờn không.

2. **`uiHints.displayStyle` sai sau confirm/reject (BE fix tận gốc, FE bỏ
   lớp vá tạm)** — BE xác nhận `REJECTED`/`CONFIRMED`/`EXPIRED` giờ luôn trả
   đúng `RESULT_CARD`, `content` cập nhật đúng theo trạng thái thật (không
   còn giữ câu "vui lòng xác nhận" cũ). Đã bỏ đoạn ép cứng `actionCard` cho
   action đã xử lý ở `AiMessage.effectiveDisplayStyle` (`lib/models/ai_chatbot.dart`)
   — giờ tin thẳng `uiHints.displayStyle` như thiết kế ban đầu. **`_ResultCard`
   (`ai_assistant_screen.dart`) đổi thành outcome-aware**: màu/icon lấy theo
   `pendingAction.outcome` (`outcomeColorFor`/`outcomeIconFor`, tách top-level
   dùng chung với `_PendingActionCard`) thay vì mặc định xanh "thành công"
   cho cả 3 trường hợp — REJECTED giờ hiện xám, EXPIRED hiện đỏ, đúng màu
   từng loại.

3. **`CREATE_BUDGET_PLAN` xác nhận chính thức** — thêm vào
   `AiPendingAction.confirmedActionTypes` (giờ 4 loại), thêm nhãn "Tạo kế
   hoạch ngân sách", icon/màu riêng (`Icons.pie_chart_outline_rounded`,
   `AppColors.accent500`). `_confirmAndReload` thêm nhánh `refreshFinance`
   gọi `FinanceProvider.fetchAll()` sau khi xác nhận (kéo lại
   models/jars/categories/budgetPlans/goals/monthlyFinance — đúng yêu cầu BE
   "refresh Wallet/Budget screens, budget plan list/detail, và finance
   overview").

4. **Permission message mất dấu (BE fix)** — không có code FE, nhờ user test
   lại xem các câu "Bạn không có quyền..." đã có dấu đầy đủ và NHẤT QUÁN
   giữa các loại hành động chưa (trước đó phát hiện có câu đúng dấu, có câu
   sai — cần xem đã sửa hết chưa).

5. **Nút "Sửa" — làm rõ luồng chính thức (không phải fix code)** — BE xác
   nhận không có endpoint edit, luồng đúng là mở form tạo dữ liệu tương ứng
   prefill từ `preview`. FE chưa có form prefill riêng theo actionType nên
   fallback hiện tại (từ chối rồi để gõ lại) được BE xác nhận là hợp lệ —
   **giữ nguyên code, chỉ cập nhật lại comment/doc** không còn gắn nhãn "suy
   đoán tạm" nữa.

**Test cập nhật:** `test/ai_pending_action_contract_test.dart` (4 actionType
thay vì 3, thêm nhóm test cho `outcomeMessageFor`/`outcomeColorFor`/
`outcomeIconFor`), `test/ai_ui_hints_test.dart` (2 test khóa hành vi vá tạm
cũ đã đổi thành khóa hành vi mới — tin thẳng `uiHints.displayStyle` cho
RESULT_CARD).

Verify: `flutter analyze` 0 error, `flutter test` 304/304 pass. Chưa verify
runtime cho cả 5 mục — nhờ user test lại, đặc biệt mục 1 và 2 (mục 2 cần coi
màu card sau khi Hủy/Xác nhận/Hết hạn có đúng xám/xanh/đỏ tương ứng không).

**Còn treo với BE (2 mục cũ chưa có phản hồi):** `ACTION_PLAN_CARD` chưa
từng thấy hoạt động thật trong runtime; endpoint reject-theo-step
(`.../actions/:actionIndex/reject`) chưa được BE xác nhận nguyên văn.

## Snapshot hiện hành 2026-08-09 — đọc phần này trước khi làm tiếp

**Trạng thái nhánh:** `NDuy` và `main` đang **trùng nhau tuyệt đối**
(`fc69b9d`, đã push cả hai). `origin/giap` đang **thua `main` 14 commit**
(không có commit riêng nào khác) — cần báo Giáp `git pull origin main` để
lấy bản mới nhất, không có rủi ro mất việc của bạn ấy khi làm vậy.

**Việc đã xong trong phiên 2026-08-08 → 2026-08-09 (chi tiết ở các mục dưới,
theo thứ tự mới nhất trên cùng):**
1. Wire BE Sprint 3 — `ACTION_PLAN_CARD` nhiều bước (model/provider/UI/test),
   backward-compatible với dữ liệu cũ. **Chưa verify runtime** vì BE chưa
   từng thực sự trả về plan nhiều bước trong lúc test (xem mục ngay dưới).
2. Sửa mất banner "đã từ chối" sau khi Hủy đề xuất (ưu tiên `pendingAction.status`
   thật hơn `uiHints.displayStyle` khi đề xuất đã có kết quả).
3. Sửa màn Trợ lý AI load trắng giữa chừng (Daily Brief tải trễ, đua với
   scroll-to-bottom).
4. Sửa 2 bug cuộn UX (icon xem lại Daily Brief kéo lệch vị trí; gửi tin đầu
   tiên từ màn trống không tự cuộn xuống).
5. Thêm ô nhập thu/chi "thực tế" hàng tháng cho thành viên (Hồ sơ → Tài
   chính tháng) — BE đã hỗ trợ sẵn field, chỉ thiếu UI.
6. Sửa checklist "Bắt đầu tháng" không tự tick sau khi khai báo (thiếu reload
   sau khi quay về từ màn khai báo).
7. 4 bug UX/UI phát hiện từ ảnh test thật (nhảy màn khi Xác nhận/Hủy, ví dụ
   chi tiêu set cứng 200k, markdown `**...**` hiện dấu sao thô, giờ ISO thô
   trong thẻ sự kiện lịch).
8. Sửa layout overflow Daily Brief + UX mở màn luôn đứng ở đầu (không tự
   cuộn xuống hội thoại đang dở).
9. Toàn bộ Sprint 2 (`uiHints`-driven rendering, 5 `displayStyle`, Daily
   Brief) — nền tảng cho mọi việc ở trên.

**Cần báo BE (8 mục, đã tổng hợp gửi user để gửi team BE — xem chi tiết ở
mục "BE Sprint 3" và các mục cũ hơn phía dưới):**
1. `ACTION_PLAN_CARD` chưa thực sự hoạt động — request nhiều hành động vẫn
   rơi về 1 action đơn, AI tự báo lỗi ("có lỗi khi ghi cả hai hành động cùng
   lúc"...). **Chưa từng thấy plan nhiều bước thật trong runtime.**
2. Endpoint reject-theo-step chưa xác nhận được nguyên văn (BE cắt dòng giữa
   chừng) — FE đang dùng `/reject` theo suy đoán đối xứng, chưa test được vì
   phụ thuộc mục 1.
3. Tạo đề xuất ghi khoản chi lỗi chập chờn, tự nhận liên quan định dạng ngày.
4. `uiHints.displayStyle` đổi sai sau khi resolve đề xuất, nội dung không
   cập nhật theo trạng thái mới (FE đã tự vá được, BE vẫn nên sửa gốc).
5. `actionType` mới `CREATE_BUDGET_PLAN` chưa xác nhận chính thức.
6. Thông báo từ chối quyền mất dấu tiếng Việt không nhất quán.
7. AI không biết displayName thành viên thật.
8. Cơ chế nút "Sửa" (`editActionLabel`) chưa rõ, FE đang tạm suy đoán.

**Quy trình đang áp dụng:** Claude chỉ code + fix, KHÔNG tự mở emulator thao
tác — user tự test mọi thay đổi UI/UX và báo lại bằng ảnh chụp. Mọi thay đổi
đều chạy `flutter analyze --no-fatal-infos` (0 error) + `flutter test`
(301/301 pass tính đến cuối phiên này) trước khi commit, nhưng **chưa có xác
nhận runtime nào** cho các mục 1-8 ở trên cho tới khi user tự test.

## BE Sprint 3 — kế hoạch nhiều bước `ACTION_PLAN_CARD` — ĐÃ WIRE (2026-08-09)

BE nâng cấp AI Chatbot lên Sprint 3, **backward-compatible**, endpoint cũ
(gửi chat, `confirm-action`, `reject-action`) giữ nguyên. Điểm mới: một
`aiMessage` có thể có nhiều đề xuất trong `pendingActions[]` thay vì đúng một
`pendingAction`; BE nói rõ `pendingAction` (số ít) **vẫn còn, là alias của
`pendingActions[0]`**. Khi `uiHints.displayStyle === "ACTION_PLAN_CARD"` thì
render card kế hoạch nhiều bước, mỗi bước có `actionIndex` riêng, xác
nhận/từ chối qua 2 endpoint mới theo bước (khác endpoint cũ theo message).

**Model (`lib/models/ai_chatbot.dart`):**
- `AiMessage.pendingAction` (field) → đổi thành **getter** đọc
  `pendingActions.first` — giữ nguyên 100% API đọc cũ (`message.pendingAction`
  chạy y hệt mọi nơi, không sửa gì ở `ai_assistant_screen.dart` cho các case
  action đơn lẻ), chỉ đổi cách LƯU trữ nội bộ.
- `AiMessage.pendingActions` (mới, `List<AiPendingAction>`) — parse từ
  `pendingActions[]` nếu BE gửi; nếu không, tự bọc `pendingAction` số ít
  thành list 1 phần tử (tương thích dữ liệu cũ hoàn toàn, có test khóa).
- `AiPendingAction.actionIndex` (mới, mặc định `0`) — ưu tiên đọc trực tiếp
  từ JSON nếu BE gửi, không thì lấy theo VỊ TRÍ trong mảng `pendingActions[]`.
- `AiDisplayStyle.actionPlanCard` (mới, map từ `ACTION_PLAN_CARD`).
  `effectiveDisplayStyle` kiểm tra style này TRƯỚC quy tắc "action đã xử lý
  thì ép actionCard" (quy tắc đó chỉ áp dụng action đơn lẻ, không áp dụng
  plan — mỗi bước tự có banner trạng thái riêng qua chính
  `_PendingActionCard` được tái dùng).
- `copyWith({pendingAction})` giữ nguyên chữ ký cũ (không ai gọi ngoài code
  hiện tại, nhưng vẫn không đổi để phòng ngừa), chuyển đổi nội bộ sang
  `pendingActions`.

**Provider (`lib/providers/ai_chatbot_provider.dart`):**
- `confirmStep(messageId, actionIndex)` / `rejectStep(messageId, actionIndex)`
  gọi 2 endpoint mới. `isStepBusy(messageId, actionIndex)` — key riêng
  `'$messageId#$actionIndex'`, không đụng `_actionBusy` của action đơn lẻ.
- **`[VERIFY]`** endpoint reject-theo-step: BE gửi tin nhắn bị cắt dòng đúng
  chỗ path này (`.../actions/:actionIndex/` rồi dừng) — FE tạm dùng `reject`
  theo đối xứng với `confirm`, **chưa được BE xác nhận nguyên văn**. Cần hỏi
  lại BE xác nhận đúng đuôi path trước khi coi đây là chốt cuối cùng.

**UI (`lib/screens/shared/ai_assistant_screen.dart`):**
- `_ActionPlanCard` (mới) — render `message.content` (nếu có) + lặp qua
  `message.pendingActions`, mỗi bước là một `_PendingActionCard` (tái dùng
  nguyên, không viết lại UI thẻ).
- `_PendingActionCard` thêm field `stepIndex` (mặc định `null` = hành vi cũ y
  nguyên cho action đơn lẻ). Khác `null` thì Xác nhận/Hủy/nút "Sửa" gọi
  `confirmStep`/`rejectStep` thay vì `confirmAction`/`rejectAction`, và
  `busy` đọc từ `isStepBusy` thay vì `isActionBusy`.
- `_MessageBubble` thêm case `AiDisplayStyle.actionPlanCard => _ActionPlanCard(...)`.

**Test mới:** `test/ai_action_plan_test.dart` (8 test) — khóa parse
`pendingActions[]`/`actionIndex`/`ACTION_PLAN_CARD`, và khóa riêng hành vi CŨ
(message chỉ có `pendingAction` số ít, hoặc không có gì) không bị đổi.

Verify: `flutter analyze` 0 error, `flutter test` 301/301 pass. Chưa verify
runtime (chưa có ví dụ `ACTION_PLAN_CARD` thật từ BE để test) — nhờ user tự
test khi BE trả về plan nhiều bước thật, đặc biệt xác nhận lại endpoint
reject-theo-step có đúng `/reject` không.

## Bug mất banner "đã từ chối" sau khi Hủy đề xuất — báo cáo 2026-08-09, ĐÃ SỬA (FE) + có phần cần báo BE

User test Manager: tạo đề xuất ghi khoản chi 500k → bấm "Hủy đề xuất" → tin
nhắn đó đổi từ thẻ `ACTION_CARD` (có banner "Bạn đã từ chối đề xuất này")
sang một thẻ "Phân tích tài chính" (`INSIGHT_CARD`) hoàn toàn chung chung,
nội dung chữ vẫn y hệt lúc CHƯA xử lý ("xin vui lòng xác nhận trên ứng
dụng") — nhìn như đề xuất chưa hề bị hủy, dù bấm hủy có tác dụng thật ở BE
(verify riêng: nhiệm vụ "Đưa con đi chợ" bị hủy trước đó vẫn hiện đúng "Đã
hủy" trong danh sách nhiệm vụ thật).

Nguyên nhân xác định qua code: khi `fetchMessages()` chạy lại sau
`rejectAction`, BE trả về CHÍNH tin nhắn đó với `uiHints.displayStyle` đổi
thành `INSIGHT_CARD` (không còn `ACTION_CARD` như lúc khởi tạo), trong khi
`pendingAction.status` vẫn có giá trị thật (`REJECTED`). `effectiveDisplayStyle`
cũ ưu tiên `uiHints.displayStyle` tuyệt đối nên vẽ theo `INSIGHT_CARD`, bỏ
qua hẳn banner kết quả.

**Đã sửa ở FE**: `AiMessage.effectiveDisplayStyle` — khi `pendingAction` đã
có kết quả (không còn `PENDING`, tức `REJECTED`/`CONFIRMED`/`EXPIRED`/
`FAILED`), LUÔN vẽ `actionCard` để hiện đúng banner kết quả, bất kể
`uiHints.displayStyle` nói gì. Vẫn quyết định theo dữ liệu cấu trúc
(`pendingAction.status`), không đoán qua `content`, nên không vi phạm yêu
cầu BE "không đoán qua content". Còn `PENDING` thì hành vi cũ giữ nguyên
(tôn trọng `uiHints` như thường). Thêm 3 test khóa hành vi này trong
`test/ai_ui_hints_test.dart`.

**[Cần báo BE]** Vẫn nên hỏi BE vì sao sau khi resolve một đề xuất
(confirm/reject), response tiếp theo cho tin nhắn đó lại đổi
`uiHints.displayStyle` sang kiểu khác (mất ý nghĩa ban đầu) mà KHÔNG cập
nhật lại nội dung `content` cho khớp trạng thái mới (vẫn nói "xin xác nhận"
dù đã xử lý xong) — FE đã tự vá ở lớp hiển thị, nhưng nội dung chữ do BE
sinh ra bên trong card vẫn có thể gây hiểu lầm nếu nơi khác hiển thị `content`
thô (ví dụ preview thông báo/lịch sử ngoài màn chat).

Verify: `flutter analyze` 0 error, `flutter test` 293/293 pass (thêm 3 test
mới). Chưa verify runtime.

## Bug màn Trợ lý AI load trắng giữa chừng — báo cáo 2026-08-09, ĐÃ SỬA

User báo: mở Trợ lý AI, thấy Daily Brief đàng hoàng, sau đó **màn trắng trơn
một lúc** rồi mới hiện đoạn chat thật — có lúc trắng luôn, phải bấm vào một
chip gợi ý mới hiện lại được nội dung.

Nguyên nhân: `AiChatbotProvider.bootstrap()` gọi `fetchDailyBrief()` kiểu
`unawaited` (không chờ) để không chặn hiển thị hội thoại nếu tính năng phụ
này lỗi/chậm. Nhưng vì không chờ, request này có thể **tự hoàn thành SAU
KHI** `bootstrap()` đã return và màn hình đã chạy xong `_scrollToBottom()`.
Daily Brief luôn là item đầu tiên của `ListView` — hoàn thành trễ nghĩa là
CHÈN THÊM một item cao ở phía TRÊN vị trí vừa cuộn tới, đẩy lệch toàn bộ nội
dung xuống dưới mà không có gì kéo lại scroll offset — màn hình đứng nhìn
vào đúng chỗ trống giữa hai layout cũ/mới cho tới khi người dùng tự thao tác
(gửi tin) kích hoạt `_scrollToBottom()` chạy lại và tự sửa.

Sửa: `fetchDailyBrief()` đã tự bắt lỗi bên trong (không throw, không treo
màn nếu lỗi/404) nên đợi cùng lúc với `fetchConversations()` qua
`Future.wait([...])` là an toàn — cả hai vẫn chạy song song như cũ, chỉ khác
là `bootstrap()` chờ đủ CẢ HAI xong rồi mới trả về, nên màn hình chỉ tính vị
trí cuộn đúng một lần, sau khi toàn bộ nội dung (kể cả Daily Brief) đã ổn
định.

Verify: `flutter analyze` 0 error, `flutter test` 290/290 pass. Chưa verify
runtime.

## Script test Member — 3 bug UX cuộn + 1 nghi vấn BE — 2026-08-08, ĐÃ SỬA 2/3 FE

Chạy script test 14 bước cho vai trò Member, phát hiện:

1. **[ĐÃ SỬA]** Bấm icon ☀️ hiện lại Daily Brief xong tự cuộn lên đầu trang —
   đúng ý "xem" nhưng UX bất tiện: xem xong lại phải tự kéo xuống mới về được
   đoạn chat đang dở, trong khi thoát màn/mở lại thì mặc định vẫn đứng ở
   cuối. Đổi thành **không đổi vị trí cuộn** khi bấm ☀️ — chỉ bỏ ẩn rồi báo
   bằng SnackBar ("Đã hiện lại... kéo lên đầu để xem"), người dùng tự kéo lên
   xem khi muốn.
2. **[ĐÃ SỬA]** Gửi tin nhắn đầu tiên từ màn trống (chưa có hội thoại) —
   thay vì tự nhảy xuống tin nhắn vừa trả lời thì đứng nguyên ở đầu trang,
   phải kéo xuống mới thấy. Nguyên nhân: gửi tin đầu tiên chuyển
   `_MessageList` từ `_EmptyStateSuggestions` (ListView riêng, KHÔNG gắn
   `_scrollCtrl`) sang `ListView.builder` thật (mới gắn `_scrollCtrl`) —
   `Future.delayed(80ms)` cũ có thể chạy đúng lúc controller chưa kịp gắn vào
   Scrollable mới nên `animateTo` không có tác dụng. Đổi
   `_scrollToBottom()`/mọi chỗ tương tự sang `addPostFrameCallback` (đợi đúng
   sau khi frame build/layout xong) thay vì đoán một mốc thời gian cố định.
3. **[Đã rút lại — không phải bug]** Từng nghi Member không thấy card "Tổng
   quan hôm nay" — kiểm tra lại 2026-08-09 thì Member ĐÃ thấy card bình
   thường (có thể lần trước do đúng ca hoàn thành trễ ở mục bug "load trắng"
   phía trên, chưa hẳn do BE). Không cần báo BE mục này nữa.
4. **[Xác nhận đúng thiết kế — không phải bug]** Member không tự tạo được
   nhiệm vụ cho chính mình qua AI (bị chặn quyền, PERMISSION_NOTICE) — user
   xác nhận 2026-08-09 đây ĐÚNG chủ ý: chỉ Manager/Deputy được giao việc,
   Member không tự giao được kể cả cho bản thân. Đã verify thêm:
   `task_management_screen.dart` (`_showAssignSheet` + `_GenerateAssignments`)
   lọc người nhận chỉ theo `isActive`, không lọc theo vai trò — Manager giao
   việc được cho Deputy đúng như kỳ vọng (và ngược lại, vì `canManageTasks`
   là quyền chung `isAdministrative`, không phân cấp trên/dưới nội bộ).

Verify: `flutter analyze` 0 error, `flutter test` 290/290 pass. Chưa verify
runtime.

## Daily Brief: xem lại sau khi đóng + sửa giờ thô + làm nổi bật tiêu đề nhóm — 2026-08-08, ĐÃ LÀM

User hỏi cách xem lại card "Tổng quan hôm nay" sau khi đã bấm X đóng (trước đó
chỉ có cách thoát hẳn màn Trợ lý AI rồi mở lại), và nhờ làm tiêu đề các nhóm
(Family/Scope/Task/Calendar...) trong `JsonReportView` nổi bật hơn.

1. **Xem lại sau khi đóng**: thêm `AiChatbotProvider.showDailyBrief()` — dùng
   lại dữ liệu đã có trong bộ nhớ (không gọi lại API nếu đã tải), chỉ bỏ cờ
   ẩn. Thêm icon ☀️ ở AppBar màn Trợ lý AI (chỉ hiện khi đang ẩn), bấm vào tự
   cuộn lên đầu vì card luôn là item đầu tiên của `ListView`.
2. **Giờ thô trong "Next Events"**: ảnh chụp cho thấy `startTime`/`endTime`
   hiện nguyên văn `2026-08-09T02:00:00.0Z` — `JsonReportView` có bộ nhận
   diện ngày riêng (`endsWith('at')`, `contains('date')`...) không khớp tên 2
   key này. Thêm nhận theo tên chứa `time` + theo HÌNH DẠNG chuỗi (ISO
   datetime, không phụ thuộc tên key — cùng cách đã áp dụng cho
   `formatAiPreviewValue`), định dạng đủ giờ:phút + đổi UTC sang giờ local.
   Tiện thể sửa luôn `_fmtDate` (dùng cho `deadline`/`periodStart`...) thiếu
   bước đổi sang local trước khi tách ngày — timestamp UTC gần nửa đêm có thể
   lệch ngày hiển thị so với giờ VN.
3. **Tiêu đề nhóm nổi bật**: đổi từ màu xám nhạt (`textSecondary`, cùng màu
   với nhãn field thường — nhìn không phân biệt được) sang màu hồng đậm
   (`primary600`) + gạch chân mảnh, đậm chữ hơn.

`JsonReportView` dùng chung cho nhiều report khác (budget-plan, goal
progress, non-essential-spending) — 2 thay đổi #2/#3 ảnh hưởng luôn các màn
đó, không chỉ Daily Brief, nhưng đều là cải thiện chung không đổi hành vi cũ
theo hướng xấu đi.

Verify: `flutter analyze` 0 error, `flutter test` 290/290 pass (không có test
riêng cho `JsonReportView` vì file này chưa từng có test, các hàm định dạng
là `static private`). Chưa verify runtime.

## Thiếu chỗ ghi thu/chi "thực tế" hàng tháng — báo cáo 2026-08-08, ĐÃ LÀM

User hỏi: nhìn màn Ví Member (`child_wallet_screen.dart`) thì Member ghi
thu/chi ở đâu? Rà lại toàn màn thì thấy Member chỉ có 3 việc: khai báo
**dự kiến** (một lần), "Xin tiền từ Trưởng/Phó nhóm", và xem lịch sử (bị chặn
403 với sổ quỹ chung) — **không có chỗ nào ghi số đã thu/chi thực tế**, nên
"Đã tiêu tháng này" luôn là 0đ.

Đối chiếu `family-care-api.json`: BE **đã có sẵn** `actualIncome`,
`actualPersonalExpense`, `actualSharedContribution` trong cùng
`CreateMemberMonthlyFinanceDto`/`UpdateMemberMonthlyFinanceDto` mà FE đang
dùng cho "dự kiến" (`POST`/`PUT .../finance/monthly-finances/me`).
`FinanceProvider.upsertMonthlyFinance()` (`lib/providers/finance_provider.dart:1517`)
**đã nhận đủ 3 tham số này từ trước** — chỉ riêng
`edit_profile_screen.dart` chưa từng có ô nhập cho chúng. Đây không phải BE
thiếu, mà là FE chưa làm nốt UI cho field BE đã hỗ trợ.

Đã thêm 3 ô "thực tế" đi kèm ngay sau mỗi ô "dự kiến" tương ứng (Thu nhập /
Chi tiêu cá nhân / Đóng góp chung) trong `edit_profile_screen.dart`, dùng
chung nút "Lưu tài chính tháng" hiện có — không cần route/API mới. Ghi chú
trong banner: có thể cập nhật lại số "thực tế" bất cứ lúc nào trong tháng.

Verify: `flutter analyze` 0 error, `flutter test` 290/290 pass. Chưa verify
runtime — nhờ user tự test: Hồ sơ → Tài chính tháng → nhập số "thực tế" →
Lưu → quay lại Ví xem "Đã tiêu tháng này" có đúng số vừa nhập không.

## Bug checklist "Bắt đầu tháng" không tự tick sau khi khai báo — báo cáo 2026-08-08, ĐÃ SỬA

User (Member) khai báo thu nhập/hạn mức ở "Chỉnh sửa hồ sơ" → bấm "Lưu tài
chính tháng" → quay lại màn Ví. Số liệu "Hạn mức tháng" đã đúng (lấy dữ liệu
mới), nhưng mục "Khai báo thu nhập & hạn mức" trong `MonthStartChecklist`
(`lib/widgets/month_start_checklist.dart`) vẫn hiện chưa tick (vòng tròn
rỗng), như thể chưa khai báo gì.

Nguyên nhân: mục này điều hướng bằng `context.push('/profile/edit')`.
go_router `push` KHÔNG dispose lại `_MonthStartChecklistState` của màn Ví khi
pop về — `_load()` (gọi `fetchMonthlyFinanceFor` để tính `_declared`) chỉ chạy
đúng 1 lần ở `initState`, không có gì kích hoạt chạy lại sau khi quay về từ
màn khai báo. Đây là bug FE thuần túy, không liên quan BE.

Sửa: đổi `onTap` của mục này thành `async`, `await context.push(...)` rồi gọi
lại `_load()` ngay khi quay về (path chỉ có đúng 1 nơi gọi
`/profile/edit` từ widget này, không cần `RouteObserver` phức tạp). Áp dụng
chung cho cả màn Ví Member (`child_wallet_screen.dart`) và Manager
(`wallet_screen.dart`) vì dùng chung 1 widget `MonthStartChecklist`.

Verify: `flutter analyze` 0 error, `flutter test` 290/290 pass. Chưa verify
runtime — nhờ user tự test lại đúng luồng: từ màn Ví bấm vào mục "Khai báo
thu nhập & hạn mức" → sửa số → Lưu → quay lại xem có tự tick "Đã khai báo"
ngay không.

## Snapshot hiện hành 2026-08-08 — Trợ lý AI render theo `uiHints` (BE Sprint 2)

> Snapshot này mới hơn toàn bộ phần 2026-08-07 bên dưới. Khi có mâu thuẫn,
> dùng trạng thái ở đây và source hiện tại.

### BE nâng cấp AI Chatbot lên Sprint 2 — đổi cách render, không đổi endpoint

BE gửi contract mới: mỗi `aiMessage` giờ có thêm khối `uiHints` chỉ định RÕ
cách hiển thị (`displayStyle`), thay cho việc FE tự đoán qua `actionType`/chữ
trong `content` như trước. Quy tắc BE nhắc đi nhắc lại: **không được đoán qua
nội dung chữ** — mọi quyết định render phải dựa vào `uiHints` và
`pendingAction` (cấu trúc). Cùng một màn `AIAssistantScreen`, cùng endpoint
gửi/confirm/reject — chỉ đổi phần hiển thị.

5 `displayStyle`: `TEXT` (bubble chữ như cũ), `INSIGHT_CARD` (phân tích/gợi ý,
có quick-action chip), `ACTION_CARD` (thẻ xác nhận — thay `_PendingActionCard`
cũ), `PERMISSION_NOTICE` (không đủ quyền, không nút), `RESULT_CARD` (kết quả
sau khi confirm).

**Tương thích ngược:** tin nhắn cũ (trước Sprint 2, hoặc BE tạm không gửi
`uiHints`) suy `effectiveDisplayStyle` theo CẤU TRÚC đã có sẵn — có
`pendingAction` → `actionCard`, không có → `text`. Đúng hành vi cũ 100%, không
đoán qua `content`.

**Model** (`lib/models/ai_chatbot.dart`): thêm `AiDisplayStyle`,
`AiQuickAction`, `AiMessageUiHints`, `AiActionField`, `AiActionUiHints`,
`AiDailyBrief`. `AiMessage` thêm `uiHints` + `effectiveDisplayStyle`.
`AiPendingAction` thêm `uiHints` + `displayTitle` + `displayFields` (ưu tiên
`uiHints.fields`, rơi về `preview` cũ khi rỗng/thiếu). Toàn bộ API cũ
(`actionLabel`, `isPending`, `outcome`, `preview`, `messageId`, `status`,
`confirmedActionTypes`, `confirmedStatuses`) **giữ nguyên không đổi** — đã
verify bằng cách chạy lại nguyên vẹn 2 file test của Giáp
(`ai_pending_action_mapping_test.dart`) và 4 file test cũ của mình, không sửa
dòng nào trong đó.

**UI** (`lib/screens/shared/ai_assistant_screen.dart`): `_MessageBubble` switch
theo `effectiveDisplayStyle` ra 5 widget con (`_TextBubble`, `_InsightCard`,
`_ActionCardWithIntro` + `_PendingActionCard`, `_PermissionNoticeCard`,
`_ResultCard`). Logic chọn field/nhãn theo `actionType` (`_previewRows`,
`_label` cũ) đã dời nguyên vẹn vào model (`AiPendingAction._fieldsFromLegacyPreview`),
không đổi nội dung bảng nhãn. `_QuickActionChips` dùng chung cho mọi style có
`uiHints.quickActions`, bấm gửi `prompt` (không gửi `label`).

**Daily Brief** (tùy chọn, BE nói "FE không bắt buộc làm ngay"): thêm
`AiChatbotProvider.fetchDailyBrief()` gọi
`GET /families/{id}/ai-chatbot/daily-brief`, lỗi/404 thì bỏ qua lặng lẽ
(không set `_error`, không che khung chat chính). BE không cho tên field con
cụ thể (task/calendar/finance/insights) nên render `raw` qua `JsonReportView`
có sẵn — đúng quy ước repo cho response chưa rõ schema (CLAUDE.md Rule 4),
không đoán tên field. `suggestedPrompts` tách riêng thành chip vì BE có nói rõ
hình dạng.

**[VERIFY chưa làm]** Nút "Sửa" (`editActionLabel`) — BE cho nhãn nhưng KHÔNG
nói cơ chế/endpoint. Tạm xử lý: bấm nút gọi `rejectAction` (endpoint đã có),
chưa tự điền lại composer. Đây là suy luận tạm, cần hỏi lại BE nếu sai — xem
comment tại `_PendingActionCard._handleEdit`.

### Bug lệch giờ + xóa hội thoại — báo cáo từ user 2026-08-08, đã xử lý 1/2

Kèm 2 bug user báo bằng ảnh chụp thật, không liên quan Sprint 2:

1. **Lịch sử ví lộn xộn khi có nhiều lần chia quỹ khác nhau** — ĐÃ SỬA. Nguyên
   nhân: `WalletProvider._entries` không hề sort, thứ tự phụ thuộc hoàn toàn
   BE trả về; các entry chia quỹ cùng `entryDate` (ngày cuối kỳ) nhưng khác
   lần tạo bị xen kẽ lộn xộn. BE có field `createdAt` riêng (khác `entryDate`)
   mà FE chưa từng đọc. Đã thêm `LedgerEntry.createdAt` + sort `_entries` theo
   `createdAt` giảm dần (dùng `createdAt`, rơi về `entryDate` nếu thiếu).
2. **Xóa hội thoại AI xong quay lại vẫn còn thấy, màn hình "nhảy liên tục"** —
   **chỉ sửa được nửa vế đầu, KHÔNG suy đoán tiếp vế sau vì thiếu bằng
   chứng.** `deleteCurrentConversation()` giờ xóa ngay khỏi `_conversations`
   trong RAM (không đợi refetch) và lọc cứng id vừa xóa khỏi ĐÚNG một lần
   `fetchConversations` kế tiếp — phòng ca hợp lý nhất không cần giả lập lại
   được: `DELETE` trả 200 nhưng `GET` danh sách ngay sau đó đọc dữ liệu chưa
   kịp đồng bộ. **"Màn hình nhảy liên tục" CHƯA chẩn đoán được** — không đủ
   bằng chứng để sửa mà không đoán mò (có thể là mở màn AI hai lần liên tiếp
   tạo hai `_AIAssistantScreenState` cùng gọi `bootstrap()` trên một provider
   dùng chung, có thể là nguyên nhân khác). Cần user mô tả rõ hơn "nhảy" là gì
   (chuyển màn, giật hình, cuộn nhảy vị trí?) hoặc quay video khi tái hiện
   được, vì từ giờ chị không tự mở emulator kiểm tra nữa.

### Bug overflow Daily Brief — báo cáo từ user 2026-08-08, ĐÃ SỬA

User gửi ảnh chụp `RenderFlex overflowed by 993 pixels` ngay trên card "Tổng
quan hôm nay" vừa thêm ở trên. Nguyên nhân: `_MessageList.build()` bọc danh
sách tin nhắn trong `Column` với `_DailyBriefCard` là con **không co giãn**
(non-flex) nằm cố định phía trên `Expanded(child: <danh sách cuộn>)`. Dữ liệu
Daily Brief thật từ BE (nhóm Family/Scope/Task/Calendar/Finance qua
`JsonReportView`) cao hơn nhiều so với chỗ còn lại, mà `Column` không thể co
nhỏ một con non-flex lại — tràn layout. `_EmptyStateSuggestions` không dính
lỗi này vì đã render trong `ListView` sẵn.

Sửa: bỏ hẳn khung `Column`/`Expanded` trong `_MessageList`, đưa
`_DailyBriefCard` thành phần tử đầu tiên (index 0) của chính
`ListView.builder` — cùng kiểu "leading item" đã dùng cho `_LoadMoreTile`
(biến đếm `leadingBrief`/`leadingLoadMore`/`leading`). Card giờ cuộn được
cùng danh sách tin nhắn thay vì chiếm không gian cố định. Sửa null-check tại
điểm gọi `_DailyBriefCard(brief: brief, ...)` từ `if (leadingBrief == 1 && i
== 0)` sang `if (brief != null && i == 0)` để Dart tự promote `brief` về
non-null (check `leadingBrief` — một biến int khác dẫn xuất từ `brief` — không
đủ để analyzer suy ra `brief` non-null tại điểm dùng).

Verify: `flutter analyze` (0 error, kể cả file này) + `flutter test`
(289/289 pass, không có test riêng cho path overflow này vì đây là lỗi layout
runtime, không phải logic parse — đúng theo quy trình mới, chưa mở emulator
kiểm tra lại bằng mắt, nhờ user tự xác nhận card cuộn mượt, không tràn nữa).

### Bug UX mở màn AI luôn đứng ở đầu (Daily Brief) — báo cáo từ user 2026-08-08, ĐÃ SỬA

User báo: bấm vào Trợ lý AI thì màn luôn dừng ở đầu danh sách (card "Tổng quan
hôm nay" chiếm hết màn hình), phải tự kéo xuống mới thấy đoạn chat đang dở —
trong khi kỳ vọng mở lên phải thấy ngay tin nhắn gần nhất như mọi app chat
khác. Nguyên nhân: `_scrollToBottom()` trước đó chỉ được gọi sau khi TỰ gửi
tin nhắn mới (`_send()`), không được gọi sau khi `bootstrap()` tải xong hội
thoại có sẵn, cũng không gọi sau khi chọn hội thoại khác từ danh sách — nên
`ListView` đứng nguyên ở vị trí mặc định (item 0 = Daily Brief nếu có).

Sửa: gọi `_scrollToBottom()` thêm ở 2 chỗ — (1) ngay sau khi `bootstrap()`
trong `initState` tải xong hội thoại gần nhất, (2) ngay sau khi chọn một hội
thoại khác từ bottom sheet "Hội thoại AI". Card Daily Brief vẫn còn đó (kéo
lên là thấy), chỉ đổi vị trí cuộn mặc định về cuối — giống hành vi chat bình
thường.

Verify: `flutter analyze` 0 error, `flutter test` 289/289 pass. Chưa xác nhận
runtime — nhờ user tự test lại bước "mở Trợ lý AI" và "chuyển hội thoại từ
danh sách" xem có nhảy thẳng xuống tin nhắn gần nhất không.

### 4 bug UX/UI từ ảnh chụp test thật — báo cáo từ user 2026-08-08, ĐÃ SỬA

User gửi 18 ảnh chụp test thật (Manager) + 4 yêu cầu cụ thể:

1. **Bấm Xác nhận/Hủy đề xuất thì đoạn chat nhảy lên đầu trang** — ĐÃ SỬA.
   Nguyên nhân: `_MessageList.build()` có `if (ai.loadingMessages) return
   Center(...)` KHÔNG loại trừ trường hợp đã có `messages`. `_handleAction`
   (confirm/reject) gọi `fetchMessages()` để làm mới trạng thái, hàm này bật
   `loadingMessages = true` trong lúc chờ — mỗi lần bấm nút, `ListView.builder`
   bị thay hẳn bằng `Center` rồi dựng lại **mất luôn vị trí cuộn cũ**. Sửa
   thành chỉ chặn cả màn bằng spinner khi `messages.isEmpty` (tải lần đầu
   thật sự), còn lại giữ nguyên `ListView` khi làm mới.
2. **Ví dụ "tạo khoản chi" luôn set cứng 200.000đ tiền ăn uống** — ĐÃ SỬA.
   Đây không phải AI tự chọn số tiền — là câu gợi ý mẫu (quick prompt) FE
   hard-code y hệt ở 2 chỗ (`aiPromptGroupsFor` nhóm "Nhờ AI tạo" + chip
   "Tạo thu/chi" dưới composer), bấm hoài ra đúng một khoản. Đổi thành random
   1 trong 6 mẫu chi tiêu khác nhau (số tiền + danh mục khác nhau) mỗi lần
   dựng widget — `_randomExpensePrompt()`.
3. **Chữ `**in đậm**` hiện nguyên cặp dấu `**` xấu** — ĐÃ SỬA. BE trả nguyên
   văn markdown để nhấn tiêu đề (`**Nhận định:**`, `**Đề xuất:**`...) nhưng
   FE vẽ bằng `Text` trơn nên hiện cả dấu sao. Thêm `_AiRichText` (regex tối
   thiểu, không kéo thư viện markdown) — phần giữa `**...**` in đậm + tô màu
   theo ngữ cảnh (chip primary cho bong bóng chữ, màu icon card cho insight/
   permission/result). Áp dụng ở cả 4 nơi hiện `content` thô: `_TextBubble`,
   `_InsightCard`, `_PermissionNoticeCard`, `_ResultCard`.
4. **Phát hiện thêm khi rà ảnh (không nằm trong 3 yêu cầu trên nhưng cùng
   nhóm UX)**: field "Bắt đầu"/"Kết thúc" của thẻ tạo sự kiện lịch hiện
   nguyên văn `2026-08-09T09:00:00+07:00` thay vì giờ đọc được — ĐÃ SỬA.
   `uiHints.fields` (Sprint 2) dùng key tự do do BE đặt, không khớp bộ khóa
   cứng của `_isTimeKey` (`startTime`/`endTime`...). Thêm nhận diện theo HÌNH
   DẠNG giá trị (chuỗi khớp `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}`) bất kể tên key —
   an toàn vì tiêu đề/địa điểm dạng chữ không khớp định dạng này nên không bị
   format nhầm. Thêm test trong `ai_pending_action_contract_test.dart`.

**[Cần báo BE — chưa/không thể sửa ở FE]**
- Ảnh lúc 10:28 (nhờ Manager "Ghi nhận khoản chi 200000 cho ăn uống hôm nay"):
  AI trả lời dạng thẻ "Phân tích tài chính" với nội dung "Tôi đã tạo đề xuất
  ghi nhận khoản chi... Xin vui lòng xác nhận trên ứng dụng để hoàn tất!"
  nhưng **không kèm `pendingAction`** — không có nút nào để bấm, y hệt lỗi đã
  từng báo cho trường hợp Thành viên (2026-08-07), nay xảy ra cả với Manager
  có đủ quyền. Cần BE xác nhận vì sao AI hứa "xác nhận trên ứng dụng" mà
  không gửi kèm `pendingAction`.
- Ảnh 22:12 xuất hiện `actionType` mới `CREATE_BUDGET_PLAN` (thẻ "Tạo kế
  hoạch ngân sách") — chưa nằm trong 3 loại đã chốt trước đó
  (`CREATE_TASK`/`CREATE_LEDGER_ENTRY`/`CREATE_CALENDAR_EVENT`). Card vẫn
  hiển thị đúng nhờ đọc `uiHints.fields` (không phụ thuộc bảng cứng), nhưng
  FE chưa biết refresh màn nào tương ứng sau khi xác nhận (hiện rơi vào
  nhánh "actionType lạ → refresh cả Task+Wallet+Calendar" mang tính phòng
  thủ, không có màn "Kế hoạch ngân sách" nào được refresh riêng). Cần BE xác
  nhận đây có phải actionType chính thức mới không, và có màn/API tương ứng
  nào ở FE cần biết để refresh.
- Quan sát chưa chắc chắn, CHƯA sửa vì không đủ bằng chứng lặp lại: một tin
  nhắn người dùng hiện dạng "phân tích tài chínhphân tích tài chính" (dính
  liền, không dấu cách) trong 1 bong bóng chat — nghi do bấm rất nhanh 2 lần
  liên tiếp vào cùng một chip gợi ý trong lúc `sending` chưa kịp bật, nhưng
  chưa tái hiện lại được để chẩn đoán chắc chắn. Em gặp lại thì mô tả rõ thao
  tác bấm (đơn/đúp) giúp chị.

Verify: `flutter analyze` 0 error. `flutter test` 290/290 pass (thêm 1 test
mới cho fix #4 ở `ai_pending_action_contract_test.dart`). Chưa verify runtime
bất kỳ ý nào — nhờ user tự test lại theo script mới gửi kèm.

### Quy trình mới từ 2026-08-08

Chị (Claude) chỉ code + fix, KHÔNG tự mở emulator thao tác kiểm tra nữa (tốn
quota/thời gian). Người dùng tự test runtime. Verify trong phiên này chỉ có
`flutter analyze` (0 error/warning) + `flutter test` (289/289 pass, tăng từ
265 nhờ 24 test mới: `ai_ui_hints_test.dart` 20 test, `ai_daily_brief_test.dart`
4 test) — **chưa verify runtime cho bất kỳ thay đổi nào trong snapshot này**,
người dùng cần tự test theo checklist BE đã gửi (10 mục, đặc biệt #1 chat
thường, #2 insight card, #4-6 action card 3 loại, #7 permission notice, #9
không đoán content, #10 reload lịch sử vẫn giữ pendingAction) cộng 2 bug lệch
giờ/xóa hội thoại ở trên.

## Snapshot 2026-08-07 — Trợ lý AI hoàn chỉnh, vá rò rỉ dữ liệu giữa hai tài khoản, đã merge lên main

### Trạng thái Git chốt cuối ngày

- **`NDuy` = `main` = `origin/NDuy` = `origin/main` = `9dda7be`.** Đã merge
  fast-forward, không có merge commit thừa, `git diff main NDuy` rỗng hoàn toàn.
- `origin/giap` còn ở `0a41e32`, **đi sau main 9 commit**. Cần báo Giáp
  `git merge origin/main` sớm: 9 commit này chạm `lib/services/api_client.dart`
  và **17 file provider**, để lâu là conflict dồn.
- Mốc cứu hộ: tag `backup/main-before-merge-20260807` trỏ `0a41e32`; nhánh
  `backup/ai-before-reword-20260807` giữ bản trước khi viết lại lời commit.
- Đã verify 5 commit của Giáp còn nguyên trong main bằng `merge-base
  --is-ancestor` (nén logo, SOS qua wearable event, ngắt kết nối thiết bị đeo,
  test mapping).

### 9 commit của phiên này (đã lên main)

```
9dda7be  docs(bàn giao): chốt trạng thái phiên Trợ lý AI và rò rỉ dữ liệu
b77d7e2  fix(bảo mật): dọn nốt 17 provider còn giữ dữ liệu tài khoản cũ
e5aeb22  feat(trợ lý AI): tải thêm hội thoại và tin nhắn cũ
57c5f8c  fix(trợ lý AI): đỡ đúng hình dạng response BE mô tả
92cea20  feat(trợ lý AI): gợi ý câu hỏi theo vai trò + nhóm mô hình tài chính
7c58bfa  fix(bảo mật): dọn dữ liệu phiên cũ khi đổi tài khoản
46c12fe  chore(tài liệu): bỏ file báo cáo BE khỏi repo
932c63b  fix(trợ lý AI): thẻ đề xuất phân biệt đã thực hiện / từ chối / hết hạn
f4b37bb  fix(trợ lý AI): định dạng tiền và giờ, sửa 403/409/410, reload đúng tháng
```

Lưu ý quy trình: **không commit tài liệu báo cáo BE vào repo nữa** (đã gỡ
`BAO_CAO_BE_AI_CHATBOT_2026-08-07.md` ở `46c12fe`). Nội dung gửi BE để trong
tin nhắn, chỉ tóm tắt lại trong tài liệu bàn giao này.

### 12 commit kéo từ main về đầu phiên (việc của Giáp)

- `2171854` — thiết bị đeo: đủ 5 loại sự kiện cảm biến, nối lại 2 màn đồng hồ bị
  mất lối vào.
- `2057edd` — thiết bị đeo: tin nhắn nhanh sửa được, vá provider thiếu ở
  entrypoint đồng hồ.
- `883a81b` — SOS: tự tạo cảnh báo khi điện thoại phát hiện té ngã.
- `ef28135` — khuôn mặt: khôi phục 3 lệch schema `face-suggestions` bị merge ghi
  đè trước đó.
- `c52f62b` — tài chính: xem và thao tác theo kỳ tháng, không còn kẹt ở tháng
  hiện tại.
- `e9532cf` — thiết bị đeo: ghép nối theo contract mới, một tài khoản một thiết bị.
- `7b9605f`, `e580b97` — hoàn thiện giao diện Wear OS và SOS gửi từ đồng hồ.
- `8e574d5` — Android: thêm biểu tượng tròn cho launcher.
- `bc624b2` — docs: thêm `CLAUDE.md`, bản dump Swagger mới, phân tích tiến trình FE.
- `13ea351`, `f947469` — các commit đồng bộ main ↔ giap.

Tổng: 54 file, +6741 / −1809 dòng. File mới đáng chú ý:
`lib/services/fall_detector_service.dart`, `lib/services/sos_location.dart`,
`lib/models/finance_period.dart`, `lib/widgets/month_switcher.dart`,
`lib/widgets/month_start_checklist.dart`, `lib/widgets/fall_countdown_dialog.dart`,
`lib/providers/wear_quick_message_provider.dart`, `lib/wear/wear_root.dart`,
`lib/wear/wear_widgets.dart` cùng 5 màn Wear mới (calendar, map, notifications,
quick message, tasks).

### Verification cuối phiên (chạy trên đúng cây đã lên main)

- `flutter analyze --no-fatal-infos`: **0 error, 0 warning**, còn đúng 20
  info-lint có sẵn từ trước — không phát sinh mới.
- `flutter test`: **252/252 PASS** (đầu phiên 160). 6 bộ test mới của phiên này:
  `ai_feature_access_test`, `ai_pending_action_contract_test`,
  `ai_send_response_test`, `ai_prompt_role_test`, `ai_pagination_test`,
  `ai_session_reset_test`, `session_reset_registered_test`.
- Lưu ý khi format: **đừng chạy `dart format lib/providers/`** trên cả thư mục.
  Một số file (nhất là `chat_provider.dart`) chưa theo style hiện hành, format
  cả thư mục sinh ra 200+ dòng nhiễu không liên quan. Chỉ format file mình sửa.

### 🔴 Rò rỉ dữ liệu giữa hai tài khoản — nghiêm trọng nhất phiên này

Phát hiện khi chạy thật, không đọc code nào ra được.

**Tái hiện:** đăng nhập Trưởng nhóm → chat AI về tài chính → đăng xuất → đăng
nhập Thành viên trên cùng máy → mở Trợ lý AI → **hiện nguyên hội thoại của
Trưởng nhóm**, gồm số liệu chi tiêu và sự kiện lịch.

**Backend KHÔNG sai.** Danh sách hội thoại trả về cho Thành viên là **rỗng**,
đúng như Swagger mô tả. Rò rỉ hoàn toàn ở app: 21 provider khai ở app scope
trong `main.dart` sống suốt vòng đời ứng dụng, còn `logout()` chỉ xóa token và
thông tin đăng nhập, không đụng dữ liệu provider đang giữ trong RAM.

**Cách sửa:** `ApiClient.clearSession()` là điểm nghẽn duy nhất của cả ba đường
kết thúc phiên (bấm đăng xuất, phiên hết hạn, bị buộc đăng xuất khi 401). Thêm
danh sách listener ở cấp static, `clearSession` gọi hết khi chạy. Danh sách cố
tình **không** bị `clearSession` xóa — provider đăng ký một lần lúc khởi tạo,
phải còn hiệu lực cho mọi lần đăng xuất sau. Một listener ném lỗi không chặn các
listener còn lại.

**18 provider** đã có `resetForNewSession()` và tự đăng ký trong constructor.
Ba cái có tài nguyên sống được xử lý riêng, không chỉ xóa field:

- `NotificationProvider` gọi `stopRealtime()` ngắt socket trước — giữ kết nối
  của tài khoản cũ thì tài khoản mới nhận thông báo không phải của mình.
- `ChatProvider` dùng lại `clear()` sẵn có, hàm này dừng luôn timer polling.
- `SosProvider` xóa cả cảnh báo, danh bạ khẩn cấp và cài đặt.

**Cố ý KHÔNG dọn 4 cái:** `AuthProvider` (chính nó quản phiên), và
`ThemeModeController` / `TabConfigProvider` / `WearQuickMessageProvider` — tùy
chọn giao diện của **máy**, không phải dữ liệu gia đình, đổi tài khoản vẫn giữ
là đúng mong đợi.

Test canh gác `test/session_reset_registered_test.dart` quét `main.dart`, đối
chiếu từng provider với file nguồn, đỏ ngay nếu thiếu đăng ký hoặc thiếu hàm
reset. Thêm provider mới mà quên dọn là biết liền.

### Trợ lý AI — 8 lỗi FE đã sửa trong ngày

- **Sai tên feature key (lỗi im lặng).** `FeatureAccess` đọc `ai.enabled` và
  `ai.chatbot`; cả hai KHÔNG nằm trong 26 key chính thức BE khai ở
  `CreateSubscriptionPlanDto.featureAccess`. `flag()` trả `false` cả khi key
  không tồn tại, nên dòng "Tính năng AI" và "Trợ lý AI" ở màn Gói đăng ký không
  bao giờ hiện, kể cả gói trả phí. Đã đổi sang `ai.assistant` (giữ tên cũ làm
  alias cho plan chưa migrate) và thêm `officialKeys` + `officialKeyLabels` để
  màn Gói đăng ký duyệt đúng 26 key thay vì liệt kê tay. Bốn key FE tự bịa khác
  cũng bị bỏ cùng lúc: `finance.advanced`, `reports.advanced`, `sos.enabled`,
  `storage.unlimited`, `families.max`.
- **Gate theo gói.** `AiChatbotProvider.bootstrap()` nay gọi
  `fetchFeatureAccess()` trước; biết chắc gói không có `ai.assistant` thì dừng,
  không gọi endpoint nào và hiện `_UpgradePanel` (nút "Xem gói đăng ký" chỉ hiện
  với Manager theo `AppUser.canManageSubscription`). Vẫn **fail-open** khi BE trả
  `featureAccess` rỗng, theo đúng convention đã ghi trong `feature_access.dart`.
- **Gợi ý câu hỏi, chia theo vai trò.** Màn rỗng trước đây chỉ có hai dòng chữ,
  người dùng không biết hỏi gì nên phần hỏi đáp gần như không ai dùng dù đã chạy
  được từ lâu. Nay là bảng gợi ý, và **phân nhánh theo `AppUser.canManageFinance`**
  (đúng với Trưởng nhóm + Phó nhóm):
  - Quản lý: 4 nhóm — tra cứu tài chính, **mô hình tài chính & ngân sách** (mô
    hình đang áp dụng, hũ vượt mục tiêu, ngân sách còn lại, đã chia quỹ chưa),
    tra cứu nhiệm vụ & lịch, và nhờ AI tạo.
  - Thành viên: 3 nhóm đúng phạm vi — việc của tôi, chi tiêu của tôi, lịch gia
    đình. **Không có nhóm "Nhờ AI tạo"**, vì Thành viên không có quyền
    `canManageFinance` / `canManageTasks` / `canManageCalendar`; mời họ làm là
    dẫn thẳng vào ngõ cụt của BE (xem mục "Cần báo BE" #1). Có thêm dòng giải
    thích để họ không tưởng app lỗi.
  - Mọi câu của Thành viên dùng ngôi "tôi" thay vì "nhà mình" — giảm bớt lỗi
    đại từ trong câu trả lời của AI (mục "Cần báo BE" #6).
  - Dải chip ngang cũng đổi theo vai trò, chỉ hiện khi hội thoại đã có tin nhắn.
  - Danh sách tách ra hàm top-level `aiPromptGroupsFor()` để khóa được bằng test.

- **`preview` in dữ liệu thô ra cho người dùng đối chiếu.** `preview` là thứ
  DUY NHẤT người dùng nhìn trước khi bấm xác nhận, nhưng đang in nguyên value:
  người nói "9h sáng mai" mà thẻ hiện `2026-08-08T02:00:00.000Z` (lệch 7 tiếng,
  không đọc nổi), tiền hiện `200000` không dấu phân cách. Nay có
  `formatAiPreviewValue`: giờ → `09:00 08/08/2026` theo giờ máy, tiền →
  `200.000 ₫`, object lồng lấy `name`/`title`, null và mảng rỗng thành dấu gạch.

- **`403` lúc xác nhận báo sai nguyên nhân.** BE nói rõ 403 ở `confirm-action`
  nghĩa là **vai trò** không được phép tạo, nhưng FE dùng chung câu với 403 lúc
  chat nên hiện "Bạn chưa có quyền dùng Trợ lý AI trong gói hiện tại" — Thành
  viên bị từ chối lại tưởng phải đi nâng gói. Đã tách theo ngữ cảnh bằng cờ
  `isAction`.

- **Thẻ kẹt ở "Chờ xác nhận" sau `409`/`410`.** Hai mã này đều nghĩa là trạng
  thái thật ở server đã khác cái FE đang vẽ, nhưng FE chỉ hiện lỗi mà không tải
  lại, nên bấm mãi cũng ra đúng lỗi đó. Nay tự `fetchMessages()`.

- **Reload lịch sai tháng.** `CalendarProvider.fetchEvents` chỉ tải đúng MỘT
  tháng, FE lại luôn truyền tháng hiện tại — sự kiện "9h sáng mai" vào ngày cuối
  tháng đã sang tháng sau, xác nhận xong mở lịch không thấy gì. Nay
  `calendarMonthToReload()` lấy tháng từ `startTime` trong preview.

- **Xác nhận thành công vẫn hiện cảnh báo đỏ.** Giao dịch đã vào sổ, quỹ đã trừ,
  mà thẻ hiện dòng đỏ "Đề xuất đã hết hạn hoặc đã được xử lý" — vì UI chỉ hỏi
  `isPending` rồi gộp mọi trạng thái kết thúc vào một câu. Nay có
  `AiActionOutcome` gồm `pending / completed / rejected / expired / failed`;
  Swagger chưa khai enum `status` nên mọi giá trị kết thúc không phải từ
  chối/hết hạn/lỗi đều coi là **đã thực hiện**, thay vì mặc định báo đỏ. Chỉ còn
  `PENDING` quá `expiresAt` mới là hết hạn thật.

- **Phân trang bị kẹt ở trang đầu.** Swagger khai `page`/`limit` cho hai endpoint
  GET nhưng FE cứng `page=1`: quá 20 hội thoại hoặc quá 50 tin nhắn là mất hẳn
  phần còn lại. Nay có `loadMoreConversations()` / `loadMoreMessages()` theo đúng
  pattern `fetchMoreEntries()` của `WalletProvider`, kèm hàng "Tải thêm". Gộp
  trang sau **theo id** thay vì nối mù; tin nhắn gộp xong sắp lại theo thời gian
  nên đúng dù BE trả mới-nhất-trước hay cũ-nhất-trước (Swagger không nói).


- **actionType lạ không còn hỏng im lặng.** Trước đây `switch` trong
  `_confirmAndReload` không có nhánh `default`: BE thêm loại mới thì người dùng
  bấm xác nhận, BE tạo dữ liệu thật, app không refresh gì — nhìn như không có
  chuyện gì xảy ra. Nay `AiPendingAction.isKnownActionType` phân biệt được, loại
  lạ thì refresh cả ba nguồn (task, ví, lịch, mỗi nguồn bọc try riêng để một lỗi
  không chặn hai nguồn kia) và hiện mã `actionType` thô ngay trên thẻ đề xuất.

### Đối chiếu contract BE — đã khớp đủ

BE chốt hỗ trợ 3 `actionType`: `CREATE_TASK`, `CREATE_LEDGER_ENTRY`,
`CREATE_CALENDAR_EVENT`. Đã soi từng dòng yêu cầu với code:

- **7/7 operation AI Chatbot trong Swagger đều đã gán**, hai chiều đều sạch:
  không endpoint nào bị bỏ quên, FE cũng không gọi endpoint AI nào ngoài Swagger.
  Ngoài 7 cái đó provider chỉ gọi thêm `GET /families/{id}/subscription` để gate
  theo gói.
- `ApiClient` bóc envelope `{success, data}`, nên `data['pendingAction']` đọc
  đúng tầng như ví dụ BE gửi.
- Reload sau confirm đúng yêu cầu: nhiệm vụ → `fetchTasks()`; giao dịch →
  `fetchWallets()` (kéo cả overview, summary, entries, jars, report); lịch →
  `fetchEvents()` theo tháng của `startTime`.
- Không tự tạo dữ liệu từ `preview` — `_confirmAndReload` chỉ gọi `fetch*`.
- **Lệch có chủ ý:** BE ghi nhãn "Xác nhận tạo **công việc**", FE dùng "Tạo
  **nhiệm vụ**" cho khớp từ ngữ toàn app (tab dưới, "Nhiệm vụ hôm nay"…).

Hai lỗ hổng phát hiện ở vòng đối chiếu cuối, đã sửa ở `57c5f8c`:

1. **Response chỉ có `pendingAction` thì thẻ bị nuốt mất.** Ví dụ trong contract
   của BE chứa đúng một khối `pendingAction`, không kèm `aiMessage`/`message`/
   `content`. Code cũ chỉ biết *gắn* đề xuất vào bong bóng có sẵn → rẽ hết nhánh
   rồi thoát, người dùng gửi tin xong màn hình trống trơn. Nay có nhánh cuối tự
   dựng bong bóng mang đề xuất.
2. **Lớp chống rò rỉ đặt sai chỗ** (do chính commit trước gây ra): phép kiểm nằm
   trong `fetchConversations()`, mà `sendMessage()` cũng gọi hàm đó — hội thoại
   vừa tạo chưa lọt vào 20 bản ghi đầu là **xóa sạch tin vừa gửi**. Đã chuyển
   sang `bootstrap()`.

### Kiểm thử runtime trên emulator (gia đình NDuy)

Chạy thật, không suy luận. Tài khoản Trưởng nhóm và Thành viên đều đã thử.

| Nhánh | Bằng chứng |
|---|---|
| Gate theo gói | BE trả **đủ 26 key chính thức**, `ai.assistant: true` |
| Hỏi đáp | AI trả đúng số liệu gia đình |
| `CREATE_LEDGER_ENTRY` | quỹ **50.000.000 → 49.800.000 đ** |
| `CREATE_TASK` | tạo + từ chối đều đúng |
| `CREATE_CALENDAR_EVENT` | thẻ hiện `09:00 08/08/2026`, có push "Sự kiện lịch mới" |
| Đổi tài khoản | sau fix: Thành viên thấy màn rỗng sạch, không còn dấu vết |
| Gợi ý theo vai trò | đã xem tận mắt cả hai vai trò |
| Ngắt socket khi đăng xuất | log `NotifSocket: disconnected`, không provider nào ném lỗi |

**✅ Câu hỏi bảo mật RBAC đã có đáp án — BE làm đúng, bỏ khỏi danh sách lo ngại.**
Cùng câu "Tháng này nhà mình đã chi bao nhiêu?": Trưởng nhóm nhận **200.000đ**,
Thành viên nhận **0đ**. AI scope theo quyền người hỏi, không có cửa sau vòng qua
phân quyền.

**Chưa test được:** `403` khi Thành viên xác nhận đề xuất (BE không phát thẻ cho
Thành viên — xem mục #1 dưới); `409`/`410` (không kích được từ UI, cần đợi hết
hạn hoặc thao tác phía server). Logic hai mã này đã có unit test phủ nhưng
**chưa xác minh runtime** — đừng ghi là đã test.

### ✅ BE đã trả lời đủ 6 mục (2026-08-07) — contract chốt

BE phản hồi bằng văn bản, đã ghi vào `API_DOCS.md` mục **AI Chatbot**. Tóm tắt
và việc FE phải làm:

| Mục | BE trả lời | FE phải làm |
|---|---|---|
| 1. Member ghi thu chi | Chọn hướng (b): sửa prompt để AI **không** nói "vui lòng xác nhận" khi không có `pendingAction`. `CREATE_LEDGER_ENTRY` chỉ mở cho `FAMILY_MANAGER` + `DEPUTY_MEMBER` | **Không** — FE đã ẩn sẵn gợi ý tạo dữ liệu với Thành viên |
| 2. Swagger thiếu schema | Đồng ý bổ sung response DTO cho cả 7 endpoint + khai enum `actionType` | **✅ BE đã ship** (bản dump 2026-08-07 có `AiActionType`, `AiActionStatus`, `AiPendingActionResponseDto`…). Đối chiếu lại thì bắt được bug thật: `AiConversationLastMessageResponseDto` dùng `messageContent` chứ không phải `content` — dòng xem trước hội thoại từng trống trơn. Đã sửa ở `746a83d` |
| 3. `status` chính thức | Đúng **4 giá trị**: `PENDING`, `CONFIRMED`, `REJECTED`, `EXPIRED`. **Chưa có `CANCELED`/`FAILED`** | Đã siết `AiPendingAction.confirmedStatuses` + test |
| 4. `expiresAt` | **Có, ISO UTC thật** (`Date.toISOString()`, đuôi `Z`), interceptor không convert timezone | **Không** — FE parse đúng sẵn, đã thêm test khẳng định |
| 5. Ba key AI phụ | Chỉ là **cờ điều khiển hành vi trong chatbot**, không phải endpoint riêng, BE cũng chưa guard | **Không gate theo ba key này**, chỉ đọc để hiển thị quyền lợi gói |
| 6. Đại từ trong câu trả lời | Đồng ý sửa: Member → "bạn", Manager/Deputy → "gia đình" | **Không** — thuộc prompt BE |

**Field mới BE nhắc tới:** sau confirm thành công, `result.id` là id bản ghi vừa
tạo. FE **hiện chưa parse** field này (không cần, vì đã refetch messages). Có thể
dùng sau để deep-link tới bản ghi vừa tạo — chưa làm, đừng tưởng là đã có.

**Còn nợ, chưa đổi:** `403`/`409`/`410` vẫn **chưa xác minh runtime**. Mục 1 và 2
phải chờ BE ship xong mới test lại được. Khi test lại mục 1, dùng đúng câu
*"Ghi nhận khoản chi 200.000 cho ăn uống hôm nay"* bằng tài khoản
`FAMILY_MEMBER` — kỳ vọng **không có thẻ xác nhận**, câu trả lời nói rõ cần nhờ
Trưởng nhóm/Phó nhóm.

### Audit contract AI Chatbot lần 2 — BE gửi kèm file contract chính thức

BE gửi thêm file `AI Chatbot contract` (markdown, có mục Pending action /
Permission behavior / Feature flags) xác nhận lại đúng 6 mục ở trên. Đọc lại
toàn bộ `ai_chatbot.dart` + `ai_chatbot_provider.dart` (full file, không phải
đoạn trích) để đối chiếu — **hầu hết đã đúng từ các lần audit trước**, không
có gì bị merge với Giáp làm lệch:

- `actionType` (3 giá trị), `status` (4 giá trị, không `CANCELED`/`FAILED`),
  `expiresAt` parse UTC không cắt `Z`, card chỉ hiện khi có `pendingAction`,
  reload đúng module, 409/410 tự đồng bộ lại thẻ, 3 key gói cước không gate
  màn AI — **tất cả khớp contract, không sửa gì**.
- Sửa đúng 1 chỗ: câu báo lỗi `403` lúc `confirm-action` trong
  `_friendlyError` chỉ nhắc "Trưởng nhóm", thiếu "Phó nhóm" — trong khi
  contract nói rõ `propose_create_ledger_entry` mở cho **cả**
  `FAMILY_MANAGER` **và** `DEPUTY_MEMBER`. Màn rỗng của Thành viên
  (`ai_assistant_screen.dart`) đã viết đúng "Trưởng nhóm và Phó nhóm" từ
  trước — chỉ riêng câu lỗi này bị sót. Đã sửa.
- Xác nhận lại: vấn đề chính (Member không nên nhận `pendingAction`) là lỗi
  **prompt/guard phía BE**, không phải chỗ nào FE sửa được — FE đã đúng sẵn
  (không có `pendingAction` thì không hiện thẻ).

### 📋 Nội dung 6 mục đã gửi BE (giữ lại để đối chiếu)

### 🔴 Bug lệch giờ 7 tiếng ở sổ thu chi — phát hiện khi verify giao dịch AI tạo

Không liên quan module AI, nhưng lộ ra khi verify runtime `CREATE_LEDGER_ENTRY`.
Ảnh hưởng **toàn bộ sổ thu chi**, mọi giao dịch, không riêng giao dịch AI tạo.

**Bằng chứng runtime:** tạo khoản chi thủ công lúc 20:19:00 giờ VN (13:19:00
UTC, verify TZ = Asia/Bangkok bằng `adb shell date`/`date -u` khớp cả emulator
lẫn host). Sổ thu chi hiện `13:18` — đúng bằng giờ UTC.

**Nguyên nhân — chứng minh bằng vòng khép kín, không suy luận:** FE tự gửi
`entryDate` bằng `DateTime.now().toUtc().toIso8601String()` (UTC chuẩn) lúc
**tạo** giao dịch (`WalletProvider.recordEntry`), nhưng `displayEntryDate` lại
cắt bỏ `Z` rồi parse như giờ naive lúc **hiển thị** — tự đọc sai dữ liệu do
chính FE gửi lên. **Lỗi FE, không phải BE.** Comment cũ trong code ghi "BE vẫn
trả hậu tố Z nhưng giữ giờ local GMT+7" — giả định này không còn đúng với
ledger (có thể BE đã đổi sang UTC thật, khớp với `expiresAt` của AI Chatbot
cũng là UTC thật).

**Đã sửa:** `WalletProvider.displayEntryDate` và `ChildWalletScreen._fmtDate`
— parse chuẩn rồi `.toLocal()` khi chuỗi thật sự UTC, giữ nguyên nếu chuỗi
naive (phòng dữ liệu cũ). Test mới: `test/wallet_ledger_date_test.dart`.
`API_DOCS.md` sửa lại dòng sai về timezone ledger.

**Không đụng:** support-request date — chưa có bằng chứng runtime mới, để
verify riêng nếu đụng tới, không suy diễn theo ledger.

**📋 Cần báo BE (phát hiện phụ, chưa xử lý):**
1. Giao dịch tự sinh từ `POST /finance/fund-allocations` có `description`
   tiếng Anh ("Allocate fund to Savings/Giving/Enjoyment/Education/
   Necessities") trong khi toàn app tiếng Việt — không tìm thấy chuỗi này ở
   bất kỳ đâu trong `lib/`, xác nhận là nội dung BE tự sinh. Không tự dịch
   cứng ở FE vì dễ vỡ nếu BE đổi tên hũ/mô hình sau này.
2. Màn Chi tiết giao dịch hiện "Số tiền: 30,000,000 đ **đ**" — lặp đơn vị.
   Phát hiện khi bấm nhầm vào giao dịch cũ lúc test, **chưa xác định được vị
   trí chính xác trong code** để phân loại lỗi FE hay do ghép chuỗi từ dữ liệu
   BE — cần soi lại trước khi sửa.

### File tạm không được commit

`.tmp_report_audit/`, `BuildDocx.cs`, `build_report6.ps1` là công cụ dựng báo cáo
docx cục bộ, cố ý để untracked. Đừng `git add -A` mà không lọc.

## Snapshot 2026-08-04 — Hoàn thành Sơ đồ Tổng thể Use Case Diagram (96 UCs / 8 Subsystems / 4 Actors / 4 External Systems)

### Use Case Diagram Tổng thể (`D:\Downloads\usecase-diagram (1).drawio`)

- **Trạng thái**: Đã hoàn thành 100%, được kiểm tra và thẩm định chi tiết cấu trúc XML.
- **4 Human Actors**:
  - `Guest` (Khách / Người dùng mới)
  - `Family Manager` (Trưởng nhóm gia đình)
  - `Family Member` (Thành viên gia đình)
  - `System Admin` (Quản trị viên hệ thống Web Admin)
- **4 External Systems**:
  - `AI Service` (Trợ lý AI Chatbot & AI Face Tags)
  - `Payment Gateway` (Cổng thanh toán gói cước)
  - `Notification Service` (Dịch vụ thông báo đẩy FCM)
  - `Wearable / GPS Device` (Đồng hồ thông minh & Định vị GPS)
- **72 Use Cases đại diện (Bao phủ trọn vẹn 100% tất cả 96 Use Cases thuộc 8 Subsystems)**:
  1. `1. Authentication & Workspace Setup` (UC09-UC13, UC69)
  2. `2. Family & Permission Management` (UC14-UC20)
  3. `3. Finance, Budget & Family Fund` (UC21-UC36, UC76-UC78, UC82-UC96)
  4. `4. Task & Reward Management` (UC37-UC49)
  5. `5. SOS, Safety & Wearable Tracking` (UC50-UC59, UC79-UC81)
  6. `6. Album & AI Face Classification` (UC72-UC75)
  7. `7. Communication, Calendar & AI Assistant` (UC60-UC68, UC70-UC71)
  8. `8. Admin System Management` (UC01-UC08)
- **Chuẩn đồ họa & Kết nối UML**:
  - 85 đường nối (`connectors`).
  - Mũi tên nét đứt `<<include>>`: chỉ từ Use Case gốc sang Use Case dịch vụ/bắt buộc.
  - Mũi tên nét đứt `<<extend>>`: chỉ từ Use Case phụ/tùy chọn về Use Case chính.
  - Dây nét liền không mũi tên nối từ Actor vào Use Case.
- **Lưu ý hoàn thiện UI trước khi xuất file**:
  - Đã nhắc người dùng chỉnh nhẹ typo `Famlily member` ➔ `Family Member`.
  - Làm sạch các thẻ ngắt dòng HTML `<br/>` trong tên hình bầu dục để khi export PNG/PDF hiển thị đẹp nhất.

## Snapshot 2026-08-02 — đồng bộ main, Finance model/hũ và Face scan

### Git / phạm vi thay đổi

- Nhánh làm việc `NDuy` đã fast-forward an toàn tới `origin/main` commit
  `1c452e1`; trước pull `main` đi trước 12 commit, không có nhánh rẽ.
- WIP được stash tạm, pull `--ff-only`, rồi khôi phục. Chỉ `API_DOCS.md` trùng
  nội dung và đã được hợp nhất giữ đủ cả hai phía; không mất code.
- Local `NDuy` hiện đi trước `origin/NDuy` 12 commit do chưa push sau khi kéo
  main. Working tree còn nhiều thay đổi cục bộ thuộc Album/SOS/Subscription,
  tài liệu và report; không commit/push nếu người dùng chưa yêu cầu.

### Finance model / category → jar — đã wire theo contract mới

- Mapping dùng đủ GET/POST/DELETE `/finance/category-jar-mappings`, luôn truyền
  `financeModelId`; mapping 5 hũ và 80/20 được tách theo từng model.
- Form tạo/sửa ledger ưu tiên `categoryId`, không gửi `jarId`; BE tự map theo
  model ACTIVE. Giao dịch cũ hoặc jar thuộc model khác đi vào `unmapped`.
- Dashboard và Báo cáo → Theo hũ gọi
  `GET /finance/reports/jar-target-actual` với active `financeModelId`; không
  còn dùng phép cộng local (`lib/utils/jar_allocation.dart` đã bị xóa).
- Parser khớp DTO live: `items[].jar`, target/actual %, target/actual amount,
  status `ON_TRACK | OVER_TARGET | UNDER_TARGET`, và `unmapped.amount`.
- Contract BE xác nhận report chỉ tính ledger `ACTIVE`, cash-out
  `EXPENSE | SUPPORT | ALLOWANCE | REWARD` trong kỳ. Jar của model cũ/khác
  model được cộng vào `unmapped.legacyJarAmount`, không cộng vào hũ mới.
- Swagger live đã có response schema/example cho mapping và
  `jar-target-actual`. Tuy nhiên GET/POST model và GET/POST/PATCH jar vẫn thiếu
  response DTO rõ ràng; đánh `[VERIFY]`, không suy diễn thêm field số dư hũ.

### Album Face AI — multi-face đã có, retry/rate-limit vừa bổ sung

- Multi-face đã đọc `data.faces[]`, mỗi face giữ candidate confidence cao nhất;
  người dùng vẫn phải bấm ✓ mới tạo tag chính thức.
- Bổ sung `FaceScanStatusInfo`: đọc `PENDING | PROCESSING | COMPLETED | FAILED`,
  `retryAllowed`, `maxProcessingSeconds` ở root hoặc object `job/scan`.
- Khi `retryAllowed=true`, FE gọi `POST .../face-scan/retry`; không tạo force
  scan mới. Lỗi `429 FACE_SCAN_FORCE_RESCAN_RATE_LIMITED` đọc
  `retryAfterSeconds`, `cooldownSeconds` hoặc header `Retry-After`, khóa nút và
  đếm ngược rõ trên UI.
- Swagger live còn thiếu success response schema cho POST scan, GET status và
  POST retry, nên parser status giữ phòng thủ và cần verify runtime với job kẹt.

### Verification 2026-08-02

- `dart analyze` trực tiếp 3 file Face/API vừa sửa: **No issues found**.
- `flutter analyze --no-fatal-infos` toàn project: **0 error, 0 warning**;
  còn 20 info-lint có sẵn ở các module khác.
- Targeted Flutter tests Face + Finance model/hũ: **21/21 pass**, gồm parser
  retry metadata, multi-face, mapping lồng, response chính xác của
  `jar-target-actual`, history allocation và ADJUSTMENT trung tính với số dư.

## Snapshot 2026-07-29 — Face AI, giao dịch theo hũ và lịch sử chia quỹ

> Đây là snapshot LỊCH SỬ. Snapshot ưu tiên nằm ở đầu tài liệu (2026-08-07).
> Phần dưới đây có thể chứa commit, API contract hoặc `[VERIFY]` đã lỗi thời.

### Git / nhánh

- Nhánh làm việc: `NDuy`.
- `NDuy`, `origin/NDuy` và `origin/main` đang đồng bộ tại commit `dfb8c6c`.
- `main` được fast-forward từ `bb368ac` lên `dfb8c6c`; không có nhánh rẽ,
  conflict hoặc merge commit thừa.
- Các commit mới nhất đã push:
  - `dfb8c6c` — `fix(tài chính): đồng bộ lịch sử chia quỹ theo contract BE mới`;
  - `6f8a744` — `fix(tài chính): gắn giao dịch chi vào đúng hũ đang áp dụng`;
  - `96961b8` — `fix(khuôn mặt): giải thích trạng thái ảnh chờ duyệt an toàn`;
  - `3d90726` — `feat(khuôn mặt): hoàn thiện kiểm tra và chọn ảnh Face Profile`;
  - `958e303` — `feat(tài chính): hiển thị thời điểm thực hiện chia quỹ`.
- Working tree vẫn có thay đổi khác chưa commit trong `AI_HANDOFF_LATEST.md`,
  `API_DOCS.md`, Album/SOS/Subscription và các file report tạm. Không stage
  chung các file này nếu chưa rà lại đúng phạm vi.

### Face Profile / Album Face AI đã kiểm tra runtime

- Face Profile cho phép chọn từng ảnh, thêm/xóa preview, đủ 3–5 ảnh mới kiểm
  tra; gọi `POST .../face-profiles/{memberId}/validate` trước khi enroll.
- FE đọc `canEnroll` và `results[]`, hiển thị pass/fail từng ảnh; chỉ bật nút
  tạo hồ sơ khi ảnh đạt và đã xác nhận đồng ý.
- Runtime đã test: 3 ảnh đạt validate, enroll thành công và member detail hiện
  trạng thái **Đã thiết lập**.
- Album media chưa SAFE hiện cảnh báo rõ **Ảnh đang chờ duyệt an toàn**; phải
  duyệt thủ công trước khi AI scan.
- Runtime đã test: ảnh SAFE quét được gợi ý thành viên, người dùng bấm xác nhận
  rồi tag chính thức được tạo. Flow hiện hành giữ rule user phải xác nhận;
  không tự tạo tag chỉ vì confidence >= 80%.

### Finance — gắn khoản chi vào hũ

- `CreateLedgerEntryDto` và `UpdateLedgerEntryDto` có `jarId`; FE đã thêm
  dropdown **Hũ chi tiêu** khi tạo/sửa giao dịch EXPENSE.
- Chỉ hiển thị hũ active thuộc đúng mô hình `ACTIVE`; có thể chuyển hũ hoặc
  chọn **Chưa gắn hũ** để bỏ liên kết.
- Runtime đã test: ghi chi `100.000đ` vào Education làm dòng Education tăng
  từ `0đ` lên `100.000đ`; số này không còn bị dồn vào **Chưa gắn hũ**.
- `POST /finance/fund-allocations` chỉ phân loại quỹ nội bộ và tạo ADJUSTMENT
  ledger để audit; không tạo tiền mới và không tự làm tăng thực chi hũ.
- Verify targeted: `flutter analyze` hai file Wallet/Provider không có lỗi;
  `test/jar_allocation_test.dart` đạt **10/10**.

### Finance — chia quỹ theo mô hình và lịch sử

- Flow: activate model → nhập số tiền/kỳ/ghi chú →
  `POST /finance/fund-allocations` → hiển thị `items[]` theo từng hũ.
- Contract BE chốt ngày 29/07/2026:
  - POST và GET history trả thêm `createdAt`, `createdByMemberId`, `note` ở
    cấp allocation;
  - GET history sort mới nhất trước theo `createdAt`;
  - history cố trả `model`, `period`, `totalAmount`, `items`, `createdAt`;
    dữ liệu legacy không khôi phục được có thể null nhưng item không bị loại;
  - unique rule là `familyId + periodMonth + periodYear`: một gia đình chỉ
    được chia một lần trong một kỳ, dù đổi model;
  - đổi active model chỉ áp dụng cho lần chia tương lai, không đổi snapshot cũ.
- FE đã đọc metadata mới ở cấp allocation, fallback timestamp từ entries cho
  legacy, giữ item nullable, sắp xếp mới nhất trước và đưa item thiếu thời gian
  xuống cuối.
- UI chi tiết hiển thị thời điểm, ghi chú, `createdByMemberId`; dữ liệu legacy
  thiếu model/kỳ/tổng/items có nhãn thay thế thay vì crash hoặc bị mất.
- Error `409 FUND_ALLOCATION_ALREADY_EXISTS` hiển thị đúng: mỗi tháng chỉ
  chia một lần kể cả đổi mô hình.
- Runtime đã test:
  - lịch sử `17:02:36` nằm trên bản `16:43:13`, ghi chú hiển thị đúng;
  - chia lại cùng kỳ trả đúng cảnh báo 409;
  - hai bản ghi trùng kỳ 7/2026 nhìn thấy trong lịch sử là dữ liệu cũ tạo trước
    khi BE áp dụng unique rule mới, không phải FE tạo thêm sau fix.
- Verify targeted: analyzer ba file contract/history không có lỗi;
  `test/fund_allocation_mapping_test.dart` đạt **5/5** (metadata mới, legacy
  nullable, sort newest-first và ADJUSTMENT không đổi tổng quỹ).

### Việc tiếp theo đề xuất

1. Test quyền chia/xem lịch sử bằng `FAMILY_MANAGER`, `DEPUTY_MEMBER` và xác
   nhận `FAMILY_MEMBER` nhận 403 đúng contract.
2. Khi xem chi tiết history, nếu không muốn lộ UUID thành viên thì đề nghị BE
   trả thêm snapshot/display name người thực hiện; hiện contract chỉ có
   `createdByMemberId` nên FE chỉ có thể hiển thị mã.
3. Tiếp tục từng module còn dở; chỉ commit/push khi người dùng yêu cầu. Commit
   message dùng tiếng Việt và tách theo chức năng.

## Snapshot đang làm 2026-07-30 — Face nhiều khuôn mặt và Category → Jar

- Đã đọc lại Swagger live ngày 30/07/2026 và tin nhắn contract BE.
- Face Album: FE nhận cả response suggestion phẳng và response nhóm theo từng
  khuôn mặt (`faces/results` + `candidates/matches`), chỉ giữ ứng viên score cao
  nhất cho mỗi face. Vẫn giữ rule: AI chỉ gợi ý, user xác nhận mới tạo tag.
- Finance: đã thêm provider/UI CRUD mapping category → jar theo từng model qua
  GET/POST/DELETE `category-jar-mappings`; sau khi activate model, màn hình ưu
  tiên mở bước cấu hình mapping.
- Tạo giao dịch mới ưu tiên `categoryId`, không gửi `jarId`, để BE tự map theo
  model ACTIVE. Giao dịch cũ không map giữ nguyên ở `unmapped`.
- Đã wire report `reports/jar-target-actual` vào tab **Theo hũ**, hỗ trợ trạng
  thái ON_TRACK / OVER_TARGET / UNDER_TARGET và fallback raw khi response chưa
  khớp parser.
- Swagger live vẫn thiếu response schema/example cho Face Suggestions,
  category-jar-mappings và jar-target-actual; cần giữ `[VERIFY]` cho tên field
  response cho đến khi có DTO/sample chính thức hoặc test runtime có dữ liệu.
- Chưa commit/push các thay đổi 30/07; chỉ thực hiện khi người dùng yêu cầu.

## 🚀 Snapshot mới nhất 2026-07-28 (Đối chiếu toàn bộ Swagger API 2026-07-28 & Verification Mobile + Web Admin)

### 📌 Trạng thái Git & Biên Dịch
- **Mobile FE (`d:\Desktop\mobile-sep`)**: `flutter analyze` clean (**0 error**, **0 warning**), `flutter test` **109 / 109 PASS 100%**.
- **Web Admin FE (`d:\Desktop\sep`)**: Next.js production build (`pnpm --filter web build`) **Compiled successfully**, 29/29 static pages.

### 🛠️ Chi Tiết Kiểm Tra & Đối Chiếu API Swagger (`familycare-swagger-2026-07-28.json`)
1. **Đối chiếu Mobile App (Flutter)**:
   - Tổng cộng 236 Non-Admin Swagger endpoints, Mobile App đã gán và hoạt động **227/236 endpoints (96.2% độ phủ)**.
   - Đã rà soát & đảm bảo phòng thủ toàn bộ 12 luồng nghiệp vụ chính: Auth, Family & Invite (mã 8 ký tự), SOS & Vị trí, Wearables, Notifications & Real-time Socket.IO, Subscriptions, Finance Module (Summary, Monthly Finance, Models/Jars, Categories, Ledger, Support Requests, Budget Plans, Goals, Reports, Alerts), Task & Reward, Calendar, Chat, Album & Face Profiles, AI Chatbot.
2. **Đối chiếu Web Admin (Next.js)**:
   - Phủ đầy đủ 100% các màn Admin: Users, Families, Subscriptions, Payments, System & Host Infrastructure, Docker containers, Audit logs, Backups & Restore, Revenue, Provisioning logs.
   - Các API Admin mới (`confirm restore`, `container stats/logs`, `family subscription/activation/provisioning logs`) đều đã có sẵn helper hooks chuẩn TypeScript trong `useAdmin.ts`.

### 📋 List 5 Điểm Cần Phản Hồi Team Backend (BE Report List)
1. **Face Profile Validate Response DTO (`POST /families/:familyId/face-profiles/:memberId/validate`)**:
   - API trả về `201 Created` thành công, nhưng Swagger OpenAPI schema chưa định nghĩa DTO mẫu JSON cho `canEnroll: boolean`, `results: Array`, `reasonCode: string`.
2. **Kế hoạch đóng góp mục tiêu (Goal Contribution Plan)**:
   - Khi tạo Kế hoạch đóng góp mới cho tháng, các khoản trích cũ (`allocations`) thực hiện trước thời điểm tạo plan không được cộng dồn vào `actualAmount` của plan mới, trừ khi được gắn với `planId`.
3. **Chuẩn hóa Timezone của các bản ghi Ledger / Support Request**:
   - Chuỗi thời gian trong response API cần được BE trả về dạng UTC chuẩn có đuôi `Z` hoặc offset `+07:00` nhất quán, tránh trả wall-clock local nhưng gắn đuôi `Z`.
4. **Trạng thái SOS Response (`SosResponseResponseDto.responseType`)**:
   - Swagger liệt kê enum gồm `VIEWED`, `CONFIRM_SAFE`, `NEED_HELP`, `RESOLVED`, `CANCELED`, nhưng summary nhắc tới `ON_THE_WAY`. BE cần xác nhận xem `ON_THE_WAY` đã hỗ trợ chưa.
5. **Nội dung Push Notification Lock Screen**:
   - Notification tin nhắn Chat hiện đẩy toàn bộ text tin nhắn. Cần cờ cấu hình ẩn nội dung nhạy cảm trên màn hình khóa.

---

## Snapshot 2026-07-28 - Finance API update, branch state, and current handoff

### Git / Branch State

- Working branch: `NDuy`.
- Local `NDuy` is currently at commit `2c2bf4c`.
- `origin/main` is also at `2c2bf4c`, so the latest remote `main` already contains the most recent merged code currently checked out locally.
- `origin/NDuy` is **behind local `NDuy` by 5 commits**. Before testing on another machine or opening another PR from `NDuy`, run:
  - `git checkout NDuy`
  - `git push origin NDuy`
- Local `main` branch is behind `origin/main` by 5 commits. If switching to `main`, run `git checkout main` then `git pull origin main`.
- Current working tree before this handoff update was clean except Git warnings about the global ignore file permission: `C:\Users\N DUY/.config/git/ignore`.

### Latest commits on top of old `origin/NDuy`

- `62f8108` - `revert(finance): dung lai design So chi tieu theo model khai-bao-thu-nhap`
- `18c8e27` - `merge: keo main ve giap (surplus allocation, deputy task proof, contribution/fund) - giu child_wallet design cua minh`
- `696c899` - `feat(family): trao quyen Truong nhom + cap nhat API_DOCS Tuan 10`
- `847e2ab` - `chore(mobile): gom thay doi moi (polish finance/theme/screens + transfer-ownership)`
- `2c2bf4c` - `chore(finance): an child_wallet design cua minh - dung ban main (Duy) de tranh xung dot merge`

### Finance API list from BE - current FE mapping status

BE confirmed Finance prefix: `/families/:familyId/finance`.

Covered in mobile FE:

- Overview / dashboard: `/overview` legacy fallback and newer `/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary`.
- Reports: `/reports/overview`, `/reports/budget-goal`, `/reports/non-essential-spending`.
- Monthly finance: `/monthly-finances/me`, `/monthly-finances/members/:memberId`, `/monthly-summary/me`, `/monthly-summary/members/:memberId`.
- Ledger: `/ledger/entries`, detail/edit/delete flow, soft delete `VOIDED` hidden from active lists.
- Categories: `/categories` CRUD, inactive categories labeled and excluded from new-create forms.
- Models/Jars: `/model-templates`, `/models`, activate model, `/jars`, patch jar.
- Budget plans: list/create/detail/edit/activate/close/cancel/report and line CRUD.
- Financial goals: list/create/detail/edit/cancel, allocations CRUD, contribution suggestions/plans/shortage and approve/reject flow.
- Alerts: list/detail/recompute/acknowledge/resolve.
- Support requests: list/create/detail/review/cancel, with Member privacy and Manager/Deputy review expectations.

Important BE updates already acknowledged:

- Swagger now has schemas + sample JSON for `/overview`, `/summary`, `/cash-flow-summary`, `/category-spending-summary`, `/member-contribution-summary`.
- Money unit is VND and response envelope is `{ success, message, data }`.
- Empty arrays should return `[]`; nullable object fields may return `null`.
- Query params include `periodStart`, `periodEnd`, `budgetPlanId`, `includeAlerts`, `includeGoals`, `includeBreakdown`.
- BE says contribution plan now only counts allocations/submissions belonging to the correct `planId`.
- BE requires ledger/support timestamps as ISO with timezone (`Z` or `+07:00`); FE sends UTC ISO where touched.
- BE says Member support request list only returns that member's own requests.
- BE says Deputy can view member monthly finance, approve/reject contribution plans, and review support requests.

### Latest Finance QA notes from user testing

Already fixed or adjusted in FE:

- Ledger delete/huy giao dich: hide `VOIDED` rows after refresh so canceled entries do not stay in active history/totals.
- Category management: inactive categories are visible with status label, sorted after active items, and not selectable in create forms.
- Budget plan detail/report: canceled plans should not show action/report like active plans; report labels localized and UUID/raw fields reduced where possible.
- Financial goal achieved state: achieved goals show completed status and progress amount such as `8.000.000 / 15.000.000`, not misleading `0 / target`.
- Contribution plan: Manager/Deputy can update monthly contribution plan after creating it; cards show planned/paid/shortage in compact UI instead of raw JSON.
- Alerts: `Acknowledge` means "Đã xem"; `Resolve` means "Đã xử lý"; recompute can recreate alerts if the underlying budget/goal condition still exists.
- Support request: Member wallet wording changed toward personal spending support, request cards are tappable, and Manager/Deputy review uses ISO timestamp.
- Monthly finance: save uses PUT/POST fallback and should keep data after leaving/re-entering the screen.
- Finance dashboard: wired newer summary APIs with fallback to old overview.

Still needs focused retest:

1. Pull/push sync first: `git push origin NDuy` if continuing from this local repo, then run app fresh.
2. Manager Ledger: create income/expense, edit, delete, refresh; deleted entry must disappear and totals must recalc.
3. Category: create, rename, deactivate; inactive category must show status and must not appear in new ledger/budget forms.
4. Budget Plan: create draft with first line, edit/add/delete line, activate, view report, cancel/close; historical closed plans may remain in report dropdown but must show status.
5. Goal Allocation: create/edit/delete allocation; if amount exceeds source transaction available amount, FE should show a friendly domain error.
6. Contribution Plan: Manager creates/updates monthly plan; Member submits; Manager/Deputy approves/rejects; shortage updates correctly.
7. Alerts: recompute after fixing source data; alert should disappear only when source condition is actually fixed.
8. Support Request: Member create/cancel/open detail; Manager/Deputy approve/reject/open detail.
9. Monthly Finance Privacy: Member saves monthly finance with visibility toggles; Manager/Deputy view member summary and private fields must be hidden/null when toggled off.

### BE questions / bugs to keep on report list

- Confirm contribution-plan retest after BE fix: old allocations must not be counted into a new monthly plan unless tied to that plan.
- Confirm all Finance summary/report endpoints document enum/nullability/400/403 cases consistently in Swagger.
- Confirm support request detail/list includes enough identity fields for FE display (`requesterMemberId`, display name, status, reviewer fields).
- Confirm profile fields `occupation`, family-facing relationship update, member role update, grant/revoke deputy permission remain missing from mobile-facing APIs unless BE has newly added them.
- Face Profile enroll still depends on BE face quality validation; if BE returns `Face image is not enrollable`, FE can only show guidance unless BE returns detailed reason codes.

---

## 🚀 Snapshot mới nhất 2026-07-23 (Phân bổ số dư mục tiêu & Deputy Task Submission & Auto Plan Approval)

### 📌 Trạng thái Git / Branch Sync
- **Nhánh local:** `NDuy` và `main` đã được merge Fast-forward đồng bộ 100%.
- **Remote:** Cả `origin/NDuy` và `origin/main` đều đã được push và đồng bộ hoàn toàn.
- **Biên dịch:** Đã fix triệt để toàn bộ lỗi import & type lookup `FamilyProvider`.

### 🛠️ Chi tiết Fixes & Cập nhật Tính năng
1. **Phân bổ số dư vào Mục tiêu tiết kiệm (Surplus Allocation - API 1 & 2):**
   - Đã tích hợp API `GET /families/:familyId/finance/financial-goals/surplus-availability` và `POST /families/:familyId/finance/financial-goals/:goalId/surplus-allocations`.
   - Tối ưu UI/UX với 2 nút hành động phân biệt rõ ràng dòng tiền:
     - `💰 Góp tiền cá nhân (Tiền túi)`: Nộp tiền mới từ cá nhân ➡️ Tăng Tổng quỹ gia đình & Tăng quỹ mục tiêu.
     - `💼 Trích từ số dư quỹ chung`: Trích tiền dư thừa tích lũy của tháng ➡️ Quỹ chung không đổi, trích số dư khả dụng sang mục tiêu.
   - Thêm Info Banner giải thích minh bạch trong từng Popup Modal.
2. **Liên kết tự động & Tự động duyệt Kế hoạch đóng góp tháng (Auto Plan Approval):**
   - Bổ sung checkbox tự động ghi nhận khoản góp cá nhân vào Kế hoạch đóng góp tháng của thành viên.
   - Nếu người thực hiện là **Manager hoặc Deputy**, hệ thống tự động gọi API `reviewContributionPlan(..., 'approve')` để **TỰ ĐỘNG DUYỆT BÀI NỘP**, ghi nhận `actualAmount` lập tức mà không bắt Manager tự duyệt lại bài của chính mình.
3. **Chức năng nộp nhiệm vụ cho Deputy / Manager (`TaskManagementScreen`):**
   - Bổ sung nút `Bắt đầu làm` & `Nộp nhiệm vụ` (kèm đính kèm ảnh minh chứng / ghi chú) ngay trong thẻ nhiệm vụ của `TaskManagementScreen` nếu công việc đó được phân công cho chính Manager / Deputy đang đăng nhập.

---

## 🚀 Snapshot 2026-07-22 (Finance, Member UI Redesign & Multi-Admin Sync)

### 📌 Trạng thái Git / Branch Sync
- **Nhánh local:** `NDuy` và `main` đã được merge Fast-forward đồng bộ 100% tại commit `936006a`.
- **Remote:** Cả `origin/NDuy` và `origin/main` đều đã được push và đang ở commit `936006a`.
- **Kiểm thử:** **81/81 unit test PASS 100%**, `flutter analyze` clean (**0 error**).

### 🛠️ Chi tiết Fixes & Cập nhật Finance (Mobile)
1. **Lỗi Tạo Danh Mục (Category Creation 502 Error):**
   - Đã bổ sung `essentialType` mặc định (`ESSENTIAL`) cho danh mục Khoản Chi và giao diện form chọn loại thiết yếu -> Loại bỏ hoàn toàn lỗi Server 502 Bad Gateway.
2. **Lỗi `entryDate không đúng định dạng` & Chọn danh mục Thu/Chi:**
   - Chuẩn hóa định dạng `entryDate` sang chuỗi ISO UTC `YYYY-MM-DDTHH:mm:ssZ` (bỏ 6 chữ số thập phân microsecond).
   - Cập nhật popup Thu/Chi dùng `watch<FinanceProvider>()` -> Mới tạo danh mục xong là dropdown tự động cập nhật ngay.
3. **Phân bổ vào Mục tiêu (Goal Allocation):**
   - Bổ sung bộ lọc bắt lỗi khi sửa số tiền phân bổ mục tiêu: hiển thị thông báo tiếng Việt rõ ràng thay vì câu văng lỗi kỹ thuật.
4. **Phân quyền & Redesign UI Trang chủ / Sổ chi tiêu Member:**
   - **Phân quyền:** Member KHÔNG có quyền xem tổng quỹ gia đình (BE trả 403, chỉ Manager/Deputy được xem).
   - **Trang chủ Member (`child_home_screen.dart`):** Đã sửa ô lối tắt 💰 hiển thị tổng quỹ chung `51,171,111 đ` thành nhãn tính năng **"Tài chính"** (đồng bộ với AI, Album, Lịch).
   - **Sổ chi tiêu Member (`child_wallet_screen.dart`):** Loại bỏ thẻ mock `Số dư hiện tại: — đ (chưa có API)` -> Thay bằng thẻ **"Còn lại có thể tiêu"** (tính từ Hạn mức cá nhân - Đã chi tiêu) vô cùng minh bạch và chuyên nghiệp.
5. **Yêu cầu hỗ trợ (Support Requests):**
   - Sửa `_statusChip` hiển thị chính xác trạng thái `CANCELED` / `CANCELLED` thành nhãn màu xám **"Đã hủy"** trên cả màn danh sách chi tiết lẫn thẻ preview ngoài màn chính.
6. **Khai báo Tài chính theo tháng (Monthly Finance):**
   - Tự động fallback giữa `POST` và `PUT` khi đã tồn tại bản ghi khai báo tháng trước đó.

### 🌐 Trạng thái Web Admin Multi-Admin Rules (`d:\Desktop\sep`)
- Gỡ bỏ hoàn toàn Modal "Đổi vai trò" (Edit Role) và không truyền `userType` trong PATCH `/admin/users/:id` (được BE kiểm soát qua script/seed).
- Tự động `disabled` nút Khóa/Mở khóa đối với chính Admin đang đăng nhập (`u.id === user?.id`) và các tài khoản `SYSTEM_ADMIN` khác (`u.userType === 'SYSTEM_ADMIN'`).

---

## Snapshot hiện tại 2026-07-22 — Finance + Face Profile QA (đọc phần này trước)

### Git / commit handoff

- Nhánh làm việc: `NDuy`.
- Working tree **chưa commit**. `git diff --check` đã pass.
- Nhóm thay đổi chức năng cần commit cùng nhau là 25 file tracked trong
  `API_DOCS.md`, `lib/` (Finance, Face Profile, Album, notification) và các
  file untracked sau:
  - `lib/providers/face_profile_provider.dart`;
  - `lib/screens/shared/face_suggestions_sheet.dart`;
  - `test/face_profile_provider_test.dart`.
- `BAO_CAO_BE_FACE_ROLE_FEATURE_2026-07-21.md` là báo cáo gửi BE, chỉ add nếu
  nhóm muốn version-control tài liệu này.
- Không add/commit `.claude/settings*.json` hoặc `.vscode/settings.json` nếu
  chưa thống nhất cấu hình dùng chung.
- Chưa chạy được full `dart format`/`flutter analyze` trong phiên này vì tiến
  trình Flutter/Android Studio đang giữ tool lâu quá timeout; đã kiểm tra diff
  tĩnh và `git diff --check`. Cần chạy CI hoặc `flutter analyze` + `flutter
  test` sau khi commit.

### Những thay đổi FE đã làm

#### Face Profile / Album

- Thêm `FaceProfileProvider`, UI thiết lập Face Profile tại member detail,
  upload từng ảnh, trạng thái enroll/enable/disable/delete và UI xem/xử lý AI
  face suggestions trong Album.
- Feature gate Face Profile/face suggestion theo subscription feature access;
  tài liệu endpoint được bổ sung vào `API_DOCS.md`.
- Đã test enroll với ảnh thật: FE gửi request đúng nhưng BE trả
  `Face image is not enrollable`. Đây là response/validation BE, không phải
  crash FE. Cần BE cung cấp tiêu chí ảnh hoặc mẫu ảnh được chấp nhận.

#### Finance — Budget, goal, alert, report

- Chuẩn hóa input tiền dùng dấu chấm (`100000` -> `100.000`) và parse an toàn
  tại các form Budget, Goal contribution, Monthly Finance và Ledger.
- Budget Plan: tạo DRAFT có dòng ngân sách đầu tiên; tạo category inline khi
  cần; thêm/sửa/xóa budget line; action activate/cancel/close hiển thị lỗi BE
  rõ ràng; report dropdown ẩn plan CANCELED, giữ CLOSED lịch sử và ưu tiên
  ACTIVE. Nút xem report không hiện ở plan đã hủy.
- Goal: sửa mapping trạng thái BE `ACHIEVED`; card/list hiển thị đúng số đã
  góp/mục tiêu, ngày `dd/MM/yyyy`, trạng thái hoàn thành và chặn góp thêm khi
  đã đạt. Detail rút từ JSON kỹ thuật xuống tiến độ dễ đọc; allocation có
  create/edit/delete.
- Goal Contribution Plan: sửa FE gửi `FamilyMember.id` (không phải `userId`),
  parse response BE bọc trong `members`, nhận status thực tế `PLANNED` và
  `PAID`, hiển thị card gọn thay JSON thô và tính thiếu hụt gọn theo plan.
- Finance Alert: làm rõ nút `Tính lại cảnh báo từ dữ liệu hiện tại`; trạng thái
  "Đã xem"/"Đã xử lý"; resolve không giả vờ thay đổi số liệu, recompute có thể
  tạo lại alert nếu điều kiện nguồn vẫn còn. Alert RESOLVED không còn ở list.
  Detail đã ẩn UUID/field kỹ thuật. Badge notification in-app/local notification
  cập nhật theo unread count (launcher badge tùy thiết bị).
- Finance Report: localize enum/ngày/số tiền, ẩn field kỹ thuật trong report
  mode và thêm mô tả nghiệp vụ cho ba tab.

#### Finance — Model, Monthly Finance, Ledger

- Finance Model: lưu 5 Jars/80-20/Custom ở lại màn hình, cập nhật banner model
  vừa áp dụng ngay, không `pop()` về tab Tôi và không để response tải cũ ghi đè
  state người dùng vừa chỉnh.
- Monthly Finance: thêm shortcut "Tài chính tháng của tôi" cho mọi role;
  format tiền và lưu/đọc lại expected income, personal expense, shared
  contribution cùng visibility.
- Ledger/Wallet: form ghi thu/chi dùng format tiền và danh mục; giao dịch gần
  đây + lịch sử hiển thị `dd/MM/yyyy HH:mm` thay ISO raw.

### Runtime test đã làm trên emulator

- Goal allocation/góp trực tiếp: tạo, sửa và xóa đã thao tác; status/progress
  cập nhật đúng (ví dụ 8.000.000 / 15.000.000 = 53%).
- Budget: tạo Draft, thêm dòng, sửa số tiền, xóa dòng, cancel plan; validation
  yêu cầu ít nhất một dòng trước activate đã hoạt động.
- Alerts: acknowledge/resolve/recompute đã test. Sau khi góp đủ mục tiêu và
  điều chỉnh budget threshold, alert tương ứng biến mất sau recompute.
- Reports: đã mở và đối chiếu Budget, Non-essential, Budget & Goal.
- Goal contribution plan: Manager confirm/update và GET list đã test; 3 member
  plan hiển thị được sau fix parser. **Chưa test** Member submit rồi
  Manager approve/reject.
- Monthly Finance: Manager lưu `20.000.000 / 7.000.000 / 1.000.000`, bật
  visibility, thoát vào lại vẫn còn đúng.
- Ledger: ghi một thu và một chi; dấu tiền/số dư cập nhật đúng. Thời gian đã
  format để dễ đọc.

### Cần test tiếp (cần đăng nhập Member)

1. Goal contribution plan: member `submit` -> Manager `approve`/`reject`.
2. Spending support request: Member create/cancel -> Manager approve/reject.
3. Monthly summary/privacy: tắt một visibility ở Member, Manager/Deputy xem
   summary phải thấy field private là null/"Riêng tư".

### Lỗi / câu hỏi cần báo BE

1. **Goal contribution plan actual bị tính sai ngữ cảnh:** Sau khi tạo plan
   tháng 7, response `GET .../contribution-plans?month=7&year=2026` gán khoản
   goal allocation cũ `8.100.000` của Manager vào `actualAmount` plan mới có
   `plannedAmount` chỉ `222.222`, status `PAID`. Xác nhận whether allocation
   lịch sử có được tính vào plan tạo sau đó hay chỉ giao dịch submit/approve
   của đúng plan mới được tính.
2. **Ledger timezone:** máy/emulator GMT+7 lúc 02:57 nhưng BE trả cùng wall
   clock với hậu tố `Z`, ví dụ `2026-07-22T02:56:26.705Z`. `Z` nghĩa UTC là sai
   ngữ nghĩa (nếu convert chuẩn sẽ lệch +7 giờ). FE đang hiển thị theo giờ local
   được người dùng nhập; BE cần trả UTC thật hoặc offset `+07:00` nhất quán.
3. **Face Profile enroll:** BE trả `Face image is not enrollable` với ảnh chân
   dung thực. Cần contract điều kiện ảnh/face quality và mã lỗi chi tiết để FE
   hướng dẫn người dùng.

---

## Snapshot hiện tại 2026-07-19 — đọc phần này trước

> Snapshot này thay thế các kết luận CI/CD trong snapshot 2026-07-18 và các
> phần lịch sử phía dưới. Không xóa lịch sử vì vẫn chứa thông tin wiring/API.

### Kết luận ngắn

- **Admin Web CI/CD: DONE.**
- **Mobile CI: DONE.**
- **Android signed release + Google Drive + QR: DONE.**
- **Bảo mật nhiều tài khoản Admin: chưa thể kết luận DONE; phải được BE enforce.**
- **iOS native/TestFlight: chưa thực hiện; iPhone dùng Web/PWA làm fallback.**

### Git và trạng thái repository

#### Mobile — `D:\Desktop\mobile-sep`

- Repository: `16-Doffy/SEP-Family-Care-Mobile`.
- `origin/main`: merge commit `5fe0708` (PR #2).
- Commit triển khai Google Drive OAuth: `18d43ae`.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- CI/CD đã được commit, push và merge vào `main`; không còn code CI/CD cần
  commit/push.
- Working tree local còn:
  - modified `AI_HANDOFF_LATEST.md`;
  - untracked `.claude/`;
  - untracked `.vscode/settings.json`.
- Chỉ commit `AI_HANDOFF_LATEST.md` sau cập nhật này. Không tự động commit
  `.claude/` hoặc `.vscode/settings.json` nếu nhóm chưa thống nhất dùng chung.

#### Admin Web — `D:\Desktop\sep`

- Repository GitHub hiện dùng: `16-Doffy/SEP-Family-Care-WEB`
  (remote cũ có thể redirect từ tên `SEP-Family-Care-Third-s`).
- `origin/main`: merge commit `15038e8` (PR #1).
- Commit CI/CD chính:
  - `25bb110` — thêm Web Admin CI/CD;
  - `2360f89` — chuyển deployment sang Vercel, bỏ VPS deployment.
- Nội dung tracked trên nhánh local `NDuy` đã được đối chiếu và giống
  `origin/main`; local chỉ thiếu merge-history commits.
- Các file untracked như `.claude/`, script Swagger và file tạm không thuộc
  CI/CD; không commit chung nếu chưa review.

### Admin Web CI/CD — DONE

- Workflow nằm tại root repository:
  `.github/workflows/web-admin.yml`.
- Monorepo dùng pnpm workspace; Admin Next.js nằm tại `apps/web`.
- GitHub Actions đã chạy thành công:
  - type-check/build shared package và Admin Web;
  - Next.js production build;
  - verify Docker build bằng `apps/web/Dockerfile`.
- GitHub Actions không SSH/VPS và không push GHCR ở phương án hiện tại.
- CD dùng Vercel Git Integration:
  - PR/branch tạo Preview deployment;
  - merge/push `main` tạo Production deployment.
- Production URL:
  `https://family-care-admin.vercel.app`.
- Vercel Environment Variables đã cấu hình cho Production/Preview:
  - `NEXT_PUBLIC_API_URL`;
  - `NEXT_PUBLIC_SOCKET_URL`;
  - `BACKEND_API_ORIGIN`.
- Các Vercel API project cũ đã disconnect khỏi Git repository. Dấu đỏ lịch sử
  trong commit/check cũ không phản ánh Web Admin CI/CD hiện tại.
- Tài liệu: `D:\Desktop\sep\docs\WEB_ADMIN_CICD.md`.

### Mobile CI — DONE

- Workflow: `.github/workflows/mobile-ci.yml`.
- Tự chạy khi `push` hoặc `pull_request`.
- Các bước chính:
  - `flutter analyze --no-fatal-infos`;
  - `flutter test`;
  - build APK debug;
  - upload build artifact.
- Run gần nhất đã kiểm tra: pass.

### Android signed release, Google Drive và QR — DONE

- Workflow: `.github/workflows/android-release.yml`.
- Có thể chạy:
  - thủ công bằng `workflow_dispatch`; hoặc
  - tự động khi push tag `v*`.
- Release keystore được giữ bên ngoài repository:
  `D:\Desktop\FamilyCare-Release-Keys\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình, chỉ ghi tên, không ghi giá trị:
  - `ANDROID_KEYSTORE_BASE64`;
  - `ANDROID_KEYSTORE_PASSWORD`;
  - `ANDROID_KEY_ALIAS`;
  - `ANDROID_KEY_PASSWORD`;
  - `GDRIVE_CLIENT_ID`;
  - `GDRIVE_CLIENT_SECRET`;
  - `GDRIVE_REFRESH_TOKEN`;
  - `GDRIVE_FOLDER_ID`.
- Google Drive dùng **OAuth cá nhân**, không còn dùng Service Account.
- Google Cloud project: `FamilyCare-Mobile-Release`.
- Google Drive API đã bật; OAuth app/client đã cấu hình.
- Folder Drive đích: `FamilyCare-APK-Releases`.
- Android Release run thành công:
  - run ID: `29675484478`;
  - source: `main` tại merge commit `5fe0708`;
  - status: Success;
  - artifacts: 2;
  - signed APK: `FamilyCare-1.0.0-3.apk`;
  - APK đã upload vào Google Drive;
  - QR tải APK đã được tạo.
- Artifact trực tiếp:
  - QR:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438908227`;
  - signed APK:
    `https://github.com/16-Doffy/SEP-Family-Care-Mobile/actions/runs/29675484478/artifacts/8438906932`.
- QR hiện được upload lên GitHub Actions artifact. Nếu muốn ảnh QR cũng nằm
  trong Google Drive thì upload thủ công, hoặc bổ sung một bước upload QR vào
  workflow ở lần cải tiến sau.
- Tài liệu: `docs/RELEASE_ANDROID.md`.

### Hành vi release về sau

- Không cần cấu hình lại Google Cloud, OAuth, GitHub Secrets hoặc keystore.
- Mỗi commit/PR thông thường chỉ chạy Mobile CI; không phát hành APK để tránh
  tạo quá nhiều bản release.
- Khi cần phát hành thủ công:
  1. Actions → Android Release → Run workflow;
  2. chọn `main`;
  3. nhập version hoặc để trống để dùng version trong `pubspec.yaml`;
  4. bật `Upload APK to Google Drive and generate a QR code`;
  5. chạy workflow.
- Muốn tag release tự upload Drive, tạo Repository Variable:
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó push tag, ví dụ `v1.0.1`.
- Không tái sử dụng/version-overwrite tùy tiện. Phải backup đúng release
  keystore; mất/đổi keystore có thể làm APK mới không cập nhật đè lên bản cũ.

### Bảo mật và dữ liệu nhạy cảm

- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, OAuth
  Client Secret, refresh/access token, mật khẩu hoặc Base64 keystore.
- GitHub Secrets/Variables là cấu hình ngoài Git; không ghi giá trị vào handoff.
- Bảo mật nhiều Admin phải do BE enforce:
  - RBAC/permission server-side cho mọi `/admin/*`;
  - không tin role do FE gửi;
  - session revocation, audit log, rate limit và MFA nếu áp dụng;
  - kiểm thử `401`/`403` và nhiều Admin độc lập.
- Checklist: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

### Việc còn lại/khuyến nghị

1. Quét QR bằng thiết bị Android, tải/cài APK và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile.
2. Backup release keystore ở ít nhất hai nơi an toàn; lưu mật khẩu trong
   password manager.
3. Tùy chọn đặt `GDRIVE_UPLOAD_ON_TAG=true` nếu nhóm muốn tag release tự upload
   Drive.
4. Tùy chọn cập nhật workflow để upload cả ảnh QR lên Google Drive.
5. Nếu cần iOS native: chuẩn bị macOS/Xcode, Apple Developer, signing và
   TestFlight. APK không cài được trên iPhone; hiện dùng Web/PWA fallback.
6. Tiếp tục làm việc với BE về checklist bảo mật nhiều Admin và hợp đồng
   Notifications realtime.

### Audit API và flow FE — tiếp tục ở phiên sau

- **Mục tiêu:** audit toàn diện Mobile Flutter theo Swagger production, SRS, UC
  Flow Tracker và báo cáo đề tài; không chỉ kiểm tra tên endpoint mà phải đối
  chiếu request/response DTO, role/permission, state transition và UI flow.
- **Nguồn cần dùng:** Swagger live
  `https://api.familycare-digital.com/api/docs` (OpenAPI:
  `/api/docs-json`), cùng các tài liệu ngoài workspace:
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_GSU26SE042_FAMILY_CARE_DIGITAL_FAMILY_MANAGEMENT_SO_HUYNX.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\Report3_Software Requirement Specification.docx`;
  - `D:\Desktop\BÁO-CÁO-NEW\SU26SE032_FamilyCare_UC_Flow_Tracker (2).xlsx`.
  `FinalReport_Template (1).docx` là template tham khảo, không dùng làm nguồn
  nghiệp vụ chính.
- **Kết quả đã có trước khi tạm dừng:** Swagger production hiện có endpoint
  location sharing chuẩn theo family (`GET /families/{familyId}/members/locations`,
  `POST /families/{familyId}/locations`, `PATCH /families/{familyId}/members/me/location-sharing`),
  trong khi `lib/providers/gps_provider.dart` vẫn gọi các path cũ `/location/*`.
  Đây là lỗi FE cần sửa và test trong phiên audit kế tiếp; **chưa sửa/commit**.
- **Cách bàn giao:** sửa các lỗi FE xác định được và chạy analyze/test; các
  thiếu/sai contract hoặc lỗi runtime của BE phải lập danh sách gửi BE với
  endpoint, payload/response thực tế, role bị ảnh hưởng và bước tái hiện.

## Snapshot 2026-07-18 — lịch sử

### Phạm vi hệ thống

- Mobile Flutter: `D:\Desktop\mobile-sep` — Family Manager, Deputy Member,
  Family Member và Wear OS.
- Admin Web: `D:\Desktop\sep` — `SYSTEM_ADMIN`, là Git repository độc lập.
- Hai frontend dùng chung backend và Swagger:
  `https://api.familycare-digital.com/api/docs`.
- OpenAPI JSON: `https://api.familycare-digital.com/api/docs-json`.
- API base Mobile: `https://api.familycare-digital.com/api/v1`.
- Swagger là nguồn chính cho endpoint/DTO/enum; SRS và Use Case Tracker là
  nguồn nghiệp vụ. Nếu khác nhau phải xác minh với BE, không fake API.
- `FinalReport_Template (1).docx` chứa nội dung TailorStore mẫu, không phải
  nghiệp vụ FamilyCare.

### Git và CI/CD Android

- Nhánh làm việc: `NDuy`.
- Commit thêm CI/release: `9c90557`.
- Commit sửa analyzer: `be9a470`.
- Pull Request `NDuy -> main` đã chạy cả push check và pull-request check xanh.
- Workflow Android Release đã chạy thành công trên `main`, head commit
  `1e7b12a`.
- Mobile CI tự chạy khi `push` hoặc `pull_request`:
  - `flutter analyze --no-fatal-infos`
  - `flutter test`
  - build APK debug
  - upload debug artifact
- Android Release chỉ chạy thủ công hoặc khi push tag `v*`; không tự phát hành
  sau mỗi commit thông thường.
- PR còn mang theo bốn sửa chức năng có chủ đích:
  - `lib/providers/family_provider.dart`
  - `lib/providers/task_provider.dart`
  - `lib/screens/parent/reward_management_screen.dart`
  - `lib/screens/parent/task_management_screen.dart`

### Release Android đã hoàn thành

- Release keystore được tạo bên ngoài repository:
  `D:\FamilyCare-Secrets\upload-keystore.jks`.
- Alias: `upload`.
- GitHub Repository Secrets đã cấu hình:
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- Không bao giờ ghi giá trị secrets, mật khẩu hoặc Base64 vào source/handoff.
- Signed APK build thành công:
  `FamilyCare-1.0.0-1.apk`.
- Artifact: `familycare-android-1.0.0`, kèm file `.sha256`.
- Run Android Release thành công: `29637020372`.
- APK chỉ cài được trên Android. iOS cần IPA + Apple signing + TestFlight,
  hoặc dùng Web/PWA làm phương án thay thế.
- Phải giữ và backup đúng keystore trên cho mọi release sau; đổi/mất keystore
  có thể khiến APK mới không cập nhật đè lên bản đã cài.

### Verification gần nhất

- Mobile CI push: pass.
- Mobile CI pull request: pass.
- Android signed release workflow: pass.
- `flutter test`: **55/55 pass**.
- Analyze: không có error/warning; còn 11 lint mức `info`.
- APK debug build: pass.
- APK signed release build: pass.
- Chưa xác nhận runtime signed APK trên thiết bị Android sau khi tải về.

### Trạng thái yêu cầu mentor

#### 1. Bảo mật khi mở rộng nhiều Admin — phụ thuộc BE

- **Chưa hoàn thành ở cấp hệ thống.** FE route guard chỉ hỗ trợ UX, không phải
  ranh giới bảo mật.
- Checklist cần gửi và thống nhất với BE nằm tại
  `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.
- BE cần:
  - cấm đăng ký công khai với `SYSTEM_ADMIN`;
  - tách `SUPER_ADMIN`/`ADMIN` hoặc permission tương đương;
  - enforce authorization trên mọi `/admin/*`, mặc định từ chối;
  - không tin role/permission do FE gửi;
  - bảo vệ Super Admin cuối cùng;
  - hỗ trợ MFA, rate limit, quản lý/thu hồi session;
  - vô hiệu session sau đổi mật khẩu, đổi role hoặc khóa tài khoản;
  - ghi audit log bất biến cho hành động nhạy cảm.
- QA cần kiểm tra `401` khi chưa đăng nhập, `403` với user không đủ quyền,
  session bị thu hồi sau khi Admin bị khóa/hạ quyền và audit actor tách biệt
  giữa nhiều Admin.

#### 3. FE setup CI/CD

- **Mobile Flutter: DONE.** CI khi push/PR đã chạy analyze, 55 tests, build
  debug APK và upload artifact; signed Android Release trên `main` đã pass.
- **Admin Web: CHƯA DONE.** Repo `D:\Desktop\sep` đã có Dockerfile/Compose
  nhưng chưa có GitHub Actions CI/CD riêng và chưa verify Docker image trên CI.
- Khi làm Admin Web CI/CD cần BE xác nhận API production URL, CORS, cookie
  domain và health-check endpoint.

#### 4. Dockerfile, APK, Google Drive, QR và iOS

- **Signed Android APK: DONE.** Đã build có chữ ký, tạo SHA-256 và upload
  GitHub Actions artifact.
- **Google Drive + QR: PARTIAL.** Workflow/code upload Drive và sinh QR đã có,
  nhưng chưa cấu hình service account/secrets và chưa chạy thử với Drive bật.
- Còn cần `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`, tùy chọn
  `GDRIVE_UPLOAD_ON_TAG=true`, sau đó chạy release và kiểm tra link/QR thật.
- **iOS: CHƯA DONE.** APK không cài được trên iPhone. Muốn phát hành iOS cần
  macOS/Xcode, Apple Developer, signing và TestFlight; nếu chưa có thì dùng
  Web/PWA. QR cuối nên điều hướng Android tới APK và iOS tới TestFlight/PWA.
- Dockerfile không dùng để tạo APK Flutter. Dockerfile hiện liên quan chủ yếu
  tới Admin Web/deployment web.

### Notifications realtime — hợp đồng BE mới nhận 2026-07-18

- Thông tin lịch sử phía dưới nói “BE chưa có FCM/WebSocket” đã **lỗi thời**.
- BE đã cung cấp hợp đồng Socket.IO namespace `/notifications`, tự join room
  `user:<userId>` bằng access token; không có Client → Server event.
- Server events:
  - `notification:new`;
  - `notification:unread-count`;
  - `notification:error`.
- REST notification vẫn dùng để list, lấy unread count, mark read/read-all.
- FCM token theo user/device:
  - `POST /api/v1/devices/tokens`;
  - `DELETE /api/v1/devices/tokens/:token` khi logout.
- `notification:new.id != null`: notification persisted, được thêm vào list và
  badge. `id == null`: push-only, chỉ toast/banner tức thời, không thêm list và
  không tăng badge.
- CHAT hiện là push-only và FCM có thể chứa toàn bộ nội dung tin nhắn; cần chốt
  với BE/Product chính sách ẩn nội dung nhạy cảm trên lock screen.
- **FE chưa tích hợp Socket.IO/FCM theo hợp đồng mới.** Polling 15 giây trong
  snapshot lịch sử chỉ là giải pháp tạm.
- Trước khi code cần BE xác nhận:
  1. URL Socket.IO production, Socket.IO path và server version;
  2. `/devices/tokens` đã deploy production và xuất hiện trên Swagger;
  3. thống nhất payload dùng `id` hay `notificationId`;
  4. unread count là theo family hay tổng tài khoản;
  5. chiến lược REST resync sau reconnect để lấy sự kiện bị bỏ lỡ;
  6. Firebase Android config và APNs/iOS config;
  7. chính sách hiển thị nội dung CHAT trên lock screen;
  8. test account/kịch bản token hết hạn, nhiều thiết bị và bị xóa khỏi family.

### Việc còn lại, theo thứ tự

1. Cài `FamilyCare-1.0.0-1.apk` trên Android và smoke-test login, refresh,
   role routing, Task, Finance, SOS và Profile. Nếu đang cài debug APK có chữ
   ký khác, phải gỡ bản debug trước (sẽ mất dữ liệu local).
2. Backup keystore ở ít nhất hai nơi an toàn và lưu mật khẩu trong password
   manager.
3. Cấu hình Google Drive + QR:
   - tạo Google Cloud service account;
   - bật Google Drive API;
   - share folder đích cho service-account email;
   - thêm `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`;
   - tùy chọn variable `GDRIVE_UPLOAD_ON_TAG=true`;
   - chạy Android Release với Drive upload bật.
4. Mở workspace Admin `D:\Desktop\sep` và thêm CI/CD riêng cho Next.js/Docker.
   Admin repo đã có `apps/web/Dockerfile`, `apps/api/Dockerfile`,
   `docker-compose.yml`, `docker-compose.prod.yml` nhưng chưa có GitHub Actions.
5. Gửi `docs/BE_ADMIN_SECURITY_CHECKLIST.md` cho BE. Bảo mật nhiều Admin phải
   được enforce ở backend; FE route guard không phải security boundary.
6. Gửi các câu hỏi Notifications realtime ở trên cho BE, sau đó tích hợp
   Socket.IO, REST resync và FCM token lifecycle vào Mobile.
7. Chốt phương án iOS: TestFlight nếu có Apple Developer + macOS/Xcode;
   nếu chưa có thì dùng Web/PWA cho thiết bị iPhone.

### Trạng thái local và quy tắc bàn giao

- Tài khoản/window Codex này chỉ sửa code; commit/push thực hiện ở window Git
  khác và phải báo danh sách file trước khi stage.
- Lần kiểm tra gần nhất local chỉ còn untracked `.claude/` và
  `.vscode/settings.json`; không commit nếu nhóm chưa chủ đích dùng chung.
- Sau khi main đã merge, window Git nên đồng bộ bằng:
  `git fetch origin`, `git switch main`, `git pull origin main`.
- Không commit `.jks`, `.keystore`, `android/key.properties`, `.env`, Google
  credentials hoặc bất kỳ secret nào.
- File hướng dẫn release: `docs/RELEASE_ANDROID.md`.
- Checklist BE nhiều Admin: `docs/BE_ADMIN_SECURITY_CHECKLIST.md`.

> Phần từ “Cập nhật 2026-07-16” trở xuống là snapshot lịch sử chi tiết. Một số
> thông tin nhánh/commit trong phần lịch sử đã lỗi thời; dùng snapshot
> 2026-07-18 ở trên làm trạng thái hiện hành.

> ⚠️ IP cũ `103.110.84.66` đã BỎ hẳn — mọi tài liệu nhắc IP này đều lỗi thời.

---

## 🆕 Cập nhật 2026-07-16 (phiên hiện tại)

Sau khi FF `giap` lên `origin/main` (`93612a9`), đã tái hoà WIP + thêm cải tiến — **9 commit local, chưa push**:

- **Invite chuyển hẳn sang MÃ MỜI 8 KÝ TỰ** (main `3c5f9cb` bỏ luồng `/invitations/{token}` cũ). FE thêm **QR thật + scanner** (`qr_flutter`, `mobile_scanner`): màn Mời hiện mã + QR encode `familycare://app/join?code=`; màn Tham gia có nút "Quét mã QR" → tự điền mã → `previewInviteCode` → `requestJoinByCode`. Quyền camera đã thêm AndroidManifest.
- **Thông báo real-time (tạm, không cần BE)**: `FamilyShell` poll toàn cục **15s** (`fetchAlerts` + `fetchNotifications`), dừng khi app nền, fetch lại khi resume. **Badge số** chưa đọc trên chuông 2 home. (BE chưa có FCM/WebSocket.)
- **SOS Response Timeline**: màn chi tiết cảnh báo (icon ℹ️) dựng timeline phản hồi từ `fetchAlertDetail().responses` — header đỏ, vị trí + mini-map, node 🚨→👀/🚗/🆘/✅→✔/✖. Parse phòng thủ (schema `responses[]` chưa document).
- **Home "Trạng thái gia đình"**: `widgets/family_status_card.dart` từ `activeAlerts` (an toàn / ai đang SOS). Bản rút gọn — chưa gắn vị trí (chờ BE location).
- **Family Map**: parse vị trí phòng thủ; **fix code chết `_pins`** trong `_locateMe`; **che raw "Cannot GET /location/family"** bằng note "🚧 đang phát triển" (cờ `sharingUnavailable`); khôi phục ±accuracy pin Tôi.
- **Task**: lọc `isActive` ở picker giao việc & reassign (tránh gán nhầm member REMOVED).
- **BE đã fix (team xác nhận 07/16)**: góp mục tiêu bỏ `ledgerEntryId`, gán task theo `FamilyMember.id` + bỏ chặn role, proof URL tự sinh lại. FE vốn đã tương thích → không phải sửa thêm (trừ lọc isActive).
- **Báo cáo BE mới**: `BAO_CAO_BE_SOS_2026-07-16.md` — 3 EP location sharing (`GET /location/family`, `POST /location/update`, `PATCH /location/toggle`) + 3 điểm SOS-detail (schema `responses[]`, enum `ON_THE_WAY`, phone thành viên).
- **Model/Build**: `userType` (SYSTEM_ADMIN) tách khỏi `familyRole` (main `fc59c69`); `planCode` đổi **FREE|MONTHLY|YEARLY**; hạ AGP 9.0.1→8.11.1 + giảm gradle heap. Verify: **55/55 test pass**, analyze 0 error.
- **Kiểm chứng Swagger prod 16/07** (fetch trọn `docs-json`, so canonical với bản Tuần 9): **giống hệt 100%** (183 paths / 133 schemas) — BE chưa ship gì mới sau 15/07. Kết quả soi SOS schemas:
  - `responses[]` **ĐÃ được document** (`SosResponseResponseDto`): field chuẩn là **`responderMember`** `{displayName, familyRole, user{fullName, email, avatarUrl}}` + `responseType` + `respondedAt` + `message` → **FE đã sửa parse timeline** đưa `responderMember` lên đầu chuỗi fallback (trước đó thiếu key này → tên hiện "Thành viên").
  - `responseType` enum = `VIEWED|CONFIRM_SAFE|NEED_HELP|RESOLVED|CANCELED` — **xác nhận KHÔNG có `ON_THE_WAY`** → "Tôi đang đến" vẫn phải dựa text message (còn nợ BE).
  - `SosMemberUserResponseDto` **không có `phone`** → nút Gọi người khác vẫn chờ BE (còn nợ).
  - `status` alert có giá trị thứ 4 **`FALSE_ALARM`** — FE chưa có nhãn riêng (TODO nhỏ, hiện rơi về hiển thị raw).
  - `/location/family|toggle|update` **xác nhận không tồn tại** → Bug 1 báo cáo BE còn nguyên hiệu lực.

---

## Nguyên tắc làm việc (bắt buộc)

1. **Chỉ build trên endpoint ĐÃ TỒN TẠI trong Swagger live.** Field/response chưa rõ → đánh `[VERIFY]` hỏi Nghĩa, KHÔNG tự đoán.
2. **Giữ `API_DOCS.md` đồng bộ với code** mỗi khi wire endpoint mới.
3. **Không mock/fake call** cho tính năng BE chưa có endpoint — giữ placeholder UI.
4. Verify bằng **kịch bản thật** (chạy app đối chiếu BE) cho các luồng nhạy cảm, không chỉ tin unit test.

---

## Cấu trúc dự án (thực tế 2026-07-11)

```
lib/
├── main.dart · main_wear.dart (Wear OS entrypoint riêng — chưa có flavor build)
├── models/user.dart               (enum UserRole { manager, deputy, member } + capabilities)
├── navigation/
│   ├── app_router.dart            (go_router + computeRedirect thuần, unit-test được)
│   └── family_shell.dart          (bottom-nav shell dùng chung 3 role)
├── providers/                     (provider/ChangeNotifier)
│   ├── auth_provider.dart         family_provider.dart      invitation_provider.dart
│   ├── finance_provider.dart      finance_alert_provider.dart
│   ├── task_provider.dart         sos_provider.dart         notification_provider.dart
│   ├── wallet_provider.dart       money_provider.dart       support_request_provider.dart
│   └── gps_provider.dart          (location UI-only, BE chưa có endpoint độc lập)
├── screens/
│   ├── auth/   login · register · verify_email · forgot_password · family_setup · join_family
│   ├── parent/ (Manager/Deputy) home_dashboard · task_management · reward_management ·
│   │           wallet · finance_model · budget_plan(+detail) · financial_goal · goal_detail ·
│   │           goal_contribution · finance_reports · finance_alerts · support_request ·
│   │           subscription · member_list · invite_member · invitation_requests · calendar
│   ├── child/  (Member) child_home · child_tasks · child_wallet
│   └── shared/ profile · edit_profile · sos · notifications · chat* · album* · ai_assistant* ·
│               family_map* · payment_result · splash   (* = mock, BE chưa có endpoint)
├── services/api_client.dart       (singleton, Bearer + auto-refresh 401, unwrap {success,data})
├── theme/  app_colors.dart · app_theme.dart
├── utils/  validators.dart        (bộ Validators dùng chung — từ UI kit của main)
├── widgets/ app_input · money_input · empty_state · json_report_view · avatar_widget ·
│            ring_chart · waffle_chart · request_money_sheet
└── wear/   main_wear.dart + screens Wear OS (dùng chung provider)
```

---

## Trạng thái wiring — ĐÃ NỐI API THẬT

### Auth & Session
Login / register / logout / refresh / me — wired. Token qua `flutter_secure_storage`. `ApiClient` gắn `Bearer`, retry 1 lần khi 401 (refresh token), unwrap envelope `{ success, message, data }`.
- ✅ **Verify email OTP (BẮT BUỘC / mandatory)**: `POST /auth/verify-email {code}` + `/auth/resend-verification`. Router ép sang `/verify-email` khi `pendingEmailVerification && !hasFamily`. `POST /families` trả **403** nếu chưa verify — message thật là **tiếng Việt** ("Vui lòng xác thực tài khoản...") nên `createFamily` tin thẳng `statusCode==403` (KHÔNG check `contains('verif')` — bug đã sửa).
- ✅ **Quên mật khẩu** (2026-07-11, endpoint mới): `POST /auth/forgot-password {email}` → BE gửi OTP → `POST /auth/reset-password {email, code, newPassword}`. Màn `forgot_password_screen.dart`, link "Quên mật khẩu?" ở login.

### Role & Route
`familyRole` từ `/auth/me`: `FAMILY_MANAGER`→manager, `DEPUTY_MEMBER`→deputy, `FAMILY_MEMBER`→member. Capabilities trong `AppUser` — **hành động nhạy cảm KHÔNG dùng `isAdministrative` chung** mà tách riêng (`canInviteMembers`/`canRemoveMembers`/`canManageSubscription` chỉ Manager, đã verify BE trả 403 cho Deputy). Router guard chặn cross-shell.

### Family & Invitation — **MÃ MỜI 8 KÝ TỰ (main `3c5f9cb`, thay luồng token cũ)**
GET/PATCH `/families/{id}` (đổi tên), DELETE member (soft-delete, lọc `status==ACTIVE`). **Luồng mời mới kiểu Zalo/Discord** (`invitation_provider.dart` viết lại):
- Manager: `GET /families/{id}/invite-code` (mã hiện tại) · `POST .../invite-code/regenerate` (tạo/đổi mã, mã cũ vô hiệu ngay).
- Người xin vào: `GET /invite-codes/{code}` (preview, public) · `POST /invite-codes/{code}/join-requests` (gửi yêu cầu, chỉ cần đăng nhập, KHÔNG cần verify email) · `GET /me/join-requests` (poll trạng thái) · `POST /me/join-requests/{id}/cancel`.
- Manager duyệt: `GET /families/{id}/join-requests` · `POST .../{id}/approve` (chọn role+quan hệ) · `POST .../{id}/reject`. `InvitationRequestsScreen` (fetch 1 lần + refresh tay, chưa poll).
- Mã 8 ký tự alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (bỏ I/O/0/1). **FE thêm QR + scanner** (xem changelog 07/16). `savePendingInviteToken` giữ tên cũ nhưng giá trị nay là **mã** (không phải token).
- 🐛 Race-condition đã sửa: dialog "Đã gửi yêu cầu" refetch `refreshFamilyContext()` trước điều hướng (Manager có thể duyệt ngay lúc member còn ở dialog).
- ⚠️ **Chưa realtime** cho join-request (module notifications còn stub) → Manager phải bấm refresh; Member poll `/me/join-requests` ~12s khi mở "Yêu cầu của tôi".

### Finance (module sâu nhất — 42/42 endpoint mobile đã nối)
Overview · ledger · jars/models · categories · budget-plans (+lines +report +detail edit) · financial-goals (+detail +progress +allocations sửa/xóa) · **goal contribution plans** (suggestions/confirm/submit/approve/reject/shortage — `GoalContributionScreen`) · alerts (+detail +recompute) · monthly-finances/me · reports (planned-vs-actual, `FinanceReportsScreen`) · support-requests (+detail). Response schema chưa document → render qua `JsonReportView` generic.

### Tasks & Reward
Full CRUD task/recurring/schedule (+generate-assignments) · assignments (assign/reassign/start/cancel/detail) · submissions (+review) · proof upload · reward-setting (create/read/update/delete) · **`RewardManagementScreen`** (3 tab: Thanh toán/Tranh chấp/Báo bận). Enum reward settlement đúng BE: `PENDING_SETTLEMENT | WAITING_CONFIRMATION | SETTLED | DISPUTED | CANCELED`. Score/XP tính từ task status thật — **không có endpoint gamification**.
- Còn thiếu UI: `PATCH/DELETE tasks/proofs/{proofId}` (luồng upload+submit gộp 1 lần, chưa có bước sửa proof).

### SOS (10 operations)
Create alert · GET list/detail · respond (`responseType`) · confirm-safety · resolve/cancel (Manager/Deputy) · **push location** + `locations/batch` (buffer offline, `pushLocationBatch` — chưa nối UI) + `location/current` (`fetchCurrentLocation`, đã gọi từ `sos_screen.dart`). Location streaming mỗi 20s khi alert active.
- ⚠️ 2 nhóm enum `sourceType` KHÁC nhau: alert = `MOBILE_APP/WEARABLE/SIMULATED_DEVICE`; location = `MOBILE_GPS/WEARABLE_GPS/SIMULATED_GPS`. Không lẫn.
- ✅ **2 fix từ main (2026-07-10, verify live BE)**: id đọc từ **`sosAlertId`** (không phải `id`) → sửa bug 404 "Tôi đang đến"; GPS treo → `timeout(10s)` + `getLastKnownPosition` + chốt cứng **15s** ở `_triggerSOS` (quá 15s vẫn gửi SOS không kèm toạ độ). `SosAlert` thêm `severity`/`resolutionNote`/`resolvedByName`.

### Chat gia đình — **[MỚI, wire thật 2026-07-11]**
BE ship 18 endpoint REST `/families/{fid}/chat/conversations/...` → FE wire xong (`chat_provider.dart` 517 dòng, `chat_screen.dart` viết lại). GROUP/PRIVATE · gửi ảnh (image_picker) · reaction · ghim · sửa/thu hồi · participants · read. `ChatProvider` đăng ký trong `main.dart`. **Transport REST polling** (`startPolling`/`stopPolling`), KHÔNG phải WebSocket.
- ✅ **Tin an toàn nhanh (2026-07-13)**: nút khiên trong input bar → sheet 4 tin mẫu, gửi `messageType: SOS_QUICK_MESSAGE` tường minh; bubble cam + nhãn "TIN AN TOÀN". Verify live BE echo đúng messageType.

### Album gia đình — **[MỚI 2026-07-13, BE ship 14 EP, swagger 223 ops]**
Giáp wire 13 EP (`album_provider.dart` + `album_screen.dart` viết lại: upload, thùng rác, tag, moderation per-media, filter). NDuy gán nốt `GET /albums/moderation` — hàng đợi kiểm duyệt toàn gia đình (nút 🛡️ AppBar, duyệt nhanh MARK_SAFE/KEEP_FLAGGED, hiển thị riskScore AI). File URL là signed URL có hạn.
- **Mọi role đều dùng được album** (verify live: member GET media 200, moderation 403 đúng thiết kế). Manager: tab shell `/manager/album`. Deputy/Member: route phẳng `/album` — entry từ trang Tôi ("Album gia đình") + shortcut 🖼️ ở Trang chủ member. Màn album tự gate nút kiểm duyệt theo `isAdministrative`.

### Xem tài chính member — **[MỚI 2026-07-13, UC gap #5 BE đã đáp ứng]**
3 EP mới: `monthly-finances/members/{memberId}` + `monthly-summary/me|members/{memberId}` (đều cần `month&year`, verify live OK). `MemberFinanceScreen` (route `/manager/member-finance?memberId&name`): chọn tháng, 3 card khai báo/quỹ gia đình/mục tiêu; field private BE trả null → hiện "🔒 Riêng tư". Entry: Member List → sheet "Xem tài chính tháng" (gate `canManageFinance` — Manager/Deputy; member route bị guard chặn, member xem của mình trong ví riêng).

### Notifications
GET list · PATCH read · read-all. Tap routing theo `referenceType`. Field id thật là `notificationId`.

### Subscription
GET current · GET `/subscription-plans` · POST `/checkout {planCode}`. `planCode` chuẩn **`FREE | MONTHLY | YEARLY`** (main `359d12b` — đổi từ FREE|PLUS|PREMIUM). Nút Nâng cấp → checkout → `url_launcher` mở Stripe.
- ✅ **UX hạ gói (2026-07-13)**: CTA đổi thành "Hạ xuống {tên}" khi gói rẻ hơn gói đang dùng (so sánh `priceValue`) + dialog xác nhận trước checkout.
- ✅ **Hết nháy FREE (main `627b2c4`)**: `_currentPlan` nullable = đang tải → hiện spinner, khoá checkout khi chưa biết gói (trước bị nháy FREE 2–3s).
- ⚠️ `[VERIFY]` response `/checkout` **vẫn trống schema** trong Swagger — FE hiện chỉ đọc `data['checkoutUrl']` (chưa fallback `url`/`sessionId`). Hỏi Nghĩa field thật + luồng chọn FREE (downgrade?).

---

## Backend Gaps — KHÔNG fake call

Swagger live vẫn **0 endpoint** cho (Chat & Album nay đã CÓ — xem các mục trên):
- **AI assistant**, **Calendar events** (`/events`), **FCM token** push (→ đang poll tạm ở `FamilyShell`)
- **Location sharing độc lập** ngoài SOS (chỉ có toạ độ trong ngữ cảnh 1 alert) → **đã có báo cáo chính thức `BAO_CAO_BE_SOS_2026-07-16.md`**; FE che raw 404 bằng note "đang phát triển".
- **PATCH /auth/me** (sửa profile), **role management user-facing** (UC18)
- **Wearable pairing / SOS device settings**
- ⚠️ **SOS alert detail** thiếu document `responses[]` + enum "đang đến" + phone thành viên (3 câu trong báo cáo trên).

25 endpoint `/admin/*` mới (audit-logs, backups, docker infra, revenue, provisioning...) thuộc **Admin Web**, ngoài phạm vi FE Mobile.

---

## `[VERIFY]` đang chờ Nghĩa

1. **[Payment]** `POST /subscription/checkout` trả field nào để redirect Stripe (`checkoutUrl`/`url`/`sessionId`)? Chọn FREE là downgrade riêng hay cũng qua `/checkout`?
2. **[Chat]** Transport hiện là REST polling — BE có kế hoạch chuyển WebSocket realtime không? Giới hạn `limit` khi load lịch sử, encode emoji trong URL reaction.
3. **[RESOLVED 2026-07-29 — Finance model / fund allocation]** BE đã đổi khóa
   chống trùng thành `familyId + periodMonth + periodYear`; đổi model không cho
   chia lại cùng kỳ. POST/GET history đã trả `createdAt`,
   `createdByMemberId`, `note`, sort mới nhất trước và giữ item legacy nullable.
   FE đã wire contract, xử lý 409, test mapping và kiểm tra runtime thành công.

---

## Verification (2026-07-16)

`flutter test` → **55/55 pass** · `flutter analyze lib` → **0 error** (11 info-lint pre-existing/từ main). Build APK debug OK (Gradle 9.1.0 / AGP 8.11.1 / Kotlin 2.3.20).
Test phủ: router redirect (verify mandatory), auth/role capabilities (+2 test mới từ main), register error mapping, SOS provider parse/guard. **Chưa verify runtime** (cần device): SOS Timeline khi có `responses[]` thật; badge/poll thông báo; quét QR mã mời.
- ⚠️ Windows build: cần **bật Developer Mode** (symlink cho plugin); nếu build lỗi lạ (BuildConfig exists / Dart compiler exited) → `flutter clean` (kill dart/java nếu `.dart_tool` bị khoá).

---

## Nhánh & Git

`giap` đã **FF tới `origin/main` (`93612a9`)** rồi chồng **9 commit local** (invite QR-code, poll+badge, map fix, SOS timeline, Home status, task isActive, map 404, build-config, docs). **Chưa push** (origin/giap còn ở `cb050e9`). Backup: `giap-backup-before-ff-20260715` (@cb050e9), `giap-backup-before-ff-20260711`, `giap-backup-20260710`.

## Next Suggested Work

1. ~~Push~~ ✅ **Đã push** `giap` + merge FF vào `main` và push `origin/main` (16/07).
2. Gửi `BAO_CAO_BE_SOS_2026-07-16.md` cho Nghĩa — còn nợ BE: **location 3 EP** (Bug 1) + **enum `ON_THE_WAY`** + **`phone` trong `SosMemberUserResponseDto`**. Kèm câu hỏi: fix gán task có áp cho `generate-assignments` (định kỳ) chưa.
3. **Verify runtime trên device**: quét QR mã mời (2 máy), badge/poll thông báo, SOS Timeline với alert có phản hồi thật (tên phải hiện đúng sau fix `responderMember`), block "Trạng thái gia đình".
4. Khi BE ship location: đổi path `GpsProvider` (parse đã sẵn) → mở marker nhiều thành viên + family cards có vị trí.
5. TODO nhỏ: nhãn hiển thị cho status **`FALSE_ALARM`** (detail sheet + alert card đang rơi về raw).
6. `[VERIFY]` tồn đọng: checkout field Stripe, chat WebSocket.
