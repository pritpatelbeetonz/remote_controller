
import 'package:flutter/cupertino.dart';

import '../../for_ads/utils/firebase_analysis.dart';

class Welcome2 extends StatefulWidget {
  const Welcome2({super.key});

  @override
  State<Welcome2> createState() => _Welcome2State();
}

class _Welcome2State extends State<Welcome2> {


  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService.logEvent(eventName: 'INTRO_SCREEN_2');
  }

  @override
  void dispose() {
    // controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(canPop: false,child: Image.asset("assets/Onboarding 2/Onboarding 2.png",fit: BoxFit.cover));
  }
}