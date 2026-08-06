package com.waysol.android_tv_remote_package.protocol

import java.io.ByteArrayOutputStream
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger

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

        Logger.i(Constants.TAG_PROTOBUF, "========== Creating Voice Payload ==========")
        Logger.i(Constants.TAG_PROTOBUF, "Session ID        : $sessionId")
        Logger.i(Constants.TAG_PROTOBUF, "Audio Bytes       : ${samples.size}")

        val voicePayloadOut = ByteArrayOutputStream()

        // Field 1 -> Session ID
        val sessionField = buildVarintField(1, sessionId)
        Logger.i(
            Constants.TAG_PROTOBUF,
            "Field 1 (Session) : ${
                sessionField.joinToString(" ") { "%02X".format(it) }
            }"
        )
        voicePayloadOut.write(sessionField)

        // Field 2 -> Audio Samples
        val audioField = buildLengthDelimitedField(2, samples)
        Logger.i(
            Constants.TAG_PROTOBUF,
            "Field 2 Header    : ${
                audioField.take(10).joinToString(" ") { "%02X".format(it) }
            } ..."
        )
        Logger.i(Constants.TAG_PROTOBUF, "Field 2 Total Size: ${audioField.size}")

        voicePayloadOut.write(audioField)

        val innerPayload = voicePayloadOut.toByteArray()

        Logger.i(
            Constants.TAG_PROTOBUF,
            "Inner Payload (${innerPayload.size} bytes): ${
                innerPayload.take(40).joinToString(" ") { "%02X".format(it) }
            } ..."
        )

        val out = ByteArrayOutputStream()

        val wrappedPayload =
            buildLengthDelimitedField(FIELD_VOICE_PAYLOAD, innerPayload)

        out.write(wrappedPayload)

        val finalMessage = out.toByteArray()

        Logger.i(
            Constants.TAG_PROTOBUF,
            "Final Message (${finalMessage.size} bytes): ${
                finalMessage.take(40).joinToString(" ") { "%02X".format(it) }
            } ..."
        )

        Logger.i(Constants.TAG_PROTOBUF, "========== Voice Payload Created ==========")

        return finalMessage
    }

    /**
     * Emit a protobuf wire-format summary for a voice payload without dumping PCM bytes.
     *
     * This is intended for byte-level comparison against a reference implementation.
     */
    fun logVoicePayloadWireFormat(sessionId: Int, samples: ByteArray, serialized: ByteArray) {
        val inner = decodeLengthDelimitedPayload(serialized, FIELD_VOICE_PAYLOAD)
        if (inner == null) {
            Logger.w(
                Constants.TAG_PROTOBUF,
                "Voice payload wire dump failed: could not decode outer field $FIELD_VOICE_PAYLOAD"
            )
            return
        }

        val (outerLength, innerBytes) = inner
        val sessionField = decodeVarintField(innerBytes, 1)
        val samplesField = decodeLengthDelimitedField(innerBytes, 2)

        val sessionSummary = if (sessionField != null) {
            "field=1 wire=0 value=${sessionField.second} bytes=${sessionField.first.toHexString()}"
        } else {
            "field=1 wire=0 <missing>"
        }
        val samplesSummary = if (samplesField != null) {
            "field=2 wire=2 length=${samplesField.second.size} lengthBytes=${samplesField.first.toHexString()} payload=<omitted>"
        } else {
            "field=2 wire=2 <missing>"
        }

        Logger.i(
            Constants.TAG_PROTOBUF,
            buildString {
                appendLine("Voice payload wire dump")
                appendLine("session_id=$sessionId")
                appendLine("samples_length=${samples.size}")
                appendLine("outer_field=31 wire=2 outer_length=$outerLength")
                appendLine("outer_tag=${encodeFieldTag(31, 2).toHexString()}")
                appendLine("inner_fields:")
                appendLine("  $sessionSummary")
                appendLine("  $samplesSummary")
                append("serialized_prefix=${serialized.prefixHex(16)}")
                if (serialized.size > 16) {
                    append(" ...")
                }
            }
        )
    }

    private fun encodeFieldTag(fieldNumber: Int, wireType: Int): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, (fieldNumber shl 3) or wireType)
        return out.toByteArray()
    }

    private fun decodeLengthDelimitedPayload(
        data: ByteArray,
        expectedFieldNumber: Int
    ): Pair<Int, ByteArray>? {
        var offset = 0
        val (tagValue, tagNext) = readVarint(data, offset) ?: return null
        offset = tagNext
        val fieldNumber = tagValue ushr 3
        val wireType = tagValue and 0x07
        if (fieldNumber != expectedFieldNumber || wireType != 2) {
            return null
        }

        val (length, lengthNext) = readVarint(data, offset) ?: return null
        offset = lengthNext
        if (offset + length > data.size) {
            return null
        }
        return length to data.copyOfRange(offset, offset + length)
    }

    private fun decodeVarintField(data: ByteArray, expectedFieldNumber: Int): Pair<ByteArray, Int>? {
        var offset = 0
        val (tagValue, tagNext) = readVarint(data, offset) ?: return null
        offset = tagNext
        val fieldNumber = tagValue ushr 3
        val wireType = tagValue and 0x07
        if (fieldNumber != expectedFieldNumber || wireType != 0) {
            return null
        }
        val (value, valueNext) = readVarint(data, offset) ?: return null
        return data.copyOfRange(0, valueNext) to value
    }

    private fun decodeLengthDelimitedField(data: ByteArray, expectedFieldNumber: Int): Pair<ByteArray, ByteArray>? {
        var offset = 0
        val (tagValue, tagNext) = readVarint(data, offset) ?: return null
        offset = tagNext
        val fieldNumber = tagValue ushr 3
        val wireType = tagValue and 0x07
        if (fieldNumber != expectedFieldNumber || wireType != 2) {
            return null
        }
        val (length, lengthNext) = readVarint(data, offset) ?: return null
        offset = lengthNext
        if (offset + length > data.size) {
            return null
        }
        return data.copyOfRange(0, lengthNext) to data.copyOfRange(offset, offset + length)
    }

    private fun readVarint(data: ByteArray, start: Int): Pair<Int, Int>? {
        var result = 0
        var shift = 0
        var offset = start
        while (offset < data.size && shift < 35) {
            val b = data[offset].toInt() and 0xFF
            result = result or ((b and 0x7F) shl shift)
            offset++
            if ((b and 0x80) == 0) {
                return result to offset
            }
            shift += 7
        }
        return null
    }

    private fun ByteArray.toHexString(): String {
        return joinToString(" ") { byte -> "%02X".format(byte) }
    }

    private fun ByteArray.prefixHex(limit: Int): String {
        val slice = if (size <= limit) this else copyOfRange(0, limit)
        return slice.toHexString()
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
