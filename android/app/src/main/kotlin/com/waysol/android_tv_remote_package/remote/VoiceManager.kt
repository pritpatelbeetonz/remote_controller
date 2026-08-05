package com.waysol.android_tv_remote_package.remote

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import com.waysol.android_tv_remote_package.util.Logger
import com.waysol.android_tv_remote_package.util.Constants
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class VoiceManager(
    private val context: Context,
    private val remoteController: RemoteController
) {
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingExecutor: ExecutorService? = null

    // Session stats
    private var chunkCount = 0
    private var totalBytesSent = 0

    companion object {
        private const val SAMPLE_RATE = 8000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE = 8192 // 8 KB
    }

    @SuppressLint("MissingPermission")
    fun startRecording(sessionId: Int): Boolean {
        if (isRecording) return true
        
        chunkCount = 0
        totalBytesSent = 0

        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        val recordingBufferSize = Math.max(minBufferSize, BUFFER_SIZE)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                recordingBufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Logger.e(Constants.TAG_REMOTE, "❌ AudioRecord initialization failed")
                return false
            }

            Logger.i(Constants.TAG_REMOTE, "🎙️ AudioRecord initialized successfully")
            
            audioRecord?.startRecording()
            isRecording = true
            Logger.i(Constants.TAG_REMOTE, "▶️ AudioRecord recording started")
            Logger.i(Constants.TAG_REMOTE, "🚀 Voice streaming session started")

            recordingExecutor = Executors.newSingleThreadExecutor()
            recordingExecutor?.submit {
                val buffer = ByteArray(BUFFER_SIZE)
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        val dataToSend = if (read < buffer.size) {
                            // Pad with zeros to 8KB
                            val padded = ByteArray(buffer.size)
                            System.arraycopy(buffer, 0, padded, 0, read)
                            padded
                        } else {
                            buffer.clone()
                        }

                        val success = remoteController.sendVoicePayload(sessionId, dataToSend)
                        if (success) {
                            chunkCount++
                            totalBytesSent += dataToSend.size
                            Logger.d(Constants.TAG_REMOTE, "📤 Voice chunk #$chunkCount transmitted (${dataToSend.size} bytes)")
                        } else {
                            Logger.e(Constants.TAG_REMOTE, "❌ Connection lost during voice streaming")
                            break
                        }
                    } else if (read < 0) {
                        Logger.e(Constants.TAG_REMOTE, "❌ AudioRecord read error: $read")
                        break
                    }
                }
            }
            return true
        } catch (e: SecurityException) {
            Logger.e(Constants.TAG_REMOTE, "❌ Permission denied for microphone recording", e)
            return false
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "❌ Unexpected voice session error: ${e.message}", e)
            return false
        }
    }

    fun stopRecording() {
        if (!isRecording) return
        isRecording = false

        try {
            audioRecord?.stop()
            Logger.i(Constants.TAG_REMOTE, "⏹️ AudioRecord recording stopped")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "❌ Error stopping AudioRecord: ${e.message}", e)
        }

        try {
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "❌ Error releasing AudioRecord: ${e.message}", e)
        }

        recordingExecutor?.shutdownNow()
        recordingExecutor = null

        Logger.i(Constants.TAG_REMOTE, "🏁 Voice streaming stopped")
        Logger.i(Constants.TAG_REMOTE, "📊 Total chunks sent: $chunkCount, Total bytes sent: $totalBytesSent")
        Logger.i(Constants.TAG_REMOTE, "✅ Voice session completed successfully")
    }
}
