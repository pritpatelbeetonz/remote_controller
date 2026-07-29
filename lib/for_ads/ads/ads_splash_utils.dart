import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_constants.dart';
import '../utils/firstTime.dart';
import '../utils/store_config.dart';
import 'ads_load_util.dart';
import 'ads_variable.dart';
import 'app_open_ad.dart';
import 'life_cycle.dart';
import '../utils/shared_prefrence_service.dart';

class AdsSplashUtils {
  late SharedPreferences prefs;

  Future<void> getOnlineIds({required Function() navigateScreen}) async {
    print("");
    prefs = await SharedPreferences.getInstance();

    /// IOS
    AdsVariable.appOpenAdsIOS = prefs.getString("tr_appOpenAd") ?? "11";

    AdsVariable.interSplashIOS =
        prefs.getString("tr_splashInterstitialAd") ?? "11";
    AdsVariable.bigNativeSurveyAdIOS1 =
        prefs.getString("tr_surveyBigNative1") ?? "11";
    AdsVariable.bigNativeSurveyAdIOS2 =
        prefs.getString("tr_surveyBigNative2") ?? "11";
    AdsVariable.fullNativeIntroAdIOS =
        prefs.getString("tr_introFullNative") ?? "11";
    AdsVariable.smallThirdIntroNativeIntroAdIOS =
        prefs.getString("tr_smallThirdIntroNative") ?? "11";
    AdsVariable.interPreLoadIOS =
        prefs.getString("tr_preInterstitialAd") ?? "11";
    AdsVariable.click = prefs.getString("click") ?? "2";
    AdsVariable.supportContactEmail = prefs.getString("supportContactEmail") ?? "qwertyui567@testing.com";

    AdsVariable.nativeBGColor = prefs.getString("nativeBGColor") ?? "#141414";
    AdsVariable.headerTextColor =
        prefs.getString("headlineTxtColor") ?? "000000";
    AdsVariable.bodyTextColor = prefs.getString("bodyTxtColor") ?? "#000000";
    AdsVariable.btnTextColor = prefs.getString("buttonTxtColor") ?? "#FFFFFF";
    AdsVariable.btnBgColorG1 = prefs.getString("buttonBgColorG1") ?? "#0091FF";
    AdsVariable.btnBgColorG2 = prefs.getString("buttonBgColorG2") ?? "#0091FF";
    AdsVariable.OpenAdInSplash = prefs.getBool("showOpenAdInSplash") ?? false;
    AdsVariable.serverUrl = prefs.getString("serverUrl") ?? "https://phpstack-1550637-6001716.cloudwaysapps.com";
    AdsVariable.serverBaseFolderName = prefs.getString("serverBaseFolderName") ?? "Sn_Ro_Pri_Framz";

    log(
      "await AdsVariable.isInternetConnected() :- ${await AdsVariable.isInternetConnected()}",
    );

    if (await AdsVariable.isInternetConnected()) {
      try {
        final remoteConfig = FirebaseRemoteConfig.instance;

        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(minutes: 1),
            minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 5),
          ),
        );

        await remoteConfig.fetchAndActivate();

        Map<String, dynamic> mapValues1 = {};

        if (Platform.isAndroid) {
          log(
            "Map is ${remoteConfig.getValue("framzy_vi_collageMaker").asString()}",
          );
          mapValues1 = jsonDecode(
            remoteConfig.getValue("framzy_vi_collageMaker").asString(),
          );
          print(mapValues1);
        } else {
          log(
            "Map is ${remoteConfig.getValue("framzy_vi_collageMaker").asString()}",
          );
          mapValues1 = jsonDecode(
            remoteConfig.getValue("framzy_vi_collageMaker").asString(),
          );
          print(mapValues1);
        }

