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
            // Lắc/té ngã vẫn qua /sos-quick (đếm ngược 3 giây + nút hủy) —
            // khác với EmergencySosWatcherService dùng /sos-immediate (gửi
            // thẳng, không đếm ngược) vì lý do khác nhau: ở đây vẫn hiện được
            // UI của app bình thường, không có màn hệ thống nào chiếm chỗ.
            SosAlertLauncher.launch(this, "sos-quick")
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
        // Channel "Kích hoạt SOS" (ALERT_CHANNEL_ID) giờ do SosAlertLauncher
        // tự tạo khi cần — dùng chung với EmergencySosWatcherService.
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
        private const val NOTIFICATION_ID = 9101

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
