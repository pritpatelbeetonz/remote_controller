package com.waysol.android_tv_remote_package.remote

import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.protocol.MessageParser
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*

class RemoteController(
    private val tlsManager: TLSManager
) {

    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var listeningJob: Job? = null

    init {
        startListening()
    }

    private fun startListening() {
        listeningJob = scope.launch(Dispatchers.IO) {
            try {
                Logger.d(Constants.TAG_REMOTE, "Starting background socket reading loop...")
                while (isActive && tlsManager.isConnected()) {
                    val data = tlsManager.receiveData() ?: break
                    
                    // 1. Handle Ping request
                    val pingVal = MessageParser.extractPingVal(data)
                    if (pingVal != null) {
                        Logger.d(Constants.TAG_REMOTE, "Received Ping Request ($pingVal). Replying with Pong...")
                        val pong = ProtobufMessage.createPongMessage(pingVal)
                        tlsManager.sendData(pong)
                        continue
                    }

                    // 2. Handle Configure request (Startup features handshake)
                    if (MessageParser.isConfigureRequest(data)) {
                        Logger.d(Constants.TAG_REMOTE, "Received Configure Request. Replying with client capabilities...")
                        val configResponse = ProtobufMessage.createConfigureResponse()
                        tlsManager.sendData(configResponse)
                        continue
                    }

                    // 3. Handle Set Active request
                    if (MessageParser.isSetActiveRequest(data)) {
                        Logger.d(Constants.TAG_REMOTE, "Received Set Active Request. Replying with active status...")
                        val activeResponse = ProtobufMessage.createActiveResponse()
                        tlsManager.sendData(activeResponse)
                        continue
                    }

                    Logger.d(Constants.TAG_REMOTE, "Received other control message from TV (size: ${data.size})")
                }
            } catch (e: Exception) {
                Logger.e(Constants.TAG_REMOTE, "Socket reading loop exception: ${e.message}", e)
            } finally {
                Logger.i(Constants.TAG_REMOTE, "Socket reading loop stopped.")
            }
        }
    }

    fun sendKeyCode(keycode: Int, delayMs: Long = 100): Boolean {
        return try {
            // Direction 3 = SHORT press (combines down and up automatically)
            val message = ProtobufMessage.createKeycodeMessage(keycode, 3)
            val result = tlsManager.sendData(message)

            if (result) {
                Logger.d(Constants.TAG_REMOTE, "Keycode sent: $keycode")
            }
            result
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Send keycode error: ${e.message}")
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
        return try {
            for (char in text.uppercase()) {
                val keycode = when (char) {
                    in 'A'..'Z' -> KeyCode.A + (char - 'A')
                    in '0'..'9' -> KeyCode.NUM_0 + (char - '0')
                    else -> continue
                }
                sendKeyCode(keycode, 50)
            }
            true
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Send text error: ${e.message}")
            false
        }
    }

    fun sendAppLink(appLink: String): Boolean {
        return try {
            val message = ProtobufMessage.createAppLinkMessage(appLink)
            val result = tlsManager.sendData(message)
            if (result) {
                Logger.d(Constants.TAG_REMOTE, "App link sent: $appLink")
            }
            result
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Send app link error: ${e.message}")
            false
        }
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