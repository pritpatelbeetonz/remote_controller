import '../log_sink.dart';

/// Prints every log record to the Flutter development console.
///
/// Format:
/// ```
/// [#001] 🟢 INFO | AndroidTV | Connection started
///                  2026-08-03T05:30:00.000Z
/// ```
class ConsoleLogSink implements LogSink {
  @override
  Future<void> onSessionStart(Map<String, dynamic> sessionInfo) async {
    // ignore: avoid_print
    print(
      '┌──────────────────────────────────────────────────────\n'
      '│ 🚀 NEW SESSION\n'
      '│ Session ID   : ${sessionInfo['sessionId']}\n'
      '│ App Version  : ${sessionInfo['appVersion']}\n'
      '│ Platform     : ${sessionInfo['platform']}\n'
      '│ Device       : ${sessionInfo['deviceModel']}\n'
      '│ OS Version   : ${sessionInfo['osVersion']}\n'
      '│ Start Time   : ${sessionInfo['sessionStartTime']}\n'
      '└──────────────────────────────────────────────────────',
    );
  }

  @override
  Future<void> onLog(LogRecord record) async {
    final seq = '#${record.sequenceNumber.toString().padLeft(4, '0')}';
    final ts = record.timestamp.toIso8601String();
    final prefix =
        '[$seq] ${record.level.emoji} ${record.level.label.padRight(7)} │ ${record.module}';

    // ignore: avoid_print
    print('$prefix │ ${record.message}');

    if (record.error != null) {
      // ignore: avoid_print
      print('${''.padLeft(prefix.length + 3)}⚠ Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('${''.padLeft(prefix.length + 3)}↳ $ts\n${record.stackTrace}');
    } else {
      // ignore: avoid_print
      print('${''.padLeft(prefix.length + 3)}↳ $ts');
    }
  }

  @override
  Future<void> onSessionEnd(Map<String, dynamic> summary) async {
    // ignore: avoid_print
    print(
      '┌──────────────────────────────────────────────────────\n'
      '│ 🏁 SESSION SUMMARY\n'
      '│ Session ID        : ${summary['sessionId']}\n'
      '│ Device Name       : ${summary['deviceName']}\n'
      '│ IP Address        : ${summary['ipAddress']}\n'
      '│ Control Port      : ${summary['controlPort']}\n'
      '│ Pairing Port      : ${summary['pairingPort']}\n'
      '│ Final State       : ${summary['finalState']}\n'
      '│ Discovered OK     : ${summary['wasDiscoverySuccessful']}\n'
      '│ TLS Handshake OK  : ${summary['wasTlsSuccessful']}\n'
      '│ Pairing Started   : ${summary['wasPairingStarted']}\n'
      '│ PIN Displayed     : ${summary['wasPinDisplayed']}\n'
      '│ SecretAck OK      : ${summary['wasSecretAckReceived']}\n'
      '│ Connected OK      : ${summary['wasControlConnectionEstablished']}\n'
      '│ Total Duration    : ${summary['totalDurationMs']}ms\n'
      '│ Failure Reason    : ${summary['failureReason'] ?? 'None'}\n'
      '└──────────────────────────────────────────────────────',
    );
  }
}
