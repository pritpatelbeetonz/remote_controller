import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:remote_controller/core/tv_remote_adapter.dart';
import 'package:remote_controller/adapters/lg_webos_adapter.dart';

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

class MockWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future get done => Completer().future;

  @override
  Future close([int? closeCode, String? closeReason]) async {}
}

class MockWebSocketChannel implements WebSocketChannel {
  final StreamController _streamController;
  final MockWebSocketSink _sink = MockWebSocketSink();

  MockWebSocketChannel(this._streamController);

  @override
  Stream get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore();

  group('LgWebOsAdapter Tests', () {
    late StreamController<dynamic> streamController;
    late MockWebSocketChannel mockChannel;
    late LgWebOsAdapter adapter;
    late TvDevice device;

    setUp(() {
      streamController = StreamController<dynamic>.broadcast();
      mockChannel = MockWebSocketChannel(streamController);
      adapter = LgWebOsAdapter((uri, {customClient}) => mockChannel);
      device = TvDevice(
        id: 'lg-192.168.1.20',
        name: 'LG TV',
        ipAddress: '192.168.1.20',
        port: 3000,
        brand: 'LG webOS',
      );
    });

    tearDown(() async {
      await streamController.close();
      await adapter.disconnect();
    });

    test('connect sets up WebSocket channel and receives registered payload', () async {
      final connected = await adapter.connect(device);
      expect(connected, isTrue);

      final statusCompleter = Completer<String>();
      final pinCompleter = Completer<String>();

      await adapter.startPairing(
        onPin: (pin) => pinCompleter.complete(pin),
        onStatus: (status) {
          if (!statusCompleter.isCompleted) {
            statusCompleter.complete(status);
          }
        },
      );

      expect(await pinCompleter.future, equals('CONFIRM ON TV'));
      expect(await statusCompleter.future, equals('WAITING_CONFIRMATION'));

      final confirmedCompleter = Completer<String>();
      await adapter.startPairing(
        onPin: (_) {},
        onStatus: (status) {
          if (!confirmedCompleter.isCompleted && status == 'CONFIRMED') {
            confirmedCompleter.complete(status);
          }
        },
      );

      // Simulate a registered event from LG TV
      final registeredMessage = jsonEncode({
        'type': 'registered',
        'payload': {'client-key': 'lg-paired-token-456'}
      });
      streamController.add(registeredMessage);

      expect(await confirmedCompleter.future, equals('CONFIRMED'));
    });

    test('failure reporting on WebSocket close during pairing', () async {
      await adapter.connect(device);

      final failureCompleter = Completer<String>();
      await adapter.startPairing(
        onPin: (_) {},
        onStatus: (status) {
          if (status == 'FAILED' && !failureCompleter.isCompleted) {
            failureCompleter.complete(status);
          }
        },
      );

      // Simulate connection closure
      await streamController.close();

      expect(await failureCompleter.future, equals('FAILED'));
    });

    test('sendKey formatting and transmission', () async {
      await adapter.connect(device);

      final success = await adapter.sendKey(TvKey.up);
      expect(success, isTrue);

      expect(mockChannel._sink.sentMessages.length, equals(1));
      final parsedRequest = jsonDecode(mockChannel._sink.sentMessages.first as String) as Map<String, dynamic>;
      expect(parsedRequest['uri'], equals('ssap://input/generateKey'));
      expect(parsedRequest['payload']['name'], equals('UP'));
    });

    test('castMedia and stopCasting send correct SSAP payloads', () async {
      await adapter.connect(device);

      final castSuccess = await adapter.castMedia(
        url: 'https://example.com/movie.mp4',
        type: 'v',
        name: 'My Movie',
      );
      expect(castSuccess, isTrue);

      expect(mockChannel._sink.sentMessages.length, equals(1));
      final castRequest = jsonDecode(mockChannel._sink.sentMessages.first as String) as Map<String, dynamic>;
      expect(castRequest['uri'], equals('ssap://media.viewer/open'));
      expect(castRequest['payload']['target'], equals('https://example.com/movie.mp4'));
      expect(castRequest['payload']['title'], equals('My Movie'));
      expect(castRequest['payload']['mimeType'], equals('video/mp4'));

      await adapter.stopCasting();
      expect(mockChannel._sink.sentMessages.length, equals(2));
      final stopRequest = jsonDecode(mockChannel._sink.sentMessages[1] as String) as Map<String, dynamic>;
      expect(stopRequest['uri'], equals('ssap://media.viewer/close'));
    });

    test('getInstalledApps sends correct SSAP request and maps response', () async {
      await adapter.connect(device);

      final appsFuture = adapter.getInstalledApps();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(mockChannel._sink.sentMessages.length, equals(1));
      final request = jsonDecode(mockChannel._sink.sentMessages.first as String) as Map<String, dynamic>;
      expect(request['uri'], equals('ssap://com.webos.applicationManager/listLaunchPoints'));
      final reqId = request['id'] as String;

      streamController.add(jsonEncode({
        'id': reqId,
        'payload': {
          'launchPoints': [
            {'id': 'com.webos.app.browser', 'title': 'Web Browser', 'icon': 'browser_icon.png'},
            {'id': 'youtube', 'title': 'YouTube'},
          ]
        }
      }));

      final apps = await appsFuture;
      expect(apps.length, equals(2));
      expect(apps[0]['id'], equals('com.webos.app.browser'));
      expect(apps[0]['name'], equals('Web Browser'));
      expect(apps[0]['icon'], equals('browser_icon.png'));
      expect(apps[1]['id'], equals('youtube'));
      expect(apps[1]['name'], equals('YouTube'));
      expect(apps[1]['icon'], equals(''));
    });

    test('launchApp sends launch command and returns success based on TV response', () async {
      await adapter.connect(device);

      final launchFuture = adapter.launchApp('youtube');

      await Future.delayed(const Duration(milliseconds: 10));

      expect(mockChannel._sink.sentMessages.length, equals(1));
      final request = jsonDecode(mockChannel._sink.sentMessages.first as String) as Map<String, dynamic>;
      expect(request['uri'], equals('ssap://system.launcher/launch'));
      expect(request['payload']['id'], equals('youtube'));
      final reqId = request['id'] as String;

      streamController.add(jsonEncode({
        'id': reqId,
        'returnValue': true,
      }));

      final success = await launchFuture;
      expect(success, isTrue);
    });
  });
}
