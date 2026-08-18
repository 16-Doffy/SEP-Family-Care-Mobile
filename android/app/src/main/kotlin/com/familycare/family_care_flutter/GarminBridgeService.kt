package com.familycare.family_care

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import org.json.JSONObject

/// Cầu nối Android <-> Garmin watch app qua Garmin Connect IQ Mobile SDK.
///
/// Garmin watch app KHÔNG gọi backend trực tiếp — nó chỉ là sensor source.
/// Service này (chạy foreground, độc lập Activity/Flutter engine, giống
/// [SosEmergencyFlowService]) là bridge duy nhất:
///   - Gửi `PAIR_CONFIRMED` xuống watch sau khi FE pair xong qua API có sẵn
///     `POST /families/{familyId}/wearables`.
///   - Nhận `FALL_DETECTED` từ watch, tự POST
///     `/families/{familyId}/wearables/{deviceId}/events` — KHÔNG cần Flutter
///     engine sống, dùng JWT cache trong [TokenCache] (tái dùng nguyên trạng
///     từ đợt Fall Detection native 2026-08-18).
///
/// **[CHƯA VERIFY]** Chưa build/chạy thật với SDK + watch app thật — xem
/// `KE_HOACH_GARMIN_CONNECTIQ_INTEGRATION_2026-08-18.md` mục "Chưa làm".
/// API `com.garmin.connectiq.*` viết theo sample chính thức của Garmin
/// (`garmin/connectiq-android-sdk` — Comm Android sample), chưa compile-check
/// được với SDK thật trong máy này.
class GarminBridgeService : Service() {
    private val binder = LocalBinder()
    private var connectIQ: ConnectIQ? = null
    private var sdkReady = false
    private val pendingWhenReady = mutableListOf<() -> Unit>()
    private val bgThread = HandlerThread("GarminBridge").apply { start() }
    private val bgHandler by lazy { Handler(bgThread.looper) }
    private val mainHandler = Handler(Looper.getMainLooper())

