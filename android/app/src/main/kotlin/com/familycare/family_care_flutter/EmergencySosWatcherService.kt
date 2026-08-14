package com.familycare.family_care

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent

/// Bám theo màn Emergency SOS của hệ thống (bấm nguồn 5 lần trên ColorOS) để
/// tự động gửi cảnh báo SOS của Family Care ngay khi màn đó xuất hiện — xem
/// [EmergencySosMatcher] cho chi tiết vì sao chỉ đúng trên Oppo/Realme/
/// OnePlus, và `KE_HOACH_SOS_KICH_HOAT_KHAN_CAP_2026-08-11.md` mục 13 cho bối
/// cảnh đầy đủ.
///
/// Đây KHÔNG phải foreground service — AccessibilityService có vòng đời
/// riêng do hệ thống quản lý, chỉ chạy khi người dùng tự bật thủ công trong
/// Cài đặt hệ thống (Settings > Trợ năng), không cần notification thường
/// trực riêng.
///
/// Không đếm ngược, không hiện UI xác nhận: màn Emergency SOS của hệ thống
/// đang chiếm toàn màn hình đúng lúc phát hiện, nên gửi thẳng — xem
/// `SOSScreen(immediate: true)`.
class EmergencySosWatcherService : AccessibilityService() {
    private val matcher = EmergencySosMatcher()

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        if (e.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val triggered = matcher.shouldTrigger(
            packageName = e.packageName?.toString(),
            className = e.className?.toString(),
            nowMs = SystemClock.elapsedRealtime(),
        )
        if (triggered) {
            SosAlertLauncher.launch(this, "sos-immediate")
        }
    }

    override fun onInterrupt() {}
}
