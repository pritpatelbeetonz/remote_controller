package com.waysol.android_tv_remote_package.remote

import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.protocol.MessageParser
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*

class RemoteController(
    val tlsManager: TLSManager
) {

    enum class KeyboardState {
        READY,
        NOT_SUPPORTED,
        NO_TEXT_FIELD,
        CONNECTION_LOST,
        UNKNOWN
    }

    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var listeningJob: Job? = null

    var onDisconnected: (() -> Unit)? = null
    var onReady: (() -> Unit)? = null
    var onVoiceBegin: ((Int) -> Unit)? = null
    private var tvSupportedFeatures: Int = 0

    private var imeCounter: Int = 0
    private var imeFieldCounter: Int = 0
    private var isTextFieldFocused: Boolean = false
    private var voicePayloadWireDumped: Boolean = false

    fun isConnected(): Boolean {
        return tlsManager.isConnected()
    }

    fun isVoiceSupported(): Boolean {
        return (tvSupportedFeatures and 8) != 0
    }

    fun isKeyboardSupported(): Boolean {
        return (tvSupportedFeatures and 4) != 0
    }

    fun isTextFieldFocused(): Boolean {
        return isTextFieldFocused
    }

    fun getKeyboardState(): KeyboardState {
        if (!isConnected()) {
            return KeyboardState.CONNECTION_LOST
        }
        if (!isKeyboardSupported()) {
            return KeyboardState.NOT_SUPPORTED
        }
        return if (isTextFieldFocused) {
            KeyboardState.READY
        } else {
            KeyboardState.NO_TEXT_FIELD
        }
    }

    fun start() {
        startListening()
    }

    private fun startListening() {
        listeningJob = scope.launch(Dispatchers.IO) {
            Logger.d(Constants.TAG_REMOTE, "Starting background socket reading loop...")
            try {
                while (isActive && tlsManager.isConnected()) {
                    val data = try {
                        tlsManager.receiveData()
                    } catch (e: java.net.SocketTimeoutException) {
                        // Expected during idle/keep-alive polling — just loop again
                        continue
                    } catch (e: java.net.SocketException) {
                        Logger.e(
                            Constants.TAG_REMOTE,
                            "Socket closed by peer, stopping listener",
                            e
                        )
                        break
                    } catch (e: Exception) {
                        Logger.e(
                            Constants.TAG_REMOTE,
                            "Unexpected receive error, stopping listener",
                            e
                        )
                        break
                    }

                    if (data == null) break

                    // 1. Handle Ping request
                    val pingVal = MessageParser.extractPingVal(data)
                    if (pingVal != null) {
                        Logger.d(
                            Constants.TAG_REMOTE,
                            "Received Ping Request ($pingVal). Replying with Pong..."
                        )
                        val pong = ProtobufMessage.createPongMessage(pingVal)
                        tlsManager.sendData(pong)
                        continue
                    }

                    // 2. Handle Configure request
                    if (MessageParser.isConfigureRequest(data)) {
                        Logger.d(
                            Constants.TAG_REMOTE,
                            "Received Configure Request. Replying with client capabilities..."
                        )
                        val features = MessageParser.parseConfigureFeatures(data)
                        if (features != null) {
                            tvSupportedFeatures = features
                            Logger.i(
                                Constants.TAG_REMOTE,
                                "TV advertised supported features: $features (voice supported: ${isVoiceSupported()})"
                            )
                        }
                        tlsManager.sendData(ProtobufMessage.createConfigureResponse())
                        continue
                    }

                    // 3. Handle Set Active request
                    if (MessageParser.isSetActiveRequest(data)) {
                        Logger.d(
                            Constants.TAG_REMOTE,
                            "Received Set Active Request. Replying with active status..."
                        )
                        tlsManager.sendData(ProtobufMessage.createActiveResponse())
                        onReady?.invoke()
                        continue
                    }

                    // 4. Handle Voice Begin request
                    val voiceSessionId = MessageParser.extractVoiceBeginSessionId(data)
                    if (voiceSessionId != null) {
                        Logger.i(Constants.TAG_REMOTE, "📥 Received RemoteVoiceBegin session ID: $voiceSessionId")
                        onVoiceBegin?.invoke(voiceSessionId)
                        continue
                    }

                    // 5. Handle Voice End request
                    val voiceEndSessionId = MessageParser.extractVoiceEndSessionId(data)
                    if (voiceEndSessionId != null) {
                        Logger.i(Constants.TAG_REMOTE, "📥 Received RemoteVoiceEnd session ID: $voiceEndSessionId")
                        continue
                    }

                    // 6. Handle IME Batch Edit (field 21) from TV to update counters
                    val counters = MessageParser.extractImeCounters(data)
                    if (counters != null) {
                        imeCounter = counters.imeCounter
                        imeFieldCounter = counters.fieldCounter
                        isTextFieldFocused = true
                        Logger.i(Constants.TAG_REMOTE, "⌨️ Received IME Batch Edit. Updated counters: ime_counter=$imeCounter, field_counter=$imeFieldCounter")
                        continue
                    }

                    // 7. Handle IME Show Request (field 22) from TV to track focus
                    val focusState = MessageParser.parseImeShowRequest(data)
                    if (focusState != null) {
                        isTextFieldFocused = focusState.isFocused
                        Logger.i(Constants.TAG_REMOTE, "⌨️ Keyboard Show Request received. isFocused=$isTextFieldFocused, text=\"${focusState.text}\"")
                        continue
                    }

                    Logger.d(
                        Constants.TAG_REMOTE,
                        "Received other control message from TV (size: ${data.size}): ${
                            data.joinToString(",") { (it.toInt() and 0xFF).toString() }
                        }"
                    )
                }
            } catch (e: Exception) {
                Logger.e(Constants.TAG_REMOTE, "Socket reading loop exception: ${e.message}", e)
            } finally {
                Logger.i(Constants.TAG_REMOTE, "Socket reading loop stopped.")
                onDisconnected?.invoke()   // see note below
            }
        }
    }

    private fun getKeyName(keycode: Int): String {
        return when (keycode) {
            KeyCode.DPAD_UP -> "UP"
            KeyCode.DPAD_DOWN -> "DOWN"
            KeyCode.DPAD_LEFT -> "LEFT"
            KeyCode.DPAD_RIGHT -> "RIGHT"
            KeyCode.DPAD_CENTER -> "SELECT"
            KeyCode.HOME -> "HOME"
            KeyCode.BACK -> "BACK"
            KeyCode.MEDIA_PLAY_PAUSE -> "PLAY_PAUSE"
            KeyCode.MEDIA_PLAY -> "PLAY"
            KeyCode.MEDIA_PAUSE -> "PAUSE"
            KeyCode.VOLUME_UP -> "VOLUME_UP"
            KeyCode.VOLUME_DOWN -> "VOLUME_DOWN"
            KeyCode.VOLUME_MUTE -> "VOLUME_MUTE"
            else -> "KEYCODE_$keycode"
        }
    }

    fun sendKeyCode(keycode: Int, delayMs: Long = 100): Boolean {
        val keyName = getKeyName(keycode)
        Logger.i(Constants.TAG_COMMAND, "Sending command: $keyName")
        val startTime = System.currentTimeMillis()
        return try {
            // Direction 3 = SHORT press (combines down and up automatically)
            val message = ProtobufMessage.createKeycodeMessage(keycode, 3)
            val result = tlsManager.sendData(message)
            val latency = System.currentTimeMillis() - startTime

            if (result) {
                Logger.i(
                    Constants.TAG_COMMAND,
                    "Command $keyName sent successfully\nLatency: $latency ms\nResult: Success"
                )
            } else {
                Logger.e(
                    Constants.TAG_COMMAND,
                    "Command $keyName failed to send\nLatency: $latency ms\nResult: Failure"
                )
            }
            result
        } catch (e: Exception) {
            val latency = System.currentTimeMillis() - startTime
            Logger.e(
                Constants.TAG_COMMAND,
                "Command $keyName failed to send\nLatency: $latency ms\nResult: Failure",
                e
            )
            false
        }
    }

    // Navigation commands
    fun sendDpadUp() = sendKeyCode(KeyCode.DPAD_UP)
    fun sendDpadDown() = sendKeyCode(KeyCode.DPAD_DOWN)
    fun sendDpadLeft() = sendKeyCode(KeyCode.DPAD_LEFT)
    fun sendDpadRight() = sendKeyCode(KeyCode.DPAD_RIGHT)
    fun sendDpadCenter() = sendKeyCode(KeyCode.DPAD_CENTER)

    // Control commands
    fun sendHome() = sendKeyCode(KeyCode.HOME)
    fun sendBack() = sendKeyCode(KeyCode.BACK)
    fun sendMenu() = sendKeyCode(KeyCode.MENU)

    // Media commands
    fun sendPlayPause() = sendKeyCode(KeyCode.MEDIA_PLAY_PAUSE)
    fun sendPlay() = sendKeyCode(KeyCode.MEDIA_PLAY)
    fun sendPause() = sendKeyCode(KeyCode.MEDIA_PAUSE)
    fun sendNext() = sendKeyCode(KeyCode.MEDIA_NEXT)
    fun sendPrevious() = sendKeyCode(KeyCode.MEDIA_PREVIOUS)

    // Volume commands
    fun sendVolumeUp() = sendKeyCode(KeyCode.VOLUME_UP)
    fun sendVolumeDown() = sendKeyCode(KeyCode.VOLUME_DOWN)
    fun sendVolumeMute() = sendKeyCode(KeyCode.VOLUME_MUTE)

    // Channel commands
    fun sendChannelUp() = sendKeyCode(KeyCode.CHANNEL_UP)
    fun sendChannelDown() = sendKeyCode(KeyCode.CHANNEL_DOWN)

    // Text input
    fun sendText(text: String): Boolean {
        Logger.i(Constants.TAG_COMMAND, "⌨️ Sending IME text: \"$text\"")
        if (!isKeyboardSupported()) {
            Logger.w(Constants.TAG_COMMAND, "❌ TV does not support IME input method")
            return false
        }
        return try {
            val message = ProtobufMessage.createImeBatchEditMessage(imeCounter, imeFieldCounter, text)
            val result = tlsManager.sendData(message)
            if (result) {
                Logger.i(Constants.TAG_COMMAND, "✅ Transmitted IME message: \"$text\" (size: ${text.length})")
            } else {
                Logger.e(Constants.TAG_COMMAND, "❌ Failed to transmit IME message: \"$text\"")
            }
            result
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Send text error: ${e.message}")
            false
        }
    }

    fun sendAppLink(appLink: String): Boolean {
        Logger.i(Constants.TAG_COMMAND, "Sending command: LAUNCH_APP ($appLink)")
        val startTime = System.currentTimeMillis()
        return try {
            val message = ProtobufMessage.createAppLinkMessage(appLink)
            val result = tlsManager.sendData(message)
            val latency = System.currentTimeMillis() - startTime
            if (result) {
                Logger.i(
                    Constants.TAG_COMMAND,
                    "Command LAUNCH_APP sent successfully\nLatency: $latency ms\nResult: Success"
                )
            } else {
                Logger.e(
                    Constants.TAG_COMMAND,
                    "Command LAUNCH_APP failed to send\nLatency: $latency ms\nResult: Failure"
                )
            }
            result
        } catch (e: Exception) {
            val latency = System.currentTimeMillis() - startTime
            Logger.e(
                Constants.TAG_COMMAND,
                "Command LAUNCH_APP failed to send\nLatency: $latency ms\nResult: Failure",
                e
            )
            false
        }
    }
    fun sendVoiceBegin(sessionId: Int): Boolean {
        Logger.i(Constants.TAG_COMMAND, "📤 Sending RemoteVoiceBegin for session $sessionId")
        val message = ProtobufMessage.createVoiceBeginMessage(sessionId)
        return tlsManager.sendData(message)
    }

    fun sendVoicePayload(sessionId: Int, samples: ByteArray): Boolean {
        val message = ProtobufMessage.createVoicePayloadMessage(sessionId, samples)
        if (!voicePayloadWireDumped) {
            ProtobufMessage.logVoicePayloadWireFormat(sessionId, samples, message)
            voicePayloadWireDumped = true
        }

        Log.d("VoicePayload", "Sending ${message.size} bytes to TLSManager")
        val result = tlsManager.sendData(message)
        Log.d("VoicePayload", "tlsManager.sendData returned: $result")

        return result
    }
    fun sendVoiceChunk(sessionId: Int, samples: ByteArray): Boolean {
        var chunk = samples
        val minSize = 8192
        val maxSize = 20480

        // 1. Pad chunk to minimum size (8 KB) if it's smaller
        if (chunk.size < minSize) {
            val padded = ByteArray(minSize)
            System.arraycopy(chunk, 0, padded, 0, chunk.size)
            chunk = padded
        }

        // 2. Limit chunk size and send in loop
        var success = true
        var i = 0
        while (i < chunk.size) {
            val end = Math.min(chunk.size, i + maxSize)
            val slice = chunk.copyOfRange(i, end)
            if (!sendVoicePayload(sessionId, slice)) {
                success = false
            }
            i += maxSize
        }
        return success
    }

    fun sendVoiceEnd(sessionId: Int): Boolean {
        Logger.i(Constants.TAG_COMMAND, "📤 Sending RemoteVoiceEnd for session $sessionId")

        val message = ProtobufMessage.createVoiceEndMessage(sessionId)

        val success = tlsManager.sendData(message)

        Logger.i(Constants.TAG_COMMAND, "📤 RemoteVoiceEnd send result = $success")

        return success
    }
    fun destroy() {
        try {
            listeningJob?.cancel()
            scope.cancel()
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Destroy error: ${e.message}")
        }
    }
}