    /// Cho phép [MainActivity] bind trực tiếp vào service đang chạy (để gọi
    /// getKnownDevices/confirmPair có callback đồng bộ), nhưng service vẫn
    /// SỐNG SAU KHI unbind vì được start bằng `startForegroundService` —
    /// không dùng `START_STICKY` một mình vì cần cả 2: chạy nền lâu dài (nhận
    /// fall event) VÀ cho Activity bind tạm khi người dùng đang ở màn ghép
    /// nối.
    inner class LocalBinder : Binder() {
        fun getService(): GarminBridgeService = this@GarminBridgeService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForegroundWith(buildRunningNotification())
        setupConnectIQSdk()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Không có action riêng — start() chỉ để đảm bảo service đang chạy.
        // START_STICKY: đây là listener sống lâu dài (khác
        // SosEmergencyFlowService là luồng 1 lần rồi tự dừng).
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            connectIQ?.unregisterAllForEvents()
            connectIQ?.shutdown(applicationContext)
        } catch (e: InvalidStateException) {
            // SDK đã shutdown sẵn — bỏ qua.
        }
        bgThread.quitSafely()
        super.onDestroy()
    }

    // ── ConnectIQ SDK lifecycle ────────────────────────────────────────────

    private fun setupConnectIQSdk() {
        val iq = ConnectIQ.getInstance(applicationContext, ConnectIQ.IQConnectType.WIRELESS)
        connectIQ = iq
        iq.initialize(
            applicationContext,
            true,
            object : ConnectIQ.ConnectIQListener {
                override fun onSdkReady() {
                    Log.i(TAG, "Garmin SDK ready")
                    sdkReady = true
                    reregisterCachedDevice()
                    val queued = pendingWhenReady.toList()
                    pendingWhenReady.clear()
                    queued.forEach { it() }
                }

                override fun onInitializeError(errStatus: ConnectIQ.IQSdkErrorStatus) {
                    Log.e(TAG, "Garmin SDK init lỗi: ${errStatus.name}")
                    sdkReady = false
                }

                override fun onSdkShutDown() {
                    Log.i(TAG, "Garmin SDK shutdown")
                    sdkReady = false
                }
            },
        )
    }

    /// Chạy [action] ngay nếu SDK đã sẵn sàng, nếu chưa thì xếp hàng chạy khi
    /// `onSdkReady()` — tránh gọi API SDK lúc `InvalidStateException`.
    private fun runWhenSdkReady(action: () -> Unit) {
        if (sdkReady) action() else pendingWhenReady.add(action)
    }

    /// Sau khi tiến trình bị hệ thống dọn rồi khởi động lại (`START_STICKY`)
    /// hoặc app mở lại sau khi bị kill, tự đăng ký lại listener cho watch đã
    /// pair trước đó — không có bước này thì mất fall event cho tới khi
    /// người dùng ghép lại từ đầu.
    private fun reregisterCachedDevice() {
        val cached = GarminDeviceCache.read(applicationContext) ?: return
        val device = IQDevice(cached.iqDeviceId, cached.iqFriendlyName)
        registerListenersFor(device)
    }

    private fun registerListenersFor(device: IQDevice) {
        val iq = connectIQ ?: return
        try {
            iq.unregisterForDeviceEvents(device)
            iq.registerForDeviceEvents(device) { _, status ->
                Log.i(TAG, "Garmin device ${device.deviceIdentifier} status=$status")
            }
            val app = IQApp(GARMIN_APP_UUID)
            iq.unregisterForApplicationEvents(device, app)
            iq.registerForAppEvents(device, app) { fromDevice, _, message, _ ->
                handleAppMessage(fromDevice, message)
            }
        } catch (e: InvalidStateException) {
            Log.e(TAG, "registerListenersFor: SDK chưa sẵn sàng", e)
        }
    }

    // ── Gọi từ MainActivity (bound) ────────────────────────────────────────

    fun getKnownDevices(callback: (devices: List<Map<String, Any?>>, error: String?) -> Unit) {
        runWhenSdkReady {
            val iq = connectIQ
            if (iq == null) {
                mainHandler.post { callback(emptyList(), "ConnectIQ chưa khởi tạo") }
                return@runWhenSdkReady
            }
            try {
                val devices = iq.knownDevices ?: emptyList()
                val mapped = devices.map {
                    mapOf(
                        "iqDeviceId" to it.deviceIdentifier,
                        "friendlyName" to it.friendlyName,
                        "status" to (iq.getDeviceStatus(it)?.name ?: "UNKNOWN"),
                    )
                }
                mainHandler.post { callback(mapped, null) }
            } catch (e: ServiceUnavailableException) {
                mainHandler.post {
                    callback(
                        emptyList(),
                        "Garmin Connect Mobile chưa cài hoặc chưa chạy",
                    )
                }
            } catch (e: InvalidStateException) {
                mainHandler.post { callback(emptyList(), "ConnectIQ chưa sẵn sàng") }
            }
        }
    }

    /// Gọi SAU KHI FE đã pair xong qua `POST /families/{familyId}/wearables`
    /// (có `backendDeviceId`). Lưu mapping IQDevice <-> backendDeviceId rồi
    /// gửi `PAIR_CONFIRMED` — watch chỉ bắt đầu fall detection sau message
    /// này.
    fun confirmPair(
        iqDeviceId: Long,
        iqFriendlyName: String,
        backendDeviceId: String,
        memberName: String,
        callback: (success: Boolean, error: String?) -> Unit,
    ) {
        val device = IQDevice(iqDeviceId, iqFriendlyName)
        GarminDeviceCache.save(
            applicationContext,
            GarminDeviceCache.PairedDevice(iqDeviceId, iqFriendlyName, backendDeviceId),
        )
        registerListenersFor(device)
        runWhenSdkReady {
            val iq = connectIQ
            if (iq == null) {
                mainHandler.post { callback(false, "ConnectIQ chưa khởi tạo") }
                return@runWhenSdkReady
            }
            try {
                iq.sendMessage(
                    device,
                    IQApp(GARMIN_APP_UUID),
                    mapOf(
                        "type" to "PAIR_CONFIRMED",
                        "deviceId" to backendDeviceId,
                        "memberName" to memberName,
                    ),
                ) { _, _, status ->
                    val ok = status == ConnectIQ.IQMessageStatus.SUCCESS
                    Log.i(TAG, "PAIR_CONFIRMED -> $status")
                    mainHandler.post { callback(ok, if (ok) null else status.name) }
                }
            } catch (e: InvalidStateException) {
                mainHandler.post { callback(false, "ConnectIQ chưa sẵn sàng: ${e.message}") }
            } catch (e: ServiceUnavailableException) {
                mainHandler.post {
                    callback(false, "Garmin Connect Mobile chưa cài hoặc chưa chạy")
                }
            }
        }
    }

    fun stopBridge() {
        val cached = GarminDeviceCache.read(applicationContext)
        if (cached != null) {
            try {
                val device = IQDevice(cached.iqDeviceId, cached.iqFriendlyName)
                connectIQ?.unregisterForDeviceEvents(device)
                connectIQ?.unregisterForApplicationEvents(device, IQApp(GARMIN_APP_UUID))
            } catch (e: InvalidStateException) {
                // Không sao — đang dừng hẳn.
            }
        }
        GarminDeviceCache.clear(applicationContext)
        stopForegroundCompat()
        stopSelf()
    }

    // ── Nhận message từ watch ───────────────────────────────────────────────

    private fun handleAppMessage(device: IQDevice, message: MutableList<Any>) {
        val payload = message.firstOrNull() as? Map<*, *>
        if (payload == null) {
            Log.i(TAG, "Message Garmin không phải Dictionary, bỏ qua: $message")
            return
        }
        when (payload["type"] as? String) {
            "FALL_DETECTED" -> handleFallDetected(payload)
            else -> Log.i(TAG, "Message Garmin loại lạ: ${payload["type"]}")
        }
    }

    /// Payload watch gửi khớp mô tả BE đã chốt (2026-08-18): forward nguyên
    /// văn các field cảm biến vào `rawValue` của
    /// `POST /families/{familyId}/wearables/{deviceId}/events`, KHÔNG suy
    /// diễn/tính toán lại trên Android.
    private fun handleFallDetected(payload: Map<*, *>) {
        val backendDeviceId = payload["deviceId"] as? String
        if (backendDeviceId.isNullOrEmpty()) {
            Log.e(TAG, "FALL_DETECTED thiếu deviceId, không gửi được sự kiện")
            return
        }
        val session = TokenCache.read(applicationContext)
        if (session == null) {
            Log.e(TAG, "FALL_DETECTED: thiếu phiên đăng nhập native (TokenCache rỗng)")
            return
        }
        val rawValue = JSONObject().apply {
            put("source", "garmin_fr735xt")
            put("deviceIdentifier", payload["deviceIdentifier"]?.toString() ?: "")
            putOpt("magnitude", payload["magnitude"] as? Number)
            putOpt("x", payload["x"] as? Number)
            putOpt("y", payload["y"] as? Number)
            putOpt("z", payload["z"] as? Number)
            putOpt("freeFallMs", payload["freeFallMs"] as? Number)
            putOpt("impactMagnitude", payload["impactMagnitude"] as? Number)
            putOpt("stillSeconds", payload["stillSeconds"] as? Number)
            putOpt("detectedAt", payload["detectedAt"] as? Number)
        }
        val body = JSONObject().apply {
            put("eventType", "FALL_DETECTED")
            put("severity", "HIGH")
            put("rawValue", rawValue)
        }
        bgHandler.post {
            try {
                val url = URL(
                    "${session.baseUrl}/families/${session.familyId}/wearables/$backendDeviceId/events",
                )
                val (code, text) = postJson(url, session.token, body)
                Log.i(TAG, "FALL_DETECTED -> POST events $code $text")
            } catch (e: Exception) {
                Log.e(TAG, "FALL_DETECTED: gửi sự kiện thất bại: ${e.message}", e)
            }
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
            OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use {
                it.write(body.toString())
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use(BufferedReader::readText) ?: ""
            return code to text
        } finally {
            connection.disconnect()
        }
    }

    // ── Notification (foreground service bắt buộc phải có) ──────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Kết nối Garmin", NotificationManager.IMPORTANCE_MIN).apply {
                description = "Giữ kết nối với đồng hồ Garmin để nhận cảnh báo té ngã"
                setShowBadge(false)
            },
        )
    }

    private fun startForegroundWith(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun builder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private fun buildRunningNotification(): Notification =
        builder()
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MIN)
            .setContentTitle("Đang kết nối với Garmin")
            .setContentText("Sẵn sàng nhận cảnh báo té ngã từ đồng hồ")
            .build()

    companion object {
        private const val TAG = "GarminBridge"
        private const val CHANNEL_ID = "familycare_garmin_bridge"
        private const val NOTIFICATION_ID = 9201

        /// UUID app watch "Family Care Garmin" — do team Garmin (Monkey C)
        /// cung cấp, khai trong `garmin/watch-app/manifest.xml` phía họ.
        /// **PHẢI KHỚP CHÍNH XÁC** — sai UUID thì `registerForAppEvents`
        /// không bao giờ nhận được message vì SDK lọc theo app id này.
        const val GARMIN_APP_UUID = "b15c3d2e-6f42-4c2b-8f8d-4a8e0f0f735a"

        fun start(context: Context) {
            val intent = Intent(context, GarminBridgeService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
