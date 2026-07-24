package com.waysol.android_tv_remote_package.util

import android.util.Log

object Logger {
    var debugEnabled = true

    // Listener type: (Level, Tag, Message)
    private val listeners = java.util.concurrent.CopyOnWriteArrayList<(String, String, String) -> Unit>()

    fun addListener(listener: (String, String, String) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (String, String, String) -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyListeners(level: String, tag: String, message: String, throwable: Throwable? = null) {
        val fullMsg = if (throwable != null) {
            "$message\n${Log.getStackTraceString(throwable)}"
        } else {
            message
        }
        for (listener in listeners) {
            try {
                listener(level, tag, fullMsg)
            } catch (e: Exception) {
                // Ignore listener exceptions to prevent crash loops
            }
        }
    }

    fun d(tag: String, message: String) {
        if (debugEnabled) {
            Log.d(tag, message)
            notifyListeners("DEBUG", tag, message)
        }
    }

    fun d(tag: String, message: String, throwable: Throwable) {
        if (debugEnabled) {
            Log.d(tag, message, throwable)
            notifyListeners("DEBUG", tag, message, throwable)
        }
    }

    fun i(tag: String, message: String) {
        Log.i(tag, message)
        notifyListeners("INFO", tag, message)
    }

    fun i(tag: String, message: String, throwable: Throwable) {
        Log.i(tag, message, throwable)
        notifyListeners("INFO", tag, message, throwable)
    }

    fun w(tag: String, message: String) {
        Log.w(tag, message)
        notifyListeners("WARN", tag, message)
    }

    fun w(tag: String, message: String, throwable: Throwable) {
        Log.w(tag, message, throwable)
        notifyListeners("WARN", tag, message, throwable)
    }

    fun e(tag: String, message: String) {
        Log.e(tag, message)
        notifyListeners("ERROR", tag, message)
    }

    fun e(tag: String, message: String, throwable: Throwable) {
        Log.e(tag, message, throwable)
        notifyListeners("ERROR", tag, message, throwable)
    }

    fun wtf(tag: String, message: String) {
        Log.wtf(tag, message)
        notifyListeners("WTF", tag, message)
    }

    fun wtf(tag: String, message: String, throwable: Throwable) {
        Log.wtf(tag, message, throwable)
        notifyListeners("WTF", tag, message, throwable)
    }
}