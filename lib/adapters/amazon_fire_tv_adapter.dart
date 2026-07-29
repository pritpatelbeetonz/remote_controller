import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tv_remote_adapter.dart';

class AmazonFireTvAdapter implements TvRemoteAdapter {
  HttpClient? _httpClient;
  bool _isConnected = false;
  String? _pairedToken;
  TvDevice? _currentDevice;

  Function(String)? _onPin;
  Function(String)? _onStatus;

  final HttpClient Function()? _clientFactory;

  AmazonFireTvAdapter([this._clientFactory]);

  final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();

  void _addLog(String level, String message) {
    _logController.add({
      'level': level,
      'tag': 'FIRETV',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs => _logController.stream;

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    _addLog('INFO', 'Starting Amazon Fire TV SSDP network scan...');
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
          'ST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n';

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
              
              if (discovered.any((d) => d.ipAddress == ip)) continue;

              _addLog('INFO', 'Found DIAL service at IP $ip, checking if Amazon Fire TV device...');
              final deviceName = await _getFireTvName(location);
              if (deviceName != null) {
                _addLog('INFO', 'Discovered Amazon Fire TV ($deviceName) at IP: $ip');
                final device = TvDevice(
                  id: 'firetv-$ip',
                  name: deviceName,
                  ipAddress: ip,
                  port: 8080, // Fire TV REST Port
                  brand: 'Amazon Fire TV',
                );
                discovered.add(device);
                onDevices(List.from(discovered));
              } else {
                _addLog('DEBUG', 'DIAL device at IP $ip is not a Fire TV.');
              }
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'SSDP Discovery error: $e');
    } finally {
      socket?.close();
      _addLog('INFO', 'Amazon Fire TV network scan finished.');
    }
  }

  Future<String?> _getFireTvName(String location) async {
    final client = _clientFactory != null ? _clientFactory!() : HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(location));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final lowerBody = body.toLowerCase();
        
        final isAmazon = lowerBody.contains('<manufacturer>amazon') || 
                         lowerBody.contains('amazon.com') || 
                         lowerBody.contains('firetv') || 
                         lowerBody.contains('fire tv');
        
