package com.waysol.android_tv_remote_package.protocol

import java.io.ByteArrayOutputStream

/**
 * Protobuf message building for Android TV Remote protocol v2
 */
object ProtobufMessage {

    // Helper to write varint to stream
    private fun writeVarint(out: ByteArrayOutputStream, value: Int) {
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            out.write((v and 0x7F) or 0x80)
            v = v ushr 7
        }
        out.write(v and 0x7F)
    }

    // Helper to build a length-delimited field
    private fun buildLengthDelimitedField(fieldNumber: Int, value: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, (fieldNumber shl 3) or 2)
        writeVarint(out, value.size)
        out.write(value)
        return out.toByteArray()
    }

    // Helper to build a varint field
    private fun buildVarintField(fieldNumber: Int, value: Int): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, (fieldNumber shl 3) or 0)
        writeVarint(out, value)
        return out.toByteArray()
    }

    // Helper to build a string field
    private fun buildStringField(fieldNumber: Int, value: String): ByteArray {
        return buildLengthDelimitedField(fieldNumber, value.toByteArray(Charsets.UTF_8))
    }

    // Polo OuterMessage prefix: version = 2 (field 1, varint), status = STATUS_OK / 200 (field 2, varint)
    private fun getPoloPrefix(): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, (1 shl 3) or 0)
        writeVarint(out, 2) // protocol_version = 2
        writeVarint(out, (2 shl 3) or 0)
        writeVarint(out, 200) // status = STATUS_OK (200)
        return out.toByteArray()
    }

    /**
     * Create pairing request message (OuterMessage wrapper)
     */
    fun createPairingRequest(clientName: String = "android_tv_remote"): ByteArray {
        val pairingRequestOut = ByteArrayOutputStream()
        pairingRequestOut.write(buildStringField(1, "atvremote")) // service_name
        pairingRequestOut.write(buildStringField(2, clientName)) // client_name
        
        val out = ByteArrayOutputStream()
        out.write(getPoloPrefix())
        out.write(buildLengthDelimitedField(10, pairingRequestOut.toByteArray())) // pairing_request
        return out.toByteArray()
    }

    /**
     * Create options message (OuterMessage wrapper)
     */
    fun createOptionsMessage(): ByteArray {
        val encodingOut = ByteArrayOutputStream()
        encodingOut.write(buildVarintField(1, 3)) // ENCODING_TYPE_HEXADECIMAL = 3
        encodingOut.write(buildVarintField(2, 6)) // symbol_length = 6

        val optionsOut = ByteArrayOutputStream()
        optionsOut.write(buildLengthDelimitedField(1, encodingOut.toByteArray())) // input_encodings
        optionsOut.write(buildVarintField(3, 1)) // preferred_role = ROLE_TYPE_INPUT (1)

        val out = ByteArrayOutputStream()
        out.write(getPoloPrefix())
        out.write(buildLengthDelimitedField(20, optionsOut.toByteArray())) // options
        return out.toByteArray()
    }

    /**
     * Create configuration message (OuterMessage wrapper)
     */
    fun createConfigurationMessage(): ByteArray {
        val encodingOut = ByteArrayOutputStream()
        encodingOut.write(buildVarintField(1, 3)) // ENCODING_TYPE_HEXADECIMAL = 3
        encodingOut.write(buildVarintField(2, 6)) // symbol_length = 6

        val configOut = ByteArrayOutputStream()
        configOut.write(buildLengthDelimitedField(1, encodingOut.toByteArray())) // encoding
        configOut.write(buildVarintField(2, 1)) // client_role = ROLE_TYPE_INPUT (1)

        val out = ByteArrayOutputStream()
        out.write(getPoloPrefix())
        out.write(buildLengthDelimitedField(30, configOut.toByteArray())) // configuration
        return out.toByteArray()
    }

    /**
     * Create secret message with PIN verification hash (OuterMessage wrapper)
     */
    fun createSecretMessage(hashBytes: ByteArray): ByteArray {
        val secretOut = ByteArrayOutputStream()
        secretOut.write(buildLengthDelimitedField(1, hashBytes)) // secret

        val out = ByteArrayOutputStream()
        out.write(getPoloPrefix())
        out.write(buildLengthDelimitedField(40, secretOut.toByteArray())) // secret (field 40)
        return out.toByteArray()
    }

    /**
     * Create keycode message for remote commands (RemoteMessage wrapper)
     */
    fun createKeycodeMessage(keycode: Int, direction: Int = 3): ByteArray { // Default direction 3 = SHORT
        val keyInjectOut = ByteArrayOutputStream()
        keyInjectOut.write(buildVarintField(1, keycode))
        keyInjectOut.write(buildVarintField(2, direction))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(10, keyInjectOut.toByteArray())) // remote_key_inject
        return out.toByteArray()
    }

    /**
     * Create application link / deep link launch message (RemoteMessage wrapper)
     */
    fun createAppLinkMessage(appLink: String): ByteArray {
        val appLinkOut = ByteArrayOutputStream()
        appLinkOut.write(buildStringField(1, appLink))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(90, appLinkOut.toByteArray())) // remote_app_link_launch_request
        return out.toByteArray()
    }

    /**
     * Create pong message to reply to keepalive ping requests (RemoteMessage wrapper)
     */
    fun createPongMessage(val1: Int): ByteArray {
        val pingResponseOut = ByteArrayOutputStream()
        pingResponseOut.write(buildVarintField(1, val1))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(9, pingResponseOut.toByteArray())) // remote_ping_response
        return out.toByteArray()
    }

    /**
     * Create configure response (RemoteMessage wrapper)
     */
    fun createConfigureResponse(): ByteArray {
        val deviceInfoOut = ByteArrayOutputStream()
        deviceInfoOut.write(buildStringField(1, "Android"))      // model
        deviceInfoOut.write(buildStringField(2, "Waysol"))        // vendor
        deviceInfoOut.write(buildVarintField(3, 1))               // unknown1 = 1
        deviceInfoOut.write(buildStringField(4, "1"))              // unknown2 = "1"
        deviceInfoOut.write(buildStringField(5, "atvremote")) // package_name
        deviceInfoOut.write(buildStringField(6, "1.0.0"))          // app_version

        val configOut = ByteArrayOutputStream()
        configOut.write(buildVarintField(1, 622)) // code1 = active features
        configOut.write(buildLengthDelimitedField(2, deviceInfoOut.toByteArray())) // device_info

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(1, configOut.toByteArray())) // remote_configure
        return out.toByteArray()
    }

    /**
     * Create active response (RemoteMessage wrapper)
     */
    fun createActiveResponse(): ByteArray {
        val activeOut = ByteArrayOutputStream()
        activeOut.write(buildVarintField(1, 622)) // active = 622

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(2, activeOut.toByteArray())) // remote_set_active
        return out.toByteArray()
    }

    private const val FIELD_VOICE_BEGIN = 30
    private const val FIELD_VOICE_PAYLOAD = 31
    private const val FIELD_VOICE_END = 32

    /**
     * Create voice begin message
     */
    fun createVoiceBeginMessage(sessionId: Int): ByteArray {
        val voiceBeginOut = ByteArrayOutputStream()
        voiceBeginOut.write(buildVarintField(1, sessionId))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(FIELD_VOICE_BEGIN, voiceBeginOut.toByteArray()))
        return out.toByteArray()
    }

    /**
     * Create voice payload message
     */
    fun createVoicePayloadMessage(sessionId: Int, samples: ByteArray): ByteArray {
        val voicePayloadOut = ByteArrayOutputStream()
        voicePayloadOut.write(buildVarintField(1, sessionId))
        voicePayloadOut.write(buildLengthDelimitedField(2, samples))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(FIELD_VOICE_PAYLOAD, voicePayloadOut.toByteArray()))
        return out.toByteArray()
    }

    /**
     * Create voice end message
     */
    fun createVoiceEndMessage(sessionId: Int): ByteArray {
        val voiceEndOut = ByteArrayOutputStream()
        voiceEndOut.write(buildVarintField(1, sessionId))

        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(FIELD_VOICE_END, voiceEndOut.toByteArray()))
        return out.toByteArray()
    }

    private const val FIELD_IME_BATCH_EDIT = 21

    /**
     * Create IME batch edit message to transmit text (RemoteMessage wrapper)
     */
    fun createImeBatchEditMessage(imeCounter: Int, fieldCounter: Int, text: String): ByteArray {
        val textLength = text.length
        val paramValue = if (textLength > 0) textLength - 1 else 0

        // 1. Build RemoteImeObject
        val imeObjOut = ByteArrayOutputStream()
        imeObjOut.write(buildVarintField(1, paramValue)) // start = paramValue
        imeObjOut.write(buildVarintField(2, paramValue)) // end = paramValue
        imeObjOut.write(buildStringField(3, text))       // value = text

        // 2. Build RemoteEditInfo
        val editInfoOut = ByteArrayOutputStream()
        editInfoOut.write(buildVarintField(1, 1))        // insert = 1
        editInfoOut.write(buildLengthDelimitedField(2, imeObjOut.toByteArray())) // text_field_status

        // 3. Build RemoteImeBatchEdit
        val batchEditOut = ByteArrayOutputStream()
        batchEditOut.write(buildVarintField(1, imeCounter))   // ime_counter
        batchEditOut.write(buildVarintField(2, fieldCounter)) // field_counter
        batchEditOut.write(buildLengthDelimitedField(3, editInfoOut.toByteArray())) // edit_info (repeated)

        // 4. Build Outer RemoteMessage wrapper
        val out = ByteArrayOutputStream()
        out.write(buildLengthDelimitedField(FIELD_IME_BATCH_EDIT, batchEditOut.toByteArray())) // remote_ime_batch_edit (field 21)
        return out.toByteArray()
    }
}
