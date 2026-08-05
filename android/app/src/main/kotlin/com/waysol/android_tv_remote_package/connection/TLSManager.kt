package com.waysol.android_tv_remote_package.connection

import com.waysol.android_tv_remote_package.util.Logger
import com.waysol.android_tv_remote_package.util.Constants
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

    @Throws(Exception::class)
    fun connect(host: String, port: Int): Boolean {
        Logger.i(Constants.TAG_TLS, "Starting control connection to $host:$port")
        val socketFactory = sslContext.socketFactory
        socket = socketFactory.createSocket(host, port) as SSLSocket
        Logger.i(Constants.TAG_SOCKET, "Socket created")

        socket?.apply {
            soTimeout = 30000
            enabledProtocols = arrayOf("TLSv1.2")
            Logger.i(Constants.TAG_TLS, "Starting TLS handshake...")
            startHandshake()
            Logger.i(Constants.TAG_TLS, "TLS handshake successful")
        }

        inputStream = DataInputStream(socket?.inputStream)
        outputStream = DataOutputStream(socket?.outputStream)

        Logger.d(Constants.TAG_TLS, "TLS connection established with $host:$port")
        return true
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
            Logger.e(Constants.TAG_SOCKET, "Send failed: ${e.message}", e)
            false
        }
    }

    @Throws(IOException::class)
    fun receiveData(): ByteArray? {
        return try {
            inputStream?.let {
                val length = readVarint(it)
                if (length <= 0) {
                    Logger.w(Constants.TAG_SOCKET, "EOF received (zero length message)")
                    return null
                }

                val data = ByteArray(length)
                it.readFully(data)
                data
            }
        } catch (e: java.io.EOFException) {
            Logger.i(Constants.TAG_SOCKET, "Socket closed: EOF received (connection closed by peer)")
            null
        } catch (e: java.net.SocketTimeoutException) {
            Logger.e(Constants.TAG_SOCKET, "Socket timeout: Read timed out", e)
            // Not a disconnect — just no data within soTimeout. Rethrow so the
            // caller can keep listening instead of treating this like a real EOF.
            throw e
        } catch (e: java.net.SocketException) {
            Logger.e(Constants.TAG_SOCKET, "Connection reset: Socket exception", e)
            null
        } catch (e: Exception) {
            Logger.e(Constants.TAG_SOCKET, "Receive failed: ${e.message}", e)
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
            Logger.e(Constants.TAG_CERTIFICATE, "Failed to get peer certificate: ${e.message}", e)
            null
        }
    }

    fun disconnect() {
        Logger.i(Constants.TAG_SOCKET, "Socket disconnected")
        try {
            inputStream?.close()
            outputStream?.close()
            socket?.close()
            Logger.i(Constants.TAG_SOCKET, "Socket closed")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_SOCKET, "Disconnect error: ${e.message}", e)
        }
        socket = null
    }

    fun isConnected(): Boolean = socket?.isConnected == true && socket?.isClosed == false

    companion object {
        private const val TAG = "TLSManager"
    }
}