import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/tv_remote_adapter.dart';

class LgWebOsAdapter implements TvRemoteAdapter {
  WebSocketChannel? _channel;
  HttpClient? _httpClient;
  bool _isConnected = false;
  String? _pairedToken;
  TvDevice? _currentDevice;
  HttpServer? _localServer;

  Function(String)? _onPin;
  Function(String)? _onStatus;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  final WebSocketChannel Function(Uri, {HttpClient? customClient})? _webSocketFactory;

  LgWebOsAdapter([this._webSocketFactory]);

  final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();

  void _addLog(String level, String message) {
    _logController.add({
      'level': level,
      'tag': 'LG_WEBOS',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs => _logController.stream;

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    _addLog('INFO', 'Starting LG webOS SSDP network scan...');
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
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

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

              _addLog('INFO', 'Found MediaRenderer at IP $ip, validating if LG Electronics device...');
              final isLg = await _isLgDevice(location);
              if (isLg) {
                _addLog('INFO', 'Discovered LG webOS TV at IP: $ip');
                final device = TvDevice(
                  id: 'lg-$ip',
                  name: 'LG webOS TV ($ip)',
                  ipAddress: ip,
                  port: 3000, // SSAP Port
                  brand: 'LG webOS',
                );
                discovered.add(device);
                onDevices(List.from(discovered));
              } else {
                _addLog('DEBUG', 'MediaRenderer at IP $ip is not an LG device.');
              }
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'SSDP Discovery error: $e');
    } finally {
      socket?.close();
      _addLog('INFO', 'LG webOS network scan finished.');
    }
  }

