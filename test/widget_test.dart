import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/core/tv_remote_manager.dart';
import 'package:remote_controller/ui/screens/brand_selection_screen.dart';

void main() {
  testWidgets('App starts and shows brand selection screen', (WidgetTester tester) async {
    final manager = TvRemoteManager();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, child) => MaterialApp(
          home: BrandSelectionScreen(manager: manager),
        ),
      ),
    );
    
    // Verify that the debug switch is present on the screen
    expect(find.text('Debug Mode (Bypass Auth)'), findsOneWidget);
  });
}
