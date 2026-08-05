import 'log_level.dart';

/// Represents a single log record dispatched from [AppLogger].
class LogRecord {
  final int sequenceNumber;
  final DateTime timestamp;
  final AppLogLevel level;
  final String module;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  const LogRecord({
    required this.sequenceNumber,
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

/// Abstract sink that every logging backend must implement.
///
/// Decouples the logging API from its destinations (console, Firestore, etc.).
/// New sinks can be registered without touching any calling code.
abstract class LogSink {
  /// Called once after [AppLogger.initialize] completes.
  /// Use this to create session documents, open file handles, etc.
  Future<void> onSessionStart(Map<String, dynamic> sessionInfo);

  /// Called for every log event.
  Future<void> onLog(LogRecord record);

  /// Called at the end of a debugging session to write metadata summaries.
  Future<void> onSessionEnd(Map<String, dynamic> summary);
}
