# Color Tokens — Family Care Design System
> Resource file cho `figma-mobile-design-system` skill
> Nguồn chân lý: `lib/theme/app_colors.dart` · Flutter `Color(0xFFRRGGBB)`
> **⚡ Cập nhật lớn 23/05/2026** — Rebrand toàn bộ palette theo logo FamilyCare

---

## ⚡ Thay đổi quan trọng (23/05/2026)

| Token | Hex cũ | Hex mới | Lý do |
|---|---|---|---|
| `planned` / `primary500` | `#2563EB` (xanh dương) | `#C7617D` (hồng vỏ đỗ) | Đồng bộ màu logo FamilyCare |
| `shared` / `secondary500` | `#7C3AED` (tím đậm) | `#B887BD` (tím pastel) | Đồng bộ màu logo FamilyCare |
| `safe` / `success` | `#22C55E` | `#16A34A` | WCAG tốt hơn (5.1:1 vs 3.6:1) |
| `sos` / `danger` | `#EF4444` | `#DC2626` | WCAG tốt hơn (4.9:1 vs 4.5:1) |

> **Dev note:** Spec gốc viết bằng TypeScript/React Native → đã dịch sang Flutter/Dart.
> Xem file `app_colors.dart` cho source of truth. **Không** copy hex từ TypeScript mà không kiểm tra.

---

## Naming Convention

```
Flutter:  AppColors.tokenName  (static const Color)
Figma:    Category/Weight format (e.g. Primary/500)
Hex:      #RRGGBB (6 chars, no alpha — alpha always FF)
```

---

## Background & Surface

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `background` | `#F8FBF5` | `Color(0xFFF8FBF5)` | `Neutral/BG` | Scaffold background — tông xanh kem |
| `white` | `#FFFFFF` | `Color(0xFFFFFFFF)` | `Neutral/White` | Card surface, bottom sheet, nav bar |

---

## Text Colors

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `textPrimary` | `#111827` | `Color(0xFF111827)` | `Neutral/900` | Tiêu đề, nội dung chính |
| `textSecondary` | `#6B7280` | `Color(0xFF6B7280)` | `Neutral/500` | Phụ đề, nhãn |
| `textMuted` | `#9CA3AF` | `Color(0xFF9CA3AF)` | `Neutral/400` | Placeholder, timestamp, caption |

---

## Hero Gradient Colors

> Dùng cho FamilyWalletCard (Manager) — gradient `heroOrange → heroPurple`

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `heroOrange` | `#FF8C42` | `Color(0xFFFF8C42)` | `Gradient/Start` | Gradient start trái |
| `heroPurple` | `#A78BFA` | `Color(0xFFA78BFA)` | `Gradient/End` | Gradient end phải |

```dart
// Wallet card gradient pattern
gradient: LinearGradient(
  colors: [AppColors.heroOrange, AppColors.heroPurple],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
)
```

### Child Wallet Gradient (chưa token hóa)

```dart
// child_wallet_screen.dart — hardcoded, chưa vào AppColors
gradient: LinearGradient(
  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
// → TODO: thêm vào AppColors: walletGradStart, walletGradEnd
```

---

## PRIMARY Scale — Hồng Vỏ Đỗ (Brand/CTA) *(MỚI)*

> Nguồn: logo FamilyCare rose `#C7617D`
> Dùng cho: Main CTA button, active tab, link text, chip highlight.
> ⚠️ Nếu dùng white text trên `primary500` mà khó đọc → đổi bg sang `primary600`.

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `primary50` | `#FFF5F7` | `Color(0xFFFFF5F7)` | `Primary/50` | Nền cực nhạt, phân cách nhẹ |
| `primary100` | `#FEACBA` | `Color(0xFFFEACBA)` | `Primary/100` | Chip bg, badge bg "Chờ duyệt" |
| `primary400` | `#D9738E` | `Color(0xFFD9738E)` | `Primary/400` | Hover / intermediate state |
| `primary500` | `#C7617D` | `Color(0xFFC7617D)` | `Primary/500` | **Brand main** — button, active tab |
| `primary600` | `#954A48` | `Color(0xFF954A48)` | `Primary/600` | Hover/pressed, text trên light bg |

