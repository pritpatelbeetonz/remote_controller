
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../for_ads/ads/ads_splash_utils.dart';
import '../for_ads/ads/ads_variable.dart';
import '../for_ads/utils/firebase_analysis.dart';
import 'PremiumCreditView.dart';

class Ratingscreen extends StatefulWidget {
  const Ratingscreen({super.key,});

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
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.bottomCenter,
                // decoration: BoxDecoration(
                //   image: DecorationImage(
                //     image: AssetImage("assets/Images/rate us screen (2).png"),
                //     fit: BoxFit.cover,
                //   ),
                // ),
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
                              MaterialPageRoute(builder: (_) => MainView()),
                              (route) => false,
                            );
                          } else {
                            if (AdsVariable.isPurchase) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => MainView()),
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
                        width: 350.w,
                        height: 62.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Color(0xFF3C8AFF), borderRadius: BorderRadius.circular(60.r)),
                        child: Text(
                          isratedialog ? "Continue" : "Rate us Now",
                          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600,color: Colors.white),
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
    );
  }
}
