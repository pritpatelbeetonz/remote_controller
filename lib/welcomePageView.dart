import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:remote_controller/main.dart';
import 'package:remote_controller/ui/screens/brand_selection_screen.dart';
import 'package:remote_controller/welcome1.dart';
import 'package:remote_controller/welcome2.dart';
import 'package:remote_controller/welcome3.dart';
import '../../for_ads/ads/ads_variable.dart';
import '../../for_ads/utils/app_constants.dart';
import '../../for_ads/utils/firebase_analysis.dart';
import 'PremiumCreditView.dart';
import 'RatingScreen.dart';

class WelPageview extends StatefulWidget {
  const WelPageview({super.key});

  State<WelPageview> createState() => WelPageviewState();
}

class WelPageviewState extends State<WelPageview> {
  final PageController pageController = PageController(initialPage: 0);
  int currentIndex = 0;
  bool isInterNetConnected = false;
  bool _hasRequestedReview = false; // <-- Add this

  @override
  void initState() {
    FirebaseAnalyticsService.logEvent(eventName: 'INTROSCREENS');
    super.initState();
    checkInterNetConnectivity();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> checkInterNetConnectivity() async {
    if (await AdsVariable.isInternetConnected()) {
      setState(() {
        isInterNetConnected = true;
      });
    }
  }

  // Without ad: 3 pages (intro1, intro2, intro3)
  int dataLength = 3;

  // Returns number of visible dots (always 3 — one per intro screen)
  int GetDots(int dataLength) {
    return 3;
  }

  // Maps the raw page index to a dot index (0, 1, or 2).
  int getDotIndex(int currentIndex, int dataLength) {
    return currentIndex;
  }

  Widget bottomnavigation(int dataLength, int currentIndex) {
    final List<String> titles = [
      "Connect to Your\n Smart TV",
      "Control All TV \n Apps",
      "Instant Screen \n Casting",
    ];

    final List<String> Subtitles = [
      "Link your phone to your smart TV for fast and \n reliable control.",
      "Easily navigate and launch entertainment apps \n without your TV remote.",
      "Cast photos, videos, and more from your phone \n to the big screen in just a few taps.",
    ];

    final int dotIdx = getDotIndex(currentIndex, dataLength);

    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Container(
            height: 210.h,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  titles[dotIdx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  Subtitles[dotIdx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15.sp,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),

                Spacer(),

                //dots
                GestureDetector(
                  onTap: () {
                    if (currentIndex == dataLength - 1) {
                      AdsVariable.showRateUsDialogInIntro ?
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Ratingscreen(),
                        ),
                        (route) => false,
                      ) : Navigator.push(context, MaterialPageRoute(builder: (context)=>PremiumCreditView(onboarding: true, onDone: (){})));
                    } else {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    width: 382.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(33.33.r),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          offset: const Offset(0, 4),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      currentIndex == dataLength - 1 ? "Continue" : 'Continue',
                      style: TextStyle(
                        fontSize: 20.sp,
                        color: Colors.white,
                        fontFamily: 'SF Pro Display',
                        fontWeight: FontWeight.w700,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 760.h,
                child: PageView(
                  controller: pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  children: [
                    Welcome1(isActive: currentIndex == 0),
                    Welcome2(isActive: currentIndex == 1),
                    Welcome3(isActive: currentIndex == 2),
                  ],
                ),
              ),

              // Bottom black gradient shade for text readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 450.h,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Show bottom nav
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
