package com.waysol.android_tv_remote_package.remote

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import com.waysol.android_tv_remote_package.util.Logger
import com.waysol.android_tv_remote_package.util.Constants
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.io.File

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
        private const val BUFFER_SIZE = 512 // 512 bytes for lower latency and stable packets
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
            Logger.i(Constants.TAG_REMOTE, "🎙️ AudioRecord initialized successfully")
            val hasAudioFeature = context.packageManager.hasSystemFeature("android.hardware.microphone")
            Logger.d(Constants.TAG_REMOTE, "Device has microphone: $hasAudioFeature")
            File(context.cacheDir, "voice.pcm").delete()


            audioRecord?.startRecording()
            isRecording = true
            Logger.i(Constants.TAG_REMOTE, "▶️ AudioRecord recording started")
            Logger.i(Constants.TAG_REMOTE, "🚀 Voice streaming session started")

            recordingExecutor = Executors.newSingleThreadExecutor()
            recordingExecutor?.submit {
                val buffer = ByteArray(BUFFER_SIZE)
                var noDataCount = 0
                val accumulationStream = ByteArrayOutputStream()

                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    Logger.d("VoiceDebug", "audioRecord.read() = $read")  // Add this!
                    Logger.d("VoiceDebug", "read=$read")  // What does read() return?


                    Logger.d(Constants.TAG_REMOTE, "AudioRecord.read() returned: $read")  // DEBUG
                    Logger.d("VoiceDebug", "read=$read")  // What does read() return?
                    if (read > 0) {
                        noDataCount = 0  // Reset counter
                        accumulationStream.write(buffer, 0, read)

                        // If we have accumulated at least 8192 bytes, send it
                        while (accumulationStream.size() >= 8192) {
                            val accumulatedBytes = accumulationStream.toByteArray()
                            val chunkSize = 8192
                            val chunkToSend = accumulatedBytes.copyOfRange(0, chunkSize)

                            Logger.i(
                                "VoiceDebug",
                                ">>> About to send voice chunk: size=${chunkToSend.size}, sessionId=$sessionId"
                            )
                            File(context.cacheDir, "voice.pcm").appendBytes(chunkToSend)
                            val success = remoteController.sendVoiceChunk(sessionId, chunkToSend)

                            Logger.i(
                                "VoiceDebug",
                                "<<< sendVoiceChunk() returned: $success"
                            )

                            Logger.d("VoiceDebug", "sendSuccess=$success")  // Did send work?

                            if (success) {
                                chunkCount++
                                totalBytesSent += chunkToSend.size
                                Logger.d(Constants.TAG_REMOTE, "📤 Voice chunk #$chunkCount transmitted (${chunkToSend.size} bytes)")
                            } else {
                                Logger.e(Constants.TAG_REMOTE, "❌ Connection lost during voice streaming")
                                break
                            }

                            // Retain remainder
                            accumulationStream.reset()
                            if (accumulatedBytes.size > chunkSize) {
                                accumulationStream.write(accumulatedBytes, chunkSize, accumulatedBytes.size - chunkSize)
                            }
                        }
                    } else if (read < 0) {
                        Logger.e(Constants.TAG_REMOTE, "❌ AudioRecord read error: $read")
                        break
                    } else {
                        // read == 0: No data available
                        noDataCount++
                        if (noDataCount > 100) {  // ~5 seconds with 50ms sleep
                            Logger.w(Constants.TAG_REMOTE, "⚠️ No audio data for 5 seconds, stopping")
                            break
                        }
                        Thread.sleep(50)  // Prevent busy loop
                    }
                }

                // Send remaining bytes padded to 8192 bytes if any exist
                if (accumulationStream.size() > 0) {
                    val remainingBytes = accumulationStream.toByteArray()
                    val padded = ByteArray(8192)
                    System.arraycopy(remainingBytes, 0, padded, 0, remainingBytes.size)

                    val success = remoteController.sendVoiceChunk(sessionId, padded)
                    if (success) {
                        chunkCount++
                        totalBytesSent += padded.size
                        Logger.d(Constants.TAG_REMOTE, "📤 Final padded Voice chunk #$chunkCount transmitted (${padded.size} bytes)")
                    } else {
                        Logger.e(Constants.TAG_REMOTE, "❌ Connection lost sending final voice chunk")
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
