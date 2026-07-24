import 'package:flutter/material.dart';
import 'core/tv_remote_manager.dart';
import 'ui/themes/app_theme.dart';
import 'ui/screens/discovery_screen.dart';

void main() {
  // Ensure Flutter engine bindings are initialized prior to channel invokes
  WidgetsFlutterBinding.ensureInitialized();
  
  final manager = TvRemoteManager();
  
  runApp(MyApp(manager: manager));
}

class MyApp extends StatelessWidget {
  final TvRemoteManager manager;

  const MyApp({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal TV Remote',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: DiscoveryScreen(manager: manager),
    );
  }
}
