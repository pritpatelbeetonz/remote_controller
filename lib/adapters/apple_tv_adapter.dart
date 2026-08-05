import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import '../core/tv_remote_adapter.dart';

class AppleTvAdapter implements TvRemoteAdapter {
  HttpClient? _httpClient;
  bool _isConnected = false;
  TvDevice? _currentDevice;
  bool _isPlaying = false;
  HttpServer? _localServer;

  final HttpClient Function()? _clientFactory;
  final MDnsClient Function()? _clientFactoryMDns;

  AppleTvAdapter([this._clientFactory, this._clientFactoryMDns]);

  @override
  void Function()? onConnectionLost;

  final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();

  void _addLog(String level, String message) {
    _logController.add({
      'level': level,
      'tag': 'APPLETV',
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  @override
  Stream<Map<String, dynamic>> get logs => _logController.stream;

  @override
  Future<void> startDiscovery(Function(List<TvDevice>) onDevices) async {
    _addLog('INFO', 'Starting Apple TV mDNS network scan for _airplay._tcp.local...');
    await _scanMDNS(onDevices);
  }

  Future<void> _scanMDNS(Function(List<TvDevice>) onDevices) async {
    final List<TvDevice> discovered = [];
    final MDnsClient client = _clientFactoryMDns != null
        ? _clientFactoryMDns!()
        : MDnsClient(
            rawDatagramSocketFactory: (dynamic host, int port,
                {bool reuseAddress = true, bool reusePort = true, int ttl = 255}) {
              return RawDatagramSocket.bind(
                host,
                port,
                reuseAddress: reuseAddress,
                reusePort: !Platform.isAndroid && !Platform.isLinux ? reusePort : false,
              );
            },
          );
    
    try {
      await client.start();
      _addLog('DEBUG', 'mDNS client started. Resolving _airplay._tcp.local...');

      const String serviceType = '_airplay._tcp.local';
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceType),
      )) {
        _addLog(
          'DEBUG',
          'PTR Service Found: ${ptr.domainName}',
        );
        String? friendlyName;
        if (ptr.domainName.endsWith('.$serviceType')) {
          friendlyName = ptr.domainName.substring(0, ptr.domainName.length - serviceType.length - 1);
        }

        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          _addLog(
            'DEBUG',
            'SRV Target: ${srv.target}:${srv.port}',
          );
          await for (final IPAddressResourceRecord ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            _addLog(
              'DEBUG',
              'Resolved IP: ${ip.address.address}',
            );
            final ipAddress = ip.address.address;
            final port = srv.port;
            final name = friendlyName ?? 'Apple TV';

            final lowerName = name.toLowerCase();
            if (lowerName.contains('mac mini') ||
                lowerName.contains('macmini') ||
                lowerName.contains('macbook') ||
                lowerName.contains('laptop') ||
                lowerName.contains('mac book') ||
                lowerName.contains('imac') ||
                lowerName.contains('mac studio') ||
                lowerName.contains('mac pro') ||
                lowerName.contains('macbookpro') ||
                lowerName.contains('macbookair') ||
                lowerName.contains('macos') ||
                (lowerName.contains('mac') && (lowerName.contains('’s') || lowerName.contains('\'s')))) {
              _addLog('INFO', 'Filtered out Mac device from Apple TV discovery: $name');
              continue;
            }

            if (!discovered.any((d) => d.ipAddress == ipAddress)) {
              _addLog('INFO', 'Discovered Apple TV ($name) at IP: $ipAddress:$port');

              final device = TvDevice(
                id: 'appletv-$ipAddress',
                name: '$name ($ipAddress)',
                ipAddress: ipAddress,
                port: port,
                brand: 'Apple TV',
              );

              discovered.add(device);

              _addLog(
                'INFO',
                'Total Apple TV devices discovered: ${discovered.length}',
              );

              onDevices(List.from(discovered));
            }          }
        }
      }
    } catch (e) {
      _addLog('ERROR', 'mDNS Discovery error: $e');
    } finally {
      client.stop();
      _addLog(
        'INFO',
        'Discovery completed. Total devices found: ${discovered.length}',
      );
      _addLog('INFO', 'Apple TV mDNS scan finished.');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _addLog('INFO', 'Apple TV discovery stopped.');
  }

