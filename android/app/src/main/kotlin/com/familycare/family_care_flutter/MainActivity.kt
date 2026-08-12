package com.familycare.family_care

import android.app.NotificationManager
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
                            "fullScreenIntentGranted" to hasFullScreenIntentPermission(),
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

    /// Từ Android 14 (API 34), app phải được người dùng cấp thủ công mới mở
    /// được Activity full-screen từ notification khi máy khóa/nền. Kiểm tra
    /// đúng bằng `canUseFullScreenIntent()` — máy cũ hơn không có giới hạn
    /// này nên luôn coi như đã có quyền.
    private fun hasFullScreenIntentPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(NotificationManager::class.java)
        return manager.canUseFullScreenIntent()
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
