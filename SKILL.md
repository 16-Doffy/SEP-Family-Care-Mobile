---

name: figma-mobile-design-system
version: "2.1.0"
description: >
  Hướng dẫn quy trình phân tích yêu cầu → xây dựng Design System →
  tạo Wireframe → build Component Set trong Figma cho Mobile App Flutter.
  Dựa trên dự án thực tế Family Care (SU26SE032) — Flutter + Material 3.
  Cập nhật từ biên bản họp 19/05 & 22/05: Family Member role, subscription tiers,
  calendar color-coding, 2 loại task, wallet permissions, SOS smartwatch.
author: Hồ Nguyên Giáp (SE171532)
tags:
  - figma
  - mobile
  - flutter
  - dart
  - design-system
  - wireframe
  - ux
  - material3
triggers:
  - "thiết kế mobile"
  - "design system figma"
  - "wireframe"
  - "component figma"
  - "color palette"
  - "ui kit"
  - "flutter design"
resources:
  - id: color-tokens
    path: resources/COLOR_TOKENS.md
    description: Color tokens đồng bộ với AppColors Flutter — hex, Flutter values, role mapping
  - id: typography-spacing
    path: resources/TYPOGRAPHY_SPACING.md
    description: Typography scale (GoogleFonts.inter) và spacing thực tế trong codebase
  - id: component-patterns
    path: resources/COMPONENT_PATTERNS.md
    description: Widget breakdown, UX patterns, edge case status, Provider pattern

---

# Figma Mobile Design System Skill

## Mục tiêu

Skill này hướng dẫn quy trình đầy đủ từ phân tích yêu cầu đến tạo
Design System và Wireframe trong Figma cho **Family Care Flutter App**,
đảm bảo output có thể bàn giao trực tiếp cho Developer Flutter.

> **Lưu ý quan trọng:** Dự án dùng **Flutter/Dart** (không phải React Native).
> - Icons: `Icons.*` (Material Icons) — không phải Lucide
> - Font: `GoogleFonts.inter()` — không phải `Inter` font family trực tiếp
> - Spacing: hardcode trong `EdgeInsets` — không có spacing constants file
> - State: Provider pattern (`AuthProvider`, `MoneyProvider`)

---

## Quy trình 4 giai đoạn

### Giai đoạn 1 — Phân tích & Cấu trúc (Làm trước, không vẽ)

**Bước 1.1 — Xác định constraints thực tế**

```
Kiểm tra trước khi làm bất cứ điều gì:
- Figma plan? (Starter: 3 pages max → dùng Sections)
- Thành viên khác đang dùng page/file nào? → KHÔNG đụng vào
- Platform target: Mobile 393×852 (iPhone 14)
- Stack kỹ thuật: Flutter + Material 3 + go_router + provider
- BottomNavBar: white bg, height 60px (không phải 82px)
```

**Bước 1.2 — Cấu trúc Page (tối ưu cho Figma Starter)**

```
Vì Starter giới hạn 3 pages → dùng Sections thay vì Pages:

Page 1: [Của thành viên khác — KHÔNG ĐỤNG]
Page 2: "Wallet & Task Flows"
  Section: [WF] Wallet Flow — Happy Path
  Section: [WF] Task Flow — Happy Path
  Section: [WF] Subscription + Invite Member Flow (MỚI)
Page 3: "Design System + Edge Cases"
  Section A: Color Palette (+ Calendar Event Colors)
  Section B: Typography Scale
  Section C: Spacing & Layout
  Section D: Role-based Color Mapping (Family Member updated)
  Section E: Icon System — Material Icons
  Section F: Calendar Color-coding (MỚI — 5 event types)

Lợi ích Sections vs Pages:
  ✅ Prototype nối được (cross-page prototype KHÔNG hoạt động trên Starter)
  ✅ Thấy Feedback Loop Manager↔Member trong cùng canvas
  ✅ Không bị giới hạn page count
```

**Bước 1.3 — Xác định Happy Path trước**

```
KHÔNG wireframe tất cả cùng lúc.
Chỉ wireframe Happy Path → review → sau đó mới thêm edge cases.

Wallet Happy Path (6 frames):
  Manager xem ví → Family Member xin tiền → Manager duyệt → Member nhận tiền

Task Happy Path — Ad-hoc (8 frames):
  Manager tạo task → Family Member làm → nộp proof → Manager duyệt → nhận thưởng

Task Happy Path — Recurring (4 frames):  [MỚI]
  Recurring task scheduled → Member không thể làm → điều phối → Member khác nhận

Subscription Flow (3 frames):  [MỚI]
  Register → Pricing table (3 tiers) → Invite Member (QR + Link + Mã 6 ký tự)
```

