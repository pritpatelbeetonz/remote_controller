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
            if (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                return fieldNumber == 1
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
            if (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                return fieldNumber == 2
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
}
