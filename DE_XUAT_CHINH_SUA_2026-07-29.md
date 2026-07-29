# Đề xuất chỉnh sửa & xây dựng — 2026-07-29

**Căn cứ:** `origin/main` tại `bb368ac` · Swagger 28/07 · Discord (Nhật 21/7 + chốt fund-allocation 28/07).
**Đã verify bằng code/Swagger thật**, không suy đoán. Chỗ nào chưa verify được đều ghi rõ.

---

## Phần A — Đề xuất Backend

Xếp theo Rule 2: **Bắt buộc** (thiếu là nghiệp vụ sai/không dùng được) vs **Nên có** (UX tốt hơn, FE đã có đường tạm).

### A1. [Bắt buộc] Response schema cho `face-suggestions`

`GET /albums/media/{mediaId}/face-suggestions` vẫn chỉ có `"200": {"description": ""}` — không có schema.

**Hệ quả thật đã xảy ra:** gợi ý hiện ra nhưng **không có tên người**, phải parse phòng thủ 6 biến thể field
(`suggestedMemberName`/`matchedMemberName`/`memberName`/`displayName`/`fullName` + nested `suggestedMember.user`).
Tương tự `confidence` đang thử `confidence`/`score`/`similarity`/`matchScore`.

**Cần BE trả:**
```
GET /families/{familyId}/albums/media/{mediaId}/face-suggestions
→ { success, message, data: [{
     id, suggestedMemberId,
     suggestedMember: { id, displayName, user: { id, fullName, avatarUrl } },
     confidence,          // ghi rõ thang: 0..1 hay 0..100
     status               // ghi rõ enum đầy đủ
   }] }
```
Cần chốt thêm: tên field confidence chính thức, thang giá trị, và enum `status` sau khi confirm/reject.

### A2. [Bắt buộc] Thông báo khi có yêu cầu xin tiền

User đã report: *"Không hiển thị thông báo xin tiền"*. FE đã sửa phần danh sách không tự nạp lại,
nhưng **push notification thì FE không tự tạo được**.

Swagger có `GET /families/{familyId}/notifications` nhưng **không document `type` enum nào**, nên không
biết BE có phát notification cho `support-requests` hay không.

**Cần BE:**
1. Document enum `type` của notification (hiện FE không thể lọc/hiển thị icon theo loại).
2. Xác nhận `POST /finance/support-requests` có phát notification cho Manager/Deputy hay không. Nếu chưa thì bổ sung.
3. Tương tự cho `review` (thông báo lại cho người xin khi được duyệt/từ chối).

### A3. [Nên có] `byJar` trong spending summary vẫn là "Reserved"

`FinanceSpendingSummaryResponseDto.byJar` bị Swagger ghi `"description": "Reserved"`, ví dụ `[]`.

FE đang **tự tính** trong `lib/utils/jar_allocation.dart` (cộng `signedAmount < 0` theo `jarId`).
Chạy được, nhưng có 2 nguồn số liệu song song → nguy cơ lệch khi BE thêm rule mới (đúng như vụ
`ADJUSTMENT + MODEL_FUND_ALLOCATION` vừa rồi: FE phải tự biết loại entry này ra khỏi thu nhập).

**Đề nghị:** BE trả `byJar: [{ jarId, jarName, jarCode, allocationPercentage, plannedAmount, actualAmount }]`
để FE bỏ phần tự tính.

### A4. [Nên có] Đổi thành viên khi AI gợi ý sai

Hiện chỉ có `confirm` và `reject`. Muốn sửa người bị nhận diện sai, user phải `reject` rồi vào
"Gắn thẻ thành viên" gắn tay — 2 bước rời rạc. Đây là mục **8.4 trong Discord của Nhật** ("Chọn thành viên khác")
nhưng chưa có contract.

**Đề nghị:** `POST .../face-suggestions/{suggestionId}/confirm { taggedMemberId? }` — có `taggedMemberId`
thì gắn cho người đó thay vì người AI đoán.

### A5. [Nên có] Seed danh mục thu chi mặc định khi tạo gia đình

Lỗi *"Chưa phân loại được chi tiêu theo danh mục"* có nguyên nhân gốc: gia đình **không có danh mục nào**,
nên mọi ledger entry đều `categoryId = null` → báo cáo chỉ có một dòng "Chưa phân loại".

BE **đã có tiền lệ** làm việc này: `POST /finance/models` tự sinh hũ mặc định cho FIVE_JARS/EIGHTY_TWENTY.

**Đề nghị:** khi tạo family, seed sẵn một bộ danh mục cơ bản (Ăn uống, Đi lại, Học tập, Y tế, Hóa đơn,
Giải trí…) kèm `essentialType` phù hợp. Rẻ hơn nhiều so với bắt từng gia đình tự tạo trước khi ghi được giao dịch.

### A6. [Nên có] Quyền gỡ tag chưa được document

Response của `GET .../tags` không có field quyền nào trong Swagger. FE đang đọc
`permissions.canRemove`/`canRemove` nếu có, **thiếu thì fail-open** (cho bấm, để BE trả 403) — vì nếu
default `false` thì user mắc kẹt với tag sai. Đề nghị BE chốt và document field này.

### A7. [Nên có] Các endpoint còn thiếu

