import 'package:cloud_firestore/cloud_firestore.dart';
import '../log_sink.dart';

/// Uploads every log record to Firestore under:
///
/// ```
/// tv_debug_logs
///   └── {sessionId}            ← session document (metadata)
///         └── logs
///               └── {auto-id}  ← individual log documents
/// ```
///
/// Session document fields:
///   sessionId, appVersion, platform, deviceModel, osVersion, sessionStartTime
///
/// Log document fields:
///   sequenceNumber, timestamp, logLevel, module, message
///   error?      (only written when non-null)
///   stackTrace? (only written when non-null)
class FirestoreLogSink implements LogSink {
  FirestoreLogSink({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  late CollectionReference<Map<String, dynamic>> _logsCollection;

  static const String _rootCollection = 'tv_debug_logs';

  @override
  Future<void> onSessionStart(Map<String, dynamic> sessionInfo) async {
    final sessionRef = _firestore
        .collection(_rootCollection)
        .doc(sessionInfo['sessionId'] as String);

    _logsCollection = sessionRef.collection('logs');

    // Write the session metadata document
    await sessionRef.set({
      'sessionId': sessionInfo['sessionId'],
      'appVersion': sessionInfo['appVersion'],
      'platform': sessionInfo['platform'],
      'deviceModel': sessionInfo['deviceModel'],
      'osVersion': sessionInfo['osVersion'],
      'sessionStartTime': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> onLog(LogRecord record) async {
    final data = <String, dynamic>{
      'sequenceNumber': record.sequenceNumber,
      'timestamp': Timestamp.fromDate(record.timestamp),
      'logLevel': record.level.label,
      'module': record.module,
      'message': record.message,
    };

    // Optional fields — only written when present
    if (record.error != null) {
      data['error'] = record.error.toString();
    }
    if (record.stackTrace != null) {
      data['stackTrace'] = record.stackTrace.toString();
    }

    await _logsCollection.add(data);
  }

  @override
  Future<void> onSessionEnd(Map<String, dynamic> summary) async {
    final sessionRef = _firestore
        .collection(_rootCollection)
        .doc(summary['sessionId'] as String);

    await sessionRef.set({
      'deviceName': summary['deviceName'],
      'ipAddress': summary['ipAddress'],
      'controlPort': summary['controlPort'],
      'pairingPort': summary['pairingPort'],
      'finalState': summary['finalState'],
      'wasDiscoverySuccessful': summary['wasDiscoverySuccessful'],
      'wasTlsSuccessful': summary['wasTlsSuccessful'],
      'wasPairingStarted': summary['wasPairingStarted'],
      'wasPinDisplayed': summary['wasPinDisplayed'],
      'wasSecretAckReceived': summary['wasSecretAckReceived'],
      'wasControlConnectionEstablished': summary['wasControlConnectionEstablished'],
      'totalDurationMs': summary['totalDurationMs'],
      'failureReason': summary['failureReason'],
      'sessionEndTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
