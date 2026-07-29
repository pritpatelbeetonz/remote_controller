import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:remote_controller/welcome1.dart';
import 'package:remote_controller/welcome2.dart';
import 'package:remote_controller/welcome3.dart';
import '../../for_ads/ads/ads_load_util.dart';
import '../../for_ads/ads/ads_variable.dart';
import '../../for_ads/utils/app_constants.dart';
import '../../for_ads/utils/firebase_analysis.dart';
import 'PremiumCreditView.dart';
import 'RatingScreen.dart';
import 'for_ads/ads/ads_splash_utils.dart';

class WelPageview extends StatefulWidget {
  const WelPageview({super.key});

  State<WelPageview> createState() => WelPageviewState();
}

class WelPageviewState extends State<WelPageview> {
  final PageController pageController = PageController(initialPage: 0);
  int currentIndex = 0;
  bool isInterNetConnected = false;
  bool _hasRequestedReview = false; // <-- Add this

  StreamSubscription? _adLoadedSubscription;
  StreamSubscription? _adFailedSubscription;

  @override
  void initState() {
    //FirebaseAnalyticsService.logEvent(eventName: 'INTROSCREENS');
    super.initState();
    checkInterNetConnectivity();
    _adLoadedSubscription = AdsLoadUtil.isFullNativeIntroAdLoaded.listen((_) {
      if (mounted) setDataLength();
    });
    _adFailedSubscription = AdsLoadUtil.isFullNativeAdFailedToLoadIntro.listen((
      _,
    ) {
      if (mounted) setDataLength();
    });
  }

  @override
  void dispose() {
    _adLoadedSubscription?.cancel();
    _adFailedSubscription?.cancel();
    pageController.dispose();
    super.dispose();
  }

  Future<void> checkInterNetConnectivity() async {
    if (await AdsVariable.isInternetConnected()) {
      setState(() {
        isInterNetConnected = true;
      });
      setDataLength();
    }
  }

  // Without ad: 3 pages (intro1, intro2, intro3)
  // With ad:    4 pages (intro1, intro2, ad, intro3)
  int dataLength = 3;

  void setDataLength() {
    if (AdsVariable.fullNativeIntroAdIOS == "11" ||
        AdsLoadUtil.isFullNativeAdFailedToLoadIntro.value == true ||
        AdsLoadUtil.isFullNativeIntroAdLoaded.value == false ||
        (!isInterNetConnected || AdsVariable.isPurchase)) {
      setState(() {
        dataLength = 3; // intro1, intro2, intro3
      });
    } else {
      setState(() {
        dataLength = 4; // intro1, intro2, ad, intro3
      });
    }
  }

  // Returns number of visible dots (always 3 — one per intro screen)
  int GetDots(int dataLength) {
    return 3;
  }

  // Maps the raw page index to a dot index (0, 1, or 2).
  // When ad is present (dataLength == 4), page 2 is the ad — skip it for dots.
  // Page 0 → dot 0, Page 1 → dot 1, ad page → dot 1, Page 3 → dot 2.
  int getDotIndex(int currentIndex, int dataLength) {
    if (dataLength == 4) {
      if (currentIndex == 0) return 0;
      if (currentIndex == 1) return 1;
      if (currentIndex == 2) return 1; // ad page
      if (currentIndex == 3) return 2;
    }
    // No ad: page 0 → dot 0, page 1 → dot 1, page 2 → dot 2
    return currentIndex;
  }

  Widget bottomnavigation(int dataLength, int currentIndex) {
    final List<String> titles = [
      "Beautiful Templates",
      "Design Every Memory",
      "Endless Layouts",
    ];

    final List<String> Subtitles = [
      "Discover the perfect layout for every memory.",
      "Create collages that tell your story.",
      "Choose a layout that fits your style.",
    ];

    // Hide bottom nav on the ad page
    if (dataLength == 4 && currentIndex == 2) {
      return const SizedBox.shrink();
    }

    final int dotIdx = getDotIndex(currentIndex, dataLength);

    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 190.h,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titles[dotIdx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),

               const SizedBox(height: 5),
                //Spacer(),

                Text(
                  Subtitles[dotIdx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                // const SizedBox(height: 15),
                Spacer(),


                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(GetDots(dataLength), (index) {
                    final bool isActive = dotIdx == index;
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: isActive ? 24.w : 8.w,
                      height: 8.h,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    );
                  }),
                ),

                //const SizedBox(height: 15),
                Spacer(),


                //dots
                GestureDetector(
                  onTap: () {
                    if (currentIndex == dataLength - 1) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PremiumCreditView(
                            onboarding: true,
                            onDone: () {
                              Get.offAllNamed(AppRoutes.home);
                            },
                          ),
                        ),
                        (route) => false,
                      );
                    } else {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    width: 358.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6F5BFF), Color(0xFF8A7DFF)],
                      ),
                    ),
                    child: Text(
                      currentIndex == dataLength - 1 ? "Get Started" : 'Next',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              PageView(
                controller: pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                  // Show review only once when Welcome2 is reached.
                  if (!_hasRequestedReview && index == 1) {
                    _hasRequestedReview = true;
                    AdsVariable.showRateUsDialogInIntro ?
                    checkAndShowInAppReview('onboarding_rate_us'):null;
                  }
                },
                // Without ad: [Welcome1, Welcome2, Welcome3]
                // With ad:    [Welcome1, Welcome2, FullNativeAdScreen, Welcome3]
                children: dataLength == 3
                    ? [const Welcome1(), const Welcome2(), const Welcome3()]
                    : [
                        const Welcome1(),
                        const Welcome2(),
                        const FullNativeAdScreen(),
                        const Welcome3(),
                      ],
              ),

              // Show bottom nav ONLY if not the ad page
              if (!(dataLength == 4 && currentIndex == 2))
                Align(
                  alignment: Alignment.bottomCenter,
                  child: bottomnavigation(dataLength, currentIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
