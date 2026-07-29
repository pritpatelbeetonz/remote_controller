
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
 import 'package:get/get.dart';

@protected
final scaffoldGlobalKey = GlobalKey<ScaffoldState>();

class LoadingScreen {
  final GlobalKey globalKey;

  LoadingScreen(this.globalKey);

  show([String? text]) {
    showDialog<String>(
      context: Get.context!,
      builder: (BuildContext context) => Scaffold(
        backgroundColor: const Color.fromRGBO(0, 0, 0, 0.3),
        body: Container(
          decoration: BoxDecoration(
            // borderRadius: BorderRadius.circular(15.w),
            color: Colors.black.withOpacity(0.5),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                
                ///CHANGE IT AS PER APP THEME
                /////changes done :- chnages as needed
                CupertinoActivityIndicator(color: Colors.white,radius: 20.r,),
                SizedBox(height: 60.h,),
                Text(
                  "Showing Ads",
                  style: TextStyle(
                    color: Colors.white,
                    //changes done :- change if needed
                    fontSize: 20.sp,
                    fontFamily: "Medium"
                  ),
                ).marginSymmetric(horizontal: 50.w, vertical: 5.w),
              ],
            ),
          ),
        ),
      ),
    );
  }

  hide() {
    if (Get.context == null) return;
    Navigator.pop(Get.context!);
  }
}

@protected
var loadingScreen = LoadingScreen(scaffoldGlobalKey);
