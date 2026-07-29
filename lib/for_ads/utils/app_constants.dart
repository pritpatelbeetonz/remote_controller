import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

showLog(String msg) {
  print("LOG >> $msg");
}
//TO DO: add the Apple API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
const appleApiKey = '';

const String iosAppId = '6751265116';


//TO DO: add the Google API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
const googleApiKey = 'goog_aJDsFyaWEyFCGDRgVOjYqcdbzbH';

//TO DO: add the Amazon API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
const amazonApiKey = '';

const entitlementKey = 'AndroidTestProAccess';



class GlobalVariables {

  static Map<String, Package>? availablePackages;

  static Future<bool> isInternetConnected() {
    return Connectivity().checkConnectivity().then((connectivityResult) {
      if (connectivityResult ==ConnectivityResult.none) {
        return false;
      } else {
        return true;
      }
    });
  }
}
