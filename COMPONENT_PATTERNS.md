# Component Patterns & UX Decisions — Family Care Design System
> Resource file cho `figma-mobile-design-system` skill
> Flutter widgets · UX patterns · Edge cases · Codebase patterns

---

## Widget Hierarchy (lib/widgets/ & lib/screens/)

```
Atoms (leaf — không phụ thuộc widget khác)
  ├─ AvatarWidget          Props: initial, color, size
  ├─ RingChart             Props: progress, size, strokeWidth, color, trackColor, child
  └─ WaffleChart           Props: segments (List<WaffleSegment>)

Molecules (dùng Atoms)
  ├─ TaskCard              (inline trong TaskManagementScreen)
  ├─ FamilyWalletCard      (inline trong WalletScreen)
  ├─ ChildWalletCard       (inline trong ChildWalletScreen)
  ├─ TransactionRow        (inline, dùng emoji icon)
  ├─ MemberWalletRow       (inline, dùng AvatarWidget)
  ├─ RequestCard           (inline, dùng AvatarWidget)
  └─ StatusBadge / Chip    (Container với decoration)

Organisms (Screens)
  ├─ WalletScreen          3 tabs: Tổng quan / Lịch sử / Yêu cầu
  ├─ TaskManagementScreen  Filter chips + list + modals
  ├─ ChildWalletScreen     Animated ring + request sheet
  └─ ChildTasksScreen      Gamified task list
```

---

## RingChart Widget

### Mục đích
Hiển thị progress dạng donut chart (vòng tròn). Dùng cho budget gauge và spending gauge.

### Props

```dart
RingChart({
  required double progress,  // 0.0 → 1.0
  required double size,      // outer diameter (px)
  double? strokeWidth,       // ring thickness (default 10)
  required Color color,      // filled arc color
  Color? trackColor,         // background arc color
  Widget? child,             // center widget
})
```

### Usage patterns

```dart
// WalletScreen — Budget Gauge (lớn, có center text)
RingChart(
  progress: spentRatio,     // totalExp / income
  size: 110,
  strokeWidth: 14,
  color: AppColors.shared,
  trackColor: const Color(0xFFDCFCE7),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('${(spentRatio * 100).round()}%', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
      Text('đã chi', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
    ],
  ),
)

// ChildWalletScreen — Spending Gauge (nhỏ, animated)
AnimatedBuilder(
  animation: _ring,
  builder: (_, __) => SizedBox(
    width: 80, height: 80,
    child: Stack(alignment: Alignment.center, children: [
      RingChart(progress: _ring.value, color: AppColors.planned, size: 80),
      Text('${(_ring.value * 100).round()}%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
    ]),
  ),
)
```

### Animation pattern (ChildWalletScreen)

```dart
// Khởi tạo trong initState
_ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: 900));
_ring = Tween<double>(begin: 0, end: targetPct)
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
_bal  = Tween<double>(begin: 0, end: balance.toDouble())
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
_ctrl.forward();
```

---

## WaffleChart Widget

### Mục đích
Grid chart trực quan hóa phân bổ phần trăm theo màu. Dùng cho "Phân bổ thu nhập".

### Props

```dart
WaffleSegment({
  required Color color,
  required int pct,     // percentage (0–100)
  required String label,
  required int amount,
})

WaffleChart({
  required List<WaffleSegment> segments,
})
```

### Usage

```dart
WaffleChart(segments: const [
  WaffleSegment(color: AppColors.income, pct: 50, label: 'Thu nhập',  amount: _income),
  WaffleSegment(color: AppColors.shared, pct: 20, label: 'Chi chung', amount: _sharedExp),
  WaffleSegment(color: AppColors.sos,    pct: 15, label: 'Chi riêng', amount: _privateExp),
])
// Phần còn lại (15%) tự động fill Neutral/200
```

---

## AvatarWidget

