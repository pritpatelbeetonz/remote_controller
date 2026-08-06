import 'dart:async';
import 'package:flutter/services.dart';

enum CastSessionState {
  IDLE,
  DISCOVERING,
  CONNECTING,
  CONNECTED,
  CASTING,
  BUFFERING,
  PAUSED,
  ERROR
}

class CastDevice {
  final String id;
  final String name;
  final String modelName;

  CastDevice({
    required this.id,
    required this.name,
    required this.modelName,
  });

  factory CastDevice.fromMap(Map<dynamic, dynamic> map) {
    return CastDevice(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      modelName: map['modelName']?.toString() ?? '',
    );
  }
}

class GoogleCastManager {
  static const MethodChannel _channel =
      MethodChannel('com.waysol.android_tv_remote_package/cast');

  static final GoogleCastManager _instance = GoogleCastManager._internal();

  factory GoogleCastManager() => _instance;

  GoogleCastManager._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Observers
  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final StreamController<CastSessionState> _stateController =
      StreamController<CastSessionState>.broadcast();

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  Stream<CastSessionState> get stateStream => _stateController.stream;

  List<CastDevice> _discoveredDevices = [];
  List<CastDevice> get discoveredDevices => _discoveredDevices;

  CastSessionState _currentState = CastSessionState.IDLE;
  CastSessionState get currentState => _currentState;

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDevicesUpdated':
        final list = call.arguments as List?;
        if (list != null) {
          _discoveredDevices = list
              .map((e) => CastDevice.fromMap(e as Map))
              .toList();
          print("📡 [GoogleCastManager] Discovered devices updated: ${_discoveredDevices.length} devices found.");
          for (var d in _discoveredDevices) {
            print("   ↳ Device: ${d.name} (${d.modelName}) [ID: ${d.id}]");
          }
          _devicesController.add(_discoveredDevices);
        }
        break;
      case 'onStateChanged':
        final stateStr = call.arguments as String?;
        if (stateStr != null) {
          _currentState = _parseState(stateStr);
          print("🔄 [GoogleCastManager] Session state changed -> $_currentState");
          _stateController.add(_currentState);
        }
        break;
    }
  }

  CastSessionState _parseState(String stateStr) {
    switch (stateStr) {
      case 'CONNECTING':
        return CastSessionState.CONNECTING;
      case 'CONNECTED':
        return CastSessionState.CONNECTED;
      case 'CASTING':
        return CastSessionState.CASTING;
      case 'BUFFERING':
        return CastSessionState.BUFFERING;
      case 'PAUSED':
        return CastSessionState.PAUSED;
      case 'ERROR':
        return CastSessionState.ERROR;
      case 'DISCONNECTED':
      case 'IDLE':
      default:
        return CastSessionState.IDLE;
    }
  }

  Future<bool> startDiscovery() async {
    try {
      print("🔍 [GoogleCastManager] startDiscovery() invoked");
      _currentState = CastSessionState.DISCOVERING;
      _stateController.add(_currentState);
      final res = await _channel.invokeMethod('discoverDevices');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] startDiscovery() error: $e");
      return false;
    }
  }

  Future<bool> stopDiscovery() async {
    try {
      print("🛑 [GoogleCastManager] stopDiscovery() invoked");
      if (_currentState == CastSessionState.DISCOVERING) {
        _currentState = CastSessionState.IDLE;
        _stateController.add(_currentState);
      }
      final res = await _channel.invokeMethod('stopDiscovery');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] stopDiscovery() error: $e");
      return false;
    }
  }

  Future<bool> connect(String deviceId) async {
    try {
      print("🔗 [GoogleCastManager] connect() requested for Device ID: $deviceId");
      final res = await _channel.invokeMethod('connect', deviceId);
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] connect() error: $e");
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      print("🔌 [GoogleCastManager] disconnect() requested");
      final res = await _channel.invokeMethod('disconnect');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] disconnect() error: $e");
      return false;
    }
  }

  Future<bool> castMedia({
    required String url,
    String? mimeType,
    String? title,
    String? subtitle,
    String? artworkUrl,
    int? durationMs,
  }) async {
    try {
      print("📺 [GoogleCastManager] castMedia() requested: URL=$url, MIME=$mimeType, TITLE=$title");
      final res = await _channel.invokeMethod('castMedia', {
        'url': url,
        'mimeType': mimeType,
        'title': title,
        'subtitle': subtitle,
        'artworkUrl': artworkUrl,
        'duration': durationMs,
      });
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] castMedia() error: $e");
      rethrow;
    }
  }

  Future<bool> play() async {
    try {
      print("▶️ [GoogleCastManager] play() requested");
      final res = await _channel.invokeMethod('play');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] play() error: $e");
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      print("⏸️ [GoogleCastManager] pause() requested");
      final res = await _channel.invokeMethod('pause');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] pause() error: $e");
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      print("⏹️ [GoogleCastManager] stop() requested");
      final res = await _channel.invokeMethod('stop');
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] stop() error: $e");
      return false;
    }
  }

  Future<bool> seek(int positionMs) async {
    try {
      print("⏩ [GoogleCastManager] seek() requested to $positionMs ms");
      final res = await _channel.invokeMethod('seek', positionMs);
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] seek() error: $e");
      return false;
    }
  }

  Future<bool> setVolume(double value) async {
    try {
      print("🔊 [GoogleCastManager] setVolume() requested to $value");
      final res = await _channel.invokeMethod('setVolume', value);
      return (res as Map?)?['success'] == true;
    } catch (e) {
      print("❌ [GoogleCastManager] setVolume() error: $e");
      return false;
    }
  }

  Future<CastSessionState> getSessionState() async {
    try {
      final res = await _channel.invokeMethod('getSessionState');
      final stateStr = (res as Map?)?['state'] as String?;
      if (stateStr != null) {
        _currentState = _parseState(stateStr);
        print("ℹ️ [GoogleCastManager] getSessionState() returned state: $_currentState");
      }
      return _currentState;
    } catch (e) {
      print("❌ [GoogleCastManager] getSessionState() error: $e");
      return CastSessionState.IDLE;
    }
  }

  void dispose() {
    _devicesController.close();
    _stateController.close();
  }
}
