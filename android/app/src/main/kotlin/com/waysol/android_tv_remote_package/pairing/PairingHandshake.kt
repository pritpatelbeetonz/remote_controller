package com.waysol.android_tv_remote_package.pairing

import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.MessageParser
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicReference

class PairingHandshake(
    private val tlsManager: TLSManager
) {

    private val status = AtomicReference(PairingStatus.IDLE)
    private val pinCode = AtomicReference<String>("")
    private var handshakeJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    private val statusCallbacks = mutableListOf<(PairingStatus) -> Unit>()
    private val pinCallbacks = mutableListOf<(String) -> Unit>()

    /**
     * Start pairing handshake - send pairing request
     */
    fun startHandshake(
        onStatusChange: (PairingStatus) -> Unit = {},
        onPinDisplay: (String) -> Unit = {}
    ): Boolean {
        if (status.get() != PairingStatus.IDLE) {
            Logger.w(Constants.TAG_PAIRING, "Handshake already in progress")
            return false
        }

        statusCallbacks.add(onStatusChange)
        pinCallbacks.add(onPinDisplay)

        try {
            setStatus(PairingStatus.CONNECTING)

            // Send pairing request
            val pairingRequest = ProtobufMessage.createPairingRequest()
            if (!tlsManager.sendData(pairingRequest)) {
                setStatus(PairingStatus.FAILED)
                Logger.e(Constants.TAG_PAIRING, "Failed to send pairing request")
                return false
            }

            setStatus(PairingStatus.WAITING_PIN)

            // Start listening for PIN from TV in background
            handshakeJob = scope.launch {
                waitForPin()
            }

            return true
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Handshake start error: ${e.message}", e)
            setStatus(PairingStatus.FAILED)
            return false
        }
    }

    /**
     * Wait for TV to send PIN
     */
    private suspend fun waitForPin() {
        try {
            var pinReceived = false
            val timeoutSeconds = Constants.PIN_DISPLAY_TIMEOUT_SEC

            for (i in 0 until timeoutSeconds.toInt()) {
                val response = withTimeoutOrNull(1000) {
                    tlsManager.receiveData()
                } ?: run {
                    delay(500)
                    return@run null
                }

                if (response != null) {
                    val pin = MessageParser.extractPinFromResponse(response)
                    if (pin.isNotEmpty() && pin.length == Constants.PIN_LENGTH) {
                        pinCode.set(pin)
                        pinCallbacks.forEach { it(pin) }
                        Logger.d(Constants.TAG_PAIRING, "PIN received from TV: $pin")
                        pinReceived = true
                        break
                    }
                }

                delay(100)
            }

            if (!pinReceived) {
                setStatus(PairingStatus.TIMEOUT)
                Logger.w(Constants.TAG_PAIRING, "PIN reception timeout")
            }
        } catch (e: CancellationException) {
            Logger.d(Constants.TAG_PAIRING, "PIN wait cancelled")
            throw e
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Wait for PIN error: ${e.message}", e)
            setStatus(PairingStatus.FAILED)
        }
    }

    /**
     * Send PIN code to complete pairing
     */
    fun sendPin(pin: String): Boolean {
        return try {
            if (pin.length != Constants.PIN_LENGTH) {
                Logger.w(Constants.TAG_PAIRING, "Invalid PIN length: ${pin.length}")
                return false
            }

            setStatus(PairingStatus.PAIRING)

            val secretMessage = ProtobufMessage.createSecretMessage(pin)
            if (!tlsManager.sendData(secretMessage)) {
                setStatus(PairingStatus.FAILED)
                Logger.e(Constants.TAG_PAIRING, "Failed to send PIN")
                return false
            }

            // Wait for confirmation
            scope.launch {
                waitForPairingConfirmation()
            }

            true
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Send PIN error: ${e.message}", e)
            setStatus(PairingStatus.FAILED)
            false
        }
    }

    /**
     * Wait for TV to confirm pairing success
     */
    private suspend fun waitForPairingConfirmation() {
        try {
            delay(1000) // Give TV time to process PIN

            val response = withTimeoutOrNull(5000) {
                tlsManager.receiveData()
            }

            if (response != null && MessageParser.isPairingSuccessful(response)) {
                setStatus(PairingStatus.SUCCESS)
                Logger.i(Constants.TAG_PAIRING, "Pairing successful!")
            } else {
                setStatus(PairingStatus.FAILED)
                Logger.e(Constants.TAG_PAIRING, "Pairing confirmation failed")
            }
        } catch (e: TimeoutCancellationException) {
            setStatus(PairingStatus.TIMEOUT)
            Logger.w(Constants.TAG_PAIRING, "Pairing confirmation timeout")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Confirmation wait error: ${e.message}", e)
            setStatus(PairingStatus.FAILED)
        }
    }

    fun getStatus(): PairingStatus = status.get()
    fun getPin(): String = pinCode.get()
    fun isSuccessful(): Boolean = status.get() == PairingStatus.SUCCESS

    fun cancel() {
        try {
            handshakeJob?.cancel()
            setStatus(PairingStatus.CANCELLED)
            Logger.d(Constants.TAG_PAIRING, "Pairing cancelled")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Cancel error: ${e.message}")
        }
    }

    private fun setStatus(newStatus: PairingStatus) {
        status.set(newStatus)
        statusCallbacks.forEach { it(newStatus) }
        Logger.d(Constants.TAG_PAIRING, "Pairing status: $newStatus")
    }

    fun destroy() {
        try {
            handshakeJob?.cancel()
            scope.cancel()
            statusCallbacks.clear()
            pinCallbacks.clear()
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Destroy error: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "PairingHandshake"
    }
}