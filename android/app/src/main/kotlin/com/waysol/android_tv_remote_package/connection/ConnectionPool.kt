package com.waysol.android_tv_remote_package.connection

import android.util.Log
import java.util.concurrent.CopyOnWriteArrayList

class ConnectionPool {
    private val connections = CopyOnWriteArrayList<PooledConnection>()
    private val maxPoolSize = 5
    private val connectionTimeout = 30000L

    data class PooledConnection(
        val host: String,
        val port: Int,
        val tlsManager: TLSManager,
        val createdAt: Long = System.currentTimeMillis()
    )

    /**
     * Get or create a connection for the given host:port
     */
    fun getConnection(host: String, port: Int, sslContext: javax.net.ssl.SSLContext): TLSManager? {
        // Check if existing connection is still valid
        val existing = connections.find { it.host == host && it.port == port }
        if (existing != null && existing.tlsManager.isConnected()) {
            Log.d(TAG, "Reusing existing connection to $host:$port")
            return existing.tlsManager
        }

        // Remove expired connection
        existing?.let { connections.remove(it) }

        // Create new connection
        val tlsManager = TLSManager(sslContext)
        if (tlsManager.connect(host, port)) {
            val pooled = PooledConnection(host, port, tlsManager)
            if (connections.size >= maxPoolSize) {
                // Remove oldest
                connections.removeAt(0)
            }
            connections.add(pooled)
            return tlsManager
        }

        return null
    }

    /**
     * Release a connection back to pool
     */
    fun releaseConnection(host: String, port: Int) {
        val connection = connections.find { it.host == host && it.port == port }
        connection?.let {
            if (!it.tlsManager.isConnected()) {
                connections.remove(it)
            }
        }
    }

    /**
     * Close all connections
     */
    fun closeAll() {
        connections.forEach { it.tlsManager.disconnect() }
        connections.clear()
    }


    /**
     * Clean up expired connections
     */
    fun cleanup() {
        val now = System.currentTimeMillis()
        connections.removeAll { connection ->
            (now - connection.createdAt) > connectionTimeout || !connection.tlsManager.isConnected()
        }
    }

    companion object {
        private const val TAG = "ConnectionPool"
    }
}