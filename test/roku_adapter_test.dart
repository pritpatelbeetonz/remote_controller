import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_controller/core/tv_remote_adapter.dart';
import 'package:remote_controller/adapters/roku_adapter.dart';

class MockHttpClientResponse implements HttpClientResponse {
  final int _statusCode;
  final String _body;

  MockHttpClientResponse(this._statusCode, [this._body = '']);

  @override
  int get statusCode => _statusCode;

  @override
  Stream<S> cast<S>() => Stream.value(utf8.encode(_body)).cast<S>();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(_body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<R> transform<R>(StreamTransformer<List<int>, R> streamTransformer) {
    return Stream.value(utf8.encode(_body)).cast<List<int>>().transform(streamTransformer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  final MockHttpClientResponse _response;

  MockHttpClientRequest(this._response);

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClient implements HttpClient {
  MockHttpClientResponse? mockResponse;
  String? lastRequestedUrl;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastRequestedUrl = url.toString();
    return MockHttpClientRequest(mockResponse ?? MockHttpClientResponse(200));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    lastRequestedUrl = url.toString();
    return MockHttpClientRequest(mockResponse ?? MockHttpClientResponse(200));
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('RokuAdapter Tests', () {
    late MockHttpClient mockClient;
    late RokuAdapter adapter;
    late TvDevice device;

    setUp(() {
      mockClient = MockHttpClient();
      adapter = RokuAdapter(() => mockClient);
      device = TvDevice(
        id: 'roku-192.168.1.15',
        name: 'Roku Device',
        ipAddress: '192.168.1.15',
        port: 8060,
        brand: 'Roku',
      );
    });

    test('connect reaches Roku and parses device info successfully', () async {
      mockClient.mockResponse = MockHttpClientResponse(200, '<device-info></device-info>');
      
      final connected = await adapter.connect(device);
      expect(connected, isTrue);
      expect(mockClient.lastRequestedUrl, equals('http://192.168.1.15:8060/query/device-info'));
    });

    test('connect fails on non-200 responses', () async {
      mockClient.mockResponse = MockHttpClientResponse(404);
      
      final connected = await adapter.connect(device);
      expect(connected, isFalse);
    });

    test('pairing requires no PIN and succeeds immediately', () async {
      mockClient.mockResponse = MockHttpClientResponse(200);
      await adapter.connect(device);

      final pinCompleter = Completer<String>();
      final statusCompleter = Completer<String>();

      await adapter.startPairing(
        onPin: (pin) => pinCompleter.complete(pin),
        onStatus: (status) => statusCompleter.complete(status),
      );

      expect(await pinCompleter.future, equals('NO PIN REQUIRED'));
      expect(await statusCompleter.future, equals('CONNECTED'));
    });

    test('sendKey issues HTTP POST to correct Roku ECP endpoints', () async {
      mockClient.mockResponse = MockHttpClientResponse(200);
      await adapter.connect(device);

      final success = await adapter.sendKey(TvKey.home);
      expect(success, isTrue);
      expect(mockClient.lastRequestedUrl, equals('http://192.168.1.15:8060/keypress/Home'));

      final powerSuccess = await adapter.sendKey(TvKey.power);
      expect(powerSuccess, isTrue);
      expect(mockClient.lastRequestedUrl, equals('http://192.168.1.15:8060/keypress/Power'));
    });

    test('getInstalledApps parses XML apps query response correctly', () async {
      final xmlBody = 
        '<apps>'
        '  <app id="12" type="menu" version="1.0.0">Netflix</app>'
        '  <app id="1357" type="appl" version="2.0.0">YouTube</app>'
        '</apps>';
      mockClient.mockResponse = MockHttpClientResponse(200, xmlBody);
      await adapter.connect(device);

      final apps = await adapter.getInstalledApps();
      expect(apps, hasLength(2));
      expect(apps[0]['id'], equals('12'));
      expect(apps[0]['name'], equals('Netflix'));
      expect(apps[0]['iconUrl'], equals('http://192.168.1.15:8060/query/icon/12'));

      expect(apps[1]['id'], equals('1357'));
      expect(apps[1]['name'], equals('YouTube'));
      expect(apps[1]['iconUrl'], equals('http://192.168.1.15:8060/query/icon/1357'));
    });

    test('launchApp issues HTTP POST to Roku ECP launch endpoint', () async {
      mockClient.mockResponse = MockHttpClientResponse(200);
      await adapter.connect(device);

      final success = await adapter.launchApp('1357');
      expect(success, isTrue);
      expect(mockClient.lastRequestedUrl, equals('http://192.168.1.15:8060/launch/1357'));
    });

    test('sendText sends correct ECP Lit_ keypresses', () async {
      mockClient.mockResponse = MockHttpClientResponse(200);
      await adapter.connect(device);

      final success = await adapter.sendText('ab');
      expect(success, isTrue);
      expect(mockClient.lastRequestedUrl, equals('http://192.168.1.15:8060/keypress/Lit_b'));
    });

    test('castMedia triggers PlayOnRoku casting ECP command', () async {
      mockClient.mockResponse = MockHttpClientResponse(200);
      await adapter.connect(device);

      final success = await adapter.castMedia(
        url: 'https://example.com/stream.mp4',
        type: 'v',
        name: 'My Video',
        format: 'mp4',
      );
      expect(success, isTrue);
      expect(mockClient.lastRequestedUrl, contains('input/15985'));
      expect(mockClient.lastRequestedUrl, contains('t=v'));
      expect(mockClient.lastRequestedUrl, contains('u=https%3A%2F%2Fexample.com%2Fstream.mp4'));
      expect(mockClient.lastRequestedUrl, contains('videoName=My%20Video'));
    });
  });
}
