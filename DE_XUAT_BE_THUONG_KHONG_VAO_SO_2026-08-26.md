# Đề xuất BE — Thưởng nhiệm vụ quyết toán xong nhưng KHÔNG vào sổ thu chi

> ## ✅ BE ĐÃ TRẢ LỜI (26/08/2026) — chốt Phase 1
>
> BE đồng ý làm **Hướng 1** ở mức Phase 1: khi Member `confirm-received` thành
> công và settlement chuyển `SETTLED`, BE tự tạo `LedgerEntry` trong **sổ quỹ
> gia đình**:
>
> | Trường | Giá trị |
> |---|---|
> | `entryType` | `REWARD` |
> | `sourceType` | `TASK_REWARD_SETTLEMENT` |
> | `sourceId` | `settlementId` |
> | `description` | `Thưởng nhiệm vụ: {task.title}` |
> | `entryDate` | `confirmedAt` |
>
> Có **idempotency** — gọi lại/đồng bộ lại không tạo trùng. Đây chính là thứ FE
> lo nhất ở mục 3, coi như đã giải quyết.
>
> **Khác biệt so với đề xuất ban đầu:** Phase 1 **KHÔNG** cộng vào
> `MemberMonthlyFinance.actualIncome`, vì BE giải thích `actualIncome` là **số
> kê khai tài chính tháng của cá nhân**, không phải sổ giao dịch cá nhân. Tức là
> câu hỏi 3 ở mục 6 đã có đáp án: **ghi vào quỹ chung gia đình**, không vào thu
> nhập cá nhân.
>
> **Trạng thái triển khai:** đo lúc 26/08 sau khi BE trả lời — **chưa deploy**
> (sổ quỹ vẫn 0 entry `REWARD`, chưa có `sourceType=TASK_REWARD_SETTLEMENT`
> trong dữ liệu thật; các sourceType hiện có: `GOAL_CONTRIBUTION_PLAN`,
> `GOAL_QUICK_CONTRIBUTION`, `MONTHLY_SURPLUS_TO_GOAL`, `MODEL_FUND_ALLOCATION`).
>
> **FE đã chuẩn bị sẵn:** thêm icon cho `entryType=REWARD` trong sổ thu chi để
> BE ship phát là hiện đúng ngay; câu cảnh báo ở hộp thoại "Đánh dấu đã trả" đã
> sửa thành *"không cộng vào thu nhập cá nhân đã khai của thành viên"* — đúng cả
> trước lẫn sau khi Phase 1 lên.
>
> **Còn treo — cần BE chốt thêm:** settlement response có trả thẳng
> `ledgerEntryId` không? Nếu không, FE phải tự dò ngược bằng
> `sourceType=TASK_REWARD_SETTLEMENT` + `sourceId=settlementId` để biết khoản
> nào đã hạch toán. Dò ngược vẫn chạy được nhưng tốn thêm request và không chắc
> chắn bằng.

**Ngày:** 26/08/2026
**Mức độ:** **Bắt buộc** (thiếu mảnh nghiệp vụ, không phải thiếu UI)
**Người kiểm chứng:** FE, test bằng dữ liệu thật trên gia đình `NDuy`
(`b0cc7942-2a29-42f0-a63b-713bc98295f1`), API production.

---

## 1. Tóm tắt

Luồng thưởng chạy **đúng về mặt trạng thái** (đã test 19/19 bước pass), nhưng khi
một khoản thưởng đi tới `SETTLED`, **không có bất kỳ giao dịch tài chính nào được
tạo ra ở bất cứ đâu**. Tiền thưởng 50.000đ "biến mất" khỏi hệ thống sổ sách:

- Member không thấy khoản thu nào trong Sổ thu chi.
- Thu nhập cá nhân của Member không đổi.
- Sổ quỹ gia đình không có bút toán nào.

Hệ quả: người dùng bấm "Đánh dấu đã trả 50.000đ", hệ thống báo thành công, nhưng
50.000đ đó không tồn tại trong bất kỳ báo cáo tài chính nào.

---

## 2. Bằng chứng đo được (không phải suy đoán)

Kịch bản đã chạy thật, trọn vẹn:
Deputy tạo task → đặt thưởng 50.000đ → giao Member → Member nộp bài → Deputy duyệt
→ tạo settlement → `mark-paid` → Member `confirm-received` → **`status = SETTLED`**.

`settlementId = f24d0fb6-70f4-404b-bfab-9b876398ce1d`

### 2.1. Bản ghi settlement KHÔNG có field liên kết giao dịch

`GET /families/{familyId}/tasks/reward-settlements/{settlementId}` trả về đúng
các key sau:

```
id, taskSubmissionId, rewardSettingId, receiverMemberId, settledByMemberId,
amount, status, externalMethod, externalNote, settledAt, confirmedAt,
createdAt, updatedAt, receiverMember, settledByMember, task, submission
```

→ **Không có** `transactionId`, `ledgerEntryId`, `walletEntryId` hay bất kỳ field
nào trỏ tới một giao dịch tài chính.

### 2.2. Sổ quỹ gia đình không có bút toán nào

`GET /families/{familyId}/finance/ledger/entries?limit=100`:

| Kiểm tra | Kết quả |
|---|---|
| Số entry có `entryType = REWARD` | **0** |
| Entry tạo trong ngày 26/08 | 4 (đều là thu/chi khác: 30tr, 15tr, 10tr, 30tr) |
| Entry có `amount = 50000` | 3, nhưng **đều là giao dịch cũ** (29/07, 30/07, 09/08) |