---

### Giai đoạn 2 — Wireframe (Grayscale, không màu)

**Nguyên tắc Wireframe:**

```
- Frame size: 393 × 852px (iPhone 14)
- Màu: Grayscale hoàn toàn (#F8FBF5 bg, #FFFFFF card, #111827 text)
- NGOẠI LỆ: SOS button luôn đỏ #DC2626 ngay từ wireframe (Muscle Memory)
- Không dùng màu brand cho đến giai đoạn Hi-Fi
- Dùng emoji/text làm icon placeholder (không cần SVG thật)
- Annotation thay cho logic phức tạp (Dev Notes)
```

**Canvas layout cho Flow:**

```
Manager screens (bên trái) ←→ Member screens (bên phải)
Mũi tên nối thể hiện Feedback Loop
Khoảng cách giữa frames: 48px (GAP = 48)
Label frame: đặt ở y = frameY - 28, font 12px Semi Bold
```

**Grayscale Palette cho Wireframe:**

```javascript
const WF_COLORS = {
  bg:       "#F8FBF5",  // page background (tông xanh kem)
  surface:  "#FFFFFF",  // card surface
  surfaceD: "#F3F4F6",  // input/chip background
  border:   "#E5E7EB",  // border, divider
  text1:    "#111827",  // text primary
  text2:    "#6B7280",  // text secondary
  disabled: "#9CA3AF",  // placeholder, disabled
  cta:      "#333333",  // button (dark, no brand color yet)
  accent:   "#738AF4",  // brand placeholder (đổi ở Hi-Fi)
  sos:      "#DC2626",  // SOS — KHÔNG bao giờ thay đổi 🔒
  success:  "#16A34A",  // success state reference
  warning:  "#D97706",  // warning state reference
}
```

**Figma MCP — Pattern tránh bug:**

```javascript
// ✅ ĐÚNG — luôn dùng setCurrentPageAsync trước khi build
await figma.setCurrentPageAsync(targetPage);
for (const n of [...figma.currentPage.children]) n.remove(); // clean
// Build: figma.currentPage.appendChild(frame) — KHÔNG dùng biến cache

// ❌ SAI — tạo nodes trực tiếp trên PAGE (gây floating nodes)
PAGE.appendChild(textLabel); // labels sẽ lơ lửng, gây loạn canvas

// ✅ ĐÚNG — wrap vào Section sau khi build frames
const section = figma.createSection();
section.name = "💳 Wallet Flow — Happy Path";
for (const frame of walletFrames) section.appendChild(frame);
```

---

### Giai đoạn 3 — Design System (Foundations trước Components)

**Thứ tự bắt buộc:**

```
1. Color Palette → đăng ký Local Styles (sync với AppColors Flutter)
2. Typography Scale → đăng ký Text Styles (GoogleFonts.inter patterns)
3. Spacing reference (screen padding 20px, card padding 20px, nav 60px)
4. Role → Color mapping documentation
5. Icon System documentation (Material Icons, không phải Lucide)
6. Components (sau khi có đủ Foundations)
```

**Lý do thứ tự này:**

```
Component cần màu để set fill → màu phải có trước
Skeleton Screen cần biết layout component thật → build skeleton SAU Hi-Fi
"Vẽ bóng trước khi có vật thể → khi vật thể thay đổi phải vẽ lại bóng"
```

**Đăng ký Figma Local Styles:**

```javascript
// Color Style — sync với AppColors Flutter
const colorStyle = figma.createPaintStyle();
colorStyle.name = "Primary/500";  // format: Category/Weight
colorStyle.paints = [{ type: "SOLID", color: h("#2563EB") }];

// h() helper
function h(hex) {
  return {
    r: parseInt(hex.slice(1,3), 16) / 255,
    g: parseInt(hex.slice(3,5), 16) / 255,
    b: parseInt(hex.slice(5,7), 16) / 255,
  };
}

// Text Style — GoogleFonts.inter mapping
const textStyle = figma.createTextStyle();
textStyle.name = "Type/H1";      // format: Type/Name
textStyle.fontName = { family: "Inter", style: "Bold" };
textStyle.fontSize = 22;
textStyle.lineHeight = { unit: "PIXELS", value: 28 };
```