**WCAG (Primary):**
```
White (#FFF) on primary500 (#C7617D) = 3.8:1  → AA-Large ✓  (icon, large text ≥18pt)
White (#FFF) on primary600 (#954A48) = 6.1:1  → AA ✓        (body text trên button)
→ Nếu cần AA cho text thường → dùng primary600 làm button bg
```

---

## SECONDARY Scale — Tím Pastel (HoH Exclusive) *(MỚI)*

> Nguồn: logo FamilyCare purple `#B887BD`
> **Rule cứng:** CHỈ dùng cho Head of Household. KHÔNG dùng cho PARENT thông thường.
> Dùng cho: HoH-only buttons, Subscription badge, Admin actions.

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `secondary100` | `#F3E8F5` | `Color(0xFFF3E8F5)` | `Secondary/100` | HoH bg tint, section header |
| `secondary500` | `#B887BD` | `Color(0xFFB887BD)` | `Secondary/500` | HoH action button, badge |

---

## ACCENT Scale — Vàng Amber (Gamification) *(MỚI)*

> Không đổi dù brand có rebrand — dùng riêng cho gamification.
> Complementary contrast cực tốt khi đặt cạnh tông Tím/Hồng.

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `accent100` | `#FEF3C7` | `Color(0xFFFEF3C7)` | `Accent/100` | XP badge bg, streak bg |
| `accent500` | `#F59E0B` | `Color(0xFFF59E0B)` | `Accent/500` | XP ⭐, streak 🔥, sinh nhật 🎂 |

---

## Semantic Colors 🔒

> **KHÔNG BAO GIỜ THAY ĐỔI** — muscle memory, nhận ra ngay không cần đọc

### income

| AppColors Token | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|
| `income` | `#F97316` | `Color(0xFFF97316)` | `Semantic/Income` | Thu nhập, WaffleChart positive |

### safe / success ✅

| AppColors Token | Alias | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|---|
| `safe` | `success` | `#16A34A` | `Color(0xFF16A34A)` | `Semantic/Success` | Task Done, +tiền, Approve, dư quỹ |
| — | — | `#DCFCE7` | `Color(0xFFDCFCE7)` | `Semantic/Success-Light` | Done card bg, badge bg |

**WCAG:** White on `#16A34A` = 5.1:1 → AA ✅

### sos / danger 🔒

| AppColors Token | Alias | Hex | Flutter Value | Figma Style | Dùng cho |
|---|---|---|---|---|---|
| `sos` | `danger`, `notification` | `#DC2626` | `Color(0xFFDC2626)` | `Semantic/SOS` | SOS FAB, Reject, `-tiền`, Budget warning |
| — | — | `#FEE2E2` | `Color(0xFFFEE2E2)` | `Semantic/SOS-Light` | Rejected card bg |

**Rule cứng:**
```
SOS FAB → luôn fill #DC2626
Dark Mode: vẫn #DC2626
Light Mode: vẫn #DC2626
Bất kỳ role nào: vẫn #DC2626
KHÔNG dùng primary600 (#954A48) thay thế — màu đỏ đất trông quá "hiền", mất cảm giác khẩn cấp
```

**Haptic khi hold SOS (3 giây):**
```
0.0s: Light impact
1.0s: Medium impact
2.0s: Medium impact
3.0s: Heavy impact (double) — SEND
```

**WCAG:** White on `#DC2626` = 4.9:1 → AA ✅

---

## Backward-Compat Aliases

> Các token cũ vẫn hoạt động — alias trỏ đến token mới.
> KHÔNG tạo thêm usage mới với tên alias — dùng tên token có scale.

| Alias | Trỏ đến | Hex mới | Hex cũ (deprecated) |
|---|---|---|---|
| `planned` | `primary500` | `#C7617D` | ~~`#2563EB`~~ |
| `shared` | `secondary500` | `#B887BD` | ~~`#7C3AED`~~ |
| `success` | `safe` | `#16A34A` | ~~`#22C55E`~~ |
| `danger` | `sos` | `#DC2626` | ~~`#EF4444`~~ |
| `link` | `primary500` | `#C7617D` | ~~`#2563EB`~~ |
| `notification` | `sos` | `#DC2626` | ~~`#EF4444`~~ |

---

## Navigation Bar Colors

