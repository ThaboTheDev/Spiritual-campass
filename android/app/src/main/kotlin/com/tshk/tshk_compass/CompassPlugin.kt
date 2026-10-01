package com.tshk.tshk_compass

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import kotlin.math.PI

/** OS fusion, with its north reference, timestamps and diagnostics preserved. */
class CompassPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler, SensorEventListener {
    companion object {
        /** Accuracy is a real fifth-element estimate, never a status proxy. */
        internal fun headingAccuracyDegrees(vector: FloatArray): Double? =
            vector.getOrNull(4)?.takeIf { it.isFinite() && it >= 0 }
                ?.let { it.toDouble() * 180.0 / PI }
    }

    private lateinit var manager: SensorManager
    private lateinit var events: EventChannel
    private lateinit var methods: MethodChannel
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private var orientation: Sensor? = null
    private val values = mutableMapOf<Int, FloatArray>()
    private val times = mutableMapOf<Int, Long>()
    private val accuracy = mutableMapOf<Int, Int>()
    private var lastEmitted = 0L
    private var periodMicros = 40000

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        manager = binding.applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        orientation = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: manager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        events = EventChannel(binding.binaryMessenger, "tshk/compass/events")
        methods = MethodChannel(binding.binaryMessenger, "tshk/compass/methods")
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(mapOf(
                    "absoluteOrientation" to (orientation != null),
                    "magnetometer" to (manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null),
                    "accelerometer" to (manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                    "gyroscope" to (manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null)
                ))
                "screenAngle" -> result.success(screenAngle())
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun screenAngle(): Double = when (activity?.windowManager?.defaultDisplay?.rotation) {
        Surface.ROTATION_90 -> -90.0
        Surface.ROTATION_180 -> -180.0
        Surface.ROTATION_270 -> -270.0
        else -> 0.0
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        stop()
        sink = eventSink
        val sensor = orientation
        if (sensor == null) {
            eventSink.error("NO_ABSOLUTE_SENSOR", "No absolute orientation sensor", null)
            return
        }
        periodMicros = ((arguments as? Map<*, *>)?.get("samplingMicros") as? Number)
            ?.toInt()?.coerceIn(20000, 200000) ?: 40000
        if (!manager.registerListener(this, sensor, periodMicros)) {
            eventSink.error("SENSOR_UNAVAILABLE", "Cannot register orientation sensor", null)
            stop()
            return
        }
        // Diagnostics are optional; a missing sensor is not replaced by zeroes.
        val gravityType = if (manager.getDefaultSensor(Sensor.TYPE_GRAVITY) != null)
            Sensor.TYPE_GRAVITY else Sensor.TYPE_ACCELEROMETER
        listOf(gravityType, Sensor.TYPE_MAGNETIC_FIELD, Sensor.TYPE_GYROSCOPE,
            Sensor.TYPE_LINEAR_ACCELERATION).forEach { type ->
            manager.getDefaultSensor(type)?.let { manager.registerListener(this, it, periodMicros) }
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val listener = sink ?: return
        val type = event.sensor.type
        if (type != orientation?.type) {
            values[type] = event.values.copyOf(3)
            times[type] = event.timestamp
            accuracy[type] = event.accuracy
            return
        }
        if (lastEmitted != 0L && event.timestamp - lastEmitted < periodMicros.toLong() * 1000) return
        lastEmitted = event.timestamp
        val matrix = FloatArray(9)
        try {
            // Some vendors reject a vector of length 5. Preserve element 4
            // separately: it is the real heading-error estimate in radians.
            SensorManager.getRotationMatrixFromVector(matrix, event.values.copyOf(minOf(4, event.values.size)))
        } catch (_: RuntimeException) {
            listener.error("INVALID_ROTATION", "Invalid rotation vector", null)
            return
        }
        val headingAccuracy = headingAccuracyDegrees(event.values)
        fun fresh(typeId: Int, maxAgeNanos: Long = 500000000L): List<Double>? {
            val at = times[typeId] ?: return null
            if (event.timestamp < at || event.timestamp - at > maxAgeNanos) return null
            return values[typeId]?.map { it.toDouble() }
        }
        val magnetic = fresh(Sensor.TYPE_MAGNETIC_FIELD, 1000000000L)
        val magneticStatus = accuracy[Sensor.TYPE_MAGNETIC_FIELD]
        val status = if (magnetic != null && magneticStatus != null)
            minOf(event.accuracy, magneticStatus) else event.accuracy
        listener.success(mapOf(
            "matrix" to matrix.map { it.toDouble() },
            "reference" to "magnetic",
            "screenAngle" to screenAngle(),
            "accuracy" to headingAccuracy,
            "reliability" to status,
            "timestampMs" to (System.currentTimeMillis() +
                (event.timestamp - SystemClock.elapsedRealtimeNanos()) / 1000000L),
            "magnetic" to magnetic,
            "gravity" to (fresh(Sensor.TYPE_GRAVITY) ?: fresh(Sensor.TYPE_ACCELEROMETER)),
            "linearAcceleration" to fresh(Sensor.TYPE_LINEAR_ACCELERATION),
            "gyro" to fresh(Sensor.TYPE_GYROSCOPE)
        ))
    }

    override fun onAccuracyChanged(sensor: Sensor, status: Int) {
        accuracy[sensor.type] = status
    }

    override fun onCancel(arguments: Any?) = stop()

    /** Native safety net when the activity stops before Dart has cancelled. */
    fun pauseSensors() = stop()

    private fun stop() {
        manager.unregisterListener(this)
        sink = null
        values.clear()
        times.clear()
        accuracy.clear()
        lastEmitted = 0L
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        events.setStreamHandler(null)
        methods.setMethodCallHandler(null)
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null; stop() }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null; stop() }
}
