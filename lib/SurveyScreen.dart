// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:remote_controller/welcomePageView.dart';
// import '../../for_ads/ads/ads_splash_utils.dart';
// import '../../for_ads/ads/ads_variable.dart';
// import '../../for_ads/utils/firebase_analysis.dart';
//
// enum UsageLocation { home, office, onTheGo, publicSpaces }
//
// class SurveyForm extends StatefulWidget {
//
//   const SurveyForm({super.key,});
//
//   @override
//   State<SurveyForm> createState() => SurveyFormState();
// }
//
// class SurveyFormState extends State<SurveyForm> {
//   UsageLocation? selectedLocation = UsageLocation.home;
//
//   @override
//   void initState() {
//     FirebaseAnalyticsService.logEvent(eventName: 'SURVEYSCREEN');
//     super.initState();
//     checkInterNetConnectivity();
//   }
//
//   bool isInterNetConnected = false;
//
//   Future<void> checkInterNetConnectivity() async {
//     if (await AdsVariable.isInternetConnected()) {
//       setState(() {
//         isInterNetConnected = true;
//         print('=>>>> Internet Connected');
//       });
//     }
//   }
//
//   int selectedIndex = -1;
//
//   //---------------------------------------------------------------main Scafold ---------------------------------------------
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: Colors.black,
//         body: SafeArea(
//           child: Padding(
//             padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 0.h),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 10.h,),
//                  /// Title
//                 SizedBox(
//                   width: MediaQuery.of(context).size.width,
//                   child: Row(
//                     children: [
//                       Text(
//                         "What would you like to \ntrack?",
//                         style: TextStyle(
//                           fontSize: 22.sp,
//                           fontWeight: FontWeight.w800,
//                           fontFamily: 'Geist',
//                           color: Colors.white,
//                           height: 1.2,
//                         ),
//                       ),
//                       const Spacer(),
//                       Visibility(
//                         visible: selectedIndex != -1,
//                         replacement: SizedBox(height: 36.h),
//                         child: GestureDetector(
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => WelPageview(),
//                               ),
//                             );
//                           },
//                           child: Container(
//                             width: 90.w,
//                             height: 36.h,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               image: const DecorationImage(
//                                 image: AssetImage("assets/survay & rate/done.png"),
//                                 fit: BoxFit.fill,
//                               ),
//                               borderRadius: BorderRadius.circular(80.r),
//                             ),
//                             child: Text(
//                               "Done",
//                               style: TextStyle(
//                                 fontSize: 16.sp,
//                                 fontWeight: FontWeight.w700,
//                                 fontFamily: 'Geist',
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 SizedBox(height: 10.h),
//                 Flexible(
//                   child: Column(
//                     children: [
//                       /// OPTIONS
//                       SurveyOption(
//                         title: "📺 Smart TV Control",
//                         index: 0,
//                         selectedIndex: selectedIndex,
//                         onTap: () {
//                           setState(() {
//                             selectedIndex = 0;
//                           });
//                         },
//                         image: "assets/Surway/collage_layouts.png",
//                         subtitle: "Control your TV with an easy-to-use remote.",
//                       ),
//                      SizedBox(height: 10.h),
//                       SurveyOption(
//                         title: "⚡ Quick TV Connection",
//                         index: 1,
//                         selectedIndex: selectedIndex,
//                         onTap: () {
//                           setState(() {
//                             selectedIndex = 1;
//                           });
//                         },
//                         image: "assets/Surway/premium_templets.png",
//                         subtitle: "Connect to compatible TVs in just seconds.",
//                       ),
//                       SizedBox(height: 10.h),
//                       SurveyOption(
//                         title: "📱 Screen Mirroring",
//                         index: 2,
//                         selectedIndex: selectedIndex,
//                         onTap: () {
//                           setState(() {
//                             selectedIndex = 2;
//                           });
//                         },
//                         image: "assets/Surway/photo_editor.png",
//                         subtitle: "Cast your phone screen to the big display.",
//                       ),
//                      SizedBox(height: 10.h),
//                       SurveyOption(
//                         title: "🎬 Streaming App Access",
//                         index: 3,
//                         selectedIndex: selectedIndex,
//                         onTap: () {
//                           setState(() {
//                             selectedIndex = 3;
//                           });
//                         },
//                         image: "assets/Surway/creative_background.png",
//                         subtitle: "Launch your favorite entertainment apps.",
//                       ),
//                     ],
//                   ),
//                 )
//
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class SurveyOption extends StatelessWidget {
//   final String title;
//   final int index;
//   final int selectedIndex;
//   final VoidCallback onTap;
//   final String image;
//   final String subtitle;
//
//   const SurveyOption({
//     super.key,
//     required this.title,
//     required this.index,
//     required this.selectedIndex,
//     required this.onTap,
//     required this.image,
//     required this.subtitle
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bool isSelected = selectedIndex == index;
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: MediaQuery.of(context).size.width,
//         decoration: BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage(
//               isSelected
//                   ? "assets/survay & rate/selected.png"
//                   : "assets/survay & rate/deseletced.png",
//             ),
//             fit: BoxFit.fill,
//           ),
//           borderRadius: BorderRadius.circular(20.r),
//         ),
//         padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
//         child: Row(
//           children: [
//             /// TEXT
//             Expanded(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: TextStyle(
//                       fontSize: 20.sp,
//                       fontWeight: FontWeight.w600,
//                       fontFamily: 'Geist',
//                       color: Colors.white,
//                     ),
//                   ),
//                   SizedBox(height: 6.h),
//                   Text(
//                     subtitle,
//                     style: TextStyle(
//                       fontSize: 15.sp,
//                       fontWeight: FontWeight.w400,
//                       fontFamily: 'Geist',
//                       color:Colors.white.withValues(alpha: 0.7),
//                     ),
//                   )
//                 ],
//               ),
//             ),
//             // if (isSelected)
//             //   Padding(
//             //     padding: EdgeInsets.only(left: 10.w),
//             //     child: const Icon(
//             //       Icons.check_rounded,
//             //       color: Colors.white,
//             //       size: 26,
//             //     ),
//             //   ),
//           ],
//         ),
//       ),
//     );
//   }
// }
