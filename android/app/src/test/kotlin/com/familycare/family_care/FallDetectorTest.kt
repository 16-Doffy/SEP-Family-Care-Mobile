package com.familycare.family_care

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FallDetectorTest {
    @Test
    fun `roi tu do du lau roi va dap manh thi phat hien te nga`() {
        val detector = FallDetector()
        assertEquals(1, runSamples(detector, fallPattern()))
    }

    @Test
    fun `chi phat hien mot lan cho mot cu nga`() {
        val detector = FallDetector()
        val samples = fallPattern() + listOf(
            28f to 400L,
            26f to 450L,
            9.8f to 500L,
        )
        assertEquals(1, runSamples(detector, samples))
    }

    @Test
    fun `rung manh khong co pha roi tu do thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            28f to 50L,
            8f to 100L,
            31f to 150L,
            7.5f to 200L,
            29f to 250L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `roi tu do qua ngan thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            1f to 50L,
            30f to 90L,
            9.8f to 140L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `roi nhung ha canh nhe thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            1f to 100L,
            0.9f to 200L,
            1.1f to 300L,
            10.5f to 400L,
            9.8f to 500L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `va dap den qua muon thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            1f to 100L,
            0.9f to 200L,
            9.8f to 300L,
            30f to 1400L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `cooldown bo qua cu nga thu hai qua gan`() {
        val detector = FallDetector()
        assertEquals(1, runSamples(detector, fallPattern()))
        assertEquals(0, runSamples(detector, fallPattern(start = 5000)))
    }

    @Test
    fun `het cooldown thi phat hien lai binh thuong`() {
        val detector = FallDetector()
        assertEquals(1, runSamples(detector, fallPattern()))
        assertEquals(1, runSamples(detector, fallPattern(start = 40000)))
    }

    @Test
    fun `reset dua may trang thai ve idle`() {
        val detector = FallDetector()
        assertFalse(detector.addSample(1f, 100))
        assertEquals("free_fall", detector.phaseName())
        detector.reset()
        assertEquals("idle", detector.phaseName())
    }

    private fun runSamples(detector: FallDetector, samples: List<Pair<Float, Long>>): Int {
        var hits = 0
        samples.forEach { (magnitude, at) ->
            if (detector.addSample(magnitude, at)) hits++
        }
        return hits
    }

    private fun fallPattern(start: Long = 0): List<Pair<Float, Long>> = listOf(
        9.8f to start,
        9.7f to start + 50,
        1.0f to start + 100,
        0.8f to start + 150,
        1.2f to start + 200,
        0.9f to start + 250,
        30.0f to start + 300,
        9.9f to start + 350,
    )
}
