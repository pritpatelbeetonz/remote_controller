import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:remote_controller/for_ads/utils/firebase_analysis.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../../for_ads/utils/app_constants.dart';
import '../../for_ads/utils/shared_prefrence_service.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'pairing_screen.dart';
import 'package:lottie/lottie.dart';
import 'remote_screen.dart';
import 'package:remote_controller/for_ads/ads/ads_variable.dart';
import 'brand_selection_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final TvRemoteManager manager;
  final String selectedBrand;

  const DiscoveryScreen({
    Key? key,
    required this.manager,
    required this.selectedBrand,
  }) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController _ipController = TextEditingController();
  late final TextEditingController _portController;
  bool _showManualInput = false;
  bool _showLogs = false;
  Timer? _scanTimer;
  late String _selectedBrand;
  bool _isNavigating = false;

  @override
  void initState() {
    FirebaseAnalyticsService.logEvent(eventName: 'DISCOVERY_SCREEN');
    super.initState();
    if (SharedPrefService.getIsFirstTime()) {
      SharedPrefService.setIsFirstTime(false);
      showLog("Entered First page");
    }
    _selectedBrand = widget.selectedBrand;
    String initialPort;
    if (_selectedBrand == 'Samsung Tizen') {
      initialPort = '8002';
    } else if (_selectedBrand == 'LG webOS') {
      initialPort = '3000';
    } else if (_selectedBrand == 'Roku') {
      initialPort = '8060';
    } else if (_selectedBrand == 'Amazon Fire TV') {
      initialPort = '8080';
    } else if (_selectedBrand == 'Apple TV') {
      initialPort = '7000';
    } else {
      initialPort = '6466';
    }
    _portController = TextEditingController(text: initialPort);
    // Auto start scanning when discovery screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.manager.startScan();
      }
    });
    widget.manager.addListener(_onStateChange);

    // Scan for 2 minutes. If no devices found, redirect to RemoteScreen anyway.
    _scanTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) {
        if (widget.manager.discoveredDevices.isEmpty) {
          Get.off(() => RemoteScreen(manager: widget.manager));
        }
      }
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    widget.manager.removeListener(_onStateChange);
    widget.manager.stopScan();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
    }

    if (_isNavigating) return;

    if (widget.manager.connectionState == TvConnectionState.connected) {
      _isNavigating = true;
      _scanTimer?.cancel();
      Get.off(() => RemoteScreen(manager: widget.manager));
    } else if (widget.manager.connectionState == TvConnectionState.pairing) {
      _isNavigating = true;
      _scanTimer?.cancel();
      // Transition to pairing screen
      Get.off(() => PairingScreen(manager: widget.manager));
    }
  }

  void _connectManually() {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    if (ip.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a valid IP address',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
      return;
    }
    final port = int.tryParse(portStr) ?? 6466;

    final device = TvDevice(
      id: ip,
      name: 'Manual $_selectedBrand ($ip)',
      ipAddress: ip,
      port: port,
      brand: _selectedBrand,
    );

    widget.manager.stopScan();
    widget.manager.connectToDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Connect Device',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20.sp,
            fontFamily: 'SF Pro Display',
            //letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.selectedBrand == 'All'
            ? null
            : IconButton(
                onPressed: () {
                  AdsVariable.onShowAds(
                    context,
                    onComplete: () {
                      Get.back();
                    },
                  );
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          TextButton(
            onPressed: () {
              AdsVariable.onShowAds(
                context,
                onComplete: () {
                  widget.manager.stopScan();
                  Get.offAll(() => RemoteScreen(manager: widget.manager));
                },
              );
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          SizedBox(width: 16.w),
        ],
      ),
      body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/home/bg.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Builder(
          builder: (context) {
            if (!manager.isWifiConnected && !manager.bypassAuthentication && !manager.bypassToPairing) {
              return _buildWifiDisconnectedView();
            }

            final displayedDevices = widget.selectedBrand == 'All'
                ? manager.discoveredDevices
                : manager.discoveredDevices
                    .where((d) => d.brand == widget.selectedBrand)
                    .toList();

            if (_showManualInput && displayedDevices.isEmpty) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),
                    const Center(child: RadarIndicator()),
                    SizedBox(height: 24.h),
                    Center(
                      child: Text(
                        widget.manager.isScanning ? 'Searching WiFi Network...' : 'Searching Stopped',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: Text(
                        'Make sure both your phone and TV are connected \n to the same Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15.sp,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                    Text(
                      'TV Brand',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                        fontFamily: 'SF Pro Display',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Android TV', child: Text('Android TV / Google TV')),
                          DropdownMenuItem(value: 'Samsung Tizen', child: Text('Samsung Tizen TV')),
                          DropdownMenuItem(value: 'LG webOS', child: Text('LG Smart TV (webOS)')),
                          DropdownMenuItem(value: 'Roku', child: Text('Roku TV')),
                          DropdownMenuItem(value: 'Amazon Fire TV', child: Text('Amazon Fire TV')),
                          DropdownMenuItem(value: 'Apple TV', child: Text('Apple TV')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBrand = val;
                              if (val == 'Samsung Tizen') {
                                _portController.text = '8002';
                              } else if (val == 'LG webOS') {
                                _portController.text = '3000';
                              } else if (val == 'Roku') {
                                _portController.text = '8060';
                              } else if (val == 'Amazon Fire TV') {
                                _portController.text = '8080';
                              } else if (val == 'Apple TV') {
                                _portController.text = '7000';
                              } else {
                                _portController.text = '6466';
                              }
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'TV IP Address',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                        fontFamily: 'SF Pro Display',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                      decoration: InputDecoration(
                        hintText: 'e.g, 192.168.1.100',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16.sp),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Port (Remote Service v2)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                        fontFamily: 'SF Pro Display',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _portController.text,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(value: _portController.text, child: Text(_portController.text)),
                          if (_portController.text != '8002') const DropdownMenuItem(value: '8002', child: Text('8002')),
                          if (_portController.text != '3000') const DropdownMenuItem(value: '3000', child: Text('3000')),
                          if (_portController.text != '8060') const DropdownMenuItem(value: '8060', child: Text('8060')),
                          if (_portController.text != '8080') const DropdownMenuItem(value: '8080', child: Text('8080')),
                          if (_portController.text != '7000') const DropdownMenuItem(value: '7000', child: Text('7000')),
                          if (_portController.text != '6466') const DropdownMenuItem(value: '6466', child: Text('6466')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _portController.text = val;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 30.h),
                    GestureDetector(
                      onTap: _connectManually,
                      child: Container(
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(33.33.r),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                          ),
                        ),
                        child: Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: Colors.white,
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              );
            }

            if (displayedDevices.isNotEmpty) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    const Center(child: RadarIndicator()),
                    SizedBox(height: 16.h),
                    _buildSelectBrandButton(),
                    SizedBox(height: 16.h),
                    Center(
                      child: Text(
                        widget.manager.isScanning ? 'Searching WiFi Network...' : 'Searching Stopped',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: Text(
                        'Make sure both your phone and TV are connected \n to the same Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15.sp,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    ...displayedDevices.map((device) {
                      return GestureDetector(
                        onTap: () {
                          manager.connectToDevice(device);
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60.w,
                                height: 44.h,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8.r),
                                  image: DecorationImage(
                                    image: AssetImage(_getBrandImage(device.brand)),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '(${device.ipAddress})',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 14.sp,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Can't find your TV? Connect manually",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _ipController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                                  decoration: InputDecoration(
                                    hintText: 'e.g, 192.168.1.100',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16.sp),
                                    filled: true,
                                    fillColor: const Color(0xFF131315),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _portController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                                  decoration: InputDecoration(
                                    hintText: 'Port',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16.sp),
                                    filled: true,
                                    fillColor: const Color(0xFF131315),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          GestureDetector(
                            onTap: _connectManually,
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 56.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(33.33.r),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                                ),
                              ),
                              child: Text(
                                'Connect',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  color: Colors.white,
                                  fontFamily: 'SF Pro Display',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                SizedBox(height: 10.h),
                const RadarIndicator(),
                SizedBox(height: 16.h),
                _buildSelectBrandButton(),
                SizedBox(height: 16.h),
                Text(
                  widget.manager.isScanning ? 'Searching WiFi Network...' : 'Searching Stopped',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Make sure both your phone and TV are connected \n to the same Wi-Fi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 15.sp,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showManualInput = true;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(33.33.r),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                        ),
                      ),
                      child: Text(
                        'Connect Manually',
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.white,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    ));
  }

  Widget _buildManualInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.settings_ethernet,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'MANUAL DEVICE CONNECT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                dropdownColor: AppTheme.surfaceElevated,
                decoration: InputDecoration(
                  labelText: 'TV Brand',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Android TV',
                    child: Text('Android TV / Google TV'),
                  ),
                  DropdownMenuItem(
                    value: 'Samsung Tizen',
                    child: Text('Samsung Tizen TV'),
                  ),
                  DropdownMenuItem(
                    value: 'LG webOS',
                    child: Text('LG Smart TV (webOS)'),
                  ),
                  DropdownMenuItem(value: 'Roku', child: Text('Roku TV')),
                  DropdownMenuItem(
                    value: 'Amazon Fire TV',
                    child: Text('Amazon Fire TV'),
                  ),
                  DropdownMenuItem(value: 'Apple TV', child: Text('Apple TV')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedBrand = val;
                      if (val == 'Samsung Tizen') {
                        _portController.text = '8002';
                      } else if (val == 'LG webOS') {
                        _portController.text = '3000';
                      } else if (val == 'Roku') {
                        _portController.text = '8060';
                      } else if (val == 'Amazon Fire TV') {
                        _portController.text = '8080';
                      } else if (val == 'Apple TV') {
                        _portController.text = '7000';
                      } else {
                        _portController.text = '6466';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'TV IP Address',
                  hintText: 'e.g. 192.168.1.100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port (Remote Service v2)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _connectManually,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                  elevation: 5,
                ),
                child: const Text('CONNECT'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showManualInput = false;
                  });
                },
                child: const Text(
                  'Back to Auto Scan',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getBrandImage(String brand) {
    if (brand == 'Samsung Tizen') return 'assets/tv images/Samsung.png';
    if (brand == 'LG webOS') return 'assets/tv images/Lg.png';
    if (brand == 'Roku') return 'assets/tv images/roku.png';
    if (brand == 'Amazon Fire TV') return 'assets/tv images/Amazon fire tv.png';
    if (brand == 'Apple TV') return 'assets/tv images/Apple Tv.png';
    return 'assets/tv images/Sony.png';
  }

  Widget _buildSelectBrandButton() {
    return GestureDetector(
      onTap: () {
        widget.manager.stopScan();
        Get.to(() => BrandSelectionScreen(manager: widget.manager));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.tv_rounded, color: Colors.white, size: 22.sp),
                SizedBox(width: 12.w),
                Text(
                  'Select TV Brand',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningPlaceholder() {
    if (_showManualInput) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              const RadarIndicator(),
              SizedBox(height: 30.h),
              Text(
                widget.manager.isScanning ? 'Searching WiFi Network...' : 'Searching Stopped',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Make sure both your phone and TV are connected \n to the same Wi-Fi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15.sp,
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 30.h),
              _buildFieldTitle('TV Brand'),
              DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  value: _selectedBrand,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Android TV', child: Text('Android TV / Google TV')),
                    DropdownMenuItem(value: 'Samsung Tizen', child: Text('Samsung Tizen TV')),
                    DropdownMenuItem(value: 'LG webOS', child: Text('LG Smart TV (webOS)')),
                    DropdownMenuItem(value: 'Roku', child: Text('Roku TV')),
                    DropdownMenuItem(value: 'Amazon Fire TV', child: Text('Amazon Fire TV')),
                    DropdownMenuItem(value: 'Apple TV', child: Text('Apple TV')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBrand = val;
                        if (val == 'Samsung Tizen') {
                          _portController.text = '8002';
                        } else if (val == 'LG webOS') {
                          _portController.text = '3000';
                        } else if (val == 'Roku') {
                          _portController.text = '8060';
                        } else if (val == 'Amazon Fire TV') {
                          _portController.text = '8080';
                        } else if (val == 'Apple TV') {
                          _portController.text = '7000';
                        } else {
                          _portController.text = '6466';
                        }
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 16.h),
              _buildFieldTitle('TV IP Address'),
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                decoration: InputDecoration(
                  hintText: 'e.g, 192.168.1.100',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16.sp),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _buildFieldTitle('Port (Remote Service v2)'),
              DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  value: _portController.text,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontFamily: 'SF Pro Display'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: _portController.text, child: Text(_portController.text)),
                    if (_portController.text != '8002') const DropdownMenuItem(value: '8002', child: Text('8002')),
                    if (_portController.text != '3000') const DropdownMenuItem(value: '3000', child: Text('3000')),
                    if (_portController.text != '8060') const DropdownMenuItem(value: '8060', child: Text('8060')),
                    if (_portController.text != '8080') const DropdownMenuItem(value: '8080', child: Text('8080')),
                    if (_portController.text != '7000') const DropdownMenuItem(value: '7000', child: Text('7000')),
                    if (_portController.text != '6466') const DropdownMenuItem(value: '6466', child: Text('6466')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _portController.text = val;
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 30.h),
              GestureDetector(
                onTap: _connectManually,
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(33.33.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
        child: Column(
          children: [
            //const Spacer(),
            const RadarIndicator(),
            SizedBox(height: 48.h),
            Text(
              widget.manager.isScanning ? 'Searching WiFi Network...' : 'Searching Stopped',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Make sure both your phone and TV are connected \n to the same Wi-Fi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15.sp,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showManualInput = true;
                });
              },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 56.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(33.33.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  'Connect Manually',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.white,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
          ],
        ),
      );
    }
  }

  Widget _buildFieldTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14.sp,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildManualInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Can't find your TV? Connect manually:",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'IP Address (e.g. 192.168.1.5)',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Port',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _connectManually,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(12),
                minimumSize: Size.zero,
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWifiDisconnectedView() {
    final hasMobileData = widget.manager.currentConnectivity.contains(ConnectivityResult.mobile);
    
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (hasMobileData ? AppTheme.warning : AppTheme.error).withValues(alpha: 0.2),
                  width: 2.w,
                ),
              ),
              child: Icon(
                hasMobileData ? Icons.signal_cellular_nodata_rounded : Icons.wifi_off_rounded,
                size: 72.r,
                color: hasMobileData ? AppTheme.warning : AppTheme.error,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              hasMobileData ? 'Wi-Fi Connection Required' : 'No Network Connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              hasMobileData
                  ? 'You are currently connected to Mobile Data. Smart TV control requires a local Wi-Fi connection.\n\nPlease connect your phone to the same Wi-Fi network as your TV.'
                  : 'Your phone is offline. Please turn on Wi-Fi and connect to the same network as your TV to discover and control devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15.sp,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            SizedBox(height: 36.h),
            GestureDetector(
              onTap: () {
                Connectivity().checkConnectivity().then((result) {
                  Fluttertoast.showToast(
                    msg: 'Checking connection...',
                    backgroundColor: AppTheme.info,
                    textColor: Colors.white,
                  );
                });
              },
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 56.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(33.33.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF794DEB), Color(0xFF512CB8)],
                  ),
                ),
                child: Text(
                  'Check Connection',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.white,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadarIndicator extends StatelessWidget {
  const RadarIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      "assets/process.json",
      width: 250.w,
      height: 250.w,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback loader if the Lottie asset is not yet bundled or fails to load
        return Container(
          width: 160.w,
          height: 160.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6338F8).withValues(alpha: 0.3),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }
}
