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
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var garminBridge: GarminBridgeService? = null
    private var garminBound = false
    private val garminConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            garminBridge = (service as? GarminBridgeService.LocalBinder)?.getService()
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

    override fun onStart() {
        super.onStart()
        val intent = Intent(this, GarminBridgeService::class.java)
        garminBound = bindService(intent, garminConnection, Context.BIND_AUTO_CREATE)
    }

    override fun onStop() {
        if (garminBound) {
            unbindService(garminConnection)
            garminBound = false
        }
        super.onStop()
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
                    // Promote sang started service NGAY từ bước liệt kê thiết
                    // bị — nếu chỉ promote lúc confirmPair thì bridge có thể
                    // bị hệ thống dọn ngay khi người dùng thoát màn ghép nối
                    // giữa chừng (unbind mà chưa từng được start).
                    GarminBridgeService.start(this)
                    val bridge = garminBridge
                    if (bridge == null) {
                        result.error("NOT_BOUND", "Chưa kết nối được GarminBridgeService", null)
                    } else {
                        bridge.getKnownDevices { devices, error ->
                            if (error != null) {
                                result.error("GARMIN_ERROR", error, null)
                            } else {
                                result.success(devices)
                            }
                        }
                    }
                }
                "confirmPair" -> {
                    GarminBridgeService.start(this)
                    val bridge = garminBridge
                    val iqDeviceId = (call.argument<Number>("iqDeviceId"))?.toLong()
                    val iqFriendlyName = call.argument<String>("iqFriendlyName") ?: "Garmin watch"
                    val backendDeviceId = call.argument<String>("backendDeviceId")
                    val memberName = call.argument<String>("memberName") ?: ""
                    if (bridge == null || iqDeviceId == null || backendDeviceId.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ARGS",
                            "Thiếu iqDeviceId/backendDeviceId hoặc chưa kết nối GarminBridgeService",
                            null,
                        )
                    } else {
                        bridge.confirmPair(iqDeviceId, iqFriendlyName, backendDeviceId, memberName) { ok, error ->
                            if (ok) result.success(null) else result.error("GARMIN_ERROR", error, null)
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
    }
}