  Future<bool> _isLgDevice(String location) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(location));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final lowerBody = body.toLowerCase();
        return lowerBody.contains('lg electronics') || lowerBody.contains('webos');
      }
    } catch (e) {
      _addLog('DEBUG', 'Failed to fetch device description XML: $e');
    } finally {
      client.close(force: true);
    }
    return false;
  }

  @override
  Future<void> stopDiscovery() async {
    _addLog('INFO', 'LG webOS discovery stopped.');
  }

  @override
  Future<bool> connect(TvDevice device) async {
    _currentDevice = device;
    _isConnected = false;
    _onPin = null;
    _onStatus = null;
    _addLog('INFO', 'Connecting to LG webOS TV at ${device.ipAddress}...');

    final prefs = await SharedPreferences.getInstance();
    _pairedToken = prefs.getString('lg_token_${device.ipAddress}');
    _addLog('DEBUG', 'Loaded cached pairing token: $_pairedToken');

    final url = 'ws://${device.ipAddress}:${device.port}';
    _addLog('DEBUG', 'Establishing WebSocket connection to: $url');

    try {
      _httpClient = HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 5);

      _channel = _webSocketFactory != null
          ? _webSocketFactory!(Uri.parse(url), customClient: _httpClient)
          : IOWebSocketChannel.connect(
              Uri.parse(url),
              customClient: _httpClient,
            );

      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (err) {
          _addLog('ERROR', 'WebSocket Connection Error: $err');
          _isConnected = false;
          _onStatus?.call('FAILED');
        },
        onDone: () {
          _addLog('WARN', 'WebSocket Connection Closed.');
          _isConnected = false;
          _onStatus?.call('FAILED');
        },
      );

      _isConnected = true;
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to initiate WebSocket connection: $e');
      _isConnected = false;
      return false;
    }
  }

  void _handleIncomingMessage(dynamic message) async {
    _addLog('DEBUG', 'Received WebSocket frame: $message');
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final id = json['id'] as String?;

      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id);
        completer?.complete(json);
      }

      if (type == 'registered') {
        final payload = json['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          final token = payload['client-key'] as String?;
          if (token != null && token != _pairedToken) {
            _pairedToken = token;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('lg_token_${_currentDevice!.ipAddress}', token);
            _addLog('INFO', 'New LG client key successfully acquired and saved: $token');
          }
        }
        _onStatus?.call('CONFIRMED');
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to parse incoming WebSocket message: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _addLog('INFO', 'Disconnecting LG webOS remote channel...');
    await _channel?.sink.close();
    _channel = null;
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

    _addLog('INFO', 'Pairing started. A confirmation popup should be visible on your TV.');
    onPin('CONFIRM ON TV');
    onStatus('WAITING_CONFIRMATION');

    // Send register payload
    final registrationPayload = jsonEncode({
      'type': 'register',
      'id': 'register_0',
      'payload': {
        'forcePairing': false,
        'pairingType': 'PROMPT',
        if (_pairedToken != null) 'client-key': _pairedToken,
        'manifest': {
          'manifestVersion': 1,
          'appVersion': '1.0.0',
          'signatures': [
            {
              'signature': 'dummy_signature',
              'signatureVersion': 1
            }
          ],
          'signed': {
            'created': '20140509',
            'appId': 'com.waysol.remote',
            'vendorId': 'waysol',
            'localizedAppNames': {
              '': 'Flutter Remote'
            },
            'permissions': [
              'LAUNCH',
              'LAUNCH_WEBAPP',
              'APP_TO_APP',
              'CLOSE',
              'TEST_OPEN',
              'TEST_CLOSE',
              'CONTROL_AUDIO',
              'CONTROL_INPUT_TEXT',
              'CONTROL_INPUT_MOUSE',
              'CONTROL_POWER',
              'READ_INSTALLED_APPS',
              'READ_STATUS',
              'READ_TV_CHANNEL',
              'WRITE_NOTIFICATION_TOAST',
              'CONTROL_TV_SCREEN'
            ]
          }
        }
      }
    });

    _addLog('DEBUG', 'Sending LG webOS SSAP registration handshake.');
    _channel?.sink.add(registrationPayload);
    return true;
  }

  @override
  Future<bool> sendPin(String pin) async {
    return true;
  }

  Future<void> _sendRequest(String uri, [Map<String, dynamic>? payload]) async {
    if (_channel == null) return;
    final msg = jsonEncode({
      'type': 'request',
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'uri': uri,
      if (payload != null) 'payload': payload,
    });
    _addLog('DEBUG', 'Sending SSAP Request: $msg');
    _channel!.sink.add(msg);
  }

  Future<Map<String, dynamic>> _sendRequestWithResponse(String uri, [Map<String, dynamic>? payload]) async {
    if (_channel == null) {
      throw Exception('Not connected to LG TV WebSocket.');
    }
    final reqId = 'req_${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[reqId] = completer;

    final msg = jsonEncode({
      'type': 'request',
      'id': reqId,
      'uri': uri,
      if (payload != null) 'payload': payload,
    });
    _addLog('DEBUG', 'Sending SSAP Request: $msg');
    _channel!.sink.add(msg);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(reqId);
        throw TimeoutException('Request to $uri timed out');
      },
    );
  }

  @override
  Future<bool> sendKey(TvKey key) async {
    if (!_isConnected || _channel == null) {
      _addLog('ERROR', 'Cannot send keypress: WebSocket is not connected.');
      return false;
    }

    switch (key) {
      case TvKey.power:
        await _sendRequest('ssap://system/turnOff');
        break;
      case TvKey.volumeUp:
        await _sendRequest('ssap://audio/volumeUp');
        break;
      case TvKey.volumeDown:
        await _sendRequest('ssap://audio/volumeDown');
        break;
      case TvKey.mute:
        await _sendRequest('ssap://audio/setMute', {'mute': true});
        break;
      case TvKey.up:
        await _sendRequest('ssap://input/generateKey', {'name': 'UP'});
        break;
      case TvKey.down:
        await _sendRequest('ssap://input/generateKey', {'name': 'DOWN'});
        break;
      case TvKey.left:
        await _sendRequest('ssap://input/generateKey', {'name': 'LEFT'});
        break;
      case TvKey.right:
        await _sendRequest('ssap://input/generateKey', {'name': 'RIGHT'});
        break;
      case TvKey.select:
        await _sendRequest('ssap://input/generateKey', {'name': 'ENTER'});
        break;
      case TvKey.back:
        await _sendRequest('ssap://input/generateKey', {'name': 'BACK'});
        break;
      case TvKey.home:
        await _sendRequest('ssap://input/generateKey', {'name': 'HOME'});
        break;
      case TvKey.playPause:
        await _sendRequest('ssap://input/generateKey', {'name': 'PLAY'});
        break;
      case TvKey.rewind:
        await _sendRequest('ssap://input/generateKey', {'name': 'REWIND'});
        break;
      case TvKey.fastForward:
        await _sendRequest('ssap://input/generateKey', {'name': 'FASTFORWARD'});
        break;
      case TvKey.options:
        await _sendRequest('ssap://input/generateKey', {'name': 'MENU'});
        break;
      case TvKey.info:
        await _sendRequest('ssap://input/generateKey', {'name': 'INFO'});
        break;
      case TvKey.inputSource:
        await _sendRequest('ssap://input/generateKey', {'name': 'INPUT'});
        break;
    }
    return true;
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final response = await _sendRequestWithResponse('ssap://com.webos.applicationManager/listLaunchPoints');
      final payload = response['payload'] as Map<String, dynamic>?;
      if (payload == null) return [];

      final launchPoints = payload['launchPoints'] as List<dynamic>?;
      if (launchPoints == null) return [];

      final List<Map<String, String>> apps = [];
      for (final lp in launchPoints) {
        if (lp is Map<String, dynamic>) {
          final id = lp['id'] as String?;
          final title = lp['title'] as String?;
          final icon = lp['icon'] as String?;
          if (id != null && title != null) {
            apps.add({
              'id': id,
              'name': title,
              'icon': icon ?? '',
            });
          }
        }
      }
      return apps;
    } catch (e) {
      _addLog('ERROR', 'Failed to fetch installed apps: $e');
      return [];
    }
  }

  @override
  Future<bool> launchApp(String appId) async {
    try {
      final response = await _sendRequestWithResponse('ssap://system.launcher/launch', {'id': appId});
      final payload = response['payload'] as Map<String, dynamic>?;
      final success = response['returnValue'] == true || (payload != null && payload['returnValue'] == true);
      if (success) {
        _addLog('INFO', 'Successfully launched app: $appId');
      } else {
        _addLog('ERROR', 'Failed to launch app $appId: $response');
      }
      return success;
    } catch (e) {
      _addLog('ERROR', 'Failed to launch app $appId: $e');
      return false;
    }
  }

  @override
  Future<bool> sendText(String text) async {
    if (!_isConnected || _channel == null) return false;
    try {
      _addLog('INFO', 'Sending text IME input: $text');
      await _sendRequest('ssap://com.webos.service.ime/insertText', {
        'text': text,
        'replace': false,
      });
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to send text via IME: $e');
      return false;
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

  @override
  Future<bool> castMedia({
    required String url,
    required String type,
    String? name,
    String? format,
  }) async {
    if (!_isConnected || _channel == null) {
      _addLog('ERROR', 'Cannot cast media: LG webOS is not connected.');
      return false;
    }

    if (type == 'w') {
      try {
        await _sendRequest('ssap://system.launcher/open', {
          'target': url,
        });
        _addLog('INFO', 'Successfully opened browser URL on LG TV: $url');
        return true;
      } catch (e) {
        _addLog('ERROR', 'Failed to open browser URL on LG TV: $e');
        return false;
      }
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

    String mimeType = 'video/mp4';
    if (type == 'p') {
      final ext = url.split('.').last.split('?').first.toLowerCase();
      mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    } else if (type == 'm') {
      mimeType = 'audio/mpeg';
    }

    try {
      await _sendRequest('ssap://media.viewer/open', {
        'target': finalUrl,
        'title': name ?? (isLocalFile ? url.split('/').last : 'Web Media'),
        'mimeType': mimeType,
        'loop': false,
      });
      _addLog('INFO', 'Cast media command sent: $finalUrl');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to send cast request: $e');
      return false;
    }
  }

  @override
  Future<void> stopCasting() async {
    _addLog('INFO', 'Stopping media cast...');
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      _addLog('INFO', 'Local media server shut down.');
    }
    await _sendRequest('ssap://media.viewer/close');
  }
}
