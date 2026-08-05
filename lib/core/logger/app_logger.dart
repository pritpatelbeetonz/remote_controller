import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'log_level.dart';
import 'log_sink.dart';

/// Central logging facade for the entire application.
///
/// Usage:
/// ```dart
/// // 1. Register sinks and initialize once at app start:
/// await AppLogger.initialize(sinks: [ConsoleLogSink(), FirestoreLogSink()]);
///
/// // 2. Log from anywhere with no other setup:
/// AppLogger.info('AndroidTV', 'Connection attempt started');
/// AppLogger.error('Purchase', 'Billing failure', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._(); // prevent instantiation

  static final List<LogSink> _sinks = [];
  static int _sequence = 0;
  static String _sessionId = '';
  static bool _initialized = false;

  // ─── Public API ─────────────────────────────────────────────────────────────

  static void debug(String module, String message) =>
      _log(AppLogLevel.debug, module, message);

  static void info(String module, String message) =>
      _log(AppLogLevel.info, module, message);

  static void warning(
    String module,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) =>
      _log(AppLogLevel.warning, module, message,
          error: error, stackTrace: stackTrace);

  static void error(
    String module,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) =>
      _log(AppLogLevel.error, module, message,
          error: error, stackTrace: stackTrace);

  // ─── Initialization ─────────────────────────────────────────────────────────

  /// Must be called once after [Firebase.initializeApp()] and before any log call.
  ///
  /// [sinks] – the list of backends to write logs to.
  static Future<void> initialize({required List<LogSink> sinks}) async {
    if (_initialized) return;

    _sessionId = const Uuid().v4();
    _sinks
      ..clear()
      ..addAll(sinks);

    final sessionInfo = await _buildSessionInfo();

    for (final sink in _sinks) {
      try {
        await sink.onSessionStart(sessionInfo);
      } catch (e, st) {
        // Never let a sink crash the app
        // ignore: avoid_print
        print('[AppLogger] Sink init failed: $e\n$st');
      }
    }

    _initialized = true;
  }

  /// The session ID for the current app launch.
  static String get sessionId => _sessionId;

  // ─── Internal ───────────────────────────────────────────────────────────────

  static void _log(
    AppLogLevel level,
    String module,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final record = LogRecord(
      sequenceNumber: ++_sequence,
      timestamp: DateTime.now().toUtc(),
      level: level,
      module: module,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    for (final sink in _sinks) {
      sink.onLog(record).catchError((e) {
        // ignore: avoid_print
        print('[AppLogger] Sink write failed: $e');
      });
    }
  }

  /// Dispatch session summary metrics and updates to all registered sinks.
  static Future<void> endSession(Map<String, dynamic> summary) async {
    if (!_initialized) return;
    for (final sink in _sinks) {
      try {
        await sink.onSessionEnd({
          'sessionId': _sessionId,
          ...summary,
        });
      } catch (e) {
        // ignore: avoid_print
        print('[AppLogger] Sink endSession failed: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> _buildSessionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    String platform = Platform.operatingSystem;
    String deviceModel = 'Unknown';
    String osVersion = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceModel = '${android.manufacturer} ${android.model}';
        osVersion = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceModel = ios.utsname.machine;
        osVersion = '${ios.systemName} ${ios.systemVersion}';
      }
    } catch (_) {
      // Device info unavailable — proceed with defaults
    }

    return {
      'sessionId': _sessionId,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'platform': platform,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'sessionStartTime': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
