# Kịch bản demo hội đồng — Toàn bộ flow Family Care

**Cập nhật:** 30/08/2026 · **Nhánh:** `hopnhat` (mới nhất `94d0136`) · **APK:**
`D:\Desktop\FamilyCare_hopnhat_2026-08-30.apk`

Kịch bản này đi hết **9 module chính** của app theo đúng thứ tự nav
(`kShellBranchOrder`): Trang chủ, Chat, Lịch, Bản đồ, Nhiệm vụ, Ví, Album,
SOS, Tôi — cộng thêm phần Onboarding/Auth ở đầu và Tài chính mở rộng (nằm
trong menu "Tôi", không có tab riêng nhưng là mảng lớn nhất của app).

Ước lượng thời gian nếu demo full: **25–35 phút**. Nếu hội đồng giới hạn
thời gian, ưu tiên theo thứ tự: **Auth → Gia đình → Nhiệm vụ+Thưởng →
Tài chính (Mô hình hũ + 1 vòng thu/chi) → SOS → Album face-tag** — đây là
5 khối thể hiện rõ nhất kiến trúc + độ khó kỹ thuật (realtime, RBAC,
state machine thưởng, nhận diện khuôn mặt, khẩn cấp).

---

## 0. Chuẩn bị trước khi lên trình bày

- [ ] Cài đúng APK mới nhất, xác nhận qua `adb shell dumpsys package
      com.company.familycare | grep lastUpdateTime` — phải sau thời điểm
      commit cuối cùng.
- [ ] Có **tối thiểu 2 thiết bị/tài khoản** đăng nhập sẵn: 1 **Manager**,
      1 **Member** (hoặc Deputy) — để demo tương tác 2 chiều (giao việc,
      SOS, chat) không phải đăng xuất/đăng nhập lại giữa chừng.
- [ ] Kiểm tra mạng ổn định (BE là server thật, không phải mock).
- [ ] Chuẩn bị sẵn 1 tài khoản **chưa có gia đình** để demo trọn vẹn luồng
      tạo gia đình/tham gia từ đầu, tránh phải xoá dữ liệu giữa buổi.
- [ ] Biết trước **2 giới hạn đã biết** để trả lời chủ động nếu hội đồng
      hỏi (không né tránh, nói thẳng là đã ghi nhận):
      - Sửa/xoá minh chứng đã nộp (`PATCH/DELETE .../tasks/proofs/{id}`)
        chưa có UI — nộp sai phải nộp lại từ đầu, cần thiết kế lại luồng
        upload trước khi làm.
      - Nghề nghiệp & quan hệ gia đình tự đổi qua UI còn giới hạn (quan hệ
        đổi được qua BE, nghề nghiệp thì chưa có endpoint).

---

## 1. Onboarding & Xác thực

1. **Đăng ký** tài khoản mới → nhập email/mật khẩu/họ tên.
2. **Xác thực email** — mở hộp thư, bấm link/nhập mã (tuỳ luồng BE hiện
   dùng), nói rõ: "Router chặn mọi truy cập nếu email chưa xác thực —
   đây là 1 trong các gate trong `computeRedirect()`".
3. **Đăng nhập** lại bằng tài khoản vừa tạo → vào thẳng màn "Chưa có gia
   đình" (chưa `family-setup`).
4. Thử **quên mật khẩu** (`/forgot-password`) nếu muốn cho hội đồng thấy
   luồng đầy đủ.

> Điểm nhấn kỹ thuật: `computeRedirect()` là hàm thuần tách khỏi
> BuildContext, có unit test riêng (`app_router_redirect_test.dart`) —
> nói được nếu hội đồng hỏi về testability.

---

## 2. Tạo/Tham gia gia đình

### 2.1. Tạo gia đình mới (role Manager)

1. Từ màn "Chưa có gia đình" → **Tạo gia đình** → nhập tên gia đình.
2. Sau khi tạo → tự động có role `FAMILY_MANAGER`.

### 2.2. Mời thành viên

1. Manager → **Tôi → Mời thành viên** → sinh link mời.
2. Gửi link cho tài khoản thứ 2 (đã đăng ký từ mục 1, chưa có gia đình).
3. Tài khoản 2 mở link (`/join?token=...`) → **Tham gia** (claim) →
   trạng thái invitation chuyển `CLAIMED` — **chưa** phải thành viên.
4. Manager → **Tôi → (badge yêu cầu chờ duyệt)** → **Duyệt** → lúc này
   mới thực sự tạo `FamilyMember`.

> Điểm nhấn: nhấn mạnh `claim ≠ tạo member` — 2 bước tách biệt, đã verify
> kỹ với BE (`API_DOCS.md`).

### 2.3. Phân quyền — 2 trục độc lập

1. Manager → **Thành viên gia đình** → chọn thành viên vừa duyệt → **Hồ
   sơ thành viên**.