        /// IOS Id setup from Firebase Remote Config
        /// Facebook id setup
        AdsVariable.reviewAfterExports = int.tryParse(mapValues1['reviewAfterExports']?.toString() ?? '') ?? AdsVariable.reviewAfterExports;
        AdsVariable.showSurveyScreen =mapValues1['showSurveyScreen'] ?? AdsVariable.showSurveyScreen;
        AdsVariable.showRateUsDialogInIntro =mapValues1['showRateUsDialogInIntro'] ?? AdsVariable.showRateUsDialogInIntro;
        AdsVariable.isUseA1ArtForNsfwCheck =mapValues1['isUseA1ArtForNsfwCheck'] ?? AdsVariable.isUseA1ArtForNsfwCheck;
        AdsVariable.facebookId = mapValues1["fb_appid"]?.toString() ?? "11";
        AdsVariable.facebookToken = mapValues1["fb_token"]?.toString() ?? "11";
        AdsVariable.freeUserTempletAllowed = int.tryParse(mapValues1['freeUserTempletAllowed']?.toString() ?? '') ?? AdsVariable.freeUserTempletAllowed;
        AdsVariable.freeUserLayoutsAllowed = int.tryParse(mapValues1['freeUserLayoutsAllowed']?.toString() ?? '') ?? AdsVariable.freeUserLayoutsAllowed;
        AdsVariable.appOpenAdsIOS = mapValues1["tr_appOpenAd"]?.toString() ?? "11";
        AdsVariable.interSplashIOS = mapValues1["tr_splashInterstitialAd"]?.toString() ?? "11";

        AdsVariable.bigNativeSurveyAdIOS1 = mapValues1["tr_surveyBigNative1"]?.toString() ?? "11";
        AdsVariable.bigNativeSurveyAdIOS2 = mapValues1["tr_surveyBigNative2"]?.toString() ?? "11";
        AdsVariable.fullNativeIntroAdIOS = mapValues1["tr_introFullNative"]?.toString() ?? "11";
        AdsVariable.smallThirdIntroNativeIntroAdIOS =
            mapValues1["tr_smallThirdIntroNative"]?.toString() ?? "11";
        AdsVariable.interPreLoadIOS = mapValues1["tr_preInterstitialAd"]?.toString() ?? "11";

        AdsVariable.nativeBGColor = mapValues1['nativeBGColor']?.toString() ?? '#141414';
        AdsVariable.headerTextColor = mapValues1["headlineTxtColor"]?.toString() ?? "#FFFFFF";
        AdsVariable.bodyTextColor = mapValues1["bodyTxtColor"]?.toString() ?? "#FFFFFF";
        AdsVariable.btnBgColorG1 = mapValues1["buttonBgColorG1"]?.toString() ?? "#0091FF";
        AdsVariable.btnBgColorG2 = mapValues1["buttonBgColorG2"]?.toString() ?? "#0091FF";
        AdsVariable.btnTextColor = mapValues1["buttonTxtColor"]?.toString() ?? "#FFFFFF";
        AdsVariable.click = mapValues1["click"]?.toString() ?? "2";
        AdsVariable.OpenAdInSplash = mapValues1["showOpenAdInSplash"] ?? false;

        AdsVariable.GeminiApi =
            mapValues1["GeminiApi"]?.toString() ??
            "AIzaSyBwvjMinbU8O03eAx2kjrJebZpbP05L8vE";
        AdsVariable.PixabayApi =
            mapValues1["PixabayApi"]?.toString() ?? "51208507-8139305412efdf67d2bf56718";

        AdsVariable.testEmail = mapValues1["testEmail"]?.toString() ?? "qwertyui567@testing.com";
        AdsVariable.supportContactEmail = mapValues1["supportContactEmail"]?.toString() ?? "qwertyui567@testing.com";
        AdsVariable.testPassword = mapValues1["testPassword"]?.toString() ?? "App*TesT@321";
        AdsVariable.serverUrl = mapValues1["serverUrl"]?.toString() ?? "https://phpstack-1550637-6001716.cloudwaysapps.com";
        AdsVariable.serverBaseFolderName = mapValues1["serverBaseFolderName"]?.toString() ?? "Sn_Ro_Pri_Framz";

        /// Store firebase remote config data into shared preferences :

         prefs.setString(
          "nativeBGColor",
          mapValues1["nativeBGColor"]?.toString() ?? "141414",
        );
        prefs.setString(
          "serverUrl",
          mapValues1["serverUrl"]?.toString() ?? "https://phpstack-1550637-6001716.cloudwaysapps.com",
        );
        prefs.setString(
          "serverBaseFolderName",
          mapValues1["serverBaseFolderName"]?.toString() ?? "Sn_Ro_Pri_Framz",
        );
        prefs.setString(
          "buttonBgColorG1",
          mapValues1["buttonBgColorG1"]?.toString() ?? "0091FF",
        );
        prefs.setString(
          "buttonBgColorG2",
          mapValues1["buttonBgColorG2"]?.toString() ?? "0091FF",
        );
        prefs.setString(
          "buttonTxtColor",
          mapValues1["buttonTxtColor"]?.toString() ?? "FFFFFF",
        );
        prefs.setString(
          "headlineTxtColor",
          mapValues1["headlineTxtColor"]?.toString() ?? "FFFFFF",
        );
        prefs.setString("bodyTxtColor", mapValues1["bodyTxtColor"]?.toString() ?? "FFFFFF");

