# Family Care — Design System Reference

> `SU26SE032` · Mobile: **Flutter** (Dart) · Admin: React Web · Font: Inter
> Figma file: `ENiRsTcclyqz70hW8DciwY` · Page: `Design System + Edge Cases`
> Flutter stack: `flutter` + `go_router` + `provider` + `google_fonts` + Material 3

---

## 1. Color Palette

> Nguồn chân lý: `lib/theme/app_colors.dart` — class `AppColors`
> Flutter dùng `Color(0xFFRRGGBB)` — alpha byte `FF` = opaque

### Background & Surface

| Token (AppColors) | Hex | Flutter Value | Dùng cho |
|-|-|-|-|
| `background` | `#F8FBF5` | `Color(0xFFF8FBF5)` | Scaffold background — tông xanh kem nhẹ |
| `white` | `#FFFFFF` | `Color(0xFFFFFFFF)` | Card surface, bottom sheet, nav bar |

### Text Colors

| Token | Hex | Flutter Value | Dùng cho |
|-|-|-|-|
| `textPrimary` | `#111827` | `Color(0xFF111827)` | Tiêu đề, nội dung chính |
| `textSecondary` | `#6B7280` | `Color(0xFF6B7280)` | Phụ đề, nhãn phụ |
| `textMuted` | `#9CA3AF` | `Color(0xFF9CA3AF)` | Placeholder, timestamp, caption |

### Hero Gradient (Wallet Card — Manager)

| Token | Hex | Flutter Value | Dùng cho |
|-|-|-|-|
| `heroOrange` | `#FF8C42` | `Color(0xFFFF8C42)` | Gradient start — Ví Gia Đình card |
| `heroPurple` | `#A78BFA` | `Color(0xFFA78BFA)` | Gradient end |

### Semantic Colors 🔒

| Token | Alias | Hex | Flutter Value | Dùng cho |
|-|-|-|-|-|
| `income` | — | `#F97316` | `Color(0xFFF97316)` | Thu nhập, reward dương, WaffleChart |
| `shared` | — | `#7C3AED` | `Color(0xFF7C3AED)` | Chi chung, HoH, Subscription, Event calendar |
| `safe` | `success` | `#22C55E` | `Color(0xFF22C55E)` | Hoàn thành ✓, dư quỹ, +tiền |
| `sos` | `danger` | `#EF4444` | `Color(0xFFEF4444)` | SOS FAB 🔒, từ chối, Health calendar |
| `planned` | `link` | `#2563EB` | `Color(0xFF2563EB)` | CTA, tab active, Task calendar |

### Calendar Event Colors *(Họp 19/05 — mới)*

| Token (đề xuất) | Hex | Flutter Value | Loại sự kiện |
|-|-|-|-|
| `calTask` → `planned` | `#2563EB` | `Color(0xFF2563EB)` | 📋 Task (dùng lại `planned`) |
| `calEvent` → `shared` | `#7C3AED` | `Color(0xFF7C3AED)` | 📅 Sự kiện (dùng lại `shared`) |
| `calTravel` *(mới)* | `#0EA5E9` | `Color(0xFF0EA5E9)` | ✈️ Du lịch |
| `calBirthday` → `accent` | `#F59E0B` | `Color(0xFFF59E0B)` | 🎂 Sinh nhật (= Accent/500) |
| `calHealth` → `sos` | `#EF4444` | `Color(0xFFEF4444)` | 🏥 Sức khỏe / Khám bệnh (dùng lại `sos`) |

