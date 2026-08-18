package com.familycare.family_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import org.json.JSONObject

/// Foreground service chạy TOÀN BỘ luồng "phát hiện té ngã -> đếm ngược -> lấy
/// GPS -> gửi SOS" độc lập với Activity/Flutter engine.
///
/// Trước đây `SosGuardService` phát hiện té ngã đúng cả khi màn hình tắt,
/// nhưng khi trigger chỉ mở `familycare://app/sos-quick` — nếu người dùng
/// không mở app, `sos_screen.dart` (Dart) không bao giờ chạy được countdown vì
/// Android có thể đóng băng tiến trình khi màn hình tắt lâu. Xem
/// `BAO_CAO_BE_FALL_DETECTION_BACKGROUND_2026-08-18.md` cho bối cảnh đầy đủ.
///
/// State machine chống trùng: một cú ngã chỉ tạo được đúng 1 SOS.
/// idle -> countingDown -> sending -> sent/failed/canceled.
class SosEmergencyFlowService : Service() {
    private enum class State { IDLE, COUNTING_DOWN, SENDING, SENT, FAILED, CANCELED }

    private var state = State.IDLE
    private var countdownTimer: CountDownTimer? = null
    private val bgThread = HandlerThread("SosEmergencyFlow").apply { start() }
    private val bgHandler by lazy { Handler(bgThread.looper) }
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleFallDetected()
            ACTION_FALL_OK -> handleCancel()
            ACTION_FALL_SEND_NOW -> handleSendNow()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        countdownTimer?.cancel()
        bgThread.quitSafely()
        super.onDestroy()
    }

    private fun handleFallDetected() {
        if (state != State.IDLE) {
            Log.i(TAG, "Bỏ qua fall event mới: đang ở state=$state")
            return
        }
        state = State.COUNTING_DOWN
        Log.i(TAG, "1. Fall detected")
        startForegroundWith(buildCountdownNotification(COUNTDOWN_SECONDS))
        Log.i(TAG, "2. Countdown started (${COUNTDOWN_SECONDS}s)")
        countdownTimer = object : CountDownTimer(COUNTDOWN_SECONDS * 1000L, 1000L) {
            override fun onTick(msLeft: Long) {
                val sec = ((msLeft + 999L) / 1000L).toInt()
                notify(buildCountdownNotification(sec))
            }

            override fun onFinish() {
                Log.i(TAG, "3. Countdown finished")
                sendSosNow()
            }
        }.also { it.start() }
    }

    private fun handleCancel() {
        if (state != State.COUNTING_DOWN) return
        Log.i(TAG, "Người dùng bấm 'Tôi ổn' -> hủy countdown, không gửi SOS")
        countdownTimer?.cancel()
        state = State.CANCELED
        stopForegroundCompat()
        stopSelf()
    }

    private fun handleSendNow() {
        if (state != State.COUNTING_DOWN) return
        Log.i(TAG, "Người dùng bấm 'Gửi SOS ngay' -> rút ngắn countdown")
        countdownTimer?.cancel()
        Log.i(TAG, "3. Countdown finished (rút ngắn bởi người dùng)")
        sendSosNow()
    }

    private fun sendSosNow() {
        if (state == State.SENDING || state == State.SENT) return
        state = State.SENDING
        notify(buildSendingNotification())
        bgHandler.post { resolveLocationThenSend() }
    }

    private fun resolveLocationThenSend() {
        Log.i(TAG, "4. Resolving GPS")
        val fused = LocationServices.getFusedLocationProviderClient(applicationContext)
        val cts = CancellationTokenSource()
        var finished = false
        val timeoutRunnable = Runnable {
            if (finished) return@Runnable
            finished = true
            cts.cancel()
            Log.i(TAG, "4. Resolving GPS -> timeout sau ${GPS_TIMEOUT_MS}ms, gửi SOS không kèm toạ độ ban đầu")
            bgHandler.post { sendToBackend(null) }
        }
        mainHandler.postDelayed(timeoutRunnable, GPS_TIMEOUT_MS)
        try {
            fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
                .addOnSuccessListener { loc ->
                    if (finished) return@addOnSuccessListener
                    finished = true
                    mainHandler.removeCallbacks(timeoutRunnable)
                    if (loc != null) {
                        Log.i(TAG, "4. Resolving GPS -> lat=${loc.latitude} lng=${loc.longitude}")
                    } else {
                        Log.i(TAG, "4. Resolving GPS -> null (không có vị trí)")
                    }
                    bgHandler.post { sendToBackend(loc) }
                }
                .addOnFailureListener { e ->
                    if (finished) return@addOnFailureListener
                    finished = true
                    mainHandler.removeCallbacks(timeoutRunnable)
                    Log.e(TAG, "4. Resolving GPS -> lỗi: ${e.message}")
                    bgHandler.post { sendToBackend(null) }
                }
        } catch (e: SecurityException) {
            finished = true
            mainHandler.removeCallbacks(timeoutRunnable)
            Log.e(TAG, "4. Resolving GPS -> thiếu quyền vị trí", e)
            bgHandler.post { sendToBackend(null) }
        }
    }

    /// Contract chốt với BE 2026-08-18: `triggerReason=FALL_DETECTION` KHÔNG bị
    /// chặn bởi `locationRequired` dù thiếu `initialLatitude/initialLongitude`
    /// — xem `BAO_CAO_BE_FALL_DETECTION_BACKGROUND_2026-08-18.md`.
    private fun sendToBackend(location: Location?) {
        val session = TokenCache.read(applicationContext)
        if (session == null) {
            Log.e(TAG, "5. Sending SOS -> BỎ, chưa có session cache native (chưa đăng nhập lúc app còn sống)")
            state = State.FAILED
            notify(buildFailedNotification("Không gửi được SOS tự động: thiếu phiên đăng nhập"))
            stopSelf()
            return
        }
        Log.i(TAG, "5. Sending SOS")
        val body = JSONObject().apply {
            put("sourceType", "MOBILE_APP")
            put("triggerReason", "FALL_DETECTION")
            put("severity", "HIGH")
            if (location != null) {
                put("initialLatitude", location.latitude)
                put("initialLongitude", location.longitude)
            }
            put(
                "message",
                if (location != null) {
                    "Tự động tạo SOS do phát hiện té ngã"
                } else {
                    "Tự động tạo SOS do phát hiện té ngã — không lấy được vị trí ban đầu"
                },
            )
        }
        val (code, responseText) = try {
            postJson(URL("${session.baseUrl}/families/${session.familyId}/sos/alerts"), session.token, body)
        } catch (e: Exception) {
            Log.e(TAG, "6. SOS API response -> lỗi kết nối: ${e.message}", e)
            state = State.FAILED
            notify(buildFailedNotification("Gửi SOS tự động thất bại: mất kết nối. Hãy mở app kiểm tra"))
            stopSelf()
            return
        }
        if (code in 200..299) {
            val json = try { JSONObject(responseText) } catch (e: Exception) { JSONObject() }
            // BE trả field "sosAlertId" ở top-level (đã verify live qua
            // sos_provider.dart), không phải "id" lồng trong "data".
            val alertId = json.optString("sosAlertId").ifEmpty { json.optString("id") }
            Log.i(TAG, "6. SOS API response -> $code alertId=$alertId")
            state = State.SENT
            notify(buildSentNotification())
            if (location == null && alertId.isNotEmpty()) {
                scheduleGpsRetry(session, alertId)
            }
        } else {
            Log.e(TAG, "6. SOS API response -> $code $responseText")
            state = State.FAILED
            notify(buildFailedNotification("Gửi SOS tự động thất bại ($code), hãy mở app kiểm tra"))
        }
        stopSelf()
    }

    /// Sau khi alert đã tạo mà thiếu GPS ban đầu, thử lấy lại GPS 1 lần sau vài
    /// giây rồi vá bằng REST `POST .../sos/alerts/{alertId}/locations` đã có
    /// sẵn — KHÔNG dùng socket Flutter (`sos:responder:location` là luồng
    /// responder đang tới, không phải vị trí nạn nhân).
    private fun scheduleGpsRetry(session: TokenCache.Session, alertId: String) {
        bgHandler.postDelayed({
            try {
                val fused = LocationServices.getFusedLocationProviderClient(applicationContext)
                fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token)
                    .addOnSuccessListener { loc ->
                        if (loc == null) return@addOnSuccessListener
                        bgHandler.post { pushLocationUpdate(session, alertId, loc) }
                    }
            } catch (e: SecurityException) {
                Log.e(TAG, "scheduleGpsRetry: thiếu quyền vị trí", e)
            }
        }, GPS_RETRY_DELAY_MS)
    }

    private fun pushLocationUpdate(session: TokenCache.Session, alertId: String, location: Location) {
        val body = JSONObject().apply {
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("sourceType", "MOBILE_GPS")
            put("accuracy", location.accuracy.toDouble())
        }
        try {
            val (code, _) = postJson(
                URL("${session.baseUrl}/families/${session.familyId}/sos/alerts/$alertId/locations"),
                session.token,
                body,
            )
            Log.i(TAG, "scheduleGpsRetry: vá vị trí sau khi thiếu GPS ban đầu -> $code")
        } catch (e: Exception) {
            Log.e(TAG, "scheduleGpsRetry: lỗi gửi vị trí bổ sung: ${e.message}", e)
        }
    }

    private fun postJson(url: URL, token: String, body: JSONObject): Pair<Int, String> {
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 10_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        try {
            OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use { it.write(body.toString()) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use(BufferedReader::readText) ?: ""
            return code to text
        } finally {
            connection.disconnect()
        }
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Cảnh báo té ngã", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Đếm ngược và gửi SOS tự động khi phát hiện té ngã"
                setShowBadge(true)
            },
        )
    }

    private fun startForegroundWith(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notify(notification: Notification) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun actionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, SosFallActionReceiver::class.java).apply { this.action = action }
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun builder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private fun buildCountdownNotification(secondsLeft: Int): Notification =
        builder()
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_HIGH)
            .setOngoing(true)
            .setContentTitle("Phát hiện té ngã — gửi SOS sau ${secondsLeft}s")
            .setContentText("Không cần mở app. Bấm 'Tôi ổn' nếu đây là báo động giả.")
            .addAction(0, "Tôi ổn", actionPendingIntent(ACTION_FALL_OK, 21))
            .addAction(0, "Gửi SOS ngay", actionPendingIntent(ACTION_FALL_SEND_NOW, 22))
            .build()

    private fun buildSendingNotification(): Notification =
        builder()
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .setContentTitle("Đang gửi SOS…")
            .setContentText("Đang lấy vị trí và gửi cảnh báo khẩn cấp")
            .build()

    private fun buildSentNotification(): Notification =
        builder()
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentTitle("Đã gửi SOS")
            .setContentText("Gia đình bạn đã được báo. Mở app để xem chi tiết.")
            .build()

    private fun buildFailedNotification(message: String): Notification =
        builder()
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentTitle("Gửi SOS tự động thất bại")
            .setContentText(message)
            .build()

    companion object {
        const val ACTION_START = "com.familycare.family_care.FALL_FLOW_START"
        const val ACTION_FALL_OK = "com.familycare.family_care.FALL_OK"
        const val ACTION_FALL_SEND_NOW = "com.familycare.family_care.FALL_SEND_NOW"
        private const val TAG = "SosEmergencyFlow"
        private const val CHANNEL_ID = "familycare_sos_fall_flow"
        private const val NOTIFICATION_ID = 9103
        private const val COUNTDOWN_SECONDS = 10
        private const val GPS_TIMEOUT_MS = 6_000L
        private const val GPS_RETRY_DELAY_MS = 15_000L

        fun start(context: Context) {
            val intent = Intent(context, SosEmergencyFlowService::class.java).apply { action = ACTION_START }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
