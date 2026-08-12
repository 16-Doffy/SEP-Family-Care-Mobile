package com.familycare.family_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/// Mở màn SOS đè lên màn khóa qua notification full-screen-intent — dùng
/// chung bởi hai nguồn kích hoạt độc lập:
/// - `SosGuardService` (lắc mạnh / té ngã, qua cảm biến)
/// - `EmergencySosWatcherService` (bám theo màn Emergency SOS của hệ thống)
///
/// Tách ra đây để cả hai không lặp lại cùng một logic full-screen-intent +
/// kiểm tra quyền — sai một chỗ là cả hai nguồn cùng hỏng.
object SosAlertLauncher {
    private const val ALERT_CHANNEL_ID = "familycare_sos_guard_alert"
    private const val DEFAULT_NOTIFICATION_ID = 9102

    /// Từ Android 14 (API 34), hệ thống chỉ tự cấp quyền mở Activity
    /// full-screen từ notification cho app nhóm gọi điện/báo thức. App khác
    /// phải được người dùng cấp thủ công — kiểm tra đúng bằng
    /// `canUseFullScreenIntent()`, KHÔNG được giả định luôn có.
    fun hasFullScreenIntentPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.canUseFullScreenIntent()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(ALERT_CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Kích hoạt SOS",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Mở màn SOS khi phát hiện lắc mạnh, té ngã, hoặc Emergency SOS hệ thống"
                setShowBadge(true)
                // Rung tường minh do phía gọi tự xử lý với mẫu riêng (xem
                // SosGuardService.vibrateStrong) — tắt rung mặc định của
                // channel để không rung chồng 2 lần.
                enableVibration(false)
            },
        )
    }

    /// [deepLinkPath] là phần sau `familycare://app/`, ví dụ `sos-quick` hoặc
    /// `sos-immediate`. KHÔNG tự gọi `pendingIntent.send()` — xem ghi chú
    /// trong nhánh `hasPermission` bên dưới, đây là lỗi thật đã xảy ra.
    fun launch(context: Context, deepLinkPath: String, notificationId: Int = DEFAULT_NOTIFICATION_ID) {
        ensureChannel(context)
        val uri = Uri.parse("familycare://app/$deepLinkPath")
        val sosIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            sosIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val hasPermission = hasFullScreenIntentPermission(context)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALERT_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
        if (hasPermission) {
            // Có quyền: để HỆ THỐNG tự mở màn SOS đè lên màn khóa — đây là
            // đường được Android cho phép khởi chạy Activity từ nền. TUYỆT
            // ĐỐI không tự gọi pendingIntent.send() ở đây: đó là app tự khởi
            // chạy Activity từ nền không qua notification, bị chặn bởi giới
            // hạn background-activity-launch từ Android 10 và sẽ âm thầm
            // không chạy — đúng lỗi đã xảy ra ở bản trước khi sửa.
            builder
                .setContentTitle("Đang kích hoạt SOS")
                .setContentText("Màn hình SOS sẽ mở để đếm ngược và cho phép hủy.")
                .setFullScreenIntent(pendingIntent, true)
        } else {
            // Không có quyền: KHÔNG có cách nào tự mở màn hình được nữa — chỉ
            // còn thông báo phải chạm tay.
            builder
                .setContentTitle("Phát hiện tình huống khẩn cấp")
                .setContentText("Chạm để mở màn SOS — cần cấp quyền màn hình khẩn cấp để tự mở.")
                .addAction(android.R.drawable.ic_dialog_alert, "Mở SOS", pendingIntent)
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, builder.build())
    }
}
