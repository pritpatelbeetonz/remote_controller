import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tv_remote_adapter.dart';
import '../adapters/android_tv_adapter.dart';

enum TvConnectionState {
  disconnected,
  connecting,
  connected,
  pairing,
  failed,
}

class LogEntry {
  final String level;
  final String tag;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() {
    final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${(timestamp.millisecond).toString().padLeft(3, '0')}";
    return "[$timeStr] [$level] [$tag] $message";
  }
}

class TvRemoteManager extends ChangeNotifier {
  final TvRemoteAdapter adapter = AndroidTvAdapter();

  List<TvDevice> _discoveredDevices = [];
  List<TvDevice> get discoveredDevices => _discoveredDevices;

  TvDevice? _currentDevice;
  TvDevice? get currentDevice => _currentDevice;

  TvConnectionState _connectionState = TvConnectionState.disconnected;
  TvConnectionState get connectionState => _connectionState;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  String? _pairingPin;
  String? get pairingPin => _pairingPin;

  String? _pairingStatusMessage;
  String? get pairingStatusMessage => _pairingStatusMessage;

  StreamSubscription? _logSubscription;

  TvRemoteManager() {
    _initLogging();
  }

  void _initLogging() {
    _logSubscription = adapter.logs.listen(
      (logData) {
        final entry = LogEntry(
          level: logData['level'] as String? ?? 'DEBUG',
          tag: logData['tag'] as String? ?? 'NATIVE',
          message: logData['message'] as String? ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            logData['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _logs.add(entry);
        if (_logs.length > 500) {
          _logs.removeAt(0); // Cap history size
        }
        notifyListeners();
      },
      onError: (e) {
        addLocalLog('ERROR', 'MANAGER', 'Log stream subscription error: $e');
      },
    );
    addLocalLog('INFO', 'MANAGER', 'Logger initialized. Log streaming started.');
  }

  void addLocalLog(String level, String tag, String message) {
    _logs.add(LogEntry(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
    ));
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    addLocalLog('INFO', 'MANAGER', 'Logs cleared.');
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    _discoveredDevices = [];
    notifyListeners();

    addLocalLog('INFO', 'MANAGER', 'Starting network service discovery for Android TV...');
    try {
      await adapter.startDiscovery((devices) {
        _discoveredDevices = devices;
        addLocalLog('DEBUG', 'MANAGER', 'Discovered ${devices.length} devices total.');
        notifyListeners();
      });
    } catch (e) {
      addLocalLog('ERROR', 'MANAGER', 'Discovery initialization failed: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await adapter.stopDiscovery();
    addLocalLog('INFO', 'MANAGER', 'Network discovery stopped.');
    notifyListeners();
  }

  Future<void> connectToDevice(TvDevice device) async {
    _currentDevice = device;
    _connectionState = TvConnectionState.connecting;
    notifyListeners();

    addLocalLog('INFO', 'MANAGER', 'Connecting to TV: ${device.name} (${device.ipAddress}:${device.port})...');

    final success = await adapter.connect(device);
    if (success) {
      addLocalLog('INFO', 'MANAGER', 'TLS connection established. Initiating pairing check.');
      _connectionState = TvConnectionState.pairing;
      notifyListeners();

      // Trigger pairing session automatically
      await _startPairingFlow();
    } else {
      addLocalLog('ERROR', 'MANAGER', 'Connection failed to TV ${device.name}.');
      _connectionState = TvConnectionState.failed;
      notifyListeners();
    }
  }

  Future<void> _startPairingFlow() async {
    addLocalLog('INFO', 'MANAGER', 'Starting Polo pairing handshake protocol...');
    final success = await adapter.startPairing(
      onPin: (pin) {
        _pairingPin = pin;
        addLocalLog('INFO', 'MANAGER', 'Pairing PIN displayed on TV: $pin');
        notifyListeners();
      },
      onStatus: (status) {
        _pairingStatusMessage = status;
        addLocalLog('DEBUG', 'MANAGER', 'Pairing state changed natively to: $status');
        if (status == 'SUCCESS') {
          _connectionState = TvConnectionState.connected;
          addLocalLog('INFO', 'MANAGER', 'TV Remote pairing successfully completed! Remote is ready.');
        } else if (status == 'FAILED') {
          _connectionState = TvConnectionState.failed;
          addLocalLog('ERROR', 'MANAGER', 'TV Remote pairing failed.');
        }
        notifyListeners();
      },
    );

    if (!success) {
      addLocalLog('ERROR', 'MANAGER', 'Failed to start pairing handshake.');
      _connectionState = TvConnectionState.failed;
      notifyListeners();
    }
  }

  Future<void> submitPin(String pin) async {
    if (_connectionState != TvConnectionState.pairing) return;
    addLocalLog('INFO', 'MANAGER', 'Submitting pairing PIN code: $pin');
    final success = await adapter.sendPin(pin);
    if (!success) {
      addLocalLog('ERROR', 'MANAGER', 'PIN submission failed.');
      notifyListeners();
    }
  }

  Future<void> sendPress(TvKey key) async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot send keypress $key: Remote is not fully connected.');
      return;
    }
    addLocalLog('DEBUG', 'MANAGER', 'Sending key command: ${key.name}');
    final success = await adapter.sendKey(key);
    if (!success) {
      addLocalLog('ERROR', 'MANAGER', 'Failed to send command ${key.name}.');
    }
  }

  Future<void> disconnect() async {
    addLocalLog('INFO', 'MANAGER', 'Disconnecting session...');
    await adapter.disconnect();
    _currentDevice = null;
    _connectionState = TvConnectionState.disconnected;
    _pairingPin = null;
    _pairingStatusMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    adapter.disconnect();
    super.dispose();
  }
}