### Mục đích
Avatar tròn với chữ cái đầu. Dùng cho danh sách thành viên, request card, task assignee.

### Props

```dart
AvatarWidget({
  required String initial,  // text hiển thị, vd: 'AN', 'BI', 'ME'
  required Color color,     // background color
  required double size,     // diameter (px)
})
```

### Common sizes

```dart
AvatarWidget(initial: 'AN', color: AppColors.avatarOrange, size: 44)  // Request card
AvatarWidget(initial: 'ME', color: AppColors.avatarBlue,   size: 40)  // Member row
AvatarWidget(initial: 'BI', color: AppColors.avatarPurple, size: 36)  // Task assignee
```

---

## TaskCard (inline pattern)

### Cấu trúc thực tế (TaskManagementScreen)

```dart
GestureDetector(
  onTap: () => task.status == TaskStatus.submitted ? showApproveSheet(task) : null,
  child: Container(
    margin: EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [...],
    ),
    child: Row(children: [
      // Left status bar (color by category)
      Container(width: 4, height: 60,
        decoration: BoxDecoration(color: task.categoryColor, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 10),
      // Content
      Expanded(child: Column(children: [
        Row(children: [
          Expanded(child: Text(task.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700))),
          if (task.status == TaskStatus.submitted) _submitBadge,
        ]),
        SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          _chip(st.label, st.bg, st.color),      // Status chip
          _chip('⚡ ${task.xp} XP', ...),        // XP chip
          _chip('💰 ${reward}K', ...),            // Money chip
        ]),
      ])),
      SizedBox(width: 8),
      AvatarWidget(initial: task.assignee, color: task.assigneeColor, size: 36),
    ]),
  ),
)
```

### Task Status Config

```dart
static const _statusCfg = {
  TaskStatus.todo:      (label: 'Chờ làm',    bg: Color(0xFFF3F4F6), color: Color(0xFF6B7280)),
  TaskStatus.doing:     (label: 'Đang làm',   bg: Color(0xFFFEF3C7), color: Color(0xFFD97706)),
  TaskStatus.submitted: (label: 'Chờ duyệt',  bg: Color(0xFFEFF6FF), color: AppColors.planned),
  TaskStatus.done:      (label: 'Hoàn thành', bg: Color(0xFFDCFCE7), color: Color(0xFF16A34A)),
  TaskStatus.rejected:  (label: 'Từ chối',    bg: Color(0xFFFEE2E2), color: Color(0xFFDC2626)),
};
```

### Task Flow

```
todo → doing → submitted → done
                        ↘ rejected → (fix) → submitted
```

---

## Approve/Reject Bottom Sheet

### Pattern

```dart
// Trigger: tap vào task có status=submitted
bottomSheet: _approveTask != null ? _approveSheet() : (_showCreate ? _createSheet() : null)
```

### Structure

```dart
Container(
  padding: EdgeInsets.fromLTRB(28, 28, 28, 40),
  decoration: BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text('✅  Duyệt task', style: ...20px w700),
    Text(task.title, ...18px w700),
    Row([assignee, xp, reward]),
    Row([
      // Approve button
      ElevatedButton(backgroundColor: AppColors.success, onPressed: () => setState(() { t.status = TaskStatus.done; _approveTask = null; })),
      // Reject button
      ElevatedButton(backgroundColor: AppColors.danger,  onPressed: () => setState(() { t.status = TaskStatus.rejected; _approveTask = null; })),
    ]),
    TextButton('Xem lại sau'),
  ]),
)
```

---

## Create Task Bottom Sheet

