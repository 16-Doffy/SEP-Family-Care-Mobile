# Đề xuất Backend — Luồng tài chính thu nhập → quỹ chung → xin tiền

> **Ngày:** 2026-07-22 · **Người đề xuất:** FE Mobile (Giáp) → gửi BE (Nhật)
> **Bối cảnh:** Team chốt lại luồng tài chính. Quỹ gia đình = tổng thu nhập các thành viên; xin tiền lấy từ quỹ chung.
> FE đã bỏ khái niệm "đóng góp quỹ" thủ công ở màn thành viên (vì income tự vào quỹ). Các mục dưới đây là **hành vi BE** cần bổ sung/xác nhận — FE chỉ hiển thị giá trị BE tính.

---

## 1. 🟠 Thu nhập thành viên → tự cộng vào quỹ chung

**Mong muốn:**
- Khi MEM khai báo `expectedIncome` (`POST/PUT /finance/monthly-finances/me`), số tiền đó **tự cộng vào quỹ gia đình** (không cần MEM `expectedSharedContribution` thủ công nữa).
- **Quỹ gia đình = tổng `expectedIncome` (hoặc `actualIncome`) của tất cả thành viên** trong tháng.

**Cần BE xác nhận / bổ sung:**
- `GET /finance/overview` trả `totalBalance`/`fund` = tổng thu nhập thành viên tháng hiện tại?
- Có endpoint cho **HOH xem breakdown thu nhập từng thành viên** không? (FE cần để hiển thị "thu nhập của từng thành viên"). Hiện có `GET /finance/monthly-summary/members/{memberId}` (HOH loop từng member) — **xác nhận HOH đọc được `expectedIncome`/`actualIncome` của member khác** (tôn trọng `incomeVisibility`).
- **`expectedSharedContribution` giờ dư thừa** — BE có thể bỏ qua/deprecate field này khi income đã tự vào quỹ.

---

## 2. 🟠 Xin tiền: trừ quỹ chung + cộng vào chi tiêu dự đoán của MEM

**Luồng mong muốn:**
1. MEM tạo yêu cầu xin tiền (`POST /finance/support-requests`) — **đã có.**
2. HOH duyệt (`PATCH /finance/support-requests/{id}/review` decision=APPROVE) → BE cần:
   - **Trừ số tiền khỏi quỹ chung** (family fund).
   - Ghi **1 ledger entry** loại `SUPPORT` (tiền ra khỏi quỹ → cho member) để lịch sử dòng tiền đầy đủ.
   - **Cộng số tiền nhận được vào `expectedPersonalExpense` của MEM** trong tháng đó.

**Ví dụ (theo team):** MEM xin 10k, quỹ có 50k. Sau duyệt: quỹ còn **40k**; MEM nhận 10k và `expectedPersonalExpense += 10k`.

**Cần BE xác nhận / bổ sung:**
- Endpoint review khi APPROVE **đã tự** (a) trừ quỹ, (b) tạo ledger SUPPORT, (c) bump `expectedPersonalExpense` của member chưa? Nếu **chưa**, nhờ bổ sung cả 3.
- FE sau khi duyệt sẽ **re-fetch** `monthly-finances/me` (MEM) và `/finance/overview` (HOH) để hiển thị số mới — nên chỉ cần BE cập nhật đúng, FE không tự tính.

---

## 3. ✅ FE đã làm (điểm 3)
- Bỏ hàng/field/biểu đồ "Đóng góp quỹ chung" ở màn thành viên (`child_wallet_screen`).
- Ràng buộc còn lại: **chi tiêu dự đoán ≤ thu nhập**. "Còn lại dự kiến" = thu nhập − chi tiêu.

---

## Tóm tắt cần BE
| # | Việc | Trạng thái |
|---|------|-----------|
| 1 | Income tự vào quỹ + quỹ = tổng income; HOH đọc income từng member | Xác nhận/bổ sung |
| 2 | APPROVE xin tiền: trừ quỹ + ledger SUPPORT + bump `expectedPersonalExpense` MEM | Xác nhận/bổ sung |
| 3 | Deprecate `expectedSharedContribution` | Tùy chọn |

Khi BE xác nhận #1/#2, FE sẽ: (a) build view **HOH xem thu nhập từng thành viên + tổng quỹ**, (b) đảm bảo re-fetch sau khi duyệt xin tiền.
