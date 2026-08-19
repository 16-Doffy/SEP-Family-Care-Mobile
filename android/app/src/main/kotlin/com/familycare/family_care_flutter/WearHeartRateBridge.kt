package com.familycare.family_care

import android.content.Context
import android.util.Log
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DataTypeAvailability
import androidx.health.services.client.data.DeltaDataType

/// Đọc nhịp tim THẬT qua Wear Health Services API — chỉ hoạt động trên đồng
/// hồ Wear OS thật có cảm biến PPG + Google Play services for Wear cài sẵn.
/// Không chạy được trên emulator/điện thoại thường (không có cảm biến để
/// Health Services đọc), xem
/// `PHAN_TICH_SOS_WEARABLE_FALL_HEART_RATE_2026-08-19.md`.
///
/// **[CHƯA VERIFY]** Chưa build/chạy thật với đồng hồ Wear OS thật — không có
/// thiết bị để test tại thời điểm viết (2026-08-19). Viết theo API chính thức
/// `androidx.health.services.client` (Health Services on Wear OS), chưa
/// compile-check được với thiết bị thật.
///
/// Yêu cầu quyền runtime `android.permission.BODY_SENSORS` — PHẢI xin và được
/// cấp ở phía Dart (`WearHeartRateBridge.requestPermission()` trong
/// `wear_heart_rate_bridge.dart`) trước khi gọi [start], nếu không
/// `registerMeasureCallback` sẽ thất bại vì thiếu quyền.
class WearHeartRateBridge(context: Context) {
    private val measureClient by lazy {
        HealthServices.getClient(context).measureClient
    }
    private var callback: MeasureCallback? = null

    /// [onReading] gọi mỗi khi có mẫu nhịp tim mới (bpm dạng `Double` theo
    /// đúng kiểu Health Services trả về — phía Dart tự làm tròn về `int`
    /// trước khi đưa vào `HeartRateDetector.addSample`).
    fun start(onReading: (bpm: Double) -> Unit, onError: (String) -> Unit) {
        stop()
        val cb = object : MeasureCallback {
            override fun onAvailabilityChanged(
                dataType: DeltaDataType<*, *>,
                availability: Availability,
            ) {
                if (availability is DataTypeAvailability &&
                    availability == DataTypeAvailability.UNAVAILABLE
                ) {
                    Log.w(TAG, "onAvailabilityChanged: UNAVAILABLE cho $dataType")
                }
            }

            override fun onDataReceived(data: DataPointContainer) {
                val points = data.getData(DataType.HEART_RATE_BPM)
                for (point in points) {
                    onReading(point.value)
                }
            }
        }
        callback = cb
        try {
            measureClient.registerMeasureCallback(DataType.HEART_RATE_BPM, cb)
        } catch (e: Exception) {
            Log.e(TAG, "start: đăng ký measure callback thất bại", e)
            callback = null
            onError(e.message ?: "Không khởi động được cảm biến nhịp tim")
        }
    }

    fun stop() {
        val cb = callback ?: return
        callback = null
        try {
            measureClient.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, cb)
        } catch (e: Exception) {
            Log.e(TAG, "stop: huỷ đăng ký measure callback thất bại", e)
        }
    }

    companion object {
        private const val TAG = "WearHeartRate"
    }
}
