package com.familycare.family_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class CallGuardService : Service() {
    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Cuộc gọi video",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Thông báo giữ cuộc gọi video khi app xuống nền"
                setShowBadge(false)
            },
        )
    }

    private fun buildNotification(): Notification {
        val openIntent =
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            31,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_notification_call)
            .setContentTitle("Đang trong cuộc gọi video")
            .setContentText("Family Care đang giữ kết nối camera và micro.")
            // ⚠️ KHÔNG dùng CATEGORY_CALL: kết hợp với foreground service type
            // camera|microphone, Android (và nhiều bản ROM OEM) tự vẽ đè một
            // thanh "cuộc gọi đang diễn ra" ở đầu màn hình — trùng và xung đột
            // với `_bottomBar()` tự vẽ trong active_call_screen.dart (nút đó
            // không nối vào CallProvider/LivekitRoomService, bấm không có tác
            // dụng gì, có máy còn vẽ vỡ hình do thiếu dữ liệu CallStyle đầy
            // đủ). Đây đúng là nguyên nhân thanh lạ + icon vỡ hình đã thấy khi
            // test trên máy ảo 12/08.
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "familycare_call_guard"
        private const val NOTIFICATION_ID = 9201

        @Volatile
        var running: Boolean = false
            private set
    }
}
