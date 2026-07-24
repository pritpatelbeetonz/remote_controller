package com.waysol.android_tv_remote_package

import android.content.Context
import android.net.nsd.NsdManager
import android.util.Log
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.waysol.android_tv_remote_package.cert.CertificateGenerator
import com.waysol.android_tv_remote_package.cert.CertificateManager
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.discovery.DeviceScanner
import com.waysol.android_tv_remote_package.pairing.PairingManager
import com.waysol.android_tv_remote_package.pairing.PairingStatus
import com.waysol.android_tv_remote_package.remote.RemoteController
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel

class AndroidTVRemotePlugin(
    private val context: Context
) {

    companion object {
        private const val CHANNEL = "com.waysol.android_tv_remote_package/method"
        private const val EVENT_CHANNEL = "com.waysol.android_tv_remote_package/event"
        private const val TAG = "AndroidTVRemote"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var eventSink: EventChannel.EventSink? = null

    // Service instances
    private var certificateGenerator: CertificateGenerator? = null
    private var certificateManager: CertificateManager? = null
    private var deviceScanner: DeviceScanner? = null
    private var tlsManager: TLSManager? = null
    private var pairingManager: PairingManager? = null
    private var remoteController: RemoteController? = null

    fun setupChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        )

        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call.method, call.arguments, result)
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Logger.i(Constants.TAG_PLUGIN, "EventChannel log stream listener subscribed")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Logger.i(Constants.TAG_PLUGIN, "EventChannel log stream listener cancelled")
            }
        })

        // Route all Logger statements to the Flutter UI EventChannel
        Logger.addListener { level, tag, message ->
            eventSink?.let { sink ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        sink.success(mapOf(
                            "level" to level,
                            "tag" to tag,
                            "message" to message,
                            "timestamp" to System.currentTimeMillis()
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "Error piping log to EventChannel: ${e.message}")
                    }
                }
            }
        }
    }

    private fun handleMethodCall(
        method: String,
        arguments: Any?,
        result: MethodChannel.Result
    ) {
        Logger.i(Constants.TAG_PLUGIN, "MethodChannel invocation: method=$method, args=$arguments")
        val startTime = System.currentTimeMillis()

        val wrappedResult = object : MethodChannel.Result {
            override fun success(res: Any?) {
                val elapsed = System.currentTimeMillis() - startTime
                Logger.i(Constants.TAG_PLUGIN, "MethodChannel SUCCESS: method=$method, elapsed=${elapsed}ms")
                result.success(res)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                val elapsed = System.currentTimeMillis() - startTime
                Logger.e(Constants.TAG_PLUGIN, "MethodChannel ERROR: method=$method, code=$errorCode, msg=$errorMessage, elapsed=${elapsed}ms")
                result.error(errorCode, errorMessage, errorDetails)
            }

            override fun notImplemented() {
                val elapsed = System.currentTimeMillis() - startTime
                Logger.w(Constants.TAG_PLUGIN, "MethodChannel NOT IMPLEMENTED: method=$method, elapsed=${elapsed}ms")
                result.notImplemented()
            }
        }

        when (method) {
            "generateCertificates" -> generateCertificates(wrappedResult)
            "startDiscovery" -> startDiscovery(wrappedResult)
            "connect" -> connect(arguments as Map<String, Any>, wrappedResult)
            "startPairing" -> startPairing(wrappedResult)
            "sendPin" -> sendPin(arguments as String, wrappedResult)
            "sendCommand" -> sendCommand(arguments as Map<String, Any>, wrappedResult)
            "disconnect" -> disconnect(wrappedResult)
            else -> wrappedResult.notImplemented()
        }
    }

    private fun generateCertificates(result: MethodChannel.Result) {
        try {
            Logger.d(Constants.TAG_PLUGIN, "Certificate generation requested")
            certificateGenerator = CertificateGenerator()
            val certResult = certificateGenerator!!.generateCertificates(context)

            if (certResult.success) {
                Logger.i(Constants.TAG_PLUGIN, "Certificates generated successfully. DER: ${certResult.derPath}, PKCS12: ${certResult.pkcs12Path}")
                certificateManager = CertificateManager(context)
                result.success(mapOf(
                    "success" to true,
                    "derPath" to certResult.derPath,
                    "pkcs12Path" to certResult.pkcs12Path
                ))
            } else {
                Logger.e(Constants.TAG_PLUGIN, "Certificates generation failed: ${certResult.error}")
                result.error("CERT_ERROR", certResult.error, null)
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during certificate generation", e)
            result.error("CERT_ERROR", e.message, null)
        }
    }

    private fun startDiscovery(result: MethodChannel.Result) {
        try {
            Logger.d(Constants.TAG_PLUGIN, "mDNS TV discovery requested")
            val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
            deviceScanner = DeviceScanner(context, nsdManager)

            deviceScanner?.startDiscovery(timeout = Constants.DISCOVERY_TIMEOUT_MS) { devices ->
                val deviceList = devices.map {
                    mapOf(
                        "name" to it.name,
                        "ipAddress" to it.ipAddress,
                        "port" to it.port,
                        "hostname" to it.hostname
                    )
                }
                Logger.i(Constants.TAG_PLUGIN, "Discovered ${devices.size} device(s), notifying Flutter")
                Handler(Looper.getMainLooper()).post {
                    methodChannel.invokeMethod("devicesDiscovered", deviceList)
                }
            }

            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during discovery start", e)
            result.error("DISCOVERY_ERROR", e.message, null)
        }
    }

    private fun connect(arguments: Map<String, Any>, result: MethodChannel.Result) {
        try {
            val host = arguments["host"] as String
            val port = arguments["port"] as Int
            val pkcs12Path = arguments["pkcs12Path"] as String
            Logger.d(Constants.TAG_PLUGIN, "Connection requested to host=$host, port=$port, cert=$pkcs12Path")

            if (certificateManager == null) {
                certificateManager = CertificateManager(context)
            }

            val sslContext = certificateManager?.createSSLContext(
                pkcs12Path = pkcs12Path,
                password = arguments["password"] as? String ?: ""
            ) ?: throw Exception("SSL context creation failed")

            tlsManager = TLSManager(sslContext)

            if (tlsManager?.connect(host, port) == true) {
                Logger.i(Constants.TAG_PLUGIN, "TLS Connection successfully established with $host:$port")
                pairingManager = PairingManager(tlsManager!!)
                result.success(mapOf("success" to true))
            } else {
                Logger.e(Constants.TAG_PLUGIN, "TLS Connection failed with $host:$port")
                result.error("CONNECTION_ERROR", "Failed to establish TLS connection", null)
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during connect", e)
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }

    private fun startPairing(result: MethodChannel.Result) {
        try {
            Logger.d(Constants.TAG_PLUGIN, "Polo pairing session start requested")
            if (pairingManager == null) {
                throw Exception("PairingManager is not initialized. Connect to a device first.")
            }
            pairingManager?.startPairing(
                onStatusChange = { status ->
                    Logger.i(Constants.TAG_PLUGIN, "Pairing status changed: ${status.name}")
                    Handler(Looper.getMainLooper()).post {
                        methodChannel.invokeMethod("pairingStatusChanged", status.name)
                    }
                },
                onPinDisplay = { pin ->
                    Logger.i(Constants.TAG_PLUGIN, "Pairing PIN displayed/received: $pin")
                    Handler(Looper.getMainLooper()).post {
                        methodChannel.invokeMethod("pinReceived", pin)
                    }
                }
            )
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during startPairing", e)
            result.error("PAIRING_ERROR", e.message, null)
        }
    }

    private fun sendPin(pin: String, result: MethodChannel.Result) {
        try {
            Logger.d(Constants.TAG_PLUGIN, "Submitting PIN for verification: $pin")
            if (pairingManager == null) {
                throw Exception("PairingManager is not initialized.")
            }
            if (pairingManager?.sendPin(pin) == true) {
                Logger.i(Constants.TAG_PLUGIN, "PIN submitted. Initializing RemoteController session.")
                remoteController = RemoteController(tlsManager!!)
                result.success(mapOf("success" to true))
            } else {
                Logger.e(Constants.TAG_PLUGIN, "Failed to submit PIN")
                result.error("PAIRING_ERROR", "Failed to send PIN", null)
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during sendPin", e)
            result.error("PAIRING_ERROR", e.message, null)
        }
    }

    private fun sendCommand(arguments: Map<String, Any>, result: MethodChannel.Result) {
        try {
            val command = arguments["command"] as String
            Logger.d(Constants.TAG_PLUGIN, "Remote Command requested: $command")
            if (remoteController == null) {
                if (tlsManager != null && tlsManager!!.isConnected()) {
                    Logger.i(Constants.TAG_PLUGIN, "RemoteController was null but socket is connected. Initializing RemoteController.")
                    remoteController = RemoteController(tlsManager!!)
                } else {
                    throw Exception("Remote session is not connected.")
                }
            }
            val success = when (command) {
                "dpad_up" -> remoteController?.sendDpadUp() ?: false
                "dpad_down" -> remoteController?.sendDpadDown() ?: false
                "dpad_left" -> remoteController?.sendDpadLeft() ?: false
                "dpad_right" -> remoteController?.sendDpadRight() ?: false
                "dpad_center" -> remoteController?.sendDpadCenter() ?: false
                "home" -> remoteController?.sendHome() ?: false
                "back" -> remoteController?.sendBack() ?: false
                "play_pause" -> remoteController?.sendPlayPause() ?: false
                "volume_up" -> remoteController?.sendVolumeUp() ?: false
                "volume_down" -> remoteController?.sendVolumeDown() ?: false
                else -> false
            }
            Logger.d(Constants.TAG_PLUGIN, "Remote Command '$command' executed. Success=$success")
            result.success(mapOf("success" to success))
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during sendCommand", e)
            result.error("COMMAND_ERROR", e.message, null)
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        try {
            Logger.i(Constants.TAG_PLUGIN, "Disconnect requested")
            deviceScanner?.stopDiscovery()
            deviceScanner?.destroy()
            tlsManager?.disconnect()
            pairingManager?.destroy()
            remoteController?.destroy()

            deviceScanner = null
            tlsManager = null
            pairingManager = null
            remoteController = null

            Logger.d(Constants.TAG_PLUGIN, "Session cleaned and disconnected")
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during disconnect", e)
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    fun destroy() {
        try {
            Logger.i(Constants.TAG_PLUGIN, "Plugin destroy lifecycle event")
            disconnect(object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
            scope.cancel()
            Logger.i(Constants.TAG_PLUGIN, "Plugin scope cancelled and destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "Error during destroy: ${e.message}")
        }
    }
}