        prefs.setString("fb_appid", mapValues1["fb_appid"]?.toString() ?? "11");
        prefs.setString("fb_token", mapValues1["fb_token"]?.toString() ?? "11");

        prefs.setString("tr_appOpenAd", mapValues1["tr_appOpenAd"]?.toString() ?? "11");
        prefs.setString(
          "tr_splashInterstitialAd",
          mapValues1["tr_splashInterstitialAd"]?.toString() ?? "11",
        );
        prefs.setString(
          "tr_preInterstitialAd",
          mapValues1["tr_preInterstitialAd"]?.toString() ?? "11",
        );
        prefs.setString(
          "tr_surveyBigNative1",
          mapValues1["tr_surveyBigNative1"]?.toString() ?? "11",
        );
        prefs.setString(
          "tr_surveyBigNative2",
          mapValues1["tr_surveyBigNative2"]?.toString() ?? "11",
        );
        prefs.setString(
          "tr_introFullNative",
          mapValues1["tr_introFullNative"]?.toString() ?? "11",
        );
        prefs.setString(
          "tr_smallThirdIntroNative",
          mapValues1["tr_smallThirdIntroNative"]?.toString() ?? "11",
        );
        prefs.setString("click", mapValues1["click"]?.toString() ?? "2");
        prefs.setString("supportContactEmail", mapValues1["supportContactEmail"]?.toString() ?? "qwertyui567@testing.com");
        prefs.setBool(
          "showOpenAdInSplash",
          mapValues1["showOpenAdInSplash"] ?? false,
        );

        /// Check available purchases
        debugPrint('=======hi prit =======');
        if (Platform.isIOS) {
          await initializeGDPR();
          await fetchPurchase();
        } else {
          await initializeMobileAds();
          await fetchPurchase();
        }

        if(kDebugMode){
          // AdsVariable.isPurchase =true;
        }

        // Removed the debug mode override of AdsVariable.isPurchase = false;
        // so that sandbox/test purchases work properly in debug mode.

        //AdsLoadUtil.loadPreInterstitialAd(adId: AdsVariable.interPreLoadIOS);
        debugPrint('------------------------------reched setupFbAdsID');

        /// Facebook id setup
        await setupFbAdsId();
        debugPrint('------------------------------fininshed setupFbAdsID');


        if (AdsVariable.isPurchase) {
          Future.delayed(const Duration(seconds: 3), () {
            print('**call navigateScreen***');
            navigateScreen();
          });
          return; // Avoid loading and displaying ads for premium users
        }

        ///LOAD AND SHOW OPEN OR SPLASH AD BASED ON CONDITION

        await Check.init();

        //loadPreLoadIntroFullNativeAds();
        //loadSmallThirdIntroNativeAds();
        // Only load survey/intro native ads on the very first app launch.
        // On subsequent opens the survey & intro screens never appear again,
        // so loading these ads would waste network calls and memory.
        if (SharedPrefService.getIsFirstTime()) {
          debugPrint('🆕 [AdsSplash] First launch detected → loading survey native ads.');
          if(AdsVariable.showSurveyScreen){
            debugPrint("======Show surveryScreen is true======");
            loadPreLoadLanguageNativeAds1();
            loadPreLoadLanguageNativeAds2();
          }
        } else {
          debugPrint('🔁 [AdsSplash] Returning user → skipping survey native ads (not needed).');
        }

