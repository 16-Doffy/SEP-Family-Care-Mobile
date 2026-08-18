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
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import kotlin.math.sqrt

class SosGuardService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var usingWakeUpSensor = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val shakeDetector = ShakeDetector()
    private val fallDetector = FallDetector()

    // Nhật ký nhịp tim của cảm biến: đếm mẫu và biên độ lớn nhất trong mỗi
    // khoảng, in định kỳ. Đây là cách DUY NHẤT biết chắc cảm biến còn gửi dữ
    // liệu khi màn hình đã tắt — nhìn UI thì không thể biết.
    private var samplesSinceLog = 0
    private var maxMagnitudeSinceLog = 0f
    private var minMagnitudeSinceLog = Float.MAX_VALUE
    private var lastHeartbeatMs = 0L
    private var lastPhase = "idle"

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        // Bản WAKE-UP là mấu chốt của việc phát hiện té ngã khi màn hình tắt.
        //
        // getDefaultSensor(type) trả về bản NON-WAKE-UP: khi SoC vào chế độ
        // ngủ (màn tắt một lúc), loại này KHÔNG đánh thức CPU và sự kiện bị
        // rơi thẳng — onSensorChanged không được gọi lần nào, nên cú ngã đi
        // qua mà không ai biết. Foreground service KHÔNG cứu được: nó chỉ giữ
        // tiến trình khỏi bị giết, không ngăn CPU ngủ.
        //
        // Không phải máy nào cũng có bản wake-up nên phải rơi về bản thường,
        // và khi đó wake lock bên dưới mới là thứ giữ cho cảm biến chạy.
        accelerometer =
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER, true)
                ?.also { usingWakeUpSensor = true }
                ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        Log.i(
            TAG,
            "onCreate: accelerometer=${accelerometer?.name} wakeUp=$usingWakeUpSensor",
        )
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
        acquireWakeLock()
        registerSensor()
        running = true
        return START_STICKY
    }

    /// Giữ CPU thức trong lúc canh cảm biến.
    ///
    /// Cần cả khi đã dùng wake-up sensor: máy không có bản wake-up sẽ rơi về
    /// bản thường, lúc đó chỉ wake lock mới giữ được luồng dữ liệu khi màn
    /// tắt. Có tốn pin, nhưng đây là tính năng cứu mạng và đã có thông báo
    /// thường trực để người dùng biết mà tắt khi không cần.
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock =
            power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
                setReferenceCounted(false)
                acquire()
            }
        Log.i(TAG, "acquireWakeLock: held=${wakeLock?.isHeld}")
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        if (lock.isHeld) lock.release()
        wakeLock = null
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        releaseWakeLock()
        fallDetector.reset()
        running = false
        Log.i(TAG, "onDestroy: đã gỡ listener và nhả wake lock")
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

        logSensorHeartbeat(magnitude, nowMs)

        val shake = shakeEnabled && shakeDetector.addSample(magnitude, nowMs)
        val fall = fallEnabled && fallDetector.addSample(magnitude, nowMs)

        // Đổi pha là lúc đáng in nhất: thấy "free_fall" nghĩa là đã bắt được
        // pha rơi, còn đứng mãi ở "idle" nghĩa là cú ngã chưa đủ nhẹ để vượt
        // ngưỡng — hai kết luận rất khác nhau khi đi chỉnh ngưỡng.
        val phase = fallDetector.phaseName()
        if (phase != lastPhase) {
            Log.i(TAG, "fall phase: $lastPhase -> $phase (|a|=$magnitude)")
            lastPhase = phase
        }

        if (fall) {
            // Té ngã đi qua SosEmergencyFlowService — TOÀN BỘ đếm ngược/GPS/gửi
            // SOS chạy trong service native, không phụ thuộc Activity/Flutter
            // engine. Trước đây gọi chung SosAlertLauncher.launch(..., "sos-quick")
            // như shake, khiến cú ngã không tự gửi được nếu người dùng không mở
            // lại app — xem BAO_CAO_BE_FALL_DETECTION_BACKGROUND_2026-08-18.md.
            Log.i(TAG, "KÍCH HOẠT té ngã: |a|=$magnitude -> native emergency flow")
            vibrateStrong()
            SosEmergencyFlowService.start(this)
        } else if (shake) {
            // Lắc mạnh vẫn qua /sos-quick (đếm ngược 3 giây + nút hủy trong
            // Flutter) — khác biệt được chấp nhận vì lắc thường xảy ra lúc
            // đang cầm/dùng máy, không phải lúc bất tỉnh như té ngã.
            Log.i(TAG, "KÍCH HOẠT lắc mạnh: |a|=$magnitude")
            vibrateStrong()
            SosAlertLauncher.launch(this, "sos-quick")
        }
    }

    /// In một dòng mỗi 10 giây: số mẫu nhận được và biên độ nhỏ nhất/lớn nhất.
    ///
    /// Màn hình tắt mà nhật ký này NGỪNG in tức là cảm biến không gửi dữ liệu
    /// nữa — lỗi nằm ở tầng đánh thức CPU. Nhật ký vẫn in đều mà không kích
    /// hoạt tức là dữ liệu vẫn về, chỉ là cú ngã chưa vượt ngưỡng — lỗi nằm ở
    /// tầng thuật toán. Không có dòng này thì hai ca đó nhìn giống hệt nhau.
    private fun logSensorHeartbeat(magnitude: Float, nowMs: Long) {
        samplesSinceLog++
        if (magnitude > maxMagnitudeSinceLog) maxMagnitudeSinceLog = magnitude
        if (magnitude < minMagnitudeSinceLog) minMagnitudeSinceLog = magnitude
        if (lastHeartbeatMs == 0L) lastHeartbeatMs = nowMs
        if (nowMs - lastHeartbeatMs < HEARTBEAT_INTERVAL_MS) return
        Log.i(
            TAG,
            "sensor alive: $samplesSinceLog mẫu/10s " +
                "|a| min=$minMagnitudeSinceLog max=$maxMagnitudeSinceLog " +
                "wakeUp=$usingWakeUpSensor wakeLock=${wakeLock?.isHeld}",
        )
        samplesSinceLog = 0
        maxMagnitudeSinceLog = 0f
        minMagnitudeSinceLog = Float.MAX_VALUE
        lastHeartbeatMs = nowMs
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
        private const val TAG = "SosGuard"
        private const val WAKE_LOCK_TAG = "FamilyCare:SosGuard"
        private const val HEARTBEAT_INTERVAL_MS = 10_000L

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
