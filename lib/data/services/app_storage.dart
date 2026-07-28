import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';

final _log = AppLogger.get('AppStorage');

String? _cachedAppStoragePath;

/// Returns the single unified directory for all app data.
/// On desktop: `.visual_song_book/` under the user's home directory
/// On mobile: `<app-docs>/VisualSongBook/`
Future<String> getAppStoragePath() async {
  if (_cachedAppStoragePath != null) return _cachedAppStoragePath!;

  final Directory baseDir;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        p.current;
    baseDir = Directory(p.join(home, '.visual_song_book'));
  } else {
    final docs = await getApplicationDocumentsDirectory();
    baseDir = Directory(p.join(docs.path, 'VisualSongBook'));
  }

  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
    _log.info('Created app storage directory: ${baseDir.path}');
  }

  _cachedAppStoragePath = baseDir.path;
  _log.fine('App storage path: $_cachedAppStoragePath');
  return _cachedAppStoragePath!;
}

/// Convenience: full path to a file inside the app storage directory.
Future<String> getAppStorageFilePath(String fileName) async {
  final dir = await getAppStoragePath();
  return p.join(dir, fileName);
}
