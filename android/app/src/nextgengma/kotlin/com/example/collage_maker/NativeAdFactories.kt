package com.test.app.testfeature.apps

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.libraries.ads.mobile.sdk.nativead.NativeAd
import com.google.android.libraries.ads.mobile.sdk.nativead.NativeAdView
import com.google.android.libraries.ads.mobile.sdk.nativead.MediaView
import io.flutter.plugins.googlemobileads.NativeAdFactory

class NativeAdFactoryBig : NativeAdFactory {
    private var layoutInflater: LayoutInflater
    private var startColor: String
    private var endColor: String
    private var backgroundColor: String
    private var headLineTextColor: String
    private var bodyTextColor: String
    private var buttonTextColor: String

    constructor(layoutInflater: LayoutInflater, startColor : String, endColor : String, backgroundColor: String, headLineTextColor: String, bodyTextColor: String, buttonTextColor: String) {
        this.layoutInflater = layoutInflater
        this.startColor = startColor
        this.endColor = endColor
        this.backgroundColor = backgroundColor
        this.headLineTextColor = headLineTextColor
        this.bodyTextColor = bodyTextColor
        this.buttonTextColor = buttonTextColor
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val ad = nativeAd
        val adView = layoutInflater.inflate(R.layout.big_template, null) as NativeAdView

        // Background color
        val circularLayoutBackground: LinearLayout = adView.findViewById(R.id.circular_layout_background)
        val cornerRadius = 20f * adView.context.resources.displayMetrics.density
        val backgroundGradientDrawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(safeParseColor(backgroundColor))
            this.cornerRadius = cornerRadius
        }
        circularLayoutBackground.background = backgroundGradientDrawable

        // Set the media view.
        val mediaView = adView.findViewById<MediaView>(R.id.native_ad_media)

        // Set other ad assets.
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView?.setTextColor(safeParseColor(headLineTextColor))

        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView?.setTextColor(safeParseColor(bodyTextColor))

        // Button Background
        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        callToActionView?.background = buttonGradientDrawable
        //Text Color
        callToActionView?.setTextColor(safeParseColor(buttonTextColor))

        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)

        // "Ad" Text background
        val priceView = adView.findViewById<TextView>(R.id.native_ad_attribution_small)
        val priceGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        ).apply {
            cornerRadii = floatArrayOf(
                10f * adView.context.resources.displayMetrics.density, 10f *  adView.context.resources.displayMetrics.density, // top-left radius
                0f, 0f, // top-right radius
                0f, 0f, // bottom-right radius
                5f *  adView.context.resources.displayMetrics.density, 5f *  adView.context.resources.displayMetrics.density  // bottom-left radius
            )
        }
        priceView?.background = priceGradientDrawable
        priceView?.setTextColor(safeParseColor(buttonTextColor))

        // Star Color
        val starRatingView = adView.findViewById<RatingBar>(R.id.ad_stars)

        // Populate ad view
        headlineView?.text = ad?.headline

        if (ad?.body == null) {
            bodyView?.visibility = View.INVISIBLE
        } else {
            bodyView?.visibility = View.VISIBLE
            bodyView?.text = ad.body
        }

        if (ad?.callToAction == null) {
            callToActionView?.visibility = View.INVISIBLE
        } else {
            callToActionView?.visibility = View.VISIBLE
            callToActionView?.text = ad.callToAction
        }

        if (ad?.icon == null) {
            iconView?.visibility = View.GONE
        } else {
            iconView?.setImageDrawable(ad.icon!!.drawable)
            iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            starRatingView?.visibility = View.INVISIBLE
        } else {
            starRatingView?.rating = ad.starRating!!.toFloat()
            starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.registerNativeAd(ad, mediaView)
        }

        return adView
    }
}

// Full
class NativeAdFactoryFull : NativeAdFactory {
    private var layoutInflater: LayoutInflater
    private var startColor: String
    private var endColor: String
    private var backgroundColor: String
    private var headLineTextColor: String
    private var bodyTextColor: String
    private var buttonTextColor: String

    constructor(layoutInflater: LayoutInflater, startColor : String, endColor : String, backgroundColor: String, headLineTextColor: String, bodyTextColor: String, buttonTextColor: String) {
        this.layoutInflater = layoutInflater
        this.startColor = startColor
        this.endColor = endColor
        this.backgroundColor = backgroundColor
        this.headLineTextColor = headLineTextColor
        this.bodyTextColor = bodyTextColor
        this.buttonTextColor = buttonTextColor
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val ad = nativeAd
        val adView = layoutInflater.inflate(R.layout.full_template, null) as NativeAdView

        // Background color
        val circularLayoutBackground: LinearLayout = adView.findViewById(R.id.circular_layout_background)
        val cornerRadius = 20f * adView.context.resources.displayMetrics.density
        val backgroundGradientDrawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(safeParseColor(backgroundColor))
            this.cornerRadius = cornerRadius
        }
        circularLayoutBackground.background = backgroundGradientDrawable

        // Set the media view.
        val mediaView = adView.findViewById<MediaView>(R.id.native_ad_media)

        // Set other ad assets.
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView?.setTextColor(safeParseColor(headLineTextColor))

        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView?.setTextColor(safeParseColor(bodyTextColor))

