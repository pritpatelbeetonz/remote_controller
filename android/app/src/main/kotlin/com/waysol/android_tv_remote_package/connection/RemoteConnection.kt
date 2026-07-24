package com.waysol.android_tv_remote_package.connection

import android.util.Log
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*

class RemoteConnection(
    private val sslContext: javax.net.ssl.SSLContext,
    private val host: String,
    private val port: Int
) {

    private var tlsManager: TLSManager? = null
    private val connectionScope = CoroutineScope(Dispatchers.Default + Job())
    private var isConnected = false

    private val connectionListeners = mutableListOf<(Boolean) -> Unit>()
    private val errorListeners = mutableListOf<(String) -> Unit>()

    /**
     * Establish remote connection to Android TV
     */
    suspend fun connect(
        onConnected: (Boolean) -> Unit = {},
        onError: (String) -> Unit = {}
    ): Boolean {
        return withContext(Dispatchers.Default) {
            try {
                connectionListeners.add(onConnected)
                errorListeners.add(onError)

                Logger.d(Constants.TAG_CONNECTION, "Connecting to $host:$port")

                tlsManager = TLSManager(sslContext)
                val connected = tlsManager?.connect(host, port) ?: false

                if (connected) {
                    isConnected = true
                    Logger.i(Constants.TAG_CONNECTION, "Connected to $host:$port")
                    notifyConnectionListeners(true)
                    true
                } else {
                    isConnected = false
                    val error = "Failed to establish TLS connection"
                    Logger.e(Constants.TAG_CONNECTION, error)
                    notifyErrorListeners(error)
                    false
                }
            } catch (e: Exception) {
                isConnected = false
                val error = "Connection error: ${e.message}"
                Logger.e(Constants.TAG_CONNECTION, error, e)
                notifyErrorListeners(error)
                false
            }
        }
    }

    /**
     * Send data through connection
     */
    suspend fun send(data: ByteArray): Boolean {
        return withContext(Dispatchers.Default) {
            try {
                if (!isConnected) {
                    Logger.w(Constants.TAG_CONNECTION, "Not connected")
                    return@withContext false
                }

                tlsManager?.sendData(data) ?: false
            } catch (e: Exception) {
                Logger.e(Constants.TAG_CONNECTION, "Send error: ${e.message}")
                isConnected = false
                notifyConnectionListeners(false)
                false
            }
        }
    }

    /**
     * Receive data from connection
     */
    suspend fun receive(): ByteArray? {
        return withContext(Dispatchers.Default) {
            try {
                if (!isConnected) {
                    return@withContext null
                }

                tlsManager?.receiveData()
            } catch (e: Exception) {
                Logger.e(Constants.TAG_CONNECTION, "Receive error: ${e.message}")
                isConnected = false
                notifyConnectionListeners(false)
                null
            }
        }
    }

    /**
     * Check if connection is alive
     */
    fun isAlive(): Boolean = isConnected && (tlsManager?.isConnected() ?: false)

    /**
     * Disconnect
     */
    suspend fun disconnect() {
        withContext(Dispatchers.Default) {
            try {
                tlsManager?.disconnect()
                isConnected = false
                Logger.d(Constants.TAG_CONNECTION, "Disconnected from $host:$port")
                notifyConnectionListeners(false)
            } catch (e: Exception) {
                Logger.e(Constants.TAG_CONNECTION, "Disconnect error: ${e.message}")
            }
        }
    }

    private fun notifyConnectionListeners(connected: Boolean) {
        connectionListeners.forEach { it(connected) }
    }

    private fun notifyErrorListeners(error: String) {
        errorListeners.forEach { it(error) }
    }

    fun destroy() {
        try {
            connectionScope.launch {
                disconnect()
                connectionScope.cancel()
                connectionListeners.clear()
                errorListeners.clear()
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_CONNECTION, "Destroy error: ${e.message}")
        }
    }
}