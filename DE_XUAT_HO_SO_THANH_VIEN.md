# Đề xuất xây dựng & chỉnh sửa — Hồ sơ cá nhân thành viên gia đình

> Phạm vi: **FE Mobile (Flutter)**. Đối chiếu code hiện tại (`giap` @ `e4f283c`) với Swagger prod Tuần 9 (183 EP).
> Ký hiệu: **[LÀM ĐƯỢC NGAY]** = đủ API · **[CẦN BE]** = thiếu endpoint/field phía backend · **[VERIFY]** = cần xác nhận thêm.

---

## 0. Tóm tắt điều hành

Hiện app có **2 lớp hồ sơ**:
1. **Hồ sơ của chính mình** — màn `profile_screen.dart` (tab "Tôi") + `edit_profile_screen.dart`.
2. **Hồ sơ thành viên khác** — chỉ có **danh sách** (`member_list_screen.dart`) + **sheet quản lý** + màn tài chính tháng (`member_finance_screen.dart`). **Chưa có màn "Chi tiết hồ sơ thành viên" riêng.**

Ba vấn đề lớn nhất:
- **Không sửa được hồ sơ bản thân** (tên/điện thoại/avatar) — BE **thiếu `PATCH /auth/me`**. Màn Edit đang khóa 2 field và hiển thị note "liên hệ quản trị viên".
- **Nút "Cấp/Thu quyền Phó nhóm" luôn lỗi** — `updateRole()` trong `family_provider.dart` **throw cứng** vì BE chưa có endpoint user-facing đổi role (chỉ có admin).
- **Nghề nghiệp / Quan hệ gia đình** trong màn Edit là **trang trí** — chọn xong không lưu đâu cả (BE không có field).

Phần **chạy thật** đang tốt: xem danh sách thành viên, xoá thành viên, xem/khai báo **tài chính tháng** (income/expense/visibility).

---

## 1. Hiện trạng UI — chi tiết từng màn

### 1.1. `profile_screen.dart` — tab "Tôi" (hub điều hướng)
Đang có:
- Avatar (chữ cái đầu + màu **suy ra từ role**, không phải user chọn), tên, "Gia đình {tên}", chip role (TRƯỞNG/PHÓ/THÀNH VIÊN).
- Card thông tin: **email + điện thoại** (điện thoại chỉ hiện nếu có).
- Nhóm "Tài khoản": Chỉnh sửa hồ sơ · Bảo mật *(onTap rỗng)* · Thông báo *(onTap rỗng)*.
- Nhóm "Gia đình" (khác theo role): Thành viên · Mời · Duyệt yêu cầu · Gói đăng ký · các mục tài chính · Bản đồ · Album.
- Nhóm "Khác": Trợ giúp/FAQ *(rỗng)* · Điều khoản *(rỗng)*. Nút Đăng xuất.

Hạn chế: đây là **menu**, không phải hồ sơ đúng nghĩa — không có ngày sinh, giới tính, quan hệ, nghề nghiệp, ngày tham gia, thống kê cá nhân.

### 1.2. `edit_profile_screen.dart` — Chỉnh sửa hồ sơ
| Khối | Trạng thái thực tế |
|---|---|
| Avatar + **color picker** (4 màu) | Chọn được nhưng **KHÔNG lưu** — `avatarColor` suy ra từ role, không gửi BE |
| **Họ tên** | `enabled: false` — **khóa**, note "liên hệ quản trị viên" |
| **Số điện thoại** | `enabled: false` — **khóa** |
| **Nghề nghiệp** (5 lựa chọn enum local) | Chọn được nhưng **KHÔNG lưu** (BE không có field) |
| **Quan hệ gia đình** (6 lựa chọn enum local) | Chọn được nhưng **KHÔNG lưu** (BE không có field user-facing) |
| **Tài chính tháng** (thu nhập/chi tiêu) | ✅ **Chạy API thật** — `saveMonthlyFinance()` → `PUT/POST monthly-finances/me` |

> Ghi chú kỹ thuật: `saveMonthlyFinance()` map field **đúng chuẩn BE** (`expectedPersonalExpense`, `expectedSharedContribution`, `incomeVisibility/expenseVisibility`, `periodMonth/Year`). Nhưng UI **chỉ phơi ra income + expense**, chưa có toggle **Riêng tư/Chia sẻ** dù note có nhắc tới — và chưa **pre-fill** giá trị đã khai (mở ra luôn trống).