```dart
// Trigger: FAB (+) button ở header
// Fields: title (TextField) + assignee (pill selector)

Container(
  padding: EdgeInsets.fromLTRB(28, 28, 28, 40),
  child: Column(children: [
    Text('📋  Tạo task mới', ...20px w700),
    // Title input
    Container(height: 52, child: TextField(controller: _titleCtrl, ...)),
    // Assignee selector
    Row(children: ['AN', 'BI'].map((n) => GestureDetector(
      onTap: () => setState(() => _newAssignee = n),
      child: Container(
        decoration: BoxDecoration(
          color: _newAssignee == n ? AppColors.link : Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(n == 'AN' ? 'An' : 'Bi'),
      ),
    )).toList()),
    // Submit button
    ElevatedButton(backgroundColor: AppColors.link, ...),
  ]),
)
```

---

## UX Patterns — Wallet Flow

### Request–Approve Pattern

```
Child (Member):
  ChildWalletScreen → tap "Xin tiền từ Trưởng/Phó nhóm"
  → showModalBottomSheet (amount + reason)
  → MoneyProvider.addRequest(MoneyRequest)
  → SnackBar xác nhận

Manager/Parent:
  WalletScreen → tab "Yêu cầu" (badge count)
  → RequestCard với ✓ / ✗ buttons
  → MoneyProvider.updateStatus(id, approved/rejected)
  → SnackBar xác nhận
```

### FundRequestForm

```dart
// Quick amounts — thực tế chưa implement, dùng free-text TextField
TextField(keyboardType: TextInputType.number, hintText: 'Nhập số tiền (₫)...')

// TODO: Thêm Quick Amounts filter theo parent balance:
// final quickAmounts = [50000, 100000, 200000].where((a) => a <= parentBalance).toList();
```

### Smart CTA — Insufficient Balance

```dart
// Trigger: walletBalance < requestAmount
// Hiện tại: WalletScreen chưa implement Smart CTA

// TODO target pattern:
final canApprove = parentBalance >= requestAmount;
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: canApprove ? AppColors.success : AppColors.danger,
  ),
  onPressed: canApprove ? onApprove : onTopUp,
  child: Text(canApprove ? '✓ Duyệt ngay' : '↑ Nạp thêm ${gap}₫'),
)
```

---

## UX Patterns — Task Flow

### Filter Chips (Manager view)

```
[Tất cả] [Chờ duyệt 🔴n] [Đang làm] [Hoàn thành]
```

### Hai loại Task *(họp 19/05 & 22/05 — mới)*

#### Ad-hoc Task (Tự phát)

```
Manager/Parent tạo theo nhu cầu:
  → Tiêu đề + người được giao + thời gian cụ thể
  → Flow: todo → doing → submitted → done/rejected
  
Ví dụ: "Đi mua thực phẩm · 14:00 hôm nay"
```

#### Recurring Task (Định kỳ bắt buộc)

```
Lặp lại hàng ngày/tuần, có khung giờ cố định:
  → Tiêu đề + người thực hiện + lịch lặp + khung giờ
  → Tự động tạo instance theo lịch

Ví dụ: "Ba đưa con đi học · 7h–7h30 · Thứ 2–6"
         "Đổ rác · T2-T4-T6 · Trước 7h"

Cơ chế điều phối khi người giao bận:
  1. Thành viên tap "Không thể làm hôm nay"
  2. Hệ thống push notify đến thành viên khác
  3. Ai đó tap "Nhận thay" → task được reassign
  4. Nếu không ai nhận → Trưởng/Phó reassign thủ công
  5. Bắt buộc: phải có "Hoàn thành" hoặc "Đã xử lý + lý do"
```

#### RecurringTaskCard (Figma target)

```
Khác biệt so với AdHocTaskCard:
  → Badge "🔁 Định kỳ" màu Neutral (gray)
  → Khung giờ hiển thị: "7h–7h30"
  → Nút "Không thể làm hôm nay" (thay nút "Làm ngay")
  → Khi người giao bận: card overlay "⚠ Cần người nhận thay"

Props bổ sung:
  isRecurring: bool
  timeSlot:    String  // "7h–7h30"
  cannotDo:    VoidCallback  // "Không thể hôm nay"
```

### Task Rejected UX

