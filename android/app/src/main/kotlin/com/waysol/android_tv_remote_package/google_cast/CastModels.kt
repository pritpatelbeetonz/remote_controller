package com.waysol.android_tv_remote_package.google_cast

data class CastDevice(
    val id: String,
    val name: String,
    val modelName: String
) {
    fun toMap(): Map<String, String> {
        return mapOf(
            "id" to id,
            "name" to name,
            "modelName" to modelName
        )
    }
}
