package com.waysol.android_tv_remote_package.google_cast

import android.content.Context
import com.google.android.gms.cast.framework.CastContext

class CastManager private constructor(context: Context) {

    companion object {
        @Volatile
        private var instance: CastManager? = null

        fun getInstance(context: Context): CastManager {
            return instance ?: synchronized(this) {
                instance ?: CastManager(context.applicationContext).also { instance = it }
            }
        }
    }

    // Initialize CastContext early to ensure options are loaded
    private val castContext: CastContext? = try {
        CastContext.getSharedInstance(context)
    } catch (e: Exception) {
        null
    }

    var onStateChangedListener: ((String) -> Unit)? = null
    var onDevicesUpdatedListener: ((List<CastDevice>) -> Unit)? = null

    val discoveryManager = CastDiscoveryManager(context) { devices ->
        onDevicesUpdatedListener?.invoke(devices)
    }

    val sessionManager = CastSessionManager(context, discoveryManager) { state ->
        onStateChangedListener?.invoke(state)
    }

    val mediaManager = CastMediaManager(context, sessionManager)
}
