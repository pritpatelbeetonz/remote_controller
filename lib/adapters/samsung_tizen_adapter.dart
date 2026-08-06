import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/tv_remote_adapter.dart';

/// Samsung Tizen WebSocket Remote Adapter.
///
/// Protocol reference:
///   ws://tv:8001/api/v2/channels/samsung.remote.control
///     ?name=<Base64(appName)>[&token=<pairedToken>]
///
/// Flow:
///   1. SSDP M-SEARCH → discover IP
///   2. GET /api/v2/ → read device info (port, TokenAuthSupport)
///   3. WS connect → receive ms.channel.connect (contains token)
///   4. Store token → reuse on reconnect (no re-pairing)
class SamsungTizenAdapter implements TvRemoteAdapter {
  // ─── State ───────────────────────────────────────────────────────────────

  WebSocketChannel? _channel;
  HttpClient? _httpClient;
  bool _isConnected = false;
  String? _pairedToken;
  TvDevice? _currentDevice;
  RawDatagramSocket? _ssdpSocket; // kept so stopDiscovery() can cancel it
  StreamSubscription<dynamic>? _wsSubscription;
  HttpServer? _localServer;

  Function(String)? _onPin;
  Function(String)? _onStatus;

  final WebSocketChannel Function(Uri, {HttpClient? customClient})? _webSocketFactory;

  SamsungTizenAdapter([this._webSocketFactory]);

  @override
  void Function()? onConnectionLost;

  // ─── Logging ─────────────────────────────────────────────────────────────

  final StreamController<Map<String, dynamic>> _logController =
      StreamController<Map<String, dynamic>>.broadcast();

  void _addLog(String level, String message) {
    _logController.add({
      'level': level,
      'tag': 'TIZEN',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs => _logController.stream;

  // ─── Discovery ───────────────────────────────────────────────────────────

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    _addLog('INFO', 'Starting Samsung Tizen SSDP network scan...');
    unawaited(_scanSSDP(onDevices));
  }

  Future<void> _scanSSDP(Function(List<TvDevice>) onDevices) async {
    final List<TvDevice> discovered = [];

    try {
      _ssdpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _ssdpSocket!.broadcastEnabled = true;
      _ssdpSocket!.multicastLoopback = false;

      // Samsung TV SSDP search target
      final searchMsg = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:samsung.com:device:RemoteControlReceiver:1\r\n\r\n';

      _ssdpSocket!.send(
        utf8.encode(searchMsg),
        InternetAddress('239.255.255.250'),
        1900,
      );
      _addLog('DEBUG', 'SSDP M-SEARCH packet sent.');

      // Listen for responses for 5 seconds
      final stream = _ssdpSocket!.timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) => sink.close(),
      );

      await for (final event in stream) {
        if (event != RawSocketEvent.read) continue;
        final datagram = _ssdpSocket?.receive();
        if (datagram == null) continue;

        final response = utf8.decode(datagram.data, allowMalformed: true);
        _addLog('DEBUG', 'SSDP response from ${datagram.address.address}');

        // Extract LOCATION header
        String? location;
        for (final line in response.split('\r\n')) {
          if (line.toLowerCase().startsWith('location:')) {
            location = line.substring(9).trim();
            break;
          }
        }
        if (location == null) continue;

        final uri = Uri.tryParse(location);
        if (uri == null) continue;

        final ip = uri.host;

        // Skip duplicates
        if (discovered.any((d) => d.ipAddress == ip)) continue;

        _addLog('INFO', 'Discovered Samsung TV at $ip — fetching device info...');

        // ── Fetch /api/v2/ to get real port and TokenAuthSupport ──────────
        final deviceInfo = await _fetchDeviceInfo(ip);
        final port = _resolvePort(deviceInfo);
        final tvName = (deviceInfo?['device']?['name'] as String?) ?? 'Samsung TV';

        final device = TvDevice(
          id: 'samsung-$ip',
          name: tvName,
          ipAddress: ip,
          port: port,
          brand: 'Samsung Tizen',
        );

        discovered.add(device);
        onDevices(List.from(discovered));
        _addLog('INFO', 'Added device: "$tvName" ($ip:$port)');
      }
    } catch (e) {
      _addLog('ERROR', 'SSDP Discovery error: $e');
    } finally {
      _ssdpSocket?.close();
      _ssdpSocket = null;
      _addLog('INFO', 'Samsung Tizen network scan finished. Found: ${discovered.length} TV(s).');
    }
  }

