package com.familycare.family_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.sqrt

class SosGuardService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private val shakeDetector = ShakeDetector()
    private val fallDetector = FallDetector()

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        shakeEnabled = intent?.getBooleanExtra(EXTRA_SHAKE_ENABLED, shakeEnabled) ?: shakeEnabled
        fallEnabled = intent?.getBooleanExtra(EXTRA_FALL_ENABLED, fallEnabled) ?: fallEnabled

        if (!shakeEnabled && !fallEnabled) {
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildPersistentNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        registerSensor()
        running = true
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        fallDetector.reset()
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val magnitude = sqrt(x * x + y * y + z * z)
        val nowMs = SystemClock.elapsedRealtime()

        val shake = shakeEnabled && shakeDetector.addSample(magnitude, nowMs)
        val fall = fallEnabled && fallDetector.addSample(magnitude, nowMs)
        if (shake || fall) {
            vibrateStrong()
            showSosFullScreenNotification()
        }
    }

    private fun registerSensor() {
        val sensor = accelerometer ?: return
        sensorManager.unregisterListener(this)
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                GUARD_CHANNEL_ID,
                "Bảo vệ SOS",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Thông báo thường trực khi bảo vệ SOS đang bật"
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Kích hoạt SOS",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Mở màn SOS khi phát hiện lắc mạnh hoặc té ngã"
                setShowBadge(true)
                // Tự rung tường minh ở vibrateStrong() với mẫu rung riêng —
                // tắt rung mặc định của channel để tránh rung chồng 2 lần.
                enableVibration(false)
            },
        )
    }

    /// Rung mạnh, lặp lại — người lỡ lắc/để rơi máy phải cảm nhận được để kịp
    /// bấm hủy ở màn đếm ngược. Đây là cơ chế chống báo động giả quan trọng
    /// nhất khi máy đang ở trong túi, không nhìn thấy màn hình.
    private fun vibrateStrong() {
        val pattern = longArrayOf(0, 400, 200, 400, 200, 400)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    private fun buildPersistentNotification(): Notification {
        val stopIntent = Intent(this, SosGuardService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(
            this,
            11,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openIntent =
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this,
            12,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return notificationBuilder(GUARD_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Bảo vệ SOS đang bật")
            .setContentText(guardDescription())
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tắt", stopPendingIntent)
            .build()
    }

    private fun guardDescription(): String = when {
        shakeEnabled && fallEnabled -> "Lắc mạnh hoặc té ngã để mở màn SOS"
        shakeEnabled -> "Lắc mạnh để gửi cảnh báo"
        fallEnabled -> "Đang theo dõi té ngã"
        else -> "Bảo vệ SOS đang tạm tắt"
    }

    /// Từ Android 14 (API 34), hệ thống chỉ tự cấp quyền mở Activity full-screen
    /// từ notification cho app nhóm gọi điện/báo thức. App khác phải được người
    /// dùng cấp thủ công qua `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` — kiểm
    /// tra đúng bằng `canUseFullScreenIntent()`, KHÔNG được giả định luôn có.
    private fun hasFullScreenIntentPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(NotificationManager::class.java)
        return manager.canUseFullScreenIntent()
    }

    private fun showSosFullScreenNotification() {
        val uri = Uri.parse("familycare://app/sos-quick")
        val sosIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            21,
            sosIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val hasPermission = hasFullScreenIntentPermission()
        val builder = notificationBuilder(ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
        if (hasPermission) {
            // Có quyền: để HỆ THỐNG tự mở màn SOS đè lên màn khóa — đây là
            // đường được Android cho phép khởi chạy Activity từ nền. TUYỆT ĐỐI
            // không tự gọi pendingIntent.send() ở đây: đó là app tự khởi chạy
            // Activity từ nền không qua notification, bị chặn bởi giới hạn
            // background-activity-launch từ Android 10 và sẽ âm thầm không
            // chạy — đúng lỗi đã xảy ra ở bản trước.
            builder
                .setContentTitle("Đang kích hoạt SOS")
                .setContentText("Màn hình SOS sẽ mở để đếm ngược và cho phép hủy.")
                .setFullScreenIntent(pendingIntent, true)
        } else {
            // Không có quyền: KHÔNG có cách nào tự mở màn hình được nữa — chỉ
            // còn thông báo phải chạm tay, đúng fallback đã chốt trong kế
            // hoạch (mục 4.3). setFullScreenIntent() cũng vô nghĩa lúc này.
            builder
                .setContentTitle("Phát hiện lắc mạnh / té ngã")
                .setContentText("Chạm để mở màn SOS — cần cấp quyền màn hình khẩn cấp để tự mở.")
                .addAction(android.R.drawable.ic_dialog_alert, "Mở SOS", pendingIntent)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(ALERT_NOTIFICATION_ID, builder.build())
    }

    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    companion object {
        const val ACTION_STOP = "com.familycare.family_care.SOS_GUARD_STOP"
        const val EXTRA_SHAKE_ENABLED = "shakeEnabled"
        const val EXTRA_FALL_ENABLED = "fallEnabled"
        private const val GUARD_CHANNEL_ID = "familycare_sos_guard"
        private const val ALERT_CHANNEL_ID = "familycare_sos_guard_alert"
        private const val NOTIFICATION_ID = 9101
        private const val ALERT_NOTIFICATION_ID = 9102

        @Volatile
        var running: Boolean = false
            private set

        @Volatile
        var shakeEnabled: Boolean = false
            private set

        @Volatile
        var fallEnabled: Boolean = false
            private set
    }
}
