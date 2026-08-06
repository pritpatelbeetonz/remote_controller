package com.waysol.android_tv_remote_package.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.waysol.android_tv_remote_package.model.TVDevice
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger
import android.net.wifi.WifiManager
import kotlinx.coroutines.*
import java.util.concurrent.CopyOnWriteArrayList

class DeviceScanner(
    private val context: Context,
    private val nsdManager: NsdManager
) {

    private val discoveredDevices = CopyOnWriteArrayList<TVDevice>()
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var resolveListener: NsdManager.ResolveListener? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var multicastLock: WifiManager.MulticastLock? = null

    private val callbacks = mutableListOf<(List<TVDevice>) -> Unit>()

    fun startDiscovery(
        timeout: Long = 10000,
        onDiscoveryComplete: (List<TVDevice>) -> Unit = {}
    ) {
        Logger.i(Constants.TAG_DISCOVERY, "Discovery started")
        Logger.i(Constants.TAG_DISCOVERY, "Acquiring multicast lock")
        
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("AndroidTVRemoteScannerLock").apply {
                setReferenceCounted(true)
                acquire()
            }
            Logger.i(Constants.TAG_DISCOVERY, "Multicast lock acquired")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Discovery failed to acquire multicast lock: ${e.message}", e)
        }

        discoveredDevices.clear()
        callbacks.add(onDiscoveryComplete)

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Logger.i(Constants.TAG_DISCOVERY, "Searching for $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Logger.i(Constants.TAG_DISCOVERY, "Service found:\n" +
                    "Service Name: ${serviceInfo.serviceName}\n" +
                    "Service Type: ${serviceInfo.serviceType}")
                Logger.i(Constants.TAG_DISCOVERY, "Resolving service: ${serviceInfo.serviceName}")
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Logger.i(Constants.TAG_DISCOVERY, "Service lost: ${serviceInfo.serviceName}")
                discoveredDevices.removeAll { it.hostname == serviceInfo.serviceName }
                notifyCallbacks()
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Logger.i(Constants.TAG_DISCOVERY, "Discovery completed")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Discovery failed: Start discovery failed with error code $errorCode")
                stopDiscovery()
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Stop discovery failed with error code: $errorCode")
            }
        }

        try {
            nsdManager.discoverServices(
                Constants.MDNS_SERVICE_TYPE,
                NsdManager.PROTOCOL_DNS_SD,
                discoveryListener
            )
            Logger.d(Constants.TAG_DISCOVERY, "mDNS Discovery started continuously (no auto-timeout).")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Discovery failed: ${e.message}", e)
        }
    }

    private val resolveQueue = java.util.concurrent.ConcurrentLinkedQueue<NsdServiceInfo>()
    private var isResolving = java.util.concurrent.atomic.AtomicBoolean(false)

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        resolveQueue.add(serviceInfo)
        processNextResolve()
    }

    private fun processNextResolve() {
        if (resolveQueue.isEmpty() || !isResolving.compareAndSet(false, true)) {
            return
        }

        val serviceInfo = resolveQueue.poll()
        if (serviceInfo == null) {
            isResolving.set(false)
            return
        }

        val listener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(resolvedInfo: NsdServiceInfo, errorCode: Int) {
                Logger.e(Constants.TAG_DISCOVERY, "Resolve failed for ${resolvedInfo.serviceName} with error code: $errorCode")
                isResolving.set(false)
                processNextResolve()
            }

            override fun onServiceResolved(resolvedInfo: NsdServiceInfo) {
                Logger.i(Constants.TAG_DISCOVERY, "Resolve successful:\n" +
                    "Service Name: ${resolvedInfo.serviceName}\n" +
                    "Hostname: ${resolvedInfo.host?.hostName ?: "Unknown"}\n" +
                    "IP: ${resolvedInfo.host?.hostAddress ?: "Unknown"}\n" +
                    "Port: ${resolvedInfo.port}")

                val device = TVDevice(
                    name = resolvedInfo.serviceName.split(".")[0],
                    hostname = resolvedInfo.serviceName,
                    ipAddress = resolvedInfo.host?.hostAddress ?: "",
                    port = resolvedInfo.port
                )

                if (device.ipAddress.isNotEmpty() && !discoveredDevices.any { it.ipAddress == device.ipAddress }) {
                    discoveredDevices.add(device)
                    Logger.i(Constants.TAG_DISCOVERY, "TV added to discovered list: ${device.name} (${device.ipAddress})")
                    notifyCallbacks()
                }

                isResolving.set(false)
                processNextResolve()
            }
        }

        try {
            nsdManager.resolveService(serviceInfo, listener)
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Error invoking resolveService: ${e.message}", e)
            isResolving.set(false)
            processNextResolve()
        }
    }

    fun stopDiscovery() {
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                    Logger.i(Constants.TAG_DISCOVERY, "Released multicast lock")
                }
            }
            multicastLock = null
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Failed to release multicast lock: ${e.message}", e)
        }
        try {
            discoveryListener?.let {
                nsdManager.stopServiceDiscovery(it)
            }
            Logger.i(Constants.TAG_DISCOVERY, "Discovery stopped")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Stop error: ${e.message}", e)
        }
    }

    fun getDiscoveredDevices(): List<TVDevice> = discoveredDevices.toList()

    private fun notifyCallbacks() {
        callbacks.forEach { it(discoveredDevices.toList()) }
    }

    fun destroy() {
        stopDiscovery()
        scope.cancel()
        callbacks.clear()
    }

    companion object {
        private const val TAG = "DeviceScanner"
    }
}