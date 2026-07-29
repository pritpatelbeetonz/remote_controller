package com.waysol.android_tv_remote_package.protocol

import java.io.ByteArrayOutputStream

/**
 * Protobuf message building for Android TV Remote protocol v2
 */
object ProtobufMessage {

    // Message type constants
    private const val PAIRING_REQUEST_TYPE = 1
    private const val SECRET_MESSAGE_TYPE = 2
    private const val KEYCODE_MESSAGE_TYPE = 3
    private const val INPUT_MESSAGE_TYPE = 4

    /**
     * Create pairing request message
     * This is sent when initiating pairing with the TV
     */
    fun createPairingRequest(): ByteArray {
        val out = ByteArrayOutputStream()

        // Message type: PAIRING_REQUEST (1)
        writeVarint(out, 1 shl 3 or 0) // field 1, wire type 0 (varint)
        writeVarint(out, PAIRING_REQUEST_TYPE)

        // Client name (field 2, string)
        val clientName = "android_tv_remote"
        val nameBytes = clientName.toByteArray()
        writeVarint(out, 2 shl 3 or 2) // field 2, wire type 2 (length-delimited)
        writeVarint(out, nameBytes.size)
        out.write(nameBytes)

        return out.toByteArray()
    }

    /**
     * Create secret message with PIN code
     */
    fun createSecretMessage(pin: String): ByteArray {
        val out = ByteArrayOutputStream()

        // Message type: SECRET (2)
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, SECRET_MESSAGE_TYPE)

        // Secret field (field 2, bytes)
        val secretBytes = pin.toByteArray()
        writeVarint(out, 2 shl 3 or 2) // field 2, wire type 2 (length-delimited)
        writeVarint(out, secretBytes.size)
        out.write(secretBytes)

        return out.toByteArray()
    }

    /**
     * Create keycode message for remote commands
     */
    fun createKeycodeMessage(keycode: Int): ByteArray {
        val out = ByteArrayOutputStream()

        // Message type: KEYCODE (3)
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, KEYCODE_MESSAGE_TYPE)

        // Keycode field (field 2, varint)
        writeVarint(out, 2 shl 3 or 0)
        writeVarint(out, keycode)

        return out.toByteArray()
    }

    /**
     * Create text input message
     */
    fun createTextInputMessage(text: String): ByteArray {
        val out = ByteArrayOutputStream()

        // Message type: TEXT_INPUT (4)
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, INPUT_MESSAGE_TYPE)

        // Text field (field 2, string)
        val textBytes = text.toByteArray()
        writeVarint(out, 2 shl 3 or 2)
        writeVarint(out, textBytes.size)
        out.write(textBytes)

        return out.toByteArray()
    }

    /**
     * Create application link / deep link launch message
     */
    fun createAppLinkMessage(appLink: String): ByteArray {
        val innerOut = ByteArrayOutputStream()
        val linkBytes = appLink.toByteArray()
        // field 1 (app_link), wire type 2 (length-delimited)
        writeVarint(innerOut, 1 shl 3 or 2)
        writeVarint(innerOut, linkBytes.size)
        innerOut.write(linkBytes)

        val innerBytes = innerOut.toByteArray()

        val out = ByteArrayOutputStream()
        // field 90 (remote_app_link_launch_request), wire type 2 (length-delimited)
        writeVarint(out, 90 shl 3 or 2)
        writeVarint(out, innerBytes.size)
        out.write(innerBytes)

        return out.toByteArray()
    }

    /**
     * Write variable-length integer (varint) to ByteArrayOutputStream
     */
    private fun writeVarint(out: ByteArrayOutputStream, value: Int) {
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            out.write((v and 0x7F) or 0x80)
            v = v ushr 7
        }
        out.write(v and 0x7F)
    }
}
