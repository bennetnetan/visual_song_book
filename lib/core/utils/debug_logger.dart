import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:visual_song_book/core/utils/app_logger.dart';

/// Legacy debug-only logger — kept for backwards compatibility.
///
/// In debug mode it now forwards to [AppLogger] so records are visible in the
/// IDE structured log view. In release builds [AppLogger] suppresses everything
/// below WARNING, so [log] and [warning] become no-ops automatically.
class DebugLogger {
  static final _log = AppLogger.get('DebugLogger');

  static void log(String message) {
    if (kDebugMode) _log.info(message);
  }

  static void warning(String message) {
    if (kDebugMode) _log.warning(message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log.severe(message, error, stackTrace);
  }
}