        // Button Background
        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        callToActionView?.background = buttonGradientDrawable
        //Text Color
        callToActionView?.setTextColor(safeParseColor(buttonTextColor))

        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)

        // "Ad" Text background
        val priceView = adView.findViewById<TextView>(R.id.native_ad_attribution_small)
        val priceGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        ).apply {
            cornerRadii = floatArrayOf(
                10f * adView.context.resources.displayMetrics.density, 10f *  adView.context.resources.displayMetrics.density, // top-left radius
                0f, 0f, // top-right radius
                0f, 0f, // bottom-right radius
                5f *  adView.context.resources.displayMetrics.density, 5f *  adView.context.resources.displayMetrics.density  // bottom-left radius
            )
        }
        priceView?.background = priceGradientDrawable
        priceView?.setTextColor(safeParseColor(buttonTextColor))

        // Star Color
        val starRatingView = adView.findViewById<RatingBar>(R.id.ad_stars)

        // Populate ad view
        headlineView?.text = ad?.headline

        if (ad?.body == null) {
            bodyView?.visibility = View.INVISIBLE
        } else {
            bodyView?.visibility = View.VISIBLE
            bodyView?.text = ad.body
        }

        if (ad?.callToAction == null) {
            callToActionView?.visibility = View.INVISIBLE
        } else {
            callToActionView?.visibility = View.VISIBLE
            callToActionView?.text = ad.callToAction
        }

        if (ad?.icon == null) {
            iconView?.visibility = View.GONE
        } else {
            iconView?.setImageDrawable(ad.icon!!.drawable)
            iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            starRatingView?.visibility = View.INVISIBLE
        } else {
            starRatingView?.rating = ad.starRating!!.toFloat()
            starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.registerNativeAd(ad, mediaView)
        }

        return adView
    }
}

// Small
class NativeAdFactorySmall : NativeAdFactory {
    private var layoutInflater: LayoutInflater
    private var startColor: String
    private var endColor: String
    private var backgroundColor: String
    private var headLineTextColor: String
    private var bodyTextColor: String
    private var buttonTextColor: String

    constructor(layoutInflater: LayoutInflater, startColor : String, endColor : String, backgroundColor: String, headLineTextColor: String, bodyTextColor: String, buttonTextColor: String) {
        this.layoutInflater = layoutInflater
        this.startColor = startColor
        this.endColor = endColor
        this.backgroundColor = backgroundColor
        this.headLineTextColor = headLineTextColor
        this.bodyTextColor = bodyTextColor
        this.buttonTextColor = buttonTextColor
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val ad = nativeAd
        val adView = layoutInflater.inflate(R.layout.small_template, null) as NativeAdView

        Log.d("Colors", "Start Color: $startColor, End Color: $endColor, Background Color: $backgroundColor")
        // Background color
        val circularLayoutBackground: LinearLayout = adView.findViewById(R.id.circular_layout_background)
        val cornerRadius = 20f * adView.context.resources.displayMetrics.density
        val backgroundGradientDrawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(safeParseColor(backgroundColor))
            this.cornerRadius = cornerRadius
        }
        circularLayoutBackground.background = backgroundGradientDrawable

        // Set other ad assets.
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView?.setTextColor(safeParseColor(headLineTextColor))

        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView?.setTextColor(safeParseColor(bodyTextColor))

        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        callToActionView?.background = buttonGradientDrawable
        //Text Color
        callToActionView?.setTextColor(safeParseColor(buttonTextColor))

        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)

        // "Ad" Text background
        val priceView = adView.findViewById<TextView>(R.id.native_ad_attribution_small)
        val priceGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        ).apply {
            cornerRadii = floatArrayOf(
                10f * adView.context.resources.displayMetrics.density, 10f *  adView.context.resources.displayMetrics.density, // top-left radius
                0f, 0f, // top-right radius
                0f, 0f, // bottom-right radius
                5f *  adView.context.resources.displayMetrics.density, 5f *  adView.context.resources.displayMetrics.density  // bottom-left radius
            )
        }
        priceView?.background = priceGradientDrawable
        priceView?.setTextColor(safeParseColor(buttonTextColor))

        val starRatingView = adView.findViewById<RatingBar>(R.id.ad_stars)

        // The headline and mediaContent are guaranteed to be in every NativeAd.
        headlineView?.text = ad?.headline

        if (ad?.body == null) {
            bodyView?.visibility = View.INVISIBLE
        } else {
            bodyView?.visibility = View.VISIBLE
            bodyView?.text = ad.body
        }

        if (ad?.callToAction == null) {
            callToActionView?.visibility = View.INVISIBLE
        } else {
            callToActionView?.visibility = View.VISIBLE
            callToActionView?.text = ad.callToAction
        }

        if (ad?.icon == null) {
            iconView?.visibility = View.GONE
        } else {
            iconView?.setImageDrawable(ad.icon!!.drawable)
            iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            starRatingView?.visibility = View.INVISIBLE
        } else {
            starRatingView?.rating = ad.starRating!!.toFloat()
            starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.registerNativeAd(ad, null)
        }

        return adView
    }
}
