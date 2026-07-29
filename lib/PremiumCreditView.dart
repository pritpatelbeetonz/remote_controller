import 'dart:math';
import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:remote_controller/main.dart';
import 'package:remote_controller/ui/screens/brand_selection_screen.dart';
import 'for_ads/ads/ads_variable.dart';
import 'for_ads/ads/app_open_ad.dart';
import 'for_ads/ads/life_cycle.dart';
import 'for_ads/utils/app_constants.dart';
import 'for_ads/utils/firebase_analysis.dart';
import 'privacy_policy_screen.dart';
import 'for_ads/utils/shared_prefrence_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class PremiumCreditView extends StatefulWidget {
  final bool onboarding;
  final Function onDone;

  const PremiumCreditView({
    key,
    required this.onboarding,
    required this.onDone,
  }) : super(key: key);

  @override
  State<PremiumCreditView> createState() => _PremiumCreditViewState();
}

class _PremiumCreditViewState extends State<PremiumCreditView> {
  int selectedPlan = 0; // 0 = Annual, 1 = Monthly
  Map<String, Package>? packageEntry;
  Package? selectedPackage;
  bool isContinue = false;
  bool tryAgain = false;
  int discount = 50;
  String price1 = "₹49"; // Monthly
  String price2 = "₹299"; // Annual
  String symbol = "₹";
  String priceprweek = "₹25";

  AppOpenAdManager appOpenAdManager = AppOpenAdManager();
  late AppLifecycleReactor _appLifecycleReactor;
  bool _hasInternet = true;

