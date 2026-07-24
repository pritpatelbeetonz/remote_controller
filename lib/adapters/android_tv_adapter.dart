import 'dart:async';
import 'package:flutter/services.dart';
import 'package:android_tv_remote_package/models/tv_device.dart';
import '../core/tv_remote_adapter.dart';

class AndroidTvAdapter implements TvRemoteAdapter {
  static const _eventChannel = EventChannel('com.waysol.android_tv_remote_package/event');

  StreamSubscription? _discoverySubscription;
  String? _pkcs12Path;

  @override
  Stream<Map<String, dynamic>> get logs {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  /// Initialize certificates. Generates if not already generated.
  Future<String> _ensureCertificates() async {
    if (_pkcs12Path != null) return _pkcs12Path!;
    try {
      final certInfo = await AndroidTVRemote.generateCertificates();
      if (certInfo['success'] == true) {
        _pkcs12Path = certInfo['pkcs12Path'] as String?;
        return _pkcs12Path!;
      } else {
        throw Exception("Certificate generation failed natively");
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    await AndroidTVRemote.startDiscovery(
      onDevices: (List<TVDevice> nativeDevices) {
        final devices = nativeDevices.map((d) {
          return TvDevice(
            id: d.ipAddress,
            name: d.name,
            ipAddress: d.ipAddress,
            port: d.port,
            brand: 'Android TV',
          );
        }).toList();
        onDevices(devices);
      },
    );
  }

  @override
  Future<void> stopDiscovery() async {
    // Discovery automatically times out or is stopped via native call
  }

  @override
  Future<bool> connect(TvDevice device) async {
    try {
      final path = await _ensureCertificates();
      final success = await AndroidTVRemote.connect(
        host: device.ipAddress,
        port: device.port,
        pkcs12Path: path,
        password: '', // Empty password used in BouncyCastle generation
      );
      return success;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await AndroidTVRemote.disconnect();
  }

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    return await AndroidTVRemote.startPairing(
      onPin: onPin,
      onStatus: onStatus,
    );
  }

  @override
  Future<bool> sendPin(String pin) async {
    return await AndroidTVRemote.sendPin(pin);
  }

  @override
  Future<bool> sendKey(TvKey key) async {
    String command;
    switch (key) {
      case TvKey.power:
        // volume_mute / power button maps
        command = 'play_pause'; // fallback mapping
        break;
      case TvKey.volumeUp:
        command = 'volume_up';
        break;
      case TvKey.volumeDown:
        command = 'volume_down';
        break;
      case TvKey.mute:
        command = 'play_pause'; // package uses play_pause as muting fallback, or we can handle
        break;
      case TvKey.up:
        command = 'dpad_up';
        break;
      case TvKey.down:
        command = 'dpad_down';
        break;
      case TvKey.left:
        command = 'dpad_left';
        break;
      case TvKey.right:
        command = 'dpad_right';
        break;
      case TvKey.select:
        command = 'dpad_center';
        break;
      case TvKey.back:
        command = 'back';
        break;
      case TvKey.home:
        command = 'home';
        break;
      case TvKey.playPause:
        command = 'play_pause';
        break;
    }
    return await AndroidTVRemote.sendCommand(command);
  }
}
