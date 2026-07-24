package com.waysol.android_tv_remote_package.protocol

import java.io.ByteArrayInputStream

/**
 * Parse incoming protobuf messages from Android TV
 */
object MessageParser {

    /**
     * Extract PIN code from TV response
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
                    fieldNumber == 1 && wireType == 0 -> { // status field
                        val status = readVarint(input)
                        return status == 1 // 1 = SUCCESS
                    }
                    else -> skipField(input, wireType)
                }
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
