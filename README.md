# Family Care — Mobile App

**SU26SE032** · Flutter Mobile Application · Capstone Project SEP

Ứng dụng quản lý gia đình toàn diện: tài chính, nhiệm vụ, lịch, SOS khẩn cấp và giao tiếp nội bộ gia đình.

---

## Thông tin dự án

| | |
|---|---|
| **Tên dự án** | Family Care |
| **Mã dự án** | SU26SE032 |
| **Platform** | Flutter (Android / Web). Wear OS: UI có sẵn ở `lib/wear/`, chưa cấu hình build app riêng. iOS: chưa setup (không có thư mục `ios/`) |
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
| Secure storage (session) | flutter_secure_storage | ^9.2.2 |
| Bản đồ | flutter_map + latlong2 | ^7.0.2 / ^0.9.1 |
| GPS | geolocator | ^13.0.0 |
| Chọn ảnh | image_picker | ^1.1.2 |
| Mở link ngoài | url_launcher | ^6.3.0 |

---

## Cấu trúc thư mục

```
lib/
├── main.dart
├── models/              # AppUser, MoneyRequest, ...
├── navigation/          # app_router.dart, manager_shell, member_shell
├── providers/           # AuthProvider, WalletProvider, TaskProvider,
│                        # FinanceProvider, FinanceAlertProvider, SupportRequestProvider, ...
├── screens/
│   ├── auth/            # LoginScreen, RegisterScreen, JoinFamilyScreen
│   ├── parent/          # HomeDashboard, WalletScreen, TaskManagement,
│   │                    # BudgetPlanScreen, FinancialGoalScreen, FinanceAlertsScreen,
│   │                    # SupportRequestScreen, ...
│   ├── child/           # ChildHome, ChildTasks, ChildWallet
│   └── shared/          # SOS, FamilyMapScreen, Chat, Album, Profile, AI Assistant, SplashScreen
├── services/            # ApiClient (singleton HTTP client, timeout + auto-refresh)
├── theme/               # AppColors, design tokens
└── widgets/             # RingChart, WaffleChart, ...

lib/wear/                # Wear OS companion UI (chưa cấu hình thành app/flavor riêng)
android/
web/
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

### ✅ Task & Reward (kết nối API thực, `/families/{id}/tasks/...`)
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

### ✅ SOS & Safety (kết nối API thực, `/families/{id}/sos/alerts...`)
- Nút SOS giữ 3 giây (UC50)
- Nhận cảnh báo SOS từ thành viên khác, global banner ở ManagerShell/MemberShell (UC51)
- Xác nhận an toàn / hủy SOS (UC52, UC53)

### ✅ Calendar
- 5 loại sự kiện màu sắc riêng: Task / Sự kiện / Du lịch / Sinh nhật / Sức khỏe (UC70, UC71)

### ✅ Subscription
- Xem / chọn gói: Free / Family (99k₫) / Premium (299k₫) (UC76, UC77)
- Nút "Nâng cấp" hiện chỉ show dialog — checkout/thanh toán thật chưa làm, xem mục "Subscription / Thanh toán" trong `BE_API_REQUESTS.md`

### ⚠️ Chờ Backend
- GPS / Location sharing (`/location/...`) — **BE chưa có endpoint nào** cho location (đã verify qua Swagger `/api/docs-json`), `GpsProvider`/`FamilyMapScreen` hiện không hoạt động
- Profile PATCH (`/auth/me`) — BE chỉ có `GET`, chưa có `PATCH` để cập nhật họ tên/SĐT/avatar
- Subscription checkout (Stripe) — BE chỉ có `GET /subscription-plans`, chưa có endpoint tạo checkout session

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
