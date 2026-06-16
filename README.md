# Family Care — Mobile App

**SU26SE032** · Flutter Mobile Application · Capstone Project SEP

Ứng dụng quản lý gia đình toàn diện: tài chính, nhiệm vụ, lịch, SOS khẩn cấp và giao tiếp nội bộ gia đình.

---

## Thông tin dự án

| | |
|---|---|
| **Tên dự án** | Family Care |
| **Mã dự án** | SU26SE032 |
| **Platform** | Flutter (Android / iOS / Wear OS) |
| **Backend** | `http://103.110.84.66/api/v1` |
| **API Docs** | `http://103.110.84.66/api/docs` |
| **Branch chính** | `main` |
| **Version** | 1.0.0+1 |

---

## Tech Stack

| Layer | Library | Version |
|---|---|---|
| Framework | Flutter | SDK ^3.12.0 |
| Navigation | go_router | ^14.3.0 |
| State Management | provider | ^6.1.2 |
| HTTP | http | ^1.2.0 |
| Font | google_fonts (Inter) | ^6.2.1 |

---

## Cấu trúc thư mục

```
lib/
├── main.dart
├── models/              # AppUser, MoneyRequest, ...
├── navigation/          # app_router.dart, manager_shell, member_shell
├── providers/           # AuthProvider, WalletProvider, TaskProvider, ...
├── screens/
│   ├── auth/            # LoginScreen, RegisterScreen, JoinFamilyScreen
│   ├── parent/          # HomeDashboard, WalletScreen, TaskManagement, ...
│   ├── child/           # ChildHome, ChildTasks, ChildWallet
│   └── shared/          # SOS, Chat, Album, Profile, AI Assistant
├── services/            # ApiClient (singleton HTTP client)
├── theme/               # AppColors, design tokens
└── widgets/             # RingChart, WaffleChart, ...

wear/                    # Wear OS companion app
android/
ios/
```

---

## Roles & Navigation

| Role | Shell | Vào từ |
|---|---|---|
| `MANAGER` (Trưởng nhóm) | `ManagerShell` | Đăng ký mới → tự động |
| `DEPUTY` (Phó nhóm) | `ManagerShell` | Được cấp quyền bởi Manager |
| `MEMBER` (Thành viên) | `MemberShell` | Tham gia qua link / QR / mã mời |

---

## Cài đặt & Chạy

### Yêu cầu

- Flutter SDK ≥ 3.12.0
- Dart ≥ 3.0.0
- Android Studio / VS Code

### Cài dependencies

```bash
flutter pub get
```

### Chạy app

```bash
# Android emulator / device
flutter run

# Chỉ định API URL khác (mặc định: http://103.110.84.66/api/v1)
flutter run --dart-define=API_BASE_URL=http://your-server/api/v1
```

### Build APK

```bash
flutter build apk --release
```

---

## Flows đã implement

### ✅ Auth
- Đăng ký → tự động tạo gia đình → role MANAGER
- Đăng nhập → lấy familyId từ `/families/my`
- Đăng xuất (revoke refresh token)

### ✅ Finance (kết nối API thực)
- Xem tổng quan quỹ gia đình (`/finance/overview`)
- Lịch sử thu/chi (`/finance/ledger/entries`)
- Yêu cầu hỗ trợ chi tiêu (`/finance/support-requests`)
- Mô hình tài chính — 5 Jars, 80-20, Custom (`/finance/models`)
- Kế hoạch ngân sách, mục tiêu tài chính

### ✅ Task & Reward
- Tạo task ad-hoc (UC38) và định kỳ (UC39)
- Giao task / reassign (UC40, UC42)
- Báo bận — recurring task (UC41)
- Duyệt / từ chối task (UC44)
- Reward settlement flow: PENDING → SETTLED → CONFIRMED / DISPUTED (UC46–48)

### ✅ Family Management
- Mời thành viên: QR / link / mã mời (UC15, UC16)
- Tham gia qua token (`/invitations/{token}/accept`) (UC13)
- Danh sách thành viên (UC20)
- Xoá thành viên (UC19)

### ✅ SOS & Safety
- Nút SOS giữ 3 giây (UC50)
- Nhận cảnh báo SOS từ thành viên khác (UC51)
- Xác nhận an toàn / hủy SOS (UC52, UC53)

### ✅ Calendar
- 5 loại sự kiện màu sắc riêng: Task / Sự kiện / Du lịch / Sinh nhật / Sức khỏe (UC70, UC71)

### ✅ Subscription
- Xem / chọn gói: Free / Family (99k₫) / Premium (299k₫) (UC76, UC77)

### ⚠️ Chờ Backend
- Tasks API (`/tasks`) — chưa có endpoint
- SOS API (`/sos`) — chưa có endpoint
- GPS / Location (`/location`) — chưa có endpoint
- Profile PATCH (`/users/me`) — chưa có endpoint

---

## API Reference

Xem chi tiết tại [`API_DOCS.md`](API_DOCS.md) hoặc Swagger UI: `http://103.110.84.66/api/docs`

---

## Wear OS

Companion app cho Wear OS nằm trong `lib/wear/`. Hỗ trợ:
- Xem trạng thái SOS
- Trigger SOS từ đồng hồ (UC57)
- Hiển thị task và thông báo (UC58)

---

## Commit Convention

```
feat:   Tính năng mới
fix:    Sửa lỗi
refactor: Tái cấu trúc code
chore:  Cập nhật dependencies, config
```