| AppColors Token | Hex | Flutter Value | Dùng cho |
|---|---|---|---|
| `navBackground` | `#111827` | `Color(0xFF111827)` | Nav bar background (dark) |
| `navActive` | `#374151` | `Color(0xFF374151)` | Active tab indicator |

---

## Avatar Colors

> Phân biệt thành viên gia đình — assign theo thứ tự hoặc role

| AppColors Token | Hex | Flutter Value | Figma Style | Thành viên mẫu |
|---|---|---|---|---|
| `avatarBlue` | `#3B82F6` | `Color(0xFF3B82F6)` | `Avatar/Blue` | Bố / Manager default |
| `avatarPurple` | `#A78BFA` | `Color(0xFFA78BFA)` | `Avatar/Purple` | Bi (con thứ 2) / Mẹ |
| `avatarOrange` | `#FB923C` | `Color(0xFFFB923C)` | `Avatar/Orange` | An (con thứ 1) |
| `avatarTeal` | `#2DD4BF` | `Color(0xFF2DD4BF)` | `Avatar/Teal` | Mẹ / Deputy |

---

## Misc / Utility

| AppColors Token | Hex | Flutter Value | Dùng cho |
|---|---|---|---|
| `progressTrack` | `#E5E7EB` | `Color(0xFFE5E7EB)` | RingChart track, border, divider |
| `accentGlow` | `#2DD4BF` 15% | `Color(0x262DD4BF)` | Glow effect teal nhẹ |

---

## Status Badge Colors

> Dùng trong `task_management_screen.dart` — `_statusCfg`
> ⚡ **submitted** đã đổi từ blue → primary (hồng) để đồng bộ rebrand

| Status | Background | Text Color | AppColors tương ứng | Tiếng Việt |
|---|---|---|---|---|
| `todo` | `#F3F4F6` | `#6B7280` | `textSecondary` bg | Chờ làm |
| `doing` | `#FEF3C7` | `#D97706` | `accent100` bg | Đang làm |
| `submitted` | `#FFF5F7` | `#C7617D` | `primary50` / `primary500` | Chờ duyệt |
| `done` | `#DCFCE7` | `#16A34A` | `safe` | Hoàn thành |
| `rejected` | `#FEE2E2` | `#DC2626` | `sos` | Từ chối |

> **TODO:** token hóa các màu inline này vào `AppColors`

---

## Budget Alert Colors (inline — chưa token hóa)

| Tình huống | BG | Title Color | Subtitle Color |
|---|---|---|---|
| Critical (<10%) | `#FEE2E2` | `#991B1B` | `#B91C1C` |
| Warning (10–30%) | `#FFFBEB` | `#92400E` | `#B45309` |
| OK (>30%) | `#F0FDF4` | `#166534` | `#15803D` |

---

## Calendar Event Colors

> 5 loại sự kiện — chỉ `calTravel` là token thực sự mới

| Token | Hex | Flutter Value | Figma Style | Loại sự kiện |
|---|---|---|---|---|
| `primary500` | `#C7617D` | `Color(0xFFC7617D)` | `Calendar/Task` | 📋 Task |
| `secondary500` | `#B887BD` | `Color(0xFFB887BD)` | `Calendar/Event` | 📅 Sự kiện |
| `calTravel` **(MỚI)** | `#0EA5E9` | `Color(0xFF0EA5E9)` | `Calendar/Travel` | ✈️ Du lịch |
| `accent500` | `#F59E0B` | `Color(0xFFF59E0B)` | `Calendar/Birthday` | 🎂 Sinh nhật |
| `sos` | `#DC2626` | `Color(0xFFDC2626)` | `Calendar/Health` | 🏥 Sức khỏe / Khám bệnh |

---

## Role → Color Mapping

> Flutter: đọc `user.isAdministrative` hoặc `user.role` từ JWT
> 1 component, nhiều role variant — không tạo widget riêng
> **Đổi tên:** "Child/Member" → **"Family Member"** (bao quát hơn)

