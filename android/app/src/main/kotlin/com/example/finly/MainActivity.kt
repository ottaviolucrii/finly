package com.example.finly

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt of
// local_auth only works with it.
//
// The option that blocks screenshots lives here, on the phone: it is saved in
// the preferences of the app and applied when the screen is created, before the
// first frame is drawn, so the list of recent apps never shows the screens when
// the person chose to hide them.
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "finly/screen_protection"
    private val key = "block_screenshots"

    private val preferences by lazy {
        getSharedPreferences("finly_privacy", Context.MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        apply(preferences.getBoolean(key, false))

        // Android 13 and above: the list of recent apps never shows a picture of
        // the screen, so a balance is not seen by glancing at it. A cover drawn
        // by the app comes too late for the picture Android takes when the app
        // goes to the background, which is why it worked only sometimes.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(preferences.getBoolean(key, false))
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        preferences.edit().putBoolean(key, enabled).apply()
                        apply(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // FLAG_SECURE blocks screenshots and screen recording, and hides the
    // content in the list of recent apps.
    private fun apply(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}