package com.waysol.android_tv_remote_package.remote

import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*
import com.waysol.android_tv_remote_package.remote.KeyCode

class RemoteController(
    private val tlsManager: TLSManager
) {

    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val commandQueue = mutableListOf<RemoteCommand>()
    private var processingJob: Job? = null

    fun sendKeyCode(keycode: Int, delayMs: Long = 100): Boolean {
        return try {
            val message = ProtobufMessage.createKeycodeMessage(keycode)
            val result = tlsManager.sendData(message)

            scope.launch {
                delay(delayMs)
            }

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
            processingJob?.cancel()
            scope.cancel()
            commandQueue.clear()
        } catch (e: Exception) {
            Logger.e(Constants.TAG_REMOTE, "Destroy error: ${e.message}")
        }
    }
}

data class RemoteCommand(
    val type: CommandType,
    val keycode: Int = 0,
    val text: String = ""
)

enum class CommandType {
    KEYCODE, TEXT, MEDIA
}