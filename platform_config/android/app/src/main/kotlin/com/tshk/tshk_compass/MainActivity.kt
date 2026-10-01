package com.tshk.tshk_compass

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var compass: CompassPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = flutterEngine.plugins.get(CompassPlugin::class.java) as? CompassPlugin
            ?: CompassPlugin().also { flutterEngine.plugins.add(it) }
        compass = plugin
    }

    override fun onStop() {
        compass?.pauseSensors()
        super.onStop()
    }
}
