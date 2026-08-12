package com.familycare.family_care

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShakeDetectorTest {
    @Test
    fun `lac du manh trong cua so chi ban mot lan`() {
        val detector = ShakeDetector()
        assertFalse(detector.addSample(26f, 0))
        assertFalse(detector.addSample(8f, 100))
        assertFalse(detector.addSample(27f, 300))
        assertFalse(detector.addSample(8f, 400))
        assertFalse(detector.addSample(28f, 700))
        assertFalse(detector.addSample(8f, 800))
        assertTrue(detector.addSample(29f, 1100))
        assertFalse(detector.addSample(8f, 1200))
        assertFalse(detector.addSample(30f, 1300))
    }

    @Test
    fun `mot cu lac duy nhat khong tao nhieu dinh`() {
        val detector = ShakeDetector()
        assertFalse(detector.addSample(28f, 0))
        assertFalse(detector.addSample(29f, 50))
        assertFalse(detector.addSample(30f, 100))
        assertFalse(detector.addSample(31f, 150))
    }

    @Test
    fun `du dinh nhung rai qua cua so thi khong ban`() {
        val detector = ShakeDetector()
        assertFalse(detector.addSample(26f, 0))
        assertFalse(detector.addSample(8f, 100))
        assertFalse(detector.addSample(27f, 900))
        assertFalse(detector.addSample(8f, 1000))
        assertFalse(detector.addSample(28f, 1900))
        assertFalse(detector.addSample(8f, 2000))
        assertFalse(detector.addSample(29f, 3001))
    }

    @Test
    fun `cooldown chan kich hoat lien tiep`() {
        val detector = ShakeDetector()
        trigger(detector, 0)
        assertFalse(detector.addSample(26f, 2000))
        assertFalse(detector.addSample(8f, 2100))
        assertFalse(detector.addSample(27f, 2300))
        assertFalse(detector.addSample(8f, 2400))
        assertFalse(detector.addSample(28f, 2600))
        assertFalse(detector.addSample(8f, 2700))
        assertFalse(detector.addSample(29f, 2900))
    }

    @Test
    fun `mau di bo bien do thap khong ban`() {
        val detector = ShakeDetector()
        val samples = listOf(9f, 12f, 14f, 10f, 15f, 13f, 9f, 14f, 12f)
        samples.forEachIndexed { index, magnitude ->
            assertFalse(detector.addSample(magnitude, index * 200L))
        }
    }

    private fun trigger(detector: ShakeDetector, start: Long) {
        assertFalse(detector.addSample(26f, start))
        assertFalse(detector.addSample(8f, start + 100))
        assertFalse(detector.addSample(27f, start + 300))
        assertFalse(detector.addSample(8f, start + 400))
        assertFalse(detector.addSample(28f, start + 700))
        assertFalse(detector.addSample(8f, start + 800))
        assertTrue(detector.addSample(29f, start + 1100))
    }
}
