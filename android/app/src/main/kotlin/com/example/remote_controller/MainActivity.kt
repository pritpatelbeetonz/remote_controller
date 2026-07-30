package com.test.app.testfeature.apps

import android.graphics.Color
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.waysol.android_tv_remote_package.AndroidTVRemotePlugin

import android.widget.Toast
import io.flutter.plugins.GeneratedPluginRegistrant
import com.facebook.FacebookSdk
import com.facebook.LoggingBehavior
import com.facebook.appevents.AppEventsLogger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

fun safeParseColor(colorStr: String, defaultColor: String = "#FFFFFF"): Int {
    return try {
        val formatted = if (colorStr.startsWith("#")) colorStr else "#$colorStr"
        Color.parseColor(formatted)
    } catch (e: Exception) {
        try {
            Color.parseColor(defaultColor)
        } catch (ex: Exception) {
            Color.WHITE
        }
    }
}


class MainActivity : FlutterActivity() {

    private fun setText(myText: String) {
        Toast.makeText(this, myText, Toast.LENGTH_SHORT).show()
    }

    private val CHANNEL = "nativeChannel"

    private var startColor: String = "0091FF"
    private var endColor: String = "0091FF"
    private var backgroundColor: String = "A7DAFB"
    private var headLineTextColor: String = "000000"
    private var bodyTextColor: String = "000000"
    private var buttonTextColor: String = "FFFFFF"

    private var plugin: AndroidTVRemotePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result ->
                Log.i("xyz", "configureFlutterEngine: ")
                when (call.method) {
                    "launchCastSettings" -> {
                        try {
                            val intent = android.content.Intent(android.provider.Settings.ACTION_CAST_SETTINGS)
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (ex: Exception) {
                                result.error("ERROR", "Could not open settings: ${ex.message}", null)
                            }
                        }
                    }
                    "setToast" -> {

                        try {
                            Log.i("xyz", "configureFlutterEngine: 1111")
                            val fb_appid = call.argument<String>("fb_appid")!!
                            val fb_token = call.argument<String>("fb_token")!!
                            startColor = call.argument<String>("btnBgColorG1")!!
                            Log.i("xyz", "configureFlutterEngine: 1111")
                            endColor = call.argument<String>("btnBgColorG2")!!
                            backgroundColor = call.argument<String>("nativeBGColor")!!
                            headLineTextColor = call.argument<String>("headerTextColor")!!
                            bodyTextColor = call.argument<String>("bodyTextColor")!!
                            buttonTextColor = call.argument<String>("btnTextColor")!!
                            Log.i("xyz", "configureFlutterEngine: 2")


                            FacebookSdk.setApplicationId(fb_appid)
                            FacebookSdk.setClientToken(fb_token)
                            FacebookSdk.sdkInitialize(this@MainActivity)
                            FacebookSdk.setAutoInitEnabled(true)
                            FacebookSdk.fullyInitialize()
                            FacebookSdk.setAutoLogAppEventsEnabled(true)
                            FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS)
                            AppEventsLogger.newLogger(this@MainActivity).applicationId

                            // Register ad factories here, after initializing properties
                            GoogleMobileAdsPlugin.registerNativeAdFactory(
                                flutterEngine,
                                "smallNativeAds",
                                NativeAdFactorySmall(layoutInflater, startColor, endColor, backgroundColor, headLineTextColor, bodyTextColor, buttonTextColor)
                            )
                            GoogleMobileAdsPlugin.registerNativeAdFactory(
                                flutterEngine,
                                "bigNativeAds",
                                NativeAdFactoryBig(layoutInflater, startColor, endColor, backgroundColor, headLineTextColor, bodyTextColor, buttonTextColor)
                            )
                            GoogleMobileAdsPlugin.registerNativeAdFactory(
                                flutterEngine,
                                "fullNativeAds",
                                NativeAdFactoryFull(layoutInflater, startColor, endColor, backgroundColor, headLineTextColor, bodyTextColor, buttonTextColor)
                            )
                            Log.i("xyz", "configureFlutterEngine: 3")

                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        result.success(true)
                    }
                }
            }

        flutterEngine.plugins.add(GoogleMobileAdsPlugin())
        
        plugin = AndroidTVRemotePlugin(this)
        plugin?.setupChannel(flutterEngine)

        super.configureFlutterEngine(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        Log.i("xyz", "configureFlutterEngine:4 ")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "smallNativeAds")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "bigNativeAds")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "fullNativeAds")
        Log.i("xyz", "configureFlutterEngine: 5")
    }

    override fun onDestroy() {
        plugin?.destroy()
        super.onDestroy()
    }
}
