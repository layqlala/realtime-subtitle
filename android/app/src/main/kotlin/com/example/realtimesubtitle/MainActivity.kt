package com.example.realtimesubtitle

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.realtimesubtitle/audio"
        private const val OVERLAY_CHANNEL = "com.example.realtimesubtitle/overlay"
        private const val REQUEST_MEDIA_PROJECTION = 1001

        var instance: MainActivity? = null // ponytail: Service→Activity桥接，非泄漏（Service寿命≤Activity）
    }

    private var pendingResult: MethodChannel.Result? = null
    private var audioEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCapture" -> {
                        pendingResult = result
                        requestMediaProjection()
                    }
                    "stopCapture" -> {
                        stopAudioCapture()
                        result.success(true)
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$CHANNEL/stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }
                override fun onCancel(args: Any?) {
                    audioEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverlay" -> {
                        showOverlay()
                        result.success(true)
                    }
                    "hideOverlay" -> {
                        hideOverlay()
                        result.success(true)
                    }
                    "updateSubtitle" -> {
                        val original = call.argument<String>("original") ?: ""
                        val translated = call.argument<String>("translated") ?: ""
                        updateSubtitle(original, translated)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestMediaProjection() {
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent) // 不需要等result，系统设置页直接跳转
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                startAudioCapture(resultCode, data)
                pendingResult?.success(true)
            } else {
                pendingResult?.error("PERMISSION_DENIED", "MediaProjection permission denied", null)
            }
            pendingResult = null
        }
    }

    private fun startAudioCapture(resultCode: Int, data: Intent) {
        val intent = Intent(this, AudioCaptureService::class.java).apply {
            putExtra("resultCode", resultCode)
            putExtra("data", data)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAudioCapture() {
        stopService(Intent(this, AudioCaptureService::class.java))
    }

    fun sendAudioData(bytes: ByteArray) {
        audioEventSink?.success(bytes)
    }

    fun sendCaptureError(error: String) {
        audioEventSink?.error("CAPTURE_ERROR", error, null)
    }

    private fun showOverlay() {
        AudioCaptureService.showOverlay(this)
    }

    private fun hideOverlay() {
        AudioCaptureService.hideOverlay(this)
    }

    private fun updateSubtitle(original: String, translated: String) {
        AudioCaptureService.updateSubtitle(original, translated)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
