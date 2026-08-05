import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:android_tv_remote_package/models/tv_device.dart';
import '../core/tv_remote_adapter.dart';
import '../core/country_manager.dart';
import '../for_ads/utils/shared_prefrence_service.dart';
import '../services/country_app_catalog.dart';

class AndroidTvAdapter implements TvRemoteAdapter {
  static const _eventChannel = EventChannel('com.waysol.android_tv_remote_package/event');

  StreamSubscription? _discoverySubscription;
  String? _pkcs12Path;
  TvDevice? _currentDevice;
  HttpServer? _localServer;

  @override
  void Function()? onConnectionLost;
  final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();
  bool _nativeLogsSubscribed = false;

  void _addLog(String level, String message) {
    final emoji = level == 'ERROR' ? '❌' : (level == 'WARN' ? '⚠️' : (level == 'DEBUG' ? '🐛' : 'ℹ️'));
    print('$emoji [AndroidTVAdapter] [$level] $message');
    _logController.add({
      'level': level,
      'tag': 'ANDROID_TV',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs {
    if (!_nativeLogsSubscribed) {
      _nativeLogsSubscribed = true;
      _eventChannel.receiveBroadcastStream().listen((event) {
        final logMap = Map<String, dynamic>.from(event as Map);
        final level = logMap['level'] as String? ?? 'DEBUG';
        final tag = logMap['tag'] as String? ?? 'NATIVE';
        final message = logMap['message'] as String? ?? '';
        final emoji = level == 'ERROR' ? '❌' : (level == 'WARN' ? '⚠️' : (level == 'DEBUG' ? '🐛' : 'ℹ️'));
        print('$emoji [AndroidTVNative] [$tag] [$level] $message');
        _logController.add(logMap);
      }, onError: (e) {
        final errorMsg = 'Error from native logs: $e';
        print('❌ [AndroidTVNative] [ERROR] $errorMsg');
        _logController.add({
          'level': 'ERROR',
          'tag': 'ANDROID_TV_NATIVE',
          'message': errorMsg,
          'timestamp': DateTime.now(),
        });
      });
    }
    return _logController.stream;
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
    _addLog('INFO', '🔍 [startDiscovery] Starting Android TV network service scan...');
    await AndroidTVRemote.startDiscovery(
      onDevices: (List<TVDevice> nativeDevices) {
        _addLog('INFO', '📺 [startDiscovery] Discovery returned ${nativeDevices.length} raw devices.');
        final devices = nativeDevices.map((d) {
          _addLog('INFO', '📱 [startDiscovery] Discovered device: ${d.name} (${d.ipAddress}:${d.port})');
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
    _addLog('INFO', '⏹️ [stopDiscovery] Stopping network scan request.');
    try {
      await const MethodChannel('com.waysol.android_tv_remote_package/method').invokeMethod('stopDiscovery');
    } catch (e) {
      _addLog('ERROR', 'Failed to stop discovery natively: $e');
    }
  }

  @override
  Future<bool> connect(TvDevice device) async {
    _addLog('INFO', '🔌 [connect] Attempting pairing/connection to TV: ${device.name} at ${device.ipAddress}:${device.port}...');
    _currentDevice = device;
    try {
      final path = await _ensureCertificates();
      _addLog('INFO', '🔑 [connect] Certificate verified at: $path');

      AndroidTVRemote.channel.setMethodCallHandler((call) async {
        if (call.method == 'connectionLost') {
          _addLog('WARN', '⚠️ Connection lost natively.');
          onConnectionLost?.call();
        }
      });

      final success = await AndroidTVRemote.connect(
        host: device.ipAddress,
        port: device.port,
        pkcs12Path: path,
        password: '', // Empty password used in BouncyCastle generation
      );
      if (!success) {
        _addLog('ERROR', '❌ [connect] Connection failed to TV: ${device.name}');
        _currentDevice = null;
      } else {
        _addLog('INFO', '✅ [connect] Connection successful to TV: ${device.name}!');
      }
      return success;
    } on PlatformException catch (e) {
      if (e.code == 'NEEDS_PAIRING') {
        _addLog('WARN', '⚠️ [connect] TV requires pairing.');
        _currentDevice = null;
        rethrow;
      }
      _addLog('ERROR', '❌ [connect] Connection failed to TV: ${device.name}');
      _currentDevice = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _addLog('INFO', '🔌 [disconnect] Closing session for device: ${_currentDevice?.name ?? "Unknown"}');
    await stopCasting();
    AndroidTVRemote.channel.setMethodCallHandler(null);
    onConnectionLost = null;
    await AndroidTVRemote.disconnect();
    _currentDevice = null;
  }

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    _addLog('INFO', '🔄 [startPairing] Requesting TLS/Protobuf pairing protocol handshake...');
    return await AndroidTVRemote.startPairing(
      onPin: (pin) {
        _addLog('INFO', '🔢 [startPairing] PIN displayed on screen: $pin');
        onPin(pin);
      },
      onStatus: (status) {
        _addLog('INFO', '📊 [startPairing] Pairing progress state changed: $status');
        onStatus(status);
      },
    );
  }

  @override
  Future<bool> sendPin(String pin) async {
    _addLog('INFO', '📤 [sendPin] Submitting PIN verification code: $pin');
    final success = await AndroidTVRemote.sendPin(pin);
    if (success) {
      _addLog('INFO', '✅ [sendPin] PIN verification request successfully accepted.');
    } else {
      _addLog('ERROR', '❌ [sendPin] PIN verification request failed.');
    }
    return success;
  }

  @override
  Future<bool> sendKey(TvKey key) async {
    String command;
    switch (key) {
      case TvKey.power:
        // volume_mute / power button maps
        command = 'power';
        break;
      case TvKey.volumeUp:
        command = 'volume_up';
        break;
      case TvKey.volumeDown:
        command = 'volume_down';
        break;
      case TvKey.mute:
        command = 'volume_mute';
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
      case TvKey.rewind:
        command = 'rewind';
        break;
      case TvKey.fastForward:
        command = 'fast_forward';
        break;
      case TvKey.options:
        command = 'media_next';
        break;
      case TvKey.info:
        command = 'media_previous';
        break;
      case TvKey.inputSource:
        command = 'source';
        break;
    }
    _addLog('INFO', '🕹️ [sendKey] Sending key command: ${key.name} -> command parameter: $command');
    bool success = false;
    try {
      success = await AndroidTVRemote.sendCommand(command);
      if (success) {
        _addLog('INFO', '✅ [sendKey] Key command parameter $command successfully sent.');
      } else {
        _addLog('ERROR', '❌ [sendKey] Key command parameter $command failed to send.');
      }
    } catch (e) {
      _addLog('ERROR', '💥 [sendKey] Exception during sendCommand for $command: $e');
    }
    return success;
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    _addLog('INFO', '📱 Querying installed apps for Android TV (IP: ${_currentDevice?.ipAddress ?? "Unknown"})...');
    _addLog('WARN', '⚠️ The Android TV Remote Control Protocol v2 does not support package/app enumeration over the TLS socket connection.');

    final countryCode = SharedPrefService.getCountryCode() ?? await CountryManager().getDeviceCountryCode();
    _addLog('INFO', '🌍 Detected Country Code for Catalog: $countryCode');

    final catalogApps = CountryAppCatalog().getAppsForCountry(countryCode);
    _addLog('INFO', '📝 Returning predefined compatible TV app packages for $countryCode:');

    final List<Map<String, String>> apps = catalogApps.map((app) => {
      'id': app.id,
      'name': app.name,
      'iconUrl': app.iconAsset,
    }).toList();

    for (final app in apps) {
      _addLog('INFO', '  - App: ${app['name']} (Package ID: ${app['id']})');
    }

    return apps;
  }

  @override
  Future<bool> launchApp(String appId) async {
    try {
      final appLink = 'market://launch?id=$appId';
      _addLog('INFO', '🚀 [launchApp] Launching Android TV app link: $appLink (App ID: $appId)');
      final res = await AndroidTVRemote.channel.invokeMethod('launchApp', appLink);
      final success = (res as Map?)?['success'] == true;
      if (success) {
        _addLog('INFO', '✅ [launchApp] App $appId launched successfully.');
      } else {
        _addLog('ERROR', '❌ [launchApp] Failed to launch app: $appId.');
      }
      return success;
    } catch (e) {
      _addLog('ERROR', '💥 [launchApp] Exception during app launch for $appId: $e');
      return false;
    }
  }

  @override
  Future<bool> sendText(String text) async {
    try {
      _addLog('INFO', '⌨️ [sendText] Typing text string natively: "$text"');
      final res = await AndroidTVRemote.channel.invokeMethod('sendText', text);
      final success = (res as Map?)?['success'] == true;
      if (success) {
        _addLog('INFO', '✅ [sendText] Text successfully typed.');
      } else {
        _addLog('ERROR', '❌ [sendText] Failed to send text.');
      }
      return success;
    } catch (e) {
      _addLog('ERROR', '💥 [sendText] Exception during sendText: $e');
      return false;
    }
  }

  @override
  Future<bool> isKeyboardSupported() async {
    try {
      final res = await AndroidTVRemote.channel.invokeMethod('isKeyboardSupported');
      return (res as Map?)?['supported'] == true;
    } catch (e) {
      _addLog('ERROR', '💥 [isKeyboardSupported] Exception: $e');
      return false;
    }
  }

  @override
  Future<bool> isTextFieldFocused() async {
    try {
      final res = await AndroidTVRemote.channel.invokeMethod('isTextFieldFocused');
      return (res as Map?)?['focused'] == true;
    } catch (e) {
      _addLog('ERROR', '💥 [isTextFieldFocused] Exception: $e');
      return false;
    }
  }

  @override
  Future<String> getKeyboardState() async {
    try {
      final res = await AndroidTVRemote.channel.invokeMethod('getKeyboardState');
      return (res as Map?)?['state'] as String? ?? 'UNKNOWN';
    } catch (e) {
      _addLog('ERROR', '💥 [getKeyboardState] Exception: $e');
      return 'UNKNOWN';
    }
  }

  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.address.startsWith('192.168.') ||
              address.address.startsWith('10.') ||
              address.address.startsWith('172.')) {
            return address.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to resolve local IP address: $e');
    }
    return null;
  }

  Future<String?> _parseControlUrlFromXml(String descriptionUrl) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse(descriptionUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final serviceBlocks = body.split('<service>');
      for (final block in serviceBlocks) {
        if (block.contains('urn:schemas-upnp-org:service:AVTransport:1')) {
          final controlUrlStart = block.indexOf('<controlURL>');
          final controlUrlEnd = block.indexOf('</controlURL>');
          if (controlUrlStart != -1 && controlUrlEnd != -1) {
            String path = block.substring(controlUrlStart + 12, controlUrlEnd).trim();
            final descUri = Uri.parse(descriptionUrl);
            if (path.startsWith('http://') || path.startsWith('https://')) {
              return path;
            } else {
              if (!path.startsWith('/')) {
                path = '/$path';
              }
              return '${descUri.scheme}://${descUri.host}:${descUri.port}$path';
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to parse DLNA description XML: $e');
    }
    return null;
  }

  Future<String?> _findAVTransportUrl(String tvIp) async {
    RawDatagramSocket? socket;
    _addLog('INFO', 'Searching for DLNA AVTransport service on Android TV at $tvIp...');
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastLoopback = false;

      final searchMsg = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:schemas-upnp-org:service:AVTransport:1\r\n\r\n';

      socket.send(
        utf8.encode(searchMsg),
        InternetAddress('239.255.255.250'),
        1900,
      );

      final stream = socket.timeout(
        const Duration(seconds: 4),
        onTimeout: (sink) => sink.close(),
      );

      await for (final event in stream) {
        if (event != RawSocketEvent.read) continue;
        final datagram = socket.receive();
        if (datagram == null) continue;

        if (datagram.address.address == tvIp) {
          final response = utf8.decode(datagram.data, allowMalformed: true);
          String? location;
          for (final line in response.split('\r\n')) {
            if (line.toLowerCase().startsWith('location:')) {
              location = line.substring(9).trim();
              break;
            }
          }
          if (location != null) {
            _addLog('DEBUG', 'Discovered DLNA description URL: $location');
            final controlUrl = await _parseControlUrlFromXml(location);
            if (controlUrl != null) {
              _addLog('INFO', 'Resolved AVTransport control URL: $controlUrl');
              return controlUrl;
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'Error during DLNA SSDP discovery: $e');
    } finally {
      socket?.close();
    }
    return null;
  }

  Future<bool> _sendSoapAction(String controlUrl, String action, String arguments) async {
    try {
      final uri = Uri.parse(controlUrl);

      // ✅ Only connectionTimeout is available
      final timeout = action == 'SetAVTransportURI'
          ? const Duration(seconds: 30)
          : const Duration(seconds: 10);

      final client = HttpClient()..connectionTimeout = timeout;

      final request = await client.postUrl(uri);

      final soapBody = '<?xml version="1.0" encoding="utf-8"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>'
          '<u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
          '<InstanceID>0</InstanceID>'
          '$arguments'
          '</u:$action>'
          '</s:Body>'
          '</s:Envelope>';

      request.headers.add('Content-Type', 'text/xml; charset="utf-8"');
      request.headers.add('SOAPAction', '"urn:schemas-upnp-org:service:AVTransport:1#$action"');
      request.headers.add('Connection', 'close');
      request.contentLength = utf8.encode(soapBody).length;
      request.write(soapBody);

      final response = await request.close().timeout(timeout);  // ← Add timeout here
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      _addLog('ERROR', 'SOAP $action action failed: $e');
      return false;
    }
  }
  String? _cachedControlUrl;

  @override
  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    _addLog('INFO', '🎬 [castMedia] Initializing media cast session -> Name: "$name", Type: "$type", URL: "$url"');
    if (_currentDevice == null) {
      _addLog('ERROR', '❌ [castMedia] Cannot cast media: Android TV is not connected.');
      return false;
    }

    String finalUrl = url;
    final isLocalFile = !url.startsWith('http://') && !url.startsWith('https://');

    if (isLocalFile) {
      await stopCasting(); // Stop any existing server

      final ip = await _getLocalIpAddress();
      if (ip == null) {
        _addLog('ERROR', 'Cannot start local server: Local IP resolution failed.');
        return false;
      }

      try {
        _localServer = await HttpServer.bind(ip, 0);
        _addLog('INFO', 'Started local media server on http://$ip:${_localServer!.port}/');

        _localServer!.listen((HttpRequest request) async {
          _addLog('DEBUG', 'Local media server received request: ${request.uri.path}');
          final file = File(url);
          if (await file.exists()) {
            final fileLength = await file.length();

            request.response.headers.add('Access-Control-Allow-Origin', '*');
            request.response.headers.add('Accept-Ranges', 'bytes');

            final fileExt = url.split('.').last.toLowerCase();
            String mimeType = 'video/mp4';
            if (type == 'p') {
              mimeType = fileExt == 'png' ? 'image/png' : 'image/jpeg';
            } else if (type == 'm') {
              mimeType = 'audio/mpeg';
            }
            request.response.headers.contentType = ContentType.parse(mimeType);
            request.response.contentLength = fileLength;

            await file.openRead().pipe(request.response);
            _addLog('DEBUG', 'Successfully served local media file.');
          } else {
            _addLog('ERROR', 'Local file not found at: $url');
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        }, onError: (e) {
          _addLog('ERROR', 'Error in local media server stream: $e');
        });

        finalUrl = 'http://$ip:${_localServer!.port}/media';
      } catch (e) {
        _addLog('ERROR', 'Failed to bind local HTTP server: $e');
        return false;
      }
    }

    String? controlUrl = _cachedControlUrl;
    if (controlUrl == null) {
      controlUrl = await _findAVTransportUrl(_currentDevice!.ipAddress);
      if (controlUrl == null) {
        controlUrl = 'http://${_currentDevice!.ipAddress}:8008/apps/YouTube';
      }
      _cachedControlUrl = controlUrl;
    }

    _addLog('INFO', 'Casting media to DLNA renderer: $finalUrl');

    final setUriSuccess = await _sendSoapAction(
      controlUrl,
      'SetAVTransportURI',
      '<CurrentURI>$finalUrl</CurrentURI><CurrentURIMetaData></CurrentURIMetaData>'
    );

    if (!setUriSuccess) {
      _addLog('ERROR', 'DLNA SetAVTransportURI failed.');
      _cachedControlUrl = null;
      return false;
    }

    final playSuccess = await _sendSoapAction(controlUrl, 'Play', '<Speed>1</Speed>');
    if (playSuccess) {
      _addLog('INFO', 'Media playback started via DLNA.');
      return true;
    } else {
      _addLog('ERROR', 'DLNA Play failed.');
      return false;
    }
  }

  @override
  Future<void> stopCasting() async {
    _addLog('INFO', 'Stopping media cast on Android TV...');
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      _addLog('INFO', 'Local media server shut down.');
    }
    String? controlUrl = _cachedControlUrl;
    if (controlUrl != null) {
      await _sendSoapAction(controlUrl, 'Stop', '');
      _addLog('INFO', 'DLNA Stop command sent.');
    }
  }
}
