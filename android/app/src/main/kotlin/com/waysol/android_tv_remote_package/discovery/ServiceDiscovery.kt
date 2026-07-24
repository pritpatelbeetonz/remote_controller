package com.waysol.android_tv_remote_package.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.waysol.android_tv_remote_package.model.TVDevice
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import kotlinx.coroutines.*
import java.util.concurrent.CopyOnWriteArrayList

class ServiceDiscovery(
    private val context: Context,
    private val nsdManager: NsdManager
) {

    private val discoveredDevices = CopyOnWriteArrayList<TVDevice>()
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var resolveListener: NsdManager.ResolveListener? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val callbacks = mutableListOf<(List<TVDevice>) -> Unit>()

    /**
     * Start discovering Android TV devices
     */
    fun startDiscovery(
        timeout: Long = Constants.DISCOVERY_TIMEOUT_MS,
        onDiscoveryComplete: (List<TVDevice>) -> Unit = {}
    ) {
        discoveredDevices.clear()
        callbacks.add(onDiscoveryComplete)

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Logger.d(Constants.TAG_DISCOVERY, "Discovery started for $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Logger.d(Constants.TAG_DISCOVERY, "Service found: ${serviceInfo.serviceName}")
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Logger.d(Constants.TAG_DISCOVERY, "Service lost: ${serviceInfo.serviceName}")
                discoveredDevices.removeAll { it.hostname == serviceInfo.serviceName }
                notifyCallbacks()
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Logger.d(Constants.TAG_DISCOVERY, "Discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Discovery failed: $errorCode")
                stopDiscovery()
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Stop discovery failed: $errorCode")
            }
        }

        try {
            nsdManager.discoverServices(
                Constants.MDNS_SERVICE_TYPE,
                NsdManager.PROTOCOL_DNS_SD,
                discoveryListener
            )

            // Auto-stop after timeout
            scope.launch {
                delay(timeout)
                stopDiscovery()
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Discovery error: ${e.message}", e)
        }
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        resolveListener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Resolve failed for ${serviceInfo.serviceName}: $errorCode")
            }

            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                Logger.d(Constants.TAG_DISCOVERY, "Service resolved: ${serviceInfo.serviceName}")

                val device = TVDevice(
                    name = serviceInfo.serviceName.split(".")[0],
                    hostname = serviceInfo.serviceName,
                    ipAddress = serviceInfo.host?.hostAddress ?: return,
                    port = serviceInfo.port
                )

                if (!discoveredDevices.any { it.ipAddress == device.ipAddress }) {
                    discoveredDevices.add(device)
                    Logger.i(Constants.TAG_DISCOVERY, "Device added: ${device.name} at ${device.ipAddress}:${device.port}")
                    notifyCallbacks()
                }
            }
        }

        try {
            nsdManager.resolveService(serviceInfo, resolveListener)
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Resolve error: ${e.message}")
        }
    }

    fun stopDiscovery() {
        try {
            discoveryListener?.let {
                nsdManager.stopServiceDiscovery(it)
            }
            Logger.d(Constants.TAG_DISCOVERY, "Discovery stopped")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Stop error: ${e.message}")
        }
    }

    fun getDiscoveredDevices(): List<TVDevice> = discoveredDevices.toList()

    private fun notifyCallbacks() {
        callbacks.forEach { it(discoveredDevices.toList()) }
    }

    fun destroy() {
        try {
            stopDiscovery()
            scope.cancel()
            callbacks.clear()
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Destroy error: ${e.message}")
        }
    }
}