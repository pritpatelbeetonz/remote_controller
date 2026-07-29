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
        Logger.d(Constants.TAG_DISCOVERY, "startDiscovery called with timeout: $timeout")
        
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("AndroidTVRemoteScannerLock").apply {
                setReferenceCounted(true)
                acquire()
            }
            Logger.d(Constants.TAG_DISCOVERY, "Acquired multicast lock")
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Failed to acquire multicast lock: ${e.message}")
        }

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

            scope.launch {
                try {
                    Logger.d(Constants.TAG_DISCOVERY, "Coroutine: delay starting for $timeout ms")
                    delay(timeout)
                    Logger.d(Constants.TAG_DISCOVERY, "Coroutine: delay finished")
                    stopDiscovery()
                } catch (e: CancellationException) {
                    Logger.d(Constants.TAG_DISCOVERY, "Coroutine: delay cancelled: ${e.message}")
                    throw e
                } catch (e: Exception) {
                    Logger.e(Constants.TAG_DISCOVERY, "Coroutine: delay error: ${e.message}", e)
                }
            }
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Discovery error: ${e.message}", e)
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
                Logger.e(Constants.TAG_DISCOVERY, "Resolve failed: $errorCode")
                isResolving.set(false)
                processNextResolve()
            }

            override fun onServiceResolved(resolvedInfo: NsdServiceInfo) {
                Logger.d(Constants.TAG_DISCOVERY, "Service resolved: ${resolvedInfo.serviceName}")

                val device = TVDevice(
                    name = resolvedInfo.serviceName.split(".")[0],
                    hostname = resolvedInfo.serviceName,
                    ipAddress = resolvedInfo.host?.hostAddress ?: "",
                    port = resolvedInfo.port
                )

                if (device.ipAddress.isNotEmpty() && !discoveredDevices.any { it.ipAddress == device.ipAddress }) {
                    discoveredDevices.add(device)
                    notifyCallbacks()
                }

                isResolving.set(false)
                processNextResolve()
            }
        }

        try {
            nsdManager.resolveService(serviceInfo, listener)
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Error invoking resolveService: ${e.message}")
            isResolving.set(false)
            processNextResolve()
        }
    }

    fun stopDiscovery() {
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                    Logger.d(Constants.TAG_DISCOVERY, "Released multicast lock")
                }
            }
            multicastLock = null
        } catch (e: Exception) {
            Logger.e(Constants.TAG_DISCOVERY, "Failed to release multicast lock: ${e.message}")
        }
        try {
            Logger.d(Constants.TAG_DISCOVERY, "stopDiscovery called. Trace:", Exception("stopDiscovery Trace"))
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
        stopDiscovery()
        scope.cancel()
        callbacks.clear()
    }

    companion object {
        private const val TAG = "DeviceScanner"
    }
}