package com.waysol.android_tv_remote_package.google_cast

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.MimeTypeMap
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.common.images.WebImage
import com.waysol.android_tv_remote_package.util.Constants
import com.waysol.android_tv_remote_package.util.Logger

class CastMediaManager(
    private val context: Context,
    private val sessionManager: CastSessionManager
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun castMedia(
        url: String,
        mimeType: String?,
        title: String?,
        subtitle: String?,
        artworkUrl: String?,
        duration: Long?
    ): String? {
        val session = sessionManager.currentSession
        if (session == null || !session.isConnected) {
            Logger.e(Constants.TAG_PLUGIN, "Cannot cast: No active session")
            return "NO_ACTIVE_SESSION"
        }

        // 1. Resolve and Validate MIME Type
        val resolvedMime = resolveMimeType(url, mimeType)
        if (resolvedMime == null) {
            Logger.e(Constants.TAG_PLUGIN, "Cannot cast: Unresolved MIME type for URL: $url")
            return "INVALID_MEDIA_TYPE"
        }

        Logger.d(Constants.TAG_PLUGIN, "Casting media URL: $url, MIME: $resolvedMime")

        // 2. Build MediaMetadata
        val mediaType = when {
            resolvedMime.startsWith("image/") -> MediaMetadata.MEDIA_TYPE_PHOTO
            resolvedMime.startsWith("audio/") -> MediaMetadata.MEDIA_TYPE_MUSIC_TRACK
            else -> MediaMetadata.MEDIA_TYPE_MOVIE
        }

        val metadata = MediaMetadata(mediaType)
        if (title != null) metadata.putString(MediaMetadata.KEY_TITLE, title)
        if (subtitle != null) metadata.putString(MediaMetadata.KEY_SUBTITLE, subtitle)
        if (artworkUrl != null) {
            metadata.addImage(WebImage(Uri.parse(artworkUrl)))
        }

        // 3. Build MediaInfo
        val mediaInfoBuilder = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(resolvedMime)
            .setMetadata(metadata)

        if (duration != null && duration > 0) {
            mediaInfoBuilder.setStreamDuration(duration)
        }

        val mediaInfo = mediaInfoBuilder.build()

        // 4. Load Media Request on main thread
        mainHandler.post {
            try {
                val remoteMediaClient = session.remoteMediaClient
                if (remoteMediaClient != null) {
                    val requestData = MediaLoadRequestData.Builder()
                        .setMediaInfo(mediaInfo)
                        .setAutoplay(true)
                        .build()
                    remoteMediaClient.load(requestData)
                    Logger.i(Constants.TAG_PLUGIN, "✅ Cast load request sent successfully")
                } else {
                    Logger.e(Constants.TAG_PLUGIN, "RemoteMediaClient is null")
                }
            } catch (e: Exception) {
                Logger.e(Constants.TAG_PLUGIN, "Exception during Cast load: ${e.message}", e)
            }
        }

        return null // Success, no error code
    }

    fun play() {
        mainHandler.post {
            sessionManager.currentSession?.remoteMediaClient?.play()
        }
    }

    fun pause() {
        mainHandler.post {
            sessionManager.currentSession?.remoteMediaClient?.pause()
        }
    }

    fun stop() {
        mainHandler.post {
            sessionManager.currentSession?.remoteMediaClient?.stop()
        }
    }

    fun seek(positionMs: Long) {
        mainHandler.post {
            sessionManager.currentSession?.remoteMediaClient?.seek(positionMs)
        }
    }

    fun setVolume(volume: Double) {
        mainHandler.post {
            sessionManager.currentSession?.remoteMediaClient?.setStreamVolume(volume)
        }
    }

    private fun resolveMimeType(url: String, passedMime: String?): String? {
        if (!passedMime.isNullOrEmpty()) {
            return passedMime
        }

        // Extract file extension from URL path
        val uri = Uri.parse(url)
        val path = uri.path ?: return null
        val extension = MimeTypeMap.getFileExtensionFromUrl(path).lowercase()
        
        if (extension.isNotEmpty()) {
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            if (mime != null) return mime
            
            // Manual overrides for standard streaming/media extensions not in MimeTypeMap
            when (extension) {
                "m3u8" -> return "application/x-mpegURL"
                "mpd" -> return "application/dash+xml"
                "mp4" -> return "video/mp4"
                "mkv" -> return "video/x-matroska"
                "mov" -> return "video/quicktime"
                "webm" -> return "video/webm"
                "mp3" -> return "audio/mpeg"
                "aac" -> return "audio/aac"
                "wav" -> return "audio/wav"
                "flac" -> return "audio/flac"
                "jpg", "jpeg" -> return "image/jpeg"
                "png" -> return "image/png"
                "webp" -> return "image/webp"
            }
        }
        return null
    }
}