        Future.delayed(const Duration(seconds: 0), () async {
          if (AdsVariable.OpenAdInSplash!) {
            print('call open ad in splash condition');
            AdsLoadUtil().loadAndShowOpenAd(
              navigateScreen,
              AdsVariable.appOpenAdsIOS,
            );
          } else {
            print('----call else part-----');
            AdsLoadUtil().loadInterSplash(
              navigateScreen,
              AdsVariable.interSplashIOS,
            );
          }
        });
      } on PlatformException catch (exception) {
        showLog("Exception is $exception");
        navigateScreen();
      } catch (exception) {
        showLog("Exception is $exception");
        navigateScreen();
      }
    } else {
      print("Not Connected");
      navigateScreen();
    }
  }

  late AppLifecycleReactor appLifecycleReactor;

  Future<void> loadAppOpenAd() async {
    showLog("Load from BG...");
    AppOpenAdManager appOpenAdManager = AppOpenAdManager()
      ..loadAd(AdsVariable.appOpenAdsIOS);
    await appOpenAdManager.loadAd(AdsVariable.appOpenAdsIOS);
    appOpenAdManager.showAdIfAvailable(AdsVariable.appOpenAdsIOS);
    appLifecycleReactor = AppLifecycleReactor(
      appOpenAdManager: appOpenAdManager,
    );
    AppLifecycleReactor(
      appOpenAdManager: appOpenAdManager,
    ).listenToAppStateChanges();
  }

  final storage = FlutterSecureStorage();

  Future<void> fetchPurchase() async {
    try {
      final isTester = prefs.getBool('is_tester_premium') ?? false;
      final customerInfo = await Purchases.getCustomerInfo();
      if (isTester || (customerInfo.entitlements.all[entitlementKey] != null &&
          customerInfo.entitlements.all[entitlementKey]!.isActive == true)) {
        AdsVariable.isPurchase = true;
        AdsVariable.resetAdIds();
      } else {
        print("print falls");
        AdsVariable.isPurchase = false;
      }
      if (AdsVariable.isPurchase) {
        showLog("Purchase ----->${AdsVariable.isPurchase}");
        AdsVariable.resetAdIds;
      }
    } catch (e) {
      showLog("PURCHASE_ERROR >> ${e.toString()}");
    }
  }
}

void premiumInit() {
  if (Platform.isIOS || Platform.isMacOS) {
    StoreConfig(store: Store.appStore, apiKey: appleApiKey);
  } else if (Platform.isAndroid) {
    const useAmazon = bool.fromEnvironment("amazon");
    StoreConfig(
      store: useAmazon ? Store.amazon : Store.playStore,
      apiKey: useAmazon ? amazonApiKey : googleApiKey,
    );
  }
}

Future<void> setupFbAdsId() async {
  showLog("Call 1");
  const platformMethodChannel = MethodChannel('nativeChannel');
  showLog("Call 2");
  if (Platform.isIOS) {
    platformMethodChannel.invokeMethod('setToast', {
      'isPurchase': AdsVariable.isPurchase.toString(),
      'fb_appid': AdsVariable.facebookId,
      'fb_token': AdsVariable.facebookToken,
      'nativeBGColor': AdsVariable.nativeBGColor,
      'btnBgColor': AdsVariable.btnBgColorG1,
      'btnTextColor': AdsVariable.btnTextColor,
      'headerTextColor': AdsVariable.headerTextColor,
      'bodyTextColor': AdsVariable.bodyTextColor,
    });
  } else {
    platformMethodChannel.invokeMethod('setToast', {
      'isPurchase': AdsVariable.isPurchase.toString(),
      'fb_appid': AdsVariable.facebookId,
      'fb_token': AdsVariable.facebookToken,
      'nativeBGColor': AdsVariable.nativeBGColor,
      'btnBgColorG1': AdsVariable.btnBgColorG1,
      'btnBgColorG2': AdsVariable.btnBgColorG2,
      'btnTextColor': AdsVariable.btnTextColor,
      'headerTextColor': AdsVariable.headerTextColor,
      'bodyTextColor': AdsVariable.bodyTextColor,
    });
  }

  showLog("Call 3");
}

Future<void> loadPreLoadLanguageNativeAds1() async {
  showLog("Call Method loadPreLoadLanguageNativeAds1");
  AdsVariable.nativeBigAdSurvey1 = await AdsLoadUtil().loadSurveyBigNative1(
    AdsVariable.bigNativeSurveyAdIOS1,
    true,
  );
  showLog(
    "AdsVariable.bigNativeSurveyAdIOS1 --->${AdsVariable.bigNativeSurveyAdIOS1}",
  );
  showLog(
    "AdsVariable.nativeBigAdSurvey1 ----===>${AdsVariable.nativeBigAdSurvey1?.adUnitId ?? ''}",
  );
  // showToast("Big Native 1 load");
}

Future<void> loadPreLoadLanguageNativeAds2() async {
  showLog("Call Method loadPreLoadLanguageNativeAds2");
  AdsVariable.nativeBigAdSurvey2 = await AdsLoadUtil().loadSurveyBigNative2(
    AdsVariable.bigNativeSurveyAdIOS2,
    true,
  );
  showLog(
    "AdsVariable.bigNativeSurveyAdIOS2 --->${AdsVariable.bigNativeSurveyAdIOS2}",
  );
  showLog(
    "AdsVariable.nativeBigAdSurvey2 ----===>${AdsVariable.nativeBigAdSurvey2?.adUnitId ?? ''}",
  );
  // showToast("Big Native 2 load");
}

