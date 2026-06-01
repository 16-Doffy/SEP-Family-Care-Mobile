# Typography & Spacing — Family Care Design System
> Resource file cho `figma-mobile-design-system` skill
> Flutter: `google_fonts` (Inter) · Material 3 · Không có spacing constants riêng

---

## Typography Scale

> Font duy nhất: **Inter** — `GoogleFonts.inter(...)`
> Package: `google_fonts: ^6.x` trong `pubspec.yaml`
> Không dùng `TextStyle` trực tiếp — luôn dùng `GoogleFonts.inter()`

### Toàn bộ scale (thực tế trong codebase)

| Usage | Size | FontWeight | Dùng cho |
|---|---|---|---|
| Balance / Display | 32px | `w700` / `w800` | Số dư ví hero — Display number |
| Screen Title | 22px | `w700` | Tiêu đề màn hình chính |
| Section Title | 20px | `w700` | Section header |
| Sheet Title | 20px | `w700` | Bottom sheet header |
| Amount Large | 20px | `w700` | Số tiền lớn trong overview |
| Task Title / Card | 18px | `w700` | Bottom sheet sub-title |
| Body Primary | 15px | `w700` | Card title, TaskCard title |
| Body Secondary | 14px | `w700` / `w600` | Member name, transaction title |
| Chip / Filter Label | 13px | `w600` | Filter chip, tab label |
| Form Label | 12px | `w600` | Section label, legend |
| Badge / Status | 11px | `w600` | Status badge, chip text |
| Caption | 12px | `w600` | Category label nhỏ |
| Tab Label | 10px | `w700` (active) / `w400` (inactive) | BottomNavBar tab |
| Micro | 9–10px | `w400` | Sub-caption nhỏ nhất |

### Nguyên tắc sử dụng

```
Balance (32px w700/w800) → Số dư ví ONLY
  Context: FamilyWalletCard hero, ChildWalletCard hero
  Dùng Colors.white khi trên gradient background

Screen Title (22px w700) → Mỗi màn hình có 1 tiêu đề duy nhất
  Context: HomeDashboard header, Wallet screen header

Tab Label (10px) → BottomNavBar
  Active:   fontWeight: FontWeight.w700, color: AppColors.link
  Inactive: fontWeight: FontWeight.w400, color: AppColors.textMuted

KHÔNG mix nhiều weight cho cùng 1 mục đích
KHÔNG dùng fontSize lẻ (e.g. 16px, 19px) ngoài danh sách trên
```

### Flutter quick reference

```dart
// Balance/Display
GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)

// Screen title
GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)

// Section header
GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)

// Card title / Task title
GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)

// Member name / Transaction title
GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)

// Chip / filter label
GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)

// Form label / section header nhỏ
GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)

// Status badge / chip text
GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)

// Tab label active
GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.link)

// Tab label inactive
GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textMuted)

// Subtitle / muted text
GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)
```

### AppTheme setup

```dart
// lib/theme/app_theme.dart
class AppTheme {
  static ThemeData get light {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.planned,   // #2563EB
        surface: AppColors.background, // #F8FBF5
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.copyWith(
        bodyLarge:  base.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: AppColors.textPrimary),
        bodySmall:  base.bodySmall?.copyWith(color: AppColors.textSecondary),
        titleLarge: base.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

---

## Spacing

> Codebase dùng trực tiếp `const EdgeInsets`, `SizedBox`, `Padding`
> **Không có spacing constants file** — các giá trị dưới đây là convention thực tế

### Screen-level padding

```dart
// Padding ngang màn hình — STANDARD
padding: const EdgeInsets.symmetric(horizontal: 20)

// Padding dọc header
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)

// ListView padding chuẩn
padding: const EdgeInsets.symmetric(horizontal: 20)
```

### Component internal spacing

```dart
// Card padding chuẩn (WalletCard, SectionCard)
padding: const EdgeInsets.all(20)
// hoặc
padding: const EdgeInsets.all(22)

// Card compact (TaskCard, RequestCard)
padding: const EdgeInsets.all(14)

