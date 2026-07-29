import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../for_ads/utils/firebase_analysis.dart';

class Welcome1 extends StatelessWidget {
  const Welcome1({super.key});

  @override
  Widget build(BuildContext context) {
    FirebaseAnalyticsService.logEvent(eventName: 'INROSCREEN_1');
    return PopScope(
      canPop: false,
      child: Image.asset(
        "assets/Onboarding 1/Onboarding 1.png",
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
