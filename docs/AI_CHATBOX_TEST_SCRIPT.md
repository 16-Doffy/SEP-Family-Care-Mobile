# Kịch bản test Trợ lý AI (AI Chatbox)

Tổng hợp câu mẫu để test thủ công màn Trợ lý AI, dựa theo `AI_HANDOFF_LATEST.md`
+ `API_DOCS.md` (mục AI Chatbot) tính đến 2026-08-09. Test bằng tài khoản
**Manager** hoặc **Deputy** trước (đủ quyền ghi tài chính), sau đó lặp lại vài
câu bằng **Member** để test phân quyền.

> Sau mỗi bước Xác nhận, kiểm tra thêm: banner đổi đúng màu (xanh = đã xác
> nhận, xám = đã từ chối, đỏ = hết hạn), dữ liệu thật đã tạo đúng ở màn tương
> ứng (Sổ thu chi / Ngân sách / Nhiệm vụ / Lịch), và field liên quan đến danh
> mục (nếu có) hiện **tên** chứ không phải UUID thô.

## 0. Daily Brief + chat thường

1. Mở màn Trợ lý AI lần đầu trong ngày → kiểm tra Daily Brief hiện đúng, không
   bị màn trắng giữa chừng, không tự cuộn lệch vị trí.
2. `Tóm tắt tình hình tài chính gia đình tháng này` → kiểm tra markdown
   (`**...**`) render đậm, không hiện dấu `*` thô.
3. `Gia đình tôi có bao nhiêu thành viên?` → kiểm tra AI trả đúng **tên hiển
   thị thật** của từng người, không phải ID hay "chưa có tên".

## 1. `CREATE_LEDGER_ENTRY` (khoản thu/chi) — Manager/Deputy only

4. `Ghi khoản chi 50.000đ tiền ăn sáng hôm nay` → thẻ "Tạo khoản chi", field
   Danh mục (nếu AI tự gán) hiện **tên danh mục**, không phải UUID.
5. `Ghi khoản thu 200.000đ tiền lì xì` → thẻ phải là "Tạo khoản thu" (tiêu đề
   phân biệt theo `Loại`, không dùng chung "Tạo giao dịch tài chính").
6. `Ghi khoản chi 500.000đ tiền đặt cọc du lịch ngay bây giờ` → kiểm tra giờ
   hiển thị đúng giờ thật lúc bấm gửi (BE báo đã fix lệch giờ "ngay bây giờ").
7. `Ghi khoản chi 1.000.000đ tiền học phí tuần này` → kiểm tra ngày suy luận
   từ "tuần này" có đúng không (trước đó từng lệch 3 ngày).
8. Gửi câu thiếu số tiền: `Ghi khoản chi tiền ăn sáng` → AI phải **hỏi lại**,
   không tự bịa số tiền.
9. Sau khi Xác nhận bước 4 → vào Sổ thu chi kiểm tra khoản mới nổi lên **trang
   đầu** (phân trang theo `createdAt desc`).

## 2. `CREATE_BUDGET_PLAN` / `CREATE_BUDGET_LINE`

10. `Tạo kế hoạch ngân sách tháng 9 cho gia đình` → thẻ "Tạo kế hoạch ngân
    sách", icon riêng.
11. `Thêm dòng ngân sách 2.000.000đ cho mục ăn uống` → xác nhận trước đó đã
    chạy đúng, test lại để phát hiện hồi quy.

## 3. Action tài chính mới + chia quỹ

Các action dưới đây đã từng sinh `pendingAction` đúng. Riêng chia quỹ cần test
cả quyền AI, quỹ khả dụng theo kỳ và rule một lần/kỳ.

12. `CREATE_FINANCIAL_GOAL` — `Tạo mục tiêu tiết kiệm 20.000.000đ để mua xe
    máy, hạn tháng 12 năm nay`
13. `CREATE_GOAL_ALLOCATION` — `Phân bổ 500.000đ mỗi tháng vào mục tiêu tiết
    kiệm mua xe máy`
14. `CREATE_GOAL_CONTRIBUTION_PLAN` — `Lập kế hoạch đóng góp hàng tháng
    2.000.000đ cho mục tiêu tiết kiệm mua xe`
15. `ALLOCATE_FUND_BY_MODEL` — `Chia quỹ tháng này theo mô hình tài chính đang
    áp dụng`.
16. Test kỳ đã chia: `Chia quỹ tháng 8 năm 2026 theo mô hình tài chính đang áp
    dụng với tổng tiền 100.000đ` → banner phải nói mỗi kỳ chỉ chia một lần.
