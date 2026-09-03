package com.familycare.family_care

/**
 * Phát hiện té ngã theo mẫu hai pha: rơi tự do rồi va đập.
 *
 * Ngưỡng rơi tự do nới dần 3.0 → 6.0 (2026-08-17) → 7.0 (2026-09-03) sau khi
 * test thật: người ngã mà điện thoại nằm trong TÚI QUẦN gần như không bao giờ
 * tạo ra pha rơi tự do "sạch" — túi giữ máy áp vào người nên máy đi theo cơ
 * thể, biên độ chỉ tụt xuống khoảng 4–7 m/s² chứ không về gần 0 như khi thả
 * rơi máy. Ngưỡng 3.0 (≈0.3g) chỉ bắt được cú THẢ RƠI MÁY, không bắt được
 * NGƯỜI NGÃ.
 *
 * 7.0 m/s² ≈ 0.71g, nằm ở mép trên khoảng 0.5–0.7g mà các nghiên cứu phát
 * hiện té ngã bằng điện thoại thường dùng. Biên với nhịp đi bộ bình thường
 * (đáy mỗi bước rơi vào khoảng 6.8–7.2 m/s²) nay chỉ còn rất mỏng — thứ bù
 * lại là VẪN bắt buộc phải có pha va đập ngay sau đó mới tính là ngã.
 *
 * Ngưỡng va đập hạ 25.0 → 19.0 m/s² (2026-09-03, ≈2.55g → ≈1.94g) cùng cửa sổ
 * va đập nới 900 → 1200ms: đo thực tế cho thấy cú ngã/thả máy xuống bề mặt
 * mềm (đệm, thảm) hiếm khi chạm được 25.0 nên lúc bắt được lúc không, phải
 * đập máy khá mạnh mới trigger. 19.0 vẫn là chốt chặn báo động giả chính, và
 * vẫn phải có ĐỦ CẢ HAI pha trong 1200ms mới tính.
 *
 * CẢNH BÁO: bộ số dưới đây phải khớp từng con với `FallDetectionTuning` trong
 * `lib/services/fall_detector_service.dart`. Bản Kotlin canh cảm biến lúc app
 * chạy nền/màn hình khoá, bản Dart canh lúc app đang mở — lệch số thì cùng
 * một cú ngã cho hai kết quả khác nhau và không chẩn đoán được gì.
 */
class FallDetector(
    private val freeFallThreshold: Float = 7.0f,
    private val minFreeFallMs: Long = 60,
    private val impactThreshold: Float = 19.0f,
    private val impactWindowMs: Long = 1200,
    private val cooldownMs: Long = 30_000,
) {
    enum class Phase { IDLE, FREE_FALL, AWAITING_IMPACT }

    private var phase = Phase.IDLE
    private var freeFallStart: Long? = null
    private var freeFallEnd: Long? = null
    private var lastTrigger: Long? = null

    fun phaseName(): String = phase.name.lowercase()

    fun reset() {
        phase = Phase.IDLE
        freeFallStart = null
        freeFallEnd = null
    }

    fun addSample(magnitude: Float, nowMs: Long): Boolean {
        val last = lastTrigger
        if (last != null && nowMs - last < cooldownMs) {
            reset()
            return false
        }

        if (magnitude <= freeFallThreshold) {
            if (phase == Phase.IDLE) {
                phase = Phase.FREE_FALL
                freeFallStart = nowMs
            }
            return false
        }

        if (phase == Phase.FREE_FALL) {
            val fellMs = nowMs - (freeFallStart ?: nowMs)
            if (fellMs >= minFreeFallMs) {
                phase = Phase.AWAITING_IMPACT
                freeFallEnd = nowMs
            } else {
                reset()
                return false
            }
        }

        if (phase != Phase.AWAITING_IMPACT) return false

        if (nowMs - (freeFallEnd ?: nowMs) > impactWindowMs) {
            reset()
            return false
        }

        if (magnitude >= impactThreshold) {
            lastTrigger = nowMs
            reset()
            return true
        }
        return false
    }
}