        if (isAmazon) {
          final match = RegExp(r'<friendlyName>(.*?)</friendlyName>', caseSensitive: false).firstMatch(body);
          if (match != null && match.groupCount >= 1) {
            return match.group(1);
          }
          final modelMatch = RegExp(r'<modelName>(.*?)</modelName>', caseSensitive: false).firstMatch(body);
          if (modelMatch != null && modelMatch.groupCount >= 1) {
            return modelMatch.group(1);
          }
          return 'Amazon Fire TV';
        }
      }
    } catch (e) {
      _addLog('DEBUG', 'Failed to fetch device description XML: $e');
    } finally {
      client.close(force: true);
    }
    return null;
  }

  @override
  Future<void> stopDiscovery() async {
    _addLog('INFO', 'Amazon Fire TV discovery stopped.');
  }

  @override
  Future<bool> connect(TvDevice device) async {
    _currentDevice = device;
    _isConnected = false;
    _onPin = null;
    _onStatus = null;
    _addLog('INFO', 'Connecting to Amazon Fire TV at ${device.ipAddress}:${device.port}...');

    // Load paired token
    final prefs = await SharedPreferences.getInstance();
    _pairedToken = prefs.getString('firetv_token_${device.ipAddress}');
    _addLog('DEBUG', 'Loaded cached pairing token: $_pairedToken');

    try {
      _httpClient = _clientFactory != null ? _clientFactory!() : HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 4);
      _httpClient!.badCertificateCallback = (cert, host, port) => true;

      // 1. Try to wake the device over HTTP port 8009
      try {
        final wakeRequest = await _httpClient!.postUrl(Uri.parse('http://${device.ipAddress}:8009/apps/FireTVRemote'));
        final wakeResponse = await wakeRequest.close();
        _addLog('DEBUG', 'Sent wake command to port 8009. Status: ${wakeResponse.statusCode}');
      } catch (e) {
        _addLog('DEBUG', 'Failed to send wake command: $e');
      }

      // 2. Validate reachability of HTTPS port 8080
      final testUri = Uri.parse('https://${device.ipAddress}:${device.port}/v1/FireTV');
      final request = await _httpClient!.getUrl(testUri);
      final response = await request.close();
      
      _addLog('INFO', 'Successfully validated Fire TV connection (Status: ${response.statusCode}).');
      _isConnected = true;
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to reach Fire TV at ${device.ipAddress}:${device.port}: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _addLog('INFO', 'Disconnecting Fire TV remote session...');
    _httpClient?.close(force: true);
    _httpClient = null;
    _isConnected = false;
    _onPin = null;
    _onStatus = null;
  }

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    _onPin = onPin;
    _onStatus = onStatus;

    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot start pairing: Not connected to device.');
      onStatus('FAILED');
      return false;
    }

    // If we already have a token, check if it works
    if (_pairedToken != null) {
      _addLog('INFO', 'Token exists. Verifying active token...');
      try {
        final testUri = Uri.parse('https://${_currentDevice!.ipAddress}:${_currentDevice!.port}/v1/FireTV');
        final request = await _httpClient!.getUrl(testUri);
        request.headers.add('X-Api-Key', '0987654321');
        request.headers.add('X-Client-Token', _pairedToken!);
        request.headers.add('User-Agent', 'okhttp/4.10.0');
        final response = await request.close();
        
        if (response.statusCode == 200) {
          _addLog('INFO', 'Cached token is valid. Reconnected.');
          onStatus('CONNECTED');
          return true;
        } else {
          _addLog('WARN', 'Cached token is invalid. Proceeding with pairing.');
        }
      } catch (e) {
        _addLog('WARN', 'Failed to verify token: $e. Proceeding with pairing.');
      }
    }

    _addLog('INFO', 'Pairing required. Requesting PIN display on TV screen...');
    try {
      final pinUrl = Uri.parse('https://${_currentDevice!.ipAddress}:${_currentDevice!.port}/v1/FireTV/pin/display');
      final request = await _httpClient!.postUrl(pinUrl);
      request.headers.add('X-Api-Key', '0987654321');
      request.headers.add('Content-Type', 'application/json');
      
      final body = jsonEncode({'friendlyName': 'Flutter Universal Remote'});
      request.write(body);
      
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        _addLog('INFO', 'PIN requested successfully. Check TV screen.');
        onPin('ENTER PIN');
        onStatus('WAITING_PIN');
        return true;
      } else {
        _addLog('ERROR', 'Failed to trigger PIN display. Status code: ${response.statusCode}');
        onStatus('FAILED');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Error starting pairing: $e');
      onStatus('FAILED');
      return false;
    }
  }

  @override
  Future<bool> sendPin(String pin) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot send PIN: Not connected to device.');
      _onStatus?.call('FAILED');
      return false;
    }

    _addLog('INFO', 'Submitting PIN: $pin for verification...');
    try {
      final verifyUrl = Uri.parse('https://${_currentDevice!.ipAddress}:${_currentDevice!.port}/v1/FireTV/pin/verify');
      final request = await _httpClient!.postUrl(verifyUrl);
      request.headers.add('X-Api-Key', '0987654321');
      request.headers.add('Content-Type', 'application/json');
      
      final body = jsonEncode({'pin': pin});
      request.write(body);
      
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(rawBody) as Map<String, dynamic>;
        final token = data['description'] as String?;
        
        if (token != null) {
          _pairedToken = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('firetv_token_${_currentDevice!.ipAddress}', token);
          
          _addLog('INFO', 'Pairing token acquired successfully: $token');
          _onStatus?.call('CONNECTED');
          return true;
        } else {
          _addLog('ERROR', 'Token field missing in verification response.');
          _onStatus?.call('FAILED');
          return false;
        }
      } else {
        _addLog('ERROR', 'PIN verification rejected. Status: ${response.statusCode}');
        _onStatus?.call('FAILED');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Error verifying PIN: $e');
      _onStatus?.call('FAILED');
      return false;
    }
  }

  @override
  Future<bool> sendKey(TvKey key) async {
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot send keypress: Not connected to Fire TV.');
      return false;
    }

    if (_pairedToken == null) {
      _addLog('ERROR', 'Cannot send keypress: Device is not paired.');
      return false;
    }

    String? action;
    bool isMedia = false;

    switch (key) {
      case TvKey.up:
        action = 'dpad_up';
        break;
      case TvKey.down:
        action = 'dpad_down';
        break;
      case TvKey.left:
        action = 'dpad_left';
        break;
      case TvKey.right:
        action = 'dpad_right';
        break;
      case TvKey.select:
        action = 'select';
        break;
      case TvKey.home:
        action = 'home';
        break;
      case TvKey.back:
        action = 'back';
        break;
      case TvKey.power:
        action = 'sleep';
        break;
      case TvKey.playPause:
        action = 'play';
        isMedia = true;
        break;
      case TvKey.volumeUp:
      case TvKey.volumeDown:
      case TvKey.mute:
        _addLog('WARN', 'Volume controls are not supported by the Fire TV REST protocol.');
        return false;
    }

    final path = isMedia ? 'media' : 'FireTV';
    final urlStr = 'https://${_currentDevice!.ipAddress}:${_currentDevice!.port}/v1/$path?action=$action';
    _addLog('DEBUG', 'Sending key press POST request to: $urlStr');

    try {
      final request = await _httpClient!.postUrl(Uri.parse(urlStr));
      request.headers.add('X-Api-Key', '0987654321');
      request.headers.add('X-Client-Token', _pairedToken!);
      request.headers.add('User-Agent', 'okhttp/4.10.0');
      request.headers.add('Content-Type', 'application/json');
      
      final response = await request.close();
      if (response.statusCode == 200) {
        return true;
      } else {
        _addLog('ERROR', 'Fire TV returned status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to send command to Fire TV: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    return [
      {'id': 'YouTube', 'name': 'YouTube'},
      {'id': 'Netflix', 'name': 'Netflix'},
      {'id': 'AmazonVideo', 'name': 'Prime Video'},
      {'id': 'Spotify', 'name': 'Spotify'},
    ];
  }

  @override
  Future<bool> launchApp(String appId) async {
    if (_currentDevice == null) {
      _addLog('ERROR', 'Cannot launch app: Not connected to Fire TV.');
      return false;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final url = 'http://${_currentDevice!.ipAddress}:8009/apps/$appId';
      _addLog('INFO', 'Launching Fire TV app $appId via DIAL: $url');
      final request = await client.postUrl(Uri.parse(url));
      request.headers.add('Content-Length', '0');
      final response = await request.close();
      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        _addLog('INFO', 'Successfully launched app $appId');
      } else {
        _addLog('ERROR', 'Failed to launch app $appId. Status: ${response.statusCode}');
      }
      return success;
    } catch (e) {
      _addLog('ERROR', 'Failed to launch app $appId via DIAL: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> sendText(String text) async {
    return false;
  }

  @override
  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    return false;
  }

  @override
  Future<void> stopCasting() async {}
}
