import 'dart:developer';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:lottie/lottie.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:remote_controller/welcomePageView.dart';
import 'package:remote_controller/main.dart';
import 'package:remote_controller/ui/screens/brand_selection_screen.dart';
import 'package:get/get.dart';
import '../../for_ads/ads/ads_splash_utils.dart';
import '../../for_ads/ads/ads_variable.dart';
import '../../for_ads/utils/app_constants.dart';
import '../../for_ads/utils/firebase_analysis.dart';
import '../../for_ads/utils/shared_prefrence_service.dart';
import 'PremiumCreditView.dart';
import 'SurveyScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint("*****///***** adsvarible === ${AdsVariable.isPurchase}......");
    WidgetsBinding.instance.addPostFrameCallback((callback) async {
      FirebaseAnalyticsService.logEvent(eventName: 'SPLASH_SCREEN');
      await AdsSplashUtils().getOnlineIds(
        navigateScreen: () async {
          log('navigate screen');

          /// todo :- when to test purchase
          fetchData();
          navigatingToNextActivity();
        },
      );
    });
  }

  void navigatingToNextActivity() async {
    bool isFirstLaunch = SharedPrefService.getIsFirstTime();
    if (isFirstLaunch) {
      AdsVariable.showSurveyScreen
          ? Get.off(SurveyForm())
          : Get.off(WelPageview()); //SurveyForm()
    } else {
      if (AdsVariable.isPurchase) {
        Get.offAll(() => BrandSelectionScreen(manager: MyApp.globalManager));
      } else {
        Get.offAll(
          () => PremiumCreditView(
            onboarding: true,
            onDone: () {
              Get.offAll(
                () => BrandSelectionScreen(manager: MyApp.globalManager),
              );
            },
          ),
        );
      }
    }
  }

  Future<void> fetchData() async {
    print("get price");
    Offerings? offerings;
    try {
      offerings = await Purchases.getOfferings();
      if (kDebugMode) {
        print(offerings);
      }

      GlobalVariables.availablePackages = {
        for (var package in offerings.current?.availablePackages ?? [])
          package.identifier: package,
      };
      print(GlobalVariables.availablePackages);
      void printLongString(String text) {
        final pattern = RegExp(
          '.{1,800}',
        ); // Splits the string every 800 characters
        pattern.allMatches(text).forEach((match) => print(match.group(0)));
      }

      // Usage
      printLongString(
        "availablePackages ********** ${GlobalVariables.availablePackages}",
      );

      // print(
      //     "availablePackages ********** ${GlobalVariables.availablePackages}");

      if ((GlobalVariables.availablePackages?.entries ?? []).length >= 2) {}
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("get error");

        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Image.asset(
                "assets/splash/bg.png",
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/splash/icon.png",
                      width: 185.w,
                      height: 185.w,
                    ),
                    // SizedBox(height: 24.h,),
                    // Column(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     Text(
                    //       "Framz",
                    //       style: TextStyle(
                    //         fontSize: 38.54.sp,
                    //         color: Colors.white,
                    //         fontFamily: 'Inter',
                    //         fontWeight: FontWeight.w700,
                    //       ),
                    //     ),
                    //     SizedBox(height: 4.h),
                    //     Text(
                    //       "Where Memories Meet Design",
                    //       style: TextStyle(
                    //         color: Colors.white,
                    //         fontSize: 14.sp,
                    //         fontWeight: FontWeight.w300,
                    //         fontFamily: 'Inter',
                    //       ),
                    //     ),
                    //     // SizedBox(height: 5.h),
                    //   ],
                    // )
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20.h,
                child: Column(
                  children: [
                    Text('Universal Remote', style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontFamily: 'SF Pro Display',
                    )),
                    SizedBox(height: 16.h),
                    Center(
                      child: Container(
                        width: 260.w,
                        height: 6.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100.r),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