  /// Fetch device info from GET /api/v2/ — returns null on failure.
  Future<Map<String, dynamic>?> _fetchDeviceInfo(String ip) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(Uri.parse('http://$ip:8001/api/v2/'));
      final response = await request.close().timeout(const Duration(seconds: 3));
      final body = await response.transform(utf8.decoder).join();
      client.close();
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (e) {
      _addLog('WARN', 'Could not fetch /api/v2/ from $ip: $e');
      return null;
    }
  }

  /// Determine WS port from device info.
  /// TokenAuthSupport=true → WSS on 8002, false → WS on 8001.
  int _resolvePort(Map<String, dynamic>? deviceInfo) {
    final tokenAuth =
        deviceInfo?['device']?['TokenAuthSupport'] as String? ?? 'false';
    return tokenAuth == 'true' ? 8002 : 8001;
  }

  /// Build the correct WebSocket scheme from port.
  String _wsScheme(int port) => port == 8002 ? 'wss' : 'ws';

  @override
  Future<void> stopDiscovery() async {
    _ssdpSocket?.close();
    _ssdpSocket = null;
    _addLog('INFO', 'Samsung Tizen discovery stopped.');
  }

  // ─── Connection ───────────────────────────────────────────────────────────

  @override
  Future<bool> connect(TvDevice device) async {
    _currentDevice = device;
    _isConnected = false;
    _onPin = null;
    _onStatus = null;
    _addLog('INFO', 'Connecting to ${device.name} at ${device.ipAddress}:${device.port}...');

    // 1. Load stored token
    final prefs = await SharedPreferences.getInstance();
    _pairedToken = prefs.getString('samsung_token_${device.ipAddress}');
    if (_pairedToken != null) {
      _addLog('DEBUG', 'Found cached token: $_pairedToken');
    }

    // 2. Build URL
    final scheme = _wsScheme(device.port);
    final appNameBase64 = base64.encode(utf8.encode('FlutterRemote'));
    final tokenParam = _pairedToken != null ? '&token=$_pairedToken' : '';
    final url = '$scheme://${device.ipAddress}:${device.port}'
        '/api/v2/channels/samsung.remote.control'
        '?name=$appNameBase64$tokenParam';

    _addLog('DEBUG', 'Connecting to: $url');

    try {
      // 3. Create HTTP client (skip cert validation for self-signed WSS)
      _httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
          ..badCertificateCallback = (cert, host, port) => true;

      _channel = _webSocketFactory != null
          ? _webSocketFactory!(Uri.parse(url), customClient: _httpClient)
          : IOWebSocketChannel.connect(
              Uri.parse(url),
              customClient: _httpClient,
            );

      // 4. Subscribe to incoming frames
      _wsSubscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (Object err) {
          _addLog('ERROR', 'WebSocket error: $err');
          _isConnected = false;
          _onStatus?.call('FAILED');
        },
        onDone: () {
          _addLog('WARN', 'WebSocket closed.');
          _isConnected = false;
          _onStatus?.call('FAILED');
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _addLog('INFO', 'WebSocket open — waiting for ms.channel.connect...');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ─── Incoming Messages ────────────────────────────────────────────────────

  Future<void> _handleIncomingMessage(dynamic message) async {
    _addLog('DEBUG', 'Frame: $message');
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final event = json['event'] as String?;

      switch (event) {
        case 'ms.channel.connect':
          await _handleChannelConnect(json);

        case 'ms.channel.ready':
          _addLog('INFO', '✅ Channel ready — TV is accepting commands.');

        case 'ms.channel.unauthorized':
          _addLog('WARN', 'Token rejected — clearing saved token for re-pairing.');
          await _clearSavedToken();
          _onStatus?.call('UNAUTHORIZED');

        case 'ms.error':
          final error = json['data']?['message'] ?? 'unknown error';
          _addLog('ERROR', 'TV error: $error');

        default:
          _addLog('DEBUG', 'Unhandled event: $event');
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to parse message: $e');
    }
  }

  Future<void> _handleChannelConnect(Map<String, dynamic> json) async {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty && token != _pairedToken) {
      _pairedToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('samsung_token_${_currentDevice!.ipAddress}', token);
      _addLog('INFO', '🔑 Token saved: $token');
    }

    _onStatus?.call('CONFIRMED');
    _addLog('INFO', '✅ Paired! App: ${_currentDevice?.name}');
  }

  Future<void> _clearSavedToken() async {
    _pairedToken = null;
    if (_currentDevice != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('samsung_token_${_currentDevice!.ipAddress}');
    }
  }

  // ─── Pairing ──────────────────────────────────────────────────────────────

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    _onPin = onPin;
    _onStatus = onStatus;
    _addLog('INFO', 'Pairing initiated — confirm popup on TV screen.');
    onPin('CONFIRM ON TV');
    onStatus('WAITING_CONFIRMATION');
    return true;
  }

  @override
  Future<bool> sendPin(String pin) async {
    // Samsung Tizen uses TV-side confirmation, not PIN entry
    return true;
  }

  // ─── Key Commands ─────────────────────────────────────────────────────────

  @override
  Future<bool> sendKey(TvKey key) async {
    if (!_isConnected || _channel == null) {
      _addLog('ERROR', 'Cannot send key: not connected.');
      return false;
    }

    final keyString = _mapKeyToTizen(key);
    if (keyString == null) {
      _addLog('WARN', 'Key $key has no Samsung Tizen mapping.');
      return false;
    }

    final payload = jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': keyString,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });

    _addLog('DEBUG', '→ $keyString');
    try {
      _channel!.sink.add(payload);
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to send key $keyString: $e');
      return false;
    }
  }

  String? _mapKeyToTizen(TvKey key) {
    switch (key) {
      case TvKey.power:
        return 'KEY_POWER';
      case TvKey.volumeUp:
        return 'KEY_VOLUMEUP';
      case TvKey.volumeDown:
        return 'KEY_VOLUMEDOWN';
      case TvKey.mute:
        return 'KEY_MUTE';
      case TvKey.up:
        return 'KEY_UP';
      case TvKey.down:
        return 'KEY_DOWN';
      case TvKey.left:
        return 'KEY_LEFT';
      case TvKey.right:
        return 'KEY_RIGHT';
      case TvKey.select:
        return 'KEY_ENTER';
      case TvKey.back:
        return 'KEY_RETURN';
      case TvKey.home:
        return 'KEY_HOME';
      case TvKey.playPause:
        return 'KEY_PLAY_BACK';
      case TvKey.rewind:
        return 'KEY_REWIND';
      case TvKey.fastForward:
        return 'KEY_FF';
      case TvKey.options:
        return 'KEY_TOOLS';
      case TvKey.info:
        return 'KEY_INFO';
      case TvKey.inputSource:
        return 'KEY_SOURCE';
    }
  }

  // ─── Apps ─────────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    if (!_isConnected || _currentDevice == null) return [];
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4)
        ..badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(
        Uri.parse('http://${_currentDevice!.ipAddress}:8001/api/v2/applications'),
      );
      final response = await request.close().timeout(const Duration(seconds: 4));
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final apps = (json['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return apps
          .map((app) => {
                'id': (app['id'] as String?) ?? '',
                'name': (app['name'] as String?) ?? 'Unknown',
                'iconUrl': (app['icon'] as String?) ?? '',
              })
          .toList();
    } catch (e) {
      _addLog('ERROR', 'Failed to fetch apps: $e');
      return [];
    }
  }

  @override
  Future<bool> launchApp(String appId) async {
    if (!_isConnected || _channel == null) return false;
    try {
      final payload = jsonEncode({
        'method': 'ms.application.start',
        'params': {'id': appId, 'action_type': 'DEEP_LINK', 'metaTag': ''},
      });
      _channel!.sink.add(payload);
      _addLog('INFO', 'Launch app: $appId');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to launch app $appId: $e');
      return false;
    }
  }

  // ─── Text Input ───────────────────────────────────────────────────────────

  @override
  Future<bool> sendText(String text) async {
    if (!_isConnected || _channel == null) return false;
    try {
      final payload = jsonEncode({
        'method': 'ms.remote.control',
        'params': {
          'Cmd': 'Click',
          'DataOfCmd': text,
          'Option': 'false',
          'TypeOfRemote': 'SendInputString',
        },
      });
      _channel!.sink.add(payload);
      _addLog('INFO', 'Sent text: $text');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to send text: $e');
      return false;
    }
  }

  @override
  Future<bool> isKeyboardSupported() => Future.value(true);

  @override
  Future<bool> isTextFieldFocused() => Future.value(true);

  @override
  Future<String> getKeyboardState() => Future.value('READY');

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

  // ─── Cast Media ───────────────────────────────────────────────────────────

  @override
  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    // Samsung Tizen uses ms.channel.emit for casting via DIAL/SmartView
    if (!_isConnected || _channel == null) return false;

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

    try {
      final payload = jsonEncode({
        'method': 'ms.channel.emit',
        'params': {
          'event': 'ed.apps.launch',
          'to': 'host',
          'data': {
            'appId': (type == 'v' || type == 'p' || type == 'w') ? 'org.tizen.browser' : '',
            'action_type': 'DEEP_LINK',
            'metaTag': finalUrl,
          },
        },
      });
      _channel!.sink.add(payload);
      _addLog('INFO', 'Cast media: $finalUrl');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Cast failed: $e');
      return false;
    }
  }

  @override
  Future<void> stopCasting() async {
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      _addLog('INFO', 'Local media server shut down.');
    }
    if (_isConnected && _channel != null) {
      final payload = jsonEncode({
        'method': 'ms.application.stop',
        'params': {},
      });
      _channel!.sink.add(payload);
      _addLog('INFO', 'Casting stopped.');
    }
  }

  // ─── Disconnect ───────────────────────────────────────────────────────────

  @override
  Future<void> disconnect() async {
    _addLog('INFO', 'Disconnecting...');
    await stopCasting();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _channel?.sink.close(1000, 'App disconnected');
    _channel = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _isConnected = false;
    _onPin = null;
    _onStatus = null;
  }
}
