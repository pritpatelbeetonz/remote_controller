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
import com.waysol.android_tv_remote_package.remote.KeyCode
import com.waysol.android_tv_remote_package.remote.VoiceManager
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class AndroidTVRemotePlugin(
    private val context: Context
) {

    companion object {
        private const val CHANNEL = "com.waysol.android_tv_remote_package/method"
        private const val EVENT_CHANNEL = "com.waysol.android_tv_remote_package/event"
        private const val TAG = "AndroidTVRemote"
    }

    // High-priority single-threaded executor for socket operations
    private val socketExecutor =
        java.util.concurrent.Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "SocketWorker").apply {
                priority = Thread.MAX_PRIORITY
            }
        }

    enum class ConnectionState {
        DISCOVERED,
        CONNECTING_CONTROL,
        NEEDS_PAIRING,
        PAIRING,
        PAIRED,
        CONNECTED
    }

    private var currentState: ConnectionState = ConnectionState.DISCOVERED

    private fun transitionTo(newState: ConnectionState, reason: String = "State lifecycle event") {
        val oldState = currentState
        currentState = newState
        Logger.i(
            Constants.TAG_STATE, "State transitioned:\n" +
                    "Old State: ${oldState.name}\n" +
                    "New State: ${newState.name}\n" +
                    "Reason: $reason"
        )
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
    private var lastHost: String? = null
    private var lastPkcs12Path: String? = null
    private var lastPassword: String? = null

    fun setupChannel(flutterEngine: FlutterEngine) {
        val isDebuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        Logger.debugEnabled = isDebuggable

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
                        sink.success(
                            mapOf(
                                "level" to level,
                                "tag" to tag,
                                "message" to message,
                                "timestamp" to System.currentTimeMillis()
                            )
                        )
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
                Logger.i(
                    Constants.TAG_PLUGIN,
                    "MethodChannel SUCCESS: method=$method, elapsed=${elapsed}ms"
                )
                result.success(res)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                val elapsed = System.currentTimeMillis() - startTime
                Logger.e(
                    Constants.TAG_PLUGIN,
                    "MethodChannel ERROR: method=$method, code=$errorCode, msg=$errorMessage, elapsed=${elapsed}ms"
                )
                result.error(errorCode, errorMessage, errorDetails)
            }

            override fun notImplemented() {
                val elapsed = System.currentTimeMillis() - startTime
                Logger.w(
                    Constants.TAG_PLUGIN,
                    "MethodChannel NOT IMPLEMENTED: method=$method, elapsed=${elapsed}ms"
                )
                result.notImplemented()
            }
        }

        when (method) {
            "generateCertificates" -> generateCertificates(wrappedResult)
            "startDiscovery" -> startDiscovery(wrappedResult)
            "stopDiscovery" -> stopDiscovery(wrappedResult)
            "connect" -> connect(arguments as Map<String, Any>, wrappedResult)
            "startPairing" -> startPairing(wrappedResult)
            "sendPin" -> sendPin(arguments as String, wrappedResult)
            "sendCommand" -> sendCommand(arguments as Map<String, Any>, wrappedResult)
            "launchApp" -> launchApp(arguments as String, wrappedResult)
            "sendText" -> sendText(arguments as String, wrappedResult)
            "disconnect" -> disconnect(wrappedResult)
            "voiceStart" -> startVoice(wrappedResult)
            "voiceStop" -> stopVoice(wrappedResult)
            "isKeyboardSupported" -> {
                val controller = remoteController
                val supported = controller?.isKeyboardSupported() ?: false
                wrappedResult.success(mapOf("success" to true, "supported" to supported))
            }
            "isTextFieldFocused" -> {
                val controller = remoteController
                val focused = controller?.isTextFieldFocused() ?: false
                wrappedResult.success(mapOf("success" to true, "focused" to focused))
            }
            "getKeyboardState" -> {
                val controller = remoteController
                val state = controller?.getKeyboardState() ?: RemoteController.KeyboardState.UNKNOWN
                wrappedResult.success(mapOf("success" to true, "state" to state.name))
            }
            else -> wrappedResult.notImplemented()
        }
    }

    private fun generateCertificates(result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            try {
                Logger.d(Constants.TAG_PLUGIN, "Certificate generation requested")
                certificateGenerator = CertificateGenerator()

                // Check if certificate already exists
                val pkcs12Path = context.filesDir.absolutePath + "/cert.p12"
                val certFile = java.io.File(pkcs12Path)

                if (certFile.exists()) {
                    Logger.i(
                        Constants.TAG_PLUGIN,
                        "Certificate already exists, reusing: $pkcs12Path"
                    )
                    Handler(Looper.getMainLooper()).post {
                        certificateManager = CertificateManager(context)
                        result.success(
                            mapOf(
                                "success" to true,
                                "derPath" to (context.filesDir.absolutePath + "/cert.der"),
                                "pkcs12Path" to pkcs12Path
                            )
                        )
                    }
                    return@launch
                }

                // Generate only if doesn't exist
                val certResult = certificateGenerator!!.generateCertificates(context)

                Handler(Looper.getMainLooper()).post {
                    if (certResult.success) {
                        Logger.i(
                            Constants.TAG_PLUGIN,
                            "Certificates generated successfully. DER: ${certResult.derPath}, PKCS12: ${certResult.pkcs12Path}"
                        )
                        certificateManager = CertificateManager(context)
                        result.success(
                            mapOf(
                                "success" to true,
                                "derPath" to certResult.derPath,
                                "pkcs12Path" to certResult.pkcs12Path
                            )
                        )
                    } else {
                        Logger.e(
                            Constants.TAG_PLUGIN,
                            "Certificates generation failed: ${certResult.error}"
                        )
                        result.error("CERT_ERROR", certResult.error, null)
                    }
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "Exception during certificate generation", e)
                    result.error("CERT_ERROR", e.message, null)
                }
            }
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
                Logger.i(
                    Constants.TAG_PLUGIN,
                    "Discovered ${devices.size} device(s), notifying Flutter"
                )
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

    private fun stopDiscovery(result: MethodChannel.Result) {
        try {
            Logger.i(Constants.TAG_PLUGIN, "Stop discovery requested natively")
            deviceScanner?.stopDiscovery()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Exception during stopDiscovery", e)
            result.error("DISCOVERY_ERROR", e.message, null)
        }
    }

    private fun connect(arguments: Map<String, Any>, result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            try {
                val host = arguments["host"] as String
                val port = arguments["port"] as Int
                val pkcs12Path = arguments["pkcs12Path"] as String
                Logger.d(
                    Constants.TAG_PLUGIN,
                    "Connection requested to host=$host, port=$port, cert=$pkcs12Path"
                )

                lastHost = host
                lastPkcs12Path = pkcs12Path
                lastPassword = arguments["password"] as? String ?: ""

                if (certificateManager == null) {
                    certificateManager = CertificateManager(context)
                }

                val sslContext = certificateManager?.createSSLContext(
                    pkcs12Path = pkcs12Path,
                    password = arguments["password"] as? String ?: ""
                ) ?: throw Exception("SSL context creation failed")

                tlsManager = TLSManager(sslContext)

                transitionTo(
                    ConnectionState.CONNECTING_CONTROL,
                    "Control connection requested by user"
                )

                try {
                    val connected = tlsManager?.connect(host, port) == true
                    if (connected) {
                        val controller = RemoteController(tlsManager!!)
                        val readyLock = java.util.concurrent.CountDownLatch(1)
                        controller.onReady = {
                            readyLock.countDown()
                        }
                        attachRemoteController(controller)
                        controller.start()

                        val ready = readyLock.await(5, java.util.concurrent.TimeUnit.SECONDS)
                        Handler(Looper.getMainLooper()).post {
                            if (ready) {
                                transitionTo(
                                    ConnectionState.CONNECTED,
                                    "Control socket fully connected and handshake complete"
                                )
                                Logger.i(
                                    Constants.TAG_PLUGIN,
                                    "TLS Connection successfully established and protocol handshake completed with $host:$port"
                                )
                                result.success(mapOf("success" to true))
                            } else {
                                transitionTo(
                                    ConnectionState.DISCOVERED,
                                    "Protocol handshake timed out"
                                )
                                Logger.e(Constants.TAG_PLUGIN, "Protocol handshake timed out with $host:$port")
                                tlsManager?.disconnect()
                                remoteController = null
                                result.error(
                                    "CONNECTION_ERROR",
                                    "Protocol handshake timed out",
                                    null
                                )
                            }
                        }
                    } else {
                        Handler(Looper.getMainLooper()).post {
                            transitionTo(
                                ConnectionState.DISCOVERED,
                                "Control TLS connection failed"
                            )
                            Logger.e(Constants.TAG_PLUGIN, "TLS Connection failed with $host:$port")
                            result.error(
                                "CONNECTION_ERROR",
                                "Failed to establish TLS connection",
                                null
                            )
                        }
                    }
                } catch (e: javax.net.ssl.SSLException) {
                    transitionTo(
                        ConnectionState.NEEDS_PAIRING,
                        "TLS Handshake failed (needs pairing)"
                    )
                    Handler(Looper.getMainLooper()).post {
                        Logger.w(
                            Constants.TAG_TLS, "TLS handshake failed\n" +
                                    "Exception: ${e.javaClass.name}\n" +
                                    "Reason: ${e.message}\n" +
                                    "Needs Pairing = true", e
                        )
                        result.error("NEEDS_PAIRING", "Handshake failed — pairing required", null)
                    }
                } catch (e: Exception) {
                    val isSslException = e.javaClass.name.contains("ssl", ignoreCase = true) ||
                            e.message?.contains("handshake", ignoreCase = true) == true ||
                            e.message?.contains("cert", ignoreCase = true) == true

                    if (isSslException) {
                        transitionTo(
                            ConnectionState.NEEDS_PAIRING,
                            "TLS Handshake Exception (needs pairing)"
                        )
                        Handler(Looper.getMainLooper()).post {
                            Logger.w(
                                Constants.TAG_TLS, "TLS handshake failed\n" +
                                        "Exception: ${e.javaClass.name}\n" +
                                        "Reason: ${e.message}\n" +
                                        "Needs Pairing = true", e
                            )
                            result.error(
                                "NEEDS_PAIRING",
                                "Handshake failed — pairing required",
                                null
                            )
                        }
                    } else {
                        transitionTo(
                            ConnectionState.DISCOVERED,
                            "Non-SSL connection exception caught"
                        )
                        Handler(Looper.getMainLooper()).post {
                            Logger.e(
                                Constants.TAG_CONNECT, "Connection failed\n" +
                                        "Exception: ${e.javaClass.name}\n" +
                                        "Message: ${e.message}\n" +
                                        "Needs Pairing = false", e
                            )
                            result.error("CONNECTION_ERROR", e.message, null)
                        }
                    }
                }
            } catch (e: Exception) {
                transitionTo(ConnectionState.DISCOVERED, "Outer Exception during connect")
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "Outer Exception during connect", e)
                    result.error("CONNECTION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun startPairing(result: MethodChannel.Result) {
        val host = lastHost
        val pkcs12Path = lastPkcs12Path
        val password = lastPassword

        if (host == null || pkcs12Path == null || password == null) {
            result.error("PAIRING_ERROR", "Device context missing. Call connect first.", null)
            return
        }

        transitionTo(ConnectionState.PAIRING, "Pairing connection requested")
        Logger.d(
            Constants.TAG_PLUGIN,
            "Polo pairing session start requested on port ${Constants.PORT_PAIRING}"
        )

        scope.launch(Dispatchers.IO) {
            try {
                if (certificateManager == null) {
                    certificateManager = CertificateManager(context)
                }

                val sslContext = certificateManager?.createSSLContext(pkcs12Path, password)
                    ?: throw Exception("SSL context creation failed for pairing")

                val pairingTlsManager = TLSManager(sslContext)
                Logger.d(
                    Constants.TAG_PLUGIN,
                    "Connecting pairing socket to $host:${Constants.PORT_PAIRING}..."
                )

                val connected = pairingTlsManager.connect(host, Constants.PORT_PAIRING)
                if (connected) {
                    Logger.i(
                        Constants.TAG_PLUGIN,
                        "Pairing socket connected. Initializing PairingManager."
                    )
                    tlsManager = pairingTlsManager
                    pairingManager = PairingManager(context, pairingTlsManager, pkcs12Path)

                    pairingManager?.startPairing(
                        onStatusChange = { status ->
                            Logger.i(Constants.TAG_PLUGIN, "Pairing status changed: ${status.name}")
                            if (status != PairingStatus.SUCCESS) {
                                Handler(Looper.getMainLooper()).post {
                                    methodChannel.invokeMethod("pairingStatusChanged", status.name)
                                }
                            } else {
                                promoteToControlConnection()
                            }
                        },
                        onPinDisplay = { pin ->
                            Logger.i(Constants.TAG_PLUGIN, "Pairing PIN displayed/received: $pin")
                            Handler(Looper.getMainLooper()).post {
                                methodChannel.invokeMethod("pinReceived", pin)
                            }
                        }
                    )

                    Handler(Looper.getMainLooper()).post {
                        result.success(mapOf("success" to true))
                    }
                } else {
                    transitionTo(ConnectionState.NEEDS_PAIRING, "Failed to connect to pairing port")
                    Handler(Looper.getMainLooper()).post {
                        result.error(
                            "PAIRING_ERROR",
                            "Failed to connect to pairing port ${Constants.PORT_PAIRING}",
                            null
                        )
                    }
                }
            } catch (e: Exception) {
                transitionTo(
                    ConnectionState.NEEDS_PAIRING,
                    "Exception during startPairing connection"
                )
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "Exception during startPairing connection", e)
                    result.error("PAIRING_ERROR", e.message, null)
                }
            }
        }
    }

    private fun sendPin(pin: String, result: MethodChannel.Result) {
        try {
            Logger.d(Constants.TAG_PLUGIN, "Submitting PIN for verification: $pin")
            if (pairingManager == null) {
                throw Exception("PairingManager is not initialized.")
            }
            if (pairingManager?.sendPin(pin) == true) {
                Logger.i(Constants.TAG_PLUGIN, "PIN submitted successfully.")
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
    private fun attachRemoteController(controller: RemoteController) {
        controller.onDisconnected = {
            Logger.w(Constants.TAG_PLUGIN, "RemoteController reported connection lost")
            remoteController?.destroy()
            remoteController = null
            tlsManager?.disconnect()
            tlsManager = null
            transitionTo(ConnectionState.DISCOVERED, "Socket read loop detected disconnect")
            Handler(Looper.getMainLooper()).post {
                methodChannel.invokeMethod("connectionLost", null)
            }
        }
        remoteController = controller
    }
    private fun promoteToControlConnection() {
        val host = lastHost ?: return
        val pkcs12Path = lastPkcs12Path ?: return
        val password = lastPassword ?: ""

        scope.launch(Dispatchers.IO) {
            try {
                Logger.i(Constants.TAG_PLUGIN, "Closing pairing socket")

                // 1. Disconnect pairing socket
                tlsManager?.disconnect()
                tlsManager = null
                pairingManager = null

                Logger.i(Constants.TAG_PLUGIN, "Opening control socket")

                // 2. Initialize control SSLContext
                if (certificateManager == null) {
                    certificateManager = CertificateManager(context)
                }
                val sslContext = certificateManager?.createSSLContext(pkcs12Path, password)
                    ?: throw Exception("SSL context creation failed for control connection")

                // 3. Connect control TLSManager
                val controlTlsManager = TLSManager(sslContext)
                transitionTo(
                    ConnectionState.PAIRED,
                    "Closed pairing connection and preparing control port connection"
                )

                Logger.i(Constants.TAG_PLUGIN, "Connecting to ${Constants.PORT_CONTROL}")
                val connected = controlTlsManager.connect(host, Constants.PORT_CONTROL)
                if (connected) {
                    Logger.i(Constants.TAG_PLUGIN, "TLS established")
                    tlsManager = controlTlsManager
                    val controller = RemoteController(controlTlsManager)
                    val readyLock = java.util.concurrent.CountDownLatch(1)
                    controller.onReady = {
                        readyLock.countDown()
                    }
                    attachRemoteController(controller)
                    controller.start()

                    val ready = readyLock.await(5, java.util.concurrent.TimeUnit.SECONDS)
                    if (ready) {
                        transitionTo(
                            ConnectionState.CONNECTED,
                            "Control socket connected and handshake completed after pairing"
                        )
                        Logger.i(Constants.TAG_PLUGIN, "Control connection and handshake ready")
                        Handler(Looper.getMainLooper()).post {
                            methodChannel.invokeMethod("pairingStatusChanged", "SUCCESS")
                        }
                    } else {
                        Logger.e(Constants.TAG_PLUGIN, "Protocol handshake timed out after pairing")
                        transitionTo(
                            ConnectionState.NEEDS_PAIRING,
                            "Handshake timeout after pairing"
                        )
                        controlTlsManager.disconnect()
                        tlsManager = null
                        remoteController = null
                        Handler(Looper.getMainLooper()).post {
                            methodChannel.invokeMethod("pairingStatusChanged", "FAILED")
                        }
                    }
                } else {
                    transitionTo(
                        ConnectionState.NEEDS_PAIRING,
                        "Control connection failed after pairing"
                    )
                    Logger.e(
                        Constants.TAG_PLUGIN,
                        "Failed to connect to control port ${Constants.PORT_CONTROL} after pairing"
                    )
                    Handler(Looper.getMainLooper()).post {
                        methodChannel.invokeMethod("pairingStatusChanged", "FAILED")
                    }
                }
            } catch (e: Exception) {
                transitionTo(
                    ConnectionState.NEEDS_PAIRING,
                    "Control connection promotion failed with exception"
                )
                Logger.e(Constants.TAG_PLUGIN, "Exception during control connection promotion", e)
            }
        }
    }

    private fun ensureRemoteControllerReady(timeoutSec: Long = 3): RemoteController {
        var controller = remoteController
        if (controller == null) {
            val tls = tlsManager
            if (tls != null && tls.isConnected()) {
                Logger.i(
                    Constants.TAG_PLUGIN,
                    "RemoteController was null but socket is connected. Initializing RemoteController."
                )
                val newController = RemoteController(tls)
                val readyLock = java.util.concurrent.CountDownLatch(1)
                newController.onReady = {
                    readyLock.countDown()
                }
                attachRemoteController(newController)
                newController.start()
                
                val ready = readyLock.await(timeoutSec, java.util.concurrent.TimeUnit.SECONDS)
                if (!ready) {
                    Logger.e(Constants.TAG_PLUGIN, "Protocol handshake timed out during lazy-init recovery")
                    tls.disconnect()
                    remoteController = null
                    throw Exception("Remote session handshake timed out.")
                }
                controller = newController
            } else {
                throw Exception("Remote session is not connected.")
            }
        }
        return controller ?: throw Exception("Remote session is not connected.")
    }

    private fun sendCommand(arguments: Map<String, Any>, result: MethodChannel.Result) {
        socketExecutor.execute {
            try {
                val command = arguments["command"] as String
                Logger.d(Constants.TAG_PLUGIN, "Remote Command requested: $command")
                val controller = ensureRemoteControllerReady(timeoutSec = 3)
                val success = when (command) {
                    "dpad_up" -> controller.sendDpadUp()
                    "dpad_down" -> controller.sendDpadDown()
                    "dpad_left" -> controller.sendDpadLeft()
                    "dpad_right" -> controller.sendDpadRight()
                    "dpad_center" -> controller.sendDpadCenter()
                    "home" -> controller.sendHome()
                    "back" -> controller.sendBack()
                    "play_pause" -> controller.sendPlayPause()
                    "volume_up" -> controller.sendVolumeUp()
                    "volume_down" -> controller.sendVolumeDown()
                    "volume_mute" -> controller.sendVolumeMute()
                    "media_next", "next" -> controller.sendNext()
                    "media_previous", "previous" -> controller.sendPrevious()
                    else -> false
                }
                Logger.d(
                    Constants.TAG_PLUGIN,
                    "Remote Command '$command' executed. Success=$success"
                )
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf("success" to success))
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "Exception during sendCommand", e)
                    result.error("COMMAND_ERROR", e.message, null)
                }
            }
        }
    }

    private fun launchApp(appLink: String, result: MethodChannel.Result) {
        socketExecutor.execute {
            try {
                Logger.d(Constants.TAG_PLUGIN, "Launch App requested with link: $appLink")
                val controller = ensureRemoteControllerReady(timeoutSec = 3)
                val success = controller.sendAppLink(appLink)
                Logger.d(Constants.TAG_PLUGIN, "Launch App command sent. Success=$success")
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf("success" to success))
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "Exception during launchApp", e)
                    result.error("COMMAND_ERROR", e.message, null)
                }
            }
        }
    }

    private fun sendText(text: String, result: MethodChannel.Result) {
        socketExecutor.execute {
            try {
                Logger.d(Constants.TAG_PLUGIN, "⌨️ Keyboard: Sending text: \"$text\"")
                val controller = remoteController
                if (controller == null || !controller.isConnected()) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("CONNECTION_LOST", "No active TV connection", null)
                    }
                    return@execute
                }
                if (!controller.isKeyboardSupported()) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("KEYBOARD_NOT_SUPPORTED", "Android TV does not support IME keyboard inputs", null)
                    }
                    return@execute
                }
                val success = controller.sendText(text)
                if (success) {
                    Logger.d(Constants.TAG_PLUGIN, "✅ IME message transmitted successfully. Character count: ${text.length}")
                    Handler(Looper.getMainLooper()).post {
                        result.success(mapOf("success" to true))
                    }
                } else {
                    Logger.e(Constants.TAG_PLUGIN, "❌ TV rejected IME message or transmission failed")
                    Handler(Looper.getMainLooper()).post {
                        result.error("COMMAND_ERROR", "TV rejected IME message", null)
                    }
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "❌ Unexpected keyboard session error: ${e.message}", e)
                    result.error("COMMAND_ERROR", e.message, null)
                }
            }
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

    private var voiceManager: VoiceManager? = null
    private var voiceSessionId: Int? = null

    private fun startVoice(result: MethodChannel.Result) {
        Logger.i(Constants.TAG_PLUGIN, "🎙️ Voice session requested")

        val controller = remoteController
        if (controller == null) {
            Logger.e(Constants.TAG_PLUGIN, "❌ Connection lost: Remote controller is null")
            result.error("CONNECTION_LOST", "Remote controller not connected", null)
            return
        }

        // 1. Check if TV supports Voice Search
        if (!controller.isVoiceSupported()) {
            Logger.e(Constants.TAG_PLUGIN, "❌ Device does not support Voice Search")
            result.error("VOICE_NOT_SUPPORTED", "Device does not support Voice Search", null)
            return
        }

        // 2. Check microphone permission
        if (androidx.core.content.ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.RECORD_AUDIO
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            Logger.e(Constants.TAG_PLUGIN, "❌ Permission denied for microphone recording")
            result.error("PERMISSION_DENIED", "Microphone permission denied", null)
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                val readyLock = java.util.concurrent.CountDownLatch(1)
                var session: Int? = null

                controller.onVoiceBegin = { sid ->
                    session = sid
                    readyLock.countDown()
                }

                Logger.i(Constants.TAG_PLUGIN, "🔍 KEYCODE_SEARCH sent")
                val searchSuccess = controller.sendKeyCode(KeyCode.SEARCH)
                if (!searchSuccess) {
                    controller.onVoiceBegin = null
                    Handler(Looper.getMainLooper()).post {
                        Logger.e(Constants.TAG_PLUGIN, "❌ Unexpected voice session error: Failed to send KEYCODE_SEARCH")
                        result.error("AUDIO_RECORD_ERROR", "Failed to send SEARCH keycode", null)
                    }
                    return@launch
                }

                Logger.i(Constants.TAG_PLUGIN, "⏳ Waiting for RemoteVoiceBegin...")
                val received = readyLock.await(2, java.util.concurrent.TimeUnit.SECONDS)
                controller.onVoiceBegin = null

                val activeSession = session
                if (received && activeSession != null) {
                    Logger.i(Constants.TAG_PLUGIN, "📥 RemoteVoiceBegin received")
                    Logger.i(Constants.TAG_PLUGIN, "🆔 Session ID assigned: $activeSession")
                    voiceSessionId = activeSession

                    // Reply to TV with Voice Begin
                    controller.sendVoiceBegin(activeSession)

                    if (voiceManager == null) {
                        voiceManager = VoiceManager(context, controller)
                    }

                    val recordingStarted = voiceManager?.startRecording(activeSession) == true
                    if (recordingStarted) {
                        Handler(Looper.getMainLooper()).post {
                            result.success(mapOf("success" to true, "sessionId" to activeSession))
                        }
                    } else {
                        Handler(Looper.getMainLooper()).post {
                            result.error("AUDIO_RECORD_ERROR", "Failed to start AudioRecord", null)
                        }
                    }
                } else {
                    Handler(Looper.getMainLooper()).post {
                        Logger.e(Constants.TAG_PLUGIN, "❌ Voice session setup timed out")
                        result.error("TIMEOUT", "Voice session setup timed out", null)
                    }
                }
            } catch (e: Exception) {
                controller.onVoiceBegin = null
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "❌ Unexpected voice session error: ${e.message}", e)
                    result.error("AUDIO_RECORD_ERROR", e.message, null)
                }
            }
        }
    }

    private fun stopVoice(result: MethodChannel.Result) {
        val controller = remoteController
        if (controller == null) {
            result.error("CONNECTION_LOST", "Remote controller not connected", null)
            return
        }

        val sessionId = voiceSessionId
        if (sessionId == null) {
            result.success(mapOf("success" to true, "message" to "No active voice session"))
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                voiceManager?.stopRecording()
                controller.sendVoiceEnd(sessionId)
                Logger.i(Constants.TAG_PLUGIN, "📤 RemoteVoiceEnd sent")
                voiceSessionId = null
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf("success" to true))
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    Logger.e(Constants.TAG_PLUGIN, "❌ Unexpected voice session error: ${e.message}", e)
                    result.error("AUDIO_RECORD_ERROR", e.message, null)
                }
            }
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
            socketExecutor.shutdown()  // Add this
            scope.cancel()
            Logger.i(Constants.TAG_PLUGIN, "Plugin scope cancelled and destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "Error during destroy: ${e.message}")
        }
    }
}