```
status = TaskStatus.rejected
→ Badge "Từ chối" (#FEE2E2 bg, #DC2626 text)
→ status bar trái vẫn màu categoryColor
→ Family Member thấy trong ChildTasksScreen
→ TODO: thêm RejectFeedbackBubble để hiện lý do từ chối
```

### Proof Submission

```
Hiện tại: chưa implement trong ChildTasksScreen
TODO target pattern:
  → Direct Camera (không qua Gallery)
  → Watermark: "Tên task · DD/MM/YYYY HH:mm"
  → CameraPermission denied: Empty state + "Mở Cài đặt"
```

---

## Wallet Permission Matrix *(họp 22/05 — mới)*

> Dùng `user.role` để ẩn/hiện các thành phần UI — không xóa, chỉ ẩn (opacity/visibility)

| Hành động | Trưởng nhóm | Phó nhóm | Family Member |
|---|---|---|---|
| Xem tài chính hạng 9 | ✅ | ✅ | ❌ (ẩn section) |
| Nạp / rút ví chung | ✅ | ✅ | ❌ (ẩn button) |
| Xem số dư ví cá nhân | ✅ | ✅ | ✅ (ví của mình) |
| Nạp vào ví cá nhân | ✅ | ✅ | ✅ |
| Rút trực tiếp ví cá nhân | ✅ | ✅ | ❌ → phải dùng Request flow |
| Gửi request xin tiền | ❌ | ❌ | ✅ |
| Duyệt / từ chối request | ✅ | ✅ | ❌ (ẩn approve buttons) |

```dart
// Pattern: conditional render theo role
final isManager = user.isAdministrative;

// Ẩn sensitive financial section
if (isManager) _buildSensitiveFinanceSection(),

// Ẩn/hiện approve buttons trong RequestCard
if (isManager) Row(children: [approveBtn, rejectBtn])
else SizedBox.shrink(),
```

---

## Invitation UI *(họp 19/05 — mới)*

> 3 cơ chế mời thành viên song song

### InviteMemberScreen (TODO)

```
Layout (bottom sheet hoặc full screen):

  [Tab: QR Code] [Tab: Link] [Tab: Mã số]

  Tab QR:
    → QRCode widget (package: qr_flutter)
    → "Hết hạn sau 24 giờ"

  Tab Link:
    → Copy link button
    → Share button (share_plus)

  Tab Mã số:
    → Text lớn: "A7X-9P2"  ← format X3-X3 hoặc XXXXXX
    → "Hết hạn sau 24 giờ · Dùng 1 lần"
    → Không dùng: O, 0, I, 1, l

Widget pattern cho Mã 6 ký tự:
  Text(
    code,  // "A7X-9P2"
    style: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: 8,
      color: AppColors.textPrimary,
    ),
  )
```

---

## Location Badge *(họp 19/05 — mới)*

> Badge nhỏ trên mỗi map pin của thành viên

### LocationPinBadge (TODO)

```
Hiển thị overlay trên map pin:
  → % pin thiết bị (ví dụ: "72%")
  → Trạng thái mạng: icon WiFi hoặc 4G

Màu sắc badge:
  pin >= 20%: Neutral/500 (#6B7280)
  pin < 20%:  SOS (#EF4444) + pulse animation

Cảnh báo tự động:
  pin < 20%         → push notification đến Parent
  offline > 15 phút → "Mất kết nối · X phút trước"

Flutter target:
  Stack(children: [
    // Map pin icon
    Icon(Icons.location_on, color: avatarColor, size: 36),
    // Badge overlay
    Positioned(
      top: 0, right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: batteryPct < 20 ? AppColors.sos : Color(0xFF374151),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$batteryPct%',
          style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ),
  ])
```

---

## SOS Smartwatch UI *(họp 22/05 — mới)*

> Giao diện tối giản — ưu tiên tốc độ phản ứng khẩn cấp

