package com.waysol.android_tv_remote_package.google_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger

class CastMethodHandler(
    context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.waysol.android_tv_remote_package/cast")
    private val castManager = CastManager.getInstance(context)

    init {
        channel.setMethodCallHandler(this)
        
        castManager.onDevicesUpdatedListener = { devices ->
            val mapped = devices.map { it.toMap() }
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("onDevicesUpdated", mapped)
            }
        }

        castManager.onStateChangedListener = { state ->
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("onStateChanged", state)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "discoverDevices" -> {
                castManager.discoveryManager.startDiscovery()
                result.success(mapOf("success" to true))
            }
            "stopDiscovery" -> {
                castManager.discoveryManager.stopDiscovery()
                result.success(mapOf("success" to true))
            }
            "connect" -> {
                val deviceId = call.arguments as? String
                if (deviceId != null) {
                    val success = castManager.sessionManager.connect(deviceId)
                    result.success(mapOf("success" to success))
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID cannot be null", null)
                }
            }
            "disconnect" -> {
                castManager.sessionManager.disconnect()
                result.success(mapOf("success" to true))
            }
            "castMedia" -> {
                val args = call.arguments as? Map<*, *>
                val url = args?.get("url") as? String
                if (url != null) {
                    val mimeType = args["mimeType"] as? String
                    val title = args["title"] as? String
                    val subtitle = args["subtitle"] as? String
                    val artworkUrl = args["artworkUrl"] as? String
                    val duration = (args["duration"] as? Number)?.toLong()

                    val errorCode = castManager.mediaManager.castMedia(
                        url = url,
                        mimeType = mimeType,
                        title = title,
                        subtitle = subtitle,
                        artworkUrl = artworkUrl,
                        duration = duration
                    )

                    if (errorCode == null) {
                        result.success(mapOf("success" to true))
                    } else {
                        result.error(errorCode, "Failed to load media payload", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Media URL cannot be null", null)
                }
            }
            "play" -> {
                castManager.mediaManager.play()
                result.success(mapOf("success" to true))
            }
            "pause" -> {
                castManager.mediaManager.pause()
                result.success(mapOf("success" to true))
            }
            "stop" -> {
                castManager.mediaManager.stop()
                result.success(mapOf("success" to true))
            }
            "seek" -> {
                val positionMs = (call.arguments as? Number)?.toLong()
                if (positionMs != null) {
                    castManager.mediaManager.seek(positionMs)
                    result.success(mapOf("success" to true))
                } else {
                    result.error("INVALID_ARGUMENT", "Position cannot be null", null)
                }
            }
            "setVolume" -> {
                val volume = (call.arguments as? Number)?.toDouble()
                if (volume != null) {
                    castManager.mediaManager.setVolume(volume)
                    result.success(mapOf("success" to true))
                } else {
                    result.error("INVALID_ARGUMENT", "Volume cannot be null", null)
                }
            }
            "getSessionState" -> {
                val state = castManager.sessionManager.getSessionStateName()
                result.success(mapOf("success" to true, "state" to state))
            }
            else -> result.notImplemented()
        }
    }
}
