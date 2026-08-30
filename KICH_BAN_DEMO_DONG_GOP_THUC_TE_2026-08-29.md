# Kịch bản demo: Tách "tự khai" vs "thực tế chính thức" trong Đóng góp chung

**Cập nhật:** 29/08/2026 · **Nhánh:** `hopnhat` (commit `379f3df`) · **Máy demo:** OPPO Reno5
(APK: `D:\Desktop\FamilyCare_hopnhat_2026-08-29.apk`, đã cài sẵn, `lastUpdateTime` 29/08 13:14)

Dùng để demo cho giáo viên/nhóm phần fix mục 1 trong báo cáo BE gửi (wording
"Đóng góp thực tế" gây hiểu nhầm). Không cần chuẩn bị gì thêm ngoài 1 tài
khoản Member và 1 tài khoản Manager cùng gia đình.

---

## 0. Bối cảnh (nói trước khi demo)

> "Trước đây màn Chỉnh sửa hồ sơ có ô 'Đóng góp chung **thực tế** / tháng' —
> đây là số Member **tự gõ tay**, chưa được xác nhận qua sổ quỹ. Nhưng ở màn
> Tài chính tháng lại có một số khác cũng gọi là 'Thực tế' — số này do BE
> **tự tính từ sổ quỹ** (ai đã thực sự ghi nhận đóng góp). Hai số cùng tên
> 'thực tế' nhưng khác nguồn, nếu member tự khai sai hoặc chưa đóng đủ thì
> hai số lệch nhau và không ai biết vì sao. Nhóm đã tách rõ 2 khái niệm này
> bằng wording, không đổi logic/API."

---

## 1. Demo phía Member — nhập số "tự khai"

Đăng nhập tài khoản **Member** → **Tôi → Chỉnh sửa hồ sơ**.

- [ ] Cuộn tới khối **"Tài chính tháng này"** — chỉ hộp info màu vàng, đọc to:
      *"Số 'tự khai' là bạn tự ước tính... số chính thức của quỹ gia đình sẽ
      tính theo sổ quỹ, xem ở 'Tài chính tháng của tôi'."*
- [ ] Chỉ vào 3 cặp field: **Thu nhập tự khai**, **Chi tiêu cá nhân tự khai**,
      **Đóng góp chung tự khai** — nhấn mạnh chữ "tự khai" đã thay cho "thực tế".
- [ ] Nhập thử "Đóng góp chung tự khai" = **1.000.000đ**, bấm **Lưu tài chính
      tháng**.

> Nói: "Ở đây member khai là đã đóng 1 triệu, nhưng giả sử thực tế mới đóng
> 500k qua sổ quỹ — mình sẽ thấy sự khác biệt ngay ở bước sau."

---

## 2. Demo phía Member — xem "Tài chính tháng của tôi"

Từ Profile Member → **"Tài chính tháng của tôi"** (hoặc menu tương đương).

- [ ] Card **"Khai báo thu chi"**: dòng "Đóng góp chung tự khai" = 1.000.000đ
      (đúng số vừa nhập ở bước 1).
- [ ] Card **"Đóng góp quỹ gia đình"** phía dưới: chỉ vào 4 dòng
      **Kế hoạch / Tự khai báo / Ghi nhận sổ quỹ / Thực tế (chính thức)**.
- [ ] Đọc to dòng chú thích in nghiêng cuối card:
      *"'Thực tế' là số chính thức của quỹ, ưu tiên tính theo sổ quỹ — có thể
      khác số tự khai ở trên nếu member chưa đóng đủ hoặc đóng qua kênh khác."*
- [ ] Nếu 2 số **Tự khai báo** và **Thực tế (chính thức)** đang lệch nhau (vì
      dữ liệu sổ quỹ thật khác số vừa gõ) → chỉ ra đúng điểm đó là bằng chứng
      sống cho việc tách wording có tác dụng.

---

## 3. Demo phía Manager — xem hồ sơ thành viên

Đăng nhập tài khoản **Manager/Deputy** → **Thành viên gia đình** → chọn đúng
member vừa test → **Hồ sơ thành viên**.

- [ ] Card **"Tài chính tháng này"**: trước đây chỉ có 1 dòng "Ghi nhận quỹ
      gia đình" mập mờ — giờ tách thành 2 dòng:
      - **Đóng góp chung tự khai**
      - **Đóng góp quỹ (thực tế, chính thức)**
- [ ] Nói: "Manager nhìn thoáng qua trang tổng quan là thấy ngay khoảng lệch,
      không cần bấm vào 'Xem tài chính chi tiết' mới biết."
- [ ] Bấm **"Xem tài chính chi tiết"** để quay lại đúng màn ở bước 2, cho thấy
      2 màn nhất quán wording với nhau.

---

## 4. Kết luận (nói khi kết thúc)

> "Đây là patch nhỏ, chỉ đổi label + thêm 1 dòng chú thích ở 3 file UI, không
> đụng Provider/Service/API — đúng yêu cầu 'ưu tiên thay đổi nhỏ và an toàn,
> không refactor lớn Finance'. Các mục còn lại BE báo (Wallet, Goal, Surplus,
> Jar/Budget/Reports) đối chiếu code hiện tại đã đúng, không có bug thật nên
> không cần patch thêm."

---

## Đối chiếu nhanh (nếu bị hỏi "trước/sau khác gì")

| Vị trí | Trước | Sau |
|---|---|---|
| `edit_profile_screen.dart` — 3 ô nhập | "...thực tế / tháng" | "...tự khai / tháng" |
| `member_finance_screen.dart` — card Khai báo thu chi | "Đóng góp chung thực tế" | "Đóng góp chung tự khai" |
| `member_finance_screen.dart` — card Đóng góp quỹ | (không có chú thích) | thêm câu giải thích "Thực tế" ưu tiên theo sổ quỹ |
| `member_detail_screen.dart` — card Tài chính (Manager) | 1 dòng "Ghi nhận quỹ gia đình" | 2 dòng: "tự khai" + "thực tế, chính thức" |

Commit: `379f3df` trên nhánh `hopnhat`. `flutter analyze --no-fatal-infos`:
0 error. `flutter test`: 626/626 pass.
