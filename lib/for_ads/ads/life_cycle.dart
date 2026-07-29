import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/app_constants.dart';
import 'ads_load_util.dart';
import 'ads_variable.dart';
import 'app_open_ad.dart';
/// Listens for app foreground events and shows app open ads.
class AppLifecycleReactor {
  final AppOpenAdManager appOpenAdManager;

  AppLifecycleReactor({required this.appOpenAdManager});

  void listenToAppStateChanges({bool shouldShow = true}) {
    showLog("AppLifecycleReactor Listen Called");
    showLog("AshouldShow -: $shouldShow");
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.forEach((state) {
      showLog("AppLifecycleReactor Should Show $shouldShow");
      showLog("State is ${state}");
      if (shouldShow && !AdsVariable.isPurchase) {
        onAppStateChanged(state);
      }else{
        showLog("NOT SHOW");
      }
    });
  }

  void onAppStateChanged(AppState appState) {
    showLog("In ON APP STATE CHANGED");
    if (appState == AppState.foreground) {
      debugPrint("App State :- $appState");
      showLog('FOREGROUND');

      appOpenAdManager.showAdIfAvailable(AdsVariable.appOpenAdsIOS);
    }else if(appState==AppState.background){
      print(AdsVariable.appOpenAdsIOS);
      ///TODO: CHANGES
      showLog('BACKGROUND');
      ///When App Go In Background If Ad is not available then it will load open Ad
      if (!AppOpenAdManager().isAdAvailable) {
        showLog("AD NOT AVAILABLE");
        AdsLoadUtil().loadAppOpen();
      }
    }
  }
}
