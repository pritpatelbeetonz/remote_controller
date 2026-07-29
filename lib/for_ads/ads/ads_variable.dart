
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'ads_load_util.dart';



class AdsVariable {
  static bool? OpenAdInSplash;
  static AppOpenAd? appOpenAd;
  static AppOpenAd? appOpenAdSplash;
  static bool isShowingAd = false;
  static late ConnectivityResult connectivityResult;
  //when submittion :- change to false when submition
  static bool isPurchase = false; //*****************************************
  static String dataGDPR = "";
  static Map<String, Package>? availablePackages;
  static bool isPrivacyOptionsRequired = false;
  static int freeUserTempletAllowed = 0;
  static int freeUserLayoutsAllowed = 0;

  static void resetAdIds() {
    appOpenAdsIOS = "11";
    interSplashIOS = "11";
    interPreLoadIOS = "11";
    bigNativeSurveyAdIOS1 = "11";
    bigNativeSurveyAdIOS2 = "11";
    fullNativeIntroAdIOS = "11";
    smallThirdIntroNativeIntroAdIOS = "11";
  }

  static Future<bool> isInternetConnected() {
    return Connectivity().checkConnectivity().then((connectivityResult) {
      return connectivityResult.contains(ConnectivityResult.none)
          ? false
          : true;
    });
  }

  /// FOR SERVER DATA
  static String serverUrl = '';
  static String serverBaseFolderName = "";
  //templet_json
  //sticker_json
  //layouts_json
  static String testEmail = "qwertyui567@testing.com";
  static String supportContactEmail = "qwertyui567@testing.com";
  static String testPassword = "App*TesT@321";



  static bool isUseA1ArtForNsfwCheck = false;
  static int currentClick = 0;
  static String click = "2";
  static String nativeBGColor = "141414";
  static String btnBgColorG1 = "CD5355";
  static String btnBgColorG2 = "BC3C99";
  static String btnTextColor = "FFFFFF";
  static String headerTextColor = "FFFFFF";
  static String bodyTextColor = "FFFFFF";

  static NativeAd? nativeBigAdSurvey1;
  static NativeAd? nativeBigAdSurvey2;
  static NativeAd? fullNativeAdIntro;
  static NativeAd? smallThirdNativeAdIntro;

  /// Facebook
  static String facebookId = "11";
  static String facebookToken = "11";

  /// Ads - IOS
  static String appOpenAdsIOS = "11";
  static String interSplashIOS = "11";
  static String interPreLoadIOS = "11";
  static String bigNativeSurveyAdIOS1 = "11";
  static String bigNativeSurveyAdIOS2 = "11";
  static String fullNativeIntroAdIOS = "11";
  static String smallThirdIntroNativeIntroAdIOS = "11";

  //APIs
  static String GeminiApi="AIzaSyBczy06aScmoms6sTfRM1mMR57sFYL0lns";
  static String PixabayApi="51208507-8139305412efdf67d2bf56718";


  static bool showRateUsDialogInIntro = false;
  static bool showSurveyScreen = false;
  static int reviewAfterExports = 0;



  static Future<void> onShowAds(BuildContext context, {required Function onComplete}) async {

    if(AdsVariable.isPurchase){

      onComplete();

    }else{
      if (AdsVariable.currentClick % int.parse(AdsVariable.click) == 0) {

        if (await isInternetConnected()) {
          AdsLoadUtil.showInterstitial(onDismissed: () {
            onComplete();
          });
        } else {
          onComplete();
        }

      } else {
        // Odd-numbered clicks: Perform onTap action directly
        onComplete();
      }
    }
    AdsVariable.currentClick++;

  }

  static void onShowAddMealAds(BuildContext context, {required Function onComplete}) {
    if (AdsVariable.currentClick % int.parse(AdsVariable.click) == 0) {
      AdsLoadUtil.showInterstitial(onDismissed: () {
        onComplete();
      });
    } else {
      onComplete();
    }
    /*  if (isPremiumUser) {
      onComplete();
      return;
    } else {
      if (AdsVariable.currentClick % AdsVariable.click == 0) {
        AdsLoadUtil.showInterstitial( onDismissed: () {
          onComplete();
        });
      } else {
        onComplete();
      }
    }*/
    AdsVariable.currentClick++;
  }
}


class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