→ Khoản thưởng vừa quyết toán **không sinh ra bút toán nào**.

### 2.3. Ví cá nhân của Member không đổi

`GET /families/{familyId}/finance/monthly-summary/me?month=8&year=2026`
(gọi bằng token của chính Member nhận thưởng):

```json
"actualIncome": 3000000,
"updatedAt": "2026-08-17T05:11:00.518Z"
```

→ `updatedAt` là **17/08**, tức hơn một tuần **trước** lần quyết toán hôm nay.
Thu nhập thực tế không hề tăng thêm 50.000đ.

---

## 3. Vì sao FE không tự xử lý được

FE **không thể** tự cộng tiền hay tự tạo giao dịch, vì:

1. Không có contract nào định nghĩa giao dịch thưởng trông như thế nào.
2. Không có liên kết `settlement ↔ transaction` → không có cách nào biết một
   khoản thưởng đã được hạch toán hay chưa. FE tự tạo sẽ **nhân đôi tiền** mỗi
   lần đồng bộ lại, hoặc tạo trùng khi người dùng mở lại màn hình.
3. Luồng tranh chấp cần **đảo bút toán**, mà FE không có quyền và cũng không nên
   là nơi quyết định việc này.

Ghi chú: `entryType` của BE **đã có sẵn giá trị `REWARD`** (theo
`CreateLedgerEntryDto`), nhưng thực tế không có bản ghi nào dùng nó — nghĩa là
mảnh nghiệp vụ này đã được thiết kế nhưng **chưa nối**.

---

## 4. Đề xuất

### Hướng 1 — Khuyến nghị: BE tự tạo giao dịch khi Member xác nhận

Khi `PATCH .../reward-settlements/{id}/confirm-received` thành công và settlement
chuyển sang `SETTLED`, BE tự tạo một giao dịch **thu nhập cá nhân** cho
`receiverMemberId`:

| Trường | Giá trị |
|---|---|
| Loại | Thu nhập (`entryType = REWARD`) |
| Số tiền | `settlement.amount` |
| Mô tả | `Thưởng nhiệm vụ: {task.title}` |
| Thời điểm | lúc Member xác nhận (`confirmedAt`) |
| Liên kết | `rewardSettlementId`, `taskId` |

Đồng thời **trả `transactionId` (hoặc `ledgerEntryId`) trong response settlement**
và trong `GET` chi tiết, để FE hiển thị được và biết khoản nào đã hạch toán.

Ưu điểm: ít thao tác, **không bao giờ cộng tiền khi còn tranh chấp**, vì chỉ
`SETTLED` mới sinh giao dịch.

### Hướng 2 — Linh hoạt hơn nhưng nhiều bước

Khi `mark-paid`, Manager/Deputy chọn thêm đích nhận (Ví cá nhân Member / ngoài hệ
thống). Nếu chọn ví cá nhân, BE tạo giao dịch ở trạng thái **chờ xác nhận**, chỉ
hạch toán thật khi Member `confirm-received`.

Nhược điểm: phát sinh trạng thái trung gian cho giao dịch, phức tạp hơn cho cả
hai phía.

**FE nghiêng về Hướng 1.**

---

## 5. Quy tắc bắt buộc cho luồng tranh chấp

Dù chọn hướng nào, phải đảm bảo:

| Tình huống | Trạng thái settlement | Giao dịch tài chính |
|---|---|---|
| Member tạo tranh chấp | `WAITING_CONFIRMATION` → `DISPUTED` | **Không** tạo, **không** đổi số dư |
| Manager/Deputy **chấp nhận** tranh chấp | `DISPUTED` → `PENDING_SETTLEMENT` | Nếu đã tạo giao dịch thì **phải đảo/huỷ** |
| Manager/Deputy **từ chối** tranh chấp | `DISPUTED` → `WAITING_CONFIRMATION` | Vẫn **chưa** cộng tiền, chờ Member xác nhận |
| Member xác nhận đã nhận | → `SETTLED` | **Chỉ lúc này** mới tạo giao dịch +tiền |

Ba chuyển trạng thái trên FE đã test thật và **BE đang chạy đúng** — chỉ thiếu
phần hạch toán tiền đi kèm.

---

## 6. Câu hỏi cần BE trả lời

1. Chọn Hướng 1 hay Hướng 2?
2. Tên field liên kết trả về trong settlement là gì (`transactionId` /
   `ledgerEntryId` / tên khác)?
3. Giao dịch thưởng tính vào **thu nhập cá nhân của Member** hay **quỹ chung gia
   đình**? (FE hiểu là thu nhập cá nhân — cần xác nhận.)
4. Với các khoản đã `SETTLED` **trước khi** sửa (dữ liệu cũ), BE có backfill giao
   dịch không, hay chấp nhận bỏ qua?

---

## 7. Phía FE sẽ làm gì

- **Chưa sửa gì về số liệu** cho tới khi BE chốt contract — tự cộng tiền ở FE là
  sai và sẽ tạo dữ liệu rác.
- Trước mắt bổ sung một dòng ghi chú trong hộp thoại "Đánh dấu đã trả thưởng",
  nói rõ đây là **ghi nhận việc trả tiền ngoài hệ thống**, chưa tự động ghi vào
  Sổ thu chi — để người dùng không hiểu nhầm.
- Khi BE xong: đọc field liên kết, hiển thị khoản thưởng trong Sổ thu chi của
  Member, và ghi lại mục này trong `API_DOCS.md`.
