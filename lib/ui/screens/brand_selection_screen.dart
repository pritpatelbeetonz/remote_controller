import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 5.h,),
                Text('Choose TV brand to get started',style: TextStyle(fontSize: 20.sp,fontWeight: FontWeight.w500,color: Colors.white),),
                kDebugMode ? AnimatedBuilder(
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
                ):SizedBox.shrink(),
                const SizedBox(height: 10),
                () {
                  final List<Map<String, String>> brands = [
                    {'image': 'assets/tv images/roku.png', 'brand': 'Roku'},
                    {'image': 'assets/tv images/Samsung.png', 'brand': 'Samsung Tizen'},
                    {'image': 'assets/tv images/Lg.png', 'brand': 'LG webOS'},
                    {'image': 'assets/tv images/Amazon fire tv.png', 'brand': 'Amazon Fire TV'},
                    {'image': 'assets/tv images/Apple Tv.png', 'brand': 'Apple TV'},
                    {'image': 'assets/tv images/Sony.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/tcl.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Xiaomi (Mi TV).png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Hisense.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/OnePlus.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Panasonic.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Haier.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Philips.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Toshiba.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Sharp.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Skyworth.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Vu.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Acer.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Blaupunkt.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Motorola.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Nokia.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Kodak.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/JVC.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Kogan.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Konka.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Hitachi.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Sanyo.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Thomson.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Westinghouse.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Changhong.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/Coocaa.png', 'brand': 'Android TV'},
                    {'image': 'assets/tv images/FFALCON.png', 'brand': 'Android TV'},
                  ];
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 5,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: brands.length,
                    itemBuilder: (context, index) {
                      final b = brands[index];
                      return _buildBrandCard(
                        image: b['image']!,
                        onTap: () => _onBrandSelected(context, b['brand']!),
                      );
                    },
                  );
                }(),
                const SizedBox(height: 20),
              ],
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
    required String image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
         image: DecorationImage(image: AssetImage(image)),
        ),
      ),
    );
  }
}
