package com.tshk.tshk_compass

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CompassPluginTest {
    @Test
    fun missingOrUnavailableAccuracyIsNotAnInventedStatusBound() {
        assertNull(CompassPlugin.headingAccuracyDegrees(floatArrayOf(0f, 0f, 0f)))
        assertNull(CompassPlugin.headingAccuracyDegrees(floatArrayOf(0f, 0f, 0f, 1f, -1f)))
        assertNull(CompassPlugin.headingAccuracyDegrees(floatArrayOf(0f, 0f, 0f, 1f, Float.NaN)))
        assertNull(CompassPlugin.headingAccuracyDegrees(floatArrayOf(0f, 0f, 0f, 1f, Float.POSITIVE_INFINITY)))
    }

    @Test
    fun genuineFifthElementIsConvertedFromRadiansToDegrees() {
        val vector = floatArrayOf(0f, 0f, 0f, 1f, (Math.PI / 18).toFloat())
        assertEquals(10.0, CompassPlugin.headingAccuracyDegrees(vector)!!, 0.00001)
        // Preserve the OS value at the boundary. Dart treats zero as unknown,
        // never as evidence of a physically perfect compass.
        assertEquals(0.0, CompassPlugin.headingAccuracyDegrees(floatArrayOf(0f, 0f, 0f, 1f, 0f))!!, 0.0)
    }
}
