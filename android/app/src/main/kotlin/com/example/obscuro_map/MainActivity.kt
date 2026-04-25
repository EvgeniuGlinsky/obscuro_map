package com.example.obscuro_map

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    ensureNotificationPermission()
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(this, intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_STOP
                    }
                    // Use startForegroundService on O+ so the service can
                    // satisfy the startForeground-within-5s contract during
                    // its short-lived stop path even if the app is in the
                    // background. stopService alone would not deliver
                    // ACTION_STOP to onStartCommand.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(this, intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Single trigger: when the user brings the app to the foreground and
        // the service is already alive, ask it to re-assert its foreground
        // notification. Gated on isRunning() so this can never spawn a
        // service. Inside the service this just re-calls startForeground()
        // with the same id — idempotent, no duplicate notification, no
        // lifecycle change.
        if (!LocationForegroundService.isRunning()) return
        val intent = Intent(this, LocationForegroundService::class.java).apply {
            action = LocationForegroundService.ACTION_ENSURE_NOTIFICATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val perm = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) return
        requestPermissions(arrayOf(perm), REQ_POST_NOTIFICATIONS)
    }

    companion object {
        // Mirror of the Dart-side platform channel name in
        // lib/core/constants/platform_channels.dart. Keep both sides in sync.
        private const val CHANNEL_NAME = "obscuro_map/foreground_service"
        private const val REQ_POST_NOTIFICATIONS = 4711
    }
}