2. Bổ nhiệm **Phó nhóm (Deputy)** → giải thích: Deputy được hầu hết quyền
   quản trị **trừ 4 quyền Manager-only** (mời thành viên, quản lý gói,
   xoá thành viên, đổi vai trò người khác).
3. (Tuỳ chọn) Demo **Trao quyền Trưởng nhóm** cho thành viên khác — nói
   rõ đây là hành động 1 chiều, Manager cũ mất quyền quản lý ngay.
4. Đổi **Quan hệ gia đình** (Vợ/Chồng, Con, Bố/Mẹ...) — có ràng buộc
   "mỗi vai trò Bố/Mẹ chỉ 1 người trong gia đình" (BE trả 409 nếu trùng).

---

## 3. Nhiệm vụ & Thưởng (module lớn thứ 2, nhiều state machine nhất)

*(Chi tiết từng bước xem file trước đó đã gửi — tóm tắt lại đây cho liền
mạch với các module khác)*

1. Manager **tạo nhiệm vụ** (thường hoặc định kỳ) → **giao việc**.
2. Manager **đặt thưởng** (Tiền/Điểm/Khác).
3. Người nhận thấy **2 nút "Bắt đầu làm" / "Bận"** ngay khi vừa nhận việc
   (fix 30/08 — trước đây phải bắt đầu làm mới có nút Bận).
4. Người nhận **bắt đầu làm → nộp bài** (kèm ảnh minh chứng).
5. Manager **duyệt bài** → thông báo đúng: "vào Quản lý thưởng để trả
   thưởng" (fix 30/08 — trước đây báo nhầm "chưa đặt thưởng").
6. Manager **Quản lý thưởng → Đánh dấu đã trả** (chọn phương thức: Tiền
   mặt/Chuyển khoản/Ví điện tử/Khác) — có cảnh báo khoản này không tự
   cộng vào thu nhập cá nhân.
7. Người nhận **Xác nhận đã nhận** (sinh bút toán `REWARD` vào sổ quỹ) —
   hoặc **Báo chưa nhận** → tạo tranh chấp → Manager xử lý (chấp
   nhận/từ chối).
8. Mở **Chi tiết khoản thưởng** — toàn bộ nhãn tiếng Việt, không còn ID
   hiện trống (fix 30/08).
9. (Nếu có task quá hạn/bận) Demo **Phân công lại** cho người khác.

---

## 4. Tài chính (mảng lớn nhất — 7 màn con)

### 4.1. Mô hình tài chính (hũ/quỹ)

1. Manager → **Tôi → Mô hình tài chính**.
2. Xem/chỉnh tỷ trọng phân bổ các hũ (%) — demo thông báo khi tổng vượt
   100%.

### 4.2. Kế hoạch ngân sách

1. **Kế hoạch ngân sách** → tạo/xem danh mục thu-chi kế hoạch theo kỳ.
2. Mở chi tiết 1 kế hoạch → xem báo cáo thực tế vs kế hoạch (đã dịch
   tiếng Việt qua `JsonReportView`, verify lại sau fix 30/08).

### 4.3. Mục tiêu tài chính (tiết kiệm)

1. **Mục tiêu tiết kiệm** → tạo mục tiêu (số tiền, hạn).
2. Đóng góp vào mục tiêu → xem tiến độ.
3. Mở **chi tiết mục tiêu** — chỉ ra 2 luồng tách biệt: đóng góp theo kế
   hoạch tự động vs đóng góp thủ công ngoài kế hoạch.

### 4.4. Tài chính tháng cá nhân + Đóng góp chung — trọng tâm fix hôm nay

1. Member → **Chỉnh sửa hồ sơ → Tài chính tháng này**.
2. Nhập **"Đóng góp chung tự khai"** (đã đổi từ "thực tế" → "tự khai").
3. Vào **"Tài chính tháng của tôi"** → chỉ vào 4 dòng: Kế hoạch / Tự khai
   báo / Ghi nhận sổ quỹ / **Thực tế (chính thức)** + câu giải thích vì
   sao 2 số có thể lệch.
4. Manager → **Hồ sơ thành viên** → thấy 2 dòng tách riêng "tự khai" và
   "thực tế, chính thức" ngay ở trang tổng quan.

### 4.5. Ví / Sổ thu chi

1. **Ví** → xem số dư quỹ gia đình, biểu đồ thu/chi.
2. Ghi nhận 1 khoản thu/chi thủ công → xem xuất hiện ngay trong sổ.
3. Đối chiếu dòng "Thưởng nhiệm vụ: {tên việc}" từ mục 3 (nếu đã demo).

### 4.6. Cảnh báo & Báo cáo tài chính

1. **Cảnh báo tài chính** → xem danh sách cảnh báo (vượt ngân sách, nguy
   cơ thiếu hụt mục tiêu...).
2. **Báo cáo tài chính** → xem báo cáo tổng hợp theo kỳ.

