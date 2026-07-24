import 'dart:async';

/// Supported physical key commands for remote control.
enum TvKey {
  power,
  volumeUp,
  volumeDown,
  mute,
  up,
  down,
  left,
  right,
  select,
  back,
  home,
  playPause,
}

/// Represents a generic TV device discovered on the network.
class TvDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String brand; // e.g. "Android TV", "Roku", "Samsung", "LG"

  TvDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.brand,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ipAddress,
    'port': port,
    'brand': brand,
  };

  factory TvDevice.fromJson(Map<String, dynamic> json) => TvDevice(
    id: json['id'] as String? ?? json['ip'] as String,
    name: json['name'] as String,
    ipAddress: json['ip'] as String,
    port: json['port'] as int,
    brand: json['brand'] as String? ?? 'Android TV',
  );
}

/// Common interface for all TV Remote brand adapters.
abstract class TvRemoteAdapter {
  /// Start discovery process for the specific brand.
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices);

  /// Stop discovery process.
  Future<void> stopDiscovery();

  /// Connect to a specific device.
  Future<bool> connect(TvDevice device);

  /// Disconnect the current session.
  Future<void> disconnect();

  /// Start the pairing flow (mutual SSL certificate challenge/PIN).
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  });

  /// Submit PIN entered by the user.
  Future<bool> sendPin(String pin);

  /// Send a button key press command.
  Future<bool> sendKey(TvKey key);

  /// Stream of log messages from the underlying adapter/native layer.
  Stream<Map<String, dynamic>> get logs;
}
