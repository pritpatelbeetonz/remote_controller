/// Defines the severity levels available to the AppLogger.
enum AppLogLevel {
  debug,
  info,
  warning,
  error;

  String get label {
    switch (this) {
      case AppLogLevel.debug:
        return 'DEBUG';
      case AppLogLevel.info:
        return 'INFO';
      case AppLogLevel.warning:
        return 'WARNING';
      case AppLogLevel.error:
        return 'ERROR';
    }
  }

  String get emoji {
    switch (this) {
      case AppLogLevel.debug:
        return '🔵';
      case AppLogLevel.info:
        return '🟢';
      case AppLogLevel.warning:
        return '🟡';
      case AppLogLevel.error:
        return '🔴';
    }
  }
}