**Xem resource đầy đủ:**
- Color tokens → `resources/COLOR_TOKENS.md`
- Typography + Spacing → `resources/TYPOGRAPHY_SPACING.md`

---

### Giai đoạn 4 — Components (Atomic Design)

**Thứ tự build components:**

```
1. Atomic components (leaf):
   StatusBadge, XPChip, MoneyChip, AvatarWidget, LocationPinBadge

2. Molecule components:
   TaskCard (ad-hoc + recurring variants)
   WalletCard, FamilyMemberWalletCard
   RingChart, WaffleChart, ApprovalBottomSheet
   InviteCodeWidget (mã 6 ký tự)

3. Organism:
   TaskManagementScreen, WalletScreen, CalendarScreen (color-coded)
   BottomNavBar, SubscriptionPricingTable
```

**Nested Component vs vẽ thẳng:**

```
✅ Nested Component khi:
  - Widget xuất hiện ở nhiều màn hình khác nhau
  - Dev cần import riêng (separate .dart file)
  - Cần thay đổi độc lập (sửa 1 chỗ → tất cả instances tự cập nhật)

❌ Vẽ thẳng khi:
  - Component chỉ xuất hiện DUY NHẤT ở 1 chỗ
  - Không có logic riêng, chỉ là layout decoration
```

**Component Set — Auto Layout bắt buộc:**

```javascript
const card = figma.createComponent();
card.layoutMode          = "VERTICAL";
card.paddingLeft         = 20;   // screen padding standard
card.paddingRight        = 20;
card.paddingTop          = 20;
card.paddingBottom       = 20;
card.itemSpacing         = 12;
card.primaryAxisSizingMode  = "AUTO";  // height = hug
card.counterAxisSizingMode  = "FIXED"; // width = fill container

// Component description (cho Dev inspect)
card.description =
  "Flutter: lib/widgets/ or inline in Screen\n" +
  "Colors: AppColors.* (app_colors.dart)\n" +
  "Font: GoogleFonts.inter()\n" +
  "Spacing: EdgeInsets.all(20)";
```

**Xem patterns đầy đủ → `resources/COMPONENT_PATTERNS.md`**

---

## Key Decisions & Lý do

### UX Decisions

| Quyết định | Lý do |
|-|-|
| Filter chips thay Kanban 4 cột | Kanban khó implement đúng trong Flutter + fit tốt hơn với danh sách dài |
| Request–Approve (không chuyển thẳng) | Phụ huynh kiểm soát dòng tiền, Financial Education cho thành viên |
| Task Rejected → về "Đang làm" | Mental Model: "Chờ duyệt" = Inbox Parent, reject → ball về Member |
| Proof: Direct Camera | Tránh Member dùng ảnh cũ, watermark timestamp tự động |
| BottomNavBar white bg, height 60px | Material 3 standard, gọn hơn dark nav cũ |
| SOS luôn là circle #DC2626 | Nhận ra ngay không cần nhìn kỹ — Muscle Memory |
| Album: Manual save từ chat | Docker storage có chi phí — tránh spam meme làm đầy container |
| Smartwatch UI chỉ 3 thành phần | Ưu tiên tốc độ phản ứng khẩn cấp — không UI phức tạp |
| Role "Family Member" thay "Child" | Bao quát: ông bà, anh chị em không phải "con cái" |
| Subscription tiêu chí: storage thay số người | Gia đình VN 7–10 người, giới hạn người → mất khách |
| Shared DB + RLS cho Free/Family | Tiết kiệm chi phí — nhiều gia đình dùng chung, bảo mật qua RLS |
| Docker riêng cho Premium | Isolation hoàn toàn — điểm cộng kiến trúc khi báo cáo SDD |

### Technical Decisions

| Quyết định | Lý do |
|-|-|
| Flutter (không phải RN) | Team đã chọn Flutter/Dart |
| Material 3 + Material Icons | Consistent với Flutter ecosystem |
| go_router StatefulShellRoute | Indexed stack nav, separate branch states |
| GoogleFonts.inter() trực tiếp | Không cần custom font file, load từ network |
| Provider (không phải Bloc/Riverpod) | Đơn giản hơn, đủ cho scale hiện tại |
| Hardcode padding 20px | Convention đơn giản — không over-engineer |

---

## Checklist Trước Khi Bàn Giao Cho Dev