### 3 thành phần duy nhất

```
Smartwatch screen layout (small screen ~1.5"):

  ┌─────────────────┐
  │  [💬] Tin nhắn  │  ← Quick message (preset options)
  │  [📞] Gọi       │  ← Direct call to family
  │  [🚨] SOS       │  ← Hold 3s → Send SOS
  └─────────────────┘

KHÔNG có: navigation, settings, wallet, task list, calendar
```

### SOS Smartwatch Flow

```
Hardware triggers:
  1. User hold SOS button 3 giây
  2. Gia tốc kế phát hiện va chạm mạnh (vượt ngưỡng)

Khi SOS kích hoạt:
  → GPS ghi lại tọa độ hiện tại
  → Ghi lộ trình di chuyển liên tục
  → Push notification đến tất cả thành viên gia đình

Tắt cảnh báo (2 cách):
  1. Thành viên khác xác nhận "An toàn" trong app
  2. Người dùng tự xác nhận trên đồng hồ

Chức năng cứu hộ (Rescue):
  → Áp dụng cho mọi thành viên (không chỉ trẻ em)
  → Thành viên nhận notify có thể tap "Tôi đang đến"
```

---

## Edge Cases — Implementation Status

### Wallet

| Tình huống | Status | UI xử lý |
|---|---|---|
| Ví không đủ tiền | 🔲 TODO | Smart CTA đổi label + badge cảnh báo |
| Child chưa có giao dịch | ✅ Done | Hardcoded mock data |
| Request amount = 0 | ✅ Done | `if (amount <= 0) return;` |
| Manager reject request | ✅ Done | `updateStatus → rejected` + SnackBar |

### Task

| Tình huống | Status | UI xử lý |
|---|---|---|
| Camera permission denied | 🔲 TODO | Empty state → "Mở Cài đặt" |
| Task bị reject | ✅ Done | Badge đỏ + nền FEE2E2 |
| Task overdue | 🔲 TODO | Badge "🕐 Quá hạn" SOS color |
| Family Member chưa có task | 🔲 TODO | EmptyState gamified |
| Create task — ad-hoc | ✅ Done | Bottom sheet: title + assignee |
| Create task — định kỳ bắt buộc | 🔲 TODO | Bottom sheet: title + lịch lặp + khung giờ |
| Người giao task định kỳ bận | 🔲 TODO | "Không thể hôm nay" → notify điều phối |

### Subscription *(cập nhật role name)*

| Tình huống | Status | UI xử lý |
|---|---|---|
| Gói hết hạn — Trưởng/Phó nhóm | 🔲 TODO | Screen + bảng giá 3 tiers + CTA "Gia hạn ngay" |
| Gói hết hạn — Family Member | 🔲 TODO | "Nhắc nhở Trưởng nhóm gia hạn" + push |
| Free → Family upgrade | 🔲 TODO | Pricing table 3 tiers |
| Family → Premium upgrade | 🔲 TODO | Docker spin-up progress indicator |

### Location & SOS *(họp 19/05 & 22/05 — mới)*

| Tình huống | Status | UI xử lý |
|---|---|---|
| Pin thành viên < 20% | 🔲 TODO | Badge đỏ trên map pin + push notify |
| Thành viên offline > 15 phút | 🔲 TODO | "Mất kết nối · X phút trước" |
| SOS kích hoạt (phone) | 🔲 TODO | Full-screen alert + map + ghi lộ trình |
| SOS kích hoạt (watch) | 🔲 TODO | Auto-detect va chạm → gửi cảnh báo |
| Xác nhận an toàn sau SOS | 🔲 TODO | Thành viên bấm "An toàn" để tắt |

### Album *(họp 19/05 — mới)*

| Tình huống | Status | UI xử lý |
|---|---|---|
| Ảnh trong chat → Album | 🔲 TODO | Hold ảnh → "Lưu vào Album chung" |
| Auto-save | ❌ KHÔNG làm | Tránh spam storage Docker |

