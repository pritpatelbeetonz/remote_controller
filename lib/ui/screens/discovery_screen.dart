import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'pairing_screen.dart';
import 'remote_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final TvRemoteManager manager;
  final String selectedBrand;

  const DiscoveryScreen({Key? key, required this.manager, required this.selectedBrand}) : super(key: key);

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
      appBar: AppBar(
        title: const Text(
          'CONNECT DEVICE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.terminal,
              color: _showLogs ? AppTheme.primary : Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _showLogs = !_showLogs;
              });
            },
          ),
          IconButton(
            icon: Icon(
              manager.isScanning ? Icons.stop : Icons.refresh,
              color: AppTheme.primary,
            ),
            onPressed: () {
              if (manager.isScanning) {
                manager.stopScan();
              } else {
                manager.startScan();
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scanning Header status
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (manager.isScanning) ...[
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scanning Local WiFi Network...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    const Icon(Icons.tv_off, color: Colors.white24, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Scanning Stopped',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Ensure your ${widget.selectedBrand} is connected to the same local Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Discovered Devices list
            Expanded(
              child: () {
                final displayedDevices = manager.discoveredDevices
                    .where((d) => d.brand == widget.selectedBrand)
                    .toList();
                return displayedDevices.isEmpty
                    ? (_showManualInput ? _buildManualInputForm() : _buildScanningPlaceholder())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayedDevices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == displayedDevices.length) {
                            // Show manual input form at the bottom of the list
                            return Column(
                              children: [
                                const Divider(color: AppTheme.border, height: 32),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tv, color: AppTheme.primary),
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('${device.brand} • ${device.ipAddress}:${device.port}'),
                              trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
                              onTap: () {
                                manager.connectToDevice(device);
                              },
                            ),
                          );
                        },
                      );
              }(),
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
                  Icon(Icons.settings_ethernet, color: AppTheme.primary, size: 20),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_find,
                  color: AppTheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Searching for TVs...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.selectedBrand == 'Android TV'
                      ? 'This scan uses multicast DNS to locate Android TV or Google TV devices automatically.'
                      : 'This scan uses SSDP network discovery to locate ${widget.selectedBrand} devices automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showManualInput = true;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('CONNECT MANUALLY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
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