> **Lưu ý:** Chỉ có `calTravel` (#0EA5E9) là token thực sự mới cần thêm vào `AppColors`.

### Avatar Colors

| Token | Hex | Flutter Value | Thành viên mẫu |
|-|-|-|-|
| `avatarBlue` | `#3B82F6` | `Color(0xFF3B82F6)` | Ba / Manager |
| `avatarPurple` | `#A78BFA` | `Color(0xFFA78BFA)` | Bi (Family Member 2) |
| `avatarOrange` | `#FB923C` | `Color(0xFFFB923C)` | An (Family Member 1) |
| `avatarTeal` | `#2DD4BF` | `Color(0xFF2DD4BF)` | Mẹ / Deputy |

### Role → Color Mapping *(cập nhật từ họp 19/05)*

| Role | Token | Hex | Ghi chú |
|-|-|-|-|
| Admin | `shared` | `#7C3AED` | Docker, Revenue, System — 1 per system |
| Head of Household (HoH) | `planned` | `#2563EB` | Flag, không phải role riêng — mặc định là Parent đầu tiên |
| Parent / Deputy | `planned` | `#2563EB` | Trưởng / Phó nhóm — giao task, duyệt, thao tác ví chung |
| **Family Member** *(đổi từ Child)* | `safe` | `#22C55E` | Tất cả thành viên còn lại: con, ông bà, anh chị em |
| SOS (all roles) | `sos` | `#EF4444` | 🔒 Luôn đỏ, không phụ thuộc role |

---

## 2. Typography

> Font duy nhất: **Inter** qua `google_fonts` package
> Dùng `GoogleFonts.inter(fontSize:, fontWeight:, color:)`

| Usage | Size | FontWeight | Dùng cho |
|-|-|-|-|
| Balance / Display | 32px | `w700`/`w800` | Số dư ví hero |
| Screen Title | 22px | `w700` | Tiêu đề màn hình |
| Section Title | 20px | `w700` | Section header |
| Sheet Title | 20px | `w700` | Bottom sheet header |
| Card Title | 15px | `w700` | TaskCard, card nội dung |
| Body | 14px | `w700`/`w600` | Tên thành viên, giao dịch |
| Chip / Filter | 13px | `w600` | Filter chip, tab label |
| Form Label | 12px | `w600` | Section label, legend |
| Badge | 11px | `w600` | Status badge, chip text |
| Tab Label | 10px | `w700`/`w400` | BottomNavBar (active/inactive) |

---

## 3. Spacing & Layout

> Standard horizontal padding: **20px** · Card padding: **20px** · BottomNavBar: **60px**

| Value | Dùng cho |
|-|-|
| 8px | Gap nội bộ component |
| 12px | Gap giữa elements |
| 16px | Input padding, chip |
| 20px | **Screen padding (chuẩn)** · Card padding |
| 24px | Bottom sheet padding |
| 28px | Bottom sheet content |
| 40–110px | Bottom clearance trước nav |

### Frame sizes

```
Mobile (iPhone 14): 393 × 852 px
Admin Web:         1440 × 900 px
```

---

## 4. Icon System

> **Flutter Material Icons** (`Icons.*`) — không phải Lucide
> Admin Web: có thể dùng Lucide React

### Manager Shell (6 tabs)

| Icon | Tab | Route |
|-|-|-|
| `Icons.home_rounded` | Trang chủ | `/manager/home` |
| `Icons.chat_bubble_rounded` | Nhắn tin | `/manager/chat` |
| `Icons.calendar_month_rounded` | Lịch | `/manager/calendar` |
| 🚨 (SOS circle) | SOS | `/manager/sos` |
| `Icons.photo_library_rounded` | Album | `/manager/album` |
| `Icons.person_rounded` | Tôi | `/manager/profile` |

### Member Shell (6 tabs)

| Icon | Tab | Route |
|-|-|-|
| `Icons.home_rounded` | Trang chủ | `/member/home` |
| `Icons.task_alt_rounded` | Nhiệm vụ | `/member/tasks` |
| `Icons.account_balance_wallet_rounded` | Ví | `/member/wallet` |
| 🚨 (SOS circle) | SOS | `/member/sos` |
| `Icons.chat_bubble_rounded` | Chat | `/member/chat` |
| `Icons.person_rounded` | Tôi | `/member/profile` |

---

## 5. Role & Permissions *(cập nhật từ họp 19/05 & 22/05)*

### Cấu trúc Role

```
Admin           → Quản trị hệ thống — 1 per system (không phải per-family)
Head of Household (HoH) → Flag trên Parent đầu tiên, không phải role riêng
Parent          → Trưởng nhóm hoặc Phó nhóm — có quyền quản lý
Family Member   → Tất cả thành viên còn lại (đổi từ "Child")
                  Field bổ sung: quan_he (vợ/chồng, con, cha mẹ, ông bà, anh chị em)
```

> **Lưu ý kỹ thuật:** Trong code, role vẫn là enum `parent` / `member` (hoặc `manager` / `member`).
> "Family Member" là tên hiển thị trong UI, không phải tên role kỹ thuật.

### Wallet Permission Matrix *(họp 22/05)*

| Hành động | Trưởng nhóm | Phó nhóm | Family Member |
|-|-|-|-|
| Xem tài chính hạng 9 (nhạy cảm) | ✅ | ✅ | ❌ |
| Nạp tiền vào ví chung | ✅ | ✅ | ❌ |
| Rút / chuyển từ ví chung | ✅ | ✅ | ❌ |
| Xem số dư ví cá nhân | ✅ | ✅ | ✅ (chỉ ví của mình) |
| Nạp vào ví cá nhân | ✅ | ✅ | ✅ |
| Rút trực tiếp từ ví cá nhân | ✅ | ✅ | ❌ — phải xin phép |
| Gửi request xin tiền | ❌ | ❌ | ✅ |
| Duyệt / từ chối request | ✅ | ✅ | ❌ |
| Nhận thông báo tài chính hạng 9 | ✅ | ✅ | ❌ |
| Nhận thông báo thường | ✅ | ✅ | ✅ |

---

## 6. Subscription Plans *(họp 19/05)*

> Tiêu chí phân tầng: **Thời gian** + **Tính năng & AI** + **Dung lượng tài nguyên**
> Không dùng số lượng thành viên làm tiêu chí (gia đình VN 5–10 người)

| Gói | Giá/tháng | Thành viên | Storage | Database | Tính năng nổi bật |
|-|-|-|-|-|-|
| **Free** | 0 ₫ | 4 TV | 1 GB | Shared DB + RLS | Task, Wallet cơ bản, Chat |
| **Family** | 99,000 ₫ | 8 TV | 5 GB | Shared DB + RLS | + Calendar, Album, Location |
| **Premium** | 299,000 ₫ | Không giới hạn | Không giới hạn | **Docker riêng/gia đình** | + AI Chatbot, Wearable, Docker |

### Kiến trúc Subscription

```
Free / Family:
  → Shared Database + Row-Level Security (RLS)
  → Tiết kiệm chi phí server, nhiều gia đình dùng chung DB
  → Mỗi family chỉ thấy data của mình (RLS đảm bảo)

Premium:
  → Tự động spin-up Docker container riêng sau khi thanh toán
  → Mỗi gia đình = 1 container độc lập
  → Dùng Docker free / Kubernetes (không cần production-scale ở giai đoạn này)
  → AI Chatbot, Wearable tích hợp
```

> **Điểm cộng báo cáo SDD (Report 4):** Trình bày rõ trade-off Shared DB vs Docker → kiến trúc microservices thực tế.

### Core Flow 0 — Khởi tạo Gia đình

```
1. Đại diện gia đình đăng ký tài khoản
2. Chọn & mua gói subscription
3. Xác minh thanh toán → gia đình được kích hoạt
4. Người đại diện thêm thành viên:
   vợ/chồng, con cái, ông bà, anh chị em...
```

---

## 7. Budget & Finance *(họp 19/05)*

### Thông tin tài chính của từng thành viên

| Thuộc tính | Kiểu | Mô tả |
|-|-|-|
| Họ tên | String | Tên hiển thị trong gia đình |
| Ngày sinh | Date | Calendar nhắc sinh nhật, tính tuổi |
| Nghề nghiệp | Enum | Đi làm / Học sinh / Hưu trí / Nội trợ / Khác |
| Nguồn thu nhập | String | Lương, lương hưu, kinh doanh, không có... |
| Thu nhập bình quân/tháng | Decimal ≥ 0 | 0 nếu chưa có thu nhập (học sinh, người phụ thuộc) |
| Chi tiêu cá nhân dự kiến/tháng | Decimal ≥ 0 | Khoản chi riêng: học phí, xăng xe... |
| Quan hệ trong gia đình | Enum | vợ/chồng / con / cha mẹ / ông bà / anh chị em / khác |

### Thông tin tài chính chung của gia đình

- Điện nước hàng tháng (dự kiến)
- Tiền thuê nhà / trả góp (nếu có)
- Chi phí ăn uống chung toàn gia đình
- Các khoản chi chung định kỳ: internet, bảo hiểm, học phí chung...

### Budget Balance Formula

```
Quỹ tháng = Tổng Thu − Chi chung − Tổng Chi riêng

Dương (+) → Dư quỹ tháng đó   →  quỹ tích lũy tăng
Âm   (−) → Thâm hụt           →  rút từ quỹ tích lũy
```

**Ví dụ (từ Mentor):**
```
Ba:   20,000,000 ₫ thu (đi làm)
Mẹ:   10,000,000 ₫ thu (đi làm)
Anh:  20,000,000 ₫ thu (đi làm)
Con:          0 ₫ thu (học sinh)

Tổng thu:  50,000,000 ₫
Chi chung: 20,000,000 ₫ (điện, nước, ăn, nhà...)
Chi riêng:  5,000,000 × 3 người = 15,000,000 ₫
            2,000,000 × 1 con   =  2,000,000 ₫
Tổng chi:  37,000,000 ₫

→ Quỹ tháng = 50M − 37M = +13,000,000 ₫  (dư)
```

### Cảnh báo ngân sách

| Loại | Trigger | Hành động |
|-|-|-|
| **Thu gần Chi** | Thu dự kiến − Chi dự kiến < 10% | Thông báo đến tất cả thành viên |
| **Vượt chi cá nhân** | Một thành viên chi thực tế > dự kiến nhiều lần liên tiếp | Gợi ý điều chỉnh (tăng dự kiến hoặc giảm thực tế) |

### AI Dự báo Tài chính *(Premium — họp 19/05)*

```
Khi quỹ ổn định (nhiều tháng liên tiếp dương), AI có thể:
→ Dự báo quỹ tích lũy N tháng tới
→ Gợi ý thời điểm có thể chi lớn (mua sắm, du lịch, sửa nhà)
→ Cảnh báo nếu xu hướng chi tăng liên tục

Trong MVP: mock AI response — không cần gọi GPT-4 API live
Chỉ available cho gói Premium (299k/tháng)
```

---

## 8. Task Management *(cập nhật từ họp 19/05 & 22/05)*

### Hai loại Task

| Loại | Mô tả | Ví dụ |
|-|-|-|
| **Task tự phát** | Parent/HoH tạo theo nhu cầu, giao cho bất kỳ thành viên | Đi mua thực phẩm, dọn phòng khách, tắm cho chó |
| **Task định kỳ bắt buộc** | Lặp lại hàng ngày/tuần, có khung giờ cố định, phải có người thực hiện | Ba đưa con đi học 7h–7h30, Mẹ nấu ăn tối 17h–18h, Đổ rác T2-T4-T6 |

### Task Status Flow

```
Ad-hoc:   todo → doing → submitted → done
                               ↘ rejected → (sửa) → submitted

Recurring: scheduled → doing → done
                  → "Không thể làm hôm nay" → [cơ chế điều phối]
```

### Cơ chế điều phối Task định kỳ *(họp 19/05 & 22/05)*

```
1. Thành viên được giao → đánh dấu "Không thể làm hôm nay"
2. Hệ thống gửi thông báo đến CÁC THÀNH VIÊN KHÁC
3. Ai đó nhận thay → task tiếp tục
4. Nếu không ai nhận → Parent/HoH reassign thủ công
5. Task định kỳ KHÔNG ĐƯỢC BỎ SÓT:
   → Phải có người nhận, hoặc
   → Đánh dấu "Đã xử lý" kèm lý do
```

### Task Status Labels

| Enum | Label hiển thị | Màu bg | Màu text |
|-|-|-|-|
| `todo` | Chờ làm | `#F3F4F6` | `#6B7280` |
| `doing` | Đang làm | `#FEF3C7` | `#D97706` |
| `submitted` | Chờ duyệt | `#EFF6FF` | `#2563EB` |
| `done` | Hoàn thành | `#DCFCE7` | `#16A34A` |
| `rejected` | Từ chối | `#FEE2E2` | `#DC2626` |

---

## 9. Calendar Color-coding *(họp 19/05 — mới)*

> 5 loại sự kiện, mỗi loại một màu riêng để phân biệt trên Calendar screen

| Loại | Màu | Hex | Icon |
|-|-|-|-|
| 📋 Task | Xanh dương | `#2563EB` | — |
| 📅 Sự kiện (Event) | Tím | `#7C3AED` | — |
| ✈️ Du lịch | Cyan | `#0EA5E9` | — |
| 🎂 Sinh nhật | Vàng | `#F59E0B` | 🎂 |
| 🏥 Sức khỏe / Khám bệnh | Đỏ nhạt | `#EF4444` | — |

---

## 10. Mời Thành viên *(họp 19/05 — mới)*

> 3 cơ chế song song — đáp ứng mọi đối tượng người dùng

| Cơ chế | Mô tả | Use case |
|-|-|-|
| **QR Code** | Quét bằng camera | Người dùng trẻ, cùng phòng |
| **Share Link** | Copy link mời qua Zalo/SMS | Gửi từ xa |
| **Mã 6 ký tự** | Ví dụ: `A7X-9P2` | Ông bà, thiết bị cũ, gọi điện đọc mã |

**Quy tắc Mã 6 ký tự:**
- Không dùng ký tự dễ nhầm: `O/0`, `I/1`, `l`
- Hết hạn sau **24 giờ**
- Dùng được **1 lần** (single-use)

---

## 11. SOS & An toàn *(cập nhật từ họp 22/05)*

### Mobile App — SOS Flow

```
Hold SOS button 3 giây:
  0.0s: Light haptic
  1.0s: Medium haptic
  2.0s: Medium haptic
  3.0s: Heavy haptic (double) → SEND

→ Gửi vị trí GPS đến tất cả thành viên
→ Cảnh báo chỉ tắt khi:
   - Thành viên khác xác nhận "An toàn"
   - Hoặc người dùng tự xác nhận
```

### Smartwatch — SOS *(họp 22/05 — mới)*

```
Hardware: Đồng hồ thông minh với GPS + cảm biến va chạm

Tự động phát hiện:
→ Đập mạnh vào tường (gia tốc vượt ngưỡng)
→ Gửi cảnh báo đến gia đình

Giao diện đồng hồ (TỐI GIẢN — 3 thành phần):
  1. 💬 Tin nhắn nhanh (Quick message)
  2. 📞 Cuộc gọi
  3. 🚨 Nút SOS

→ Ưu tiên tốc độ phản ứng khẩn cấp — không UI phức tạp
→ Ghi lại lộ trình di chuyển khi SOS kích hoạt
→ Chức năng cứu hộ (rescue) — áp dụng cho mọi thành viên
```

### Location — Pin & Network Status *(họp 19/05 — mới)*

```
Trên bản đồ, mỗi pin thành viên hiển thị badge nhỏ:
  → % pin thiết bị
  → Trạng thái mạng: WiFi / 4G

Cảnh báo tự động:
  Pin < 20%        → badge đỏ + thông báo cho Parent
  Offline > 15 phút → "Mất kết nối · X phút trước"

Pain point Việt Nam: "Gọi con không nghe, không biết hết pin hay mải chơi"
```

---

## 12. Album *(cập nhật từ họp 19/05)*

```
KHÔNG auto-save ảnh từ Chat vào Album

Flow thủ công:
  → User giữ ảnh trong chat
  → Hiện option "Lưu vào Album chung"
  → User xác nhận → ảnh được lưu

Lý do: Docker-per-family có chi phí storage — trẻ spam meme sẽ làm đầy container
Role-based hint: ảnh từ Parent gửi có thể gợi ý "Lưu vào Album" tự động
```

---

## 13. Component Summary

### Custom Widgets (`lib/widgets/`)

| Widget | Props | Dùng cho |
|-|-|-|
| `RingChart` | progress, size, strokeWidth, color, trackColor, child | Budget gauge, spending gauge |
| `WaffleChart` | segments (List\<WaffleSegment\>) | Phân bổ thu nhập |
| `AvatarWidget` | initial, color, size | Avatar thành viên (36/40/44px) |

### Screens Matrix

| Screen | Role | File | Status |
|-|-|-|-|
| `LoginScreen` | All | `auth/login_screen.dart` | ✅ |
| `RegisterScreen` | All | `auth/register_screen.dart` | ✅ |
| `HomeDashboardScreen` | Manager | `parent/home_dashboard_screen.dart` | ✅ |
| `WalletScreen` | Manager | `parent/wallet_screen.dart` | ✅ |
| `TaskManagementScreen` | Manager | `parent/task_management_screen.dart` | ✅ |
| `CalendarScreen` | Manager | `parent/calendar_screen.dart` | ✅ |
| `ChildHomeScreen` | Family Member | `child/child_home_screen.dart` | ✅ |
| `ChildTasksScreen` | Family Member | `child/child_tasks_screen.dart` | ✅ |
| `ChildWalletScreen` | Family Member | `child/child_wallet_screen.dart` | ✅ |
| `ChatScreen` | Shared | `shared/chat_screen.dart` | ✅ |
| `SOSScreen` | Shared | `shared/sos_screen.dart` | ✅ |
| `AlbumScreen` | Shared | `shared/album_screen.dart` | ✅ |
| `ProfileScreen` | Shared | `shared/profile_screen.dart` | ✅ |
| `NotificationsScreen` | Shared | `shared/notifications_screen.dart` | ✅ |
| `AIAssistantScreen` | Shared | `shared/ai_assistant_screen.dart` | ✅ |
| `SubscriptionScreen` | Manager/HoH | — | 🔲 TODO |
| `EditProfileScreen` | All | — | 🔲 TODO |
| `InviteMemberScreen` | Manager | — | 🔲 TODO |
| `CalendarScreen` (color-coded) | Manager | — | 🔲 TODO (nâng cấp) |
| `SOSWatchScreen` | — | — | 🔲 TODO |

---

## 14. UX Patterns

### Wallet Flow *(cập nhật wallet permissions)*

```
Family Member:
  ChildWalletScreen → tap "Xin tiền từ Trưởng/Phó nhóm"
  → Bottom sheet (amount + reason)
  → MoneyProvider.addRequest()
  → SnackBar xác nhận gửi

Manager/Parent:
  WalletScreen → tab "Yêu cầu" (badge count)
  → RequestCard với ✓ / ✗ buttons
  → MoneyProvider.updateStatus(approved/rejected)
  → SnackBar xác nhận
```

### Task Flow *(cập nhật 2 loại task)*

```
Ad-hoc task:
  Manager tạo → giao member → member làm → nộp proof → manager duyệt

Recurring task (mới):
  Manager tạo lịch lặp → hệ thống tự tạo instance mỗi ngày/tuần
  → Member nhận task → làm → xong
  → Nếu không làm được: đánh dấu "Không thể" → hệ thống điều phối
```

### Navigation & Routing

```
/login, /register

/manager/* → ManagerShell (isAdministrative=true)
  tabs: home, chat, calendar, sos, album, profile
  push: /manager/wallet, /manager/tasks

/member/*  → MemberShell (isAdministrative=false)
  tabs: home, tasks, wallet, sos, chat, profile
```

### Edge Cases

| Tình huống | UI xử lý | Status |
|-|-|-|
| Budget < 10% | Alert 🚨 đỏ | ✅ Done |
| Budget 10–30% | Alert ⚠️ vàng | ✅ Done |
| Task bị từ chối | Badge đỏ + nền FEE2E2 | ✅ Done |
| Ví không đủ tiền | Smart CTA đổi label | 🔲 TODO |
| Recurring task — người giao bận | Notification điều phối | 🔲 TODO |
| Pin < 20% | Badge đỏ + cảnh báo | 🔲 TODO |
| Offline > 15 phút | "Mất kết nối · X phút trước" | 🔲 TODO |
| Album — manual save từ chat | Hold → "Lưu vào Album chung" | 🔲 TODO |
| Subscription hết hạn (Parent) | Screen + CTA "Gia hạn ngay" | 🔲 TODO |
| Subscription hết hạn (Member) | "Nhắc nhở Trưởng nhóm gia hạn" | 🔲 TODO |

---

## 15. Figma File Structure

```
File: FC — Mobile Wireframes (Giáp)
URL:  figma.com/design/ENiRsTcclyqz70hW8DciwY

Pages:
├── Wallet & Task Flows
│   ├── Section: 💳 Wallet Flow (6 frames)
│   │   ├── [WF] Manager_FamilyWalletCard
│   │   ├── [WF] Member_FamilyWalletCard
│   │   ├── [WF] Member_FundRequestForm
│   │   ├── [WF] Manager_ApprovalBottomSheet
│   │   ├── [WF] Manager_Approval_Insufficient
│   │   └── [WF] Member_RequestApproved
│   ├── Section: 📋 Task Flow (8 frames)
│   └── Section: 🔔 Subscription Flow (TODO)
│       ├── [WF] Register → Choose Plan
│       ├── [WF] Pricing Table (3 tiers)
│       └── [WF] Invite Member (QR + Link + Code)
│
└── Design System + Edge Cases
    ├── Section A: Color Palette
    ├── Section B: Typography Scale
    ├── Section C: Spacing & Layout
    ├── Section D: Role-based Color Mapping (updated)
    ├── Section E: Icon System — Material Icons
    ├── Section F: Calendar Color-coding (NEW)
    ├── 📦 RejectFeedbackBubble
    └── 🃏 TaskCard (Ad-hoc + Recurring variants)
```

---

## 16. Tech Stack & Dependencies

```yaml
# Mobile (Flutter)
flutter_sdk: ">=3.0.0"
go_router: ^14.x      # Navigation
provider: ^6.x        # State management
google_fonts: ^6.x    # Inter font

# Admin: Web (React)
# Smartwatch: TBD
```

```
Architecture: Provider pattern
State:       AuthProvider, MoneyProvider
Models:      User, MoneyRequest, Task (ad-hoc + recurring)
Navigation:  go_router StatefulShellRoute (indexed stack)
DB:          Free/Family = Shared DB + RLS | Premium = Docker/family
```

---

## 17. Checklist Từ Biên Bản Họp

**Họp 19/05:**
- ☐ Đổi role "Child" → "Family Member" trong code (enum, UI strings)
- ☐ Thêm field `quan_he` vào User model
- ☐ Cập nhật ERD: bảng `member_finance` (income, avg_expense, occupation)
- ☐ Budget Balance Formula + cảnh báo thu gần chi
- ☐ Implement task định kỳ bắt buộc + cơ chế điều phối
- ☐ Thiết kế màn hình Edit Profile (avatar, nghề nghiệp, thu nhập)
- ☐ Thiết kế màn hình Subscription (3 tiers, pricing table)
- ☐ Thiết kế Calendar với color-coding 5 event types
- ☐ Thiết kế Flow mời thành viên: QR + Link + Mã 6 ký tự
- ☐ Cập nhật Map screen: badge pin % + trạng thái mạng
- ☐ Album: manual save từ chat (hold → option)

**Họp 22/05:**
- ☐ Wallet permission matrix (trưởng/phó vs thành viên)
- ☐ Flow xin tiền: member gửi request → trưởng/phó duyệt
- ☐ Xác nhận & document 2 loại Task (tự phát + định kỳ với khung giờ)
- ☐ Cơ chế reassign task định kỳ khi người giao bận
- ☐ SOS smartwatch: GPS + impact detection + xác nhận an toàn + ghi lộ trình
- ☐ Màn hình đồng hồ: 3 thành phần (tin nhắn / gọi / nút SOS)
- ☐ Admin = Web only (không build mobile cho Admin)
- ☐ Review toàn bộ ~41 UC: kiểm tra trùng lặp, bổ sung thiếu
- ☐ Chuẩn bị ERD + Database Design (họp thứ 3, 27/05)

---

*Last updated: 2026-05-23 (từ biên bản họp 19/05 & 22/05) · Author: Hồ Nguyên Giáp (SE171532) · SU26SE032*
