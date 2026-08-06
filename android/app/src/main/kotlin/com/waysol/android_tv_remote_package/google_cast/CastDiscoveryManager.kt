package com.waysol.android_tv_remote_package.google_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastDevice as GmsCastDevice
import com.google.android.gms.cast.framework.CastContext
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger

class CastDiscoveryManager(
    private val context: Context,
    private val onDevicesUpdated: (List<CastDevice>) -> Unit
) {
    private val mediaRouter = MediaRouter.getInstance(context)
    private var routeSelector: MediaRouteSelector? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeDevices = mutableMapOf<String, CastDevice>()

    private val routeCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) {
            updateRoute(route)
        }

        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) {
            removeRoute(route)
        }

        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
            updateRoute(route)
        }
    }

    init {
        try {
            val castContext = CastContext.getSharedInstance(context)
            routeSelector = castContext.mergedSelector
        } catch (e: Exception) {
            Logger.e(Constants.TAG_PLUGIN, "Failed to initialize CastContext selector: ${e.message}")
        }
    }

    fun startDiscovery() {
        val selector = routeSelector
        if (selector == null) {
            Logger.e(Constants.TAG_PLUGIN, "Cannot start Cast discovery: selector is null")
            return
        }

        mainHandler.post {
            Logger.d(Constants.TAG_PLUGIN, "🔍 Starting Cast discovery...")
            activeDevices.clear()
            // Scan current routes already in MediaRouter
            for (route in mediaRouter.routes) {
                if (route.matchesSelector(selector)) {
                    updateRoute(route)
                }
            }
            mediaRouter.addCallback(
                selector,
                routeCallback,
                MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY
            )
        }
    }

    fun stopDiscovery() {
        mainHandler.post {
            Logger.d(Constants.TAG_PLUGIN, "🛑 Stopping Cast discovery...")
            mediaRouter.removeCallback(routeCallback)
        }
    }

    fun getDiscoveredRoutes(): List<MediaRouter.RouteInfo> {
        val selector = routeSelector ?: return emptyList()
        return mediaRouter.routes.filter { it.matchesSelector(selector) }
    }

    private fun updateRoute(route: MediaRouter.RouteInfo) {
        val castDevice = GmsCastDevice.getFromBundle(route.extras) ?: return
        val device = CastDevice(
            id = route.id,
            name = route.name,
            modelName = castDevice.modelName ?: "Chromecast"
        )
        Logger.d(Constants.TAG_PLUGIN, "📡 Cast: Discovered/Updated route: ${route.name} (${route.id})")
        activeDevices[route.id] = device
        notifyUpdates()
    }

    private fun removeRoute(route: MediaRouter.RouteInfo) {
        if (activeDevices.containsKey(route.id)) {
            Logger.d(Constants.TAG_PLUGIN, "🗑️ Cast: Route removed: ${route.name} (${route.id})")
            activeDevices.remove(route.id)
            notifyUpdates()
        }
    }

    private fun notifyUpdates() {
        val list = activeDevices.values.toList()
        Logger.d(Constants.TAG_PLUGIN, "📊 Cast: Active discovered devices list size: ${list.size}")
        onDevicesUpdated(list)
    }
}
