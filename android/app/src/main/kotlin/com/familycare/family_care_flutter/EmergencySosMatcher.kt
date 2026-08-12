package com.familycare.family_care

/// Quyết định xem một sự kiện đổi màn hình (window state change) có phải là
/// màn Emergency SOS của hệ thống hay không, và có nên bắn cảnh báo hay
/// không (chống bắn lặp) — tách thành class thuần để JVM test được, cùng
/// khuôn với [ShakeDetector]/[FallDetector].
///
/// [targetPackage] mặc định `com.oplus.sos` — package Emergency SOS của
/// ColorOS (Oppo/Realme/OnePlus), xác nhận qua `adb shell dumpsys window`
/// thật trên máy Oppo CPH2159 (11/08). Đây là chi tiết CHỈ ĐÚNG cho ColorOS —
/// Samsung/Xiaomi/Pixel dùng package khác hẳn hoặc không có màn tương đương,
/// nên cơ chế này im lặng không kích hoạt trên các máy đó (không crash, không
/// báo lỗi — chỉ đơn giản là không khớp package nào cả).
class EmergencySosMatcher(
    private val targetPackage: String = "com.oplus.sos",
    private val cooldownMs: Long = 30_000L,
) {
    private var lastTriggerMs: Long? = null

    /// Trả `true` đúng MỘT lần cho mỗi lần màn Emergency SOS thật sự mở —
    /// event `TYPE_WINDOW_STATE_CHANGED` từ package này bắn liên tục ~4
    /// lần/giây trong lúc màn đó còn hiện, nên bắt buộc phải có cooldown,
    /// khác với chỉ lọc theo package/class.
    fun shouldTrigger(packageName: String?, className: String?, nowMs: Long): Boolean {
        if (packageName != targetPackage) return false
        val cls = className ?: return false
        if (!cls.contains("Emergency", ignoreCase = true)) return false

        val last = lastTriggerMs
        if (last != null && nowMs - last < cooldownMs) return false

        lastTriggerMs = nowMs
        return true
    }
}
