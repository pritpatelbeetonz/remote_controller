import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:remote_controller/splash_view.dart';
import 'package:showcaseview/showcaseview.dart';
import 'core/onboarding/onboarding_service.dart';
import 'core/logger/logger.dart';
import 'core/tv_remote_manager.dart';
import 'for_ads/utils/app_constants.dart';
import 'for_ads/utils/shared_prefrence_service.dart';
import 'for_ads/utils/store_config.dart';
import 'ui/themes/app_theme.dart';

void main() async {

  // Ensure Flutter engine bindings are initialized prior to channel invokes
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefService.init();
  await MobileAds.instance.initialize();

  // Initialize ShowcaseView / Onboarding configs
  OnboardingService().initialize();

  await Firebase.initializeApp();
  await AppLogger.initialize(
    sinks: [
      ConsoleLogSink(),
    ],
  );
  AppLogger.info('App', 'Application started — session: ${AppLogger.sessionId}');

  // Now that AppLogger sinks are registered, create TvRemoteManager.
  final manager = TvRemoteManager();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  if (Platform.isIOS || Platform.isMacOS) {
    print("object");
    StoreConfig(store: Store.appStore, apiKey: appleApiKey);
  } else if (Platform.isAndroid) {
    // Run the app passing --dart-define=AMAZON=true
    const useAmazon = bool.fromEnvironment("amazon");
    StoreConfig(
      store: useAmazon ? Store.amazon : Store.playStore,
      apiKey: useAmazon ? amazonApiKey : googleApiKey,
    );
  }

  await configureSDK();

  runApp(MyApp(manager: manager));
}

Future<void> configureSDK() async {
  try {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (StoreConfig.isForAmazonAppstore()) {
      configuration = AmazonConfiguration(StoreConfig.instance.apiKey);
    } else {
      configuration = PurchasesConfiguration(StoreConfig.instance.apiKey);
    }

    configuration.entitlementVerificationMode =
        EntitlementVerificationMode.informational;
    await Purchases.configure(configuration);

    // ✅ ADD THIS — register renewal listener immediately after configure
    // SubscriptionCreditService.initUpdateListener();

    await Purchases.enableAdServicesAttributionTokenCollection();

    final offerings = await Purchases.getOfferings();
    if (offerings.current != null) {
      ('✅ Offering found: ${offerings.current!.identifier}');
      for (final pkg in offerings.current!.availablePackages) {
        print('👉 Package: ${pkg.identifier}');
        print('👉 Product: ${pkg.storeProduct.identifier}');
      }
    } else {
      print('⚠️ No current offering found');
    }
  } catch (e, st) {
    print('❌ Error configuring SDK or fetching offerings: $e');
    print(st);
  }
}

class MyApp extends StatelessWidget {
  final TvRemoteManager manager;
  static late TvRemoteManager globalManager;

  MyApp({super.key, required this.manager}) {
    globalManager = manager;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(428, 926),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return ShowCaseWidget(
          builder: (context) => GetMaterialApp(
            title: 'Universal TV Remote',
            theme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