17. Test kỳ mới: tạo khoản thu và xác nhận trước, ví dụ `Ghi khoản thu
    500.000đ quỹ thử nghiệm ngày 01/09/2026`; sau đó `Chia quỹ tháng 9 năm 2026
    theo mô hình tài chính đang áp dụng với tổng tiền 100.000đ`. Nếu AI trả
    “không có quyền” bằng Manager/Deputy, đây là hồi quy BE. Nếu confirm báo
    thiếu quỹ, banner phải nêu số yêu cầu, quỹ khả dụng và đúng kỳ BE trả về.

→ Ghi lại nguyên văn câu trả lời của AI cho từng câu (có/không có thẻ), mã lỗi
nếu có, và ảnh chụp để báo BE kèm bằng chứng.

## 4. `CREATE_TASK`

18. `Tạo nhiệm vụ đưa con đi học lúc 7h sáng mai, giao cho [tên thành viên]`
    → field trong preview dùng tên **`task`**, kiểm tra hiển thị đúng nội
    dung công việc (không rỗng).
19. Xác nhận → vào danh sách Nhiệm vụ kiểm tra đã tạo đúng người được giao.

## 5. `CREATE_CALENDAR_EVENT`

20. `Tạo lịch họp gia đình cuối tuần này lúc 19h tại nhà` → kiểm tra field
    ngày giờ không hiện chuỗi ISO thô, mà format người đọc được.
21. Xác nhận → vào Lịch kiểm tra sự kiện xuất hiện đúng **tháng của
    `startTime`** (không phải tháng hiện tại nếu event ở tháng sau).
22. Luồng nhiều lượt: `Hãy đề xuất lịch đi chơi cuối tuần này` → trả lời
    giờ/địa điểm khi AI hỏi thêm → card phải là thứ Bảy/Chủ Nhật 15–16/08/2026,
    không phải 13/08/2026.

## 6. `ACTION_PLAN_CARD` — kế hoạch nhiều bước

23. `Giúp tôi chuẩn bị cho chuyến du lịch: tạo lịch đi chơi cuối tuần này và
    ghi khoản chi 500.000đ tiền đặt cọc` → phải ra **đúng 1 tin nhắn** (1
    avatar AI) chứa 2 thẻ xếp chồng.
24. Trong thẻ trên: Xác nhận thẻ lịch trước, để thẻ khoản chi ở trạng thái chờ
    → kiểm tra thẻ khoản chi **không bị ảnh hưởng**, vẫn "Chờ xác nhận".
25. Từ chối toàn bộ các bước còn lại trong 1 plan khác → kiểm tra ra đúng 1
    thẻ tổng kết "Kế hoạch đã hủy".

## 7. Phân quyền theo role

26. Đăng nhập bằng **Member** (không phải Manager/Deputy), gửi câu ở mục 1
    (`Ghi khoản chi 50.000đ...`) → AI phải **từ chối kèm câu giải thích có
    dấu tiếng Việt đầy đủ** ("Bạn không có quyền... nhờ Trưởng/Phó nhóm"),
    không trả về `pendingAction`.
27. Kiểm tra màn Trợ lý AI của Member **không hiện chip gợi ý** tạo khoản
    thu/chi (đã ẩn sẵn ở FE).

## 8. Xác nhận / Từ chối / Hết hạn (outcome màu)

28. Với 1 đề xuất bất kỳ: bấm **Xác nhận** → banner xanh, đúng nội dung kết
    quả (không còn câu "xin vui lòng xác nhận" cũ).
29. Với 1 đề xuất khác: bấm **Hủy đề xuất** → banner **xám**, không rơi về
    thẻ "Phân tích tài chính" chung chung.
30. Chờ một đề xuất hết hạn (hoặc test với `expiresAt` gần) → banner **đỏ**
    "Hết hạn".
31. Bấm nút **"Sửa"** trên 1 thẻ đang chờ → xác nhận hành vi là từ chối đề
    xuất hiện tại rồi để gõ lại (không có form prefill riêng, đây là hành vi
    đã chốt với BE, không phải bug).

## 9. Regression nhanh (chạy lại mỗi khi có bản mới)

32. `Rửa bát` (nhiệm vụ đơn giản) + khoản chi 50k — xác nhận/từ chối vẫn ra
    banner đúng màu.
33. Gửi liên tiếp 2-3 câu tạo khoản chi/thu ngẫu nhiên (dùng chip gợi ý random
    `_randomLedgerPrompt`) — kiểm tra không bị lặp lại y hệt, có trộn cả ví dụ
    thu (lương/thưởng/lì xì) lẫn chi.

---

**Khi test xong**, đối chiếu kết quả với mục "Cần báo BE" đang mở trong
`AI_HANDOFF_LATEST.md` (mục “Cập nhật BE 2026-08-10”) — câu nào vẫn
lỗi thì note lại nguyên văn phản hồi AI + ảnh chụp để cập nhật handoff.
