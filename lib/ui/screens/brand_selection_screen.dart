import 'package:flutter/material.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import 'discovery_screen.dart';
import 'pairing_screen.dart';
import 'remote_screen.dart';

class BrandSelectionScreen extends StatelessWidget {
  final TvRemoteManager manager;

  const BrandSelectionScreen({Key? key, required this.manager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF020617), // Slate 950
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Premium Logo / Icon Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E293B),
                        border: Border.all(color: Colors.white10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings_remote_outlined,
                        color: AppTheme.primary,
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'UNIVERSAL TV REMOTE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select your television brand to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: manager,
                    builder: (context, _) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bug_report_outlined, color: AppTheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Debug Mode (Bypass Auth)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Switch(
                                    value: manager.bypassAuthentication,
                                    activeColor: AppTheme.primary,
                                    onChanged: (value) {
                                      manager.bypassAuthentication = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flash_on_outlined, color: Colors.amberAccent, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Bypass to Pairing Screen',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Switch(
                                    value: manager.bypassToPairing,
                                    activeColor: Colors.amberAccent,
                                    onChanged: (value) {
                                      manager.bypassToPairing = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                    children: [
                      // Android TV Card
                      _buildBrandCard(
                        context: context,
                        title: 'Android TV',
                        subtitle: 'Sony, TCL, Hisense, etc.',
                        icon: Icons.android_outlined,
                        glowColor: Colors.greenAccent,
                        onTap: () => _onBrandSelected(context, 'Android TV'),
                      ),
                      // Samsung Tizen Card
                      _buildBrandCard(
                        context: context,
                        title: 'Samsung TV',
                        subtitle: 'Tizen OS (2016+).',
                        icon: Icons.tv_outlined,
                        glowColor: Colors.blueAccent,
                        onTap: () => _onBrandSelected(context, 'Samsung Tizen'),
                      ),
                      // LG webOS Card
                      _buildBrandCard(
                        context: context,
                        title: 'LG TV',
                        subtitle: 'webOS (2014+).',
                        icon: Icons.personal_video_outlined,
                        glowColor: Colors.redAccent,
                        onTap: () => _onBrandSelected(context, 'LG webOS'),
                      ),
                      // Roku TV Card
                      _buildBrandCard(
                        context: context,
                        title: 'Roku TV',
                        subtitle: 'Roku sticks & TV sets.',
                        icon: Icons.play_circle_outline,
                        glowColor: Colors.deepPurpleAccent,
                        onTap: () => _onBrandSelected(context, 'Roku'),
                      ),
                      // Amazon Fire TV Card
                      _buildBrandCard(
                        context: context,
                        title: 'Fire TV',
                        subtitle: 'Firestick & Fire TV OS.',
                        icon: Icons.local_fire_department_outlined,
                        glowColor: Colors.orangeAccent,
                        onTap: () => _onBrandSelected(context, 'Amazon Fire TV'),
                      ),
                      // Apple TV Card
                      _buildBrandCard(
                        context: context,
                        title: 'Apple TV',
                        subtitle: 'Media Control & AirPlay.',
                        icon: Icons.video_library_outlined,
                        glowColor: Colors.blueGrey,
                        onTap: () => _onBrandSelected(context, 'Apple TV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onBrandSelected(BuildContext context, String brand) {
    if (manager.bypassToPairing) {
      final mockDevice = TvDevice(
        id: 'mock-${brand.toLowerCase().replaceAll(' ', '-')}',
        name: 'Mock $brand',
        ipAddress: '127.0.0.1',
        port: 8080,
        brand: brand,
      );
      manager.connectToDevice(mockDevice);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PairingScreen(manager: manager),
        ),
      );
      return;
    }

    if (manager.bypassAuthentication) {
      final mockDevice = TvDevice(
        id: 'mock-${brand.toLowerCase().replaceAll(' ', '-')}',
        name: 'Mock $brand',
        ipAddress: '127.0.0.1',
        port: 8080,
        brand: brand,
      );
      manager.connectToDevice(mockDevice);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RemoteScreen(manager: manager),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoveryScreen(
          manager: manager,
          selectedBrand: brand,
        ),
      ),
    );
  }

  Widget _buildBrandCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6), // Glassy backdrop
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          highlightColor: glowColor.withOpacity(0.1),
          splashColor: glowColor.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: glowColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: glowColor.withOpacity(0.2)),
                  ),
                  child: Icon(
                    icon,
                    color: glowColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
