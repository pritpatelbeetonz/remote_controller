import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'for_ads/utils/firebase_analysis.dart';

class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  late WebViewController controller;
  RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService.logEvent(eventName: 'PRIVACY_POLICY_SCREEN');
    try {
      if (Platform.isAndroid) {
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(true)
          ..loadFlutterAsset('assets/luka_privacy.html')
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                setState(() {
                  isLoading.value = true;
                });
              },
              onPageFinished: (url) {
                setState(() {
                  isLoading.value = false;
                });
                injectDarkCss();
              },
            ),
          );
        controller.setBackgroundColor(Colors.white);
      } else {
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                isLoading.value = true;
              },
              onPageFinished: (url) {
                isLoading.value = false;
                injectDarkCss();
              },
            ),
          )
          ..loadRequest(
            Uri.parse(
              'https://nidhirola.blogspot.com/2025/01/privacy-policy.html',
            ),
          );
      }
    } catch (e) {
      log("Webview Error :- $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/Browse Categories/back_button.png',
                    width: 35.w,
                    height: 35.h,
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            title: Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
            centerTitle: true,
          ),
          body: Obx(
            () => isLoading.value
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                  )
                : WebViewWidget(controller: controller),
          ),
        ),
      ),
    );
  }

  void injectDarkCss() {
    controller.runJavaScript("""
    (function() {
      var style = document.createElement('style');
      style.type = 'text/css';
      style.innerHTML = `
        html, body {
          background-color: #14151A !important;
          color: #ffffff !important;
        }
        * {
          color: #ffffff !important;
          background-color: transparent !important;
        }
        a { color: #4da6ff !important; }
      `;
      document.head.appendChild(style);
    })();
  """);
  }
}
