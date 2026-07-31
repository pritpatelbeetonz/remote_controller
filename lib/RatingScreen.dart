import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../for_ads/ads/ads_splash_utils.dart';
import '../for_ads/ads/ads_variable.dart';
import '../for_ads/utils/firebase_analysis.dart';
import 'package:remote_controller/main.dart';
import 'package:remote_controller/ui/screens/discovery_screen.dart';
import 'PremiumCreditView.dart';

class Ratingscreen extends StatefulWidget {
  const Ratingscreen({super.key});

  @override
  State<Ratingscreen> createState() => _RatingscreenState();
}

class _RatingscreenState extends State<Ratingscreen> {
  bool isratedialog = false;

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.logEvent(eventName: 'RATE_US_SCREEN');
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Container(
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/survay & rate/bg.png"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (isratedialog) {
                        final hasNet = await AdsVariable.isInternetConnected();
                        if (!hasNet) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiscoveryScreen(
                                manager: MyApp.globalManager,
                                selectedBrand: 'All',
                              ),
                            ),
                            (route) => false,
                          );
                        } else {
                          if (AdsVariable.isPurchase) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DiscoveryScreen(
                                  manager: MyApp.globalManager,
                                  selectedBrand: 'All',
                                ),
                              ),
                              (route) => false,
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PremiumCreditView(
                                  onboarding: true,
                                  onDone: () {},
                                ),
                              ),
                            );
                          }
                        }
                      } else {
                        await checkAndShowInAppReview("FromRateusScreen");
                        Future.delayed(Duration(seconds: 2), () {
                          setState(() {
                            isratedialog = true;
                          });
                        });
                      }
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: 62.h,
                      alignment: Alignment.center,
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
                        isratedialog ? "Continue" : "Rate Us Now",
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
            // Positioned(
            //   top: 50.h,
            //   left: 20.w,
            //   child: GestureDetector(
            //     onTap: () {
            //       Navigator.pushReplacement(
            //         context,
            //         MaterialPageRoute(
            //           builder: (_) => PremiumCreditView(
            //             onboarding: true,
            //             onDone: () {
            //               Navigator.push(
            //                 context,
            //                 MaterialPageRoute(
            //                   builder: (context) => HomeScreen(),
            //                 ),
            //               );
            //             },
            //           ),
            //         ),
            //       );
            //     },
            //     child: Container(
            //       padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 5.w),
            //       child: Image.asset(
            //         "assets/Images/close.png",
            //         width: 30.w,
            //         height: 30.h,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
      ),
    );
  }
}
