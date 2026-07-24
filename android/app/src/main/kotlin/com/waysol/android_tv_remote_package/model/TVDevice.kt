package com.waysol.android_tv_remote_package.model

data class TVDevice(
    val name: String,
    val hostname: String,
    val ipAddress: String,
    val port: Int
)