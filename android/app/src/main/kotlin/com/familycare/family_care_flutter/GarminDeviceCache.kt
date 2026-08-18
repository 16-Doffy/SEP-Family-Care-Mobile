package com.familycare.family_care

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/// Nhớ Garmin watch nào đã pair xong (IQDevice + deviceId phía backend), để
/// [GarminBridgeService] tự đăng ký lại app-event listener sau khi tiến trình
/// bị hệ thống dọn/khởi động lại — không có bản ghi này thì service không
/// biết phải lắng nghe thiết bị Garmin nào.
///
/// Tách riêng khỏi [TokenCache] vì vòng đời khác nhau: phiên đăng nhập đổi
/// theo tài khoản, còn thiết bị Garmin đã pair thì giữ nguyên cho tới khi
/// người dùng chủ động gỡ ghép nối (`unpairDevice`).
object GarminDeviceCache {
    private const val PREFS_NAME = "familycare_garmin_device"
    private const val KEY_IQ_DEVICE_ID = "iqDeviceId"
    private const val KEY_IQ_FRIENDLY_NAME = "iqFriendlyName"
    private const val KEY_BACKEND_DEVICE_ID = "backendDeviceId"

    data class PairedDevice(
        val iqDeviceId: Long,
        val iqFriendlyName: String,
        val backendDeviceId: String,
    )

    private fun prefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun save(context: Context, device: PairedDevice) {
        prefs(context).edit()
            .putLong(KEY_IQ_DEVICE_ID, device.iqDeviceId)
            .putString(KEY_IQ_FRIENDLY_NAME, device.iqFriendlyName)
            .putString(KEY_BACKEND_DEVICE_ID, device.backendDeviceId)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun read(context: Context): PairedDevice? {
        val p = prefs(context)
        if (!p.contains(KEY_IQ_DEVICE_ID)) return null
        val iqDeviceId = p.getLong(KEY_IQ_DEVICE_ID, -1L)
        val backendDeviceId = p.getString(KEY_BACKEND_DEVICE_ID, null) ?: return null
        if (iqDeviceId <= 0L) return null
        return PairedDevice(
            iqDeviceId = iqDeviceId,
            iqFriendlyName = p.getString(KEY_IQ_FRIENDLY_NAME, null) ?: "Garmin watch",
            backendDeviceId = backendDeviceId,
        )
    }
}
