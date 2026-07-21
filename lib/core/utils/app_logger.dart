import 'dart:developer' as developer;
import 'package:logging/logging.dart';

/// Central app logger.
///
/// Usage (per-file):
/// ```dart
/// import 'package:visual_song_book/core/utils/app_logger.dart';
/// final _log = AppLogger.get('FeatureName');
///
/// _log.info('Something happened');
/// _log.warning('Watch out');
/// _log.severe('Critical error', error, stackTrace);
/// ```
///
/// All loggers are children of the root 'VSB' logger, so setting the root
/// level controls the whole app.
class AppLogger {
  AppLogger._();

  /// Initialise the logging pipeline. Call once from [main] before [runApp].
  ///
  /// In debug mode every record is printed via [developer.log] so it appears in
  /// the IDE console / flutter logs with level colouring.
  /// In release mode only WARNING and above are emitted.
  static void init({Level level = Level.ALL}) {
    Logger.root.level = level;
    Logger.root.onRecord.listen(_onRecord);
  }

  /// Returns a named logger scoped under the app root namespace.
  static Logger get(String name) => Logger('VSB.$name');

  static void _onRecord(LogRecord rec) {
    // Map logging levels → developer.log levels (integers used by dart:developer)
    final devLevel = switch (rec.level) {
      Level.FINEST || Level.FINER || Level.FINE => 300,
      Level.CONFIG => 400,
      Level.INFO => 800,
      Level.WARNING => 900,
      Level.SEVERE => 1000,
      Level.SHOUT => 1200,
      _ => 500,
    };

    developer.log(
      rec.message,
      time: rec.time,
      level: devLevel,
      name: rec.loggerName,
      error: rec.error,
      stackTrace: rec.stackTrace,
    );
  }
}
