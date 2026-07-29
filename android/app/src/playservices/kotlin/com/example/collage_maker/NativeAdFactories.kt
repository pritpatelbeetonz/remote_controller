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
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
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
        adView.mediaView = adView.findViewById(R.id.native_ad_media)

        // Set other ad assets.
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        (adView.headlineView as? TextView)?.setTextColor(safeParseColor(headLineTextColor))

        adView.bodyView = adView.findViewById(R.id.ad_body)
        (adView.bodyView as? TextView)?.setTextColor(safeParseColor(bodyTextColor))

        // Button Background
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        adView.callToActionView?.background = buttonGradientDrawable
        //Text Color
        (adView.callToActionView as? Button)?.setTextColor(safeParseColor(buttonTextColor))

        adView.iconView = adView.findViewById(R.id.ad_app_icon)

        // "Ad" Text background
        adView.priceView = adView.findViewById(R.id.native_ad_attribution_small)
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
        adView.priceView?.background = priceGradientDrawable
        (adView.priceView as? TextView)?.setTextColor(safeParseColor(buttonTextColor))

        // Star Color
        adView.starRatingView = adView.findViewById(R.id.ad_stars)

        // Populate ad view
        (adView.headlineView as TextView).text = ad?.headline
        adView.mediaView?.mediaContent = ad?.mediaContent

        if (ad?.body == null) {
            adView.bodyView?.visibility = View.INVISIBLE
        } else {
            adView.bodyView?.visibility = View.VISIBLE
            (adView.bodyView as TextView).text = ad.body
        }

        if (ad?.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as Button).text = ad.callToAction
        }

        if (ad?.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(ad.icon!!.drawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            adView.starRatingView?.visibility = View.INVISIBLE
        } else {
            (adView.starRatingView as RatingBar).rating = ad.starRating!!.toFloat()
            adView.starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.setNativeAd(ad)
        }

        return adView
    }
}

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
        adView.mediaView = adView.findViewById(R.id.native_ad_media)

        // Set other ad assets.
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        (adView.headlineView as? TextView)?.setTextColor(safeParseColor(headLineTextColor))

        adView.bodyView = adView.findViewById(R.id.ad_body)
        (adView.bodyView as? TextView)?.setTextColor(safeParseColor(bodyTextColor))

        // Button Background
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        adView.callToActionView?.background = buttonGradientDrawable
        //Text Color
        (adView.callToActionView as? Button)?.setTextColor(safeParseColor(buttonTextColor))

        adView.iconView = adView.findViewById(R.id.ad_app_icon)

        // "Ad" Text background
        adView.priceView = adView.findViewById(R.id.native_ad_attribution_small)
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
        adView.priceView?.background = priceGradientDrawable
        (adView.priceView as? TextView)?.setTextColor(safeParseColor(buttonTextColor))

        // Star Color
        adView.starRatingView = adView.findViewById(R.id.ad_stars)

        // Populate ad view
        (adView.headlineView as TextView).text = ad?.headline
        adView.mediaView?.mediaContent = ad?.mediaContent

        if (ad?.body == null) {
            adView.bodyView?.visibility = View.INVISIBLE
        } else {
            adView.bodyView?.visibility = View.VISIBLE
            (adView.bodyView as TextView).text = ad.body
        }

        if (ad?.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as Button).text = ad.callToAction
        }

        if (ad?.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(ad.icon!!.drawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            adView.starRatingView?.visibility = View.INVISIBLE
        } else {
            (adView.starRatingView as RatingBar).rating = ad.starRating!!.toFloat()
            adView.starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.setNativeAd(ad)
        }

        return adView
    }
}

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
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        (adView.headlineView as? TextView)?.setTextColor(safeParseColor(headLineTextColor))

        adView.bodyView = adView.findViewById(R.id.ad_body)
        (adView.bodyView as? TextView)?.setTextColor(safeParseColor(bodyTextColor))

        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        val buttonGradientDrawable = GradientDrawable(
            GradientDrawable.Orientation.TR_BL, // 135 degrees
            intArrayOf(safeParseColor(startColor), safeParseColor(endColor))
        )
        buttonGradientDrawable.cornerRadius = 14f * adView.context.resources.displayMetrics.density
        adView.callToActionView?.background = buttonGradientDrawable
        //Text Color
        (adView.callToActionView as? Button)?.setTextColor(safeParseColor(buttonTextColor))

        adView.iconView = adView.findViewById(R.id.ad_app_icon)

        // "Ad" Text background
        adView.priceView = adView.findViewById(R.id.native_ad_attribution_small)
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
        adView.priceView?.background = priceGradientDrawable
        (adView.priceView as? TextView)?.setTextColor(safeParseColor(buttonTextColor))

        adView.starRatingView = adView.findViewById(R.id.ad_stars)

        // The headline and mediaContent are guaranteed to be in every NativeAd.
        (adView.headlineView as TextView).text = ad?.headline

        if (ad?.body == null) {
            adView.bodyView?.visibility = View.INVISIBLE
        } else {
            adView.bodyView?.visibility = View.VISIBLE
            (adView.bodyView as TextView).text = ad.body
        }

        if (ad?.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as Button).text = ad.callToAction
        }

        if (ad?.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(ad.icon!!.drawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        if (ad?.starRating == null) {
            adView.starRatingView?.visibility = View.INVISIBLE
        } else {
            (adView.starRatingView as RatingBar).rating = ad.starRating!!.toFloat()
            adView.starRatingView?.visibility = View.VISIBLE
        }

        if (ad != null) {
            adView.setNativeAd(ad)
        }

        return adView
    }
}
