package com.waysol.android_tv_remote_package.util

object Constants {
    // Service Discovery
    const val MDNS_SERVICE_TYPE = "_androidtvremote2._tcp"
    const val DISCOVERY_TIMEOUT_MS = 10000L
    const val NSD_RESOLVE_TIMEOUT_MS = 5000L

    // Connection
    const val PORT_PAIRING = 6467
    const val PORT_CONTROL = 6466
    const val CONNECTION_TIMEOUT_MS = 30000L
    const val READ_TIMEOUT_MS = 5000L

    // TLS
    const val TLS_VERSION = "TLSv1.2"
    const val CIPHER_SUITE_1 = "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    const val CIPHER_SUITE_2 = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"

    // Pairing
    const val PAIRING_TIMEOUT_SEC = 60L
    const val PIN_DISPLAY_TIMEOUT_SEC = 30L
    const val PIN_LENGTH = 6

    // Certificates
    const val CERT_DER_FILENAME = "cert.der"
    const val CERT_P12_FILENAME = "cert.p12"
    const val CERT_VALIDITY_DAYS = 1825 // ~5 years

    // Protocol
    const val FRAME_HEADER_SIZE = 4 // 4-byte length prefix
    const val MAX_FRAME_SIZE = 65536
    const val KEYCODE_REPEAT_DELAY_MS = 100L

    // Logging Tags
    const val TAG_DISCOVERY = "TVDiscovery"
    const val TAG_CONNECTION = "TVConnection"
    const val TAG_TLS = "TVTLS"
    const val TAG_PAIRING = "TVPairing"
    const val TAG_PROTOCOL = "TVProtocol"
    const val TAG_REMOTE = "TVRemote"
    const val TAG_PLUGIN = "TVPlugin"
}