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
import android.util.Log
import kotlin.math.sqrt

class SosGuardService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var sampleCount = 0

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startInForeground()
        registerAccelerometer()
        Log.d(TAG, "started sensor spike service")
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        isRunning = false
        Log.d(TAG, "stopped sensor spike service")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        sampleCount += 1
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val magnitude = sqrt((x * x + y * y + z * z).toDouble())
        val interactive = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive

        if (sampleCount == 1 || sampleCount % LOG_EVERY_N_SAMPLES == 0) {
            Log.d(
                TAG,
                "sample=$sampleCount interactive=$interactive magnitude=${"%.2f".format(magnitude)} " +
                    "x=${"%.2f".format(x)} y=${"%.2f".format(y)} z=${"%.2f".format(z)}",
            )
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun registerAccelerometer() {
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.d(TAG, "accelerometer not found")
            stopSelf()
            return
        }
        sensorManager.unregisterListener(this)
        sensorManager.registerListener(
            this,
            accelerometer,
            SENSOR_PERIOD_US,
        )
    }

    private fun startInForeground() {
        createNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java)
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(this, SosGuardService::class.java).setAction(ACTION_STOP)
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Family Care SOS đang kiểm tra cảm biến")
            .setContentText("Khóa màn hình rồi xem logcat tag SOSSHAKE.")
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dừng", stopPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SOS sensor guard",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Foreground service thử gia tốc kế cho SOS khi khóa màn hình"
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    companion object {
        const val TAG = "SOSSHAKE"
        private const val CHANNEL_ID = "sos_guard_spike"
        private const val NOTIFICATION_ID = 4108
        private const val SENSOR_PERIOD_US = 50_000
        private const val LOG_EVERY_N_SAMPLES = 20
        private const val ACTION_STOP = "com.familycare.family_care.action.STOP_SOS_GUARD_SPIKE"

        @Volatile
        var isRunning = false
            private set
    }
}