### 1.3. `member_list_screen.dart` — Danh sách thành viên
Đang có: card (avatar, tên + "(Bạn)", chip role, email, quan hệ), badge số yêu cầu chờ duyệt, đổi tên gia đình (Manager). Sheet quản lý mở khi bấm "⋯":
- **Xem tài chính tháng** → `member_finance_screen` ✅
- **Cấp/Thu quyền Phó nhóm** → ❌ **luôn lỗi** ("Tính năng… đang được cập nhật từ phía server")
- **Xoá thành viên** → ✅ `DELETE /families/{familyId}/members/{userId}`

> Bấm vào 1 thành viên **không mở hồ sơ chi tiết** — chỉ có sheet thao tác. Đây là khoảng trống chính.
> Lỗi copy nhỏ: empty-view ghi "mã **6 ký tự**" nhưng flow mới là **8 ký tự** — cần sửa.

### 1.4. `member_finance_screen.dart` — Tài chính tháng của member
✅ Manager/Deputy xem tổng quan tài chính tháng của member (chọn tháng, field private → "Riêng tư"), gate `canManageFinance`. Chạy API thật.

### 1.5. Model dữ liệu hiện có
- **`AppUser`**: `id, name, email, phone?, familyName, familyId?, role, avatarInitials, avatarColor (suy ra từ role), userType`. **Thiếu**: ngày sinh, giới tính, quan hệ, nghề nghiệp, địa chỉ, ảnh avatar thật, ngày tham gia.
- **`FamilyMember`**: `id, userId, name, email, role, relation, status, avatarColor`. **Thiếu**: điện thoại, ngày sinh, ảnh, thống kê.

---

## 2. API backend liên quan (Swagger Tuần 9)

### 2.1. Đang có — dùng được ngay
| Endpoint | Method | Dùng cho hồ sơ |
|---|---|---|
| `/auth/me` | GET | Lấy hồ sơ bản thân (⚠️ **không có response DTO** trong Swagger — FE đang đoán field) |
| `/families/{familyId}` | GET | Lấy family + `members[]` (nguồn danh sách thành viên) |
| `/families/{familyId}` | PATCH | Sửa **family** (`UpdateFamilyDto {name, description, avatarUrl}`) — Manager |
| `/families/{familyId}/members/{userId}` | DELETE | Xoá thành viên — Manager |
| `/families/{familyId}/finance/monthly-finances/me` | GET/POST/PUT | Khai báo tài chính tháng của mình |
| `/families/{familyId}/finance/monthly-finances/members/{memberId}` | GET | Manager xem tài chính member |
| `/families/{familyId}/finance/monthly-summary/me` · `.../members/{memberId}` | GET | Tổng quan tài chính tháng |
| `/families/{familyId}/tasks/my-assignments` | GET | Việc được giao (đưa vào hồ sơ) |
| `/families/{familyId}/face-profiles/{memberId}` (+ enroll/enable/disable) | GET/POST/PATCH | Face profile — **FE cố ý ẩn** (chưa bật Face AI) |

**DTO tài chính tháng** (`CreateMemberMonthlyFinanceDto` / `UpdateMemberMonthlyFinanceDto`):
`periodMonth*`, `periodYear*`, `expectedIncome`, `actualIncome`, `expectedPersonalExpense`, `actualPersonalExpense`, `expectedSharedContribution`, `actualSharedContribution`, `incomeVisibility (PRIVATE|FAMILY)`, `expenseVisibility (PRIVATE|FAMILY)`, `note`.

### 2.2. Thiếu — chặn tính năng hồ sơ [CẦN BE]
| Thiếu | Hệ quả | Đề xuất gửi BE |
|---|---|---|
| ❌ **`PATCH /auth/me`** | Không tự sửa tên/điện thoại/avatar. Chỉ có `AdminUpdateUserDto` (admin). | Thêm endpoint user tự cập nhật, whitelist `fullName, phone, avatarUrl, dob?, gender?`, trả user sau cập nhật |
| ❌ **Đổi role/relationship/status user-facing** | Nút Cấp/Thu Phó nhóm chết; không sửa quan hệ. Chỉ có `AdminUpdateMemberDto` (admin). | Thêm `PATCH /families/{familyId}/members/{userId}` (Manager-only), body `{familyRole, relationship, status}`, validate 1 Manager |
| ❌ **Field hồ sơ mở rộng** (dob, gender, occupation, relationship ở user) | Nghề nghiệp/Quan hệ trong Edit không lưu được | Bổ sung field vào user hoặc family-member; hoặc chốt bỏ khỏi scope |
| ⚠️ **`/auth/me` + family GET không có response DTO** | FE đoán field (`fullName`/`displayName`, `phone`/`phoneNumber`) | Bổ sung response DTO cho 2 EP này (đồng bộ đợt admin DTO Tuần 9) |
| ⚠️ **avatar** | UpdateFamilyDto có `avatarUrl` (family) nhưng **user chưa có** avatar ảnh | Thêm `avatarUrl` cho user + endpoint upload (như album/chat đã có R2) |

