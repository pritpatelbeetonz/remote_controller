package com.example.remote_controller

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.waysol.android_tv_remote_package.AndroidTVRemotePlugin

class MainActivity : FlutterActivity() {
    private var plugin: AndroidTVRemotePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        plugin = AndroidTVRemotePlugin(this)
        plugin?.setupChannel(flutterEngine)
    }

    override fun onDestroy() {
        plugin?.destroy()
        super.onDestroy()
    }
}
