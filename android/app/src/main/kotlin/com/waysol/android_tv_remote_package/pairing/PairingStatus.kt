package com.waysol.android_tv_remote_package.pairing

enum class PairingStatus {
    IDLE,
    CONNECTING,
    WAITING_PIN,
    PAIRING,
    SUCCESS,
    FAILED,
    TIMEOUT,
    CANCELLED
}