import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'tv_remote_adapter.dart';
import '../adapters/android_tv_adapter.dart';
import '../adapters/samsung_tizen_adapter.dart';
import '../adapters/lg_webos_adapter.dart';
import '../adapters/roku_adapter.dart';
import '../adapters/amazon_fire_tv_adapter.dart';
import '../adapters/apple_tv_adapter.dart';
import 'logger/app_logger.dart';
import '../for_ads/utils/firebase_analysis.dart';
import '../services/country_app_catalog.dart';
import '../for_ads/utils/shared_prefrence_service.dart';

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
  final List<TvRemoteAdapter> adapters = [
    AndroidTvAdapter(),
    SamsungTizenAdapter(),
    LgWebOsAdapter(),
    RokuAdapter(),
    AmazonFireTvAdapter(),
    AppleTvAdapter(),
  ];

  List<TvDevice> _discoveredDevices = [];
  List<TvDevice> get discoveredDevices => _discoveredDevices;

  TvDevice? _currentDevice;
  TvDevice? get currentDevice => _currentDevice;

  DateTime? _sessionStartTime;
  bool _wasDiscoverySuccessful = false;
  bool _wasTlsSuccessful = false;
  bool _wasPairingStarted = false;
  bool _wasPinDisplayed = false;
  bool _wasSecretAckReceived = false;
  bool _wasControlConnectionEstablished = false;

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

  String? _loadingMessage;
  String? get loadingMessage => _loadingMessage;

  bool _bypassAuthentication = false;
  bool get bypassAuthentication => _bypassAuthentication;
  set bypassAuthentication(bool value) {
    _bypassAuthentication = value;
    notifyListeners();
  }

  bool _bypassToPairing = false;
  bool get bypassToPairing => _bypassToPairing;
  set bypassToPairing(bool value) {
    _bypassToPairing = value;
    notifyListeners();
  }

  final List<StreamSubscription> _subscriptions = [];

  bool _isWifiConnected = true;
  bool get isWifiConnected => _isWifiConnected;

  List<ConnectivityResult> _currentConnectivity = [];
  List<ConnectivityResult> get currentConnectivity => _currentConnectivity;

  TvRemoteManager() {
    _initLogging();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    Connectivity().checkConnectivity().then((result) {
      _updateWifiStatus(result);
    });

    final sub = Connectivity().onConnectivityChanged.listen((result) {
      _updateWifiStatus(result);
    });
    _subscriptions.add(sub);
  }

  void _updateWifiStatus(List<ConnectivityResult> result) {
    _currentConnectivity = result;
    final hasWifi = result.contains(ConnectivityResult.wifi) ||
                    result.contains(ConnectivityResult.ethernet);
    if (_isWifiConnected != hasWifi) {
      _isWifiConnected = hasWifi;
      addLocalLog('INFO', 'MANAGER', 'Network connectivity changed. Wi-Fi connected: $_isWifiConnected');
      notifyListeners();

      if (!_isWifiConnected) {
        if (_isScanning) {
          addLocalLog('WARN', 'MANAGER', 'Wi-Fi disconnected. Pausing active scanner.');
        }
        if (_connectionState == TvConnectionState.connected ||
            _connectionState == TvConnectionState.connecting ||
            _connectionState == TvConnectionState.pairing) {
          addLocalLog('WARN', 'MANAGER', 'Wi-Fi lost. Disconnecting active session.');
          disconnect();
        }
      } else {
        if (_isScanning) {
          addLocalLog('INFO', 'MANAGER', 'Wi-Fi reconnected. Restarting scan.');
          stopScan().then((_) => startScan());
        }
      }
    }
  }

  void _initLogging() {
    for (final adapter in adapters) {
      final sub = adapter.logs.listen(
        (logData) {
          final rawTimestamp = logData['timestamp'];
          DateTime timestamp;
          if (rawTimestamp is DateTime) {
            timestamp = rawTimestamp;
          } else if (rawTimestamp is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
          } else {
            timestamp = DateTime.now();
          }

          final lvl = logData['level'] as String? ?? 'DEBUG';
          final tag = logData['tag'] as String? ?? 'NATIVE';
          final message = logData['message'] as String? ?? '';

          // Forward to AppLogger
          if (lvl == 'ERROR') {
            AppLogger.error(tag, message);
          } else if (lvl == 'WARN') {
            AppLogger.warning(tag, message);
          } else if (lvl == 'INFO') {
            AppLogger.info(tag, message);
          } else {
            AppLogger.debug(tag, message);
          }

          final entry = LogEntry(
            level: lvl,
            tag: tag,
            message: message,
            timestamp: timestamp,
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
      _subscriptions.add(sub);
    }
    addLocalLog('INFO', 'MANAGER', 'Logger initialized. Log streaming started.');
  }

  void addLocalLog(String level, String tag, String message) {
    // Forward to AppLogger
    if (level == 'ERROR') {
      AppLogger.error(tag, message);
    } else if (level == 'WARN') {
      AppLogger.warning(tag, message);
    } else if (level == 'INFO') {
      AppLogger.info(tag, message);
    } else {
      AppLogger.debug(tag, message);
    }

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

  TvRemoteAdapter _getAdapterForDevice(TvDevice? device) {
    final brand = device?.brand ?? 'Android TV';
    if (brand == 'Samsung Tizen') {
      return adapters.firstWhere((a) => a is SamsungTizenAdapter);
    }
    if (brand == 'LG webOS') {
      return adapters.firstWhere((a) => a is LgWebOsAdapter);
    }
    if (brand == 'Roku') {
      return adapters.firstWhere((a) => a is RokuAdapter);
    }
    if (brand == 'Amazon Fire TV') {
      return adapters.firstWhere((a) => a is AmazonFireTvAdapter);
    }
    if (brand == 'Apple TV') {
      return adapters.firstWhere((a) => a is AppleTvAdapter);
    }
    return adapters.firstWhere((a) => a is AndroidTvAdapter);
  }

  TvRemoteAdapter? get activeAdapter {
    if (_currentDevice == null) return null;
    return _getAdapterForDevice(_currentDevice);
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    if (!_isWifiConnected && !_bypassAuthentication && !_bypassToPairing) {
      addLocalLog('WARN', 'MANAGER', 'Cannot start scan: Wi-Fi is disconnected.');
      return;
    }
    _isScanning = true;
    _discoveredDevices = [];
    _wasDiscoverySuccessful = false;
    notifyListeners();

    FirebaseAnalyticsService.logEvent(eventName: 'ATV_SCAN_STARTED');
    addLocalLog('INFO', 'MANAGER', 'Starting network service discovery for all brands...');
    final Map<String, List<TvDevice>> brandDevices = {};

    final scanFutures = adapters.map((adapter) async {
      try {
        if (adapter is! AndroidTvAdapter) {
          await Future.delayed(const Duration(seconds: 1));
        }
        if (!_isScanning) return;

        await adapter.startDiscovery((devices) {
          if (devices.isNotEmpty) {
            final brand = devices.first.brand;
            final isNewBrand = !brandDevices.containsKey(brand);
            brandDevices[brand] = devices;

            if (isNewBrand) {
              FirebaseAnalyticsService.logEvent(eventName: 'ATV_DEVICE_FOUND_${brand.toUpperCase().replaceAll(' ', '_')}');
            }

            // Merge devices from all brands
            final allDevices = <TvDevice>[];
            brandDevices.forEach((_, list) {
              allDevices.addAll(list);
            });
            _discoveredDevices = allDevices;
            if (allDevices.isNotEmpty) {
              _wasDiscoverySuccessful = true;
            }
            notifyListeners();
          }
        });
      } catch (e) {
        addLocalLog('ERROR', 'MANAGER', 'Discovery initialization failed for adapter: $e');
      }
    }).toList();

    // Await all discovery scans starting in parallel
    await Future.wait(scanFutures);
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    for (final adapter in adapters) {
      await adapter.stopDiscovery();
    }
    addLocalLog('INFO', 'MANAGER', 'Network discovery stopped.');
    notifyListeners();
  }

  Future<void> connectToDevice(TvDevice device) async {
    if (!_isWifiConnected && !_bypassAuthentication && !_bypassToPairing) {
      addLocalLog('WARN', 'MANAGER', 'Cannot connect: Wi-Fi is disconnected.');
      _connectionState = TvConnectionState.failed;
      notifyListeners();
      return;
    }
    _currentDevice = device;
    if (_bypassAuthentication) {
      _connectionState = TvConnectionState.connected;
      addLocalLog('INFO', 'MANAGER', 'Connecting to TV: ${device.name} (Bypassing authentication for UI testing)...');
      notifyListeners();
      return;
    }

    if (_bypassToPairing) {
      _connectionState = TvConnectionState.pairing;
      _pairingPin = '123456';
      addLocalLog('INFO', 'MANAGER', 'Connecting to TV: ${device.name} (Bypassing to pairing screen)...');
      notifyListeners();
      return;
    }

    _sessionStartTime = DateTime.now();
    _wasTlsSuccessful = false;
    _wasPairingStarted = false;
    _wasPinDisplayed = false;
    _wasSecretAckReceived = false;
    _wasControlConnectionEstablished = false;

    _loadingMessage = "Connecting to TV...";
    _connectionState = TvConnectionState.connecting;
    notifyListeners();

    FirebaseAnalyticsService.logEvent(eventName: 'ATV_DEVICE_TAPPED');
    FirebaseAnalyticsService.logEvent(eventName: 'ATV_TLS_CONNECTING');
    final activeAdapter = _getAdapterForDevice(device);
    addLocalLog('INFO', 'CONNECT', 'User selected TV. Name: ${device.name}, IP: ${device.ipAddress}, Port: ${device.port}, Brand: ${device.brand}, Session ID: ${AppLogger.sessionId}');

    try {
      final success = await activeAdapter.connect(device);
      if (success) {
        activeAdapter.onConnectionLost = () {
          addLocalLog('WARN', 'MANAGER', 'Connection lost natively via callback.');
          _connectionState = TvConnectionState.disconnected;
          notifyListeners();
        };

        // ✅ Connection successful - TV already paired
        FirebaseAnalyticsService.logEvent(eventName: 'ATV_TLS_SUCCESS');
        _connectionState = TvConnectionState.connected;
        _wasTlsSuccessful = true;
        _wasControlConnectionEstablished = true;
        addLocalLog('INFO', 'MANAGER', 'Connection established. TV is ready to control.');
        notifyListeners();
        _endSession(null);  // Session ended successfully
      } else {
        // ❌ Connection failed completely
        FirebaseAnalyticsService.logEvent(eventName: 'ATV_TLS_FAILED');
        addLocalLog('ERROR', 'MANAGER', 'Connection failed to TV ${device.name}.');
        _connectionState = TvConnectionState.failed;
        notifyListeners();
        _endSession('Connection handshake failed (success was false)');
      }
    } on PlatformException catch (e) {
      if (e.code == 'NEEDS_PAIRING') {
        // ⚠️ Connection failed but TV needs pairing
        FirebaseAnalyticsService.logEvent(eventName: 'ATV_TLS_NEEDS_PAIRING');
        _connectionState = TvConnectionState.pairing;
        notifyListeners();
        await _startPairingFlow();
      } else {
        // ❌ Connection failed completely
        FirebaseAnalyticsService.logEvent(eventName: 'ATV_TLS_FAILED');
        addLocalLog('ERROR', 'MANAGER', 'Connection failed to TV ${device.name}.');
        _connectionState = TvConnectionState.failed;
        notifyListeners();
        _endSession('Connection handshake failed');
      }
    }
  }

  Future<void> _startPairingFlow() async {
    _loadingMessage = null;
    notifyListeners();
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    FirebaseAnalyticsService.logEvent(eventName: 'ATV_PAIRING_STARTED');
    addLocalLog('INFO', 'MANAGER', 'Starting pairing handshake protocol...');
    _wasPairingStarted = true;
    final success = await activeAdapter.startPairing(
      onPin: (pin) {
        _pairingPin = pin;
        _wasPinDisplayed = true;
        FirebaseAnalyticsService.logEvent(eventName: 'ATV_PIN_DISPLAYED');
        addLocalLog('INFO', 'MANAGER', 'Pairing info displayed: $pin');
        notifyListeners();
      },
      onStatus: (status) {
        _pairingStatusMessage = status;
        addLocalLog('DEBUG', 'MANAGER', 'Pairing state changed natively to: $status');
        if (status == 'SUCCESS' || status == 'CONFIRMED' || status == 'CONNECTED') {
          _wasSecretAckReceived = true;
          _wasControlConnectionEstablished = true;
          _wasTlsSuccessful = true;
          _connectionState = TvConnectionState.connected;
          FirebaseAnalyticsService.logEvent(eventName: 'ATV_PAIRING_SUCCESS');
          FirebaseAnalyticsService.logEvent(eventName: 'ATV_CONTROL_CONNECTED');
          addLocalLog('INFO', 'MANAGER', 'TV Remote pairing successfully completed! Remote is ready.');
          
          activeAdapter.onConnectionLost = () {
            addLocalLog('WARN', 'MANAGER', 'Connection lost natively via callback.');
            _connectionState = TvConnectionState.disconnected;
            notifyListeners();
          };

          notifyListeners();
          _endSession(null);
        } else if (status == 'FAILED') {
          _connectionState = TvConnectionState.failed;
          FirebaseAnalyticsService.logEvent(eventName: 'ATV_PAIRING_FAILED');
          addLocalLog('ERROR', 'MANAGER', 'TV Remote pairing failed.');
          notifyListeners();
          _endSession('Pairing handshake status reported FAILED');
        } else {
          notifyListeners();
        }
      },
    );

    if (!success) {
      FirebaseAnalyticsService.logEvent(eventName: 'ATV_PAIRING_START_FAILED');
      addLocalLog('ERROR', 'MANAGER', 'Failed to start pairing handshake.');
      _connectionState = TvConnectionState.failed;
      notifyListeners();
      _endSession('Failed to start pairing handshake');
    }
  }

  void _endSession(String? failureReason) {
    _loadingMessage = null;
    if (_sessionStartTime == null) return;
    final duration = DateTime.now().difference(_sessionStartTime!).inMilliseconds;
    final finalState = _connectionState.name;

    final summary = {
      'deviceName': _currentDevice?.name ?? 'Unknown',
      'ipAddress': _currentDevice?.ipAddress ?? 'Unknown',
      'controlPort': 6466,
      'pairingPort': 6467,
      'finalState': finalState,
      'wasDiscoverySuccessful': _wasDiscoverySuccessful,
      'wasTlsSuccessful': _wasTlsSuccessful,
      'wasPairingStarted': _wasPairingStarted,
      'wasPinDisplayed': _wasPinDisplayed,
      'wasSecretAckReceived': _wasSecretAckReceived,
      'wasControlConnectionEstablished': _wasControlConnectionEstablished,
      'totalDurationMs': duration,
      'failureReason': failureReason,
    };

    AppLogger.endSession(summary);
    _sessionStartTime = null;
  }

  Future<void> submitPin(String pin) async {
    if (_bypassToPairing) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock submitting PIN: $pin');
      _connectionState = TvConnectionState.connected;
      notifyListeners();
      return;
    }
    if (_connectionState != TvConnectionState.pairing) return;
    _loadingMessage = "Verifying PIN code...";
    notifyListeners();
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    FirebaseAnalyticsService.logEvent(eventName: 'ATV_PIN_SUBMITTED');
    addLocalLog('INFO', 'MANAGER', 'Submitting pairing PIN code: $pin');
    final success = await activeAdapter.sendPin(pin);
    if (!success) {
      FirebaseAnalyticsService.logEvent(eventName: 'ATV_PIN_SUBMIT_FAILED');
      addLocalLog('ERROR', 'MANAGER', 'PIN submission failed.');
      notifyListeners();
    }
  }

  Future<void> sendPress(TvKey key) async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot send keypress $key: Remote is not fully connected.');
      return;
    }
    if (_bypassAuthentication) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock sending key command: ${key.name}');
      return;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Sending key command: ${key.name}');
    final success = await activeAdapter.sendKey(key);
    if (!success) {
      addLocalLog('ERROR', 'MANAGER', 'Failed to send command ${key.name}.');
    }
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot query apps: TV is not connected.');
      return [];
    }
    if (_bypassAuthentication) {
      addLocalLog('DEBUG', 'MANAGER', '[BYPASS] Mock querying installed apps...');
      final brand = _currentDevice?.brand ?? 'Android TV';
      if (brand == 'Samsung Tizen' || brand == 'Samsung TV') {
        return [
          {'id': 'YouTube', 'name': 'YouTube', 'iconUrl': ''},
          {'id': 'Netflix', 'name': 'Netflix', 'iconUrl': ''},
          {'id': 'Prime Video', 'name': 'Prime Video', 'iconUrl': ''},
        ];
      }
      if (brand == 'Amazon Fire TV') {
        return [
          {'id': 'YouTube', 'name': 'YouTube', 'iconUrl': ''},
          {'id': 'Netflix', 'name': 'Netflix', 'iconUrl': ''},
          {'id': 'AmazonVideo', 'name': 'Prime Video', 'iconUrl': ''},
          {'id': 'Spotify', 'name': 'Spotify', 'iconUrl': ''},
        ];
      }
      final countryCode = SharedPrefService.getCountryCode() ?? 'US';
      final catalogApps = CountryAppCatalog().getAppsForCountry(countryCode);
      return catalogApps.map((app) => {
        'id': app.id,
        'name': app.name,
        'iconUrl': app.iconAsset,
      }).toList();
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Querying installed apps...');
    return await activeAdapter.getInstalledApps();
  }

  Future<bool> launchApp(String appId) async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot launch app: TV is not connected.');
      return false;
    }
    if (_bypassAuthentication) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock launching app: $appId');
      return true;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Launching app $appId...');
    return await activeAdapter.launchApp(appId);
  }

  Future<bool> sendText(String text) async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot send text: TV is not connected.');
      return false;
    }
    if (_bypassAuthentication) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock sending text: $text');
      return true;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Sending text: $text...');
    return await activeAdapter.sendText(text);
  }

  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    if (_connectionState != TvConnectionState.connected) {
      addLocalLog('WARN', 'MANAGER', 'Cannot cast media: TV is not connected.');
      return false;
    }
    if (_bypassAuthentication) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock casting media: $url (Type: $type)');
      return true;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Casting media URL: $url (Type: $type)...');
    return await activeAdapter.castMedia(url: url, type: type, name: name, format: format);
  }

  Future<void> stopCasting() async {
    if (_connectionState != TvConnectionState.connected) return;
    if (_bypassAuthentication) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Mock stopping media cast');
      return;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    addLocalLog('DEBUG', 'MANAGER', 'Stopping media cast...');
    await activeAdapter.stopCasting();
  }

  Future<void> disconnect() async {
    if (_bypassAuthentication || _bypassToPairing) {
      addLocalLog('INFO', 'MANAGER', '[BYPASS] Disconnecting mock session...');
      _currentDevice = null;
      _connectionState = TvConnectionState.disconnected;
      _pairingPin = null;
      _pairingStatusMessage = null;
      notifyListeners();
      return;
    }
    final activeAdapter = _getAdapterForDevice(_currentDevice);
    FirebaseAnalyticsService.logEvent(eventName: 'ATV_USER_DISCONNECTED');
    addLocalLog('INFO', 'MANAGER', 'Disconnecting session...');
    _endSession('User disconnected');
    try {
      await activeAdapter.stopCasting();
    } catch (e) {
      addLocalLog('WARN', 'MANAGER', 'Error stopping casting on disconnect: $e');
    }
    await activeAdapter.disconnect();
    activeAdapter.onConnectionLost = null;
    _currentDevice = null;
    _connectionState = TvConnectionState.disconnected;
    _pairingPin = null;
    _pairingStatusMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final adapter in adapters) {
      adapter.disconnect();
    }
    super.dispose();
  }
}
