import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:remote_controller/core/tv_remote_adapter.dart';
import 'package:remote_controller/adapters/samsung_tizen_adapter.dart';

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

  group('SamsungTizenAdapter Tests', () {
    late StreamController<dynamic> streamController;
    late MockWebSocketChannel mockChannel;
    late SamsungTizenAdapter adapter;
    late TvDevice device;

    setUp(() {
      streamController = StreamController<dynamic>.broadcast();
      mockChannel = MockWebSocketChannel(streamController);
      adapter = SamsungTizenAdapter((uri, {customClient}) => mockChannel);
      device = TvDevice(
        id: 'samsung-192.168.1.10',
        name: 'Samsung TV',
        ipAddress: '192.168.1.10',
        port: 8002,
        brand: 'Samsung Tizen',
      );
    });

    tearDown(() async {
      await streamController.close();
      await adapter.disconnect();
    });

    test('connect sets up WebSocket channel and receives pairing token updates', () async {
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

      // Simulate a connect event from TV
      final connectMessage = jsonEncode({
        'event': 'ms.channel.connect',
        'data': {'token': 'test-pairing-token-123'}
      });
      streamController.add(connectMessage);

      expect(await confirmedCompleter.future, equals('CONFIRMED'));
    });

    test('failure reporting on WebSocket error/done during pairing', () async {
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
  });
}
