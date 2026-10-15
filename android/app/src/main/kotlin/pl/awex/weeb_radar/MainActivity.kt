package pl.awex.weeb_radar

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "weeb_radar/battery").setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoring" -> result.success(isIgnoring())
                "request" -> {
                    request()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoring(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    // Prosi system o zwolnienie z oszczędzania baterii, żeby codzienne
    // sprawdzanie w tle nie było ubijane (Motorola potrafi być surowa).
    @SuppressLint("BatteryLife")
    private fun request() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }
}
