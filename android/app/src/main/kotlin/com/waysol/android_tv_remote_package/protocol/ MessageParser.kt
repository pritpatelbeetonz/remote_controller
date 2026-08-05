package com.waysol.android_tv_remote_package.protocol

import java.io.ByteArrayInputStream

/**
 * Parse incoming protobuf messages from Android TV
 */
object MessageParser {

    /**
     * Extract PIN code from TV response (mock or unused in actual v2, kept for compatibility)
     */
    fun extractPinFromResponse(data: ByteArray): String {
        return try {
            val input = ByteArrayInputStream(data)

            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 2 && wireType == 2 -> { // field 2, length-delimited
                        val length = readVarint(input)
                        val pinBytes = ByteArray(length)
                        input.read(pinBytes)
                        return String(pinBytes)
                    }
                    else -> skipField(input, wireType)
                }
            }
            ""
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Check if pairing was successful
     */
    fun isPairingSuccessful(data: ByteArray): Boolean {
        return try {
            val input = ByteArrayInputStream(data)

            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 2 && wireType == 0 -> { // Status field (usually status in OuterMessage)
                        val status = readVarint(input)
                        return status == 200 // 200 = STATUS_OK
                    }
                    else -> skipField(input, wireType)
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get the active field number of the Polo OuterMessage wrapper.
     * Field mappings:
     * - 10: PairingRequest
     * - 11: PairingRequestAck
     * - 20: Options
     * - 30: Configuration
     * - 31: ConfigurationAck
     * - 40: Secret
     * - 41: SecretAck
     */
    fun getOuterMessageField(data: ByteArray): Int {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                if (fieldNumber == 1 || fieldNumber == 2) {
                    skipField(input, wireType)
                } else {
                    return fieldNumber
                }
            }
            -1
        } catch (e: Exception) {
            -1
        }
    }

    /**
     * Extract Ping Request value from TV message
     * Returns null if it is not a ping request or parsing fails
     */
    fun extractPingVal(data: ByteArray): Int? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 8 && wireType == 2 -> { // field 8 (remote_ping_request), wire type 2 (length-delimited)
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)
                        
                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            if (innerField == 1 && innerWire == 0) { // field 1 (val1), wire type 0
                                return readVarint(innerInput)
                            } else {
                                skipField(innerInput, innerWire)
                            }
                        }
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Check if message is a configure request (field 1)
     */
    fun isConfigureRequest(data: ByteArray): Boolean {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                if (fieldNumber == 1) return true
                skipField(input, wireType)
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if message is a set active request (field 2)
     */
    fun isSetActiveRequest(data: ByteArray): Boolean {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                if (fieldNumber == 2) return true
                skipField(input, wireType)
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun readVarint(input: ByteArrayInputStream): Int {
        var result = 0
        var shift = 0

        while (true) {
            val byte = input.read()
            if (byte == -1) break

            result = result or ((byte and 0x7F) shl shift)
            if ((byte and 0x80) == 0) break
            shift += 7
        }

        return result
    }

    private fun readString(input: ByteArrayInputStream): String {
        val length = readVarint(input)
        val bytes = ByteArray(length)
        input.read(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    private fun skipField(input: ByteArrayInputStream, wireType: Int) {
        when (wireType) {
            0 -> readVarint(input) // varint
            1 -> input.skip(8) // 64-bit
            2 -> {
                val length = readVarint(input)
                input.skip(length.toLong()) // length-delimited
            }
            5 -> input.skip(4) // 32-bit
        }
    }

    private const val FIELD_VOICE_BEGIN = 30
    private const val FIELD_VOICE_END = 32

    /**
     * Extract session_id from RemoteVoiceBegin
     */
    fun extractVoiceBeginSessionId(data: ByteArray): Int? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == FIELD_VOICE_BEGIN && wireType == 2 -> { // field 30, length-delimited
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)

                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            if (innerField == 1 && innerWire == 0) { // field 1 (session_id), varint
                                return readVarint(innerInput)
                            } else {
                                skipField(innerInput, innerWire)
                            }
                        }
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Extract session_id from RemoteVoiceEnd
     */
    fun extractVoiceEndSessionId(data: ByteArray): Int? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == FIELD_VOICE_END && wireType == 2 -> { // field 32, length-delimited
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)

                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            if (innerField == 1 && innerWire == 0) { // field 1 (session_id), varint
                                return readVarint(innerInput)
                            } else {
                                skipField(innerInput, innerWire)
                            }
                        }
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Parse code1 (supported features) from RemoteConfigure
     */
    fun parseConfigureFeatures(data: ByteArray): Int? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 1 && wireType == 2 -> { // field 1 (remote_configure), length-delimited
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)

                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            if (innerField == 1 && innerWire == 0) { // field 1 (code1), varint
                                return readVarint(innerInput)
                            } else {
                                skipField(innerInput, innerWire)
                            }
                        }
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    data class ImeCounters(val imeCounter: Int, val fieldCounter: Int)

    fun extractImeCounters(data: ByteArray): ImeCounters? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 21 && wireType == 2 -> { // field 21 (remote_ime_batch_edit), length-delimited
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)

                        var imeCounter = 0
                        var fieldCounter = 0

                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            when {
                                innerField == 1 && innerWire == 0 -> { // field 1 (ime_counter), varint
                                    imeCounter = readVarint(innerInput)
                                }
                                innerField == 2 && innerWire == 0 -> { // field 2 (field_counter), varint
                                    fieldCounter = readVarint(innerInput)
                                }
                                else -> skipField(innerInput, innerWire)
                            }
                        }
                        return ImeCounters(imeCounter, fieldCounter)
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    data class KeyboardFocusState(val isFocused: Boolean, val text: String?)

    fun parseImeShowRequest(data: ByteArray): KeyboardFocusState? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07

                when {
                    fieldNumber == 22 && wireType == 2 -> { // remote_ime_show_request (length-delimited)
                        val length = readVarint(input)
                        val innerBytes = ByteArray(length)
                        input.read(innerBytes)

                        var hasStatus = false
                        var textValue: String? = null

                        val innerInput = ByteArrayInputStream(innerBytes)
                        while (innerInput.available() > 0) {
                            val innerTag = readVarint(innerInput)
                            val innerField = innerTag shr 3
                            val innerWire = innerTag and 0x07
                            when {
                                innerField == 2 && innerWire == 2 -> { // field 2 (remote_text_field_status), length-delimited
                                    hasStatus = true
                                    val statusLen = readVarint(innerInput)
                                    val statusBytes = ByteArray(statusLen)
                                    innerInput.read(statusBytes)

                                    val statusInput = ByteArrayInputStream(statusBytes)
                                    while (statusInput.available() > 0) {
                                        val statusTag = readVarint(statusInput)
                                        val statusField = statusTag shr 3
                                        val statusWire = statusTag and 0x07
                                        when {
                                            statusField == 2 && statusWire == 2 -> { // field 2 (value), string
                                                textValue = readString(statusInput)
                                            }
                                            else -> skipField(statusInput, statusWire)
                                        }
                                    }
                                }
                                else -> skipField(innerInput, innerWire)
                            }
                        }
                        return KeyboardFocusState(isFocused = hasStatus, text = textValue)
                    }
                    else -> skipField(input, wireType)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }
}
