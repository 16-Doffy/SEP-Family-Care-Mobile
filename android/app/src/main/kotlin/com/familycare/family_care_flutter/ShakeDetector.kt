package com.familycare.family_care

import java.util.ArrayDeque

class ShakeDetector(
    private val threshold: Float = 25f,
    private val requiredPeaks: Int = 4,
    private val windowMs: Long = 2000,
    private val cooldownMs: Long = 30_000,
) {
    private val peaks = ArrayDeque<Long>()
    private var lastTrigger = 0L
    private var above = false

    fun addSample(magnitude: Float, nowMs: Long): Boolean {
        if (lastTrigger != 0L && nowMs - lastTrigger < cooldownMs) return false

        if (magnitude >= threshold) {
            if (!above) {
                above = true
                peaks.addLast(nowMs)
            }
        } else if (magnitude < threshold * 0.6f) {
            above = false
        }

        while (peaks.isNotEmpty() && nowMs - peaks.first > windowMs) {
            peaks.removeFirst()
        }

        if (peaks.size >= requiredPeaks) {
            peaks.clear()
            above = false
            lastTrigger = nowMs
            return true
        }
        return false
    }
}