```
Design System:
□ Color tokens sync với AppColors Flutter (hex values khớp)
□ Text styles documented với fontSize + fontWeight
□ Icon system: Material Icons name list
□ Role → Color mapping documented (Family Member, không phải Child)
□ BottomNavBar: white bg, height 60px (KHÔNG phải 82px)
□ Calendar Event Colors: 5 loại + calTravel #0EA5E9 (mới)

Components:
□ Mọi component dùng Auto Layout
□ Component descriptions viết đủ Flutter file path
□ Width = "Fill Container"
□ SOS luôn fill #DC2626 🔒 (KHÔNG dùng #EF4444 cũ)
□ TaskCard: 2 variants (ad-hoc + recurring)
□ InviteCodeWidget: Mã 6 ký tự với letterSpacing
□ LocationPinBadge: % pin + network status

Wireframes:
□ Happy Path hoàn chỉnh (Wallet + Task ad-hoc + Task recurring)
□ Subscription flow: Register → Pricing → Invite (QR+Link+Code)
□ Edge cases: budget alert, task rejected, offline, pin <20%
□ Dev Notes annotation trên màn hình phức tạp
□ Prototype connections cho ít nhất Wallet + Task flows

Họp 19/05 checklist:
□ Thiết kế màn hình Edit Profile (avatar, nghề nghiệp, thu nhập)
□ Thiết kế màn hình Subscription (3 tiers, pricing table)
□ Thiết kế Calendar với color-coding 5 event types
□ Thiết kế Flow mời thành viên: QR + Link + Mã 6 ký tự
□ Cập nhật Map screen: badge pin % + trạng thái mạng
□ Album: manual save pattern (hold → option)

File Structure:
□ Canvas chỉ chứa Sections (không có floating nodes)
□ Frame labels rõ ràng
□ Không có duplicate frames cùng tên
□ Section F: Calendar Color-coding (mới)
```

---

## Lỗi Thường Gặp & Fix

| Lỗi | Nguyên nhân | Fix |
|-|-|-|
| Frames không persist | Không dùng `setCurrentPageAsync` | Gọi trước khi build |
| Floating text nodes | Append vào PAGE thay vì Section/Frame | Xóa non-FRAME nodes, wrap vào Section |
| Duplicate frames | `createFrame()` không check tên | Xóa toàn bộ page rồi rebuild |
| Rate limit MCP | Quá nhiều tool calls | Chờ reset hoặc tạo file mới |
| `createPage()` lỗi | Figma Starter (3 pages max) | Dùng Sections hoặc upgrade Education |
| `set_fills` failed | Pass hex string thay vì `{r,g,b}` | Dùng `h()` helper |
| Font not loaded | Tạo text trước khi load font | Gọi `loadFontAsync` trước |

---

## Màu Thực Tế (quick reference)

> ⚡ Cập nhật 23/05/2026 — Rebrand theo logo FamilyCare

```
background:    #F8FBF5

--- PRIMARY scale (Hồng Vỏ Đỗ — Brand) ---
primary50:     #FFF5F7
primary100:    #FEACBA
primary400:    #D9738E
primary500:    #C7617D  ← Brand main CTA (KHÔNG còn là #2563EB)
primary600:    #954A48  ← Hover/pressed, strict-AA text

--- SECONDARY scale (Tím Pastel — HoH only) ---
secondary100:  #F3E8F5
secondary500:  #B887BD  ← HoH action (KHÔNG còn là #7C3AED)

--- ACCENT (Gamification) ---
accent100:     #FEF3C7
accent500:     #F59E0B  ← XP ⭐, streak 🔥, sinh nhật 🎂

--- SEMANTIC (LOCKED 🔒) ---
income:        #F97316
safe/success:  #16A34A  ← (KHÔNG còn là #22C55E)
sos/danger:    #DC2626  ← (KHÔNG còn là #EF4444) 🔒 KHÔNG ĐỔI

--- BACKWARD-COMPAT ALIASES ---
planned → primary500   #C7617D  (was #2563EB)
shared  → secondary500 #B887BD  (was #7C3AED)
link    → primary500   #C7617D
notification → sos     #DC2626

--- OTHER ---
heroOrange:    #FF8C42
heroPurple:    #A78BFA
avatarBlue:    #3B82F6
avatarPurple:  #A78BFA
avatarOrange:  #FB923C
avatarTeal:    #2DD4BF

--- Calendar Event Colors ---
calTask:       #C7617D  ← primary500 (was #2563EB)
calEvent:      #B887BD  ← secondary500 (was #7C3AED)
calTravel:     #0EA5E9  ← MỚI — token riêng trong AppColors
calBirthday:   #F59E0B  ← accent500
calHealth:     #DC2626  ← sos (was #EF4444)
```
