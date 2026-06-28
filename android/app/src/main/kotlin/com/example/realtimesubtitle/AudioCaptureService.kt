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

        @Volatile
        private var overlayView: View? = null
        private var windowManager: WindowManager? = null
        private var originalText: TextView? = null
        private var translatedText: TextView? = null

        fun showOverlay(context: Context) {
            if (overlayView != null) return
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val layout = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.argb(140, 0, 0, 0)) // 半透明黑色底
                setPadding(24, 12, 24, 12)
            }

            originalText = TextView(context).apply {
                text = ""
                textSize = 16f
                setTextColor(Color.WHITE)
                isSingleLine = false
                maxLines = 2
            }
            translatedText = TextView(context).apply {
                text = ""
                textSize = 20f
                setTextColor(Color.YELLOW)
                isSingleLine = false
                maxLines = 2
            }

            layout.addView(originalText)
            layout.addView(translatedText)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                y = 150
            }

            overlayView = layout
            wm.addView(layout, params)
        }

        fun hideOverlay(context: Context) {
            overlayView?.let {
                windowManager?.removeView(it)
            }
            overlayView = null
            originalText = null
            translatedText = null
            windowManager = null
        }

        fun updateSubtitle(original: String, translated: String) {
            originalText?.post {
                originalText?.text = original
                translatedText?.text = translated
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
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val resultCode = intent.getIntExtra("resultCode", Activity.RESULT_CANCELED)
        val data = intent.getParcelableExtra<Intent>("data")
        if (resultCode == Activity.RESULT_OK && data != null) {
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

            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT
            )
            val bufferSize = maxOf(minBufferSize, BUFFER_SIZE)

            audioRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(config)
                .setAudioFormat(AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build())
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
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "字幕监听",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "实时字幕翻译运行中"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
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
