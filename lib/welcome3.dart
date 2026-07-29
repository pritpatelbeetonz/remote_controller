import 'package:flutter/material.dart';

import '../../for_ads/utils/firebase_analysis.dart';

class Welcome3 extends StatelessWidget {
  const Welcome3({super.key});

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.logEvent(eventName: 'INTRO_SCREEN_3');
    return PopScope(
      canPop: false,
      child: Image.asset(
        "assets/Onboarding 3/Onboarding 3.png",
        width: double.infinity,
        height:double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
