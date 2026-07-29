import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:remote_controller/core/tv_remote_adapter.dart';
import 'package:remote_controller/adapters/amazon_fire_tv_adapter.dart';

class InMemorySharedPreferencesStore extends SharedPreferencesStorePlatform {
  final Map<String, Object> data = {};

  @override
  Future<bool> clear() async => true;
  @override
  Future<Map<String, Object>> getAll() async => data;
  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    data[key] = value;
    return true;
  }
}

class MockX509Certificate implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  bool Function(X509Certificate cert, String host, int port)? badCertificateCallback;

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
  void close({bool force = false}) {
    isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore();

  group('AmazonFireTvAdapter Tests', () {
    late MockHttpClient mockClient;
    late AmazonFireTvAdapter adapter;
    late TvDevice device;

    setUp(() {
      mockClient = MockHttpClient();
      adapter = AmazonFireTvAdapter(() => mockClient);
      device = TvDevice(
        id: 'firetv-192.168.1.50',
        name: 'Living Room Fire TV',
        ipAddress: '192.168.1.50',
        port: 8080,
        brand: 'Amazon Fire TV',
      );
    });

    test('connect wakes device on port 8009 and validates port 8080 reachability', () async {
      mockClient.responses['POST http://192.168.1.50:8009/apps/FireTVRemote'] =
          MockHttpClientResponse(statusCode: 200, body: 'OK');
      mockClient.responses['GET https://192.168.1.50:8080/v1/FireTV'] =
          MockHttpClientResponse(statusCode: 401, body: '{"error": "Unauthorized"}');

      final connected = await adapter.connect(device);
      expect(connected, isTrue);

      expect(mockClient.requestedUrls, contains('POST http://192.168.1.50:8009/apps/FireTVRemote'));
      expect(mockClient.requestedUrls, contains('GET https://192.168.1.50:8080/v1/FireTV'));
      expect(mockClient.badCertificateCallback, isNotNull);
      expect(mockClient.badCertificateCallback!(MockX509Certificate(), '', 0), isTrue);
    });

    test('connect handles unreachable device', () async {
      // Simulate connection timeout or socket error
      adapter = AmazonFireTvAdapter(() {
        throw const SocketException('Connection refused');
      });

      final connected = await adapter.connect(device);
      expect(connected, isFalse);
    });

    test('startPairing requests PIN display if no token cached', () async {
      // Setup connection first
      mockClient.responses['POST http://192.168.1.50:8009/apps/FireTVRemote'] = MockHttpClientResponse(statusCode: 200, body: '');
      mockClient.responses['GET https://192.168.1.50:8080/v1/FireTV'] = MockHttpClientResponse(statusCode: 401, body: '');
      await adapter.connect(device);

      mockClient.responses['POST https://192.168.1.50:8080/v1/FireTV/pin/display'] =
          MockHttpClientResponse(statusCode: 200, body: '{"status": "SUCCESS"}');

      final pinCompleter = Completer<String>();
      final statusCompleter = Completer<String>();

      final pairingStarted = await adapter.startPairing(
        onPin: (pin) => pinCompleter.complete(pin),
        onStatus: (status) => statusCompleter.complete(status),
      );

      expect(pairingStarted, isTrue);
      expect(await pinCompleter.future, equals('ENTER PIN'));
      expect(await statusCompleter.future, equals('WAITING_PIN'));
      expect(mockClient.requestedUrls, contains('POST https://192.168.1.50:8080/v1/FireTV/pin/display'));
    });

    test('startPairing verifies existing token if cached', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firetv_token_192.168.1.50', 'cached-token-xyz');

      mockClient.responses['POST http://192.168.1.50:8009/apps/FireTVRemote'] = MockHttpClientResponse(statusCode: 200, body: '');
      mockClient.responses['GET https://192.168.1.50:8080/v1/FireTV'] = MockHttpClientResponse(statusCode: 200, body: 'OK');
      
      await adapter.connect(device);

      final statusCompleter = Completer<String>();
      final pairingStarted = await adapter.startPairing(
        onPin: (_) {},
        onStatus: (status) => statusCompleter.complete(status),
      );

      expect(pairingStarted, isTrue);
      expect(await statusCompleter.future, equals('CONNECTED'));
      expect(mockClient.requestedUrls, contains('GET https://192.168.1.50:8080/v1/FireTV'));
    });

    test('sendPin sends PIN and caches acquired client token', () async {
      mockClient.responses['POST http://192.168.1.50:8009/apps/FireTVRemote'] = MockHttpClientResponse(statusCode: 200, body: '');
      mockClient.responses['GET https://192.168.1.50:8080/v1/FireTV'] = MockHttpClientResponse(statusCode: 401, body: '');
      await adapter.connect(device);

      mockClient.responses['POST https://192.168.1.50:8080/v1/FireTV/pin/verify'] =
          MockHttpClientResponse(statusCode: 200, body: '{"description": "new-client-token-999"}');

      final statusCompleter = Completer<String>();
      await adapter.startPairing(
        onPin: (_) {},
        onStatus: (status) {
          if (status == 'CONNECTED') {
            statusCompleter.complete(status);
          }
        },
      );

      final verified = await adapter.sendPin('1234');
      expect(verified, isTrue);
      expect(await statusCompleter.future, equals('CONNECTED'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('firetv_token_192.168.1.50'), equals('new-client-token-999'));
    });

    test('sendKey maps buttons to REST endpoints correctly with headers', () async {
      mockClient.responses['POST http://192.168.1.50:8009/apps/FireTVRemote'] = MockHttpClientResponse(statusCode: 200, body: '');
      mockClient.responses['GET https://192.168.1.50:8080/v1/FireTV'] = MockHttpClientResponse(statusCode: 401, body: '');
      await adapter.connect(device);

      // Verify and pair
      mockClient.responses['POST https://192.168.1.50:8080/v1/FireTV/pin/verify'] =
          MockHttpClientResponse(statusCode: 200, body: '{"description": "token123"}');
      await adapter.startPairing(onPin: (_) {}, onStatus: (_) {});
      await adapter.sendPin('1234');

      // 1. Test Navigation key (UP)
      mockClient.responses['POST https://192.168.1.50:8080/v1/FireTV?action=dpad_up'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      final upSent = await adapter.sendKey(TvKey.up);
      expect(upSent, isTrue);
      expect(mockClient.requestedUrls, contains('POST https://192.168.1.50:8080/v1/FireTV?action=dpad_up'));

      // 2. Test Media key (Play/Pause)
      mockClient.responses['POST https://192.168.1.50:8080/v1/media?action=play'] =
          MockHttpClientResponse(statusCode: 200, body: '');
      final playSent = await adapter.sendKey(TvKey.playPause);
      expect(playSent, isTrue);
      expect(mockClient.requestedUrls, contains('POST https://192.168.1.50:8080/v1/media?action=play'));

      // 3. Test Unsupported Key (Volume Up)
      final volSent = await adapter.sendKey(TvKey.volumeUp);
      expect(volSent, isFalse);
    });
  });
}
