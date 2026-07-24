import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/core/tv_remote_manager.dart';
import 'package:remote_controller/main.dart';

void main() {
  testWidgets('App starts and shows discovery screen', (WidgetTester tester) async {
    final manager = TvRemoteManager();
    await tester.pumpWidget(MyApp(manager: manager));
    
    // Verify that the header CONNECT DEVICE is present on the screen
    expect(find.text('CONNECT DEVICE'), findsOneWidget);
  });
}
