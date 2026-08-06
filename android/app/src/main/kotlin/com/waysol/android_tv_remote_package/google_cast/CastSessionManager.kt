package com.waysol.android_tv_remote_package.google_cast

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger

class CastSessionManager(
    private val context: Context,
    private val discoveryManager: CastDiscoveryManager,
    private val onStateChanged: (String) -> Unit
) {
    private val mediaRouter = MediaRouter.getInstance(context)
    private val sessionManager = CastContext.getSharedInstance(context).sessionManager
    private val mainHandler = Handler(Looper.getMainLooper())
    var currentSession: CastSession? = null
        private set

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarting(session: CastSession) {
            Logger.d(Constants.TAG_PLUGIN, "🔌 Session starting...")
            onStateChanged("CONNECTING")
        }

        override fun onSessionStarted(session: CastSession, sessionId: String) {
            Logger.i(Constants.TAG_PLUGIN, "🚀 Session started: $sessionId")
            currentSession = session
            onStateChanged("CONNECTED")
        }

        override fun onSessionStartFailed(session: CastSession, error: Int) {
            Logger.e(Constants.TAG_PLUGIN, "❌ Session start failed: error $error")
            currentSession = null
            onStateChanged("ERROR")
        }

        override fun onSessionEnding(session: CastSession) {
            Logger.d(Constants.TAG_PLUGIN, "🔌 Session ending...")
        }

        override fun onSessionEnded(session: CastSession, error: Int) {
            Logger.i(Constants.TAG_PLUGIN, "🏁 Session ended: error $error")
            currentSession = null
            onStateChanged("DISCONNECTED")
        }

        override fun onSessionResuming(session: CastSession, sessionId: String) {
            Logger.d(Constants.TAG_PLUGIN, "🔄 Session resuming: $sessionId")
            onStateChanged("CONNECTING")
        }

        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
            Logger.i(Constants.TAG_PLUGIN, "✅ Session resumed. Suspended before: $wasSuspended")
            currentSession = session
            onStateChanged("CONNECTED")
        }

        override fun onSessionResumeFailed(session: CastSession, error: Int) {
            Logger.e(Constants.TAG_PLUGIN, "❌ Session resume failed: error $error")
            currentSession = null
            onStateChanged("ERROR")
        }

        override fun onSessionSuspended(session: CastSession, reason: Int) {
            Logger.w(Constants.TAG_PLUGIN, "⚠️ Session suspended: reason $reason")
            onStateChanged("BUFFERING")
        }
    }

    init {
        mainHandler.post {
            sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
            // Restore session if active already
            currentSession = sessionManager.currentCastSession
        }
    }

    fun connect(deviceId: String): Boolean {
        var success = false
        mainHandler.postAtTime({
            val routes = discoveryManager.getDiscoveredRoutes()
            val route = routes.firstOrNull { it.id == deviceId }
            if (route != null) {
                Logger.i(Constants.TAG_PLUGIN, "🔗 Programmatic connect selected route: ${route.name}")
                mediaRouter.selectRoute(route)
                success = true
            } else {
                Logger.e(Constants.TAG_PLUGIN, "❌ Cannot connect: route ID $deviceId not found")
            }
        }, 0)
        // Since we post to main handler, return true if route exists and selection is requested
        val routes = discoveryManager.getDiscoveredRoutes()
        return routes.any { it.id == deviceId }
    }

    fun disconnect() {
        mainHandler.post {
            Logger.i(Constants.TAG_PLUGIN, "🔌 Programmatic disconnect requested")
            mediaRouter.unselect(MediaRouter.UNSELECT_REASON_DISCONNECTED)
        }
    }

    fun isConnected(): Boolean {
        val session = currentSession ?: sessionManager.currentCastSession
        return session != null && session.isConnected
    }

    fun getSessionStateName(): String {
        val session = currentSession ?: sessionManager.currentCastSession
        return when {
            session == null -> "DISCONNECTED"
            session.isConnected -> {
                val mediaClient = session.remoteMediaClient
                if (mediaClient != null) {
                    when {
                        mediaClient.isBuffering -> "BUFFERING"
                        mediaClient.isPlaying -> "CASTING"
                        mediaClient.isPaused -> "PAUSED"
                        mediaClient.playerState == com.google.android.gms.cast.MediaStatus.PLAYER_STATE_IDLE && mediaClient.idleReason == com.google.android.gms.cast.MediaStatus.IDLE_REASON_ERROR -> "ERROR"
                        else -> "CONNECTED"
                    }
                } else {
                    "CONNECTED"
                }
            }
            session.isConnecting -> "CONNECTING"
            else -> "DISCONNECTED"
        }
    }

    fun destroy() {
        mainHandler.post {
            sessionManager.removeSessionManagerListener(sessionListener, CastSession::class.java)
        }
    }
}
