package com.familycare.family_care

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSpike" -> {
                    val intent = Intent(this, SosGuardService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopSpike" -> {
                    stopService(Intent(this, SosGuardService::class.java))
                    result.success(true)
                }
                "isSpikeRunning" -> result.success(SosGuardService.isRunning)
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val CHANNEL = "familycare/sos_guard_spike"
    }
}
