package com.familycare.family_care

class FallDetector(
    private val freeFallThreshold: Float = 3.0f,
    private val minFreeFallMs: Long = 100,
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
