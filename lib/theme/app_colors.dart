import 'package:flutter/material.dart';

/// Design-system color tokens — single source of truth for the entire app.
///
/// Aligned with FamilyCare logo palette (cập nhật 23/05/2026).
/// Semantic tokens carry fixed meanings — NEVER repurpose them.
///
/// WCAG notes:
///   white on primary500 (#C7617D) = 3.8 : 1  → AA-Large (large text / icons)
///   white on primary600 (#954A48) = 6.1 : 1  → AA (normal text on buttons)
///   white on sos        (#DC2626) = 4.9 : 1  → AA
///   white on safe       (#16A34A) = 5.1 : 1  → AA
class AppColors {
  AppColors._();

  // ─── Background & surface ───────────────────────────────────────────────────
  static const background = Color(0xFFF8FBF5); // scaffold — xanh kem nhẹ
  static const white = Color(0xFFFFFFFF); // card, bottom sheet, nav bar

  // ─── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // ─── Hero Gradient (FamilyWalletCard Manager) ───────────────────────────────
  // Usage: LinearGradient(colors: [heroOrange, heroPurple], ...)
  static const heroOrange = Color(0xFFFF8C42);
  static const heroPurple = Color(0xFFA78BFA);

  // ─── Navigation bar ─────────────────────────────────────────────────────────
  static const navBackground = Color(0xFF111827);
  static const navActive = Color(0xFF374151);

  // ─── Avatar palette (phân biệt thành viên) ──────────────────────────────────
  static const avatarBlue = Color(0xFF3B82F6); // Bố / Manager default
  static const avatarPurple = Color(0xFFA78BFA); // Mẹ / Bi (con thứ 2)
  static const avatarOrange = Color(0xFFFB923C); // An (con thứ 1)
  static const avatarTeal = Color(0xFF2DD4BF); // Mẹ / Deputy

  // ─── PRIMARY scale — Hồng Vỏ Đỗ (Brand/CTA) ────────────────────────────────
  // Source: FamilyCare logo rose (#C7617D)
  // Dùng cho: Main CTA button, active tab, link, chip highlight.
  // Nếu dùng chữ trắng trên primary500 mà khó đọc → đổi bg sang primary600.
  static const primary50 = Color(0xFFFFF5F7); // nền cực nhạt, phân cách nhẹ
  static const primary100 = Color(0xFFFEACBA); // chip bg, badge bg "Chờ duyệt"
  static const primary400 = Color(0xFFD9738E); // hover / intermediate state
  static const primary500 = Color(
    0xFFC7617D,
  ); // Brand main — button, active tab
  static const primary600 = Color(
    0xFF954A48,
  ); // hover/pressed, text on light bg

  // ─── SECONDARY scale — Tím Pastel (HoH Exclusive) ──────────────────────────
  // Source: FamilyCare logo purple (#B887BD)
  // Dùng cho: HoH-only buttons, Subscription badge, Admin actions.
  // Rule: CHỈ dùng cho Head of Household — không dùng cho PARENT thông thường.
  static const secondary100 = Color(0xFFF3E8F5); // HoH bg tint, section header
  static const secondary500 = Color(0xFFB887BD); // HoH action button, badge

  // ─── ACCENT scale — Vàng Amber (Gamification) ──────────────────────────────
  // Giữ ổn định — không đổi dù brand có rebrand.
  // Complementary contrast cực tốt khi đặt cạnh tông Tím/Hồng.
  static const accent100 = Color(0xFFFEF3C7); // XP badge bg, streak bg
  static const accent500 = Color(0xFFF59E0B); // XP, streak, sinh nhật

  // ─── Calendar Event Colors ──────────────────────────────────────────────────
  // Chỉ calTravel là token thực sự mới — 4 loại còn lại tái dùng token có sẵn:
  //   Task:     primary500  (#C7617D)
  //   Event:    secondary500 (#B887BD)
  //   Birthday: accent500   (#F59E0B)
  //   Health:   sos         (#DC2626)
  static const calTravel = Color(0xFF0EA5E9); // Du lịch — token mới

  // ─── SEMANTIC tokens (LOCKED — fixed meanings, never repurpose) ─────────────

  /// Thu nhập / Reward / WaffleChart positive — KHÔNG ĐỔI
  static const income = Color(0xFFF97316);

  /// Task Done / +money / Approve / Dư quỹ — KHÔNG ĐỔI
  /// Light bg: Color(0xFFDCFCE7)
  static const safe = Color(0xFF16A34A);

  /// SOS FAB / Reject / -money / Budget warning — KHÔNG ĐỔI
  /// Quy tắc cứng: LUÔN LUÔN #DC2626 — dark mode, light mode, mọi role.
  /// KHÔNG dùng primary600 (#954A48) thay thế — quá "hiền", mất cảm giác khẩn cấp.
  /// WCAG: white on #DC2626 = 4.9:1 → AA
  /// Light bg: Color(0xFFFEE2E2)
  /// Haptic: 0 s Light → 1 s Medium → 2 s Medium → 3 s Heavy×2 (SEND)
  static const sos = Color(0xFFDC2626);

  // ─── Backward-compat aliases ────────────────────────────────────────────────
  /// Alias → primary500 (#C7617D). Trước đây = #2563EB (blue).
  static const planned = primary500;

  /// Alias → secondary500 (#B887BD). Trước đây = #7C3AED (deep purple).
  static const shared = secondary500;

  static const success = safe; // #16A34A
  static const danger = sos; // #DC2626
  static const link = primary500; // #C7617D
  static const notification = sos; // #DC2626

  // ─── Misc / Utility ─────────────────────────────────────────────────────────
  static const progressTrack = Color(0xFFE5E7EB); // ring track, border, divider
  static const accentGlow = Color(0x262DD4BF); // teal glow 15%
}