// Bottom sheet
padding: const EdgeInsets.fromLTRB(28, 28, 28, 40)  // content sheet
padding: const EdgeInsets.all(24)                     // modal sheet
```

### Gap values thường gặp

| SizedBox | Dùng cho |
|---|---|
| `SizedBox(height: 4)` | Gap siêu nhỏ, label-value |
| `SizedBox(height: 6)` | Gap nhỏ trong row |
| `SizedBox(height: 8)` | Gap nội bộ component |
| `SizedBox(height: 10)` | Gap vừa trong legend/list |
| `SizedBox(height: 12)` | Gap giữa elements |
| `SizedBox(height: 16)` | Gap section nhỏ |
| `SizedBox(height: 18)` | Gap trong wallet card |
| `SizedBox(height: 20)` | Gap section chuẩn |
| `SizedBox(height: 24)` | Gap section lớn |
| `SizedBox(width: 4)` | Badge-text gap |
| `SizedBox(width: 8)` | Button gap, icon-label |
| `SizedBox(width: 10)` | Status bar-content gap |
| `SizedBox(width: 12)` | Avatar-text gap |
| `SizedBox(width: 16)` | Between inline elements |
| `SizedBox(width: 20)` | Ring chart - text gap |

### Bottom clearance

```dart
// ListView bottom padding — prevent content behind nav bar
SizedBox(height: 110)  // khi có FAB / sheet
SizedBox(height: 40)   // standard bottom clearance
```

---

## Frame Sizes

```
Mobile (iPhone 14 — reference):  393 × 852 px
Admin Web (Desktop):            1440 × 900 px
```

---

## Component Dimensions

### BottomNavBar

```dart
// ManagerShell & MemberShell
SizedBox(height: 60)    // ← actual height (không phải 82px)
Icon size: 24px
Label: 10px
Background: AppColors.white
Shadow: BoxShadow(color: black.withOpacity(0.08), blurRadius: 20, offset: Offset(0, -4))
```

### SOS NavItem (special)

```dart
Container(
  width: 36, height: 36,
  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.sos),
)
// Text: '🚨' fontSize: 18
// Label: 'SOS' 10px w700 color: AppColors.sos
```

### Button — Primary CTA (ElevatedButton)

```dart
ElevatedButton.styleFrom(
  backgroundColor: AppColors.link,  // #2563EB
  minimumSize: const Size.fromHeight(54),  // height 52–54px
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
)
// Label: 15–16px w700 white
```

### Button — Approve / Reject (pair)

```dart
// Approve
ElevatedButton.styleFrom(
  backgroundColor: AppColors.success,   // #22C55E
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
)

// Reject
ElevatedButton.styleFrom(
  backgroundColor: AppColors.danger,    // #EF4444
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
)
```

### Input Field (TextField)

```dart
// Dùng trong bottom sheet forms
height: không fix — content sizing
decoration: BoxDecoration(
  border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
  borderRadius: BorderRadius.circular(14),
)
contentPadding: EdgeInsets.symmetric(horizontal: 14)
font: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary)

// Variant: filled (ChildWalletScreen request sheet)
filled: true, fillColor: AppColors.background
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)
```

### Card (SectionCard / TaskCard)

```dart
Container(
  padding: const EdgeInsets.all(20),   // standard card
  // hoặc EdgeInsets.all(14)           // compact card
  decoration: BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 20,
      offset: Offset(0, 4),
    )],
  ),
)
```

### Status Badge / Chip

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: statusBg,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
)
```

### Avatar (AvatarWidget)

```dart
// Sizes used: 36, 40, 44
AvatarWidget(initial: 'AN', color: AppColors.avatarOrange, size: 44)
// Shape: BoxShape.circle (pill)
// Font size: ~size * 0.35 (auto-scaled)
```

### Filter Chip

```dart
Container(
  height: 40,
  padding: EdgeInsets.fromLTRB(14, 0, badge > 0 ? 4 : 14, 0),
  decoration: BoxDecoration(
    color: active ? AppColors.link : AppColors.white,
    borderRadius: BorderRadius.circular(999),   // pill
    boxShadow: [...],
  ),
)
```

---

## Border Radius Scale

```
pill/full: BorderRadius.circular(999) hoặc BoxShape.circle — avatar, chip, FAB
20px:      BorderRadius.circular(20)  — card chính, filter chip rounded
16px:      BorderRadius.circular(16) — nhỏ card
14px:      BorderRadius.circular(14) — CTA button, input field
12px:      BorderRadius.circular(12) — input filled style, small card
8px:       BorderRadius.circular(8)  — status badge, chip text
6px:       BorderRadius.circular(6)  — stacked bar, small indicator
```

---

## Accessibility — Touch Target

> iOS HIG: tối thiểu **44 × 44px**
> Android Material: tối thiểu **48 × 48px**

```dart
// Nếu icon nhỏ hơn 44px, bọc trong GestureDetector với HitTestBehavior.opaque
GestureDetector(
  behavior: HitTestBehavior.opaque,  // expand hit area
  onTap: onTap,
  child: Column(  // tab item đủ width
    ...
  ),
)

// SOS FAB: 36×36px visual → trong Row với Expanded → đủ touch target
// Back button: 40×40px Container — đúng tiêu chuẩn
```
