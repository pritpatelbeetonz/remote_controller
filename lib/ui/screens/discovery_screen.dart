import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'pairing_screen.dart';
import 'package:lottie/lottie.dart';
import 'remote_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RemoteScreen(manager: widget.manager),
            ),
          );
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

    if (widget.manager.connectionState == TvConnectionState.connected) {
      _scanTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RemoteScreen(manager: widget.manager),
        ),
      );
    } else if (widget.manager.connectionState == TvConnectionState.pairing) {
      _scanTimer?.cancel();
      // Transition to pairing screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PairingScreen(manager: widget.manager),
        ),
      );
    }
  }

  void _connectManually() {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid IP address'),
          backgroundColor: AppTheme.error,
        ),
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
    return Scaffold(
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
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_rounded),
        ),
        //centerTitle: true,
        actions: [
          // IconButton(
          //   icon: Icon(
          //     Icons.terminal,
          //     color: _showLogs ? AppTheme.primary : Colors.white54,
          //   ),
          //   onPressed: () {
          //     setState(() {
          //       _showLogs = !_showLogs;
          //     });
          //   },
          // ),
          // Container(
          //   padding: EdgeInsets.symmetric(
          //     horizontal: 19.9.w,
          //     vertical: 15.5.h,
          //   ),
          //   decoration: BoxDecoration(
          //     color: Colors.white.withValues(alpha: 0.06),
          //     borderRadius: BorderRadius.circular(28.r),
          //   ),
          //   child: manager.isScanning
          //       ? Text(
          //           'Stop Searching',
          //           style: TextStyle(
          //             color: Colors.white,
          //             fontFamily: 'SF Pro Display',
          //             fontWeight: FontWeight.w500,
          //             fontSize: 16.15.sp,
          //           ),
          //         )
          //       : Text('Start Searching'),
          // ),
          SizedBox(width: 5.w,)
,        ],
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
            final displayedDevices = manager.discoveredDevices
                .where((d) => d.brand == widget.selectedBrand)
                .toList();
            return Column(
              children: [
                // Scanning Header status
                if (displayedDevices.isNotEmpty || _showManualInput)
                  Padding(
                    padding: const EdgeInsets.all(00.0),
                    child: Column(
                      children: [
                        if (manager.isScanning) ...[

                        ] else ...[
                          const Icon(Icons.tv_off, color: Colors.white24, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Scanning Stopped',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Text(
                        //   'Ensure your ${widget.selectedBrand} is connected to the same local Wi-Fi network.',
                        //   textAlign: TextAlign.center,
                        //   style: Theme.of(context).textTheme.bodyMedium,
                        // ),
                      ],
                    ),
                  ),

                // Discovered Devices list
                Expanded(
                  child: displayedDevices.isEmpty
                      ? _buildScanningPlaceholder()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: displayedDevices.length + 1,
                          itemBuilder: (context, index) {
                            if (index == displayedDevices.length) {
                              // Show manual input form at the bottom of the list
                              return Column(
                                children: [
                                  const Divider(
                                    color: AppTheme.border,
                                    height: 32,
                                  ),
                                  _buildManualInputSection(),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }

                            final device = displayedDevices[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppTheme.surface,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tv,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                title: Text(
                                  device.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${device.brand} • ${device.ipAddress}:${device.port}',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.primary,
                                ),
                                onTap: () {
                                  manager.connectToDevice(device);
                                },
                              ),
                            );
                          },
                        ),
                ),

                // Logs console drawer at the bottom
                if (_showLogs)
                  LogConsoleDrawer(
                    manager: manager,
                    onClose: () {
                      setState(() {
                        _showLogs = false;
                      });
                    },
                  ),
              ],
            );
          },
        ),
      ),
      ),
    );
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