  @override
  void initState() {
    if (widget.onboarding) {
      FirebaseAnalyticsService.logEvent(
        eventName: 'PREMIUM_SCREEN_FROM_INTRO_SCREEN',
      );
    } else {
      FirebaseAnalyticsService.logEvent(
        eventName: 'PREMIUM_SCREEN_FROM_OTHER_PAGES',
      );
    }

    isInternetConnected();
    PackageData();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _appLifecycleReactor = AppLifecycleReactor(
        appOpenAdManager: appOpenAdManager,
      );
      _appLifecycleReactor.listenToAppStateChanges(shouldShow: false);
    });

    super.initState();
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
              // 1. Collage background at top half
              Positioned.fill(
                child: Image.asset(
                  "assets/Premium/premium.png",
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Scrollable Body Contents
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + 180.h),
                      // Title
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          'Create Without Limits',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      
                      // Subtitle
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          "Unlock premium editing and templates.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      SizedBox(height: 28.h),
          
                      // 3. Features Card (rounded with thin border)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101012),
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              _featureRow("Export Without Watermarks"),
                              SizedBox(height: 14.h),
                              _featureRow("Unlimited Layouts"),
                              SizedBox(height: 14.h),
                              _featureRow("Unlimited Templates"),
                              SizedBox(height: 14.h),
                              _featureRow("Unlimited Share & save"),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
          
                      if (_hasInternet) ...[
                        // 4. Subscription Plan Cards Row
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Row(
                            children: [
                              // Annual Plan
                              Expanded(
                                child: _planCard(
                                  index: 0,
                                  title: "Annual Plan",
                                  price: price2,
                                  subtitle: "$priceprweek / Weekly",
                                  hasRibbon: true,
                                  ribbonText: "$discount% OFF",
                                  packgaedata: PackageType.annual,
                                ),
                              ),
            
                              SizedBox(width: 12.w),
                              // Monthly Plan
                              Expanded(
                                child: _planCard(
                                  index: 1,
                                  title: "Monthly Plan",
                                  price: price1,
                                  subtitle: "Cancel Anytime",
                                  hasRibbon: false,
                                  badgeText: "BEST VALUE",
                                  packgaedata: PackageType.monthly,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 30.h),
            
                        // 5. Upgrade Button
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                barrierDismissible: false,
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    contentPadding: EdgeInsets.zero,
                                    content: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 20.h,
                                          horizontal: 30.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF141416),
                                          borderRadius: BorderRadius.circular(16.r),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 24.w,
                                              height: 24.w,
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6F5BFF)),
                                              ),
                                            ),
                                            SizedBox(width: 16.w),
                                            Text(
                                              "Loading...",
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
            
                              _getPremiumVersion();
                            },
                            child: Container(
                              height: 56.h,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.r),
                                color: const Color(0xFF6F5BFF),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6F5BFF).withOpacity(0.6),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                "Upgrade to Premium",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Premium Offline Card
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            padding: EdgeInsets.all(24.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101012),
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  "Plans are unavailable offline",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  "Please connect to the internet to purchase premium subscriptions.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13.sp,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                GestureDetector(
                                  onTap: () {
                                    isInternetConnected();
                                    PackageData();
                                  },
                                  child: Container(
                                    height: 40.h,
                                    width: 120.w,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C2E),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      "Try Again",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 5.h),
                      GestureDetector(
                        onTap: () {
                          _showTesterLoginDialog(context);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Text(
                            "I am Tester",
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6F5BFF),
                              fontFamily: 'Inter',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5.h),
          
                      // 6. Terms & Privacy policy footer
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white38,
                              height: 1.5,
                              fontFamily: 'Inter',
                            ),
                            children: [
                              const TextSpan(
                                text: 'by continue, you accept our ',
                              ),
                              TextSpan(
                                text: 'terms of use',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Open terms
                                    _launchURL('https://www.google.com');
                                  },
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'privacy policy',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Open privacy policy view
                                    Get.to(() => const PrivacyPolicyView());
                                  },
                              ),
                              const TextSpan(
                                text: '\nsubscription auto renew, cancel anytime.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
          
              // 7. Top Navigation Bar (Back and Restore)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10.h,
                left: 16.w,
                right: 16.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onboarding) {
                          Get.offAll(() => BrandSelectionScreen(manager: MyApp.globalManager));
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // GestureDetector(
                    //   onTap: () async {
                    //     try {
                    //       CustomerInfo restoredInfo = await Purchases.restorePurchases();
                    //       if (restoredInfo.entitlements.all[entitlementKey]?.isActive == true) {
                    //         Fluttertoast.showToast(msg: "Purchases Restored Successfully!");
                    //         initPlatformState();
                    //       } else {
                    //         Fluttertoast.showToast(msg: "No active purchases found.");
                    //       }
                    //     } catch (e) {
                    //       Fluttertoast.showToast(msg: "Failed to restore: $e");
                    //     }
                    //   },
                    //   child: Text(
                    //     "Restore",
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 15.sp,
                    //       fontWeight: FontWeight.w600,
                    //       decoration: TextDecoration.underline,
                    //       fontFamily: 'Inter',
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> fetchData() async {
    if ((GlobalVariables.availablePackages?.entries ?? []).length >= 2) {
      selectedPackage = (GlobalVariables.availablePackages?.entries ?? [])
          .where((test) => test.value.packageType == PackageType.annual)
          .first
          .value;
    }
  }

  Future<void> PackageData() async {
    Offerings? offerings;
    try {
      offerings = await Purchases.getOfferings();
      GlobalVariables.availablePackages = {
        for (var package in offerings.current?.availablePackages ?? [])
          package.identifier: package,
      };

      setState(() {
        _hasInternet = true;
      });
      fetchData();
      getprice();
    } on PlatformException catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  void isInternetConnected() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      setState(() {
        _hasInternet = false;
      });
      Fluttertoast.showToast(
        msg: "No Internet Connection Found",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    } else {
      setState(() {
        _hasInternet = true;
      });
    }
  }

  void _getPremiumVersion() async {
    if (selectedPackage == null) {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Store is currently unavailable. Try again later.");
      return;
    }

    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(selectedPackage!),
      );
      final customerInfo = purchaseResult.customerInfo;

      appData.entitlementIsActive =
          customerInfo.entitlements.all[entitlementKey]!.isActive;
      initPlatformState();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (kDebugMode) {
        print('Purchase Error: $errorCode');
      }
    } finally {
      Navigator.pop(context);
    }
  }

  Future<void> initPlatformState() async {
    final customerInfo = await Purchases.getCustomerInfo();
    if (customerInfo.entitlements.all[entitlementKey] != null &&
        customerInfo.entitlements.all[entitlementKey]!.isActive == true) {
      AdsVariable.resetAdIds();
      AdsVariable.isPurchase = true;

      if (selectedPlan == 0) {
        FirebaseAnalyticsService.logEvent(eventName: 'YEAR_PLAN_PURCHASE');
      } else {
        FirebaseAnalyticsService.logEvent(eventName: 'MONTH_PLAN_PURCHASE');
      }

      Fluttertoast.showToast(
        msg: 'Successfully upgraded to Premium!',
        backgroundColor: const Color(0xFF6F5BFF),
        textColor: Colors.white,
      );

      if (widget.onboarding) {
        Get.offAll(() => BrandSelectionScreen(manager: MyApp.globalManager));
        widget.onDone();
      } else {
        Navigator.of(context).pop();
        widget.onDone();
      }
    } else {
      AdsVariable.isPurchase = false;
    }
  }

  Package? _firstWhereOrNull(Iterable<Package> list, bool Function(Package) test) {
    for (final element in list) {
      if (test(element)) return element;
    }
    return null;
  }

  void getprice() {
    if (GlobalVariables.availablePackages != null) {
      final monthlyPkg = _firstWhereOrNull(
        GlobalVariables.availablePackages!.values,
        (test) => test.packageType == PackageType.monthly,
      ) ?? _firstWhereOrNull(
        GlobalVariables.availablePackages!.values,
        (test) => test.packageType == PackageType.weekly,
      );

      final annualPkg = _firstWhereOrNull(
        GlobalVariables.availablePackages!.values,
        (test) => test.packageType == PackageType.annual,
      );

      if (monthlyPkg != null) {
        price1 = monthlyPkg.storeProduct.priceString;
      }
      if (annualPkg != null) {
        price2 = annualPkg.storeProduct.priceString;
        
        final double yearlyVal = annualPkg.storeProduct.price;
        final double monthlyAvg = yearlyVal / 12.0;
        symbol = price1.substring(0, 1);
        priceprweek = "$symbol${monthlyAvg.toStringAsFixed(0)}";
      }

      if (monthlyPkg != null && annualPkg != null) {
        final double monthlyVal = monthlyPkg.storeProduct.price;
        final double yearlyVal = annualPkg.storeProduct.price;
        if (monthlyVal > 0) {
          double fullYearCost = monthlyVal * 12;
          double discountVal = ((fullYearCost - yearlyVal) / fullYearCost) * 100;
          discount = discountVal.round();
        }
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _featureRow(String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Image.asset("assets/Premium/Frame.png", width: 22.w, height: 22.h),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required int index,
    required String title,
    required String price,
    required String subtitle,
    required bool hasRibbon,
    String? ribbonText,
    String? badgeText,
    required PackageType packgaedata,
  }) {
    final bool selected = selectedPlan == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = index;
          final packages = GlobalVariables.availablePackages;
          if (packages != null) {
            final match = packages.values
                .where((test) => test.packageType == packgaedata)
                .toList();
            if (match.isNotEmpty) {
              selectedPackage = match.first;
            }
          }
        });
      },
      child: Container(
        height: 140.h,
        decoration: BoxDecoration(
          color: const Color(0xFF101012),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? const Color(0xFF6F5BFF) : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2.w : 2.w,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6F5BFF).withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 25.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                 // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Spacer(),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price.replaceAll(RegExp(r'/(year|month|week)'), ''),
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                          TextSpan(
                            text: index == 0 ? '/year' : '/month',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFF6F5BFF) : Colors.white38,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              // 50% OFF diagonal ribbon banner (top right)
              if (hasRibbon && ribbonText != null)
                Positioned(
                  right: -28.w,
                  top: 10.h,
                  child: Transform.rotate(
                    angle: 45 * pi / 180,
                    child: Container(
                      width: 90.w,
                      height: 20.h,
                      color: const Color(0xFF6F5BFF),
                      alignment: Alignment.center,
                      child: Text(
                        ribbonText,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),

              // BEST VALUE pill badge (top right)
              if (!hasRibbon && badgeText != null)
                Positioned(
                  right: 0.w,
                  top: 0.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4.r)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTesterLoginDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        bool obscurePassword = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101012),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              title: Text(
                'Tester Login',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF6F5BFF),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF6F5BFF),
                          ),
                        ),
                        suffixIcon: IconButton(
                          splashRadius: 20,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.only(
                bottom: 16.h,
                right: 16.w,
                left: 16.w,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F5BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      debugPrint("tester Email :- $email");
                      debugPrint("tester Email :- $password");
                      debugPrint("firebase Email :- $email");
                      debugPrint("firebase Email :- $email");


                      try {
                        final testEmail = AdsVariable.testEmail.trim();
                        final testPassword = AdsVariable.testPassword.trim();
                        debugPrint("firebase Email :- $testEmail");
                        debugPrint("firebase Email :- $testPassword");
                        if (email == testEmail &&
                            password == testPassword) {
                          Navigator.pop(context);

                          // Enable Premium
                          AdsVariable.resetAdIds();
                          AdsVariable.isPurchase = true;

                          await SharedPrefService.sharedPreferences.setBool(
                            'is_tester_premium',
                            true,
                          );

                          Fluttertoast.showToast(
                            msg: 'Tester premium successfully activated!',
                            backgroundColor: const Color(0xFF6F5BFF),
                            textColor: Colors.white,
                          );

                          if (widget.onboarding) {
                            Get.offAll(() => BrandSelectionScreen(manager: MyApp.globalManager));
                            widget.onDone();
                          } else {
                            Navigator.of(context).pop();
                            widget.onDone();
                          }
                        } else {
                          Fluttertoast.showToast(
                            msg: 'Incorrect email or password.',
                            backgroundColor: Colors.redAccent,
                            textColor: Colors.white,
                          );
                        }
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: 'Error verifying credentials: $e',
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AppData {
  static final AppData _appData = AppData._internal();

  bool entitlementIsActive = false;
  String appUserID = '';

  factory AppData() {
    return _appData;
  }

  AppData._internal();
}

final appData = AppData();