> Khớp với `API_MOBILE_AUDIT_2026-07-15.md`: các mục "High" (thiếu `PATCH /auth/me`, thiếu API đổi role/relationship — UC17/UC18) chính là gốc của các khoảng trống hồ sơ này.

---

## 3. Đề xuất — chia theo khả năng triển khai

### NHÓM A — Làm được ngay (không chờ BE)

**A1. [LÀM ĐƯỢC NGAY] Hoàn thiện màn "Tài chính tháng" trong Edit Profile**
- Thêm toggle **Riêng tư / Chia sẻ** cho income & expense (BE đã có `incomeVisibility`/`expenseVisibility`) — hiện `saveMonthlyFinance` đã nhận tham số, chỉ cần UI.
- **Pre-fill** giá trị đã khai tháng này: gọi `GET monthly-finances/me` khi mở (hiện đang để trống).
- Thêm field **Đóng góp chung dự kiến** (`expectedSharedContribution`) — đã có trong DTO & provider.

**A2. [LÀM ĐƯỢC NGAY] Màn "Chi tiết hồ sơ thành viên" (mới)** — xem §4.
- Ghép từ API sẵn có: thông tin cơ bản (từ `members[]`), tài chính tháng (`monthly-summary/members/{id}`), việc được giao. **Read-only** phần chưa có API ghi.

**A3. [LÀM ĐƯỢC NGAY] Dọn UI gây hiểu nhầm**
- `edit_profile`: **ẩn** (hoặc chuyển "Sắp có") 2 khối **Nghề nghiệp** & **Quan hệ** vì không lưu được — tránh người dùng tưởng đã lưu. Hoặc giữ nhưng **disable + nhãn "Sắp có"**.
- `member_list`: sửa "mã **6 ký tự**" → **8 ký tự**; với nút **Cấp/Thu Phó nhóm** — tạm **ẩn** cho tới khi có BE (thay vì để bấm ra lỗi). *(Quyết định A hay để lỗi tuỳ bạn — khuyến nghị ẩn.)*
- Avatar color picker: hoặc **ẩn** (vì không lưu), hoặc lưu **local** tạm bằng `flutter_secure_storage`/prefs để ít nhất persist trên máy. `[VERIFY hướng]`

**A4. [LÀM ĐƯỢC NGAY] "Hồ sơ của tôi" giàu hơn**
- Bổ sung vào `profile_screen`: **ngày tham gia gia đình**, **vai trò + quyền tóm tắt**, **thống kê nhanh** (số việc đang làm từ `my-assignments`, khai báo tài chính tháng đã/chưa). Toàn bộ từ API sẵn có.

### NHÓM B — Cần BE mở endpoint trước [CẦN BE]

**B1. Sửa hồ sơ bản thân** — chờ `PATCH /auth/me`. FE có sẵn màn Edit, chỉ cần bật `enabled: true` + wire provider khi BE ship. **Ưu tiên cao nhất** (audit xếp High).
**B2. Đổi role (Cấp/Thu Phó nhóm) + Quan hệ** — chờ `PATCH /families/{familyId}/members/{userId}`. `family_provider.updateRole()` đã có sẵn chỗ, chỉ cần thay thân hàm gọi API thật.
**B3. Avatar ảnh thật** — chờ user `avatarUrl` + upload. Tái dùng pattern R2 của album/chat.

### Bảng ưu tiên
| Ưu tiên | Việc | Nhóm |
|---|---|---|
| 🔴 P0 | Ẩn nút Phó nhóm đang lỗi + sửa "6→8 ký tự" | A3 |
| 🔴 P0 | Màn Chi tiết hồ sơ thành viên (read-only) | A2 |
| 🟠 P1 | Hoàn thiện Tài chính tháng (visibility + pre-fill + shared) | A1 |
| 🟠 P1 | Hồ sơ của tôi giàu hơn (thống kê, ngày tham gia) | A4 |
| 🟡 P2 | Gửi BE mở `PATCH /auth/me` + `PATCH members/{userId}` → bật B1/B2 | B |
| ⚪ P3 | Avatar ảnh thật (B3), nghề nghiệp/quan hệ nếu BE thêm field | B |

