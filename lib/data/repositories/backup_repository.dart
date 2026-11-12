import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:visual_song_book/data/services/app_storage.dart';

class BackupRepository {
  /// Locates the active SQLite database file on disk.
  Future<File> _getDatabaseFile() async {
    final dbPath = await getAppStorageFilePath('songs_db.sqlite');
    return File(dbPath);
  }

  /// Returns the backup as [Uint8List] bytes.
  Future<Uint8List> exportBackupBytes({String? databasePath}) async {
    final dbFile = databasePath != null
        ? File(databasePath)
        : await _getDatabaseFile();
    if (!await dbFile.exists()) {
      throw Exception('Active database file not found on disk.');
    }

    // Read active database file bytes
    final dbBytes = await dbFile.readAsBytes();

    // Create Zip archive
    final archive = Archive();

    // 1. Add SQLite database
    archive.addFile(ArchiveFile('songs.db', dbBytes.length, dbBytes));

    // 2. Add metadata.json
    final metadata = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Visual Song Book',
    };
    final metadataBytes = utf8.encode(json.encode(metadata));
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );

    // Encode Zip file
    return ZipEncoder().encodeBytes(archive);
  }

  /// Exports the current database to a [.vsbook] archive file at the specified [targetPath].
  ///
  /// [databasePath] overrides the active database file location (used by tests
  /// to keep the round-trip hermetic); when omitted the app-storage database
  /// is used.
  Future<void> exportBackup(String targetPath, {String? databasePath}) async {
    final bytes = await exportBackupBytes(databasePath: databasePath);
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes);
  }
}
