package com.familycare.family_care

/**
 * Phát hiện té ngã theo mẫu hai pha: rơi tự do rồi va đập.
 *
 * Ngưỡng rơi tự do nới từ 3.0 lên 6.0 m/s² (2026-08-17) sau khi test thật:
 * người ngã mà điện thoại nằm trong TÚI QUẦN gần như không bao giờ tạo ra pha
 * rơi tự do "sạch" — túi giữ máy áp vào người nên máy đi theo cơ thể, biên độ
 * chỉ tụt xuống khoảng 4–7 m/s² chứ không về gần 0 như khi thả rơi máy.
 * Ngưỡng 3.0 (≈0.3g) chỉ bắt được cú THẢ RƠI MÁY, không bắt được NGƯỜI NGÃ.
 *
 * 6.0 m/s² ≈ 0.61g, nằm trong khoảng 0.5–0.7g mà các nghiên cứu phát hiện té
 * ngã bằng điện thoại thường dùng.
 *
 * Ngưỡng va đập giữ nguyên 25.0 m/s² (≈2.5g) — đây mới là chốt chặn báo động
 * giả chính, và vẫn phải có ĐỦ CẢ HAI pha trong 900ms mới tính.
 */
class FallDetector(
    private val freeFallThreshold: Float = 6.0f,
    private val minFreeFallMs: Long = 80,
    private val impactThreshold: Float = 25.0f,
    private val impactWindowMs: Long = 900,
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