### 4.7. Yêu cầu hỗ trợ chi tiêu

1. Member → **Yêu cầu hỗ trợ chi tiêu** → tạo yêu cầu (xin thêm ngân
   sách/hỗ trợ khoản chi phát sinh).
2. Manager → duyệt/từ chối yêu cầu.

---

## 5. Lịch (Calendar)

1. Tab **Lịch** → xem các nhiệm vụ có hạn chót hiển thị theo ngày/tháng.
2. Chọn 1 ngày → xem danh sách việc trong ngày đó.

> Lưu ý nói trước: chưa có endpoint sự kiện lịch riêng — Lịch hiện tính
> từ `dueDate`/`startAt` của Nhiệm vụ, không phải calendar event độc lập.

---

## 6. Chat

1. Tab **Chat** → gửi tin nhắn giữa các thành viên.
2. Nói rõ cơ chế: **REST polling**, không phải WebSocket — khác với
   Notification dùng Socket.IO.

---

## 7. SOS (khẩn cấp) — điểm nhấn về realtime

1. 1 thiết bị (Member) → tab **SOS** → **kích hoạt SOS**.
2. Thiết bị Manager: nhận **push notification** ngay cả khi app đang nền
   (FCM) → mở app vào thẳng **chi tiết SOS**.
3. Manager bấm phản hồi nhanh: "Đã xem" / "Tôi an toàn" / "Cần giúp đỡ".
4. Manager gửi vị trí, hoặc **Xác nhận an toàn** / **Giải quyết** (nhập
   ghi chú xử lý) / **Huỷ**.

> Điểm nhấn kỹ thuật: 3 kênh realtime khác nhau (Socket.IO khi foreground,
> FCM khi nền/tắt app, local notification khi tiến trình còn sống) — nói
> được nếu hội đồng hỏi vì sao không dùng 1 kênh duy nhất.

---

## 8. Bản đồ gia đình

1. Tab **Bản đồ** → xem vị trí các thành viên đã bật chia sẻ vị trí trên
   bản đồ chung.

---

## 9. Album ảnh + Nhận diện khuôn mặt

1. Tab **Album** → tải lên vài ảnh gia đình (có nhiều người trong 1 ảnh).
2. Vào **Hồ sơ thành viên** (Manager) → **Thiết lập hồ sơ khuôn mặt** cho
   1–2 thành viên (chọn 3–5 ảnh chân dung rõ mặt, tick đồng ý, kiểm tra
   ảnh, gửi tạo hồ sơ).
3. Quay lại Album → ảnh nhóm → hệ thống gợi ý tag khuôn mặt (khung vàng =
   gợi ý AI, khung xanh = đã xác nhận).
4. Demo nút **bật/tắt khung nhận diện** (mới thêm) — ẩn hết khung để xem
   trọn ảnh mà không ảnh hưởng dữ liệu tag đã xác nhận.

---

## 10. Hồ sơ cá nhân, Cài đặt & Gói đăng ký

1. Tab **Tôi** → xem thông tin cá nhân, đổi mật khẩu.
2. **Tuỳ chỉnh tab** (`/settings/tabs`) → đổi 3 vị trí tab được phép tuỳ
   biến (vị trí 0/3/5 — Trang chủ/SOS/Tôi cố định).
3. Manager → **Gói đăng ký** → xem gói hiện tại, giới hạn tính năng theo
   gói (nếu đang ở gói Free, chỉ ra 1 tính năng bị khoá/giới hạn để minh
   hoạ `featureAccess`).

---

## 11. (Tuỳ chọn, nếu có đồng hồ) Wear OS

1. Đeo smartwatch đã cài app, mở ứng dụng — tự nhận diện màn hình đồng
   hồ (`_isWearDisplay`) và chuyển sang giao diện Wear riêng.
2. Demo nhanh: xem nhiệm vụ, gửi tin nhắn nhanh, hoặc kích hoạt SOS từ
   đồng hồ (nếu đã setup nhịp tim/cảm biến té ngã).

> Chỉ demo nếu hội đồng hỏi sâu hoặc còn thời gian — đây là phần cộng
> điểm, không phải luồng lõi.

---

## Bảng tóm tắt để bốc thăm nếu hội đồng chỉ muốn xem nhanh

| Muốn xem gì | Đi thẳng mục |
|---|---|
| Kiến trúc phân quyền (RBAC 2 trục) | Mục 2.3 |
| State machine phức tạp nhất trong app | Mục 3 (thưởng) |
| Độ sâu nhất của module Tài chính | Mục 4.4 (vừa fix hôm nay) |
| Realtime/push notification | Mục 7 (SOS) |
| Có dùng AI/ML không | Mục 9 (nhận diện khuôn mặt) |
| Test coverage / kỹ thuật testability | Mục 1 (nhắc `computeRedirect` có unit test) |
