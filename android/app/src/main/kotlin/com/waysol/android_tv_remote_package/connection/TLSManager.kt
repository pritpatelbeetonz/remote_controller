package com.waysol.android_tv_remote_package.connection

import android.util.Log
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import javax.net.ssl.SSLSocket

class TLSManager(
    private val sslContext: javax.net.ssl.SSLContext
) {

    private var socket: SSLSocket? = null
    private var inputStream: DataInputStream? = null
    private var outputStream: DataOutputStream? = null

    @Throws(IOException::class)
    fun connect(host: String, port: Int): Boolean {
        return try {
            val socketFactory = sslContext.socketFactory
            socket = socketFactory.createSocket(host, port) as SSLSocket

            socket?.apply {
                enabledProtocols = arrayOf("TLSv1.2")
                enabledCipherSuites = arrayOf(
                    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
                    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
                )
                startHandshake()
            }

            inputStream = DataInputStream(socket?.inputStream)
            outputStream = DataOutputStream(socket?.outputStream)

            Log.d(TAG, "TLS connection established with $host:$port")
            true
        } catch (e: Exception) {
            Log.e(TAG, "TLS connection failed: ${e.message}")
            disconnect()
            false
        }
    }

    private fun writeVarint(out: DataOutputStream, value: Int) {
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            out.write((v and 0x7F) or 0x80)
            v = v ushr 7
        }
        out.write(v and 0x7F)
    }

    @Throws(IOException::class)
    private fun readVarint(input: DataInputStream): Int {
        var result = 0
        var shift = 0
        while (shift < 32) {
            if (input.available() <= 0 && shift > 0) {
                // If there's no data available, but we've started reading,
                // we should wait or error. Since readByte blocks, we just call it.
            }
            val b = input.readByte().toInt()
            result = result or ((b and 0x7F) shl shift)
            if ((b and 0x80) == 0) {
                return result
            }
            shift += 7
        }
        throw IOException("Varint too long")
    }

    @Throws(IOException::class)
    fun sendData(data: ByteArray): Boolean {
        return try {
            outputStream?.let {
                writeVarint(it, data.size)
                it.write(data)
                it.flush()
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Send failed: ${e.message}")
            false
        }
    }

    @Throws(IOException::class)
    fun receiveData(): ByteArray? {
        return try {
            inputStream?.let {
                val length = readVarint(it)
                if (length <= 0) return null

                val data = ByteArray(length)
                it.readFully(data)
                data
            }
        } catch (e: java.io.EOFException) {
            Log.d(TAG, "Connection closed by peer")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Receive failed: ${e.message}")
            null
        }
    }

    fun getPeerCertificate(): java.security.cert.X509Certificate? {
        return try {
            val session = socket?.session
            val certs = session?.peerCertificates
            if (certs != null && certs.isNotEmpty()) {
                certs[0] as? java.security.cert.X509Certificate
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get peer certificate: ${e.message}")
            null
        }
    }

    fun disconnect() {
        try {
            inputStream?.close()
            outputStream?.close()
            socket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Disconnect error: ${e.message}")
        }
        socket = null
    }

    fun isConnected(): Boolean = socket?.isConnected == true

    companion object {
        private const val TAG = "TLSManager"
    }
}