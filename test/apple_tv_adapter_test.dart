import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:remote_controller/core/tv_remote_adapter.dart';
import 'package:remote_controller/adapters/apple_tv_adapter.dart';

class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  MockHttpClientResponse({required this.statusCode, required this.body});

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([utf8.encode(body)]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();
  @override
  int contentLength = 0;
  final HttpClientResponse response;
  final List<List<int>> writtenData = [];

  MockHttpClientRequest(this.response);

  @override
  void write(Object? obj) {
    if (obj != null) {
      writtenData.add(utf8.encode(obj.toString()));
    }
  }

  @override
  void add(List<int> data) {
    writtenData.add(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClient implements HttpClient {
  final List<String> requestedUrls = [];
  final Map<String, MockHttpClientResponse> responses = {};
  bool isClosed = false;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add('GET $url');
    final res = responses['GET $url'] ?? responses['GET ${url.path}'] ?? MockHttpClientResponse(statusCode: 404, body: '{}');
    return MockHttpClientRequest(res);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    requestedUrls.add('POST $url');
    final res = responses['POST $url'] ?? responses['POST ${url.path}'] ?? MockHttpClientResponse(statusCode: 404, body: '{}');
    return MockHttpClientRequest(res);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    requestedUrls.add('PUT $url');
    final res = responses['PUT $url'] ?? responses['PUT ${url.path}'] ?? MockHttpClientResponse(statusCode: 404, body: '{}');
    return MockHttpClientRequest(res);
  }

  @override
  void close({bool force = false}) {
    isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMDnsClient implements MDnsClient {
  final List<ResourceRecord> records = [];
  bool isStarted = false;
  bool isStopped = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #start) {
      isStarted = true;
      return Future.value();
    }
    if (invocation.memberName == #stop) {
      isStopped = true;
      return null;
    }
    if (invocation.memberName == #lookup) {
      final typeArg = invocation.typeArguments.first;
      final matching = records.where((r) {
        final rTypeStr = r.runtimeType.toString();
        final typeArgStr = typeArg.toString();
        return rTypeStr == typeArgStr ||
            (typeArgStr.contains('PtrResourceRecord') && r is PtrResourceRecord) ||
            (typeArgStr.contains('SrvResourceRecord') && r is SrvResourceRecord) ||
            (typeArgStr.contains('IPAddressResourceRecord') && r is IPAddressResourceRecord);
      }).toList();
      
      final typeStr = typeArg.toString();
      if (typeStr.contains('PtrResourceRecord')) {
        return Stream<PtrResourceRecord>.fromIterable(matching.cast<PtrResourceRecord>());
      } else if (typeStr.contains('SrvResourceRecord')) {
        return Stream<SrvResourceRecord>.fromIterable(matching.cast<SrvResourceRecord>());
      } else if (typeStr.contains('IPAddressResourceRecord')) {
        return Stream<IPAddressResourceRecord>.fromIterable(matching.cast<IPAddressResourceRecord>());
      }
      return Stream<ResourceRecord>.fromIterable(matching);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('AppleTvAdapter Tests', () {
    late MockHttpClient mockClient;
    late MockMDnsClient mockMDns;
    late AppleTvAdapter adapter;
    late TvDevice device;

    setUp(() {
      mockClient = MockHttpClient();
      mockMDns = MockMDnsClient();
      adapter = AppleTvAdapter(() => mockClient, () => mockMDns);
      device = TvDevice(
        id: 'appletv-192.168.1.60',
        name: 'Living Room Apple TV',
        ipAddress: '192.168.1.60',
        port: 7000,
        brand: 'Apple TV',
      );
    });

    test('startDiscovery performs mDNS lookup and returns TvDevice', () async {
      mockMDns.records.addAll([
        const PtrResourceRecord(
          '_airplay._tcp.local',
          0,
          domainName: 'Living Room Apple TV._airplay._tcp.local',
        ),
        SrvResourceRecord(
          'Living Room Apple TV._airplay._tcp.local',
          0,
          port: 7000,
          priority: 0,
          weight: 0,
          target: 'Apple-TV-Target.local',
        ),
        IPAddressResourceRecord(
          'Apple-TV-Target.local',
          0,
          address: InternetAddress('192.168.1.60'),
        ),
      ]);

      final completer = Completer<List<TvDevice>>();
      await adapter.startDiscovery((devices) {
        if (!completer.isCompleted) {
          completer.complete(devices);
        }
      });

      final discovered = await completer.future;
      expect(discovered, isNotEmpty);
      expect(discovered.first.brand, equals('Apple TV'));
      expect(discovered.first.ipAddress, equals('192.168.1.60'));
      expect(discovered.first.port, equals(7000));
      expect(discovered.first.name, contains('Living Room Apple TV'));
      expect(mockMDns.isStarted, isTrue);
      expect(mockMDns.isStopped, isTrue);
    });

    test('connect checks AirPlay reachability via GET /server-info', () async {
      mockClient.responses['GET http://192.168.1.60:7000/server-info'] =
          MockHttpClientResponse(statusCode: 200, body: 'AirPlay Server Info XML');

      final connected = await adapter.connect(device);
      expect(connected, isTrue);
      expect(mockClient.requestedUrls, contains('GET http://192.168.1.60:7000/server-info'));
    });

    test('connect returns false on connection failure', () async {
      adapter = AppleTvAdapter(() {
        throw const SocketException('Connection timed out');
      }, () => mockMDns);

      final connected = await adapter.connect(device);
      expect(connected, isFalse);
    });

    test('pairing requires no PIN and completes immediately', () async {
      final pinCompleter = Completer<String>();
      final statusCompleter = Completer<String>();

      final pairingStarted = await adapter.startPairing(
        onPin: (pin) => pinCompleter.complete(pin),
        onStatus: (status) => statusCompleter.complete(status),
      );

      expect(pairingStarted, isTrue);
      expect(await pinCompleter.future, equals('NO PIN REQUIRED'));
      expect(await statusCompleter.future, equals('CONNECTED'));
    });

    test('sendKey alternates rate=1 (play) and rate=0 (pause) on PlayPause key', () async {
      mockClient.responses['GET http://192.168.1.60:7000/server-info'] =
          MockHttpClientResponse(statusCode: 200, body: 'OK');
      await adapter.connect(device);

      // First PlayPause: should send rate=1.000000 (Play)
      mockClient.responses['POST http://192.168.1.60:7000/rate?value=1.000000'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      final playSuccess = await adapter.sendKey(TvKey.playPause);
      expect(playSuccess, isTrue);
      expect(mockClient.requestedUrls, contains('POST http://192.168.1.60:7000/rate?value=1.000000'));

      // Second PlayPause: should send rate=0.000000 (Pause)
      mockClient.responses['POST http://192.168.1.60:7000/rate?value=0.000000'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      final pauseSuccess = await adapter.sendKey(TvKey.playPause);
      expect(pauseSuccess, isTrue);
      expect(mockClient.requestedUrls, contains('POST http://192.168.1.60:7000/rate?value=0.000000'));
    });

    test('sendKey navigation and volume commands return false and log warnings', () async {
      mockClient.responses['GET http://192.168.1.60:7000/server-info'] =
          MockHttpClientResponse(statusCode: 200, body: 'OK');
      await adapter.connect(device);

      final logStream = adapter.logs;
      final warnings = <String>[];
      final subscription = logStream.listen((log) {
        if (log['level'] == 'WARN') {
          warnings.add(log['message'] as String);
        }
      });

      final upResult = await adapter.sendKey(TvKey.up);
      expect(upResult, isFalse);

      final volResult = await adapter.sendKey(TvKey.volumeUp);
      expect(volResult, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('not supported over AirPlay'));

      await subscription.cancel();
    });

    test('castMedia and stopCasting send correct AirPlay play/photo/stop commands', () async {
      mockClient.responses['GET http://192.168.1.60:7000/server-info'] =
          MockHttpClientResponse(statusCode: 200, body: 'OK');
      await adapter.connect(device);

      // 1. Cast Video
      mockClient.responses['POST http://192.168.1.60:7000/play'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      final castVideoSuccess = await adapter.castMedia(
        url: 'https://example.com/movie.mp4',
        type: 'v',
        name: 'My Video',
      );
      expect(castVideoSuccess, isTrue);
      expect(mockClient.requestedUrls, contains('POST http://192.168.1.60:7000/play'));

      // 2. Cast Photo
      mockClient.responses['PUT http://192.168.1.60:7000/photo'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      mockClient.responses['GET https://example.com/photo.jpg'] =
          MockHttpClientResponse(statusCode: 200, body: 'dummy_image_bytes');
      final castPhotoSuccess = await adapter.castMedia(
        url: 'https://example.com/photo.jpg',
        type: 'p',
        name: 'My Photo',
      );
      expect(castPhotoSuccess, isTrue);
      expect(mockClient.requestedUrls, contains('PUT http://192.168.1.60:7000/photo'));

      // 3. Stop casting
      mockClient.responses['POST http://192.168.1.60:7000/stop'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      await adapter.stopCasting();
      expect(mockClient.requestedUrls, contains('POST http://192.168.1.60:7000/stop'));
    });

    test('getInstalledApps returns empty list and launchApp returns false', () async {
      await adapter.connect(device);

      final apps = await adapter.getInstalledApps();
      expect(apps, isEmpty);

      final success = await adapter.launchApp('youtube');
      expect(success, isFalse);
    });
  });
}