| Việc | Hiện trạng | Đề nghị |
|---|---|---|
| Sửa `relationship` của thành viên | Chỉ có admin API; `PATCH members/{userId}/role` chỉ nhận `familyRole` | `PATCH /families/{familyId}/members/{userId}` nhận `relationship`, `displayName` |
| Lịch sử tài chính theo tháng | FE loop từng tháng để vẽ chart | `GET /finance/monthly-finances/me/history?from=&to=` |
| Filter album | Có `taggedMemberId`; thiếu "chưa tag" và "có gợi ý AI" | thêm `untagged=true`, `hasFaceSuggestions=true` (mục 8.6 Discord) |
| `face-profiles/{memberId}/validate` | Không có response schema | Document `canEnroll`, `results[].reasonCode` |

---

## Phần B — Đề xuất Frontend

### P0 — Làm ngay (rủi ro tăng theo thời gian)

1. **Merge `origin/NDuy` (`6f8a744` "gắn giao dịch chi vào đúng hũ đang áp dụng") vào main.**
   Commit này đụng **đúng vùng hũ** mà `main` vừa đổi. Càng để lâu càng khó merge.
2. **Push commit `62b97a7`** (bắt kịp 2 thay đổi BE của fund-allocation). Đang nằm local, và Duy đang
   sửa cùng file `finance_model_screen.dart`.

### P1 — Yêu cầu nhóm đã nêu 21/7, chưa làm

Verify trong code: 3 việc chat dưới đây **BE đã có endpoint, FE chưa dùng**.

| Việc | Endpoint BE | Hiện trạng FE |
|---|---|---|
| Tìm kiếm tin nhắn | `GET .../messages?q=` | **Chưa dùng** `q` |
| Màn "Tin đã ghim" | `GET .../pinned-messages` | **Chưa gọi** (ghim/bỏ ghim thì đã có) |
| Thư viện ảnh/file/link đã gửi | Lọc từ `messages`/`attachments` | **Chưa có màn** |
| Đổi tên nhóm chat | `PATCH .../conversations/{id}` | ✅ Đã có |

Ngoài ra còn 2 việc UI Nhật nêu, cần bạn xác nhận mức độ ưu tiên vì là việc thẩm mỹ, không phải lỗi:
- **Sửa icon trợ lý AI.**
- **Cải thiện UI SOS** ("thay vì 1 nút đang quá đơn giản"). Lưu ý `sos_screen.dart` đã 2030 dòng —
  nên làm rõ Nhật muốn sửa *màn SOS* hay *nút SOS trên thanh tab* trước khi sửa.

### P2 — Hoàn thiện phần vừa làm

1. **Hiện tên người chia quỹ.** Vừa parse `createdByMemberId` nhưng UI chỉ hiện giờ; nên resolve sang
   tên qua `FamilyProvider` cho dễ đọc.
2. **Nút "Phân bổ số dư vào mục tiêu" ở màn tổng quan finance.** Hiện chỉ có ở `goal_detail_screen` —
   Discord đề nghị có ở cả màn tổng quan.
3. **Bỏ phần FE tự tính hũ** nếu BE làm A3.

---

## Phần C — Việc quy trình, không phải code

### C1. Chốt lại nghiệp vụ auto-tag khuôn mặt

Ngày 28/07 có **hai quyết định ngược nhau** trên cùng một tính năng:
- Yêu cầu nội bộ: tự gắn thẻ khi AI chắc chắn ≥80%, không cần bấm duyệt → đã code và push (`eb9bb36`).
- Duy revert trên `main`, ghi trong API_DOCS: *"Face suggestion luôn cần người dùng xác nhận… đúng flow
  nghiệp vụ đã chốt"* — khớp Discord của Nhật: *"Chỉ khi user xác nhận thì mới tạo tag chính thức."*

Hiện đang **giữ theo Duy** (không auto-tag). Cần nói rõ trong nhóm để không revert qua lại. Nếu nhóm
đồng ý mở auto-tag thì nên gắn kèm điều kiện: chỉ khi BE trả `confidence` thật (xem A1), có ngưỡng
cấu hình được, và tag sai phải gỡ được (đã fail-open ở A6).

### C2. Một bài học nên ghi lại

Vụ `ADJUSTMENT + MODEL_FUND_ALLOCATION`: nếu FE không chủ động loại loại entry này, **mỗi lần chia quỹ
sẽ làm tổng quỹ phình lên đúng bằng số tiền chia** — mà không có lỗi HTTP nào báo. Cùng loại lỗi với vụ
`totals['income']` vs `incomeAmount` (sai tên field → hiện 0đ, không có lỗi).

**Rút ra:** với API tài chính, mỗi lần BE thêm `sourceType`/`entryType` mới thì phải rà lại chiều tiền,
không mặc định entry mới là trung tính.

---

## Ưu tiên đề nghị

1. **A2** (thông báo xin tiền) — user đã report, FE không tự làm được.
2. **A1** (schema face-suggestions) — đang parse đoán, đã gây bug mất tên.
3. **P0** (merge NDuy + push) — nợ kỹ thuật, càng để càng đắt.
4. **A5** (seed danh mục) — mở khoá toàn bộ báo cáo theo danh mục, cost BE thấp.
5. **P1 chat** — endpoint có sẵn, chỉ thiếu UI.
