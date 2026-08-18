package com.familycare.family_care

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/// Bản sao mã hoá của session hiện tại (access token + familyId + base URL),
/// để [SosEmergencyFlowService] tự gọi được API SOS khi phát hiện té ngã lúc
/// Flutter engine không còn sống — Dart `ApiClient` không đọc được từ tiến
/// trình native.
///
/// Flutter đẩy xuống qua MethodChannel `native_session` mỗi khi login/refresh
/// thành công (xem `NativeSessionBridge` trong `lib/services/`). KHÔNG lưu
/// refresh token ở đây — chỉ access token, để giảm rủi ro nếu bị trích xuất;
/// token hết hạn (sống 15 phút) thì native chấp nhận gửi SOS thất bại, ghi rõ
/// lý do trong log bước 6 thay vì tự ý refresh.
object TokenCache {
    private const val PREFS_NAME = "familycare_native_session"
    private const val KEY_TOKEN = "token"
    private const val KEY_FAMILY_ID = "familyId"
    private const val KEY_BASE_URL = "baseUrl"

    data class Session(val token: String, val familyId: String, val baseUrl: String)

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

    fun save(context: Context, token: String, familyId: String, baseUrl: String) {
        prefs(context).edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_FAMILY_ID, familyId)
            .putString(KEY_BASE_URL, baseUrl)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun read(context: Context): Session? {
        val p = prefs(context)
        val token = p.getString(KEY_TOKEN, null) ?: return null
        val familyId = p.getString(KEY_FAMILY_ID, null) ?: return null
        val baseUrl = p.getString(KEY_BASE_URL, null) ?: return null
        return Session(token, familyId, baseUrl)
    }
}
