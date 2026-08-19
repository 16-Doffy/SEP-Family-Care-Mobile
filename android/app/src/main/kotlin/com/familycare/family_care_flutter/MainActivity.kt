package com.familycare.family_care

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var garminBridge: GarminBridgeService? = null
    private var garminBound = false
    private var wearHeartRateBridge: WearHeartRateBridge? = null
    private var heartRateEventSink: EventChannel.EventSink? = null

    /// Yêu cầu Garmin đang chờ service bind xong (bấm "Ghép Garmin" lần đầu —
    /// chưa có [GarminDeviceCache], nên không tự bind sẵn ở [onStart]).
    private val pendingGarminRequests = mutableListOf<(GarminBridgeService) -> Unit>()

    private val garminConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val bridge = (service as? GarminBridgeService.LocalBinder)?.getService() ?: return
            garminBridge = bridge
            val queued = pendingGarminRequests.toList()
            pendingGarminRequests.clear()
            queued.forEach { it(bridge) }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            garminBridge = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        // Đã pair Garmin từ trước (kể cả app bị kill/máy reboot rồi mở lại) —
        // tự chạy bridge ngay, không đợi người dùng vào lại màn Wearables.
        if (GarminDeviceCache.read(this) != null) {
            GarminBridgeService.start(this)
        }
    }

    /// CHỈ bind khi đã từng pair Garmin — bind vô điều kiện ở đây (bản cũ)
    /// khiến MỌI user mở app đều tự tạo GarminBridgeService (kèm notification
    /// thường trực), kể cả người chưa từng đụng tới Garmin. Lượt ghép nối
    /// ĐẦU TIÊN (chưa có cache) bind qua [withGarminBridge] khi thật sự cần,
    /// từ handler "getKnownDevices"/"confirmPair".
    override fun onStart() {
        super.onStart()
        if (GarminDeviceCache.read(this) != null) {
            garminBound = bindService(
                Intent(this, GarminBridgeService::class.java),
                garminConnection,
                Context.BIND_AUTO_CREATE,
            )
        }
    }

    override fun onStop() {
        if (garminBound) {
            unbindService(garminConnection)
            garminBound = false
        }
        pendingGarminRequests.clear()
        super.onStop()
    }

    /// Dùng bridge đang bind sẵn nếu có; nếu chưa (lượt ghép Garmin đầu tiên,
    /// trước khi có [GarminDeviceCache]) thì tự start + bind rồi chạy [onReady]
    /// ngay khi [ServiceConnection.onServiceConnected] về.
    private fun withGarminBridge(onReady: (GarminBridgeService) -> Unit) {
        val bridge = garminBridge
        if (bridge != null) {
            onReady(bridge)
            return
        }
        pendingGarminRequests.add(onReady)
        if (!garminBound) {
            GarminBridgeService.start(this)
            garminBound = bindService(
                Intent(this, GarminBridgeService::class.java),
                garminConnection,
                Context.BIND_AUTO_CREATE,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SOS_GUARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val shakeEnabled = call.argument<Boolean>("shakeEnabled") ?: false
                    val fallEnabled = call.argument<Boolean>("fallEnabled") ?: false
                    startSosGuard(shakeEnabled, fallEnabled)
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, SosGuardService::class.java))
                    result.success(null)
                }
                "getStatus" -> {
                    result.success(
                        mapOf(
                            "running" to SosGuardService.running,
                            "shakeEnabled" to SosGuardService.shakeEnabled,
                            "fallEnabled" to SosGuardService.fallEnabled,
                            "fullScreenIntentGranted" to SosAlertLauncher.hasFullScreenIntentPermission(this),
                            "emergencyWatcherEnabled" to isEmergencyWatcherEnabled(),
                        ),
                    )
                }
                "openBatteryOptimizationSettings" -> {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                "openFullScreenIntentSettings" -> {
                    openFullScreenIntentSettings()
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "isEmergencyWatcherEnabled" -> result.success(isEmergencyWatcherEnabled())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_SESSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "cacheSession" -> {
                    val token = call.argument<String>("token")
                    val familyId = call.argument<String>("familyId")
                    val baseUrl = call.argument<String>("baseUrl")
                    if (token != null && familyId != null && baseUrl != null) {
                        TokenCache.save(applicationContext, token, familyId, baseUrl)
                    }
                    result.success(null)
                }
                "clearSession" -> {
                    TokenCache.clear(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_GUARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startCallGuard()
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, CallGuardService::class.java))
                    result.success(null)
                }
                "isRunning" -> result.success(CallGuardService.running)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GARMIN_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getKnownDevices" -> {
                    withGarminBridge { bridge ->
                        bridge.getKnownDevices { devices, error ->
                            if (error != null) {
                                result.error("GARMIN_ERROR", error, null)
                            } else {
                                result.success(devices)
                            }
                        }
                    }
                }
                "checkDeviceReady" -> {
                    val iqDeviceId = (call.argument<Number>("iqDeviceId"))?.toLong()
                    val iqFriendlyName = call.argument<String>("iqFriendlyName") ?: "Garmin watch"
                    if (iqDeviceId == null) {
                        result.error("INVALID_ARGS", "Thiếu iqDeviceId", null)
                    } else {
                        withGarminBridge { bridge ->
                            bridge.checkDeviceReadyForPairing(iqDeviceId, iqFriendlyName) { ready, error ->
                                if (ready) result.success(null) else result.error("GARMIN_ERROR", error, null)
                            }
                        }
                    }
                }
                "confirmPair" -> {
                    val iqDeviceId = (call.argument<Number>("iqDeviceId"))?.toLong()
                    val iqFriendlyName = call.argument<String>("iqFriendlyName") ?: "Garmin watch"
                    val backendDeviceId = call.argument<String>("backendDeviceId")
                    val memberName = call.argument<String>("memberName") ?: ""
                    if (iqDeviceId == null || backendDeviceId.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "Thiếu iqDeviceId/backendDeviceId", null)
                    } else {
                        withGarminBridge { bridge ->
                            bridge.confirmPair(iqDeviceId, iqFriendlyName, backendDeviceId, memberName) { ok, error ->
                                if (ok) result.success(null) else result.error("GARMIN_ERROR", error, null)
                            }
                        }
                    }
                }
                "stopBridge" -> {
                    garminBridge?.stopBridge()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Stream nhịp tim thật (WearHeartRateBridge) — EventChannel vì đây là
        // dữ liệu liên tục nhiều mẫu, khác các channel khác trong file này chỉ
        // gọi 1 lần rồi trả kết quả qua callback.
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEAR_HEART_RATE_EVENTS_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    heartRateEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    heartRateEventSink = null
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEAR_HEART_RATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    // health-services-client khai minSdk 30 (Wear OS 3+) —
                    // app chạy chung điện thoại/Wear OS nên phải tự chặn ở
                    // đây thay vì để AAR/manifest chặn cả app. Xem
                    // AndroidManifest.xml (tools:overrideLibrary).
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                        result.error(
                            "UNSUPPORTED_SDK",
                            "Cần Wear OS 3 trở lên (Android 11+) để đọc nhịp tim thật",
                            null,
                        )
                    } else {
                        val bridge = wearHeartRateBridge
                            ?: WearHeartRateBridge(applicationContext).also { wearHeartRateBridge = it }
                        // Health Services gọi callback trên main thread theo
                        // mặc định (không truyền Executor riêng) — an toàn
                        // gọi thẳng EventSink.success() từ đây, không cần
                        // post lại Handler.
                        bridge.start(
                            onReading = { bpm -> heartRateEventSink?.success(mapOf("bpm" to bpm)) },
                            onError = { message ->
                                heartRateEventSink?.error("HEART_RATE_ERROR", message, null)
                            },
                        )
                        result.success(null)
                    }
                }
                "stop" -> {
                    wearHeartRateBridge?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSosGuard(shakeEnabled: Boolean, fallEnabled: Boolean) {
        if (!shakeEnabled && !fallEnabled) {
            stopService(Intent(this, SosGuardService::class.java))
            return
        }
        val intent = Intent(this, SosGuardService::class.java).apply {
            putExtra(SosGuardService.EXTRA_SHAKE_ENABLED, shakeEnabled)
            putExtra(SosGuardService.EXTRA_FALL_ENABLED, fallEnabled)
        }
        startForegroundCompat(intent)
    }

    private fun startCallGuard() {
        startForegroundCompat(Intent(this, CallGuardService::class.java))
    }

    /// So khớp `ENABLED_ACCESSIBILITY_SERVICES` (danh sách phân tách bởi `:`)
    /// để biết người dùng đã tự bật EmergencySosWatcherService trong Cài đặt
    /// > Trợ năng chưa — app không có cách nào tự bật hộ, chỉ đọc trạng thái.
    private fun isEmergencyWatcherEnabled(): Boolean {
        val expected = ComponentName(this, EmergencySosWatcherService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.splitToSequence(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    private fun startForegroundCompat(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    companion object {
        private const val SOS_GUARD_CHANNEL = "com.familycare.family_care/sos_guard"
        private const val CALL_GUARD_CHANNEL = "com.familycare.family_care/call_guard"
        private const val NATIVE_SESSION_CHANNEL = "com.familycare.family_care/native_session"
        private const val GARMIN_CHANNEL = "com.familycare.family_care/garmin"
        private const val WEAR_HEART_RATE_CHANNEL = "com.familycare.family_care/wear_heart_rate"
        private const val WEAR_HEART_RATE_EVENTS_CHANNEL = "com.familycare.family_care/wear_heart_rate_stream"
    }
}
