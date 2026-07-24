package com.waysol.android_tv_remote_package.pairing

import android.util.Log
import com.waysol.android_tv_remote_package.connection.TLSManager
import com.waysol.android_tv_remote_package.protocol.MessageParser
import com.waysol.android_tv_remote_package.protocol.ProtobufMessage
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicReference

class PairingManager(
    private val tlsManager: TLSManager
) {

    private val status = AtomicReference(PairingStatus.IDLE)
    private val pinCode = AtomicReference<String>("")
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

                val pairingRequest = ProtobufMessage.createPairingRequest()
                if (!tlsManager.sendData(pairingRequest)) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                setStatus(PairingStatus.WAITING_PIN)

                var pinReceived = false
                for (i in 0 until 30) {
                    val response = tlsManager.receiveData() ?: break
                    val pin = MessageParser.extractPinFromResponse(response)

                    if (pin.isNotEmpty()) {
                        pinCode.set(pin)
                        pinCallbacks.forEach { it(pin) }
                        pinReceived = true
                        break
                    }

                    delay(1000)
                }

                if (!pinReceived) {
                    setStatus(PairingStatus.FAILED)
                    return@launch
                }

                setStatus(PairingStatus.PAIRING)

            } catch (e: Exception) {
                Logger.e(Constants.TAG_PAIRING, "Pairing error: ${e.message}", e)
                setStatus(PairingStatus.FAILED)
            }
        }
    }

    fun sendPin(pin: String): Boolean {
        return try {
            val secretMessage = ProtobufMessage.createSecretMessage(pin)
            if (tlsManager.sendData(secretMessage)) {
                scope.launch {
                    delay(1000)
                    val response = tlsManager.receiveData()
                    if (response != null && MessageParser.isPairingSuccessful(response)) {
                        setStatus(PairingStatus.SUCCESS)
                    } else {
                        setStatus(PairingStatus.FAILED)
                    }
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PAIRING, "Send PIN error: ${e.message}", e)
            false
        }
    }

    fun getStatus(): PairingStatus = status.get()
    fun getPin(): String = pinCode.get()

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