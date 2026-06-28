package com.example.realtimesubtitle

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean

class AudioCaptureService : Service() {
    companion object {
        const val CHANNEL_ID = "audio_capture"
        const val NOTIFICATION_ID = 2001
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE = 4096

        private const val PLACEHOLDER_ORIGINAL = "等待识别..."
        private const val PLACEHOLDER_TRANSLATED = "实时字幕准备中"

        @Volatile
        private var overlayView: View? = null
        private var windowManager: WindowManager? = null
        private var originalTextView: TextView? = null
        private var translatedTextView: TextView? = null

        fun showOverlay(context: Context) {
            if (overlayView != null) {
                updateSubtitle(PLACEHOLDER_ORIGINAL, PLACEHOLDER_TRANSLATED)
                return
            }

            val appContext = context.applicationContext
            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val layout = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.TRANSPARENT)
                val hPad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 20f, appContext.resources.displayMetrics).toInt()
                val vPad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, appContext.resources.displayMetrics).toInt()
                setPadding(hPad, vPad, hPad, vPad)
            }

            originalTextView = TextView(appContext).apply {
                text = PLACEHOLDER_ORIGINAL
                textSize = 15f
                setTextColor(Color.WHITE)
                isSingleLine = false
                maxLines = 2
            }
            translatedTextView = TextView(appContext).apply {
                text = PLACEHOLDER_TRANSLATED
                textSize = 19f
                setTextColor(Color.WHITE)
                isSingleLine = false
                maxLines = 2
            }

            layout.addView(originalTextView)
            layout.addView(translatedTextView)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                y = 180
                horizontalMargin = 0.04f
            }

            overlayView = layout
            wm.addView(layout, params)
        }

        fun hideOverlay(context: Context) {
            val view = overlayView ?: return
            try {
                windowManager?.removeView(view)
            } catch (_: Throwable) {}
            overlayView = null
            originalTextView = null
            translatedTextView = null
            windowManager = null
        }

        fun updateSubtitle(original: String, translated: String) {
            val safeOriginal = original.ifBlank { PLACEHOLDER_ORIGINAL }
            val safeTranslated = translated.ifBlank { PLACEHOLDER_TRANSLATED }

            originalTextView?.post {
                originalTextView?.text = safeOriginal
                translatedTextView?.text = safeTranslated
            }
        }
    }

    private var isCapturing = AtomicBoolean(false)
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val resultCode = intent.getIntExtra("resultCode", Activity.RESULT_CANCELED)
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("data", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra("data")
        }

        if (resultCode == Activity.RESULT_OK && data != null) {
            showOverlay(this)
            startCapturing(resultCode, data)
        } else {
            MainActivity.instance?.sendCaptureError("Invalid MediaProjection data")
            stopSelf()
        }

        return START_STICKY
    }

    private fun startCapturing(resultCode: Int, data: Intent) {
        try {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = manager.getMediaProjection(resultCode, data)

            val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .build()

            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            val bufferSize = maxOf(minBufferSize, BUFFER_SIZE)

            audioRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(config)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AUDIO_FORMAT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(CHANNEL_CONFIG)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .build()

            audioRecord!!.startRecording()
            isCapturing.set(true)

            captureThread = Thread {
                val buffer = ByteArray(bufferSize)
                while (isCapturing.get()) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        val chunk = buffer.copyOf(read)
                        MainActivity.instance?.sendAudioData(chunk)
                    }
                }
            }
            captureThread!!.priority = Thread.MAX_PRIORITY
            captureThread!!.start()
        } catch (e: Exception) {
            MainActivity.instance?.sendCaptureError("Audio capture failed: ${e.message}")
            stopSelf()
        }
    }

    override fun onDestroy() {
        isCapturing.set(false)
        captureThread?.join(1000)
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        mediaProjection?.stop()
        mediaProjection = null
        hideOverlay(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "字幕监听", NotificationManager.IMPORTANCE_LOW).apply {
                description = "实时字幕翻译运行中"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("实时字幕")
            .setContentText("正在监听系统音频...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
