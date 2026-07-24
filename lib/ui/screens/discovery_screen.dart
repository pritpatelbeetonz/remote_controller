import 'package:flutter/material.dart';
import '../../core/tv_remote_adapter.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/log_console_drawer.dart';
import 'pairing_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final TvRemoteManager manager;

  const DiscoveryScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '6466');

  @override
  void initState() {
    super.initState();
    // Auto start scanning when discovery screen opens
    widget.manager.startScan();
    widget.manager.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onStateChange);
    widget.manager.stopScan();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (widget.manager.connectionState == TvConnectionState.pairing) {
      // Transition to pairing screen
      Navigator.push(
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
      name: 'Custom Android TV',
      ipAddress: ip,
      port: port,
      brand: 'Android TV',
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
                    'Ensure your Android TV has remote services enabled and is connected to the same network.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Discovered Devices list
            Expanded(
              child: manager.discoveredDevices.isEmpty
                  ? _buildManualInputForm()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: manager.discoveredDevices.length + 1,
                      itemBuilder: (context, index) {
                        if (index == manager.discoveredDevices.length) {
                          // Show manual input form at the bottom of the list
                          return Column(
                            children: [
                              const Divider(color: AppTheme.border, height: 32),
                              _buildManualInputSection(),
                              const SizedBox(height: 20),
                            ],
                          );
                        }

                        final device = manager.discoveredDevices[index];
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
                            subtitle: Text('${device.ipAddress}:${device.port}'),
                            trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
                            onTap: () {
                              manager.connectToDevice(device);
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Logs console drawer at the bottom
            LogConsoleDrawer(manager: manager),
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
                  shadowColor: AppTheme.primary.withOpacity(0.5),
                  elevation: 5,
                ),
                child: const Text('CONNECT'),
              ),
            ],
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
