import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/tv_remote_adapter.dart';

class RokuAdapter implements TvRemoteAdapter {
  HttpClient? _httpClient;
  bool _isConnected = false;
  TvDevice? _currentDevice;

  final HttpClient Function()? _clientFactory;

  RokuAdapter([this._clientFactory]);

  @override
  void Function()? onConnectionLost;

  final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();

  void _addLog(String level, String message) {
    _logController.add({
      'level': level,
      'tag': 'ROKU',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs => _logController.stream;

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    _addLog('INFO', 'Starting Roku SSDP network scan...');
    _scanSSDP(onDevices);
  }

  Future<void> _scanSSDP(Function(List<TvDevice>) onDevices) async {
    final List<TvDevice> discovered = [];
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastLoopback = false;

      final searchMsg =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: roku:ecp\r\n\r\n';

      final data = utf8.encode(searchMsg);
      socket.send(data, InternetAddress('239.255.255.250'), 1900);
      _addLog('DEBUG', 'SSDP M-SEARCH discovery packet broadcasted.');

      final stream = socket.timeout(const Duration(seconds: 5), onTimeout: (sink) => sink.close());
      await for (final event in stream) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            _addLog('DEBUG', 'Received SSDP response:\n$response');
            final lines = response.split('\r\n');
            String? location;
            for (final line in lines) {
              if (line.toLowerCase().startsWith('location:')) {
                location = line.substring(9).trim();
                break;
              }
            }
            if (location != null) {
              final uri = Uri.parse(location);
              final ip = uri.host;
              
              if (!discovered.any((d) => d.ipAddress == ip)) {
                _addLog('INFO', 'Discovered Roku TV at IP: $ip');
                final device = TvDevice(
                  id: 'roku-$ip',
                  name: 'Roku TV ($ip)',
                  ipAddress: ip,
                  port: 8060, // Roku ECP Port
                  brand: 'Roku',
                );
                discovered.add(device);
                onDevices(List.from(discovered));
              }
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'SSDP Discovery error: $e');
    } finally {
      socket?.close();
      _addLog('INFO', 'Roku network scan finished.');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _addLog('INFO', 'Roku discovery stopped.');
  }

  @override
  Future<bool> connect(TvDevice device) async {
    _currentDevice = device;
    _isConnected = false;
    _addLog('INFO', 'Connecting to Roku TV at ${device.ipAddress}:${device.port}...');

    try {
      _httpClient = _clientFactory != null ? _clientFactory!() : HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 4);

      // Verify reachability via device-info query
      final request = await _httpClient!.getUrl(
        Uri.parse('http://${device.ipAddress}:${device.port}/query/device-info'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        _addLog('INFO', 'Successfully validated Roku connection.');
        _isConnected = true;
        return true;
      } else {
        _addLog('ERROR', 'Failed to reach Roku TV. Status code: ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to connect to Roku TV: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _addLog('INFO', 'Disconnecting Roku remote session...');
    _httpClient?.close(force: true);
    _httpClient = null;
    _isConnected = false;
  }

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    // Roku ECP does not require pairing, just report status success.
    _addLog('INFO', 'Pairing not required for Roku. Connecting directly.');
    onPin('NO PIN REQUIRED');
    onStatus('CONNECTED');
    return true;
  }

  @override
  Future<bool> sendPin(String pin) async {
    return true;
  }

  @override
  Future<bool> sendKey(TvKey key) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot send keypress: Roku session is not connected.');
      return false;
    }

    final keyString = _mapKeyToRoku(key);
    if (keyString == null) {
      _addLog('WARN', 'Key $key not supported on Roku.');
      return false;
    }

    final urlStr = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/keypress/$keyString';
    _addLog('DEBUG', 'Sending Roku key press event POST to: $urlStr');

    try {
      final request = await _httpClient!.postUrl(Uri.parse(urlStr));
      final response = await request.close();
      if (response.statusCode == 200) {
        return true;
      } else {
        _addLog('ERROR', 'Roku ECP returned status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Error sending keypress to Roku ECP: $e');
      return false;
    }
  }

  String? _mapKeyToRoku(TvKey key) {
    switch (key) {
      case TvKey.power:
        return 'Power';
      case TvKey.volumeUp:
        return 'VolumeUp';
      case TvKey.volumeDown:
        return 'VolumeDown';
      case TvKey.mute:
        return 'VolumeMute';
      case TvKey.up:
        return 'Up';
      case TvKey.down:
        return 'Down';
      case TvKey.left:
        return 'Left';
      case TvKey.right:
        return 'Right';
      case TvKey.select:
        return 'Select';
      case TvKey.back:
        return 'Back';
      case TvKey.home:
        return 'Home';
      case TvKey.playPause:
        return 'Play';
      case TvKey.rewind:
        return 'Rev';
      case TvKey.fastForward:
        return 'Fwd';
      case TvKey.options:
      case TvKey.info:
        return 'Info';
      case TvKey.inputSource:
        return 'InputTuner';
    }
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot query apps: Roku is not connected.');
      return [];
    }

    final urlStr = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/query/apps';
    _addLog('DEBUG', 'Querying installed apps GET: $urlStr');

    try {
      final request = await _httpClient!.getUrl(Uri.parse(urlStr));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();

        final List<Map<String, String>> apps = [];
        final regex = RegExp(r'<app id="([^"]+)"[^>]*>([^<]+)</app>');
        final matches = regex.allMatches(body);

        for (final match in matches) {
          final id = match.group(1);
          final name = match.group(2);
          if (id != null && name != null) {
            apps.add({
              'id': id,
              'name': name,
              'iconUrl': 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/query/icon/$id',
            });
          }
        }

        _addLog('INFO', 'Retrieved ${apps.length} apps/channels from Roku.');
        return apps;
      } else {
        _addLog('ERROR', 'Failed to query Roku apps. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _addLog('ERROR', 'Error querying apps from Roku: $e');
      return [];
    }
  }

  @override
  Future<bool> launchApp(String appId) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot launch app: Roku is not connected.');
      return false;
    }

    final urlStr = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/launch/$appId';
    _addLog('INFO', 'Launching Roku application ID: $appId');

    try {
      final request = await _httpClient!.postUrl(Uri.parse(urlStr));
      final response = await request.close();
      if (response.statusCode == 200) {
        return true;
      } else {
        _addLog('ERROR', 'Roku ECP returned status code for launch: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Error launching app on Roku: $e');
      return false;
    }
  }

  @override
  Future<bool> sendText(String text) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot send text: Roku is not connected.');
      return false;
    }

    _addLog('INFO', 'Sending text string: "$text" to Roku TV.');
    try {
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        final encodedChar = Uri.encodeComponent(char);
        final urlStr = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/keypress/Lit_$encodedChar';

        final request = await _httpClient!.postUrl(Uri.parse(urlStr));
        final response = await request.close();
        if (response.statusCode != 200) {
          _addLog('WARN', 'Failed to send character: $char. Status: ${response.statusCode}');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return true;
    } catch (e) {
      _addLog('ERROR', 'Error sending text to Roku: $e');
      return false;
    }
  }

  HttpServer? _localServer;

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

  @override
  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot cast media: Roku is not connected.');
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

    final encodedUrl = Uri.encodeComponent(finalUrl);
    final mediaType = type;
    final defaultFormat = type == 'p' ? 'jpg' : (type == 'm' ? 'mp3' : 'mp4');
    final mediaFormat = format ??
        (url.contains('.') ? url.split('.').last.split('?').first.toLowerCase() : defaultFormat);
    final displayName = name ?? (isLocalFile ? url.split('/').last : 'Web Media');
    final encodedName = Uri.encodeComponent(displayName);

    final castUrl = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/input/15985'
        '?t=$mediaType'
        '&u=$encodedUrl'
        '&videoFormat=$mediaFormat'
        '&videoName=$encodedName';

    _addLog('INFO', 'Initiating cast request. URL: $finalUrl (Type: $type)');
    _addLog('DEBUG', 'Sending ECP cast request POST: $castUrl');

    try {
      final request = await _httpClient!.postUrl(Uri.parse(castUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        _addLog('INFO', 'Casting request accepted by Roku TV.');
        return true;
      } else {
        _addLog('ERROR', 'Roku ECP cast returned status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to send cast command: $e');
      return false;
    }
  }

  @override
  Future<void> stopCasting() async {
    _addLog('INFO', 'Stopping casting session.');
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      _addLog('INFO', 'Local media server shut down.');
    }
    await sendKey(TvKey.home);
  }
}
