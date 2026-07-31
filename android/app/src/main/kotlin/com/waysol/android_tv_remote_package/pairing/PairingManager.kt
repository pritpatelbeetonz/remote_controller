package com.waysol.android_tv_remote_package.pairing

import android.content.Context
import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*
import java.io.FileInputStream
import java.security.KeyStore
import java.security.interfaces.RSAPublicKey
import java.security.MessageDigest
import java.math.BigInteger
import java.util.concurrent.atomic.AtomicReference

class PairingManager(
    private val context: Context,
    private val tlsManager: TLSManager,
    private val pkcs12Path: String
) {

    private val status = AtomicReference(PairingStatus.IDLE)
    private var pairingJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    private val statusCallbacks = mutableListOf<(PairingStatus) -> Unit>()
    private val pinCallbacks = mutableListOf<(String) -> Unit>()

    fun startPairing(
        onStatusChange: (PairingStatus) -> Unit = {},
        onPinDisplay: (String) -> Unit = {}
    ) {
        statusCallbacks.add(onStatusChange)
        pinCallbacks.add(onPinDisplay)

        pairingJob = scope.launch {
            try {
                setStatus(PairingStatus.CONNECTING)

                // 1. Send PairingRequest
                Logger.d(Constants.TAG_PAIRING, "Sending PairingRequest...")
                val pairingRequest = ProtobufMessage.createPairingRequest()
                if (!tlsManager.sendData(pairingRequest)) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 2. Receive PairingRequestAck
                Logger.d(Constants.TAG_PAIRING, "Waiting for PairingRequestAck...")
                val response1 = tlsManager.receiveData()
                if (response1 == null) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 3. Send Options
                Logger.d(Constants.TAG_PAIRING, "Sending Options...")
                val options = ProtobufMessage.createOptionsMessage()
                if (!tlsManager.sendData(options)) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 4. Receive Options from TV
                Logger.d(Constants.TAG_PAIRING, "Waiting for TV Options...")
                val response2 = tlsManager.receiveData()
                if (response2 == null) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 5. Send Configuration
                Logger.d(Constants.TAG_PAIRING, "Sending Configuration...")
                val config = ProtobufMessage.createConfigurationMessage()
                if (!tlsManager.sendData(config)) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 6. Receive ConfigurationAck
                Logger.d(Constants.TAG_PAIRING, "Waiting for ConfigurationAck...")
                val response3 = tlsManager.receiveData()
                if (response3 == null) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 7. Transition to WAITING_PIN state (TV is now showing PIN)
                Logger.i(Constants.TAG_PAIRING, "Polo negotiation complete. TV is showing PIN.")
                setStatus(PairingStatus.WAITING_PIN)

            } catch (e: Exception) {
                Logger.e(Constants.TAG_PAIRING, "Pairing handshake sequence failed: ${e.message}", e)
                setStatus(PairingStatus.FAILED)
            }
        }
    }

    fun sendPin(pin: String): Boolean {
        if (pin.length != 6) {
            Logger.w(Constants.TAG_PAIRING, "Invalid PIN length: ${pin.length}")
            return false
        }
        
        pairingJob = scope.launch {
            try {
                setStatus(PairingStatus.PAIRING)
                Logger.d(Constants.TAG_PAIRING, "Generating pairing signature for PIN: $pin")

                // 1. Load client certificate
                val keyStore = KeyStore.getInstance("PKCS12")
                FileInputStream(pkcs12Path).use { fis ->
                    keyStore.load(fis, "".toCharArray())
                }
                val alias = keyStore.aliases().nextElement()
                val clientCert = keyStore.getCertificate(alias) as java.security.cert.X509Certificate
                
                // 2. Load TV peer certificate
                val serverCert = tlsManager.getPeerCertificate() ?: throw Exception("Failed to retrieve TV peer certificate")

                // 3. Extract RSA mod/exp keys
                val clientPublicKey = clientCert.publicKey as RSAPublicKey
                val clientModulus = clientPublicKey.modulus
                val clientExponent = clientPublicKey.publicExponent

                val serverPublicKey = serverCert.publicKey as RSAPublicKey
                val serverModulus = serverPublicKey.modulus
                val serverExponent = serverPublicKey.publicExponent

                // 4. Compute SHA-256 HMAC PIN hash
                val h = MessageDigest.getInstance("SHA-256")
                h.update(getUnsignedBytes(clientModulus))
                h.update(getUnsignedBytes(clientExponent))
                h.update(getUnsignedBytes(serverModulus))
                h.update(getUnsignedBytes(serverExponent))
                
                val pinSuffixHex = pin.substring(2)
                h.update(hexStringToByteArray(pinSuffixHex))
                val hashResult = h.digest()

                // Validate locally calculated digest
                val firstByte = hashResult[0].toInt() and 0xFF
                val expectedFirstByte = pin.substring(0, 2).toInt(16)
                if (firstByte != expectedFirstByte) {
                    Logger.w(Constants.TAG_PAIRING, "Warning: Local hash first-byte verification failed.")
                }

                // 5. Send Secret message containing PIN hash signature
                Logger.d(Constants.TAG_PAIRING, "Sending signed Secret bytes...")
                val secretMsg = ProtobufMessage.createSecretMessage(hashResult)
                if (!tlsManager.sendData(secretMsg)) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                // 6. Receive SecretAck
                Logger.d(Constants.TAG_PAIRING, "Waiting for SecretAck...")
                val response = tlsManager.receiveData()
                if (response != null) {
                    Logger.i(Constants.TAG_PAIRING, "Pairing successful!")
                    setStatus(PairingStatus.SUCCESS)
                } else {
                    Logger.e(Constants.TAG_PAIRING, "Pairing rejected by TV (received null response).")
                    setStatus(PairingStatus.FAILED)
                }

            } catch (e: Exception) {
                Logger.e(Constants.TAG_PAIRING, "PIN verification failed: ${e.message}", e)
                setStatus(PairingStatus.FAILED)
            }
        }
        return true
    }

    private fun getUnsignedBytes(bi: BigInteger): ByteArray {
        val bytes = bi.toByteArray()
        if (bytes.isNotEmpty() && bytes[0].toInt() == 0) {
            return bytes.copyOfRange(1, bytes.size)
        }
        return bytes
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val len = s.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(s[i], 16) shl 4) + Character.digit(s[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    fun getStatus(): PairingStatus = status.get()

    private fun setStatus(newStatus: PairingStatus) {
        status.set(newStatus)
        statusCallbacks.forEach { it(newStatus) }
        Logger.d(Constants.TAG_PAIRING, "Pairing status: $newStatus")
    }

    fun destroy() {
        try {
            pairingJob?.cancel()
            scope.cancel()
            statusCallbacks.clear()
            pinCallbacks.clear()
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Destroy error: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "PairingManager"
    }
}