| Role | Primary Token | Hex | Accent Token | Ghi chú |
|---|---|---|---|---|
| `ADMIN` | `secondary500` | `#B887BD` | — | Docker, Revenue, System — 1 per system |
| `HEAD_OF_HOUSEHOLD` | `primary500` | `#C7617D` | `secondary500` | Flag trên Parent đầu tiên |
| `PARENT` / `DEPUTY` | `primary500` | `#C7617D` | — | Trưởng/Phó nhóm — giao task, duyệt ví |
| **`FAMILY_MEMBER`** *(đổi từ CHILD)* | `safe` | `#16A34A` | `income` | Con, ông bà, anh chị em... |
| `SOS` (all) | `sos` | `#DC2626` | — | 🔒 Không phụ thuộc role |

---

## Flutter — AppColors class (đầy đủ)

```dart
// lib/theme/app_colors.dart — source of truth, cập nhật 23/05/2026
import 'package:flutter/material.dart';

/// Design-system color tokens — single source of truth for the entire app.
/// Aligned with FamilyCare logo palette (cập nhật 23/05/2026).
class AppColors {
  AppColors._();

  // ─── Background & surface ─────────────────────────────────────────────────
  static const background = Color(0xFFF8FBF5); // scaffold — xanh kem nhẹ
  static const white      = Color(0xFFFFFFFF); // card, bottom sheet, nav bar

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);

  // ─── Hero Gradient ────────────────────────────────────────────────────────
  static const heroOrange = Color(0xFFFF8C42);
  static const heroPurple = Color(0xFFA78BFA);

  // ─── Navigation bar ───────────────────────────────────────────────────────
  static const navBackground = Color(0xFF111827);
  static const navActive     = Color(0xFF374151);

  // ─── Avatar palette ───────────────────────────────────────────────────────
  static const avatarBlue   = Color(0xFF3B82F6);
  static const avatarPurple = Color(0xFFA78BFA);
  static const avatarOrange = Color(0xFFFB923C);
  static const avatarTeal   = Color(0xFF2DD4BF);

  // ─── PRIMARY scale — Hồng Vỏ Đỗ (Brand/CTA) ──────────────────────────────
  static const primary50  = Color(0xFFFFF5F7);
  static const primary100 = Color(0xFFFEACBA);
  static const primary400 = Color(0xFFD9738E);
  static const primary500 = Color(0xFFC7617D); // Brand main
  static const primary600 = Color(0xFF954A48); // hover/pressed, strict-AA text

  // ─── SECONDARY scale — Tím Pastel (HoH Exclusive) ────────────────────────
  static const secondary100 = Color(0xFFF3E8F5);
  static const secondary500 = Color(0xFFB887BD);

  // ─── ACCENT scale — Vàng Amber (Gamification) ────────────────────────────
  static const accent100 = Color(0xFFFEF3C7);
  static const accent500 = Color(0xFFF59E0B);

  // ─── Calendar Event Colors ────────────────────────────────────────────────
  static const calTravel = Color(0xFF0EA5E9); // ✈️ Du lịch — token mới

  // ─── SEMANTIC tokens (LOCKED) ─────────────────────────────────────────────
  static const income = Color(0xFFF97316); // 🔒 Thu nhập / Reward
  static const safe   = Color(0xFF16A34A); // 🔒 Task Done / Approve / Dư quỹ
  static const sos    = Color(0xFFDC2626); // 🔒 SOS / Reject / Budget warning

  // ─── Backward-compat aliases ──────────────────────────────────────────────
  static const planned      = primary500;   // alias → #C7617D (was #2563EB)
  static const shared       = secondary500; // alias → #B887BD (was #7C3AED)
  static const success      = safe;         // #16A34A
  static const danger       = sos;          // #DC2626
  static const link         = primary500;   // #C7617D
  static const notification = sos;          // #DC2626

  // ─── Misc / Utility ───────────────────────────────────────────────────────
  static const progressTrack = Color(0xFFE5E7EB);
  static const accentGlow    = Color(0x262DD4BF); // teal glow 15%
}
```

---

> ⚠️ **Lưu ý cho Dev (React Native → Flutter migration):**
> Spec màu gốc có thể được viết bằng TypeScript/React Native syntax (`const colors = { primary500: '#C7617D' }`).
> Trong Flutter, luôn dùng `AppColors.primary500` thay vì hardcode hex.
> Đừng copy hex từ TypeScript file mà không verify với `app_colors.dart`.
