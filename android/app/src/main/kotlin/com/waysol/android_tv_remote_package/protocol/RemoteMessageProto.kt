package com.waysol.android_tv_remote_package.protocol

/**
 * Protobuf message structure for Android TV Remote v2
 * Bare-bones protobuf implementation without code generation
 *
 * Message format:
 * - Message Type (varint, field 1)
 * - Payload (varies by message type, field 2+)
 *
 * Wire types:
 * 0 = varint
 * 1 = 64-bit
 * 2 = length-delimited
 * 5 = 32-bit
 */
object RemoteMessageProto {

    // Message types
    const val MSG_TYPE_PAIRING_REQUEST = 1
    const val MSG_TYPE_SECRET = 2
    const val MSG_TYPE_KEYCODE = 3
    const val MSG_TYPE_TEXT_INPUT = 4
    const val MSG_TYPE_PAIRING_RESPONSE = 5

    /**
     * Build varint encoded value
     */
    fun varint(value: Int): ByteArray {
        val bytes = mutableListOf<Byte>()
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            bytes.add(((v and 0x7F) or 0x80).toByte())
            v = v ushr 7
        }
        bytes.add((v and 0x7F).toByte())
        return bytes.toByteArray()
    }

    /**
     * Build field tag (field number + wire type)
     */
    fun fieldTag(fieldNumber: Int, wireType: Int): ByteArray {
        return varint((fieldNumber shl 3) or wireType)
    }

    /**
     * Encode a string field
     */
    fun stringField(fieldNumber: Int, value: String): ByteArray {
        val stringBytes = value.toByteArray(Charsets.UTF_8)
        return fieldTag(fieldNumber, 2) + varint(stringBytes.size) + stringBytes
    }

    /**
     * Encode a bytes field
     */
    fun bytesField(fieldNumber: Int, value: ByteArray): ByteArray {
        return fieldTag(fieldNumber, 2) + varint(value.size) + value
    }

    /**
     * Encode a varint field
     */
    fun varintField(fieldNumber: Int, value: Int): ByteArray {
        return fieldTag(fieldNumber, 0) + varint(value)
    }

    /**
     * Build complete message with type
     */
    fun buildMessage(messageType: Int, vararg fields: ByteArray): ByteArray {
        val typeField = varintField(1, messageType)
        val payload = typeField + fields.fold(ByteArray(0)) { acc, bytes -> acc + bytes }
        return payload
    }
}