void showToast(String msg) {
  Fluttertoast.showToast(msg: msg);
}

void loadPreLoadIntroFullNativeAds() async {
  showLog("Call Method loadPreLoadIntroFullNativeAds ");
  AdsVariable.fullNativeAdIntro = await AdsLoadUtil().loadIntroFullNative(
    AdsVariable.fullNativeIntroAdIOS,
    false,
  );
  showLog(
    "AdsVariable.fullNativeIntroAdIOS --->${AdsVariable.fullNativeIntroAdIOS}",
  );
  showLog(
    "AdsVariable.fullNativeAdIntro ----===>${AdsVariable.fullNativeAdIntro?.adUnitId ?? ''}",
  );
  // showToast("Full Native load");
}

void loadSmallThirdIntroNativeAds() async {
  showLog("Call Method loadPreLoadIntroFullNativeAds ");
  AdsVariable.smallThirdNativeAdIntro = await AdsLoadUtil()
      .loadSmallThirdIntroNative(
        AdsVariable.smallThirdIntroNativeIntroAdIOS,
        true,
      );
  showLog(
    "AdsVariable.fullNativeIntroAdIOS --->${AdsVariable.smallThirdIntroNativeIntroAdIOS}",
  );
  showLog(
    "AdsVariable.fullNativeAdIntro ----===>${AdsVariable.smallThirdNativeAdIntro?.adUnitId ?? ''}",
  );
}

/// GDPR Implementation methods : initializeGDPR, changePrivacyPreferences, loadConsentForm, initializeMobileAds

Future<FormError?> initializeGDPR() async {
  final completer = Completer<FormError?>();
  final params = ConsentRequestParameters(); //
  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await isPrivacyOptionsStatus()) {
        await loadConsentForm();
      } else {
        await initializeWithOutGDPR();
      }
      completer.complete();
    },
    (error) {
      log("ERROR ==> ${error.message}");
      completer.complete(error);
    },
  );

  return completer.future;
}

Future<TrackingStatus> initializeWithOutGDPR() async {
  final completer = Completer<TrackingStatus>();
  AppTrackingTransparency.requestTrackingAuthorization().then((value) async {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.authorized) {
      print("GDPR: TrackingStatus.required");
      await initializeMobileAds();
      completer.complete(TrackingStatus.authorized);
    } else {
      print("GDPR: TrackingStatus Not Required");
      await initializeMobileAds();
      completer.complete(TrackingStatus.denied);
    }
  });
  return completer.future;
}

Future<bool> changePrivacyPreferences() async {
  final completer = Completer<bool>();

  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadConsentForm(
          (consentForm) {
            consentForm.show((formError) async {
              await initializeMobileAds();
              completer.complete(true);
            });
          },
          (formError) {
            completer.complete(false);
          },
        );
      } else {
        completer.complete(false);
      }
    },
    (error) {
      completer.complete(false);
    },
  );

  return completer.future;
}

void showPrivacyOptionsForm(
  OnConsentFormDismissedListener onConsentFormDismissedListener,
) {
  ConsentForm.showPrivacyOptionsForm(onConsentFormDismissedListener);
}

Future<FormError?> loadConsentForm() async {
  final completer = Completer<FormError?>();

  ConsentForm.loadConsentForm(
    (consentForm) async {
      final status = await ConsentInformation.instance.getConsentStatus();
      if (status == ConsentStatus.required) {
        consentForm.show((formError) {
          completer.complete(loadConsentForm());
        });
      } else {
        await initializeMobileAds();
        completer.complete();
      }
    },
    (FormError? error) {
      completer.complete(error);
    },
  );

  return completer.future;
}

Future<void> initializeMobileAds() async {
  if (await isPrivacyOptionsStatus()) {
    AdsVariable.isPrivacyOptionsRequired = true;
  } else {
    AdsVariable.isPrivacyOptionsRequired = false;
  }
  await MobileAds.instance.initialize();
}

Future<bool> isPrivacyOptionsStatus() async {
  return await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;
}

Future<void> checkAndShowInAppReview(String key) async {
  log('enter in app review function');
  final prefs = await SharedPreferences.getInstance();
  final hasShown = prefs.getBool(key) ?? false;
  final inAppReview = InAppReview.instance;
  if (!hasShown && await inAppReview.isAvailable()) {
    await inAppReview.requestReview();
    await prefs.setBool(key, true); // Mark as shown
    log('show review box');
  }
}