  @override
  Future<bool> connect(TvDevice device) async {
    _currentDevice = device;
    _isConnected = false;
    _addLog('INFO', 'Connecting to Apple TV at ${device.ipAddress}:${device.port}...');

    try {
      _httpClient = _clientFactory != null ? _clientFactory!() : HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 4);

      // Validate reachability via GET /server-info
      final testUri = Uri.parse('http://${device.ipAddress}:${device.port}/server-info');
      final request = await _httpClient!.getUrl(testUri);
      final response = await request.close();

      if (response.statusCode == 200) {
        _addLog('INFO', 'Successfully validated AirPlay connection to Apple TV.');
        _isConnected = true;
        return true;
      } else {
        _addLog('ERROR', 'Failed to reach Apple TV AirPlay service. Status code: ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      _addLog('ERROR', 'Failed to connect to Apple TV at ${device.ipAddress}:${device.port}: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _addLog('INFO', 'Disconnecting Apple TV remote session...');
    _httpClient?.close(force: true);
    _httpClient = null;
    _isConnected = false;
  }

  @override
  Future<bool> startPairing({
    required Function(String) onPin,
    required Function(String) onStatus,
  }) async {
    // Option A: AirPlay basic control does not require pairing/PIN.
    _addLog('INFO', 'Pairing not required for AirPlay basic media control.');
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
      _addLog('ERROR', 'Cannot send keypress: Not connected to Apple TV.');
      return false;
    }

    if (key == TvKey.playPause) {
      // Toggle play/pause state
      final targetRate = _isPlaying ? '0.000000' : '1.000000';
      final actionLabel = _isPlaying ? 'Pause' : 'Play';
      final urlStr = 'http://${_currentDevice!.ipAddress}:${_currentDevice!.port}/rate?value=$targetRate';
      
      _addLog('DEBUG', 'Sending $actionLabel command via POST: $urlStr');

      try {
        final request = await _httpClient!.postUrl(Uri.parse(urlStr));
        final response = await request.close();
        
        if (response.statusCode == 200) {
          _isPlaying = !_isPlaying;
          return true;
        } else {
          _addLog('ERROR', 'AirPlay returned status code: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        _addLog('ERROR', 'Failed to send Play/Pause to Apple TV: $e');
        return false;
      }
    }

    // Log helpful navigation warning and platform-specific tips
    String tip;
    if (Platform.isIOS) {
      tip = 'Tip: Swipe down from the top-right corner of your screen to open iOS Control Center and use the built-in system Apple TV Remote widget.';
    } else {
      tip = "Tip: Apple TV requires Apple's proprietary Media Remote Protocol (MRP) for D-pad control. Please use the physical remote for menu navigation.";
    }

    _addLog('WARN', 'Key $key not supported over AirPlay. Only basic media playback (Play/Pause) is supported.');
    _addLog('WARN', tip);
    return false;
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    return [];
  }

  @override
  Future<bool> launchApp(String appId) async {
    return false;
  }

  @override
  Future<bool> sendText(String text) async {
    return false;
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
    if (!_isConnected || _currentDevice == null || _httpClient == null) {
      _addLog('ERROR', 'Cannot cast media: Apple TV is not connected.');
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

    if (type == 'p') {
      try {
        List<int> bytes;
        if (isLocalFile) {
          bytes = await File(url).readAsBytes();
        } else {
          final getReq = await _httpClient!.getUrl(Uri.parse(url));
          final getRes = await getReq.close();
          if (getRes.statusCode != 200) {
            _addLog('ERROR', 'Failed to download web image for casting. Status: ${getRes.statusCode}');
            return false;
          }
          bytes = await getRes.expand((b) => b).toList();
        }

        final ext = url.split('.').last.split('?').first.toLowerCase();
        final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

        final putUri = Uri.parse('http://${_currentDevice!.ipAddress}:7000/photo');
        final request = await _httpClient!.putUrl(putUri);
        request.headers.add('Content-Type', contentType);
        request.headers.add('User-Agent', 'MediaControl/1.0');
        request.contentLength = bytes.length;
        request.add(bytes);

        final response = await request.close();
        if (response.statusCode == 200) {
          _addLog('INFO', 'Successfully casted photo to Apple TV via AirPlay.');
          return true;
        } else {
          _addLog('ERROR', 'Apple TV photo PUT failed. Status code: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        _addLog('ERROR', 'Failed to cast photo to Apple TV: $e');
        return false;
      }
    } else {
      final body = 'Content-Location: $finalUrl\nStart-Position: 0.0\n';
      final playUri = Uri.parse('http://${_currentDevice!.ipAddress}:7000/play');

      _addLog('INFO', 'Initiating Apple TV AirPlay video/audio cast: $finalUrl');
      try {
        final request = await _httpClient!.postUrl(playUri);
        request.headers.add('Content-Type', 'text/parameters');
        request.headers.add('User-Agent', 'MediaControl/1.0');
        request.write(body);

        final response = await request.close();
        if (response.statusCode == 200) {
          _addLog('INFO', 'Media cast successfully accepted by Apple TV.');
          return true;
        } else {
          _addLog('ERROR', 'Apple TV AirPlay play command failed. Status code: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        _addLog('ERROR', 'Failed to send AirPlay play command to Apple TV: $e');
        return false;
      }
    }
  }

  @override
  Future<void> stopCasting() async {
    _addLog('INFO', 'Stopping media cast on Apple TV...');
    if (_localServer != null) {
      await _localServer!.close(force: true);
      _localServer = null;
      _addLog('INFO', 'Local media server shut down.');
    }
    if (_currentDevice != null && _httpClient != null) {
      try {
        final stopUri = Uri.parse('http://${_currentDevice!.ipAddress}:7000/stop');
        final request = await _httpClient!.postUrl(stopUri);
        request.headers.add('User-Agent', 'MediaControl/1.0');
        final response = await request.close();
        if (response.statusCode == 200) {
          _addLog('INFO', 'Successfully stopped Apple TV casting session.');
        } else {
          _addLog('WARN', 'Stop cast command returned status: ${response.statusCode}');
        }
      } catch (e) {
        _addLog('ERROR', 'Failed to send stop casting command to Apple TV: $e');
      }
    }
  }
}
