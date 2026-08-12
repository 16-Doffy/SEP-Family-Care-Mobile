package com.familycare.family_care

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmergencySosMatcherTest {
    @Test
    fun `dung package va class thi ban dung mot lan`() {
        val matcher = EmergencySosMatcher()
        assertTrue(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.LaunchEmergencyCallActivity", 0),
        )
        // Event tiep theo bung lien tuc ~4 lan/giay trong luc man con hien.
        assertFalse(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.LaunchEmergencyCallActivity", 250),
        )
        assertFalse(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.EmergencyCallDetailActivity", 500),
        )
    }

    @Test
    fun `sai package thi khong ban`() {
        val matcher = EmergencySosMatcher()
        assertFalse(
            matcher.shouldTrigger("com.android.launcher", "com.oplus.sos.LaunchEmergencyCallActivity", 0),
        )
    }

    @Test
    fun `dung package nhung class khong lien quan emergency thi khong ban`() {
        val matcher = EmergencySosMatcher()
        assertFalse(matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.SettingsActivity", 0))
    }

    @Test
    fun `packageName hoac className null thi khong ban`() {
        val matcher = EmergencySosMatcher()
        assertFalse(matcher.shouldTrigger(null, "com.oplus.sos.LaunchEmergencyCallActivity", 0))
        assertFalse(matcher.shouldTrigger("com.oplus.sos", null, 0))
    }

    @Test
    fun `qua cooldown thi ban lai duoc`() {
        val matcher = EmergencySosMatcher(cooldownMs = 30_000L)
        assertTrue(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.LaunchEmergencyCallActivity", 0),
        )
        assertFalse(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.LaunchEmergencyCallActivity", 29_999),
        )
        assertTrue(
            matcher.shouldTrigger("com.oplus.sos", "com.oplus.sos.LaunchEmergencyCallActivity", 30_001),
        )
    }
}