---

## 4. Đề xuất màn mới: "Chi tiết hồ sơ thành viên"

Route đề xuất: `/manager/member/:memberId` (hoặc `/family/member/:memberId` cho mọi role xem cơ bản). Mở khi **bấm vào card** trong `member_list` (thay vì chỉ mở sheet).

```
┌─────────────────────────────────────────────┐
│  ←            Hồ sơ thành viên           ⋯   │  ⋯ = sheet quản lý (Manager)
├─────────────────────────────────────────────┤
│              (Avatar 88px)                   │
│              Nguyễn Văn An                   │
│         [ PHÓ NHÓM ]   Con cái               │  chip role + quan hệ
│                                              │
│  ┌── Thông tin ──────────────────────────┐   │
│  │ ✉  Email      an@...                   │   │  từ members[] / auth/me
│  │ ☎  Điện thoại  0901… (nếu có)          │   │  [CẦN BE nếu member khác]
│  │ 📅 Tham gia    12/06/2026              │   │  [VERIFY field joinedAt]
│  │ 🟢 Trạng thái  Đang hoạt động          │   │
│  └───────────────────────────────────────┘   │
│                                              │
│  ┌── Tài chính tháng (Manager/Deputy) ───┐   │  monthly-summary/members/{id}
│  │ Thu nhập   ••• (Riêng tư) / số tiền   │   │  gate canManageFinance
│  │ Chi tiêu   …                          │   │
│  │ Đóng góp   …        [Xem chi tiết →]   │   │  → member_finance_screen
│  └───────────────────────────────────────┘   │
│                                              │
│  ┌── Công việc ──────────────────────────┐   │  tasks/my-assignments (của member)
│  │ Đang làm: 2 · Hoàn thành tháng: 5     │   │  [VERIFY EP lọc theo member]
│  └───────────────────────────────────────┘   │
│                                              │
│  [ Nhắn tin ]   (chat 1-1)                    │  chat/conversations
└─────────────────────────────────────────────┘
   ⋯ sheet: Cấp/Thu Phó nhóm · Đổi quan hệ · Xoá   ← B2 (chờ BE), Xoá đã chạy
```

Nguyên tắc: phần **có API** hiển thị thật; phần **chờ BE** để read-only hoặc ẩn, gắn `[CẦN BE]` trong code comment để dễ bật sau.

---

## 5. Thay đổi code cụ thể (gợi ý file)

| File | Thay đổi |
|---|---|
| `lib/screens/parent/member_detail_screen.dart` | **MỚI** — màn §4, nhận `memberId`, đọc `FamilyProvider` + `FinanceProvider` |
| `lib/navigation/app_router.dart` | Thêm route `/manager/member/:memberId` |
| `lib/screens/parent/member_list_screen.dart` | `onTap` card → push member-detail; sửa "6→8 ký tự"; ẩn nút Phó nhóm (tới khi B2) |
| `lib/screens/shared/edit_profile_screen.dart` | Thêm toggle visibility + pre-fill + shared-contribution; ẩn/nhãn "Sắp có" cho Nghề nghiệp/Quan hệ |
| `lib/providers/family_provider.dart` | `updateRole()`: thay throw bằng gọi `PATCH members/{userId}` **khi BE sẵn sàng** `[CẦN BE]` |
| `lib/models/user.dart` | Bổ sung field khi BE trả (dob/gender/avatarUrl/joinedAt) — parse phòng thủ |

---

## 6. Việc cần gửi Backend (tổng hợp)

1. **`PATCH /auth/me`** — user tự sửa `fullName, phone, avatarUrl` (+ `dob, gender` nếu chốt). Trả user sau cập nhật. *(High — mở B1)*
2. **`PATCH /families/{familyId}/members/{userId}`** (Manager) — `{familyRole, relationship, status}`, validate đúng 1 Manager. *(High — mở B2, UC17/18)*
3. **Response DTO cho `GET /auth/me` và `GET /families/{familyId}`** — hết cảnh FE đoán field. *(Medium)*
4. **Xác nhận field mở rộng hồ sơ** (dob/gender/occupation/relationship) có nằm trong scope demo không. `[VERIFY]`
5. **Upload avatar user** (R2) nếu làm B3.

---

*Mọi số liệu/endpoint trong tài liệu lấy từ Swagger prod Tuần 9 (16/07). Field đánh `[VERIFY]` cần xác nhận lại với BE trước khi wire.*
