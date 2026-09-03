package com.familycare.family_care

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
    fun `roi tu do 6 den 7 roi va dap khoang 20 thi phat hien te nga`() {
        // Ca mà bộ ngưỡng cũ (6.0 / 25.0) bỏ sót: máy trong túi nên biên độ chỉ
        // tụt xuống 6.4-6.9 m/s², tiếp đất bề mặt mềm nên va đập chỉ ~20.5.
        val detector = FallDetector()
        assertEquals(1, runSamples(detector, softFallPattern()))
    }

    @Test
    fun `va dap dung bang nguong 19 thi van tinh la nga`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            6.8f to 100L,
            6.5f to 180L,
            19f to 240L, // đúng bằng impactThreshold, so sánh là >=
            9.8f to 300L,
        )
        assertEquals(1, runSamples(detector, samples))
    }

    @Test
    fun `va dap o mep cuoi cua so 1200ms thi van tinh la nga`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            1f to 100L,
            0.9f to 200L,
            9.8f to 300L, // hết pha rơi tại đây
            21f to 1450L, // 1150ms sau, còn trong cửa sổ 1200ms
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
    fun `bien do cham 7 phay 5 chua duoi nguong thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            7.6f to 100L,
            8.2f to 150L,
            21f to 200L, // va đập đủ mạnh nhưng trước đó không có pha rơi hợp lệ
            9.8f to 260L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `roi tu do qua ngan thi khong phat hien`() {
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            1f to 50L,
            30f to 90L, // 40ms < minFreeFall 60ms
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
            30f to 1700L, // 1400ms > impactWindow 1200ms
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
    fun `cooldown chan ca cu nga mem di theo ngay sau do`() {
        val detector = FallDetector()
        assertEquals(1, runSamples(detector, softFallPattern()))
        assertEquals(0, runSamples(detector, softFallPattern(start = 8000)))
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

    @Test
    fun `nga voi dien thoai trong tui van phat hien duoc`() {
        // Mẫu đo thực tế của người ngã khi máy nằm trong túi quần: biên độ chỉ
        // tụt xuống khoảng 4-5 m/s² chứ không về gần 0 như lúc thả rơi máy.
        // Ngưỡng cũ 3.0 bỏ sót hoàn toàn ca này.
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            5.2f to 100L,
            4.4f to 150L,
            4.9f to 200L,
            27.5f to 260L,
            9.7f to 320L,
        )
        assertEquals(1, runSamples(detector, samples))
    }

    @Test
    fun `di lai binh thuong khong bi coi la nga`() {
        // Đáy mỗi bước chân có thể chạm 6.8 m/s², tức là LỌT vào pha rơi tự do
        // của ngưỡng 7.0 — thứ chặn lại là không có cú va đập >=19 ngay sau đó.
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            7.2f to 100L,
            12.5f to 200L,
            6.8f to 300L,
            13.1f to 400L,
            8.4f to 500L,
        )
        assertEquals(0, runSamples(detector, samples))
    }

    @Test
    fun `ngoi phich xuong ghe khong bi coi la nga`() {
        // Có pha nhẹ khi ngồi xuống nhưng va đập chỉ tầm 1.5g, dưới ngưỡng 19.
        // Đây là chốt chặn: hạ tiếp xuống 15 là ca này bắt đầu báo giả.
        val detector = FallDetector()
        val samples = listOf(
            9.8f to 0L,
            5.0f to 100L,
            4.8f to 180L,
            15.0f to 240L,
            9.8f to 300L,
        )
        assertEquals(0, runSamples(detector, samples))
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

    /// Cú ngã "mềm": rơi tự do chỉ tụt xuống 6.4-6.9 m/s², va đập ~20.5 m/s².
    private fun softFallPattern(start: Long = 0): List<Pair<Float, Long>> = listOf(
        9.8f to start,
        6.6f to start + 100,
        6.9f to start + 150,
        6.4f to start + 200,
        20.5f to start + 260,
        9.7f to start + 320,
    )
}