### Network

| Tình huống | Status | UI xử lý |
|---|---|---|
| Mất mạng | 🔲 TODO | OfflineBanner vàng top |
| Offline task done | 🔲 TODO | AsyncStorage queue + ↻ icon |
| API timeout | 🔲 TODO | Toast error + Retry |

### Budget Alerts (WalletScreen — ✅ Implemented)

```dart
// _alertBar() trong WalletScreen
if (_bufferPct < 10)  → 🚨 Cảnh báo ngân sách (đỏ)
if (_bufferPct < 30)  → ⚠️ Thu gần Chi (vàng)
else                  → ✅ Dư tháng tốt! (xanh)
```

---

## State Management (Provider)

### AuthProvider

```dart
// lib/providers/auth_provider.dart
class AuthProvider extends ChangeNotifier {
  User? user;
  bool get isLoggedIn => user != null;
  // user.isAdministrative → Manager Shell / Member Shell routing
}
```

### MoneyProvider

```dart
// lib/providers/money_provider.dart
class MoneyProvider extends ChangeNotifier {
  List<MoneyRequest> get requests => [...];
  List<MoneyRequest> get pendingRequests => requests.where((r) => r.status == pending).toList();

  void addRequest(MoneyRequest r);
  void updateStatus(String id, MoneyRequestStatus status);
}
```

### MoneyRequest Model

```dart
// lib/models/money_request.dart
enum MoneyRequestStatus { pending, approved, rejected }

class MoneyRequest {
  final String id, senderId, senderName, senderAvatarInitial, reason;
  final int senderAvatarColor;
  final double amount;
  final DateTime createdAt;
  MoneyRequestStatus status;
}
```

---

## Figma MCP — Gotchas & Fixes (Flutter context)

### Gotcha 1: Floating nodes

```javascript
// FIX: Mọi node phải nằm trong Section hoặc Frame
section.appendChild(node);  // ✅
// KHÔNG append thẳng vào PAGE
```

### Gotcha 2: setCurrentPageAsync

```javascript
await figma.setCurrentPageAsync(targetPage);
figma.currentPage.appendChild(frame);  // ✅ (không cache biến)
```

### Gotcha 3: hex → RGB (Figma API)

```javascript
function h(hex) {
  return {
    r: parseInt(hex.slice(1,3), 16) / 255,
    g: parseInt(hex.slice(3,5), 16) / 255,
    b: parseInt(hex.slice(5,7), 16) / 255,
  };
}
// Dùng: node.fills = [{ type: "SOLID", color: h("#EF4444") }]  // SOS
```

### Gotcha 4: Font loading

```javascript
await figma.loadFontAsync({ family: "Inter", style: "Regular" });
await figma.loadFontAsync({ family: "Inter", style: "Medium" });
await figma.loadFontAsync({ family: "Inter", style: "Semi Bold" });
await figma.loadFontAsync({ family: "Inter", style: "Bold" });
```

---

## Checklist Trước Bàn Giao Dev

```
Design System:
□ Color tokens đồng bộ với AppColors (class + file COLOR_TOKENS.md)
□ Text styles documented với fontSize + fontWeight
□ Spacing values documented

Components:
□ Mọi widget dùng AppColors — không hardcode hex string
□ AvatarWidget dùng đúng avatarColor theo role
□ SOS màu luôn AppColors.sos (#EF4444) 🔒

Screens:
□ Happy Path: Wallet + Task flows hoàn chỉnh
□ Edge cases: budget alert, task rejected, empty state
□ Bottom sheets: create task, approve task, fund request

Còn thiếu (TODO):
□ RejectFeedbackBubble widget (standalone)
□ Camera proof submission
□ Smart CTA khi ví không đủ
□ Quick amount chips cho fund request
□ Offline banner
□ Task overdue badge
□ Subscription expiry screens
```
