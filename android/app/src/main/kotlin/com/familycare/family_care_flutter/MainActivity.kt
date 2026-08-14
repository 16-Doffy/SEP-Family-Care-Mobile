package com.familycare.family_care

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
